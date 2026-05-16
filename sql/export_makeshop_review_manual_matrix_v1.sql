-- =============================================================================
-- export_makeshop_review_manual_matrix_v1.sql
--
-- SELECT-only MakeShop review_required manual matrix export v1.
--
-- Purpose:
--   Split remaining review_required rows after auto_confirm v3 local apply into
--   human-reviewable CSV files.
--
-- CSV input path inside Docker container:
--   /tmp/makeshop_minimal_full.csv
--
-- Output CSV files:
--   /tmp/makeshop_review_ambiguous_weak_top1_matrix.csv
--   /tmp/makeshop_review_ambiguous_manual_matrix.csv
--   /tmp/makeshop_review_not_in_alias_matrix.csv
--   /tmp/makeshop_review_null_key_matrix.csv
--   /tmp/makeshop_review_pattern_loose_matrix.csv
--
-- Safety:
--   - product_ops_test guard
--   - TEMP TABLE only
--   - SELECT and \copy only
--   - BEGIN ... ROLLBACK
--   - No persistent DB changes
--   - No review target apply
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'export_makeshop_review_manual_matrix_v1.sql is allowed only on product_ops_test. Current database: %',
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
    substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+-[0-9]+)\]') AS opt_values_4part_bracket,
    substring(COALESCE(s.opt_value, '') || ' ' || COALESCE(s.opt_values, '')
              FROM '([A-Za-z]+-[0-9]+-[0-9]+-[0-9]+)') AS loose_4part_candidate
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
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> '' THEN 'sto_code'
    WHEN b.opt_values_existing_bracket IS NOT NULL THEN 'opt_values_bracket'
    WHEN b.opt_values_4part_bracket IS NOT NULL THEN 'opt_values_4part_bracket'
    WHEN b.opt_value_existing_bracket IS NOT NULL THEN 'opt_value_bracket'
    WHEN b.opt_value_4part_bracket IS NOT NULL THEN 'opt_value_4part_bracket'
    ELSE NULL
  END AS extraction_method,
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> '' THEN 'sto_code_exact'
    WHEN b.opt_values_existing_bracket IS NOT NULL THEN 'existing_bracket'
    WHEN b.opt_values_4part_bracket IS NOT NULL THEN 'bracket_4part'
    WHEN b.opt_value_existing_bracket IS NOT NULL THEN 'existing_bracket'
    WHEN b.opt_value_4part_bracket IS NOT NULL THEN 'bracket_4part'
    ELSE NULL
  END AS regex_pattern_used,
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> '' THEN 'existing'
    WHEN b.opt_values_existing_bracket IS NOT NULL THEN 'existing'
    WHEN b.opt_values_4part_bracket IS NOT NULL THEN 'new_regex'
    WHEN b.opt_value_existing_bracket IS NOT NULL THEN 'existing'
    WHEN b.opt_value_4part_bracket IS NOT NULL THEN 'new_regex'
    ELSE NULL
  END AS extraction_family,
  CASE
    WHEN b.product_uid IS NOT NULL AND btrim(b.product_uid) <> ''
     AND b.sto_id IS NOT NULL AND btrim(b.sto_id) <> ''
      THEN btrim(b.product_uid) || '-' || btrim(b.sto_id)
    ELSE NULL
  END AS channel_sku_code,
  CASE
    WHEN b.loose_4part_candidate IS NOT NULL
     AND b.opt_value_4part_bracket IS NULL
     AND b.opt_values_4part_bracket IS NULL
     AND b.opt_value_existing_bracket IS NULL
     AND b.opt_values_existing_bracket IS NULL
     AND (b.sto_code IS NULL OR btrim(b.sto_code) = '')
      THEN true
    ELSE false
  END AS loose_regex_only_flag
FROM base b;

CREATE TEMP TABLE mk_match_agg AS
SELECT
  e.*,
  COUNT(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL) AS match_count,
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
  e.mk_row_id, e.product_uid, e.sto_id, e.sto_code, e.opt_value, e.opt_values,
  e.barcode, e.product_name, e.status, e.gid, e.ps_num, e.opt_value_existing_bracket,
  e.opt_values_existing_bracket, e.opt_value_4part_bracket, e.opt_values_4part_bracket,
  e.loose_4part_candidate, e.own_sku_candidate, e.extraction_method,
  e.regex_pattern_used, e.extraction_family, e.channel_sku_code,
  e.loose_regex_only_flag;

