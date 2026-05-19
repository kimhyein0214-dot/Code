/*
  Local-only Ably / PlayAuto stage import validation v1.

  DO NOT EXECUTE IN THIS STEP.

  Purpose:
  - SELECT-only checks to run after a future local stage import.
  - Validate raw and normalized stage quality before any evidence matching.

  Assumed local-only stage objects:
  - product_code_stage.ably_playauto_source_file
  - product_code_stage.ably_raw
  - product_code_stage.playauto_product_raw
  - product_code_stage.playauto_sku_raw
  - product_code_stage.channel_option_evidence

  Safety:
  - SELECT-only.
  - No DDL.
  - No DML.
  - No source file import.
  - No apply.
*/

SELECT
  'guard'::text AS section,
  current_database() AS current_database,
  current_user AS current_user,
  current_setting('transaction_read_only') AS transaction_read_only,
  CASE WHEN current_database() = 'product_ops_test' THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS verdict,
  'Run against local product_ops_test after a reviewed local stage import only.'::text AS note;

WITH relation_presence AS (
  SELECT *
  FROM (
    VALUES
      ('product_code_stage', 'ably_playauto_source_file'),
      ('product_code_stage', 'ably_raw'),
      ('product_code_stage', 'playauto_product_raw'),
      ('product_code_stage', 'playauto_sku_raw'),
      ('product_code_stage', 'channel_option_evidence')
  ) AS r(table_schema, table_name)
),
presence AS (
  SELECT
    rp.table_schema,
    rp.table_name,
    it.table_name IS NOT NULL AS is_present
  FROM relation_presence AS rp
  LEFT JOIN information_schema.tables AS it
    ON it.table_schema = rp.table_schema
   AND it.table_name = rp.table_name
)
SELECT
  'stage_relation_presence' AS section,
  table_schema,
  table_name,
  CASE WHEN is_present THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS verdict,
  'Required stage relation for validation.' AS note
FROM presence
ORDER BY table_schema, table_name;

SELECT
  'source_file_summary' AS section,
  source_system,
  source_file_name,
  source_row_count,
  source_column_count,
  source_sheet_count,
  source_file_hash,
  collected_at,
  CASE
    WHEN source_system = 'ably_csv' AND source_row_count = 9158 AND source_column_count = 29 THEN 'PASS'
    WHEN source_system = 'playauto_xlsx' AND source_sheet_count = 7 THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS verdict
FROM product_code_stage.ably_playauto_source_file
ORDER BY source_system, source_file_name;

SELECT
  'raw_row_count' AS section,
  'ably_raw' AS relation_name,
  COUNT(*)::bigint AS row_count,
  COUNT(DISTINCT source_file_id)::bigint AS source_file_count,
  COUNT(*) FILTER (WHERE raw_product_no IS NULL OR btrim(raw_product_no) = '')::bigint AS missing_product_no_count,
  COUNT(*) FILTER (WHERE raw_option_no IS NULL OR btrim(raw_option_no) = '')::bigint AS missing_option_no_count,
  CASE
    WHEN COUNT(*) = 9158
     AND COUNT(*) FILTER (WHERE raw_product_no IS NULL OR btrim(raw_product_no) = '') = 0
     AND COUNT(*) FILTER (WHERE raw_option_no IS NULL OR btrim(raw_option_no) = '') = 0
    THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS verdict
FROM product_code_stage.ably_raw

UNION ALL

SELECT
  'raw_row_count' AS section,
  'playauto_product_raw' AS relation_name,
  COUNT(*)::bigint AS row_count,
  COUNT(DISTINCT source_file_id)::bigint AS source_file_count,
  COUNT(*) FILTER (WHERE raw_mall_account IS NULL OR btrim(raw_mall_account) = '')::bigint AS missing_product_no_count,
  COUNT(*) FILTER (WHERE raw_sku_text IS NULL OR btrim(raw_sku_text) = '')::bigint AS missing_option_no_count,
  CASE WHEN COUNT(*) = 4219 THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS verdict
FROM product_code_stage.playauto_product_raw

UNION ALL

SELECT
  'raw_row_count' AS section,
  'playauto_sku_raw' AS relation_name,
  COUNT(*)::bigint AS row_count,
  COUNT(DISTINCT source_file_id)::bigint AS source_file_count,
  COUNT(*) FILTER (WHERE raw_sku_code IS NULL OR btrim(raw_sku_code) = '')::bigint AS missing_product_no_count,
  0::bigint AS missing_option_no_count,
  CASE WHEN COUNT(*) = 17968 THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS verdict
