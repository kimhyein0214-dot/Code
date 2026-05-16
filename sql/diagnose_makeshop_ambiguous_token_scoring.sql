-- =============================================================================
-- diagnose_makeshop_ambiguous_token_scoring.sql
--
-- SELECT-only token scoring diagnostic for MakeShop own_sku_ambiguous rows.
-- This script does not auto-resolve or apply mappings.
--
-- Safety: product_ops_test guard, TEMP TABLE only, SELECT only,
-- BEGIN ... ROLLBACK, no persistent DB changes.
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'ambiguous token scoring is allowed only on product_ops_test. Current database: %',
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
WITH base AS (
  SELECT
    row_number() OVER () AS mk_row_id,
    s.*,
    substring(s.opt_value  FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]') AS opt_value_existing_bracket,
    substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]') AS opt_values_existing_bracket,
    substring(s.opt_value  FROM '\[([A-Za-z]+-[0-9]+-[0-9]+-[0-9]+)\]') AS opt_value_4part_bracket,
    substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+-[0-9]+)\]') AS opt_values_4part_bracket
  FROM mk_src s
)
SELECT
  b.*,
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> '' THEN btrim(b.sto_code)
    WHEN b.opt_values_existing_bracket IS NOT NULL THEN b.opt_values_existing_bracket
    WHEN b.opt_values_4part_bracket IS NOT NULL THEN b.opt_values_4part_bracket
    WHEN b.opt_value_existing_bracket IS NOT NULL THEN b.opt_value_existing_bracket
    WHEN b.opt_value_4part_bracket IS NOT NULL THEN b.opt_value_4part_bracket
    ELSE NULL
  END AS own_sku_candidate,
  CASE
    WHEN b.product_uid IS NOT NULL AND btrim(b.product_uid) <> ''
     AND b.sto_id IS NOT NULL AND btrim(b.sto_id) <> ''
      THEN btrim(b.product_uid) || '-' || btrim(b.sto_id)
    ELSE NULL
  END AS channel_sku_code
FROM base b;

CREATE TEMP TABLE ambiguous_rows AS
SELECT
  e.*,
  COUNT(DISTINCT ca.target_id) AS candidate_sku_count,
  lower(regexp_replace(COALESCE(e.opt_values, ''), '[^[:alnum:]]+', ' ', 'g')) AS opt_values_norm,
  regexp_replace(COALESCE(e.opt_values, ''), '[^0-9]+', ' ', 'g') AS opt_values_numbers
FROM mk_extracted e
JOIN product_code.code_alias ca
  ON ca.target_type = 'SKU'
 AND ca.code_system = 'own_sku'
 AND ca.code_value = e.own_sku_candidate
WHERE e.own_sku_candidate IS NOT NULL
  AND btrim(e.own_sku_candidate) <> ''
GROUP BY
  e.mk_row_id, e.product_uid, e.sto_id, e.sto_code, e.opt_value, e.opt_values,
  e.barcode, e.product_name, e.status, e.gid, e.ps_num, e.opt_value_existing_bracket,
  e.opt_values_existing_bracket, e.opt_value_4part_bracket, e.opt_values_4part_bracket,
  e.own_sku_candidate, e.channel_sku_code
HAVING COUNT(DISTINCT ca.target_id) > 1;

CREATE TEMP TABLE ambiguous_candidate_matrix AS
SELECT
  ar.mk_row_id,
  ar.product_uid,
  ar.channel_sku_code,
  ar.sto_id,
  ar.opt_value,
  ar.opt_values,
  ar.opt_values_norm,
  ar.opt_values_numbers,
  ar.product_name AS makeshop_product_name,
  ar.barcode,
  ar.own_sku_candidate AS own_sku_code,
  ar.candidate_sku_count,
  sm.id AS candidate_sku_id,
  sm.option_value AS candidate_option_value,
  sm.virtual_sku_code AS candidate_virtual_sku_code,
  sm.product_id AS candidate_product_id,
  pm.product_name AS candidate_product_name,
  selfpia.selfpia_sku_aliases,
  selfpia.selfpia_product_aliases,
  selfpia.selfpia_option_nos,
  lower(regexp_replace(COALESCE(sm.option_value, ''), '[^[:alnum:]]+', ' ', 'g')) AS candidate_option_norm,
  regexp_replace(COALESCE(sm.option_value, ''), '[^0-9]+', ' ', 'g') AS candidate_option_numbers
