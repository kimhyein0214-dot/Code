/*
  Manual review decision v2 schema postcheck.

  Purpose:
  - Verify a user-approved local schema apply after it has been executed.
  - This file does not apply schema.
  - This file does not write data.

  Scope:
  - Local product_ops_test only.
  - Production Supabase, NAS PostgreSQL, and remote DB execution are prohibited.
*/

WITH expected_columns AS (
  SELECT *
  FROM (VALUES
    ('decision_id'),
    ('review_candidate_id'),
    ('review_scope'),
    ('channel_code'),
    ('channel_product_code'),
    ('channel_option_code'),
    ('suggested_sku_id'),
    ('suggested_selfpia_sku'),
    ('decision_status'),
    ('decision_reason'),
    ('reviewer_note'),
    ('reviewer'),
    ('decided_at'),
    ('source_risk_type'),
    ('source_evidence_level'),
    ('source_suggested_action'),
    ('created_at'),
    ('updated_at')
  ) AS c(column_name)
),
column_checks AS (
  SELECT
    'required_column_' || ec.column_name AS check_name,
    EXISTS (
      SELECT 1
      FROM information_schema.columns c
      WHERE c.table_schema = 'product_code_review'
        AND c.table_name = 'manual_review_decision'
        AND c.column_name = ec.column_name
    ) AS pass,
    ec.column_name AS detail
  FROM expected_columns ec
),
checks AS (
  SELECT
    'database_guard'::text AS check_name,
    current_database() = 'product_ops_test' AS pass,
    current_database() AS detail

  UNION ALL

  SELECT
    'table_exists',
    to_regclass('product_code_review.manual_review_decision') IS NOT NULL,
    COALESCE(to_regclass('product_code_review.manual_review_decision')::text, 'missing')

  UNION ALL

  SELECT
    'decision_status_constraint_exists',
    EXISTS (
      SELECT 1
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      JOIN pg_namespace n ON n.oid = t.relnamespace
      WHERE n.nspname = 'product_code_review'
        AND t.relname = 'manual_review_decision'
        AND c.conname = 'manual_review_decision_status_chk'
        AND c.contype = 'c'
    ),
    'manual_review_decision_status_chk'

  UNION ALL

  SELECT
    'review_scope_constraint_exists',
    EXISTS (
      SELECT 1
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      JOIN pg_namespace n ON n.oid = t.relnamespace
      WHERE n.nspname = 'product_code_review'
        AND t.relname = 'manual_review_decision'
        AND c.conname = 'manual_review_decision_review_scope_chk'
        AND c.contype = 'c'
    ),
    'manual_review_decision_review_scope_chk'

  UNION ALL

  SELECT
    'write_guard_assumption',
    current_database() = 'product_ops_test',
    'API writes must still reject non-local DB/env even if this table exists.'

  UNION ALL

  SELECT
    'row_count_observable',
    to_regclass('product_code_review.manual_review_decision') IS NOT NULL,
    COALESCE((
      SELECT s.n_live_tup::text
      FROM pg_stat_user_tables s
      WHERE s.schemaname = 'product_code_review'
        AND s.relname = 'manual_review_decision'
    ), 'table missing')
),
all_checks AS (
  SELECT * FROM checks
  UNION ALL
  SELECT * FROM column_checks
),
overall AS (
  SELECT
    'OVERALL'::text AS check_name,
    bool_and(pass) AS pass,
    CASE
      WHEN bool_and(pass) THEN 'ALL PASS - local decision schema is present'
      ELSE 'FAIL - review missing schema pieces before enabling API writes'
    END AS detail
  FROM all_checks
)
SELECT
  check_name,
  CASE WHEN pass THEN 'PASS' ELSE 'FAIL' END AS verdict,
  detail
FROM (
  SELECT * FROM all_checks
  UNION ALL
  SELECT * FROM overall
) result
ORDER BY
  CASE WHEN check_name = 'OVERALL' THEN 0 ELSE 1 END,
  check_name;