CREATE TEMP TABLE mk_classified AS
SELECT
  m.*,
  scm.id AS existing_mapping_id,
  scm.sku_id AS existing_mapped_sku_id,
  sm.status AS sku_master_status,
  CASE
    WHEN m.product_uid IS NULL OR btrim(m.product_uid) = ''
      OR m.sto_id IS NULL OR btrim(m.sto_id) = '' THEN 'null_key'
    WHEN m.own_sku_candidate IS NULL OR btrim(m.own_sku_candidate) = '' THEN
      CASE WHEN m.loose_regex_only_flag THEN 'loose_regex_only' ELSE 'pattern_unmatched' END
    WHEN m.match_count = 0 THEN 'own_sku_not_in_alias'
    WHEN m.match_count > 1 THEN 'own_sku_ambiguous'
    WHEN scm.id IS NOT NULL AND scm.sku_id IS DISTINCT FROM m.resolved_sku_id THEN 'channel_sku_conflict'
    WHEN sm.status IS NOT NULL
     AND (sm.status ILIKE '%inactive%' OR sm.status ILIKE '%deleted%' OR sm.status ILIKE '%archive%') THEN 'sku_inactive'
    WHEN scm.id IS NOT NULL AND scm.sku_id IS NOT DISTINCT FROM m.resolved_sku_id THEN 'already_applied_auto_confirm'
    WHEN m.match_count = 1 AND m.extraction_family IN ('existing', 'new_regex') THEN 'unapplied_auto_candidate'
    ELSE 'review_required'
  END AS reason
FROM mk_match_agg m
LEFT JOIN product_code.sku_channel_mapping scm
  ON scm.channel_code = 'makeshop'
 AND scm.channel_sku_code = m.channel_sku_code
 AND m.channel_sku_code IS NOT NULL
LEFT JOIN product_code.sku_master sm
  ON sm.id = m.resolved_sku_id;

CREATE TEMP TABLE ambiguous_rows AS
SELECT
  c.*,
  c.match_count AS candidate_sku_count,
  lower(regexp_replace(COALESCE(c.opt_values, ''), '[^[:alnum:]]+', ' ', 'g')) AS opt_values_norm,
  regexp_replace(COALESCE(c.opt_values, ''), '[^0-9]+', ' ', 'g') AS opt_values_numbers
FROM mk_classified c
WHERE c.reason = 'own_sku_ambiguous';

CREATE TEMP TABLE ambiguous_candidate_matrix AS
SELECT
  ar.mk_row_id,
  ar.reason,
  ar.product_uid,
  ar.channel_sku_code,
  ar.sto_id,
  ar.sto_code,
  ar.opt_value,
  ar.opt_values,
  ar.opt_values_norm,
  ar.opt_values_numbers,
  ar.product_name AS makeshop_product_name,
  ar.barcode,
  ar.own_sku_candidate AS own_sku_code,
  ar.extraction_method,
  ar.regex_pattern_used,
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
      THEN 'strong_unique_top1'
    WHEN max(top_score) > 0 AND max(top_score_tied_count) = 1
      THEN 'weak_unique_top1'
    ELSE 'manual_review_required'
  END AS diagnostic_label
FROM ranked_candidates
GROUP BY mk_row_id, product_uid, channel_sku_code, sto_id, own_sku_code, candidate_sku_count;

CREATE TEMP TABLE ambiguous_weak_top1_export AS
SELECT
  c.reason,
  r.diagnostic_label,
  c.product_uid,
  c.channel_sku_code,
  c.sto_id AS sto_id_raw,
  c.own_sku_code,
  c.candidate_sku_count,
  c.candidate_sku_id AS top1_candidate_sku_id,
  c.candidate_virtual_sku_code AS top1_virtual_sku_code,
  c.candidate_option_value AS top1_option_value,
  c.candidate_product_name AS top1_product_name,
  array_to_string(c.selfpia_sku_aliases, '|') AS top1_selfpia_sku_aliases,
  c.token_score,
  c.opt_values,
  c.makeshop_product_name,
  c.barcode,
  ''::text AS review_action_blank
FROM ranked_candidates c
JOIN row_diagnostic r
  ON r.mk_row_id = c.mk_row_id
