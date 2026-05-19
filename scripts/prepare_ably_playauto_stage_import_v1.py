# -*- coding: utf-8 -*-
"""
Prepare and optionally execute the Ably / PlayAuto local stage raw import.

Scope:
- Local DB only: product_ops_test / product_ops_tester.
- Inserts only into product_code_stage raw/source tables.
- Does not write import/export files.
- Does not modify source CSV/XLSX files.
- Does not touch product_code.code_alias or product_code.sku_channel_mapping.

Default source file paths are outside the repository:
  ../기타/에이블리 ALL.csv
  ../기타/플레이오토_일반_ALL판매처 (판매중,수정대기,판매대기 ALL).xlsx

Run dry summary only:
  python scripts/prepare_ably_playauto_stage_import_v1.py

Execute local stage import:
  python scripts/prepare_ably_playauto_stage_import_v1.py --execute
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

import pandas as pd


EXPECTED_ABLY_ROWS = 9158
EXPECTED_PLAYAUTO_PRODUCT_ROWS = 4219
EXPECTED_PLAYAUTO_SKU_ROWS = 17968

DEFAULT_SOURCE_DIR = Path.cwd().parent / "기타"
DEFAULT_ABLY_CSV = DEFAULT_SOURCE_DIR / "에이블리 ALL.csv"
DEFAULT_PLAYAUTO_XLSX = DEFAULT_SOURCE_DIR / "플레이오토_일반_ALL판매처 (판매중,수정대기,판매대기 ALL).xlsx"

PLAYAUTO_PRODUCT_SHEET_NAME = "쇼핑몰상품"
PLAYAUTO_SKU_SHEET_NAME = "SKU상품"


@dataclass(frozen=True)
class SourceFilePlan:
    source_file_id: str
    source_system: str
    source_file_path: Path
    source_file_name: str
    source_file_hash: str
    source_row_count: int
    source_column_count: int
    source_sheet_count: int | None
    source_note: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepare and optionally execute Ably / PlayAuto raw stage import."
    )
    parser.add_argument("--ably-csv", type=Path, default=DEFAULT_ABLY_CSV)
    parser.add_argument("--playauto-xlsx", type=Path, default=DEFAULT_PLAYAUTO_XLSX)
    parser.add_argument("--execute", action="store_true", help="Insert into local product_code_stage tables.")
    parser.add_argument("--allow-reimport", action="store_true", help="Allow duplicate source_file_hash imports.")
    parser.add_argument("--batch-size", type=int, default=400)
    parser.add_argument("--db-name", default=os.environ.get("POSTGRES_DB", "product_ops_test"))
    parser.add_argument("--db-user", default=os.environ.get("POSTGRES_USER", "product_ops_tester"))
    parser.add_argument(
        "--compose-file",
        type=Path,
        default=Path("docker-compose.local-test.yml"),
        help="Docker compose file for the local PostgreSQL service.",
    )
    parser.add_argument(
        "--env-file",
        type=Path,
        default=Path(".env.local"),
        help="Local compose env file.",
    )
    return parser.parse_args()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_ably_csv(path: Path) -> tuple[pd.DataFrame, str]:
    last_error: Exception | None = None
    for encoding in ("utf-8-sig", "cp949", "utf-8"):
        try:
            df = pd.read_csv(path, dtype=str, keep_default_na=False, encoding=encoding)
            return df, encoding
        except UnicodeDecodeError as exc:
            last_error = exc
    raise RuntimeError(f"failed to read Ably CSV with utf-8-sig/cp949/utf-8: {last_error}")


def read_playauto_workbook(path: Path) -> tuple[pd.DataFrame, pd.DataFrame, int]:
    workbook = pd.ExcelFile(path)
    sheet_names = workbook.sheet_names
    if PLAYAUTO_PRODUCT_SHEET_NAME not in sheet_names:
        raise RuntimeError(f"missing PlayAuto sheet: {PLAYAUTO_PRODUCT_SHEET_NAME}")
    if PLAYAUTO_SKU_SHEET_NAME not in sheet_names:
        raise RuntimeError(f"missing PlayAuto sheet: {PLAYAUTO_SKU_SHEET_NAME}")

    product_df = pd.read_excel(
        path,
        sheet_name=PLAYAUTO_PRODUCT_SHEET_NAME,
        dtype=str,
        keep_default_na=False,
        engine="openpyxl",
    )
    sku_df = pd.read_excel(
        path,
        sheet_name=PLAYAUTO_SKU_SHEET_NAME,
        dtype=str,
        keep_default_na=False,
        engine="openpyxl",
    )
    return product_df, sku_df, len(sheet_names)


def require_columns(df: pd.DataFrame, required: Iterable[str], label: str) -> None:
    missing = [column for column in required if column not in df.columns]
    if missing:
        raise RuntimeError(f"{label} missing required columns: {missing}")


def clean_cell(value: Any) -> str | None:
    if value is None:
        return None
    if pd.isna(value):
        return None
    text = str(value)
    return text


def row_payload(row: pd.Series) -> dict[str, Any]:
    payload: dict[str, Any] = {}
    for key, value in row.items():
        payload[str(key)] = clean_cell(value)
    return payload


def stable_row_hash(payload: dict[str, Any]) -> str:
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def sql_literal(value: Any) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "true" if value else "false"
    text = str(value).replace("\x00", "")
    return "'" + text.replace("'", "''") + "'"


def values_clause(rows: list[dict[str, Any]], columns: list[str]) -> str:
    value_rows = []
    for row in rows:
        value_rows.append("(" + ", ".join(sql_literal(row.get(column)) for column in columns) + ")")
    return ",\n".join(value_rows)


def chunked(items: list[dict[str, Any]], batch_size: int) -> Iterable[list[dict[str, Any]]]:
    for start in range(0, len(items), batch_size):
        yield items[start : start + batch_size]


def build_insert_sql(table_name: str, columns: list[str], rows: list[dict[str, Any]], batch_size: int) -> str:
    statements = []
    column_sql = ", ".join(columns)
    for batch in chunked(rows, batch_size):
        statements.append(
            f"INSERT INTO {table_name} ({column_sql}) VALUES\n"
            f"{values_clause(batch, columns)};"
        )
    return "\n\n".join(statements)


def make_source_plan(
    source_system: str,
    source_file_path: Path,
    source_row_count: int,
    source_column_count: int,
    source_sheet_count: int | None,
    source_note: str,
) -> SourceFilePlan:
    if "\\" in source_file_path.name or "/" in source_file_path.name:
        raise RuntimeError("source_file_name must be a basename, not a path")
    return SourceFilePlan(
        source_file_id=str(uuid.uuid4()),
        source_system=source_system,
        source_file_path=source_file_path,
        source_file_name=source_file_path.name,
        source_file_hash=sha256_file(source_file_path),
        source_row_count=source_row_count,
        source_column_count=source_column_count,
        source_sheet_count=source_sheet_count,
        source_note=source_note,
    )


def build_source_rows(source_plans: list[SourceFilePlan]) -> list[dict[str, Any]]:
    return [
        {
            "source_file_id": plan.source_file_id,
            "source_system": plan.source_system,
            "source_file_name": plan.source_file_name,
            "source_file_hash": plan.source_file_hash,
            "source_row_count": plan.source_row_count,
            "source_column_count": plan.source_column_count,
            "source_sheet_count": plan.source_sheet_count,
            "source_note": plan.source_note,
        }
        for plan in source_plans
    ]


def build_ably_rows(df: pd.DataFrame, source_file_id: str) -> list[dict[str, Any]]:
    required = [
        "상품 번호",
        "옵션 번호",
        "판매자 상품코드",
        "솔루션사 고유코드",
        "상품명",
        "옵션1",
        "옵션2",
        "전체 옵션명",
        "재고수량",
        "품절상태",
        "진열상태",
    ]
    require_columns(df, required, "Ably CSV")
    rows = []
    for index, row in df.iterrows():
        payload = row_payload(row)
        rows.append(
            {
                "source_file_id": source_file_id,
                "source_row_no": int(index) + 2,
                "raw_product_no": clean_cell(row["상품 번호"]),
                "raw_option_no": clean_cell(row["옵션 번호"]),
                "raw_seller_product_code": clean_cell(row["판매자 상품코드"]),
                "raw_solution_unique_code": clean_cell(row["솔루션사 고유코드"]),
                "raw_product_name": clean_cell(row["상품명"]),
                "raw_option1": clean_cell(row["옵션1"]),
                "raw_option2": clean_cell(row["옵션2"]),
                "raw_full_option_name": clean_cell(row["전체 옵션명"]),
                "raw_stock_qty": clean_cell(row["재고수량"]),
                "raw_soldout_status": clean_cell(row["품절상태"]),
                "raw_display_status": clean_cell(row["진열상태"]),
                "raw_payload": json.dumps(payload, ensure_ascii=False, sort_keys=True),
                "raw_row_hash": stable_row_hash(payload),
                "parse_status": "pending",
            }
        )
    return rows


def build_playauto_product_rows(df: pd.DataFrame, source_file_id: str) -> list[dict[str, Any]]:
    required = [
        "판매자관리코드",
        "쇼핑몰(계정)",
        "온라인 상품명",
        "쇼핑몰 상품번호",
        "상품상태(수정불가)",
        "옵션",
        "SKU",
        "옵션 추가금액",
        "옵션 판매수량",
        "출고수량",
        "옵션 상태",
    ]
    require_columns(df, required, "PlayAuto 쇼핑몰상품")
    rows = []
    for index, row in df.iterrows():
        payload = row_payload(row)
        rows.append(
            {
                "source_file_id": source_file_id,
                "source_sheet_name": "shopping_mall_products",
                "source_row_no": int(index) + 2,
                "raw_seller_management_code": clean_cell(row["판매자관리코드"]),
                "raw_mall_account": clean_cell(row["쇼핑몰(계정)"]),
                "raw_online_product_name": clean_cell(row["온라인 상품명"]),
                "raw_mall_product_no": clean_cell(row["쇼핑몰 상품번호"]),
                "raw_product_status": clean_cell(row["상품상태(수정불가)"]),
                "raw_option_text": clean_cell(row["옵션"]),
                "raw_sku_text": clean_cell(row["SKU"]),
                "raw_option_extra_price": clean_cell(row["옵션 추가금액"]),
                "raw_option_sale_qty": clean_cell(row["옵션 판매수량"]),
                "raw_outbound_qty": clean_cell(row["출고수량"]),
                "raw_option_status": clean_cell(row["옵션 상태"]),
                "raw_payload": json.dumps(payload, ensure_ascii=False, sort_keys=True),
                "raw_row_hash": stable_row_hash(payload),
                "parse_status": "pending",
            }
        )
    return rows


def build_playauto_sku_rows(df: pd.DataFrame, source_file_id: str) -> list[dict[str, Any]]:
    required = ["SKU코드", "SKU명", "속성", "배송처코드"]
    require_columns(df, required, "PlayAuto SKU상품")
    rows = []
    for index, row in df.iterrows():
        payload = row_payload(row)
        rows.append(
            {
                "source_file_id": source_file_id,
                "source_sheet_name": "sku_products",
                "source_row_no": int(index) + 2,
                "raw_sku_code": clean_cell(row["SKU코드"]),
                "raw_sku_name": clean_cell(row["SKU명"]),
                "raw_attribute": clean_cell(row["속성"]),
                "raw_shipping_place_code": clean_cell(row["배송처코드"]),
                "raw_payload": json.dumps(payload, ensure_ascii=False, sort_keys=True),
                "raw_row_hash": stable_row_hash(payload),
                "parse_status": "pending",
            }
        )
    return rows


def validate_expected_counts(ably_df: pd.DataFrame, playauto_product_df: pd.DataFrame, playauto_sku_df: pd.DataFrame) -> None:
    checks = [
        ("Ably CSV", len(ably_df), EXPECTED_ABLY_ROWS),
        ("PlayAuto 쇼핑몰상품", len(playauto_product_df), EXPECTED_PLAYAUTO_PRODUCT_ROWS),
        ("PlayAuto SKU상품", len(playauto_sku_df), EXPECTED_PLAYAUTO_SKU_ROWS),
    ]
    failures = [f"{label}: actual={actual}, expected={expected}" for label, actual, expected in checks if actual != expected]
    if failures:
        raise RuntimeError("source row count mismatch: " + "; ".join(failures))


def build_import_sql(
    *,
    source_plans: list[SourceFilePlan],
    source_rows: list[dict[str, Any]],
    ably_rows: list[dict[str, Any]],
    playauto_product_rows: list[dict[str, Any]],
    playauto_sku_rows: list[dict[str, Any]],
    batch_size: int,
    allow_reimport: bool,
) -> str:
    hashes = ", ".join(sql_literal(plan.source_file_hash) for plan in source_plans)
    duplicate_guard = ""
    if not allow_reimport:
        duplicate_guard = f"""
