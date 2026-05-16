-- =============================================================================
-- postcheck_makeshop_auto_confirm_v3.sql
--
-- Read-only postcheck after running apply_makeshop_auto_confirm_v3.sql.
--
-- Source CSV inside Docker container:
--   /tmp/makeshop_auto_confirm_candidates_v3.csv
--
-- Target:
--   product_code.sku_channel_mapping
--
-- Safety:
--   - product_ops_test guard
--   - TEMP TABLE only
--   - SELECT only
--   - No persistent DB changes
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'postcheck_makeshop_auto_confirm_v3.sql is allowed only on product_ops_test. Current database: %',
      current_database();
  END IF;
END
$$;

BEGIN;

CREATE TEMP TABLE stg_makeshop_auto_confirm_v3 (
  channel_code                         text,
  seller_product_code_raw              text,
  channel_sku_code                     text,
  sto_id_raw                           text,
  sto_code                             text,
  opt_value                            text,
  opt_values                           text,
  own_sku_code                         text,
  extraction_method                    text,
  regex_pattern_used                   text,
  auto_confirm_type                    text,
  matched_sku_id                       text,
  matched_virtual_sku_code             text,
  matched_option_value                 text,
  matched_product_id                   text,
  matched_product_name                 text,
  makeshop_product_name                text,
  barcode                              text,
  repeated_matched_sku_count           text,
  repeated_matched_sku_3plus_flag      text,
  v2_selected_own_sku_code             text,
  v2_selected_matched_sku_id           text,
  changed_from_v2_flag                 text,
  source_note                          text
);

\copy stg_makeshop_auto_confirm_v3 FROM '/tmp/makeshop_auto_confirm_candidates_v3.csv' WITH (FORMAT CSV, HEADER true, ENCODING 'UTF8')

CREATE TEMP TABLE source_normalized AS
SELECT
  s.*,
  NULLIF(btrim(s.channel_sku_code), '') AS normalized_channel_sku_code,
  CASE
    WHEN NULLIF(btrim(s.matched_sku_id), '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      THEN NULLIF(btrim(s.matched_sku_id), '')::uuid
    ELSE NULL
  END AS matched_sku_id_uuid,
  (lower(COALESCE(s.repeated_matched_sku_3plus_flag, '')) IN ('t', 'true', '1', 'yes')) AS repeated_matched_sku_3plus_bool,
  (lower(COALESCE(s.changed_from_v2_flag, '')) IN ('t', 'true', '1', 'yes')) AS changed_from_v2_bool
FROM stg_makeshop_auto_confirm_v3 s;

\echo
\echo ===== [POSTCHECK MAKESHOP AUTO CONFIRM V3 SUMMARY] =====
SELECT
  (SELECT COUNT(*) FROM source_normalized) AS source_rows,
  11179::integer AS expected_rows,
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping scm WHERE scm.channel_code = 'makeshop') AS makeshop_mapping_rows,
  (SELECT COUNT(*)
   FROM source_normalized s
   JOIN product_code.sku_channel_mapping scm
     ON scm.channel_code = 'makeshop'
    AND scm.channel_sku_code = s.normalized_channel_sku_code
    AND scm.sku_id = s.matched_sku_id_uuid) AS matched_source_rows,
  (SELECT COUNT(*)
   FROM source_normalized s
   LEFT JOIN product_code.sku_channel_mapping scm
     ON scm.channel_code = 'makeshop'
    AND scm.channel_sku_code = s.normalized_channel_sku_code
   WHERE scm.id IS NULL) AS missing_mapping_rows,
  (SELECT COUNT(*)
   FROM source_normalized s
   JOIN product_code.sku_channel_mapping scm
     ON scm.channel_code = 'makeshop'
    AND scm.channel_sku_code = s.normalized_channel_sku_code
    AND scm.sku_id IS DISTINCT FROM s.matched_sku_id_uuid) AS conflict_rows,
  (SELECT COUNT(*)
   FROM (
     SELECT channel_sku_code
     FROM product_code.sku_channel_mapping
     WHERE channel_code = 'makeshop'
     GROUP BY channel_sku_code
     HAVING COUNT(*) > 1
   ) d) AS duplicate_channel_sku_code_keys,
  (SELECT COUNT(*)
   FROM source_normalized
   WHERE normalized_channel_sku_code IS NULL OR matched_sku_id_uuid IS NULL) AS null_key_or_missing_sku_rows,
  (SELECT COUNT(*) FROM source_normalized WHERE auto_confirm_type = 'new_regex_candidate') AS new_regex_candidate_rows,
  (SELECT COUNT(*) FROM source_normalized WHERE changed_from_v2_bool) AS changed_from_v2_rows,
  (SELECT COUNT(*) FROM source_normalized WHERE repeated_matched_sku_3plus_bool) AS repeated_matched_sku_3plus_rows;

\echo
\echo ===== [POSTCHECK DUPLICATE MAKESHOP KEYS] =====
SELECT
  channel_code,
  channel_sku_code,
  COUNT(*) AS rows,
  array_agg(sku_id ORDER BY sku_id) AS sku_ids
FROM product_code.sku_channel_mapping
WHERE channel_code = 'makeshop'
GROUP BY channel_code, channel_sku_code
HAVING COUNT(*) > 1
ORDER BY rows DESC, channel_sku_code
LIMIT 100;

\echo
\echo ===== [POSTCHECK CONFLICT SAMPLE] =====
SELECT
  s.channel_sku_code,
  s.seller_product_code_raw,
  s.sto_id_raw,
  s.own_sku_code,
  s.matched_sku_id_uuid AS expected_sku_id,
  scm.id AS existing_mapping_id,
  scm.sku_id AS mapped_sku_id
FROM source_normalized s
JOIN product_code.sku_channel_mapping scm
  ON scm.channel_code = 'makeshop'
 AND scm.channel_sku_code = s.normalized_channel_sku_code
 AND scm.sku_id IS DISTINCT FROM s.matched_sku_id_uuid
ORDER BY s.seller_product_code_raw, s.sto_id_raw
LIMIT 100;

\echo
\echo ===== [POSTCHECK MISSING SAMPLE] =====
SELECT
  s.channel_sku_code,
  s.seller_product_code_raw,
  s.sto_id_raw,
  s.own_sku_code,
  s.matched_sku_id_uuid AS expected_sku_id
FROM source_normalized s
LEFT JOIN product_code.sku_channel_mapping scm
  ON scm.channel_code = 'makeshop'
 AND scm.channel_sku_code = s.normalized_channel_sku_code
WHERE scm.id IS NULL
ORDER BY s.seller_product_code_raw, s.sto_id_raw
LIMIT 100;

ROLLBACK;

\echo
\echo postcheck_makeshop_auto_confirm_v3.sql complete. Read-only postcheck finished. No persistent DB changes.
