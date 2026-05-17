-- =============================================================================
-- postcheck_cleanup_smartstore_product_no_candidate_overlap.sql
--
-- LOCAL DOCKER ONLY POSTCHECK.
--
-- Purpose:
--   Verify the local cleanup result for one redundant Smartstore productNo
--   candidate alias after apply_cleanup_smartstore_product_no_candidate_overlap.
--
-- Target:
--   local Docker PostgreSQL database only: product_ops_test
--
-- DO NOT run on Supabase/NAS/remote DB.
-- SELECT-only. No INSERT/UPDATE/DELETE/DDL/COMMIT.
--
-- Expected post-cleanup state:
--   * smartstore_product_no = 897
--   * smartstore_product_no_candidate = 11,690
--   * confirmed/candidate productNo overlap = 0
--   * candidate primary violations = 0
--   * SKU 1000-3 smartstore_product_* rows = 0
--
-- Stage note:
--   The original stage still contains 11,691 candidate rows. Cleanup excludes
--   exactly one candidate pair already covered by confirmed productNo, so the
--   adjusted expected applied candidate distinct pairs are 11,690.
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'Refusing Smartstore productNo overlap cleanup postcheck on database %. Expected product_ops_test. DO NOT run on Supabase/NAS/remote DB.',
      current_database();
  END IF;
END
$$;

DO $$
BEGIN
  IF to_regclass('product_code.smartstore_product_no_stage') IS NULL THEN
    RAISE EXCEPTION
      'Missing product_code.smartstore_product_no_stage. Cleanup postcheck needs the original staged productNo rows to compute adjusted candidate expectations.';
  END IF;
END
$$;

BEGIN;

SELECT 'CLEANUP_TARGET_AFTER' AS stage,
       id,
       target_type,
       target_id,
       code_system,
       code_value,
       parsed_part1,
       parsed_part2,
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

SELECT 'CONFIRMED_COUNTERPART_AFTER' AS stage,
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

SELECT 'SMARTSTORE_PRODUCT_COUNTS' AS stage,
       count(*) FILTER (WHERE code_system = 'smartstore_product_no') AS smartstore_product_no,
       count(*) FILTER (WHERE code_system = 'smartstore_product_no_candidate') AS smartstore_product_no_candidate,
       count(*) FILTER (WHERE code_system = 'smartstore_option_no') AS smartstore_option_no,
       count(*) FILTER (WHERE code_system = 'smartstore_option_no_candidate') AS smartstore_option_no_candidate
FROM product_code.code_alias;

