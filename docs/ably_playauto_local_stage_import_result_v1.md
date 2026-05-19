# Ably / PlayAuto Local Stage Import Result v1

## Scope

This document records the local raw stage import result for Ably and PlayAuto source files.

This step is local-stage-only:

- No operating Supabase access.
- No NAS PostgreSQL access.
- No remote DB access.
- No automatic matching apply.
- No `product_code.code_alias` change.
- No `product_code.sku_channel_mapping` change.
- No source CSV/XLSX modification.
- No source CSV/XLSX git add.
- No export/backup copy creation.

## Source Files

| Source | File name | Expected rows | Stage target |
|---|---:|---:|---|
| Ably CSV | `에이블리 ALL.csv` | 9,158 | `product_code_stage.ably_raw` |
| PlayAuto XLSX / 쇼핑몰상품 | `플레이오토_일반_ALL판매처 (판매중,수정대기,판매대기 ALL).xlsx` | 4,219 | `product_code_stage.playauto_product_raw` |
| PlayAuto XLSX / SKU상품 | `플레이오토_일반_ALL판매처 (판매중,수정대기,판매대기 ALL).xlsx` | 17,968 | `product_code_stage.playauto_sku_raw` |

Source paths are kept outside the repository under `..\기타`. The stage metadata table stores only each basename and hash, not the full local path.

## Execution Result

Status: executed on local `product_ops_test` only.

Execution:

- Dry summary: PASS.
- Raw stage import: PASS.
- Postcheck SQL: PASS.
- Guard result: `current_database=product_ops_test`, `current_user=product_ops_tester`.
- Import transaction: COMMIT completed for raw stage tables only.

Expected raw-stage outcome:

| Table | Expected count | Actual count | Verdict |
|---|---:|---:|---|
| `product_code_stage.ably_playauto_source_file` | 2 new rows | 2 latest source rows | PASS |
| `product_code_stage.ably_raw` | 9,158 | 9,158 | PASS |
| `product_code_stage.playauto_product_raw` | 4,219 | 4,219 | PASS |
| `product_code_stage.playauto_sku_raw` | 17,968 | 17,968 | PASS |
| `product_code_stage.channel_option_evidence` | 0 | 0 | PASS |

Latest source metadata:

| Source system | Source file hash prefix | Rows | Columns | Sheets | Verdict |
|---|---:|---:|---:|---:|---|
| `ably_csv` | `619c1edf544553dd` | 9,158 | 29 | 1 | PASS |
| `playauto_xlsx` | `ec3d60baa7cfcac7` | 4,219 | 95 | 7 | PASS |

## Import Behavior

The import is prepared by `scripts/prepare_ably_playauto_stage_import_v1.py`.

- Ably CSV is read with encoding fallback: `utf-8-sig`, `cp949`, then `utf-8`.
- PlayAuto XLSX reads the explicit sheets `쇼핑몰상품` and `SKU상품`.
- `source_row_no` preserves the source worksheet/file row number, with the first data row stored as `2` because row `1` is the header.
- `raw_payload` preserves every original column as JSONB.
- `raw_row_hash` is computed from the full source row payload.
- Duplicate identical source files are blocked by `source_file_hash` unless `--allow-reimport` is explicitly used.
- The script performs batched `INSERT ... VALUES` through the local Docker PostgreSQL service; it does not use `COPY` or `\copy`.

## Normalized Evidence

Normalized evidence generation is deferred.

Reason:

- PlayAuto `SKU` and `옵션` can contain multi-line values.
- Those lines must be exploded and alignment-checked before creating option-level evidence.
- `channel_code` must be derived from `쇼핑몰(계정)`, not stored as `playauto`.
- The raw import is sufficient for the next evidence-inspection step without risking premature matching evidence.

Expected current state:

- `product_code_stage.channel_option_evidence` remains empty for these source files.
- `reviewer_decision='pending'` and `export_allowed=false` remain enforced for the future normalized layer.

## Validation Summary

Postcheck SQL: `sql/postcheck_local_stage_ably_playauto_import_v1.sql`

PASS checks:

- Local guard: `current_database() = 'product_ops_test'`.
- Local guard: `current_user = 'product_ops_tester'`.
- Latest Ably source metadata exists with `9,158` rows and `29` columns.
- Latest PlayAuto source metadata exists with `4,219` 쇼핑몰상품 rows, `95` columns, and `7` sheets.
- `ably_raw` latest source count is `9,158`.
- `playauto_product_raw` latest source count is `4,219`.
- `playauto_sku_raw` latest source count is `17,968`.
- `channel_option_evidence` count for latest source files is `0`.
- Required raw columns are non-null.
- `source_row_no` is unique within each raw table/source.
- `raw_payload` is non-empty.
- No Ably/PlayAuto rows are created in `product_code.code_alias`.
- No Ably/PlayAuto rows are created in `product_code.sku_channel_mapping`.
- Overall import postcheck verdict: PASS, `passed_check_count=7`, `needs_review_check_count=0`.

PlayAuto mall account distribution after import:

| Mall account | Row count |
|---|---:|
| `스마트스토어=w_ground` | 2,039 |
| `에이블리=pink_rocket@naver.com` | 2,016 |
| `쿠팡=wworks2010` | 161 |
| `카카오톡 스토어=pink_rocket@naver.com` | 3 |

## Issues / Notes

- This stage import intentionally does not create automatic matching candidates yet.
- The next step should transform raw PlayAuto rows into option-level rows only after validating SKU/option multi-line alignment.
- PlayAuto must branch by `쇼핑몰(계정)` into actual channel codes such as `ably`, `smartstore`, `coupang`, and `kakaotalk_store`.
- The source files were read but not modified, copied, exported, or added to git.
- `product_code.code_alias` and `product_code.sku_channel_mapping` remained unchanged for Ably/PlayAuto evidence: both checked as `0` rows.

## Next Steps

A) Generate normalized `channel_option_evidence` from raw stage rows.

B) Inspect code evidence against `sku_master`, `product_master`, `code_alias`, and `sku_channel_mapping`.

C) Run unique evidence dryrun.

D) Review samples before local apply.

E) Apply only approved local matching changes.

F) Run postcheck.