WHERE r.diagnostic_label = 'weak_unique_top1'
  AND c.score_rank = 1;

CREATE TEMP TABLE ambiguous_manual_export AS
SELECT
  r.diagnostic_label,
  c.reason,
  c.product_uid,
  c.channel_sku_code,
  c.sto_id AS sto_id_raw,
  c.own_sku_code,
  c.candidate_sku_count,
  r.top_score AS top_token_score,
  r.top1_tied_candidate_count,
  array_to_string(array_agg(c.candidate_sku_id ORDER BY c.token_score DESC, c.candidate_sku_id), '|') AS candidate_sku_ids,
  array_to_string(array_agg(COALESCE(c.candidate_virtual_sku_code, '') ORDER BY c.token_score DESC, c.candidate_sku_id), '|') AS candidate_virtual_sku_codes,
  array_to_string(array_agg(COALESCE(c.candidate_option_value, '') ORDER BY c.token_score DESC, c.candidate_sku_id), '|') AS candidate_option_values,
  array_to_string(array_agg(COALESCE(c.candidate_product_name, '') ORDER BY c.token_score DESC, c.candidate_sku_id), '|') AS candidate_product_names,
  array_to_string(array_agg(COALESCE(array_to_string(c.selfpia_sku_aliases, '/'), '') ORDER BY c.token_score DESC, c.candidate_sku_id), '|') AS candidate_selfpia_sku_aliases,
  array_to_string(array_agg(c.token_score::text ORDER BY c.token_score DESC, c.candidate_sku_id), '|') AS candidate_token_scores,
  c.opt_values,
  c.makeshop_product_name,
  c.barcode,
  ''::text AS review_action_blank
FROM ranked_candidates c
JOIN row_diagnostic r
  ON r.mk_row_id = c.mk_row_id
WHERE r.diagnostic_label = 'manual_review_required'
GROUP BY
  r.diagnostic_label, c.reason, c.mk_row_id, c.product_uid, c.channel_sku_code,
  c.sto_id, c.own_sku_code, c.candidate_sku_count, r.top_score,
  r.top1_tied_candidate_count, c.opt_values, c.makeshop_product_name, c.barcode;

CREATE TEMP TABLE not_in_alias_export AS
WITH not_in_alias_rows AS (
  SELECT *
  FROM mk_classified
  WHERE reason = 'own_sku_not_in_alias'
),
ranked_not_in_alias_rows AS (
  SELECT
    r.*,
    row_number() OVER (
      PARTITION BY r.own_sku_candidate
      ORDER BY r.product_uid NULLS LAST, r.sto_id NULLS LAST, r.mk_row_id
    ) AS rn,
    count(*) OVER (PARTITION BY r.own_sku_candidate) AS row_count
  FROM not_in_alias_rows r
)
SELECT
  own_sku_candidate AS own_sku_code,
  row_count,
  CASE WHEN rn = 1 THEN true ELSE false END AS representative_row_flag,
  product_uid,
  channel_sku_code,
  sto_id AS sto_id_raw,
  extraction_method,
  regex_pattern_used,
  opt_values,
  opt_value,
  product_name AS makeshop_product_name,
  barcode,
  ''::text AS suggested_action_blank
FROM ranked_not_in_alias_rows;

CREATE TEMP TABLE null_key_export AS
SELECT
  reason,
  CASE
    WHEN product_uid IS NULL OR btrim(product_uid) = '' THEN 'product_uid_blank'
    WHEN sto_id IS NULL OR btrim(sto_id) = '' THEN 'sto_id_blank'
    ELSE 'key_blank'
  END AS diagnostic_label,
  product_uid,
  channel_sku_code,
  sto_id AS sto_id_raw,
  sto_code AS sto_code_raw,
  own_sku_candidate AS own_sku_code,
  opt_value,
  opt_values,
  product_name AS makeshop_product_name,
  barcode,
  status AS makeshop_status,
  gid,
  ps_num,
  ''::text AS review_action_blank
FROM mk_classified
WHERE reason = 'null_key';

CREATE TEMP TABLE pattern_loose_export AS
SELECT
  reason,
  CASE
    WHEN reason = 'loose_regex_only' THEN 'loose_4part_regex_hit_only'
    ELSE 'pattern_unmatched'
  END AS diagnostic_label,
  product_uid,
  channel_sku_code,
  sto_id AS sto_id_raw,
  sto_code AS sto_code_raw,
  own_sku_candidate AS own_sku_code,
  loose_4part_candidate,
  opt_value,
  opt_values,
  product_name AS makeshop_product_name,
  barcode,
  status AS makeshop_status,
  gid,
  ps_num,
  ''::text AS suggested_regex_or_action_blank
