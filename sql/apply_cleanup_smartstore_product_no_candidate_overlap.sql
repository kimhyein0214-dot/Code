-- =============================================================================
-- apply_cleanup_smartstore_product_no_candidate_overlap.sql
--
-- LOCAL DOCKER ONLY REAL CLEANUP APPLY.
--
-- Purpose:
--   Remove exactly one redundant Smartstore productNo candidate alias that
--   overlaps an already confirmed Smartstore productNo alias for the same SKU.
--
-- Target:
--   local Docker PostgreSQL database only: product_ops_test
--
-- DO NOT run on Supabase/NAS/remote DB.
-- DO NOT delete confirmed Smartstore productNo aliases.
-- DO NOT change smartstore_option_no or smartstore_option_no_candidate aliases.
--
-- Cleanup target:
--   code_system = 'smartstore_product_no_candidate'
--   target_id   = 'f46f312c-4c9e-4405-a9a7-c23e1155bd31'
--   code_value  = '7577001822'
--
-- Backup/recovery:
--   This script COMMITs on success. Create a local DB backup or Docker volume
--   snapshot before running. After COMMIT, recovery requires backup restore or
--   a separately reviewed inverse insert script.
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'Refusing Smartstore productNo overlap cleanup apply on database %. Expected product_ops_test. DO NOT run on Supabase/NAS/remote DB.',
      current_database();
  END IF;
END
$$;

DROP TABLE IF EXISTS pg_temp._cleanup_baseline;
CREATE TEMP TABLE _cleanup_baseline AS
SELECT
  count(*) FILTER (WHERE code_system = 'smartstore_product_no') AS smartstore_product_confirmed,
  count(*) FILTER (WHERE code_system = 'smartstore_product_no_candidate') AS smartstore_product_candidate,
  count(*) FILTER (WHERE code_system = 'smartstore_option_no') AS smartstore_option_confirmed,
  count(*) FILTER (WHERE code_system = 'smartstore_option_no_candidate') AS smartstore_option_candidate,
  count(*) FILTER (WHERE code_system = 'selfpia_sku') AS selfpia_sku,
  count(*) FILTER (WHERE code_system = 'own_sku') AS own_sku,
  count(*) FILTER (WHERE code_system ILIKE 'makeshop%') AS makeshop_total,
  count(*) AS total_alias
FROM product_code.code_alias;

SELECT 'BASELINE' AS stage, * FROM _cleanup_baseline;

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

BEGIN;

DO $$
DECLARE
  v_target_rows bigint;
  v_confirmed_rows bigint;
BEGIN
  SELECT count(*)
  INTO v_target_rows
  FROM product_code.code_alias
  WHERE target_type = 'SKU'
    AND code_system = 'smartstore_product_no_candidate'
    AND target_id = 'f46f312c-4c9e-4405-a9a7-c23e1155bd31'
    AND code_value = '7577001822';

  SELECT count(*)
  INTO v_confirmed_rows
  FROM product_code.code_alias
  WHERE target_type = 'SKU'
    AND code_system = 'smartstore_product_no'
    AND target_id = 'f46f312c-4c9e-4405-a9a7-c23e1155bd31'
    AND code_value = '7577001822';

  IF v_target_rows <> 1 THEN
    RAISE EXCEPTION
      'Expected exactly 1 cleanup candidate target row, found %. Transaction will not commit.',
      v_target_rows;
  END IF;

  IF v_confirmed_rows <> 1 THEN
    RAISE EXCEPTION
      'Expected exactly 1 confirmed counterpart row, found %. Transaction will not commit.',
      v_confirmed_rows;
  END IF;
END
$$;

CREATE TEMP TABLE _cleanup_deleted (
  id uuid PRIMARY KEY
) ON COMMIT PRESERVE ROWS;

WITH target AS MATERIALIZED (
  SELECT id
  FROM product_code.code_alias
  WHERE target_type = 'SKU'
    AND code_system = 'smartstore_product_no_candidate'
    AND target_id = 'f46f312c-4c9e-4405-a9a7-c23e1155bd31'
    AND code_value = '7577001822'
),
deleted AS (
  DELETE FROM product_code.code_alias ca
  USING target t
  WHERE ca.id = t.id
  RETURNING ca.id
)
INSERT INTO _cleanup_deleted (id)
SELECT id FROM deleted;

