#!/usr/bin/env python3
"""
Build human-review templates for MakeShop review_required CSVs.

Scope
-----
- Reads existing matrix CSV files from outputs/.
- Writes new review/template CSV files to outputs/.
- Does not call a database, write SQL, or mutate source CSV files.
- Uses UTF-8-SIG for Excel-friendly Korean text handling.

Usage
-----
  python scripts/build_makeshop_review_templates.py
"""

from __future__ import annotations

import csv
import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUTS = ROOT / "outputs"

COMMON_REVIEW_COLS = [
    "review_status",
    "action_type",
    "reviewer",
    "reviewed_at",
    "decision_sku_id",
    "decision_reason",
    "memo",
    "review_batch",
    "priority_score",
    "validation_note",
    "needs_second_review",
    "source_row_ref",
]

REVIEW_STATUS_ENUM = [
    ("pending", "Not reviewed yet. Never eligible for apply."),
    ("approved", "Human reviewer found enough evidence for the selected follow-up action."),
    ("rejected", "Candidate SKU or action is wrong. Not eligible for apply."),
    ("needs_alias", "SKU seems identifiable, but own_sku alias backfill must be handled first."),
    ("exclude_meta_row", "Product-level/meta/non-option row excluded from SKU mapping."),
    ("needs_more_evidence", "CSV evidence is insufficient; more source evidence is required."),
]

ACTION_TYPE_ENUM = [
    ("create_channel_mapping", "Channel mapping candidate only after strict approval fields are filled."),
    ("backfill_own_sku_alias", "Alias backfill candidate. Do not apply as channel mapping directly."),
    ("exclude_from_sku_mapping", "Excluded from SKU mapping."),
    ("regex_candidate", "Regex rule candidate. Requires new select-only export before any mapping decision."),
    ("manual_hold", "Manual hold for later review."),
]

INPUTS = {
    "weak_top1": "makeshop_review_ambiguous_weak_top1_matrix.csv",
    "ambiguous_manual": "makeshop_review_ambiguous_manual_matrix.csv",
    "not_in_alias": "makeshop_review_not_in_alias_matrix.csv",
    "null_key": "makeshop_review_null_key_matrix.csv",
    "pattern_loose": "makeshop_review_pattern_loose_matrix.csv",
}

OUTPUT_FILES = {
    "weak_priority": "makeshop_review_ambiguous_weak_top1_priority.csv",
    "weak_template": "makeshop_review_ambiguous_weak_top1_review_template.csv",
    "manual_template": "makeshop_review_ambiguous_manual_review_template.csv",
    "manual_long": "makeshop_review_ambiguous_manual_candidate_long.csv",
    "not_in_alias_template": "makeshop_review_not_in_alias_review_template.csv",
    "null_key_template": "makeshop_review_null_key_review_template.csv",
    "pattern_loose_template": "makeshop_review_pattern_loose_review_template.csv",
    "enum_guide": "makeshop_review_enum_guide.csv",
}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames is None:
            raise ValueError(f"CSV has no header: {path}")
        return list(reader)


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    assert_not_source_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    print(f"wrote {path.relative_to(ROOT)} rows={len(rows)}")


def assert_inputs_exist() -> None:
    missing = []
    for filename in INPUTS.values():
        path = OUTPUTS / filename
        if not path.exists():
            missing.append(str(path.relative_to(ROOT)))
    if missing:
        raise FileNotFoundError("Missing input CSV(s): " + ", ".join(missing))


def assert_not_source_path(path: Path) -> None:
    resolved = path.resolve()
    source_paths = {(OUTPUTS / filename).resolve() for filename in INPUTS.values()}
    if resolved in source_paths:
        raise ValueError(f"Refusing to overwrite source matrix CSV: {path}")


def int_value(value: str, default: int = 0) -> int:
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return default


def make_source_ref(filename: str, data_index: int) -> str:
    # CSV row number as opened in Excel: header is row 1, first data row is row 2.
    return f"{filename}:row{data_index + 2}"


