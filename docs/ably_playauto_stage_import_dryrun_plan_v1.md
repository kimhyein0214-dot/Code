# Ably / PlayAuto Stage Import Dryrun Plan v1

## Purpose

This step designs the dryrun checks needed before loading Ably and PlayAuto source evidence into local DB stage tables.

This is not an import step. It does not create stage tables, does not load CSV/XLSX content, does not modify local DB data, and does not connect to operating Supabase, NAS PostgreSQL, or any remote DB.

## Scope

Inputs already analyzed:

- Ably CSV: `9,158` rows, `29` columns
- PlayAuto XLSX:
  - `쇼핑몰상품`: `4,219` rows, `95` columns
  - `SKU상품`: `17,968` rows, `4` columns
- PlayAuto account distribution:
  - `스마트스토어=w_ground`: `2,039`
  - `에이블리=pink_rocket@naver.com`: `2,016`
  - `쿠팡=wworks2010`: `161`
  - `카카오톡 스토어=pink_rocket@naver.com`: `3`
- PlayAuto Ably relationship:
  - PlayAuto Ably rows have `877` distinct nonblank `쇼핑몰 상품번호`
  - `875` overlap with Ably CSV `상품 번호`

## Recommended Stage Structure

Use two layers.

### Raw Preservation Layer

Purpose:

- preserve every source row exactly as received
- retain source filename, source sheet, row number, and raw JSON payload
- make the import auditable without using raw files as DB identity

Conceptual fields:

| field | purpose |
|---|---|
| `source_file_id` | stable identifier for one imported source file batch |
| `source_system` | `ably_csv` or `playauto_xlsx` |
| `source_file_name` | basename only |
| `source_sheet_name` | sheet name, or `csv` for Ably |
| `source_row_no` | row number in the source |
| `raw_payload` | full source row as structured payload |
| `raw_row_hash` | duplicate detection across repeated imports |
| `collected_at` | source collection/import timestamp |
| `parse_status` | `pending`, `ok`, `warning`, `error` |
| `parse_warning` | parse warning text |

### Normalized Option-Level Stage

Purpose:

- one row per channel option/SKU evidence item
- expose canonical matching fields independent of source layout
- classify active/inactive, duplicate, and evidence-missing rows before auto-match

Conceptual fields:

| field | purpose |
|---|---|
| `source_file_id` | batch identifier |
| `source_row_no` | raw row reference |
| `source_option_line_no` | line number after PlayAuto option/SKU explode |
| `source_system` | `ably_csv` or `playauto_xlsx` |
| `channel_code` | actual marketplace channel |
| `channel_account` | marketplace account/store identifier |
| `channel_product_code` | marketplace product code |
| `channel_option_code` | marketplace option code where available |
| `seller_product_code` | seller/source product code |
| `channel_sku_code` | source SKU or channel SKU code |
| `own_sku_code` | own_sku evidence candidate |
| `selfpia_sku_code` | selfpia_sku evidence candidate |
| `product_name` | source product name |
| `option_name` | source option name |
| `option_value` | normalized option value |
| `sale_status` | source sale status |
| `display_status` | source display status |
| `stock_status` | source stock/option active status |
| `stock_qty` | parsed stock quantity |
| `evidence_status` | direct, unique, duplicate, missing, inactive |
| `export_allowed` | always false during dryrun |
| `reviewer_decision` | always pending during dryrun |

## Ably Canonical Mapping

| Ably source column | canonical field | dryrun rule |
|---|---|---|
| `상품 번호` | `channel_product_code` | required, nonblank, product-level identity |
| `옵션 번호` | `channel_option_code` | required, nonblank, unique option-level identity |
| `판매자 상품코드` | `seller_product_code` | normalize blanks/dashes; product-level evidence only |
| `솔루션사 고유코드` | `own_sku_code` or evidence candidate | join to `selfpia_sku` / `own_sku` only after uniqueness check |
| `옵션1` | `option_value` / option text evidence | extract bracket codes as candidates |
| `옵션2` | `option_value` / option text evidence | support evidence only |
| `전체 옵션명` | `option_name` / option text evidence | support evidence and bracket-code source |
| `재고수량` | `stock_qty` | numeric parse and active/inactive support |
| `품절상태` | `stock_status` / `sale_status` | bucket `품절` separately |
| `진열상태` | `display_status` | bucket `미진열` separately |

Ably import preconditions:

- `상품 번호` and `옵션 번호` must both be present.
- `옵션 번호` must be unique within the source batch.
- `상품 번호 + 옵션 번호` must be unique.
- rows with `품절` or `미진열` should be classified as inactive/channel-absent before unmatched counting.
- `판매자 상품코드` must not be treated as a SKU-level identity by itself.
- `솔루션사 고유코드` and bracket codes are candidate evidence until they join uniquely.

## PlayAuto Canonical Mapping