FROM ambiguous_rows ar
JOIN product_code.code_alias own
  ON own.target_type = 'SKU'
 AND own.code_system = 'own_sku'
 AND own.code_value = ar.own_sku_candidate
JOIN product_code.sku_master sm
  ON sm.id = own.target_id
LEFT JOIN product_code.product_master pm
  ON pm.id = sm.product_id
LEFT JOIN LATERAL (
  SELECT
    array_agg(DISTINCT ca.code_value ORDER BY ca.code_value)
      FILTER (WHERE ca.code_system = 'selfpia_sku') AS selfpia_sku_aliases,
    array_agg(DISTINCT ca.selfpia_product_code ORDER BY ca.selfpia_product_code)
      FILTER (WHERE ca.selfpia_product_code IS NOT NULL AND btrim(ca.selfpia_product_code) <> '') AS selfpia_product_aliases,
    array_agg(DISTINCT ca.selfpia_option_no ORDER BY ca.selfpia_option_no)
      FILTER (WHERE ca.selfpia_option_no IS NOT NULL AND btrim(ca.selfpia_option_no) <> '') AS selfpia_option_nos
  FROM product_code.code_alias ca
  WHERE ca.target_type = 'SKU'
    AND ca.target_id = sm.id
) selfpia ON true;

CREATE TEMP TABLE scored_candidates AS
SELECT
  m.*,
  (m.opt_values_norm <> '' AND m.candidate_option_norm <> '' AND m.opt_values_norm = m.candidate_option_norm) AS option_exact_match,
  (m.opt_values_norm <> '' AND m.candidate_option_norm <> ''
    AND (m.opt_values_norm LIKE '%' || m.candidate_option_norm || '%'
      OR m.candidate_option_norm LIKE '%' || m.opt_values_norm || '%')) AS option_partial_match,
  (btrim(m.opt_values_numbers) <> '' AND btrim(m.candidate_option_numbers) <> ''
    AND btrim(m.opt_values_numbers) = btrim(m.candidate_option_numbers)) AS number_token_match,
  CASE
    WHEN m.opt_values_norm ~ '(white|black|red|blue|green|pink|purple|orange|yellow|gold|silver|clear|화이트|블랙|레드|블루|그린|핑크|퍼플|오렌지|옐로우|골드|실버|클리어)'
     AND m.candidate_option_norm ~ '(white|black|red|blue|green|pink|purple|orange|yellow|gold|silver|clear|화이트|블랙|레드|블루|그린|핑크|퍼플|오렌지|옐로우|골드|실버|클리어)'
      THEN true
    ELSE false
  END AS color_option_token_present,
  CASE
    WHEN m.selfpia_option_nos IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM unnest(m.selfpia_option_nos) AS opt_no
       WHERE opt_no IS NOT NULL
         AND btrim(opt_no) <> ''
         AND m.sto_id = opt_no
     )
      THEN true
    ELSE false
  END AS selfpia_option_no_matches_sto_id,
  (
    CASE WHEN m.opt_values_norm <> '' AND m.candidate_option_norm <> '' AND m.opt_values_norm = m.candidate_option_norm THEN 100 ELSE 0 END
    + CASE WHEN m.opt_values_norm <> '' AND m.candidate_option_norm <> ''
      AND (m.opt_values_norm LIKE '%' || m.candidate_option_norm || '%'
        OR m.candidate_option_norm LIKE '%' || m.opt_values_norm || '%') THEN 40 ELSE 0 END
    + CASE WHEN btrim(m.opt_values_numbers) <> '' AND btrim(m.candidate_option_numbers) <> ''
      AND btrim(m.opt_values_numbers) = btrim(m.candidate_option_numbers) THEN 20 ELSE 0 END
    + CASE WHEN m.selfpia_option_nos IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM unnest(m.selfpia_option_nos) AS opt_no
        WHERE opt_no IS NOT NULL
          AND btrim(opt_no) <> ''
          AND m.sto_id = opt_no
      ) THEN 30 ELSE 0 END
  ) AS token_score