DO $duplicate_guard$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM product_code_stage.ably_playauto_source_file
    WHERE source_file_hash IN ({hashes})
  ) THEN
    RAISE EXCEPTION 'blocked: source_file_hash already exists in product_code_stage.ably_playauto_source_file';
  END IF;
END
$duplicate_guard$;
"""

    sql_parts = [
        "BEGIN;",
        """
SELECT
  'guard'::text AS section,
  current_database() AS current_database,
  current_user AS current_user,
  CASE
    WHEN current_database() = 'product_ops_test'
     AND current_user = 'product_ops_tester'
    THEN 'PASS'
    ELSE 'STOP'
  END AS guard_result,
  'local raw stage import guard'::text AS note;

DO $guard$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION 'blocked: current database is %, expected product_ops_test', current_database();
  END IF;

  IF current_user <> 'product_ops_tester' THEN
    RAISE EXCEPTION 'blocked: current user is %, expected product_ops_tester', current_user;
  END IF;
END
$guard$;
""",
        duplicate_guard,
        build_insert_sql(
            "product_code_stage.ably_playauto_source_file",
            [
                "source_file_id",
                "source_system",
                "source_file_name",
                "source_file_hash",
                "source_row_count",
                "source_column_count",
                "source_sheet_count",
                "source_note",
            ],
            source_rows,
            batch_size,
        ),
        build_insert_sql(
            "product_code_stage.ably_raw",
            [
                "source_file_id",
                "source_row_no",
                "raw_product_no",
                "raw_option_no",
                "raw_seller_product_code",
                "raw_solution_unique_code",
                "raw_product_name",
                "raw_option1",
                "raw_option2",
                "raw_full_option_name",
                "raw_stock_qty",
                "raw_soldout_status",
                "raw_display_status",
                "raw_payload",
                "raw_row_hash",
                "parse_status",
            ],
            ably_rows,
            batch_size,
        ),
        build_insert_sql(
            "product_code_stage.playauto_product_raw",
            [
                "source_file_id",
                "source_sheet_name",
                "source_row_no",
                "raw_seller_management_code",
                "raw_mall_account",
                "raw_online_product_name",
                "raw_mall_product_no",
                "raw_product_status",
                "raw_option_text",
                "raw_sku_text",
                "raw_option_extra_price",
                "raw_option_sale_qty",
                "raw_outbound_qty",
                "raw_option_status",
                "raw_payload",
                "raw_row_hash",
                "parse_status",
            ],
            playauto_product_rows,
            batch_size,
        ),
        build_insert_sql(
            "product_code_stage.playauto_sku_raw",
            [
                "source_file_id",
                "source_sheet_name",
                "source_row_no",
                "raw_sku_code",
                "raw_sku_name",
                "raw_attribute",
                "raw_shipping_place_code",
                "raw_payload",
                "raw_row_hash",
                "parse_status",
            ],
            playauto_sku_rows,
            batch_size,
        ),
        f"""
