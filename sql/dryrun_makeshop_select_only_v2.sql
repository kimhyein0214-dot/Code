-- =============================================================================
-- dryrun_makeshop_select_only_v2.sql
--
-- SELECT-only MakeShop mapping dryrun v2.
--
-- v2 changes:
--   - Keeps the existing own_sku extraction chain:
--       sto_code -> opt_value existing bracket -> opt_values existing bracket
--   - Adds bracketed 4-part own_sku recovery:
--       opt_value [ALPHA-NN-NN-N] / [ALPHA-NN-NN-NN]
--       opt_values [ALPHA-NN-NN-N] / [ALPHA-NN-NN-NN]
--   - Dedupes row-level extraction into one chosen own_sku candidate.
--   - Keeps loose 4-part regex diagnostic-only, never auto-confirms it.
--   - Flags repeated matched_sku_id / own_sku_code among existing auto-confirm rows.
--   - Does not auto-resolve ambiguous rows. Only emits token diagnostic samples.
--
-- Safety:
--   - product_ops_test guard
--   - TEMP TABLE only
--   - SELECT / \copy only
--   - BEGIN ... ROLLBACK
--   - No persistent DB changes
--
-- CSV input path inside Docker container:
--   /tmp/makeshop_minimal_full.csv
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'dryrun v2 is allowed only on product_ops_test. Current database: %',
      current_database();
  END IF;
