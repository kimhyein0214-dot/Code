-- =============================================================================
-- diagnose_makeshop_auto_confirm_quality.sql
--
-- SELECT-only quality diagnostic for MakeShop auto_confirm candidates.
-- Reuses the same extraction/classification logic as dryrun_makeshop_select_only.sql.
--
-- Safety: product_ops_test guard, TEMP TABLE only, BEGIN ... ROLLBACK.
-- CSV input path inside Docker container: /tmp/makeshop_minimal_full.csv
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'diagnostic is allowed only on product_ops_test. Current database: %',
      current_database();
  END IF;
END
$$;

BEGIN;

CREATE TEMP TABLE mk_src (
  product_uid   text,
  sto_id        text,
  sto_code      text,
  opt_value     text,
  opt_values    text,
  barcode       text,
  product_name  text,
  status        text,
  gid           text,
  ps_num        text
);

\copy mk_src FROM '/tmp/makeshop_minimal_full.csv' WITH (FORMAT CSV, HEADER true, ENCODING 'UTF8')

CREATE TEMP TABLE mk_extracted AS
SELECT
  s.product_uid,
  s.sto_id,
  s.sto_code,
  s.opt_value,
  s.opt_values,
  s.barcode,
  s.product_name,
  s.status AS source_status,
  substring(s.opt_value  FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]') AS opt_value_bracket,
  substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]') AS opt_values_bracket,
  CASE
    WHEN s.sto_code IS NOT NULL AND btrim(s.sto_code) <> ''
      THEN btrim(s.sto_code)
    WHEN substring(s.opt_value FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]') IS NOT NULL
      THEN substring(s.opt_value FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]')
    WHEN substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]') IS NOT NULL
      THEN substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]')
    ELSE NULL
  END AS own_sku_candidate,
  CASE
    WHEN s.sto_code IS NOT NULL AND btrim(s.sto_code) <> ''
      THEN 'sto_code'
    WHEN substring(s.opt_value FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]') IS NOT NULL
      THEN 'opt_value_bracket'
    WHEN substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]') IS NOT NULL
      THEN 'opt_values_bracket'
    ELSE NULL
  END AS extraction_method,
  CASE
    WHEN s.product_uid IS NOT NULL AND btrim(s.product_uid) <> ''
     AND s.sto_id IS NOT NULL AND btrim(s.sto_id) <> ''
      THEN btrim(s.product_uid) || '-' || btrim(s.sto_id)
    ELSE NULL
  END AS channel_sku_code
FROM mk_src s;

CREATE TEMP TABLE mk_match_agg AS
SELECT
  e.*,
  COUNT(ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL) AS match_count,
  array_agg(DISTINCT ca.target_id ORDER BY ca.target_id)
    FILTER (WHERE ca.target_id IS NOT NULL) AS candidate_sku_ids,
  CASE
    WHEN COUNT(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL) = 1
      THEN (array_agg(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL))[1]
    ELSE NULL
  END AS resolved_sku_id
FROM mk_extracted e
LEFT JOIN product_code.code_alias ca
  ON ca.target_type = 'SKU'
 AND ca.code_system = 'own_sku'
 AND ca.code_value = e.own_sku_candidate
 AND e.own_sku_candidate IS NOT NULL
 AND btrim(e.own_sku_candidate) <> ''
GROUP BY
  e.product_uid, e.sto_id, e.channel_sku_code, e.sto_code, e.opt_value,
  e.opt_values, e.barcode, e.product_name, e.source_status, e.own_sku_candidate,
  e.extraction_method, e.opt_value_bracket, e.opt_values_bracket;