FROM product_code_stage.playauto_sku_raw;

SELECT
  'normalized_evidence_row_count' AS section,
  source_system,
  channel_code,
  COUNT(*)::bigint AS evidence_rows,
  COUNT(*) FILTER (WHERE is_active_candidate)::bigint AS active_candidate_rows,
  COUNT(*) FILTER (WHERE NOT is_active_candidate)::bigint AS inactive_or_blocked_rows,
  COUNT(*) FILTER (WHERE parse_status <> 'ok')::bigint AS parse_warning_or_error_rows,
  CASE
    WHEN channel_code = 'playauto' THEN 'NEEDS_REVIEW'
    WHEN COUNT(*) = 0 THEN 'NEEDS_REVIEW'
    ELSE 'PASS'
  END AS verdict
FROM product_code_stage.channel_option_evidence
GROUP BY source_system, channel_code
ORDER BY source_system, channel_code;

SELECT
  'required_canonical_non_null' AS section,
  source_system,
  COUNT(*)::bigint AS evidence_rows,
  COUNT(*) FILTER (WHERE source_file_id IS NULL)::bigint AS missing_source_file_id,
  COUNT(*) FILTER (WHERE channel_code IS NULL OR btrim(channel_code) = '')::bigint AS missing_channel_code,
  COUNT(*) FILTER (WHERE product_name IS NULL OR btrim(product_name) = '')::bigint AS missing_product_name,
  COUNT(*) FILTER (
    WHERE is_active_candidate
      AND (channel_product_code IS NULL OR btrim(channel_product_code) = '')
  )::bigint AS active_missing_channel_product_code,
  COUNT(*) FILTER (
    WHERE source_system = 'ably_csv'
      AND is_active_candidate
      AND (channel_option_code IS NULL OR btrim(channel_option_code) = '')
  )::bigint AS active_ably_missing_channel_option_code,
  CASE
    WHEN COUNT(*) FILTER (WHERE source_file_id IS NULL) = 0
     AND COUNT(*) FILTER (WHERE channel_code IS NULL OR btrim(channel_code) = '') = 0
     AND COUNT(*) FILTER (WHERE product_name IS NULL OR btrim(product_name) = '') = 0
     AND COUNT(*) FILTER (
       WHERE is_active_candidate
         AND (channel_product_code IS NULL OR btrim(channel_product_code) = '')
     ) = 0
     AND COUNT(*) FILTER (
       WHERE source_system = 'ably_csv'
         AND is_active_candidate
         AND (channel_option_code IS NULL OR btrim(channel_option_code) = '')
     ) = 0
    THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS verdict
FROM product_code_stage.channel_option_evidence
GROUP BY source_system
ORDER BY source_system;

SELECT
  'channel_distribution' AS section,
  channel_code,
  channel_account,
  COUNT(*)::bigint AS evidence_rows,
  COUNT(DISTINCT channel_product_code) FILTER (
    WHERE channel_product_code IS NOT NULL AND btrim(channel_product_code) <> ''
  )::bigint AS distinct_channel_product_code,
  COUNT(DISTINCT channel_option_code) FILTER (
    WHERE channel_option_code IS NOT NULL AND btrim(channel_option_code) <> ''
  )::bigint AS distinct_channel_option_code,
  CASE WHEN channel_code = 'playauto' THEN 'NEEDS_REVIEW' ELSE 'PASS' END AS verdict
FROM product_code_stage.channel_option_evidence
GROUP BY channel_code, channel_account
ORDER BY channel_code, channel_account;

WITH source_duplicates AS (
  SELECT
    source_system,
    source_file_id,
    channel_code,
    channel_account,
    channel_product_code,
    channel_option_code,
    seller_product_code,
    source_option_line_no,
    COUNT(*) AS duplicate_count
  FROM product_code_stage.channel_option_evidence
  GROUP BY
    source_system,
    source_file_id,
    channel_code,
    channel_account,
    channel_product_code,
    channel_option_code,
    seller_product_code,
    source_option_line_no
  HAVING COUNT(*) > 1
)
SELECT
  'duplicate_source_row_check' AS section,
  COUNT(*)::bigint AS duplicate_key_count,
  COALESCE(SUM(duplicate_count), 0)::bigint AS duplicate_rows,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS verdict,
  'Duplicates are checked on source identity plus channel identity fields.' AS note
FROM source_duplicates;