DO $count_guard$
DECLARE
  ably_count bigint;
  playauto_product_count bigint;
  playauto_sku_count bigint;
BEGIN
  SELECT COUNT(*) INTO ably_count
  FROM product_code_stage.ably_raw
  WHERE source_file_id = {sql_literal(source_plans[0].source_file_id)};

  SELECT COUNT(*) INTO playauto_product_count
  FROM product_code_stage.playauto_product_raw
  WHERE source_file_id = {sql_literal(source_plans[1].source_file_id)}
    AND source_sheet_name = 'shopping_mall_products';

  SELECT COUNT(*) INTO playauto_sku_count
  FROM product_code_stage.playauto_sku_raw
  WHERE source_file_id = {sql_literal(source_plans[1].source_file_id)}
    AND source_sheet_name = 'sku_products';

  IF ably_count <> {EXPECTED_ABLY_ROWS} THEN
    RAISE EXCEPTION 'Ably raw row count mismatch: actual %, expected {EXPECTED_ABLY_ROWS}', ably_count;
  END IF;

  IF playauto_product_count <> {EXPECTED_PLAYAUTO_PRODUCT_ROWS} THEN
    RAISE EXCEPTION 'PlayAuto product raw row count mismatch: actual %, expected {EXPECTED_PLAYAUTO_PRODUCT_ROWS}', playauto_product_count;
  END IF;

  IF playauto_sku_count <> {EXPECTED_PLAYAUTO_SKU_ROWS} THEN
    RAISE EXCEPTION 'PlayAuto SKU raw row count mismatch: actual %, expected {EXPECTED_PLAYAUTO_SKU_ROWS}', playauto_sku_count;
  END IF;