CREATE TEMP TABLE mk_classified AS
SELECT
  m.*,
  scm.id AS existing_mapping_id,
  scm.sku_id AS existing_mapped_sku_id,
  sm.status AS sku_master_status,
  CASE
    WHEN m.product_uid IS NULL OR btrim(m.product_uid) = ''
      OR m.sto_id IS NULL OR btrim(m.sto_id) = ''
      THEN 'null_key'
    WHEN (m.sto_code IS NULL OR btrim(m.sto_code) = '')
     AND ((m.opt_value IS NOT NULL AND btrim(m.opt_value) <> '')
       OR (m.opt_values IS NOT NULL AND btrim(m.opt_values) <> ''))
     AND m.opt_value_bracket IS NULL
     AND m.opt_values_bracket IS NULL
      THEN 'pattern_unmatched'
    WHEN m.own_sku_candidate IS NULL OR btrim(m.own_sku_candidate) = ''
      THEN 'own_sku_missing'
    WHEN m.match_count = 0
      THEN 'own_sku_not_in_alias'
    WHEN m.match_count > 1
      THEN 'own_sku_ambiguous'
    WHEN scm.id IS NOT NULL
      THEN 'channel_sku_conflict'
    WHEN sm.status IS NOT NULL
     AND (sm.status ILIKE '%inactive%' OR sm.status ILIKE '%deleted%' OR sm.status ILIKE '%archive%')
      THEN 'sku_inactive'
    ELSE NULL
  END AS review_reason,
  CASE
    WHEN m.product_uid IS NULL OR btrim(m.product_uid) = ''
      OR m.sto_id IS NULL OR btrim(m.sto_id) = ''
      OR m.own_sku_candidate IS NULL OR btrim(m.own_sku_candidate) = ''
      OR m.match_count <> 1
      OR scm.id IS NOT NULL
      OR (sm.status IS NOT NULL AND (sm.status ILIKE '%inactive%' OR sm.status ILIKE '%deleted%' OR sm.status ILIKE '%archive%'))
      OR ((m.sto_code IS NULL OR btrim(m.sto_code) = '')
       AND ((m.opt_value IS NOT NULL AND btrim(m.opt_value) <> '')
         OR (m.opt_values IS NOT NULL AND btrim(m.opt_values) <> ''))
       AND m.opt_value_bracket IS NULL
       AND m.opt_values_bracket IS NULL)
      THEN 'review_required'
    ELSE 'auto_confirm'
  END AS classification
FROM mk_match_agg m
LEFT JOIN product_code.sku_channel_mapping scm
  ON scm.channel_code = 'makeshop'
 AND scm.channel_sku_code = m.channel_sku_code
 AND m.channel_sku_code IS NOT NULL
LEFT JOIN product_code.sku_master sm
  ON sm.id = m.resolved_sku_id;

CREATE TEMP TABLE auto_confirm_detail AS
SELECT
  'makeshop'::text AS channel_code,
  c.product_uid AS seller_product_code_raw,
  c.channel_sku_code,
  c.sto_id AS sto_id_raw,
  c.own_sku_candidate AS own_sku_code,
  c.extraction_method,
  c.resolved_sku_id AS matched_sku_id,
  sm.virtual_sku_code,
  sm.option_value AS sku_option_value,
  sm.sku_type,
  sm.status AS sku_status,
  sm.product_id,
  pm.virtual_product_code,
  pm.product_name AS master_product_name,
  c.product_name AS makeshop_product_name,
  c.opt_value AS makeshop_opt_value,
  c.opt_values AS makeshop_opt_values,
  c.barcode,
  selfpia.selfpia_sku_codes,
  selfpia.selfpia_product_codes,
  selfpia.selfpia_option_nos
FROM mk_classified c
JOIN product_code.sku_master sm
  ON sm.id = c.resolved_sku_id
LEFT JOIN product_code.product_master pm
  ON pm.id = sm.product_id
LEFT JOIN LATERAL (
  SELECT
    array_agg(DISTINCT ca.code_value ORDER BY ca.code_value)
      FILTER (WHERE ca.code_system = 'selfpia_sku') AS selfpia_sku_codes,
    array_agg(DISTINCT ca.selfpia_product_code ORDER BY ca.selfpia_product_code)
      FILTER (WHERE ca.selfpia_product_code IS NOT NULL AND btrim(ca.selfpia_product_code) <> '') AS selfpia_product_codes,
    array_agg(DISTINCT ca.selfpia_option_no ORDER BY ca.selfpia_option_no)
      FILTER (WHERE ca.selfpia_option_no IS NOT NULL AND btrim(ca.selfpia_option_no) <> '') AS selfpia_option_nos
  FROM product_code.code_alias ca
  WHERE ca.target_type = 'SKU'
    AND ca.target_id = sm.id
) selfpia ON true
WHERE c.classification = 'auto_confirm';

\echo
\echo ===== [auto_confirm summary] =====
SELECT
  COUNT(*) AS auto_confirm_rows,
  COUNT(DISTINCT seller_product_code_raw) AS distinct_product_uid,
  COUNT(DISTINCT channel_sku_code) AS distinct_channel_sku_code,
  COUNT(DISTINCT own_sku_code) AS distinct_own_sku_code,
  COUNT(DISTINCT matched_sku_id) AS distinct_matched_sku_id,
  COUNT(*) FILTER (WHERE channel_sku_code IS NULL OR btrim(channel_sku_code) = '') AS blank_channel_sku_code,
  COUNT(*) FILTER (WHERE own_sku_code IS NULL OR btrim(own_sku_code) = '') AS blank_own_sku_code,
  COUNT(*) FILTER (WHERE matched_sku_id IS NULL) AS blank_matched_sku_id
