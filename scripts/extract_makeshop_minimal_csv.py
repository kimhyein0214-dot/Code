#!/usr/bin/env python3
"""
extract_makeshop_minimal_csv.py

Extract a minimal column set from a MakeShop SpreadsheetML 2003 XML
(*.xml exported from Excel) into CSV for dryrun matching.

Source row layout
-----------------
- Row 1 : Korean human-readable header (informational only)
- Row 2 : English field-name header (used for column resolution if available)
- Row 3+: data rows

Column resolution policy
------------------------
For each output column we use, in order:
  1) FIXED_INDICES (authoritative for 8 verified columns; see below)
  2) Header match against Row 2 English names
  3) None (cell stays blank in the CSV)

Why fixed indices?
The prior implementation (header-only) silently failed because Row 1 was the
Korean header. With fixed indices in `ss:Index` (1-based) the extraction is
robust against header label changes.

FIXED_INDICES (1-based ss:Index)
  product_uid = 5
  gid         = 11
  opt_value   = 21
  opt_values  = 30
  sto_code    = 40
  sto_id      = 44
  ps_num      = 126
  barcode     = 132

`product_name` and `status` are not in FIXED_INDICES; they are resolved by
header match against Row 2 only, and may be left blank if not present.

Forward-fill
------------
Product-level columns are typically filled on the first option row of each
product and left blank for subsequent option rows. We forward-fill:
  product_uid, product_name, status, barcode, gid, ps_num
Option-level columns (sto_id, sto_code, opt_value, opt_values) are NOT filled.

Usage
-----
  python scripts/extract_makeshop_minimal_csv.py \
      --input-xml "./메이크샵_ALL_변경양식.xml" \
      --output-full outputs/makeshop_minimal_full.csv \
      --output-sample outputs/makeshop_minimal_sample100.csv \
      --sample-rows 100 \
      --debug

When --debug is set, writes:
  outputs/makeshop_extract_debug.txt
containing:
  - Row 1 (Korean) col -> value, top 140
  - Row 2 (English) col -> value, top 140
  - Rows 3-10 raw cells
  - Raw values at each FIXED_INDICES position (20 samples each)
  - product_uid pre/post forward-fill (20 samples)
  - Header-resolved column mapping (for product_name/status visibility)

Docker invocation (Linux)
-------------------------
  docker run --rm -v "${PWD}:/work" -w /work python:3.12-slim \
    python scripts/extract_makeshop_minimal_csv.py \
      --input-xml "./메이크샵_ALL_변경양식.xml" \
      --output-full "outputs/makeshop_minimal_full.csv" \
      --output-sample "outputs/makeshop_minimal_sample100.csv" \
      --sample-rows 100 \
      --debug

Constraints
-----------
- Pure stdlib (xml.etree.ElementTree, csv, argparse, sys). No lxml required.
- Streaming parse via iterparse so 102MB input is handled in bounded memory.
- No DB calls. No network. Read-only on the XML.
"""

from __future__ import annotations

import argparse
import csv
import os
import sys
from xml.etree.ElementTree import iterparse

NS = "{urn:schemas-microsoft-com:office:spreadsheet}"
ROW_TAG = f"{NS}Row"
CELL_TAG = f"{NS}Cell"
DATA_TAG = f"{NS}Data"
INDEX_ATTR = f"{NS}Index"

# Output CSV column order.
OUT_COLS = [
    "product_uid",
    "sto_id",
    "sto_code",
    "opt_value",
    "opt_values",
    "barcode",
    "product_name",
    "status",
    "gid",
    "ps_num",
]

# Verified absolute column indices in the source XML (1-based ss:Index).
# Authoritative — header match is only used to fill in product_name/status.
FIXED_INDICES: dict[str, int] = {
    "product_uid": 5,
    "gid":         11,
    "opt_value":   21,
    "opt_values":  30,
    "sto_code":    40,
    "sto_id":      44,
    "ps_num":      126,
    "barcode":     132,
}

# Columns we attempt to resolve via header match only (no fixed index).
HEADER_ONLY_COLS = {"product_name", "status"}

# Product-level: forward-fill when blank.
FORWARD_FILL = {
    "product_uid",
    "product_name",
    "status",
    "barcode",
    "gid",
    "ps_num",
}


def _cell_text(cell) -> str | None:
    data = cell.find(DATA_TAG)
    if data is None:
        return None
    txt = data.text
    if txt is None:
        return None
    txt = txt.strip()
    return txt if txt != "" else None


