# Ably / PlayAuto Local Stage Import Runbook v1

## Purpose

This runbook describes the future local-only workflow for staging Ably and PlayAuto source evidence before candidate generation.

This is not an execution approval. Do not run the schema draft, do not import files, do not apply mappings, and do not connect to operating Supabase, NAS PostgreSQL, or any remote database during this step.

## Inputs

Previously analyzed source files:

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
  - `877` distinct nonblank PlayAuto Ably `쇼핑몰 상품번호`
  - `875` overlap with Ably CSV `상품 번호`

## New Draft Files

- `sql/schema_local_stage_ably_playauto_draft_v1.sql`
- `sql/local_stage_ably_playauto_import_workflow_draft_v1.sql`
- `sql/validate_local_stage_ably_playauto_import_v1.sql`

All SQL files are drafts. They are not approved to run yet.

## Stage Schema Summary

Schema draft uses a local-only schema:

- `product_code_stage`

Raw preservation layer:

- `product_code_stage.ably_playauto_source_file`
- `product_code_stage.ably_raw`
- `product_code_stage.playauto_product_raw`
- `product_code_stage.playauto_sku_raw`

Normalized option-level evidence:

- `product_code_stage.channel_option_evidence`

The normalized evidence table keeps:

- `source_file_id`
- `source_file_name` through source-file relation
- `source_sheet_name`
- `source_row_no`
- `source_option_line_no`
- `channel_code`
- `channel_account`
- `channel_product_code`
- `channel_option_code`
- `seller_product_code`
- `channel_sku_code`
- `own_sku_code_candidate`
- `selfpia_sku_candidate`
- `product_name`
- `option_name`
- `option_value`
- `sale_status_raw`
- `display_status_raw`
- `option_status_raw`
- `stock_qty_raw`
- normalized status fields
- `is_active_candidate`
- `raw_payload`
- `parse_status`
- `parse_warning`
- `reviewer_decision='pending'`
- `export_allowed=false`
- `created_at`

## Ably Mapping

| Ably column | stage field | note |
|---|---|---|
| `상품 번호` | `channel_product_code` | required product-level channel code |
| `옵션 번호` | `channel_option_code` | required option-level channel code |
| `판매자 상품코드` | `seller_product_code` | product-level candidate, not SKU-safe alone |
| `솔루션사 고유코드` | `own_sku_code_candidate` or evidence candidate | must join uniquely before use |
| `상품명` | `product_name` | support only |
| `옵션1`, `옵션2`, `전체 옵션명` | `option_name`, `option_value`, candidate code extraction | support and bracket-code evidence |
| `재고수량` | `stock_qty_raw` | status/inventory support |
| `품절상태` | `sale_status_raw` / `option_status_raw` | inactive split |
| `진열상태` | `display_status_raw` | hidden split |

## PlayAuto Mapping

| PlayAuto column | stage field | note |
|---|---|---|
| `쇼핑몰(계정)` | `channel_code`, `channel_account` | split before matching |
| `판매자관리코드` | `seller_product_code` | source product code candidate |
| `온라인 상품명` | `product_name` | support only |
| `쇼핑몰 상품번호` | `channel_product_code` | required for active marketplace rows |
| `옵션` | `option_name` | multi-line text evidence |
| `SKU` | `channel_sku_code`, `own_sku_code_candidate` | multi-line code evidence |
| `상품상태(수정불가)` | `sale_status_raw` | active/inactive/pending split |
| `옵션 상태` | `option_status_raw` | multi-line Y/N option status |

## PlayAuto Channel Branching

Never store PlayAuto rows as final `channel_code='playauto'`.

| `쇼핑몰(계정)` | `channel_code` | `channel_account` |
|---|---|---|
| `스마트스토어=w_ground` | `smartstore` | `w_ground` |
| `에이블리=pink_rocket@naver.com` | `ably` | `pink_rocket@naver.com` |
| `쿠팡=wworks2010` | `coupang` | `wworks2010` |
| `카카오톡 스토어=pink_rocket@naver.com` | `kakaotalk_store` | `pink_rocket@naver.com` |