DROP TABLE IF EXISTS pg_temp._cleanup_precommit_metrics;
CREATE TEMP TABLE _cleanup_precommit_metrics AS
WITH cur AS (
  SELECT
    count(*) FILTER (WHERE code_system = 'smartstore_product_no') AS smartstore_product_confirmed,
    count(*) FILTER (WHERE code_system = 'smartstore_product_no_candidate') AS smartstore_product_candidate,
    count(*) FILTER (WHERE code_system = 'smartstore_option_no') AS smartstore_option_confirmed,
    count(*) FILTER (WHERE code_system = 'smartstore_option_no_candidate') AS smartstore_option_candidate,
    count(*) FILTER (WHERE code_system = 'selfpia_sku') AS selfpia_sku,
    count(*) FILTER (WHERE code_system = 'own_sku') AS own_sku,
    count(*) FILTER (WHERE code_system ILIKE 'makeshop%') AS makeshop_total,
    count(*) AS total_alias
  FROM product_code.code_alias
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
)
SELECT 'rows_deleted' AS metric,
       (SELECT count(*) FROM _cleanup_deleted)::text AS actual,
       '1' AS expected,
       CASE WHEN (SELECT count(*) FROM _cleanup_deleted) = 1 THEN 'PASS' ELSE 'FAIL' END AS verdict
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
SELECT 'smartstore_product_no_count', cur.smartstore_product_confirmed::text, '897',
       CASE WHEN cur.smartstore_product_confirmed = 897 THEN 'PASS' ELSE 'FAIL' END
FROM cur
UNION ALL
SELECT 'smartstore_product_no_candidate_count', cur.smartstore_product_candidate::text, '11690',
       CASE WHEN cur.smartstore_product_candidate = 11690 THEN 'PASS' ELSE 'FAIL' END
FROM cur
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
SELECT 'smartstore_option_no_unchanged', cur.smartstore_option_confirmed::text, b.smartstore_option_confirmed::text,
       CASE WHEN cur.smartstore_option_confirmed = b.smartstore_option_confirmed THEN 'PASS' ELSE 'FAIL' END
FROM cur CROSS JOIN _cleanup_baseline b
UNION ALL
SELECT 'smartstore_option_no_candidate_unchanged', cur.smartstore_option_candidate::text, b.smartstore_option_candidate::text,
       CASE WHEN cur.smartstore_option_candidate = b.smartstore_option_candidate THEN 'PASS' ELSE 'FAIL' END
FROM cur CROSS JOIN _cleanup_baseline b
UNION ALL
SELECT 'selfpia_sku_unchanged', cur.selfpia_sku::text, b.selfpia_sku::text,
       CASE WHEN cur.selfpia_sku = b.selfpia_sku THEN 'PASS' ELSE 'FAIL' END
FROM cur CROSS JOIN _cleanup_baseline b
UNION ALL
SELECT 'own_sku_unchanged', cur.own_sku::text, b.own_sku::text,
       CASE WHEN cur.own_sku = b.own_sku THEN 'PASS' ELSE 'FAIL' END
FROM cur CROSS JOIN _cleanup_baseline b
UNION ALL
SELECT 'makeshop_total_unchanged', cur.makeshop_total::text, b.makeshop_total::text,
       CASE WHEN cur.makeshop_total = b.makeshop_total THEN 'PASS' ELSE 'FAIL' END
FROM cur CROSS JOIN _cleanup_baseline b;

SELECT 'PRECOMMIT_METRIC' AS stage, metric, actual, expected, verdict
FROM _cleanup_precommit_metrics
ORDER BY metric;

DO $$
DECLARE
  v_failures text;
BEGIN
  SELECT string_agg(metric || '=' || actual || ' expected ' || expected, '; ' ORDER BY metric)
  INTO v_failures
  FROM _cleanup_precommit_metrics
  WHERE verdict <> 'PASS';

  IF v_failures IS NOT NULL THEN
    RAISE EXCEPTION
      'Smartstore productNo candidate overlap cleanup precommit guard failed: %. Transaction will not commit.',
      v_failures;
  END IF;
END
$$;

COMMIT;

SELECT 'FINAL APPLY VERDICT' AS stage,
       'OVERALL PASS' AS verdict,
       'Committed local cleanup of 1 redundant smartstore_product_no_candidate alias. Confirmed productNo and Smartstore optionNo aliases unchanged.' AS note;

