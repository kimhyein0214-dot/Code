-- =============================================================================
-- export_makeshop_auto_confirm_candidates.sql
--
-- Read-only export of MakeShop auto_confirm candidates.
-- This is not apply SQL and performs no sku_channel_mapping INSERT.
--
-- Output:
--   /tmp/makeshop_auto_confirm_candidates.csv
--
-- Safety: product_ops_test guard, TEMP TABLE only, BEGIN ... ROLLBACK.
-- CSV input path inside Docker container: /tmp/makeshop_minimal_full.csv
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'export diagnostic is allowed only on product_ops_test. Current database: %',
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
  sm.status AS sku_master_status,
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

\echo
\echo ===== [auto_confirm export count] =====
SELECT COUNT(*) AS auto_confirm_candidates
FROM mk_classified
WHERE classification = 'auto_confirm';

\copy (SELECT 'makeshop'::text AS channel_code, product_uid AS seller_product_code_raw, channel_sku_code, sto_id AS sto_id_raw, sto_code, opt_value, opt_values, own_sku_candidate AS own_sku_code, extraction_method, resolved_sku_id AS matched_sku_id, product_name, barcode FROM mk_classified WHERE classification = 'auto_confirm' ORDER BY product_uid, sto_id) TO '/tmp/makeshop_auto_confirm_candidates.csv' WITH (FORMAT CSV, HEADER true, ENCODING 'UTF8')

\echo
\echo Exported auto_confirm CSV file:
\echo /tmp/makeshop_auto_confirm_candidates.csv

ROLLBACK;

\echo
\echo export_makeshop_auto_confirm_candidates.sql complete. ROLLBACK applied. No persistent DB changes.