def base_review_values(filename: str, data_index: int, priority_score: str = "") -> dict[str, str]:
    return {
        "review_status": "pending",
        "action_type": "",
        "reviewer": "",
        "reviewed_at": "",
        "decision_sku_id": "",
        "decision_reason": "",
        "memo": "",
        "review_batch": "",
        "priority_score": priority_score,
        "validation_note": "",
        "needs_second_review": "",
        "source_row_ref": make_source_ref(filename, data_index),
    }


def combine_fields(extra_cols: list[str], original_cols: list[str]) -> list[str]:
    fields = COMMON_REVIEW_COLS + extra_cols
    for col in original_cols:
        if col not in fields:
            fields.append(col)
    return fields


def weak_sort_bucket(row: dict[str, str]) -> str:
    score = int_value(row.get("token_score", ""))
    candidates = int_value(row.get("candidate_sku_count", ""))
    if score == 70 and candidates in (2, 3):
        return "A_score70_candidates2_3"
    if score == 70:
        return "B_score70_other"
    if score == 40:
        return "C_score40"
    if score == 30:
        return "D_score30"
    return "E_other"


def weak_priority_score(row: dict[str, str]) -> str:
    score = int_value(row.get("token_score", ""))
    candidates = int_value(row.get("candidate_sku_count", ""))
    bucket_bonus = 10000 if score == 70 and candidates in (2, 3) else 0
    value = bucket_bonus + (score * 100) - candidates
    return str(value)


def build_weak_outputs(rows: list[dict[str, str]], filename: str) -> dict[str, tuple[list[str], list[dict[str, str]]]]:
    original_cols = list(rows[0].keys()) if rows else []
    extra_cols = ["option_match_level", "product_name_match_level", "sort_bucket"]
    fieldnames = combine_fields(extra_cols, original_cols)

    enriched = []
    for idx, row in enumerate(rows):
        out = {}
        out.update(base_review_values(filename, idx, weak_priority_score(row)))
        out.update(
            {
                "option_match_level": "",
                "product_name_match_level": "",
                "sort_bucket": weak_sort_bucket(row),
            }
        )
        out.update(row)
        enriched.append(out)

    def sort_key(row: dict[str, str]) -> tuple[int, int, str, str]:
        return (
            -int_value(row.get("token_score", "")),
            int_value(row.get("candidate_sku_count", ""), 999999),
            row.get("product_uid", ""),
            row.get("own_sku_code", ""),
        )

    sorted_rows = sorted(enriched, key=sort_key)
    return {
        OUTPUT_FILES["weak_priority"]: (fieldnames, sorted_rows),
        OUTPUT_FILES["weak_template"]: (fieldnames, sorted_rows),
    }


def split_pipe(value: str) -> list[str]:
    if value is None or value == "":
        return []
    return str(value).split("|")


def build_manual_outputs(rows: list[dict[str, str]], filename: str) -> dict[str, tuple[list[str], list[dict[str, str]]]]:
    original_cols = list(rows[0].keys()) if rows else []
    extra_cols = ["selected_candidate_index", "candidate_compare_ref"]
    template_fields = combine_fields(extra_cols, original_cols)

    template_rows = []
    long_rows = []
    for idx, row in enumerate(rows):
        source_ref = make_source_ref(filename, idx)
        template = {}
        template.update(base_review_values(filename, idx))
        template.update(
            {
                "selected_candidate_index": "",
                "candidate_compare_ref": source_ref,
            }
        )
        template.update(row)
        template_rows.append(template)

        ids = split_pipe(row.get("candidate_sku_ids", ""))
        virtual_codes = split_pipe(row.get("candidate_virtual_sku_codes", ""))
        option_values = split_pipe(row.get("candidate_option_values", ""))
        product_names = split_pipe(row.get("candidate_product_names", ""))
        aliases = split_pipe(row.get("candidate_selfpia_sku_aliases", ""))
        scores = split_pipe(row.get("candidate_token_scores", ""))
        max_len = max(
            len(ids),
            len(virtual_codes),
            len(option_values),
            len(product_names),
            len(aliases),
            len(scores),
            0,
        )
        for candidate_idx in range(max_len):
            long_rows.append(
                {
                    "source_row_ref": source_ref,
                    "product_uid": row.get("product_uid", ""),
                    "channel_sku_code": row.get("channel_sku_code", ""),
                    "own_sku_code": row.get("own_sku_code", ""),
                    "opt_values": row.get("opt_values", ""),
                    "makeshop_product_name": row.get("makeshop_product_name", ""),
                    "candidate_index": str(candidate_idx + 1),
                    "candidate_sku_id": ids[candidate_idx] if candidate_idx < len(ids) else "",
                    "candidate_virtual_sku_code": virtual_codes[candidate_idx] if candidate_idx < len(virtual_codes) else "",
                    "candidate_option_value": option_values[candidate_idx] if candidate_idx < len(option_values) else "",
                    "candidate_product_name": product_names[candidate_idx] if candidate_idx < len(product_names) else "",
                    "selfpia_sku_aliases": aliases[candidate_idx] if candidate_idx < len(aliases) else "",
                    "token_score": scores[candidate_idx] if candidate_idx < len(scores) else "",
                }
            )

    long_fields = [
        "source_row_ref",
        "product_uid",
        "channel_sku_code",
        "own_sku_code",
        "opt_values",
        "makeshop_product_name",
        "candidate_index",
        "candidate_sku_id",
        "candidate_virtual_sku_code",
        "candidate_option_value",
        "candidate_product_name",
        "selfpia_sku_aliases",
        "token_score",
    ]
    return {
        OUTPUT_FILES["manual_template"]: (template_fields, template_rows),
        OUTPUT_FILES["manual_long"]: (long_fields, long_rows),
    }


