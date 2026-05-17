-- =============================================================================
-- dryrun_cleanup_smartstore_product_no_candidate_overlap.sql
--
-- LOCAL DOCKER ONLY DRYRUN.
--
-- Purpose:
--   Simulate cleanup of one redundant Smartstore productNo candidate alias that
--   overlaps an already confirmed Smartstore productNo alias for the same SKU.
--
-- Target:
--   local Docker PostgreSQL database only: product_ops_test
--
-- DO NOT run on Supabase/NAS/remote DB.
-- This script runs DELETE only inside BEGIN/ROLLBACK dryrun transaction.
-- No persistent DB changes should remain after ROLLBACK.
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'Refusing Smartstore productNo overlap cleanup dryrun on database %. Expected product_ops_test. DO NOT run on Supabase/NAS/remote DB.',
      current_database();
  END IF;
END
$$;

SELECT 'CLEANUP_TARGET_BEFORE' AS stage,
       id,
       target_type,
       target_id,
       code_system,
       code_value,
       parsed_part1,
       parsed_part2 AS option_no_from_candidate,
       is_primary,
       memo,
       raw_payload,
       created_at,
       updated_at
FROM product_code.code_alias
WHERE target_type = 'SKU'
  AND code_system = 'smartstore_product_no_candidate'
  AND target_id = 'f46f312c-4c9e-4405-a9a7-c23e1155bd31'
  AND code_value = '7577001822'
ORDER BY id;

SELECT 'CONFIRMED_COUNTERPART_BEFORE' AS stage,
       id,
       target_type,
       target_id,
       code_system,
       code_value,
       parsed_part1,
       parsed_part2 AS option_no_from_confirmed,
       is_primary,
       memo,
       raw_payload,
       created_at,
       updated_at
FROM product_code.code_alias
WHERE target_type = 'SKU'
  AND code_system = 'smartstore_product_no'
  AND target_id = 'f46f312c-4c9e-4405-a9a7-c23e1155bd31'
  AND code_value = '7577001822'
ORDER BY id;

BEGIN;

CREATE TEMP TABLE _dryrun_cleanup_target_before AS
SELECT id
FROM product_code.code_alias
WHERE target_type = 'SKU'
  AND code_system = 'smartstore_product_no_candidate'
  AND target_id = 'f46f312c-4c9e-4405-a9a7-c23e1155bd31'
  AND code_value = '7577001822';

CREATE TEMP TABLE _dryrun_confirmed_counterpart AS
SELECT id
FROM product_code.code_alias
WHERE target_type = 'SKU'
  AND code_system = 'smartstore_product_no'
  AND target_id = 'f46f312c-4c9e-4405-a9a7-c23e1155bd31'
  AND code_value = '7577001822';

CREATE TEMP TABLE _dryrun_deleted (
  id uuid PRIMARY KEY
) ON COMMIT DROP;

WITH deleted AS (
  DELETE FROM product_code.code_alias ca
  USING _dryrun_cleanup_target_before t
  WHERE ca.id = t.id
    AND (SELECT count(*) FROM _dryrun_cleanup_target_before) = 1
    AND (SELECT count(*) FROM _dryrun_confirmed_counterpart) = 1
  RETURNING ca.id
)
INSERT INTO _dryrun_deleted (id)
SELECT id FROM deleted;

WITH remaining_overlap AS (
  SELECT count(*) AS rows
  FROM (
    SELECT target_id, code_value
    FROM product_code.code_alias
    WHERE target_type = 'SKU'
      AND code_system IN ('smartstore_product_no', 'smartstore_product_no_candidate')
    GROUP BY target_id, code_value
    HAVING count(DISTINCT code_system) > 1
  ) x
),
metrics AS (
  SELECT 'cleanup_candidate_target_rows' AS metric,
         (SELECT count(*) FROM _dryrun_cleanup_target_before)::text AS actual,
         '1' AS expected,
         CASE WHEN (SELECT count(*) FROM _dryrun_cleanup_target_before) = 1 THEN 'PASS' ELSE 'FAIL' END AS verdict
  UNION ALL
  SELECT 'confirmed_counterpart_rows',
         (SELECT count(*) FROM _dryrun_confirmed_counterpart)::text,
         '1',
         CASE WHEN (SELECT count(*) FROM _dryrun_confirmed_counterpart) = 1 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL
  SELECT 'rows_deleted_in_tx',
         (SELECT count(*) FROM _dryrun_deleted)::text,
         '1',
         CASE WHEN (SELECT count(*) FROM _dryrun_deleted) = 1 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL
  SELECT 'remaining_overlap_in_tx',
         remaining_overlap.rows::text,
         '0',
         CASE WHEN remaining_overlap.rows = 0 THEN 'PASS' ELSE 'FAIL' END
  FROM remaining_overlap
)
SELECT 'DRYRUN_CLEANUP_METRIC' AS stage, metric, actual, expected, verdict
FROM metrics
UNION ALL
SELECT 'DRYRUN_CLEANUP_METRIC',
       'OVERALL',
       CASE WHEN bool_and(verdict = 'PASS') THEN 'OVERALL PASS' ELSE 'OVERALL FAIL' END,
       'OVERALL PASS',
       CASE WHEN bool_and(verdict = 'PASS') THEN 'PASS' ELSE 'FAIL' END
FROM metrics
ORDER BY metric;

ROLLBACK;

SELECT 'DRYRUN_ROLLBACK_CHECK' AS stage,
       count(*) AS cleanup_candidate_target_rows_after_rollback
FROM product_code.code_alias
WHERE target_type = 'SKU'
  AND code_system = 'smartstore_product_no_candidate'
  AND target_id = 'f46f312c-4c9e-4405-a9a7-c23e1155bd31'
  AND code_value = '7577001822';
