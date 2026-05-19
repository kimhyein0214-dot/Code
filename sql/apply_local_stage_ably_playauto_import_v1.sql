/*
  Apply local raw stage import for Ably / PlayAuto source files v1.

  Scope:
  - Local product_ops_test only.
  - This is the SQL workflow/template used by scripts/prepare_ably_playauto_stage_import_v1.py.
  - It inserts only into product_code_stage source/raw tables.
  - It does not COPY or \copy files.
  - It does not modify product_code.code_alias.
  - It does not modify product_code.sku_channel_mapping.
  - It does not create normalized channel_option_evidence rows in this step.

  Execution note:
  - Run the Python script with --execute so source_file_id values, file hashes, row hashes,
    raw_payload JSON, and batched VALUES inserts are generated in memory.
  - Do not paste source file paths into this SQL file.
*/

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
  'local raw stage import guard; script enforces the same guard before insert'::text AS note;

/*
Expected script transaction shape:

BEGIN;

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

-- Duplicate source-file guard unless --allow-reimport is explicitly supplied.
-- The script checks source_file_hash, not source_file_name, so renamed identical
-- files are still blocked by default.

INSERT INTO product_code_stage.ably_playauto_source_file (
  source_file_id,
  source_system,
  source_file_name,
  source_file_hash,
  source_row_count,
  source_column_count,
  source_sheet_count,
  source_note
) VALUES
  (:ably_source_file_id, 'ably_csv', :ably_source_file_name, :ably_source_file_hash, 9158, 29, 1, :ably_source_note),
  (:playauto_source_file_id, 'playauto_xlsx', :playauto_source_file_name, :playauto_source_file_hash, 4219, 95, 7, :playauto_source_note);

-- Batched INSERT ... VALUES into:
--   product_code_stage.ably_raw
--   product_code_stage.playauto_product_raw
--   product_code_stage.playauto_sku_raw
--
-- No COPY or \copy is used. raw_payload JSON and raw_row_hash are generated
-- per source row by the Python script.

-- Row-count guard before COMMIT:
--   ably_raw = 9158
--   playauto_product_raw = 4219
--   playauto_sku_raw = 17968
--   channel_option_evidence = 0 for these source_file_id values

COMMIT;
*/

WITH expected_stage_targets AS (
  SELECT *
  FROM (
    VALUES
      ('product_code_stage.ably_playauto_source_file', 'source metadata', 2),
      ('product_code_stage.ably_raw', 'Ably CSV raw rows', 9158),
      ('product_code_stage.playauto_product_raw', 'PlayAuto 쇼핑몰상품 raw rows', 4219),
      ('product_code_stage.playauto_sku_raw', 'PlayAuto SKU상품 raw rows', 17968),
      ('product_code_stage.channel_option_evidence', 'normalized evidence rows deferred in this step', 0)
  ) AS t(stage_target, purpose, expected_rows)
)
SELECT
  'raw_stage_import_plan'::text AS section,
  stage_target,
  purpose,
  expected_rows,
  CASE
    WHEN stage_target = 'product_code_stage.channel_option_evidence' THEN 'DEFERRED'
    ELSE 'READY'
  END AS import_action
FROM expected_stage_targets
ORDER BY stage_target;

WITH safety_checks AS (
  SELECT 'product_ops_test_guard' AS check_name, 'required before DML' AS check_detail
  UNION ALL SELECT 'source_file_hash_duplicate_guard', 'block identical source files by default'
  UNION ALL SELECT 'source_file_name_not_path', 'store basename only; source path is not inserted'
  UNION ALL SELECT 'source_row_no_preserved', 'first data row is source_row_no=2 because row 1 is header'
  UNION ALL SELECT 'raw_payload_jsonb_preserved', 'all original columns are retained in raw_payload'
  UNION ALL SELECT 'no_copy_or_backups', 'script does not create COPY files, exports, or backups'
  UNION ALL SELECT 'no_code_alias_or_mapping_dml', 'script does not modify code_alias or sku_channel_mapping'
  UNION ALL SELECT 'normalized_evidence_deferred', 'PlayAuto multi-line SKU/option alignment is handled in a later step'
)
SELECT
  'safety_checklist'::text AS section,
  check_name,
  check_detail,
  'PASS_REQUIRED'::text AS expected_result
FROM safety_checks
ORDER BY check_name;