Unknown account strings must be blocked as `parse_status='warning'` or `parse_status='error'`.

## PlayAuto Multi-Line Handling

PlayAuto `옵션`, `SKU`, `옵션 추가금액`, `옵션 판매수량`, `출고수량`, and `옵션 상태` can contain line-delimited arrays.

Draft rule:

- split by CRLF, LF, or CR
- preserve `source_row_no`
- assign `source_option_line_no`
- allow `옵션` to have the same line count as `SKU`, or one additional header/group line
- after optional header removal, `SKU`, option status, price, quantity, and outbound quantity line counts must align
- validate exploded `SKU` against `SKU상품.SKU코드`
- unaligned rows are blocked from auto-confirm

## Execution Sequence

A. Schema draft review

- Review `sql/schema_local_stage_ably_playauto_draft_v1.sql`.
- Confirm local-only schema name and table names.
- Confirm no conflict with existing local schemas.

B. Local schema apply dryrun

- Prepare a separate migration dryrun if approved later.
- This current task does not run DDL.

C. Source file staging preparation

- Confirm source file hashes, row counts, and column counts.
- Keep original CSV/XLSX out of git.
- Do not copy source files to `outputs/`, `exports/`, or `backups/`.

D. Import dryrun

- Use the workflow draft to verify parsing assumptions.
- Confirm PlayAuto multi-line behavior with sample rows.
- Confirm channel branching.

E. Local stage import

- Only after explicit approval.
- Local `product_ops_test` only.
- Keep all candidates pending and non-exportable.

F. Validation

- Run `sql/validate_local_stage_ably_playauto_import_v1.sql` after local stage import.
- Check row counts, required non-null fields, uniqueness, duplicates, channel distribution, status split, PlayAuto SKU explode, and Ably/PlayAuto overlap.

G. Code evidence inspection

- Join staged evidence to `product_code.code_alias` and `product_code.sku_channel_mapping`.
- Classify direct, unique, duplicate, missing, and inactive evidence.

H. Unique evidence dryrun

- Generate SELECT-only candidate rows.
- Do not apply.

I. Sample review

- Review direct/unique candidates and blockers.
- Confirm no confirmed/manual mappings would be overwritten.

J. Local apply

- Only after sample review and explicit approval.

K. Postcheck

- Verify row counts, matching rate movement, duplicate blockers, and inactive buckets.

## Validation Checklist

After future local stage import, validation must check:

- source file row counts
- raw row counts
- normalized option-level row counts
- required canonical fields
- channel distribution
- channel account distribution
- active/inactive split
- option-level uniqueness
- duplicate source row keys
- Ably product number and PlayAuto Ably product number overlap
- PlayAuto SKU explode row counts
- PlayAuto SKU dictionary coverage
- `parse_status`
- `reviewer_decision='pending'`
- `export_allowed=false`
- possible conflicts with existing `code_alias`
- possible conflicts with existing `sku_channel_mapping`

## Safety Rules

- No operating Supabase access.
- No NAS PostgreSQL access.
- No remote DB access.
- No DB execution in this task.
- No DB changes in this task.
- No DDL execution in this task.
- No source file import/export in this task.
- No original CSV/XLSX edits.
- No original CSV/XLSX git add.
- No `outputs/`, `exports/`, or `backups/` add.
- No confirmed/manual mapping overwrite.
- No `git add .`.

## Completion Report Template

1. Created/modified files
2. SQL static review result
3. DB execution status
4. Stage schema draft summary
5. Import workflow draft summary
6. Validation SQL summary
7. PlayAuto multi-line handling
8. Channel branching
9. Next step proposal
10. Commit hash
11. Push status
12. `git status -s`
13. Safety confirmation