FROM auto_confirm_detail;

\echo
\echo ===== [auto_confirm count by extraction_method] =====
SELECT
  extraction_method,
  COUNT(*) AS rows,
  COUNT(DISTINCT seller_product_code_raw) AS distinct_product_uid,
  COUNT(DISTINCT own_sku_code) AS distinct_own_sku_code,
  COUNT(DISTINCT matched_sku_id) AS distinct_matched_sku_id
FROM auto_confirm_detail
GROUP BY extraction_method
ORDER BY extraction_method;

\echo
\echo ===== [anomaly counters] =====
WITH sku_repeat AS (
  SELECT matched_sku_id, COUNT(*) AS rows, COUNT(DISTINCT seller_product_code_raw) AS product_uids
  FROM auto_confirm_detail
  GROUP BY matched_sku_id
),
own_repeat AS (
  SELECT own_sku_code, COUNT(*) AS rows, COUNT(DISTINCT seller_product_code_raw) AS product_uids
  FROM auto_confirm_detail
  GROUP BY own_sku_code
)
SELECT
  (SELECT COUNT(*) FROM sku_repeat WHERE rows > 1) AS matched_sku_repeated_keys,
  (SELECT COALESCE(SUM(rows), 0) FROM sku_repeat WHERE rows > 1) AS matched_sku_repeated_rows,
  (SELECT COUNT(*) FROM sku_repeat WHERE rows >= 3) AS matched_sku_repeated_3plus_keys,
  (SELECT COUNT(*) FROM sku_repeat WHERE product_uids > 1) AS matched_sku_across_multiple_product_uid_keys,
  (SELECT COUNT(*) FROM own_repeat WHERE rows > 1) AS own_sku_repeated_keys,
  (SELECT COALESCE(SUM(rows), 0) FROM own_repeat WHERE rows > 1) AS own_sku_repeated_rows,
  (SELECT COUNT(*) FROM own_repeat WHERE rows >= 3) AS own_sku_repeated_3plus_keys,
  (SELECT COUNT(*) FROM own_repeat WHERE product_uids > 1) AS own_sku_across_multiple_product_uid_keys;

\echo
\echo ===== [opt_values_bracket auto_confirm sample 100] =====
SELECT *
FROM auto_confirm_detail
WHERE extraction_method = 'opt_values_bracket'
ORDER BY seller_product_code_raw, sto_id_raw
LIMIT 100;

\echo
\echo ===== [opt_value_bracket auto_confirm sample 100] =====
SELECT *
FROM auto_confirm_detail
WHERE extraction_method = 'opt_value_bracket'
ORDER BY seller_product_code_raw, sto_id_raw
LIMIT 100;

\echo
\echo ===== [same own_sku_code repeated in auto_confirm top 50] =====
SELECT
  own_sku_code,
  COUNT(*) AS rows,
  COUNT(DISTINCT seller_product_code_raw) AS distinct_product_uid,
  COUNT(DISTINCT channel_sku_code) AS distinct_channel_sku_code,
  COUNT(DISTINCT matched_sku_id) AS distinct_matched_sku_id,
  array_agg(DISTINCT seller_product_code_raw ORDER BY seller_product_code_raw) AS product_uids,
  MIN(makeshop_product_name) AS sample_makeshop_product_name,
  MIN(master_product_name) AS sample_master_product_name
FROM auto_confirm_detail
GROUP BY own_sku_code
HAVING COUNT(*) > 1
ORDER BY rows DESC, distinct_product_uid DESC, own_sku_code
LIMIT 50;

\echo
\echo ===== [same matched_sku_id repeated in auto_confirm top 50] =====
SELECT
  matched_sku_id,
  COUNT(*) AS rows,
  COUNT(DISTINCT seller_product_code_raw) AS distinct_product_uid,
  COUNT(DISTINCT channel_sku_code) AS distinct_channel_sku_code,
  COUNT(DISTINCT own_sku_code) AS distinct_own_sku_code,
  MIN(own_sku_code) AS sample_own_sku_code,
  MIN(virtual_sku_code) AS sample_virtual_sku_code,
  MIN(sku_option_value) AS sample_sku_option_value,
  MIN(makeshop_product_name) AS sample_makeshop_product_name,
  MIN(master_product_name) AS sample_master_product_name
FROM auto_confirm_detail
GROUP BY matched_sku_id
HAVING COUNT(*) > 1
ORDER BY rows DESC, distinct_product_uid DESC, matched_sku_id
LIMIT 50;

ROLLBACK;

\echo
\echo diagnose_makeshop_auto_confirm_quality.sql complete. ROLLBACK applied. No persistent changes.