FROM mk_classified
WHERE reason IN ('pattern_unmatched', 'loose_regex_only');

\copy (SELECT * FROM ambiguous_weak_top1_export ORDER BY own_sku_code, product_uid, sto_id_raw, channel_sku_code) TO '/tmp/makeshop_review_ambiguous_weak_top1_matrix.csv' WITH (FORMAT CSV, HEADER true, ENCODING 'UTF8')

\copy (SELECT * FROM ambiguous_manual_export ORDER BY own_sku_code, product_uid, sto_id_raw, channel_sku_code) TO '/tmp/makeshop_review_ambiguous_manual_matrix.csv' WITH (FORMAT CSV, HEADER true, ENCODING 'UTF8')

\copy (SELECT * FROM not_in_alias_export ORDER BY row_count DESC, own_sku_code) TO '/tmp/makeshop_review_not_in_alias_matrix.csv' WITH (FORMAT CSV, HEADER true, ENCODING 'UTF8')

\copy (SELECT * FROM null_key_export ORDER BY product_uid NULLS LAST, sto_id_raw NULLS LAST, makeshop_product_name) TO '/tmp/makeshop_review_null_key_matrix.csv' WITH (FORMAT CSV, HEADER true, ENCODING 'UTF8')

\copy (SELECT * FROM pattern_loose_export ORDER BY reason, product_uid, sto_id_raw, channel_sku_code) TO '/tmp/makeshop_review_pattern_loose_matrix.csv' WITH (FORMAT CSV, HEADER true, ENCODING 'UTF8')

\echo
\echo ===== [EXPORT REVIEW MANUAL MATRIX V1 SUMMARY] =====
SELECT
  (SELECT COUNT(*) FROM mk_src) AS total_rows,
  (SELECT COUNT(*) FROM mk_classified WHERE reason = 'already_applied_auto_confirm') AS already_applied_makeshop_rows,
  (SELECT COUNT(*) FROM mk_classified WHERE reason NOT IN ('already_applied_auto_confirm', 'unapplied_auto_candidate')) AS review_required_rows,
  (SELECT COUNT(*) FROM mk_classified WHERE reason = 'unapplied_auto_candidate') AS unapplied_auto_candidate_rows,
  (SELECT COUNT(*) FROM mk_classified WHERE reason = 'channel_sku_conflict') AS existing_mapping_different_sku,
  (SELECT COUNT(*) FROM ambiguous_weak_top1_export) AS ambiguous_weak_top1_export_rows,
  (SELECT COUNT(*) FROM ambiguous_manual_export) AS ambiguous_manual_export_rows,
  (SELECT COUNT(DISTINCT own_sku_code) FROM not_in_alias_export) AS not_in_alias_export_codes,
  (SELECT COUNT(*) FROM not_in_alias_export) AS not_in_alias_export_rows,
  (SELECT COUNT(*) FROM not_in_alias_export WHERE representative_row_flag) AS not_in_alias_representative_rows,
  (SELECT COUNT(*) FROM null_key_export) AS null_key_export_rows,
  (SELECT COUNT(*) FROM pattern_loose_export) AS pattern_loose_export_rows;

\echo
\echo ===== [REVIEW REQUIRED BY REASON] =====
SELECT
  reason,
  COUNT(*) AS rows
FROM mk_classified
WHERE reason NOT IN ('already_applied_auto_confirm', 'unapplied_auto_candidate')
GROUP BY reason
ORDER BY rows DESC, reason;

\echo
\echo Exported CSV files:
\echo /tmp/makeshop_review_ambiguous_weak_top1_matrix.csv
\echo /tmp/makeshop_review_ambiguous_manual_matrix.csv
\echo /tmp/makeshop_review_not_in_alias_matrix.csv
\echo /tmp/makeshop_review_null_key_matrix.csv
\echo /tmp/makeshop_review_pattern_loose_matrix.csv

ROLLBACK;

\echo
\echo export_makeshop_review_manual_matrix_v1.sql complete. ROLLBACK applied. No persistent DB changes.
