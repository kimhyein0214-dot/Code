/*
  Postcheck local raw stage import for Ably / PlayAuto source files v1.

  Scope:
  - SELECT-only.
  - Local product_ops_test only.
  - Validates raw stage import counts and safety defaults.
  - Verifies normalized evidence remains deferred.
  - Does not modify product_code.code_alias or product_code.sku_channel_mapping.
*/

SELECT
  'guard'::text AS section,
  current_database() AS current_database,
  current_user AS current_user,
  CASE
    WHEN current_database() = 'product_ops_test'
     AND current_user = 'product_ops_tester'
    THEN 'PASS'
    ELSE 'STOP'
  END AS guard_result,
  'local raw stage import postcheck guard'::text AS note;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system,
    source_file_name,
    source_file_hash,
    source_row_count,
    source_column_count,
    source_sheet_count,
    source_note,
    created_at
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system IN ('ably_csv', 'playauto_xlsx')
  ORDER BY source_system, created_at DESC
)
SELECT
  'latest_source_file'::text AS section,
  source_system,
  source_file_name,
  left(source_file_hash, 16) AS source_file_hash_prefix,
  source_row_count,
  source_column_count,
  source_sheet_count,
  created_at,
  CASE
    WHEN source_system = 'ably_csv'
     AND source_row_count = 9158
     AND source_column_count = 29 THEN 'PASS'
    WHEN source_system = 'playauto_xlsx'
     AND source_row_count = 4219
     AND source_column_count = 95
     AND source_sheet_count = 7 THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS verdict
FROM latest_sources
ORDER BY source_system;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system IN ('ably_csv', 'playauto_xlsx')
  ORDER BY source_system, created_at DESC
),
counts AS (
  SELECT
    'ably_raw' AS table_name,
    COUNT(*)::bigint AS row_count,
    9158::bigint AS expected_count
  FROM product_code_stage.ably_raw AS r
  JOIN latest_sources AS s
    ON s.source_file_id = r.source_file_id
   AND s.source_system = 'ably_csv'
  UNION ALL
  SELECT
    'playauto_product_raw' AS table_name,
    COUNT(*)::bigint AS row_count,
    4219::bigint AS expected_count
  FROM product_code_stage.playauto_product_raw AS r
  JOIN latest_sources AS s
    ON s.source_file_id = r.source_file_id
   AND s.source_system = 'playauto_xlsx'
  UNION ALL
  SELECT
    'playauto_sku_raw' AS table_name,
    COUNT(*)::bigint AS row_count,
    17968::bigint AS expected_count
  FROM product_code_stage.playauto_sku_raw AS r
  JOIN latest_sources AS s
    ON s.source_file_id = r.source_file_id
   AND s.source_system = 'playauto_xlsx'
  UNION ALL
  SELECT
    'channel_option_evidence' AS table_name,
    COUNT(*)::bigint AS row_count,
    0::bigint AS expected_count
  FROM product_code_stage.channel_option_evidence AS r
  JOIN latest_sources AS s
    ON s.source_file_id = r.source_file_id
)
SELECT
  'row_count_check'::text AS section,
  table_name,
  row_count,
  expected_count,
  CASE WHEN row_count = expected_count THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS verdict
FROM counts
ORDER BY table_name;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system IN ('ably_csv', 'playauto_xlsx')
  ORDER BY source_system, created_at DESC
),
required_checks AS (
  SELECT
    'ably_required_non_null' AS check_name,
    COUNT(*) FILTER (
      WHERE source_row_no IS NULL
         OR raw_product_no IS NULL
         OR raw_option_no IS NULL
         OR raw_payload IS NULL
    )::bigint AS issue_count
  FROM product_code_stage.ably_raw AS r
  JOIN latest_sources AS s
    ON s.source_file_id = r.source_file_id
   AND s.source_system = 'ably_csv'
  UNION ALL
  SELECT
    'playauto_product_required_non_null' AS check_name,
    COUNT(*) FILTER (
      WHERE source_row_no IS NULL
         OR raw_mall_account IS NULL
         OR raw_mall_product_no IS NULL
         OR raw_payload IS NULL
    )::bigint AS issue_count
  FROM product_code_stage.playauto_product_raw AS r
  JOIN latest_sources AS s
    ON s.source_file_id = r.source_file_id
   AND s.source_system = 'playauto_xlsx'
  UNION ALL
  SELECT
    'playauto_sku_required_non_null' AS check_name,
    COUNT(*) FILTER (
      WHERE source_row_no IS NULL
         OR raw_sku_code IS NULL
         OR raw_payload IS NULL
    )::bigint AS issue_count
  FROM product_code_stage.playauto_sku_raw AS r
  JOIN latest_sources AS s
    ON s.source_file_id = r.source_file_id
   AND s.source_system = 'playauto_xlsx'
)
SELECT
  'required_non_null_check'::text AS section,
  check_name,
  issue_count,
  CASE WHEN issue_count = 0 THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS verdict