END
$$;

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Raw landing
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 2. Regex extraction with explicit priority and diagnostic loose candidate.
--    Existing regex keeps prior dryrun behavior. New 4-part regex is bracketed
--    only and is classified separately.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE mk_extracted AS
WITH base AS (
  SELECT
    row_number() OVER () AS mk_row_id,
    s.product_uid,
    s.sto_id,
    s.sto_code,
    s.opt_value,
    s.opt_values,
    s.barcode,
    s.product_name,
    s.status AS source_status,
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
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> ''
      THEN btrim(b.sto_code)
    WHEN b.opt_value_existing_bracket IS NOT NULL
      THEN b.opt_value_existing_bracket
    WHEN b.opt_values_existing_bracket IS NOT NULL
      THEN b.opt_values_existing_bracket
    WHEN b.opt_value_4part_bracket IS NOT NULL
      THEN b.opt_value_4part_bracket
    WHEN b.opt_values_4part_bracket IS NOT NULL
      THEN b.opt_values_4part_bracket
    ELSE NULL
  END AS own_sku_candidate,
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> ''
      THEN 'sto_code'
    WHEN b.opt_value_existing_bracket IS NOT NULL
      THEN 'opt_value_bracket'
    WHEN b.opt_values_existing_bracket IS NOT NULL
      THEN 'opt_values_bracket'
    WHEN b.opt_value_4part_bracket IS NOT NULL
      THEN 'opt_value_4part_bracket'
    WHEN b.opt_values_4part_bracket IS NOT NULL
      THEN 'opt_values_4part_bracket'
    ELSE NULL
  END AS extraction_method,
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> ''
      THEN 'sto_code_exact'
    WHEN b.opt_value_existing_bracket IS NOT NULL
      THEN 'existing_bracket'
    WHEN b.opt_values_existing_bracket IS NOT NULL
      THEN 'existing_bracket'
    WHEN b.opt_value_4part_bracket IS NOT NULL
      THEN 'bracket_4part'
    WHEN b.opt_values_4part_bracket IS NOT NULL
      THEN 'bracket_4part'
    ELSE NULL
  END AS regex_pattern_used,
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> ''
      THEN 'existing'
    WHEN b.opt_value_existing_bracket IS NOT NULL
      THEN 'existing'
    WHEN b.opt_values_existing_bracket IS NOT NULL
      THEN 'existing'
    WHEN b.opt_value_4part_bracket IS NOT NULL
      THEN 'new_regex'
    WHEN b.opt_values_4part_bracket IS NOT NULL
      THEN 'new_regex'
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

-- ---------------------------------------------------------------------------
-- 3. Match chosen own_sku candidate against own_sku aliases.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE mk_match_agg AS
SELECT
  e.*,
  COUNT(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL) AS match_count,
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
  e.mk_row_id, e.product_uid, e.sto_id, e.sto_code, e.opt_value, e.opt_values,
  e.barcode, e.product_name, e.source_status, e.opt_value_existing_bracket,
  e.opt_values_existing_bracket, e.opt_value_4part_bracket,
  e.opt_values_4part_bracket, e.loose_4part_candidate, e.own_sku_candidate,
  e.extraction_method, e.regex_pattern_used, e.extraction_family,
  e.channel_sku_code, e.loose_regex_only_flag;

-- ---------------------------------------------------------------------------
-- 4. Conflict/status lookup and v2 classification.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE mk_classified_base AS
SELECT
  m.*,
  scm.id AS existing_mapping_id,
  scm.sku_id AS existing_mapped_sku_id,
  scm.is_primary AS existing_is_primary,
  sm.status AS sku_master_status,
  CASE
    WHEN m.product_uid IS NULL OR btrim(m.product_uid) = ''
      OR m.sto_id IS NULL OR btrim(m.sto_id) = ''
      THEN 'review_null_key'
    WHEN m.own_sku_candidate IS NULL OR btrim(m.own_sku_candidate) = ''
      THEN CASE
        WHEN m.loose_regex_only_flag THEN 'review_loose_regex_only'
        ELSE 'review_pattern_unmatched'
      END
    WHEN m.match_count = 0
      THEN 'review_not_in_alias'
    WHEN m.match_count > 1
      THEN 'review_ambiguous'
    WHEN scm.id IS NOT NULL
      THEN 'channel_sku_conflict'
    WHEN sm.status IS NOT NULL
     AND (sm.status ILIKE '%inactive%' OR sm.status ILIKE '%deleted%' OR sm.status ILIKE '%archive%')
      THEN 'sku_inactive'
    ELSE NULL
  END AS review_reason,
  CASE
    WHEN m.product_uid IS NOT NULL AND btrim(m.product_uid) <> ''
     AND m.sto_id IS NOT NULL AND btrim(m.sto_id) <> ''
     AND m.own_sku_candidate IS NOT NULL AND btrim(m.own_sku_candidate) <> ''
     AND m.match_count = 1
     AND scm.id IS NULL
     AND NOT (
       sm.status IS NOT NULL
       AND (sm.status ILIKE '%inactive%' OR sm.status ILIKE '%deleted%' OR sm.status ILIKE '%archive%')
     )
     AND m.extraction_family = 'existing'
      THEN 'auto_confirm_existing_regex'
    WHEN m.product_uid IS NOT NULL AND btrim(m.product_uid) <> ''
     AND m.sto_id IS NOT NULL AND btrim(m.sto_id) <> ''
     AND m.own_sku_candidate IS NOT NULL AND btrim(m.own_sku_candidate) <> ''
     AND m.match_count = 1
     AND scm.id IS NULL
     AND NOT (
       sm.status IS NOT NULL
       AND (sm.status ILIKE '%inactive%' OR sm.status ILIKE '%deleted%' OR sm.status ILIKE '%archive%')
     )
     AND m.extraction_family = 'new_regex'
      THEN 'auto_confirm_new_regex_candidate'
    ELSE 'review_required'
  END AS classification
FROM mk_match_agg m
LEFT JOIN product_code.sku_channel_mapping scm
  ON scm.channel_code = 'makeshop'
 AND scm.channel_sku_code = m.channel_sku_code
 AND m.channel_sku_code IS NOT NULL
LEFT JOIN product_code.sku_master sm
  ON sm.id = m.resolved_sku_id;

-- ---------------------------------------------------------------------------
-- 5. Repeated auto-confirm flags. These are diagnostic flags only and do not
--    remove rows from auto-confirm classification.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE auto_existing_repeat_stats AS
SELECT
  resolved_sku_id,
  own_sku_candidate,
  COUNT(*) AS repeated_matched_sku_count,
  COUNT(DISTINCT product_uid) AS repeated_across_product_uid_count,
  array_agg(channel_sku_code ORDER BY product_uid, sto_id) AS sample_channel_sku_codes
FROM mk_classified_base
WHERE classification = 'auto_confirm_existing_regex'
GROUP BY resolved_sku_id, own_sku_candidate;

CREATE TEMP TABLE mk_classified AS
SELECT
  c.*,
  COALESCE(rs.repeated_matched_sku_count, 0) AS repeated_matched_sku_count,
  COALESCE(rs.repeated_matched_sku_count, 0) >= 3 AS repeated_matched_sku_flag,
  COALESCE(rs.repeated_matched_sku_count, 0) AS repeated_own_sku_count,
  COALESCE(rs.repeated_across_product_uid_count, 0) AS repeated_across_product_uid_count,
  rs.sample_channel_sku_codes AS repeated_sample_channel_sku_codes
FROM mk_classified_base c
LEFT JOIN auto_existing_repeat_stats rs
  ON rs.resolved_sku_id IS NOT DISTINCT FROM c.resolved_sku_id
 AND rs.own_sku_candidate IS NOT DISTINCT FROM c.own_sku_candidate;

-- ---------------------------------------------------------------------------
-- 6. Ambiguous token diagnostic enrichment. No auto-resolution.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE ambiguous_code_summary AS
SELECT
  own_sku_candidate,
  COUNT(*) AS ambiguous_rows,
  COUNT(DISTINCT product_uid) AS distinct_product_uid,
  COUNT(DISTINCT channel_sku_code) AS distinct_channel_sku_code,
  MAX(match_count) AS candidate_sku_count
FROM mk_classified
WHERE review_reason = 'review_ambiguous'
GROUP BY own_sku_candidate;

CREATE TEMP TABLE ambiguous_candidate_enriched AS
SELECT
  c.mk_row_id,
  c.product_uid,
  c.sto_id,
  c.channel_sku_code,
  c.own_sku_candidate,
  c.extraction_method,
  c.regex_pattern_used,
  c.match_count AS candidate_sku_count,
  c.candidate_sku_ids,
  c.opt_value,
  c.opt_values,
  COALESCE(c.opt_values, c.opt_value) AS makeshop_option_text,
  c.product_name AS makeshop_product_name,
  c.barcode,
  array_agg(DISTINCT sm.option_value ORDER BY sm.option_value)
    FILTER (WHERE sm.option_value IS NOT NULL AND btrim(sm.option_value) <> '') AS candidate_option_values,
  array_agg(DISTINCT selfpia.code_value ORDER BY selfpia.code_value)
    FILTER (WHERE selfpia.code_value IS NOT NULL AND btrim(selfpia.code_value) <> '') AS candidate_selfpia_sku_codes
FROM mk_classified c
JOIN product_code.code_alias own
  ON own.target_type = 'SKU'
 AND own.code_system = 'own_sku'
 AND own.code_value = c.own_sku_candidate
JOIN product_code.sku_master sm
  ON sm.id = own.target_id
LEFT JOIN product_code.code_alias selfpia
  ON selfpia.target_type = 'SKU'
 AND selfpia.target_id = sm.id
 AND selfpia.code_system = 'selfpia_sku'
WHERE c.review_reason = 'review_ambiguous'
GROUP BY
  c.mk_row_id, c.product_uid, c.sto_id, c.channel_sku_code,
  c.own_sku_candidate, c.extraction_method, c.regex_pattern_used, c.match_count,
  c.candidate_sku_ids, c.opt_value, c.opt_values, c.product_name, c.barcode;

-- ---------------------------------------------------------------------------
-- 7. Result sets
-- ---------------------------------------------------------------------------
\echo
\echo ===== [V2 SUMMARY] =====
SELECT
  COUNT(*) AS total_rows,
  COUNT(*) FILTER (WHERE classification = 'auto_confirm_existing_regex') AS auto_confirm_existing_regex,
  COUNT(*) FILTER (WHERE classification = 'auto_confirm_new_regex_candidate') AS auto_confirm_new_regex_candidate,
  COUNT(*) FILTER (WHERE classification = 'review_required') AS review_required,
  COUNT(*) FILTER (WHERE review_reason = 'review_null_key') AS null_key,
  COUNT(*) FILTER (WHERE review_reason = 'review_pattern_unmatched') AS pattern_unmatched,
  COUNT(*) FILTER (WHERE review_reason = 'review_not_in_alias') AS own_sku_not_in_alias,
  COUNT(*) FILTER (WHERE review_reason = 'review_ambiguous') AS own_sku_ambiguous,
  COUNT(*) FILTER (WHERE review_reason = 'channel_sku_conflict') AS channel_sku_conflict,
  COUNT(*) FILTER (WHERE review_reason = 'sku_inactive') AS sku_inactive,
  COUNT(*) FILTER (WHERE review_reason = 'review_loose_regex_only') AS loose_regex_only,
  COUNT(*) FILTER (
    WHERE classification = 'auto_confirm_existing_regex'
      AND repeated_matched_sku_flag
  ) AS repeated_matched_sku_3plus_count,
  COUNT(DISTINCT resolved_sku_id) FILTER (
    WHERE classification = 'auto_confirm_existing_regex'
      AND repeated_matched_sku_flag
  ) AS repeated_matched_sku_3plus_keys
FROM mk_classified;

\echo
\echo ===== [V2 SUMMARY by extraction_method] =====
SELECT
  COALESCE(extraction_method, '(none)') AS extraction_method,
  COUNT(*) AS rows,
  COUNT(*) FILTER (WHERE classification = 'auto_confirm_existing_regex') AS auto_confirm_existing_regex,
  COUNT(*) FILTER (WHERE classification = 'auto_confirm_new_regex_candidate') AS auto_confirm_new_regex_candidate,
  COUNT(*) FILTER (WHERE classification = 'review_required') AS review_required
FROM mk_classified
GROUP BY extraction_method
ORDER BY 1;

\echo
\echo ===== [V2 NEW REGEX CANDIDATES] =====
SELECT
  channel_sku_code,
  product_uid AS seller_product_code_raw,
  sto_id AS sto_id_raw,
  own_sku_candidate AS own_sku_code,
  extraction_method,
  regex_pattern_used,
  resolved_sku_id AS matched_sku_id,
  product_name,
  opt_value,
  opt_values
FROM mk_classified
WHERE classification = 'auto_confirm_new_regex_candidate'
ORDER BY product_uid, sto_id
LIMIT 200;

\echo
\echo ===== [V2 REPEATED AUTO FLAGS] =====
SELECT
  resolved_sku_id AS matched_sku_id,
  own_sku_candidate AS own_sku_code,
  repeated_matched_sku_count AS repeated_count,
  repeated_across_product_uid_count AS distinct_product_uid_count,
  repeated_sample_channel_sku_codes AS sample_channel_sku_codes
FROM mk_classified
WHERE classification = 'auto_confirm_existing_regex'
  AND repeated_matched_sku_flag
GROUP BY
  resolved_sku_id,
  own_sku_candidate,
  repeated_matched_sku_count,
  repeated_across_product_uid_count,
  repeated_sample_channel_sku_codes
ORDER BY repeated_count DESC, own_sku_code
LIMIT 100;

\echo
\echo ===== [V2 AMBIGUOUS TOKEN DIAGNOSTIC SAMPLE] =====
WITH top_ambiguous AS (
  SELECT own_sku_candidate
  FROM ambiguous_code_summary
  ORDER BY ambiguous_rows DESC, candidate_sku_count DESC, own_sku_candidate
  LIMIT 50
)
SELECT
  ace.channel_sku_code,
  ace.product_uid AS seller_product_code_raw,
  ace.sto_id AS sto_id_raw,
  ace.own_sku_candidate AS own_sku_code,
  ace.extraction_method,
  ace.regex_pattern_used,
  ace.candidate_sku_count,
  ace.candidate_sku_ids,
  ace.candidate_option_values,
  ace.candidate_selfpia_sku_codes,
  ace.makeshop_option_text,
  ace.makeshop_product_name,
  ace.opt_value,
  ace.opt_values,
  ace.barcode
FROM ambiguous_candidate_enriched ace
JOIN top_ambiguous ta
  ON ta.own_sku_candidate = ace.own_sku_candidate
ORDER BY ace.own_sku_candidate, ace.product_uid, ace.sto_id
LIMIT 200;

\echo
\echo ===== [V2 CONFLICT] =====
SELECT
  'makeshop'::text AS channel_code,
  product_uid AS seller_product_code_raw,
  channel_sku_code,
  sto_id AS sto_id_raw,
  own_sku_candidate AS own_sku_code,
  resolved_sku_id AS would_be_sku_id,
  existing_mapping_id,
  existing_mapped_sku_id,
  existing_is_primary,
  CASE
    WHEN existing_mapped_sku_id IS NOT DISTINCT FROM resolved_sku_id
      THEN 'idempotent_same_sku'
    ELSE 'different_sku'
  END AS conflict_kind
FROM mk_classified
WHERE existing_mapping_id IS NOT NULL
ORDER BY product_uid, sto_id
LIMIT 200;

ROLLBACK;

\echo
\echo dryrun_makeshop_select_only_v2.sql complete. ROLLBACK applied. No persistent changes.