def build_simple_template(
    rows: list[dict[str, str]],
    filename: str,
    extra_cols: list[str],
) -> tuple[list[str], list[dict[str, str]]]:
    original_cols = list(rows[0].keys()) if rows else []
    fieldnames = combine_fields(extra_cols, original_cols)
    out_rows = []
    for idx, row in enumerate(rows):
        out = {}
        out.update(base_review_values(filename, idx))
        for col in extra_cols:
            out[col] = ""
        out.update(row)
        out_rows.append(out)
    return fieldnames, out_rows


def build_enum_guide() -> tuple[list[str], list[dict[str, str]]]:
    rows = []
    for value, description in REVIEW_STATUS_ENUM:
        rows.append(
            {
                "enum_type": "review_status",
                "value": value,
                "description": description,
                "channel_mapping_apply_candidate": "yes_only_when_approved" if value == "approved" else "no",
            }
        )
    for value, description in ACTION_TYPE_ENUM:
        rows.append(
            {
                "enum_type": "action_type",
                "value": value,
                "description": description,
                "channel_mapping_apply_candidate": "yes_only_with_approved_and_required_fields"
                if value == "create_channel_mapping"
                else "no",
            }
        )
    return ["enum_type", "value", "description", "channel_mapping_apply_candidate"], rows


def main() -> int:
    assert_inputs_exist()

    loaded: dict[str, list[dict[str, str]]] = {}
    for key, filename in INPUTS.items():
        rows = read_csv(OUTPUTS / filename)
        loaded[key] = rows
        print(f"read outputs/{filename} rows={len(rows)}")

    outputs: dict[str, tuple[list[str], list[dict[str, str]]]] = {}
    outputs.update(build_weak_outputs(loaded["weak_top1"], INPUTS["weak_top1"]))
    outputs.update(build_manual_outputs(loaded["ambiguous_manual"], INPUTS["ambiguous_manual"]))
    outputs[OUTPUT_FILES["not_in_alias_template"]] = build_simple_template(
        loaded["not_in_alias"],
        INPUTS["not_in_alias"],
        ["normalized_own_sku_code", "proposed_alias", "matched_existing_sku_id", "alias_action"],
    )
    outputs[OUTPUT_FILES["null_key_template"]] = build_simple_template(
        loaded["null_key"],
        INPUTS["null_key"],
        ["null_key_type", "exclude_reason", "original_row_type"],
    )
    outputs[OUTPUT_FILES["pattern_loose_template"]] = build_simple_template(
        loaded["pattern_loose"],
        INPUTS["pattern_loose"],
        ["regex_candidate_code", "regex_rule_proposal", "regex_confidence", "sample_group_key"],
    )
    outputs[OUTPUT_FILES["enum_guide"]] = build_enum_guide()

    for filename, (fieldnames, rows) in outputs.items():
        write_csv(OUTPUTS / filename, fieldnames, rows)

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