WITH cur AS (
  SELECT
    count(*) FILTER (WHERE code_system = 'smartstore_product_no') AS applied_confirmed,
    count(*) FILTER (WHERE code_system = 'smartstore_product_no_candidate') AS applied_candidate,
    count(*) FILTER (WHERE code_system = 'smartstore_option_no') AS smartstore_option_confirmed,
    count(*) FILTER (WHERE code_system = 'smartstore_option_no_candidate') AS smartstore_option_candidate,
    count(*) FILTER (WHERE code_system = 'selfpia_sku') AS selfpia_sku,
    count(*) FILTER (WHERE code_system = 'own_sku') AS own_sku,
    count(*) FILTER (WHERE code_system ILIKE 'makeshop%') AS makeshop_alias_total
  FROM product_code.code_alias
),
stg AS (
  SELECT
    count(*) FILTER (WHERE code_system = 'smartstore_product_no') AS stg_raw_confirmed,
    count(DISTINCT (target_id, code_value)) FILTER (WHERE code_system = 'smartstore_product_no') AS stg_distinct_confirmed,
    count(*) FILTER (WHERE code_system = 'smartstore_product_no_candidate') AS stg_raw_candidate,
    count(DISTINCT (target_id, code_value)) FILTER (WHERE code_system = 'smartstore_product_no_candidate') AS stg_distinct_candidate,
    count(*) FILTER (
      WHERE code_system IN ('smartstore_product_no', 'smartstore_product_no_candidate')
        AND (target_id IS NULL OR code_value IS NULL OR btrim(code_value) = '')
    ) AS null_key_rows
  FROM product_code.smartstore_product_no_stage
),
stage_distinct AS (
  SELECT DISTINCT code_system, target_id, code_value
  FROM product_code.smartstore_product_no_stage
  WHERE code_system IN ('smartstore_product_no', 'smartstore_product_no_candidate')
),
stage_excluded_candidate AS (
  SELECT count(*) AS rows
  FROM stage_distinct
  WHERE code_system = 'smartstore_product_no_candidate'
    AND target_id = 'f46f312c-4c9e-4405-a9a7-c23e1155bd31'
    AND code_value = '7577001822'
    AND EXISTS (
      SELECT 1
      FROM stage_distinct c
      WHERE c.code_system = 'smartstore_product_no'
        AND c.target_id = stage_distinct.target_id
        AND c.code_value = stage_distinct.code_value
    )
),
adjusted_stage_distinct AS (
  SELECT code_system, target_id, code_value
  FROM stage_distinct
  WHERE NOT (
    code_system = 'smartstore_product_no_candidate'
    AND target_id = 'f46f312c-4c9e-4405-a9a7-c23e1155bd31'
    AND code_value = '7577001822'
  )
),
stage_distinct_resolvable AS (
  SELECT d.code_system, d.target_id, d.code_value
  FROM adjusted_stage_distinct d
  JOIN product_code.sku_master sm ON sm.id = d.target_id
),
missing AS (
  SELECT
    count(*) FILTER (WHERE d.code_system = 'smartstore_product_no' AND ca.id IS NULL) AS missing_confirmed,
    count(*) FILTER (WHERE d.code_system = 'smartstore_product_no_candidate' AND ca.id IS NULL) AS missing_candidate
  FROM stage_distinct_resolvable d
  LEFT JOIN product_code.code_alias ca
    ON ca.target_type = 'SKU'
   AND ca.target_id = d.target_id
   AND ca.code_system = d.code_system
   AND ca.code_value = d.code_value
),
resv AS (
  SELECT count(*) FILTER (WHERE sm.id IS NULL) AS unresolved
  FROM product_code.smartstore_product_no_stage s
  LEFT JOIN product_code.sku_master sm ON sm.id = s.target_id
  WHERE s.code_system IN ('smartstore_product_no', 'smartstore_product_no_candidate')
),
overlap AS (
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
target_after AS (
  SELECT count(*) AS rows
  FROM product_code.code_alias
  WHERE target_type = 'SKU'
    AND code_system = 'smartstore_product_no_candidate'
    AND target_id = 'f46f312c-4c9e-4405-a9a7-c23e1155bd31'
    AND code_value = '7577001822'
),
confirmed_counterpart AS (
  SELECT count(*) AS rows
  FROM product_code.code_alias
  WHERE target_type = 'SKU'
    AND code_system = 'smartstore_product_no'
    AND target_id = 'f46f312c-4c9e-4405-a9a7-c23e1155bd31'
    AND code_value = '7577001822'
),
prim AS (
  SELECT count(*) AS rows
  FROM product_code.code_alias
  WHERE code_system = 'smartstore_product_no_candidate'
    AND is_primary = true
),
chk_1000_3 AS (
  SELECT count(*) AS rows
  FROM product_code.code_alias
  WHERE target_id = 'd4c0a5bf-73f1-4203-a6f8-9a27a44f58da'
    AND code_system IN ('smartstore_product_no', 'smartstore_product_no_candidate')
),
dupes AS (
  SELECT count(*) AS rows
  FROM (
    SELECT code_system, target_type, target_id, code_value
    FROM product_code.code_alias
    WHERE code_system IN ('smartstore_product_no', 'smartstore_product_no_candidate')
    GROUP BY code_system, target_type, target_id, code_value
    HAVING count(*) > 1
  ) x
),
fk AS (
  SELECT count(*) AS rows
  FROM product_code.code_alias ca
  LEFT JOIN product_code.sku_master sm ON sm.id = ca.target_id
  WHERE ca.target_type = 'SKU'
    AND ca.code_system IN ('smartstore_product_no', 'smartstore_product_no_candidate')
    AND sm.id IS NULL
),
metrics AS (
  SELECT 'smartstore_product_no_count' AS metric, cur.applied_confirmed::text AS actual, '897' AS expected,
         CASE WHEN cur.applied_confirmed = 897 THEN 'PASS' ELSE 'FAIL' END AS verdict
  FROM cur
  UNION ALL
  SELECT 'smartstore_product_no_candidate_count', cur.applied_candidate::text, '11690',
         CASE WHEN cur.applied_candidate = 11690 THEN 'PASS' ELSE 'FAIL' END
  FROM cur
  UNION ALL
  SELECT 'cleanup_candidate_target_rows_after', target_after.rows::text, '0',
         CASE WHEN target_after.rows = 0 THEN 'PASS' ELSE 'FAIL' END
  FROM target_after
  UNION ALL
  SELECT 'confirmed_counterpart_rows_after', confirmed_counterpart.rows::text, '1',
         CASE WHEN confirmed_counterpart.rows = 1 THEN 'PASS' ELSE 'FAIL' END
  FROM confirmed_counterpart
  UNION ALL
  SELECT 'confirmed_candidate_overlap_rows', overlap.rows::text, '0',
         CASE WHEN overlap.rows = 0 THEN 'PASS' ELSE 'FAIL' END
  FROM overlap
  UNION ALL
  SELECT 'candidate_primary_violations', prim.rows::text, '0',
         CASE WHEN prim.rows = 0 THEN 'PASS' ELSE 'FAIL' END
  FROM prim
  UNION ALL
  SELECT 'sku_1000_3_smartstore_product_rows', chk_1000_3.rows::text, '0',
         CASE WHEN chk_1000_3.rows = 0 THEN 'PASS' ELSE 'FAIL' END
  FROM chk_1000_3
  UNION ALL
  SELECT 'duplicate_alias_pairs', dupes.rows::text, '0',
         CASE WHEN dupes.rows = 0 THEN 'PASS' ELSE 'FAIL' END
  FROM dupes
  UNION ALL
  SELECT 'fk_missing_rows', fk.rows::text, '0',
         CASE WHEN fk.rows = 0 THEN 'PASS' ELSE 'FAIL' END
  FROM fk
  UNION ALL
  SELECT 'stage_raw_confirmed', stg.stg_raw_confirmed::text, '908',
         CASE WHEN stg.stg_raw_confirmed = 908 THEN 'PASS' ELSE 'FAIL' END
  FROM stg
  UNION ALL
  SELECT 'stage_distinct_confirmed', stg.stg_distinct_confirmed::text, '897',
         CASE WHEN stg.stg_distinct_confirmed = 897 THEN 'PASS' ELSE 'FAIL' END
  FROM stg
  UNION ALL
  SELECT 'stage_raw_candidate', stg.stg_raw_candidate::text, '11691',
         CASE WHEN stg.stg_raw_candidate = 11691 THEN 'PASS' ELSE 'FAIL' END
  FROM stg
  UNION ALL
  SELECT 'stage_distinct_candidate_raw', stg.stg_distinct_candidate::text, '11691',
         CASE WHEN stg.stg_distinct_candidate = 11691 THEN 'PASS' ELSE 'FAIL' END
  FROM stg
  UNION ALL
  SELECT 'stage_excluded_candidate_overlap_rows', stage_excluded_candidate.rows::text, '1',
         CASE WHEN stage_excluded_candidate.rows = 1 THEN 'PASS' ELSE 'FAIL' END
  FROM stage_excluded_candidate
  UNION ALL
  SELECT 'stage_distinct_candidate_adjusted', (stg.stg_distinct_candidate - stage_excluded_candidate.rows)::text, '11690',
         CASE WHEN stg.stg_distinct_candidate - stage_excluded_candidate.rows = 11690 THEN 'PASS' ELSE 'FAIL' END
  FROM stg CROSS JOIN stage_excluded_candidate
  UNION ALL
  SELECT 'stage_null_key_rows', stg.null_key_rows::text, '0',
         CASE WHEN stg.null_key_rows = 0 THEN 'PASS' ELSE 'FAIL' END
  FROM stg
  UNION ALL
  SELECT 'stage_unresolved_rows', resv.unresolved::text, '0',
         CASE WHEN resv.unresolved = 0 THEN 'PASS' ELSE 'FAIL' END
  FROM resv
  UNION ALL
  SELECT 'missing_confirmed_distinct_pairs_adjusted', missing.missing_confirmed::text, '0',
         CASE WHEN missing.missing_confirmed = 0 THEN 'PASS' ELSE 'FAIL' END
  FROM missing
  UNION ALL
  SELECT 'missing_candidate_distinct_pairs_adjusted', missing.missing_candidate::text, '0',
         CASE WHEN missing.missing_candidate = 0 THEN 'PASS' ELSE 'FAIL' END
  FROM missing
),
baseline_info AS (
  SELECT 'smartstore_option_no_current' AS metric, cur.smartstore_option_confirmed::text AS actual, 'informational only' AS expected, 'INFO_NOT_IN_OVERALL' AS verdict
  FROM cur
  UNION ALL
  SELECT 'smartstore_option_no_candidate_current', cur.smartstore_option_candidate::text, 'informational only', 'INFO_NOT_IN_OVERALL'
  FROM cur
  UNION ALL
  SELECT 'selfpia_sku_current', cur.selfpia_sku::text, 'informational only', 'INFO_NOT_IN_OVERALL'
  FROM cur
  UNION ALL
  SELECT 'own_sku_current', cur.own_sku::text, 'informational only', 'INFO_NOT_IN_OVERALL'
  FROM cur
  UNION ALL
  SELECT 'makeshop_alias_current', cur.makeshop_alias_total::text, 'informational only', 'INFO_NOT_IN_OVERALL'
  FROM cur
)
SELECT 'POSTCHECK_CLEANUP_METRIC' AS stage, metric, actual, expected, verdict
FROM metrics
UNION ALL
SELECT 'POSTCHECK_CLEANUP_METRIC' AS stage, metric, actual, expected, verdict
FROM baseline_info
UNION ALL
SELECT 'POSTCHECK_CLEANUP_METRIC',
       'OVERALL',
       CASE WHEN bool_and(verdict = 'PASS') THEN 'OVERALL PASS' ELSE 'OVERALL FAIL' END,
       'OVERALL PASS',
       CASE WHEN bool_and(verdict = 'PASS') THEN 'PASS' ELSE 'FAIL' END
FROM metrics
ORDER BY metric;

ROLLBACK;
