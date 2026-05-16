#!/usr/bin/env python3
"""
Analyze MakeShop weak_top1 rows for possible automatic reduction.

This script is CSV-only and does not connect to a database. It classifies
strong_candidate rows for later review/dryrun design, but it does not apply
anything.

Inputs:
  outputs/makeshop_review_ambiguous_weak_top1_matrix.csv

Outputs:
  outputs/makeshop_weak_top1_reduction_summary.txt
  outputs/makeshop_weak_top1_strong_candidate.csv
  outputs/makeshop_weak_top1_needs_review.csv
  outputs/makeshop_weak_top1_group_patterns.csv
"""

from __future__ import annotations

import csv
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUTS = ROOT / "outputs"
INPUT_CSV = OUTPUTS / "makeshop_review_ambiguous_weak_top1_matrix.csv"

SUMMARY_TXT = OUTPUTS / "makeshop_weak_top1_reduction_summary.txt"
STRONG_CSV = OUTPUTS / "makeshop_weak_top1_strong_candidate.csv"
NEEDS_REVIEW_CSV = OUTPUTS / "makeshop_weak_top1_needs_review.csv"
GROUP_PATTERNS_CSV = OUTPUTS / "makeshop_weak_top1_group_patterns.csv"


DERIVED_COLS = [
    "analysis_status",
    "strong_candidate",
    "strong_candidate_reason",
    "review_reason",
    "option_exact_match",
    "option_partial_match",
    "selfpia_option_no_matches_sto_id",
    "extracted_selfpia_option_nos",
    "extracted_selfpia_product_aliases",
    "primary_selfpia_option_no",
    "primary_selfpia_product_alias",
    "selfpia_product_alias_matches_product_uid",
    "product_name_token_overlap",
    "product_name_group_match",
    "product_uid_group_row_count",
    "product_uid_group_matched_count",
    "product_uid_group_consistency_ratio",
    "product_uid_group_consistent",
    "channel_sku_code_duplicate_count",
    "score_gap_available",
    "score_gap_note",
]

GROUP_COLS = [
    "product_uid",
    "row_count",
    "matched_option_no_count",
    "group_consistency_ratio",
    "group_consistent",
    "token70_count",
    "candidate_count_le3_count",
    "strong_candidate_count",
    "distinct_own_sku_codes",
    "min_sto_id",
    "max_sto_id",
    "selfpia_option_nos",
    "makeshop_product_names",
    "candidate_product_names",
]

STOPWORDS = {
    "925",
    "14k",
    "silver",
    "실버",
    "써지컬",
    "써지컬스틸",
    "피어싱",
    "귀걸이",
    "목걸이",
    "팔찌",
    "반지",
    "모음",
    "종",
    "무배",
    "무료배송",
    "기본",
}


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise FileNotFoundError(f"Missing input CSV: {path}")
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames is None:
            raise ValueError(f"CSV has no header: {path}")
        return list(reader)


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    print(f"wrote {path.relative_to(ROOT)} rows={len(rows)}")


def to_int(value: str, default: int = 0) -> int:
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return default


def truth(value: bool) -> str:
    return "true" if value else "false"