FROM required_checks
ORDER BY check_name;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system IN ('ably_csv', 'playauto_xlsx')
  ORDER BY source_system, created_at DESC
),
trace_checks AS (
  SELECT
    'ably_source_row_no' AS check_name,
    COUNT(*)::bigint AS row_count,
    COUNT(DISTINCT source_row_no)::bigint AS distinct_source_row_no
  FROM product_code_stage.ably_raw AS r
  JOIN latest_sources AS s
    ON s.source_file_id = r.source_file_id
   AND s.source_system = 'ably_csv'
  UNION ALL
  SELECT
    'playauto_product_source_row_no' AS check_name,
    COUNT(*)::bigint AS row_count,
    COUNT(DISTINCT source_row_no)::bigint AS distinct_source_row_no
  FROM product_code_stage.playauto_product_raw AS r
  JOIN latest_sources AS s
    ON s.source_file_id = r.source_file_id
   AND s.source_system = 'playauto_xlsx'
  UNION ALL
  SELECT
    'playauto_sku_source_row_no' AS check_name,
    COUNT(*)::bigint AS row_count,
    COUNT(DISTINCT source_row_no)::bigint AS distinct_source_row_no
  FROM product_code_stage.playauto_sku_raw AS r
  JOIN latest_sources AS s
    ON s.source_file_id = r.source_file_id
   AND s.source_system = 'playauto_xlsx'
)
SELECT
  'source_row_no_trace_check'::text AS section,
  check_name,
  row_count,
  distinct_source_row_no,
  CASE WHEN row_count = distinct_source_row_no THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS verdict
FROM trace_checks
ORDER BY check_name;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system IN ('ably_csv', 'playauto_xlsx')
  ORDER BY source_system, created_at DESC
),
raw_payload_checks AS (
  SELECT
    'ably_raw_payload' AS check_name,
    COUNT(*) FILTER (WHERE raw_payload = '{}'::jsonb)::bigint AS empty_payload_count
  FROM product_code_stage.ably_raw AS r
  JOIN latest_sources AS s
    ON s.source_file_id = r.source_file_id
   AND s.source_system = 'ably_csv'
  UNION ALL
  SELECT
    'playauto_product_raw_payload' AS check_name,
    COUNT(*) FILTER (WHERE raw_payload = '{}'::jsonb)::bigint AS empty_payload_count
  FROM product_code_stage.playauto_product_raw AS r
  JOIN latest_sources AS s
    ON s.source_file_id = r.source_file_id
   AND s.source_system = 'playauto_xlsx'
  UNION ALL
  SELECT
    'playauto_sku_raw_payload' AS check_name,
    COUNT(*) FILTER (WHERE raw_payload = '{}'::jsonb)::bigint AS empty_payload_count
  FROM product_code_stage.playauto_sku_raw AS r
  JOIN latest_sources AS s
    ON s.source_file_id = r.source_file_id
   AND s.source_system = 'playauto_xlsx'
)
SELECT
  'raw_payload_check'::text AS section,
  check_name,
  empty_payload_count,
  CASE WHEN empty_payload_count = 0 THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS verdict
FROM raw_payload_checks
ORDER BY check_name;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system IN ('ably_csv', 'playauto_xlsx')
  ORDER BY source_system, created_at DESC
)
SELECT
  'playauto_mall_account_distribution'::text AS section,
  raw_mall_account,
  COUNT(*)::bigint AS row_count
FROM product_code_stage.playauto_product_raw AS r
JOIN latest_sources AS s
  ON s.source_file_id = r.source_file_id
 AND s.source_system = 'playauto_xlsx'
