/*
  Postcheck Ably / PlayAuto local stage schema v1.

  Purpose:
  - Verify local product_code_stage schema and empty stage tables after apply.

  Safety:
  - SELECT-only.
  - No source file import.
  - No stage data load.
  - No code_alias changes.
  - No sku_channel_mapping changes.
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
  'local stage schema postcheck guard'::text AS note;

WITH expected_tables AS (
  SELECT *
  FROM (
    VALUES
      ('ably_playauto_source_file'),
      ('ably_raw'),
      ('playauto_product_raw'),
      ('playauto_sku_raw'),
      ('channel_option_evidence')
  ) AS t(table_name)
)
SELECT
  'schema_table_presence'::text AS section,
  e.table_name,
  CASE WHEN c.relname IS NULL THEN 'NEEDS_REVIEW' ELSE 'PASS' END AS verdict,
  c.relkind,
  'expected product_code_stage table'::text AS note
FROM expected_tables AS e
LEFT JOIN pg_namespace AS n
  ON n.nspname = 'product_code_stage'
LEFT JOIN pg_class AS c
  ON c.relnamespace = n.oid
 AND c.relname = e.table_name
 AND c.relkind IN ('r', 'p')
ORDER BY e.table_name;

SELECT
  'stage_row_count'::text AS section,
  'ably_playauto_source_file'::text AS table_name,
  COUNT(*)::bigint AS row_count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS verdict
FROM product_code_stage.ably_playauto_source_file
UNION ALL
SELECT
  'stage_row_count',
  'ably_raw',
  COUNT(*)::bigint,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'NEEDS_REVIEW' END
FROM product_code_stage.ably_raw
UNION ALL
SELECT
  'stage_row_count',
  'playauto_product_raw',
  COUNT(*)::bigint,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'NEEDS_REVIEW' END
FROM product_code_stage.playauto_product_raw
UNION ALL
SELECT
  'stage_row_count',
  'playauto_sku_raw',
  COUNT(*)::bigint,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'NEEDS_REVIEW' END
FROM product_code_stage.playauto_sku_raw
UNION ALL
SELECT
  'stage_row_count',
  'channel_option_evidence',
  COUNT(*)::bigint,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'NEEDS_REVIEW' END
FROM product_code_stage.channel_option_evidence
ORDER BY table_name;

WITH expected_columns AS (
  SELECT *
  FROM (
    VALUES
      ('ably_playauto_source_file', 'source_file_id', 'uuid'),
      ('ably_raw', 'source_file_id', 'uuid'),
      ('ably_raw', 'source_row_no', 'integer'),
      ('ably_raw', 'raw_payload', 'jsonb'),
      ('playauto_product_raw', 'source_file_id', 'uuid'),
      ('playauto_product_raw', 'source_row_no', 'integer'),
      ('playauto_product_raw', 'raw_payload', 'jsonb'),
      ('playauto_sku_raw', 'source_file_id', 'uuid'),
      ('playauto_sku_raw', 'source_row_no', 'integer'),
      ('playauto_sku_raw', 'raw_payload', 'jsonb'),
      ('channel_option_evidence', 'source_file_id', 'uuid'),
      ('channel_option_evidence', 'source_row_no', 'integer'),
      ('channel_option_evidence', 'source_option_line_no', 'integer'),
      ('channel_option_evidence', 'raw_payload', 'jsonb'),
      ('channel_option_evidence', 'channel_code', 'text'),
      ('channel_option_evidence', 'channel_product_code', 'text'),
      ('channel_option_evidence', 'channel_option_code', 'text'),
      ('channel_option_evidence', 'seller_product_code', 'text'),
      ('channel_option_evidence', 'channel_sku_code', 'text'),
      ('channel_option_evidence', 'own_sku_code_candidate', 'text'),
      ('channel_option_evidence', 'selfpia_sku_candidate', 'text'),
      ('channel_option_evidence', 'product_name', 'text'),
      ('channel_option_evidence', 'option_name', 'text'),
      ('channel_option_evidence', 'option_value', 'text'),
      ('channel_option_evidence', 'sale_status_raw', 'text'),
      ('channel_option_evidence', 'display_status_raw', 'text'),
      ('channel_option_evidence', 'option_status_raw', 'text'),
      ('channel_option_evidence', 'stock_qty_raw', 'text'),
      ('channel_option_evidence', 'normalized_sale_status', 'text'),
      ('channel_option_evidence', 'normalized_display_status', 'text'),
      ('channel_option_evidence', 'normalized_option_status', 'text'),
      ('channel_option_evidence', 'is_active_candidate', 'boolean'),
      ('channel_option_evidence', 'parse_status', 'text'),
      ('channel_option_evidence', 'reviewer_decision', 'text'),
      ('channel_option_evidence', 'export_allowed', 'boolean')
  ) AS c(table_name, column_name, expected_data_type)
)
SELECT
  'required_column_check'::text AS section,
  e.table_name,
  e.column_name,
  col.data_type,
  CASE
    WHEN col.column_name IS NULL THEN 'NEEDS_REVIEW'
    WHEN col.data_type = e.expected_data_type THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS verdict,
  concat('expected_data_type=', e.expected_data_type) AS note
FROM expected_columns AS e
LEFT JOIN information_schema.columns AS col
  ON col.table_schema = 'product_code_stage'
 AND col.table_name = e.table_name
 AND col.column_name = e.column_name
ORDER BY e.table_name, e.column_name;

SELECT
  'default_check'::text AS section,
  table_name,
  column_name,
  column_default,
  CASE
    WHEN table_name = 'channel_option_evidence'
     AND column_name = 'reviewer_decision'
     AND column_default = '''pending''::text' THEN 'PASS'
    WHEN table_name = 'channel_option_evidence'
     AND column_name = 'export_allowed'
     AND column_default = 'false' THEN 'PASS'
    WHEN column_name = 'parse_status'
     AND column_default = '''pending''::text' THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS verdict,
  'defaults should keep staged evidence pending and non-exportable'::text AS note
FROM information_schema.columns
WHERE table_schema = 'product_code_stage'
  AND (
    (table_name = 'channel_option_evidence' AND column_name IN ('reviewer_decision', 'export_allowed', 'parse_status'))
    OR (table_name IN ('ably_raw', 'playauto_product_raw', 'playauto_sku_raw') AND column_name = 'parse_status')
  )
ORDER BY table_name, column_name;

WITH expected_constraints AS (
  SELECT *
  FROM (
    VALUES
      ('ably_playauto_source_file', 'ck_ably_playauto_source_file_name_not_path'),
      ('channel_option_evidence', 'ck_channel_option_evidence_reviewer_pending'),
      ('channel_option_evidence', 'ck_channel_option_evidence_export_blocked'),
      ('channel_option_evidence', 'ck_channel_option_evidence_not_playauto_channel')
  ) AS c(table_name, constraint_name)
)
SELECT
  'constraint_check'::text AS section,
  e.table_name,
  e.constraint_name,
  pg_get_constraintdef(con.oid) AS constraint_definition,
  CASE WHEN con.oid IS NULL THEN 'NEEDS_REVIEW' ELSE 'PASS' END AS verdict,
  'required safety constraint should exist after apply'::text AS note
FROM expected_constraints AS e
LEFT JOIN pg_namespace AS n
  ON n.nspname = 'product_code_stage'
LEFT JOIN pg_class AS cls
  ON cls.relnamespace = n.oid
 AND cls.relname = e.table_name
LEFT JOIN pg_constraint AS con
  ON con.conrelid = cls.oid
 AND con.conname = e.constraint_name
ORDER BY e.table_name, e.constraint_name;

WITH expected_indexes AS (
  SELECT *
  FROM (
    VALUES
      ('ix_ably_raw_product_no'),
      ('ix_ably_raw_option_no'),
      ('ix_playauto_product_raw_account'),
      ('ix_playauto_product_raw_product_no'),
      ('ix_playauto_sku_raw_code'),
      ('ix_channel_option_evidence_source'),
      ('ix_channel_option_evidence_channel_product'),
      ('ix_channel_option_evidence_channel_option'),
      ('ix_channel_option_evidence_own_sku_candidate'),
      ('ix_channel_option_evidence_selfpia_candidate')
  ) AS i(index_name)
)
SELECT
  'index_check'::text AS section,
  e.index_name,
  CASE WHEN c.relname IS NULL THEN 'NEEDS_REVIEW' ELSE 'PASS' END AS verdict,
  pg_get_indexdef(c.oid) AS index_definition
FROM expected_indexes AS e
LEFT JOIN pg_namespace AS n
  ON n.nspname = 'product_code_stage'
LEFT JOIN pg_class AS c
  ON c.relnamespace = n.oid
 AND c.relname = e.index_name
 AND c.relkind = 'i'
ORDER BY e.index_name;

WITH checks AS (
  SELECT 'schema_exists' AS check_name, EXISTS (
    SELECT 1 FROM pg_namespace WHERE nspname = 'product_code_stage'
  ) AS passed
  UNION ALL
  SELECT 'five_tables_exist', (
    SELECT COUNT(*)
    FROM pg_namespace AS n
    JOIN pg_class AS c
      ON c.relnamespace = n.oid
    WHERE n.nspname = 'product_code_stage'
      AND c.relkind IN ('r', 'p')
      AND c.relname IN (
        'ably_playauto_source_file',
        'ably_raw',
        'playauto_product_raw',
        'playauto_sku_raw',
        'channel_option_evidence'
      )
  ) = 5
  UNION ALL
  SELECT 'stage_tables_empty',
    (SELECT COUNT(*) FROM product_code_stage.ably_playauto_source_file) = 0
    AND (SELECT COUNT(*) FROM product_code_stage.ably_raw) = 0
    AND (SELECT COUNT(*) FROM product_code_stage.playauto_product_raw) = 0
    AND (SELECT COUNT(*) FROM product_code_stage.playauto_sku_raw) = 0
    AND (SELECT COUNT(*) FROM product_code_stage.channel_option_evidence) = 0
  UNION ALL
  SELECT 'required_constraints_exist', (
    SELECT COUNT(*)
    FROM pg_constraint AS con
    JOIN pg_class AS cls
      ON cls.oid = con.conrelid
    JOIN pg_namespace AS n
      ON n.oid = cls.relnamespace
    WHERE n.nspname = 'product_code_stage'
      AND con.conname IN (
        'ck_ably_playauto_source_file_name_not_path',
        'ck_channel_option_evidence_reviewer_pending',
        'ck_channel_option_evidence_export_blocked',
        'ck_channel_option_evidence_not_playauto_channel'
      )
  ) = 4
  UNION ALL
  SELECT 'required_indexes_exist', (
    SELECT COUNT(*)
    FROM pg_namespace AS n
    JOIN pg_class AS c
      ON c.relnamespace = n.oid
    WHERE n.nspname = 'product_code_stage'
      AND c.relkind = 'i'
      AND c.relname IN (
        'ix_ably_raw_product_no',
        'ix_ably_raw_option_no',
        'ix_playauto_product_raw_account',
        'ix_playauto_product_raw_product_no',
        'ix_playauto_sku_raw_code',
        'ix_channel_option_evidence_source',
        'ix_channel_option_evidence_channel_product',
        'ix_channel_option_evidence_channel_option',
        'ix_channel_option_evidence_own_sku_candidate',
        'ix_channel_option_evidence_selfpia_candidate'
      )
  ) = 10
)
SELECT
  'overall_postcheck_verdict'::text AS section,
  CASE WHEN bool_and(passed) THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS overall_verdict,
  COUNT(*) FILTER (WHERE passed)::bigint AS passed_check_count,
  COUNT(*) FILTER (WHERE NOT passed)::bigint AS needs_review_check_count,
  string_agg(check_name, ', ' ORDER BY check_name) FILTER (WHERE NOT passed) AS needs_review_checks
FROM checks;