WITH option_identity AS (
  SELECT
    source_system,
    channel_code,
    channel_product_code,
    channel_option_code,
    COUNT(*) AS rows_per_option_identity,
    COUNT(DISTINCT source_file_id) AS source_file_count
  FROM product_code_stage.channel_option_evidence
  WHERE is_active_candidate
    AND channel_product_code IS NOT NULL
    AND btrim(channel_product_code) <> ''
    AND channel_option_code IS NOT NULL
    AND btrim(channel_option_code) <> ''
  GROUP BY source_system, channel_code, channel_product_code, channel_option_code
)
SELECT
  'option_level_uniqueness_check' AS section,
  source_system,
  COUNT(*)::bigint AS option_identity_count,
  COUNT(*) FILTER (WHERE rows_per_option_identity > 1)::bigint AS duplicate_option_identity_count,
  MAX(rows_per_option_identity)::bigint AS max_rows_per_option_identity,
  CASE
    WHEN COUNT(*) FILTER (WHERE rows_per_option_identity > 1) = 0 THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS verdict
FROM option_identity
GROUP BY source_system
ORDER BY source_system;

SELECT
  'status_and_defaults_check' AS section,
  source_system,
  normalized_sale_status,
  normalized_display_status,
  normalized_option_status,
  is_active_candidate,
  COUNT(*)::bigint AS evidence_rows,
  COUNT(*) FILTER (WHERE reviewer_decision <> 'pending')::bigint AS non_pending_review_rows,
  COUNT(*) FILTER (WHERE export_allowed IS DISTINCT FROM false)::bigint AS export_allowed_rows,
  CASE
    WHEN COUNT(*) FILTER (WHERE reviewer_decision <> 'pending') = 0
     AND COUNT(*) FILTER (WHERE export_allowed IS DISTINCT FROM false) = 0
    THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS verdict
FROM product_code_stage.channel_option_evidence
GROUP BY
  source_system,
  normalized_sale_status,
  normalized_display_status,
  normalized_option_status,
  is_active_candidate
ORDER BY source_system, normalized_sale_status, normalized_display_status, normalized_option_status, is_active_candidate;

WITH playauto_sku_lines AS (
  SELECT
    source_file_id,
    COUNT(*) FILTER (WHERE source_system = 'playauto_xlsx') AS exploded_rows,
    COUNT(*) FILTER (
      WHERE source_system = 'playauto_xlsx'
        AND channel_sku_code IS NOT NULL
        AND btrim(channel_sku_code) <> ''
    ) AS exploded_sku_rows,
    COUNT(DISTINCT channel_sku_code) FILTER (
      WHERE source_system = 'playauto_xlsx'
        AND channel_sku_code IS NOT NULL
        AND btrim(channel_sku_code) <> ''
    ) AS exploded_sku_distinct
  FROM product_code_stage.channel_option_evidence
  GROUP BY source_file_id
),
sku_dictionary AS (
  SELECT
    source_file_id,
    COUNT(*) AS dictionary_rows,
    COUNT(DISTINCT raw_sku_code) AS dictionary_distinct
  FROM product_code_stage.playauto_sku_raw
  GROUP BY source_file_id
),
missing_dictionary AS (
  SELECT
    e.source_file_id,
    COUNT(*) AS missing_dictionary_rows
  FROM product_code_stage.channel_option_evidence AS e
  LEFT JOIN product_code_stage.playauto_sku_raw AS d
    ON d.source_file_id = e.source_file_id
   AND d.raw_sku_code = e.channel_sku_code
  WHERE e.source_system = 'playauto_xlsx'
    AND e.channel_sku_code IS NOT NULL
    AND btrim(e.channel_sku_code) <> ''
    AND d.raw_sku_code IS NULL
  GROUP BY e.source_file_id
)
SELECT
  'playauto_sku_explode_validation' AS section,
  p.source_file_id,
  p.exploded_rows::bigint,
  p.exploded_sku_rows::bigint,
  p.exploded_sku_distinct::bigint,
  COALESCE(d.dictionary_rows, 0)::bigint AS dictionary_rows,
  COALESCE(d.dictionary_distinct, 0)::bigint AS dictionary_distinct,
  COALESCE(m.missing_dictionary_rows, 0)::bigint AS missing_dictionary_rows,
  CASE
    WHEN p.exploded_sku_rows > 0
     AND COALESCE(m.missing_dictionary_rows, 0) = 0
    THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS verdict
FROM playauto_sku_lines AS p
LEFT JOIN sku_dictionary AS d
  ON d.source_file_id = p.source_file_id
