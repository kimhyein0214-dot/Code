/*
  Manual review decision v2 schema dry-run.

  Purpose:
  - Verify that the local decision schema can be created.
  - Run inside a transaction and ROLLBACK.
  - This file is for local product_ops_test only.

  Prohibited:
  - Production Supabase execution.
  - NAS PostgreSQL execution.
  - Remote DB execution.
  - Treating this dry-run as an apply.
*/

BEGIN;

WITH guard AS (
  SELECT
    current_database() AS current_database,
    current_user AS current_user,
    CASE
      WHEN current_database() = 'product_ops_test'
      THEN true
      ELSE false
    END AS database_guard_pass
)
SELECT
  'guard_database'::text AS check_name,
  CASE WHEN database_guard_pass THEN 'PASS' ELSE 'FAIL' END AS verdict,
  current_database AS detail
FROM guard;

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION 'STOP: manual_review_decision dry-run is local-only and requires product_ops_test, got %', current_database();
  END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS product_code_review;

CREATE TABLE product_code_review.manual_review_decision (
  decision_id uuid PRIMARY KEY,
  review_candidate_id text NOT NULL,
  review_scope text NOT NULL,
  channel_code text NOT NULL,
  channel_product_code text,
  channel_option_code text,
  suggested_sku_id uuid,
  suggested_selfpia_sku text,
  decision_status text NOT NULL,
  decision_reason text,
  reviewer_note text,
  reviewer text NOT NULL,
  decided_at timestamptz NOT NULL DEFAULT now(),
  source_risk_type text,
  source_evidence_level text,
  source_suggested_action text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT manual_review_decision_review_scope_chk
    CHECK (review_scope IN (
      'manual_matching_candidate',
      'deletion_or_inactive_review_candidate'
    )),

  CONSTRAINT manual_review_decision_status_chk
    CHECK (decision_status IN (
      'approve_match',
      'hold',
      'exclude_candidate',
      'inactive_reviewed',
      'needs_source_fix'
    )),

  CONSTRAINT manual_review_decision_scope_status_chk
    CHECK (
      (review_scope = 'manual_matching_candidate'
        AND decision_status IN (
          'approve_match',
          'hold',
          'exclude_candidate',
          'needs_source_fix'
        ))
      OR
      (review_scope = 'deletion_or_inactive_review_candidate'
        AND decision_status IN (
          'hold',
          'exclude_candidate',
          'inactive_reviewed',
          'needs_source_fix'
        ))
    ),

  CONSTRAINT manual_review_decision_candidate_unique
    UNIQUE (review_candidate_id)
);

CREATE INDEX manual_review_decision_status_idx
  ON product_code_review.manual_review_decision (decision_status);

CREATE INDEX manual_review_decision_scope_idx
  ON product_code_review.manual_review_decision (review_scope);

CREATE INDEX manual_review_decision_channel_idx
  ON product_code_review.manual_review_decision (channel_code);

CREATE INDEX manual_review_decision_decided_at_idx
  ON product_code_review.manual_review_decision (decided_at DESC);

WITH checks AS (
  SELECT
    'database_guard'::text AS check_name,
    current_database() = 'product_ops_test' AS pass,
    current_database() AS detail

  UNION ALL

  SELECT
    'table_can_be_created',
    to_regclass('product_code_review.manual_review_decision') IS NOT NULL,
    COALESCE(to_regclass('product_code_review.manual_review_decision')::text, 'missing')

  UNION ALL

  SELECT
    'decision_status_check_exists',
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
    'review_scope_check_exists',
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
    'scope_status_check_exists',
    EXISTS (
      SELECT 1
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      JOIN pg_namespace n ON n.oid = t.relnamespace
      WHERE n.nspname = 'product_code_review'
        AND t.relname = 'manual_review_decision'
        AND c.conname = 'manual_review_decision_scope_status_chk'
        AND c.contype = 'c'
    ),
    'manual_review_decision_scope_status_chk'

  UNION ALL

  SELECT
    'rollback_expected',
    true,
    'This dry-run ends with ROLLBACK; no schema should persist.'
),
overall AS (
  SELECT
    'OVERALL'::text AS check_name,
    bool_and(pass) AS pass,
    CASE
      WHEN bool_and(pass) THEN 'ALL PASS - draft can be considered for local apply after user approval'
      ELSE 'FAIL - do not apply'
    END AS detail
  FROM checks
)
SELECT
  check_name,
  CASE WHEN pass THEN 'PASS' ELSE 'FAIL' END AS verdict,
  detail
FROM (
  SELECT * FROM checks
  UNION ALL
  SELECT * FROM overall
) result
ORDER BY
  CASE WHEN check_name = 'OVERALL' THEN 0 ELSE 1 END,
  check_name;

ROLLBACK;
