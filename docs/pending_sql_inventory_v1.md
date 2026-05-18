# Pending SQL Inventory v1

## 1. Purpose

This document classifies the current 8 untracked pending SQL files without executing them.

The goal is to provide a safety reference that prevents accidental `git add` of execution-oriented SQL, accidental local DB execution, and accidental operation DB execution. The files below were reviewed by reading file contents only. No SQL was executed, no DB was accessed, and no existing SQL file was modified.

## 2. File Classification

| file_path | inferred_purpose | sql_type | risk_level | contains_write_operation | contains_ddl | likely_already_applied | recommended_action | reason |
|---|---|---:|---:|---:|---:|---:|---|---|
| `sql/apply_local_data_import.sql` | Applies `stg_import_v1` staging data into `product_code.product_master`, `sku_master`, and `code_alias` using the same logic as `dryrun_local_data_import.sql`, but with `COMMIT`. | apply / import | high | yes | no persistent DDL observed | unknown | do_not_execute; review_before_any_use; keep_untracked | Contains real `INSERT INTO product_code.*` statements and a final `COMMIT`. Header says it is local Docker only and requires explicit apply approval. Apply history is not confirmed from this file alone. |
| `sql/apply_makeshop_auto_confirm_v3.sql` | Real local apply for MakeShop auto-confirm v3 candidates into `product_code.sku_channel_mapping`; expected insert rows are 11,179. | apply / import | high | yes | temp DDL only | yes | do_not_execute; commit_as_record_only or move_to_archived_sql_later | Header explicitly says it performs real inserts and commits on `product_ops_test`. The project note says the 11,179-row local apply may already be completed, so rerun would be dangerous. |
| `sql/apply_product_image_import.sql` | Local Docker apply that imports matched Selfpia image CSV rows into `product_code.product_image`; expected inserted rows are 19,331. | apply / import | high | yes | temp DDL only | yes | do_not_execute; commit_as_record_only or move_to_archived_sql_later | Contains `\copy`, candidate temp tables, `INSERT INTO product_code.product_image`, and `COMMIT`. Header requires `schema_local_patch_product_image.sql` first and stops if source rows already exist. Treat as completed-record candidate, not execution script. |
| `sql/apply_smartstore_alias_import.sql` | Local apply for Smartstore optionNo aliases into `product_code.code_alias`, inserting confirmed and candidate `smartstore_option_no` rows. | apply / import | high | yes | temp DDL only | yes | do_not_execute; commit_as_record_only or move_to_archived_sql_later | Header says `BEGIN ... COMMIT`, same insert logic as dryrun, no rollback, and no Supabase/NAS change. Contains `insert into product_code.code_alias`. Project note says optionNo local apply may already be completed. |
| `sql/apply_smartstore_product_no_import.sql` | Local real apply for Smartstore productNo aliases into `product_code.code_alias`, including confirmed and candidate productNo systems. | apply / import | high | yes | temp DDL only | yes | do_not_execute; keep_untracked; review_before_any_use | Header explicitly says local-only real apply, commits on success, and recovery requires backup restore or reviewed cleanup. Project note says productNo was already in local DB and cleanup was completed, so rerun is especially risky. |
| `sql/check_local_own_sku_coverage.sql` | Read-only local diagnostic for `own_sku` coverage and MakeShop mapping preparation. | check | low | no persistent write; `\copy` into temp table only | temp DDL only | unknown | commit_as_record_only; review_before_any_use | Header states read-only diagnostic, temp tables only, `BEGIN ... ROLLBACK`, and no persistent DB changes. Still requires explicit approval before any execution because it accesses local DB and reads CSV from `/tmp`. |
| `sql/local_schema_apply_test.sql` | Wrapper to apply `schema_nas_postgresql_draft_v2.sql` to local Docker PostgreSQL only. Includes commented destructive reset section. | schema_test | high | unknown | yes via included schema file | unknown | do_not_execute; keep_untracked; review_before_any_use | Uses `\i /sql/schema_nas_postgresql_draft_v2.sql`, so its actual DDL surface comes from the included schema file. Commented reset section contains destructive `DROP SCHEMA ... CASCADE`. It must not be rerun without explicit schema-apply approval. |
| `sql/schema_local_patch_product_image.sql` | Local Docker DDL patch to create `product_code.product_image` and related indexes for Product Management v1 image preview. | ddl_patch | high | no DML observed | yes | yes | do_not_execute; commit_as_record_only or move_to_archived_sql_later | Contains `CREATE TABLE IF NOT EXISTS product_code.product_image`, multiple indexes, and `COMMIT`. Header says draft only and requires explicit approval. Since the product image apply depends on it and may already be completed, rerun should be avoided unless schema state is verified. |