def normalize_text(value: str) -> str:
    value = str(value or "").lower()
    value = re.sub(r"\[[^\]]*\]", " ", value)
    value = re.sub(r"[^0-9a-z가-힣]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def compact_text(value: str) -> str:
    return re.sub(r"\s+", "", normalize_text(value))


def tokens(value: str) -> set[str]:
    found = set()
    for token in normalize_text(value).split():
        if len(token) < 2:
            continue
        if token in STOPWORDS:
            continue
        found.add(token)
    return found


def option_exact_match(opt_values: str, candidate_option_value: str) -> bool:
    opt = compact_text(opt_values)
    cand = compact_text(candidate_option_value)
    return bool(opt and cand and opt == cand)


def option_partial_match(opt_values: str, candidate_option_value: str) -> bool:
    opt = compact_text(opt_values)
    cand = compact_text(candidate_option_value)
    if not opt or not cand:
        return False
    return cand in opt or opt in cand


def extract_option_nos(alias_value: str) -> list[str]:
    option_nos: list[str] = []
    for raw in re.split(r"[|,;/\s]+", alias_value or ""):
        alias = raw.strip()
        if not alias:
            continue
        match = re.search(r"-(\d+)$", alias)
        if match:
            option_nos.append(str(int(match.group(1))))
    return option_nos


def extract_product_aliases(alias_value: str) -> list[str]:
    product_aliases: list[str] = []
    for raw in re.split(r"[|,;/\s]+", alias_value or ""):
        alias = raw.strip()
        if not alias:
            continue
        match = re.search(r"^(.+)-\d+$", alias)
        if match:
            product_aliases.append(match.group(1))
    return product_aliases


def product_name_overlap(make_name: str, candidate_name: str) -> tuple[int, bool]:
    left = tokens(make_name)
    right = tokens(candidate_name)
    if not left or not right:
        return 0, False
    overlap = len(left & right)
    return overlap, overlap >= 1


def analyze(rows: list[dict[str, str]]) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    channel_counts = Counter(row.get("channel_sku_code", "") for row in rows if row.get("channel_sku_code", ""))

    pre = []
    groups: dict[str, list[dict[str, str]]] = defaultdict(list)
    for idx, row in enumerate(rows):
        option_nos = extract_option_nos(row.get("top1_selfpia_sku_aliases", ""))
        product_aliases = extract_product_aliases(row.get("top1_selfpia_sku_aliases", ""))
        primary_no = option_nos[0] if option_nos else ""
        primary_product_alias = product_aliases[0] if product_aliases else ""
        sto_id = str(to_int(row.get("sto_id_raw", ""), -1)) if row.get("sto_id_raw", "") != "" else ""
        option_no_match = bool(primary_no and sto_id and primary_no == sto_id)
        product_alias_matches_product_uid = bool(primary_product_alias and row.get("product_uid", "") and primary_product_alias == row.get("product_uid", ""))
        exact = option_exact_match(row.get("opt_values", ""), row.get("top1_option_value", ""))
        partial = option_partial_match(row.get("opt_values", ""), row.get("top1_option_value", ""))
        overlap_count, product_group_match = product_name_overlap(
            row.get("makeshop_product_name", ""),
            row.get("top1_product_name", ""),
        )

        enriched = dict(row)
        enriched["_source_index"] = str(idx)
        enriched["_option_no_match_bool"] = truth(option_no_match)
        enriched["_token70_bool"] = truth(to_int(row.get("token_score", "")) >= 70)
        enriched["_candidate_le3_bool"] = truth(to_int(row.get("candidate_sku_count", ""), 999999) <= 3)
        enriched["option_exact_match"] = truth(exact)
        enriched["option_partial_match"] = truth(partial)
        enriched["selfpia_option_no_matches_sto_id"] = truth(option_no_match)
        enriched["extracted_selfpia_option_nos"] = "|".join(option_nos)
        enriched["extracted_selfpia_product_aliases"] = "|".join(product_aliases)
        enriched["primary_selfpia_option_no"] = primary_no
        enriched["primary_selfpia_product_alias"] = primary_product_alias
        enriched["selfpia_product_alias_matches_product_uid"] = truth(product_alias_matches_product_uid)
        enriched["product_name_token_overlap"] = str(overlap_count)
        enriched["product_name_group_match"] = truth(product_group_match)
        enriched["channel_sku_code_duplicate_count"] = str(channel_counts.get(row.get("channel_sku_code", ""), 0))
        enriched["score_gap_available"] = "false"
        enriched["score_gap_note"] = "not_available_in_weak_top1_matrix; only top1 candidate columns are present"
        pre.append(enriched)
        groups[row.get("product_uid", "")].append(enriched)

    group_stats: dict[str, dict[str, str]] = {}
    for product_uid, items in groups.items():
        row_count = len(items)
        matched_count = sum(1 for item in items if item["_option_no_match_bool"] == "true")
        ratio = matched_count / row_count if row_count else 0
        group_consistent = row_count >= 2 and ratio >= 0.80
        strong_count_placeholder = 0
        option_nos = sorted({item["primary_selfpia_option_no"] for item in items if item["primary_selfpia_option_no"]}, key=lambda x: to_int(x))
        sto_ids = [to_int(item.get("sto_id_raw", "")) for item in items if item.get("sto_id_raw", "")]
        stat = {
            "product_uid": product_uid,
            "row_count": str(row_count),
            "matched_option_no_count": str(matched_count),
            "group_consistency_ratio": f"{ratio:.4f}",
            "group_consistent": truth(group_consistent),
            "token70_count": str(sum(1 for item in items if item["_token70_bool"] == "true")),
            "candidate_count_le3_count": str(sum(1 for item in items if item["_candidate_le3_bool"] == "true")),
            "strong_candidate_count": str(strong_count_placeholder),
            "distinct_own_sku_codes": str(len({item.get("own_sku_code", "") for item in items if item.get("own_sku_code", "")})),
            "min_sto_id": str(min(sto_ids)) if sto_ids else "",
            "max_sto_id": str(max(sto_ids)) if sto_ids else "",
            "selfpia_option_nos": "|".join(option_nos),
            "makeshop_product_names": " | ".join(sorted({item.get("makeshop_product_name", "") for item in items if item.get("makeshop_product_name", "")})[:5]),
            "candidate_product_names": " | ".join(sorted({item.get("top1_product_name", "") for item in items if item.get("top1_product_name", "")})[:5]),
        }
        group_stats[product_uid] = stat

    enriched_rows = []
    strong_by_product_uid = Counter()
    for row in pre:
        stat = group_stats.get(row.get("product_uid", ""), {})
        row["product_uid_group_row_count"] = stat.get("row_count", "0")
        row["product_uid_group_matched_count"] = stat.get("matched_option_no_count", "0")
        row["product_uid_group_consistency_ratio"] = stat.get("group_consistency_ratio", "0.0000")
        row["product_uid_group_consistent"] = stat.get("group_consistent", "false")

        reasons = []
        review_reasons = []
        if to_int(row.get("token_score", "")) >= 70:
            reasons.append("token_score>=70")
        else:
            review_reasons.append("token_score<70")
        if to_int(row.get("candidate_sku_count", ""), 999999) <= 3:
            reasons.append("candidate_sku_count<=3")
        else:
            review_reasons.append("candidate_sku_count>3")
        if row["selfpia_option_no_matches_sto_id"] == "true":
            reasons.append("selfpia_option_no_matches_sto_id")
        else:
            review_reasons.append("selfpia_option_no_mismatch_or_missing")
        if row["option_partial_match"] == "true" or row["option_exact_match"] == "true":
            reasons.append("option_match")
        else:
            review_reasons.append("option_not_matched")
        if row.get("channel_sku_code", ""):
            reasons.append("channel_sku_code_nonblank")
        else:
            review_reasons.append("channel_sku_code_blank")
        if row.get("top1_candidate_sku_id", ""):
            reasons.append("top1_candidate_sku_id_nonblank")
        else:
            review_reasons.append("top1_candidate_sku_id_blank")
        if to_int(row["channel_sku_code_duplicate_count"]) == 1:
            reasons.append("channel_sku_code_unique")
        else:
            review_reasons.append("channel_sku_code_duplicate")

        strong = not review_reasons
        row["strong_candidate"] = truth(strong)
        row["analysis_status"] = "strong_auto_candidate" if strong else "needs_review"
        row["strong_candidate_reason"] = ";".join(reasons)
        row["review_reason"] = ";".join(review_reasons)
        enriched_rows.append(row)
        if strong:
            strong_by_product_uid[row.get("product_uid", "")] += 1

    group_rows = []
    for product_uid in sorted(group_stats.keys()):
        stat = dict(group_stats[product_uid])
        stat["strong_candidate_count"] = str(strong_by_product_uid[product_uid])
        group_rows.append(stat)

    group_rows.sort(
        key=lambda item: (
            item["group_consistent"] != "true",
            -to_int(item["strong_candidate_count"]),
            -to_int(item["row_count"]),
            item["product_uid"],
        )
    )
    return enriched_rows, group_rows


def summarize(rows: list[dict[str, str]], group_rows: list[dict[str, str]]) -> str:
    total = len(rows)
    strong = [row for row in rows if row["strong_candidate"] == "true"]
    needs = total - len(strong)

    def count_where(predicate) -> int:
        return sum(1 for row in rows if predicate(row))

    score_candidate_counter = Counter(
        (row.get("token_score", ""), row.get("candidate_sku_count", "")) for row in rows
    )
    top_score_candidate = score_candidate_counter.most_common(20)

    lines = [
        "MakeShop weak_top1 reduction analysis",
        "======================================",
        "",
        f"input: {INPUT_CSV.relative_to(ROOT)}",
        f"total_rows: {total}",
        "",
        "Key counts",
        "----------",
        f"token_score>=70: {count_where(lambda r: to_int(r.get('token_score', '')) >= 70)}",
        f"candidate_sku_count<=3: {count_where(lambda r: to_int(r.get('candidate_sku_count', ''), 999999) <= 3)}",
        f"token_score>=70_and_candidate_sku_count<=3: {count_where(lambda r: to_int(r.get('token_score', '')) >= 70 and to_int(r.get('candidate_sku_count', ''), 999999) <= 3)}",
        f"option_exact_match: {count_where(lambda r: r['option_exact_match'] == 'true')}",
        f"option_partial_match: {count_where(lambda r: r['option_partial_match'] == 'true')}",
        f"selfpia_option_no_matches_sto_id: {count_where(lambda r: r['selfpia_option_no_matches_sto_id'] == 'true')}",
        f"selfpia_product_alias_matches_product_uid: {count_where(lambda r: r['selfpia_product_alias_matches_product_uid'] == 'true')}",
        f"product_name_group_match: {count_where(lambda r: r['product_name_group_match'] == 'true')}",
        f"channel_sku_code_duplicate_rows: {count_where(lambda r: to_int(r['channel_sku_code_duplicate_count']) > 1)}",
        "",
        "Strong candidate proposal",
        "-------------------------",
        f"strong_auto_candidate_rows: {len(strong)}",
        f"needs_review_rows: {needs}",
        f"strong_auto_candidate_pct: {(len(strong) / total * 100 if total else 0):.2f}%",
        "",
        "Group consistency",
        "-----------------",
        f"product_uid_groups: {len(group_rows)}",
        f"group_consistent_true: {sum(1 for row in group_rows if row['group_consistent'] == 'true')}",
        f"groups_with_strong_candidate: {sum(1 for row in group_rows if to_int(row['strong_candidate_count']) > 0)}",
        "",
        "Score gap",
        "---------",
        "score_gap_available: false",
        "score_gap_note: weak_top1 matrix contains only top1 candidate columns; second candidate score/gap cannot be computed from this CSV.",
        "selfpia_product_alias_note: top1_selfpia_sku_aliases look like selfpia SKU aliases such as 3295-1. The prefix is not the MakeShop product_uid, so direct product_uid match is usually not available from this CSV alone.",
        "",
        "Top token_score / candidate_sku_count buckets",
        "----------------------------------------------",
    ]
    for (score, count), bucket_count in top_score_candidate:
        lines.append(f"token_score={score}, candidate_sku_count={count}: {bucket_count}")
    lines.extend(
        [
            "",
            "Strong candidate criteria used",
            "------------------------------",
            "- token_score >= 70",
            "- candidate_sku_count <= 3",
            "- selfpia option number parsed from top1_selfpia_sku_aliases matches sto_id_raw",
            "- option_partial_match=true or option_exact_match=true",
            "- channel_sku_code nonblank",
            "- top1_candidate_sku_id nonblank",
            "- channel_sku_code unique within source CSV",
            "",
            "Important",
            "---------",
            "This is classification only. No apply SQL was generated and no database was changed.",
        ]
    )
    return "\n".join(lines) + "\n"


def main() -> int:
    rows = read_csv(INPUT_CSV)
    print(f"read {INPUT_CSV.relative_to(ROOT)} rows={len(rows)}")

    enriched_rows, group_rows = analyze(rows)
    strong_rows = [row for row in enriched_rows if row["strong_candidate"] == "true"]
    needs_rows = [row for row in enriched_rows if row["strong_candidate"] != "true"]

    original_fields = list(rows[0].keys()) if rows else []
    enriched_fields = DERIVED_COLS + [field for field in original_fields if field not in DERIVED_COLS]
    write_csv(STRONG_CSV, enriched_fields, strong_rows)
    write_csv(NEEDS_REVIEW_CSV, enriched_fields, needs_rows)
    write_csv(GROUP_PATTERNS_CSV, GROUP_COLS, group_rows)

    summary = summarize(enriched_rows, group_rows)
    SUMMARY_TXT.write_text(summary, encoding="utf-8")
    print(f"wrote {SUMMARY_TXT.relative_to(ROOT)}")
    print(summary)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