| PlayAuto source column | canonical field | dryrun rule |
|---|---|---|
| `쇼핑몰(계정)` | `channel_code`, `channel_account` | split into actual marketplace and account before matching |
| `판매자관리코드` | `seller_product_code` or source product code | source/product-level code candidate |
| `쇼핑몰 상품번호` | `channel_product_code` | marketplace product code; may be blank for pending rows |
| `SKU` | exploded `channel_sku_code`, `own_sku_code` evidence candidate | explode multi-line values and validate against `SKU상품.SKU코드` |
| `옵션` | `option_name` / option text evidence | explode and align with SKU/status lines |
| `온라인 상품명` | `product_name` | support evidence only |
| `상품상태(수정불가)` | `sale_status` | active/inactive/pending classifier |
| `옵션 상태` | `stock_status` | explode multi-line `Y`/`N` option flags |
| `SKU상품.SKU코드` | SKU dictionary code | validates main-sheet `SKU` line values |
| `SKU상품.속성` | option value support | text support for exploded SKU evidence |

PlayAuto import preconditions:

- Do not set `channel_code='playauto'` for final marketplace mappings.
- `쇼핑몰(계정)` must map to one of `ably`, `smartstore`, `coupang`, or `kakaotalk_store` before candidate generation.
- Unknown account strings must be `NEEDS_REVIEW`.
- `SKU`, `옵션 상태`, option prices, option quantities, and shipment quantities must align after line explosion.
- `옵션` may contain a header/group line and may have one more line than `SKU`; dryrun must explicitly handle or flag this.
- `쇼핑몰 상품번호` blanks must be evaluated with `상품상태(수정불가)` before being treated as missing evidence.
- `판매대기`, `수정대기`, `승인대기`, `일시품절`, and `판매중지` should be separated from active unmatched rows.

## Import Pre-Check Checklist

Before any real local stage import:

- Confirm target DB is `product_ops_test`.
- Confirm execution is local-only and reviewed.
- Confirm the source file hash, row count, and column count.
- Confirm a `source_file_id` exists for each file/batch.
- Confirm source rows are not copied to `outputs/`, `exports/`, or `backups/`.
- Confirm canonical field names and nullability expectations.
- Confirm PlayAuto account mapping rules.
- Confirm Ably `상품 번호 + 옵션 번호` uniqueness.
- Confirm PlayAuto option/SKU line-alignment rules.
- Confirm inactive/channel-absent status rules.
- Confirm duplicate source row keys:
  - Ably: `source_file_id + channel_product_code + channel_option_code`
  - PlayAuto: `source_file_id + channel_code + channel_account + seller_product_code + source_option_line_no`
- Confirm no source evidence overwrites existing confirmed/manual mappings.
- Confirm all candidates default to `export_allowed=false` and `reviewer_decision='pending'`.

## Post-Import Candidate Flow

After a future local stage import, candidate generation should classify rows in this order.

### Direct Evidence

Rows with a source code that joins directly and uniquely to one local `sku_id`.

Examples:

- source selfpia-like code matches one `code_alias(code_system='selfpia_sku')`
- source own_sku-like code matches one `code_alias(code_system='own_sku')`
- existing confirmed `sku_channel_mapping` already has the same identity for the same `sku_id`

### Unique Evidence

Rows with one source option identity, one candidate local `sku_id`, one channel product/option identity, compatible product/option text, and no conflict.

### Duplicate Evidence

Rows where a source code maps to multiple SKU targets, one channel code maps to multiple source rows unexpectedly, or PlayAuto line alignment is ambiguous.

### Evidence Missing

Rows where no usable code evidence exists after normalization. Product/option names alone are not enough.

### Channel Absent Or Inactive

Rows that are hidden, sold out, pending, paused, waiting for approval, stopped, or option-inactive. These should not be counted as true active-channel unmatched rows.

## Manual Review Reduction Principle

Reduce automatically before sending to the manual review frontend:

- separate inactive/channel-absent rows first
- remove exact duplicate source evidence
- require code evidence before text support
- validate PlayAuto `SKU` against `SKU상품`
- block multi-target own_sku conflicts
- block source rows with parse warnings
- group missing product numbers by channel status
- keep candidate rows non-exportable until reviewed

## Dryrun SQL

The companion SQL file is:

- `sql/dryrun_ably_playauto_stage_import_v1.sql`

It is a SELECT-only dryrun design script. It checks local schema readiness, outputs canonical fields and validation rules, and reports `PASS` / `NEEDS_REVIEW` style verdicts. It does not read source files and does not import data.

## Next Steps

A. Actual local stage table and seed SQL design

B. Local stage import dryrun

C. Local stage import

D. Code evidence inspection

E. Unique evidence dryrun

F. Sample review

G. Local apply

H. Postcheck

## Completion Report Template

Report:

1. Created/modified files
2. SQL static review result
3. Local DB read-only execution status
4. Stage canonical field summary
5. Ably pre-import required checks
6. PlayAuto pre-import required checks
7. Existing schema / `code_alias` / `sku_channel_mapping` conflict risk
8. Dryrun design verdict
9. Next step proposal
10. Commit hash
11. Push status
12. `git status -s`
13. Safety confirmation