## 3. Classification Notes

- `apply_makeshop_auto_confirm_v3.sql` matches a completed local apply record candidate for MakeShop auto-confirm v3 11,179 rows. It contains real write operations and must not be executed casually.
- `apply_product_image_import.sql` matches a completed local product image import record candidate. It contains real write operations and depends on the product image schema patch.
- `apply_smartstore_alias_import.sql` matches a completed local Smartstore optionNo alias apply record candidate. It contains real writes to `product_code.code_alias`.
- `apply_smartstore_product_no_import.sql` has the highest rerun concern among the Smartstore files because productNo was reportedly already present in local DB and cleanup was completed.
- `check_local_own_sku_coverage.sql` is the only low-risk candidate after content review, but it is still not execution-free: it uses DB reads, temp tables, and `\copy`, so it requires explicit approval before use.
- `apply_local_data_import.sql` remains high risk because it contains real inserts and its local apply history is not confirmed.
- `local_schema_apply_test.sql` is a schema wrapper and includes another SQL file, so it should be treated as DDL-capable even though most destructive reset statements are commented.
- `schema_local_patch_product_image.sql` is a DDL patch and should not be rerun without checking whether `product_code.product_image` already exists.

## 4. Safety Rules

- Files with `apply`, `sql`, or `import` in the name are execution-prohibited by default until separately approved.
- Files containing DDL must not be executed before explicit user approval.
- Apply SQL that may already have been reflected in the local DB must not be rerun.
- Even SELECT-only or read-only check SQL requires separate approval before execution.
- If any SQL file is committed, document whether it is for record/archive only and not for immediate execution.
- Do not mix SQL commits with `outputs/`, `exports/`, or `backups/`.
- Do not use `git add .`.
- Do not run `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `CREATE`, `ALTER`, `DROP`, or `TRUNCATE` from these pending files without a separate, explicit execution request.
- Do not access operation Supabase, NAS, or remote DB targets for these files.

## 5. Suggested Next Actions

### Immediate Do-Not-Execute Files

- `sql/apply_local_data_import.sql`
- `sql/apply_makeshop_auto_confirm_v3.sql`
- `sql/apply_product_image_import.sql`
- `sql/apply_smartstore_alias_import.sql`
- `sql/apply_smartstore_product_no_import.sql`
- `sql/local_schema_apply_test.sql`
- `sql/schema_local_patch_product_image.sql`

### Files That May Be Reviewed for Commit Later

- `sql/check_local_own_sku_coverage.sql`: possible commit candidate as a diagnostic script if clearly labeled as approval-required.
- `sql/apply_makeshop_auto_confirm_v3.sql`: possible record-only or archive commit candidate.
- `sql/apply_product_image_import.sql`: possible record-only or archive commit candidate.
- `sql/apply_smartstore_alias_import.sql`: possible record-only or archive commit candidate.
- `sql/schema_local_patch_product_image.sql`: possible record-only or archive commit candidate if paired with a schema decision note.

### Files Requiring Delete vs Preserve Confirmation

- `sql/apply_local_data_import.sql`: preserve until local apply history is verified.
- `sql/apply_smartstore_product_no_import.sql`: preserve as evidence until productNo apply and cleanup history is fully reconciled; delete only after confirmation.
- `sql/local_schema_apply_test.sql`: preserve only if local schema rebuild workflow is still needed; otherwise consider archive or deletion after confirmation.

### Files to Consider Moving to an Archive Folder Later

- `sql/apply_makeshop_auto_confirm_v3.sql`
- `sql/apply_product_image_import.sql`
- `sql/apply_smartstore_alias_import.sql`
- `sql/schema_local_patch_product_image.sql`
- `sql/local_schema_apply_test.sql`

### Next Codex Task

1. Do not execute any pending SQL.
2. If requested, prepare a narrow git staging plan that stages only documentation or explicitly approved SQL record files.
3. Before any SQL execution request, re-open the target SQL, confirm exact DB target, classify DML/DDL, and ask for explicit approval.
4. If archiving is approved, move selected SQL files to a clearly named archive location in a separate change from exports/backups/output artifacts.