GROUP BY raw_mall_account
ORDER BY row_count DESC, raw_mall_account;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system IN ('ably_csv', 'playauto_xlsx')
  ORDER BY source_system, created_at DESC
),
default_checks AS (
  SELECT
    'channel_option_evidence_reviewer_pending' AS check_name,
    COUNT(*) FILTER (WHERE reviewer_decision <> 'pending')::bigint AS issue_count
  FROM product_code_stage.channel_option_evidence AS r
  JOIN latest_sources AS s
    ON s.source_file_id = r.source_file_id
  UNION ALL
  SELECT
    'channel_option_evidence_export_blocked' AS check_name,
    COUNT(*) FILTER (WHERE export_allowed <> false)::bigint AS issue_count
  FROM product_code_stage.channel_option_evidence AS r
  JOIN latest_sources AS s
    ON s.source_file_id = r.source_file_id
)
SELECT
  'normalized_default_check'::text AS section,
  check_name,
  issue_count,
  CASE WHEN issue_count = 0 THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS verdict,
  'channel_option_evidence generation is deferred, so zero issues is expected'::text AS note
FROM default_checks
ORDER BY check_name;

SELECT
  'code_alias_sku_channel_mapping_safety_check'::text AS section,
  (SELECT COUNT(*) FROM product_code.code_alias WHERE lower(code_system) IN ('ably', 'playauto'))::bigint AS code_alias_ably_playauto_rows,
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE lower(channel_code) IN ('ably', 'playauto'))::bigint AS sku_channel_mapping_ably_playauto_rows,
  CASE
    WHEN (SELECT COUNT(*) FROM product_code.code_alias WHERE lower(code_system) IN ('ably', 'playauto')) = 0
     AND (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE lower(channel_code) IN ('ably', 'playauto')) = 0
    THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS verdict,
  'raw stage import must not create matching evidence or channel mappings'::text AS note;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system,
    source_row_count,
    source_column_count,
    source_sheet_count
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system IN ('ably_csv', 'playauto_xlsx')
  ORDER BY source_system, created_at DESC
),
checks AS (
  SELECT 'latest_two_source_files_exist' AS check_name, (SELECT COUNT(*) FROM latest_sources) = 2 AS passed
  UNION ALL
  SELECT 'source_metadata_expected',
    EXISTS (SELECT 1 FROM latest_sources WHERE source_system = 'ably_csv' AND source_row_count = 9158 AND source_column_count = 29)
    AND EXISTS (SELECT 1 FROM latest_sources WHERE source_system = 'playauto_xlsx' AND source_row_count = 4219 AND source_column_count = 95 AND source_sheet_count = 7)
  UNION ALL
  SELECT 'ably_raw_count',
    (SELECT COUNT(*)
     FROM product_code_stage.ably_raw AS r
     JOIN latest_sources AS s ON s.source_file_id = r.source_file_id AND s.source_system = 'ably_csv') = 9158
  UNION ALL
  SELECT 'playauto_product_raw_count',
    (SELECT COUNT(*)
     FROM product_code_stage.playauto_product_raw AS r
     JOIN latest_sources AS s ON s.source_file_id = r.source_file_id AND s.source_system = 'playauto_xlsx') = 4219
  UNION ALL
  SELECT 'playauto_sku_raw_count',
    (SELECT COUNT(*)
     FROM product_code_stage.playauto_sku_raw AS r
     JOIN latest_sources AS s ON s.source_file_id = r.source_file_id AND s.source_system = 'playauto_xlsx') = 17968
  UNION ALL
  SELECT 'normalized_evidence_deferred',
    (SELECT COUNT(*)
     FROM product_code_stage.channel_option_evidence AS r
     JOIN latest_sources AS s ON s.source_file_id = r.source_file_id) = 0
  UNION ALL
  SELECT 'code_alias_sku_mapping_not_created',
    (SELECT COUNT(*) FROM product_code.code_alias WHERE lower(code_system) IN ('ably', 'playauto')) = 0
    AND (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE lower(channel_code) IN ('ably', 'playauto')) = 0
)
SELECT
  'overall_import_postcheck_verdict'::text AS section,
  CASE WHEN bool_and(passed) THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS overall_verdict,
  COUNT(*) FILTER (WHERE passed)::bigint AS passed_check_count,
  COUNT(*) FILTER (WHERE NOT passed)::bigint AS needs_review_check_count,
  string_agg(check_name, ', ' ORDER BY check_name) FILTER (WHERE NOT passed) AS needs_review_checks
FROM checks;
