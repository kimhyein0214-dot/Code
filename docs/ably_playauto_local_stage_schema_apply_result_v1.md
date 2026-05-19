# Ably / PlayAuto Local Stage Schema Apply Result v1

## Purpose

This document records the local-only stage schema apply for Ably / PlayAuto source evidence.

This step created empty local stage tables only. No Ably CSV or PlayAuto XLSX source file was imported. No automatic matching apply was executed. No operating Supabase, NAS PostgreSQL, or remote database was used.

## Files

Created in this step:

- `sql/apply_schema_local_stage_ably_playauto_v1.sql`
- `sql/postcheck_schema_local_stage_ably_playauto_v1.sql`
- `docs/ably_playauto_local_stage_schema_apply_result_v1.md`

Input drafts:

- `sql/schema_local_stage_ably_playauto_draft_v1.sql`
- `sql/dryrun_schema_local_stage_ably_playauto_v1.sql`
- `docs/ably_playauto_local_stage_schema_dryrun_result_v1.md`

## Apply Execution

Target:

- database: `product_ops_test`
- user: `product_ops_tester`

Guard:

| check | result |
|---|---|
| `current_database()` | `product_ops_test` |
| `current_user` | `product_ops_tester` |
| guard result | `PASS` |

The apply created `product_code_stage` and the five stage tables. It did not load source data.

## Created Objects

Schema:

- `product_code_stage`

Tables:

| table | postcheck |
|---|---|
| `product_code_stage.ably_playauto_source_file` | PASS |
| `product_code_stage.ably_raw` | PASS |
| `product_code_stage.playauto_product_raw` | PASS |
| `product_code_stage.playauto_sku_raw` | PASS |
| `product_code_stage.channel_option_evidence` | PASS |

## Row Counts

All stage tables are empty after schema apply.

| table | row count | result |
|---|---:|---|
| `ably_playauto_source_file` | 0 | PASS |
| `ably_raw` | 0 | PASS |
| `playauto_product_raw` | 0 | PASS |
| `playauto_sku_raw` | 0 | PASS |
| `channel_option_evidence` | 0 | PASS |

## Column Checks

Postcheck verified required traceability and normalized evidence columns:

- `source_file_id`
- `source_row_no`
- `source_option_line_no`
- `raw_payload jsonb`
- `channel_code`
- `channel_product_code`
- `channel_option_code`
- `seller_product_code`
- `channel_sku_code`
- `own_sku_code_candidate`
- `selfpia_sku_candidate`
- product / option text fields
- raw and normalized status fields
- `is_active_candidate`
- `parse_status`
- `reviewer_decision`
- `export_allowed`

Column check result: `PASS`

## Defaults

| table | column | default | result |
|---|---|---|---|
| `ably_raw` | `parse_status` | `'pending'::text` | PASS |
| `playauto_product_raw` | `parse_status` | `'pending'::text` | PASS |
| `playauto_sku_raw` | `parse_status` | `'pending'::text` | PASS |
| `channel_option_evidence` | `parse_status` | `'pending'::text` | PASS |
| `channel_option_evidence` | `reviewer_decision` | `'pending'::text` | PASS |
| `channel_option_evidence` | `export_allowed` | `false` | PASS |

## Constraints

| constraint | purpose | result |
|---|---|---|
| `ck_ably_playauto_source_file_name_not_path` | blocks source file path storage | PASS |
| `ck_channel_option_evidence_reviewer_pending` | keeps staged evidence pending | PASS |
| `ck_channel_option_evidence_export_blocked` | keeps staged evidence non-exportable | PASS |
| `ck_channel_option_evidence_not_playauto_channel` | blocks `channel_code='playauto'` | PASS |

## Indexes

All ten expected indexes exist:

- `ix_ably_raw_product_no`
- `ix_ably_raw_option_no`
- `ix_playauto_product_raw_account`
- `ix_playauto_product_raw_product_no`
- `ix_playauto_sku_raw_code`
- `ix_channel_option_evidence_source`
- `ix_channel_option_evidence_channel_product`
- `ix_channel_option_evidence_channel_option`
- `ix_channel_option_evidence_own_sku_candidate`
- `ix_channel_option_evidence_selfpia_candidate`

Index check result: `PASS`

## Postcheck Verdict

`overall_postcheck_verdict = PASS`

Summary:

- schema exists
- five tables exist
- all stage tables are empty
- required constraints exist
- required indexes exist
- `needs_review_check_count = 0`

## Interpretation

The local stage schema is ready for the next stage: local source-file stage import design/execution, after user approval.

The next step should not apply channel mappings. It should only register source file metadata, load raw rows into the local stage tables, normalize option-level evidence, and run validation.

## Safety Notes

- Operating Supabase was not accessed.
- NAS PostgreSQL was not accessed.
- No remote DB was accessed.
- Only local `product_ops_test` was used.
- No source CSV/XLSX was imported.
- No source CSV/XLSX was modified.
- No source CSV/XLSX was added to git.
- No import/export artifact was generated.
- `product_code.code_alias` was not changed.
- `product_code.sku_channel_mapping` was not changed.
- Existing confirmed/manual mappings were not touched.