END
$count_guard$;

SELECT
  'raw_stage_import_summary'::text AS section,
  (SELECT COUNT(*) FROM product_code_stage.ably_playauto_source_file WHERE source_file_id IN ({sql_literal(source_plans[0].source_file_id)}, {sql_literal(source_plans[1].source_file_id)})) AS source_file_rows,
  (SELECT COUNT(*) FROM product_code_stage.ably_raw WHERE source_file_id = {sql_literal(source_plans[0].source_file_id)}) AS ably_raw_rows,
  (SELECT COUNT(*) FROM product_code_stage.playauto_product_raw WHERE source_file_id = {sql_literal(source_plans[1].source_file_id)}) AS playauto_product_raw_rows,
  (SELECT COUNT(*) FROM product_code_stage.playauto_sku_raw WHERE source_file_id = {sql_literal(source_plans[1].source_file_id)}) AS playauto_sku_raw_rows,
  (SELECT COUNT(*) FROM product_code_stage.channel_option_evidence WHERE source_file_id IN ({sql_literal(source_plans[0].source_file_id)}, {sql_literal(source_plans[1].source_file_id)})) AS normalized_evidence_rows,
  'PASS'::text AS import_verdict;

COMMIT;
""",
    ]
    return "\n\n".join(part for part in sql_parts if part.strip())


def run_psql(sql_text: str, args: argparse.Namespace) -> int:
    command = [
        "docker",
        "compose",
        "--env-file",
        str(args.env_file),
        "-f",
        str(args.compose_file),
        "exec",
        "-T",
        "postgres",
        "psql",
        "-v",
        "ON_ERROR_STOP=1",
        "-U",
        args.db_user,
        "-d",
        args.db_name,
        "-P",
        "pager=off",
    ]
    result = subprocess.run(
        command,
        input=sql_text.encode("utf-8"),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    sys.stdout.buffer.write(result.stdout)
    return result.returncode


def print_plan_summary(
    *,
    ably_encoding: str,
    source_plans: list[SourceFilePlan],
    ably_df: pd.DataFrame,
    playauto_product_df: pd.DataFrame,
    playauto_sku_df: pd.DataFrame,
    execute: bool,
) -> None:
    summary = {
        "mode": "execute" if execute else "dry_run_summary_only",
        "ably_encoding": ably_encoding,
        "source_files": [
            {
                "source_system": plan.source_system,
                "source_file_name": plan.source_file_name,
                "source_file_hash": plan.source_file_hash,
                "source_row_count": plan.source_row_count,
                "source_column_count": plan.source_column_count,
                "source_sheet_count": plan.source_sheet_count,
            }
            for plan in source_plans
        ],
        "raw_stage_expected_rows": {
            "ably_raw": len(ably_df),
            "playauto_product_raw": len(playauto_product_df),
            "playauto_sku_raw": len(playauto_sku_df),
            "channel_option_evidence": 0,
        },
        "normalized_evidence": "deferred",
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))


def main() -> int:
    args = parse_args()
    if args.db_name != "product_ops_test":
        raise RuntimeError(f"blocked: db name must be product_ops_test, got {args.db_name}")
    if args.db_user != "product_ops_tester":
        raise RuntimeError(f"blocked: db user must be product_ops_tester, got {args.db_user}")

    ably_path = args.ably_csv.resolve()
    playauto_path = args.playauto_xlsx.resolve()
    if not ably_path.exists():
        raise FileNotFoundError(ably_path)
    if not playauto_path.exists():
        raise FileNotFoundError(playauto_path)

    ably_df, ably_encoding = read_ably_csv(ably_path)
    playauto_product_df, playauto_sku_df, playauto_sheet_count = read_playauto_workbook(playauto_path)
    validate_expected_counts(ably_df, playauto_product_df, playauto_sku_df)

    ably_plan = make_source_plan(
        "ably_csv",
        ably_path,
        len(ably_df),
        len(ably_df.columns),
        1,
        f"read_encoding={ably_encoding}; raw stage import only; normalized evidence deferred",
    )
    playauto_plan = make_source_plan(
        "playauto_xlsx",
        playauto_path,
        len(playauto_product_df),
        len(playauto_product_df.columns),
        playauto_sheet_count,
        f"shopping_mall_products_rows={len(playauto_product_df)}; sku_products_rows={len(playauto_sku_df)}; raw stage import only; normalized evidence deferred",
    )
    source_plans = [ably_plan, playauto_plan]

    print_plan_summary(
        ably_encoding=ably_encoding,
        source_plans=source_plans,
        ably_df=ably_df,
        playauto_product_df=playauto_product_df,
        playauto_sku_df=playauto_sku_df,
        execute=args.execute,
    )

    if not args.execute:
        return 0

    source_rows = build_source_rows(source_plans)
    ably_rows = build_ably_rows(ably_df, ably_plan.source_file_id)
    playauto_product_rows = build_playauto_product_rows(playauto_product_df, playauto_plan.source_file_id)
    playauto_sku_rows = build_playauto_sku_rows(playauto_sku_df, playauto_plan.source_file_id)
    import_sql = build_import_sql(
        source_plans=source_plans,
        source_rows=source_rows,
        ably_rows=ably_rows,
        playauto_product_rows=playauto_product_rows,
        playauto_sku_rows=playauto_sku_rows,
        batch_size=args.batch_size,
        allow_reimport=args.allow_reimport,
    )
    return run_psql(import_sql, args)


if __name__ == "__main__":
    raise SystemExit(main())