def _row_to_indexed_cells(row_elem) -> dict[int, str | None]:
    """Convert <Row> into {1-based col index: text-or-None}, honoring ss:Index."""
    cells: dict[int, str | None] = {}
    pos = 0
    for cell in row_elem.findall(CELL_TAG):
        idx_attr = cell.get(INDEX_ATTR)
        if idx_attr is not None:
            try:
                pos = int(idx_attr)
            except ValueError:
                pos += 1
        else:
            pos += 1
        cells[pos] = _cell_text(cell)
    return cells


def _resolve_target_indices(
    row2_cells: dict[int, str | None] | None,
) -> tuple[dict[str, int], dict[str, str]]:
    """
    Build {OUT_COL: 1-based index} for ALL output columns.

    Returns (target_indices, source_map) where source_map[col] is one of
    {'fixed', 'header', 'none'} for traceability in --debug.
    """
    name_to_idx: dict[str, int] = {}
    if row2_cells:
        for idx in sorted(row2_cells.keys()):
            name = row2_cells[idx]
            if not name:
                continue
            if name not in name_to_idx:
                name_to_idx[name] = idx

    target: dict[str, int] = {}
    source: dict[str, str] = {}
    for col in OUT_COLS:
        if col in FIXED_INDICES:
            target[col] = FIXED_INDICES[col]
            source[col] = "fixed"
        elif col in name_to_idx:
            target[col] = name_to_idx[col]
            source[col] = "header"
        else:
            source[col] = "none"
    return target, source


def _build_output_row(
    cells: dict[int, str | None],
    target_indices: dict[str, int],
    current_fill: dict[str, str],
) -> list[str]:
    out: list[str] = []
    for col in OUT_COLS:
        idx = target_indices.get(col)
        val = cells.get(idx) if idx is not None else None
        if col in FORWARD_FILL:
            if val is None or val == "":
                val = current_fill.get(col, "")
            else:
                current_fill[col] = val
        if val is None:
            val = ""
        out.append(val)
    return out


