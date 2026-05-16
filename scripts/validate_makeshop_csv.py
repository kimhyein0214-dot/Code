#!/usr/bin/env python3
"""
validate_makeshop_csv.py

Validate a makeshop_minimal_*.csv produced by extract_makeshop_minimal_csv.py
and emit a small set of integrity / matching readiness metrics.

Metrics emitted (stdout, pipe-friendly):
  - row_count
  - product_uid_distinct
  - product_uid_blank_rows
  - sto_id_blank_rows
  - sto_code_blank_rows
  - opt_value_blank_rows
  - opt_values_blank_rows
  - opt_value_bracket_hits           # rows whose opt_value matched the bracket regex
  - opt_value_bracket_unique_codes   # distinct candidates pulled from opt_value
  - opt_values_bracket_hits          # rows whose opt_values matched the bracket regex
  - opt_values_bracket_unique_codes  # distinct candidates pulled from opt_values
  - own_sku_candidate_resolvable     # rows where sto_code OR opt_value OR opt_values yields a candidate
  - own_sku_candidate_unresolvable   # rows where none of the three yields a candidate
  - sto_id_duplicate_keys            # sto_id values appearing in 2+ rows
  - sto_id_duplicate_rows            # total rows belonging to a duplicated sto_id
  - product_sto_duplicate_keys       # (product_uid, sto_id) pairs appearing in 2+ rows
  - product_sto_duplicate_rows       # total rows belonging to a duplicated pair

Usage
-----
  python scripts/validate_makeshop_csv.py outputs/makeshop_minimal_sample100.csv
  python scripts/validate_makeshop_csv.py outputs/makeshop_minimal_full.csv

This script is SELECT-only relative to the source file: it only reads the CSV.
It does NOT touch the database, network, or any other file.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from collections import Counter

# Bracket pattern matching the seed convention [ALPHA-NN-NN] or [ALPHA-NN-NN_N]
# Matches: [ABC-12-34], [ABC-12-34_5], [Ab-1-2] etc.
BRACKET_RE = re.compile(r"\[([A-Za-z]+-\d+-\d+(?:_\d+)?)\]")


def _is_blank(v) -> bool:
    return v is None or str(v).strip() == ""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("csv_path", help="CSV file to validate (utf-8-sig or utf-8)")
    ap.add_argument(
        "--encoding",
        default="utf-8-sig",
        help="CSV read encoding (default: utf-8-sig)",
    )
    args = ap.parse_args()

    with open(args.csv_path, "r", encoding=args.encoding, newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    row_count = len(rows)

    product_uid_vals = [(r.get("product_uid") or "").strip() for r in rows]
    product_uid_nonblank = [v for v in product_uid_vals if v]
    product_uid_distinct = len(set(product_uid_nonblank))
    product_uid_blank_rows = sum(1 for v in product_uid_vals if not v)

    sto_id_blank_rows = sum(1 for r in rows if _is_blank(r.get("sto_id")))
    sto_code_blank_rows = sum(1 for r in rows if _is_blank(r.get("sto_code")))
    opt_value_blank_rows = sum(1 for r in rows if _is_blank(r.get("opt_value")))
    opt_values_blank_rows = sum(1 for r in rows if _is_blank(r.get("opt_values")))

    opt_value_bracket_hits = 0
    opt_value_bracket_codes: list[str] = []
    opt_values_bracket_hits = 0
    opt_values_bracket_codes: list[str] = []

    own_sku_resolvable = 0
    own_sku_unresolvable = 0

    for r in rows:
        ov = r.get("opt_value") or ""
        ovs = r.get("opt_values") or ""

        m1 = BRACKET_RE.search(ov)
        if m1:
            opt_value_bracket_hits += 1
            opt_value_bracket_codes.append(m1.group(1))

        m2 = BRACKET_RE.search(ovs)
        if m2:
            opt_values_bracket_hits += 1
            opt_values_bracket_codes.append(m2.group(1))

        # candidate resolution chain: sto_code -> opt_value bracket -> opt_values bracket
        sto_code_val = (r.get("sto_code") or "").strip()
        if sto_code_val:
            own_sku_resolvable += 1
        elif m1:
            own_sku_resolvable += 1
        elif m2:
            own_sku_resolvable += 1
        else:
            own_sku_unresolvable += 1

    sto_counts = Counter(
        (r.get("sto_id") or "").strip()
        for r in rows
        if not _is_blank(r.get("sto_id"))
    )
    sto_dup_keys = sum(1 for c in sto_counts.values() if c > 1)
    sto_dup_rows = sum(c for c in sto_counts.values() if c > 1)

    pair_counts = Counter(
        (
            (r.get("product_uid") or "").strip(),
            (r.get("sto_id") or "").strip(),
        )
        for r in rows
        if not _is_blank(r.get("product_uid")) and not _is_blank(r.get("sto_id"))
    )
    pair_dup_keys = sum(1 for c in pair_counts.values() if c > 1)
    pair_dup_rows = sum(c for c in pair_counts.values() if c > 1)

    metrics = [
        ("row_count", row_count),
        ("product_uid_distinct", product_uid_distinct),
        ("product_uid_blank_rows", product_uid_blank_rows),
        ("sto_id_blank_rows", sto_id_blank_rows),
        ("sto_code_blank_rows", sto_code_blank_rows),
        ("opt_value_blank_rows", opt_value_blank_rows),
        ("opt_values_blank_rows", opt_values_blank_rows),
        ("opt_value_bracket_hits", opt_value_bracket_hits),
        ("opt_value_bracket_unique_codes", len(set(opt_value_bracket_codes))),
        ("opt_values_bracket_hits", opt_values_bracket_hits),
        ("opt_values_bracket_unique_codes", len(set(opt_values_bracket_codes))),
        ("own_sku_candidate_resolvable", own_sku_resolvable),
        ("own_sku_candidate_unresolvable", own_sku_unresolvable),
        ("sto_id_duplicate_keys", sto_dup_keys),
        ("sto_id_duplicate_rows", sto_dup_rows),
        ("product_sto_duplicate_keys", pair_dup_keys),
        ("product_sto_duplicate_rows", pair_dup_rows),
    ]

    width = max(len(k) for k, _ in metrics)
    print(f"=== {args.csv_path} ===")
    for k, v in metrics:
        print(f"{k.ljust(width)} : {v}")

    # Non-zero exit only if the CSV is structurally unusable.
    if row_count == 0:
        sys.stderr.write("ERROR: CSV has zero data rows\n")
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