LEFT JOIN missing_dictionary AS m
  ON m.source_file_id = p.source_file_id
ORDER BY p.source_file_id;

WITH ably_product_codes AS (
  SELECT DISTINCT channel_product_code
  FROM product_code_stage.channel_option_evidence
  WHERE source_system = 'ably_csv'
    AND channel_product_code IS NOT NULL
    AND btrim(channel_product_code) <> ''
),
playauto_ably_product_codes AS (
  SELECT DISTINCT channel_product_code
  FROM product_code_stage.channel_option_evidence
  WHERE source_system = 'playauto_xlsx'
    AND channel_code = 'ably'
    AND channel_product_code IS NOT NULL
    AND btrim(channel_product_code) <> ''
)
SELECT
  'ably_playauto_ably_product_overlap' AS section,
  (SELECT COUNT(*) FROM ably_product_codes)::bigint AS ably_product_code_count,
  (SELECT COUNT(*) FROM playauto_ably_product_codes)::bigint AS playauto_ably_product_code_count,
  (
    SELECT COUNT(*)
    FROM playauto_ably_product_codes AS p
    JOIN ably_product_codes AS a
      ON a.channel_product_code = p.channel_product_code
  )::bigint AS overlap_count,
  CASE
    WHEN (
      SELECT COUNT(*)
      FROM playauto_ably_product_codes AS p
      JOIN ably_product_codes AS a
        ON a.channel_product_code = p.channel_product_code
    ) >= 875 THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS verdict,
  'Expected historical overlap from source analysis: 875 of 877 PlayAuto Ably product numbers.' AS note;

WITH stage_candidates AS (
  SELECT
    e.evidence_id,
    e.source_system,
    e.channel_code,
    e.channel_product_code,
    e.channel_option_code,
    e.own_sku_code_candidate,
    e.selfpia_sku_candidate
  FROM product_code_stage.channel_option_evidence AS e
  WHERE e.is_active_candidate
),
alias_conflicts AS (
  SELECT
    sc.evidence_id,
    COUNT(DISTINCT selfpia.target_id) FILTER (WHERE selfpia.target_id IS NOT NULL) AS selfpia_target_count,
    COUNT(DISTINCT own.target_id) FILTER (WHERE own.target_id IS NOT NULL) AS own_sku_target_count
  FROM stage_candidates AS sc
  LEFT JOIN product_code.code_alias AS selfpia
    ON selfpia.target_type = 'SKU'
   AND selfpia.code_system = 'selfpia_sku'
   AND selfpia.code_value = sc.selfpia_sku_candidate
  LEFT JOIN product_code.code_alias AS own
    ON own.target_type = 'SKU'
   AND own.code_system = 'own_sku'
   AND own.code_value = sc.own_sku_code_candidate
  GROUP BY sc.evidence_id
),
mapping_conflicts AS (
  SELECT
    sc.evidence_id,
    COUNT(DISTINCT scm.sku_id) AS existing_mapping_target_count
  FROM stage_candidates AS sc
  LEFT JOIN product_code.sku_channel_mapping AS scm
    ON lower(scm.channel_code) = lower(sc.channel_code)
   AND (
        scm.seller_product_code = sc.channel_product_code
        OR scm.channel_sku_code = sc.channel_option_code
      )
  GROUP BY sc.evidence_id
)
SELECT
  'code_alias_sku_channel_mapping_conflict_check' AS section,
  COUNT(*)::bigint AS active_stage_candidate_rows,
  COUNT(*) FILTER (WHERE ac.selfpia_target_count > 1)::bigint AS selfpia_multi_target_rows,
  COUNT(*) FILTER (WHERE ac.own_sku_target_count > 1)::bigint AS own_sku_multi_target_rows,
  COUNT(*) FILTER (WHERE mc.existing_mapping_target_count > 1)::bigint AS existing_mapping_multi_target_rows,
  CASE
    WHEN COUNT(*) FILTER (WHERE ac.selfpia_target_count > 1) = 0
     AND COUNT(*) FILTER (WHERE ac.own_sku_target_count > 1) = 0
     AND COUNT(*) FILTER (WHERE mc.existing_mapping_target_count > 1) = 0
    THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS verdict
FROM stage_candidates AS sc
JOIN alias_conflicts AS ac
  ON ac.evidence_id = sc.evidence_id
JOIN mapping_conflicts AS mc
  ON mc.evidence_id = sc.evidence_id;