def _write_debug(
    debug_path: str,
    debug_data: dict,
    target_indices: dict[str, int],
    source_map: dict[str, str],
    written: int,
    skipped_empty: int,
    row_counter: int,
) -> None:
    os.makedirs(os.path.dirname(debug_path) or ".", exist_ok=True)
    with open(debug_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("=== MakeShop CSV Extraction DEBUG ===\n")
        f.write(f"rows_seen_total          : {row_counter}\n")
        f.write(f"data_rows_written        : {written}\n")
        f.write(f"skipped_empty_data_rows  : {skipped_empty}\n\n")

        f.write("--- Resolved target indices ---\n")
        for col in OUT_COLS:
            idx = target_indices.get(col)
            src = source_map.get(col, "?")
            f.write(f"  {col:<14}: idx={idx if idx is not None else '-'}  source={src}\n")
        f.write("\n")

        f.write("--- Row 1 (Korean header), top 140 indices ---\n")
        r1 = debug_data.get("row1_cells") or {}
        if r1:
            for idx in sorted(r1.keys())[:140]:
                f.write(f"  col {idx:>3}: {r1[idx]!r}\n")
        else:
            f.write("  (no row 1 captured)\n")
        f.write("\n")

        f.write("--- Row 2 (English field names), top 140 indices ---\n")
        r2 = debug_data.get("row2_cells") or {}
        if r2:
            for idx in sorted(r2.keys())[:140]:
                f.write(f"  col {idx:>3}: {r2[idx]!r}\n")
        else:
            f.write("  (no row 2 captured)\n")
        f.write("\n")

        f.write("--- Rows 3-10 raw cells (all indices that appeared) ---\n")
        for row_num, cells in debug_data.get("row3_10_cells", []):
            f.write(f"  row {row_num}:\n")
            for idx in sorted(cells.keys()):
                f.write(f"    col {idx:>3}: {cells[idx]!r}\n")
        f.write("\n")

        f.write("--- Fixed index raw values, first 20 data rows each ---\n")
        for col, idx in FIXED_INDICES.items():
            f.write(f"  {col} (col {idx}):\n")
            for row_num, val in debug_data.get("fixed_index_samples", {}).get(col, []):
                f.write(f"    data#{row_num:<4}: {val!r}\n")
        f.write("\n")

        f.write("--- product_uid forward-fill (first 20 data rows) ---\n")
        f.write("  data#  raw_cell  -> filled_value\n")
        for row_num, raw, filled in debug_data.get("product_uid_fill_samples", []):
            f.write(f"  {row_num:<5}  {raw!r}  ->  {filled!r}\n")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--input-xml", required=True, help="Path to MakeShop SpreadsheetML XML")
    ap.add_argument("--output-full", required=True)
    ap.add_argument("--output-sample", required=True)
    ap.add_argument(
        "--sample-rows", type=int, default=100,
        help="Number of data rows in the sample CSV (default: 100)",
    )
    ap.add_argument(
        "--encoding", default="utf-8-sig",
        help="CSV write encoding (default: utf-8-sig for Excel)",
    )
    ap.add_argument(
        "--progress-every", type=int, default=1000,
        help="Print progress every N data rows to stderr (0 disables)",
    )
    ap.add_argument(
        "--debug", action="store_true",
        help="Emit outputs/makeshop_extract_debug.txt (or --debug-path)",
    )
    ap.add_argument(
        "--debug-path", default="outputs/makeshop_extract_debug.txt",
        help="Debug output path when --debug is set",
    )
    args = ap.parse_args()

    target_indices: dict[str, int] = {}
    source_map: dict[str, str] = {}
    current_fill: dict[str, str] = {k: "" for k in FORWARD_FILL}
    sample_buf: list[list[str]] = []
    written = 0
    skipped_empty = 0
    row_counter = 0  # 1-based: counts <Row> elements seen

    debug_data: dict = {
        "row1_cells": None,
        "row2_cells": None,
        "row3_10_cells": [],
        "fixed_index_samples": {col: [] for col in FIXED_INDICES},
        "product_uid_fill_samples": [],
    }

    # Pre-resolve target indices from FIXED_INDICES only (row 2 may refine).
    target_indices, source_map = _resolve_target_indices(None)

    context = iter(iterparse(args.input_xml, events=("start", "end")))
    _, root = next(context)

    os.makedirs(os.path.dirname(args.output_full) or ".", exist_ok=True)
    os.makedirs(os.path.dirname(args.output_sample) or ".", exist_ok=True)

    with open(args.output_full, "w", encoding=args.encoding, newline="") as f_full:
        writer_full = csv.writer(f_full)
        writer_full.writerow(OUT_COLS)

        for event, elem in context:
            if event != "end" or elem.tag != ROW_TAG:
                continue

            row_counter += 1
            cells = _row_to_indexed_cells(elem)

            if row_counter == 1:
                # Korean header — informational
                if args.debug:
                    debug_data["row1_cells"] = dict(cells)
                elem.clear()
                root.clear()
                continue

            if row_counter == 2:
                # English field names — refine product_name / status via header
                target_indices, source_map = _resolve_target_indices(cells)
                if args.debug:
                    debug_data["row2_cells"] = dict(cells)
                # Note: FIXED_INDICES is authoritative; header only fills
                # product_name and status when present.
                missing_header_only = [
                    c for c in HEADER_ONLY_COLS if source_map.get(c) != "header"
                ]
                if missing_header_only:
                    sys.stderr.write(
                        f"NOTE: header did not provide {missing_header_only}; "
                        f"those columns will be blank in CSV.\n"
                    )
                elem.clear()
                root.clear()
                continue

            # Data rows (row 3+)
            if args.debug and row_counter <= 10:
                debug_data["row3_10_cells"].append((row_counter, dict(cells)))

            if args.debug:
                for col, idx in FIXED_INDICES.items():
                    bucket = debug_data["fixed_index_samples"][col]
                    if len(bucket) < 20:
                        bucket.append((row_counter, cells.get(idx)))

            # Skip completely empty rows.
            if not any(v for v in cells.values()):
                skipped_empty += 1
                elem.clear()
                root.clear()
                continue

            pre_fill_product_uid = cells.get(FIXED_INDICES["product_uid"])
            row_out = _build_output_row(cells, target_indices, current_fill)

            if args.debug and len(debug_data["product_uid_fill_samples"]) < 20:
                filled_value = row_out[OUT_COLS.index("product_uid")]
                debug_data["product_uid_fill_samples"].append(
                    (row_counter, pre_fill_product_uid, filled_value)
                )

            writer_full.writerow(row_out)
            written += 1
            if written <= args.sample_rows:
                sample_buf.append(row_out)

            if args.progress_every and written % args.progress_every == 0:
                sys.stderr.write(f"  ... {written} data rows processed\n")

            elem.clear()
            root.clear()

    with open(args.output_sample, "w", encoding=args.encoding, newline="") as f_sample:
        writer_sample = csv.writer(f_sample)
        writer_sample.writerow(OUT_COLS)
        for r in sample_buf:
            writer_sample.writerow(r)

    if args.debug:
        _write_debug(
            args.debug_path,
            debug_data,
            target_indices,
            source_map,
            written,
            skipped_empty,
            row_counter,
        )
        sys.stderr.write(f"debug log -> {args.debug_path}\n")

    sys.stderr.write(
        f"Done. full={written} rows -> {args.output_full}\n"
        f"     sample={len(sample_buf)} rows -> {args.output_sample}\n"
        f"     skipped_empty={skipped_empty}  rows_seen_total={row_counter}\n"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