FROM ambiguous_candidate_matrix m;

CREATE TEMP TABLE ranked_candidates AS
WITH with_top_score AS (
  SELECT
    s.*,
    max(token_score) OVER (PARTITION BY mk_row_id) AS top_score
  FROM scored_candidates s
)
SELECT
  w.*,
  dense_rank() OVER (PARTITION BY mk_row_id ORDER BY token_score DESC, candidate_sku_id) AS score_rank,
  COUNT(*) FILTER (WHERE token_score = top_score) OVER (PARTITION BY mk_row_id) AS top_score_tied_count
FROM with_top_score w;

CREATE TEMP TABLE row_diagnostic AS
SELECT
  mk_row_id,
  product_uid,
  channel_sku_code,
  sto_id,
  own_sku_code,
  candidate_sku_count,
  max(top_score) AS top_score,
  max(top_score_tied_count) AS top1_tied_candidate_count,
  CASE
    WHEN max(top_score) >= 100 AND max(top_score_tied_count) = 1
      THEN 'possible_auto_resolution_candidate_strong_token'
    WHEN max(top_score) > 0 AND max(top_score_tied_count) = 1
      THEN 'possible_auto_resolution_candidate_weak_token'
    ELSE 'manual_review_required'
  END AS diagnostic_label
FROM ranked_candidates
GROUP BY mk_row_id, product_uid, channel_sku_code, sto_id, own_sku_code, candidate_sku_count;

\echo
\echo ===== [AMBIGUOUS TOKEN SCORING SUMMARY] =====
SELECT
  COUNT(DISTINCT mk_row_id) AS ambiguous_rows,
  COUNT(DISTINCT own_sku_code) AS distinct_own_sku_code,
  COUNT(*) AS candidate_rows,
  COUNT(*) FILTER (WHERE diagnostic_label = 'possible_auto_resolution_candidate_strong_token') AS strong_unique_top1_rows,
  COUNT(*) FILTER (WHERE diagnostic_label = 'possible_auto_resolution_candidate_weak_token') AS weak_unique_top1_rows,
  COUNT(*) FILTER (WHERE diagnostic_label = 'manual_review_required') AS manual_review_required_rows
FROM row_diagnostic;

\echo
\echo ===== [AMBIGUOUS TOKEN SCORING TOP1 SAMPLE] =====
SELECT
  r.diagnostic_label,
  c.product_uid,
  c.channel_sku_code,
  c.sto_id AS sto_id_raw,
  c.own_sku_code,
  c.candidate_sku_count,
  c.candidate_sku_id,
  c.candidate_option_value,
  c.candidate_virtual_sku_code,
  c.candidate_product_name,
  c.selfpia_sku_aliases,
  c.selfpia_product_aliases,
  c.selfpia_option_nos,
  c.token_score,
  c.option_exact_match,
  c.option_partial_match,
  c.number_token_match,
  c.selfpia_option_no_matches_sto_id,
  c.opt_values,
  c.makeshop_product_name,
  c.barcode
FROM ranked_candidates c
JOIN row_diagnostic r
  ON r.mk_row_id = c.mk_row_id
WHERE c.score_rank = 1
ORDER BY r.diagnostic_label, c.token_score DESC, c.product_uid, c.sto_id
LIMIT 300;

\echo
\echo ===== [AMBIGUOUS OWN SKU CANDIDATE COUNT] =====
SELECT
  own_sku_code,
  COUNT(DISTINCT mk_row_id) AS rows,
  max(candidate_sku_count) AS candidate_sku_count,
  COUNT(*) FILTER (WHERE diagnostic_label = 'possible_auto_resolution_candidate_strong_token') AS strong_unique_top1_rows,
  COUNT(*) FILTER (WHERE diagnostic_label = 'possible_auto_resolution_candidate_weak_token') AS weak_unique_top1_rows,
  COUNT(*) FILTER (WHERE diagnostic_label = 'manual_review_required') AS manual_review_required_rows
FROM row_diagnostic
GROUP BY own_sku_code
ORDER BY rows DESC, own_sku_code
LIMIT 100;

ROLLBACK;

\echo
\echo diagnose_makeshop_ambiguous_token_scoring.sql complete. ROLLBACK applied. No persistent changes.
