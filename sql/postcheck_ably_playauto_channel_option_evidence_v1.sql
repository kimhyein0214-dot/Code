/*
  Postcheck Ably / PlayAuto normalized channel option evidence v1.

  Scope:
  - SELECT-only.
  - Local product_ops_test only.
  - Verifies stage evidence row counts, warnings, duplicates, and safety.
  - Does not modify product_code.code_alias.
  - Does not modify product_code.sku_channel_mapping.
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
  'local channel option evidence postcheck guard'::text AS note;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system,
    source_file_name,
    created_at
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system IN ('ably_csv', 'playauto_xlsx')
  ORDER BY source_system, created_at DESC
),
expected AS (
  SELECT
    (SELECT COUNT(*) FROM product_code_stage.ably_raw AS r JOIN latest_sources AS s ON s.source_file_id = r.source_file_id AND s.source_system = 'ably_csv') AS ably_raw_rows,
    (SELECT COUNT(*) FROM product_code_stage.playauto_product_raw AS r JOIN latest_sources AS s ON s.source_file_id = r.source_file_id AND s.source_system = 'playauto_xlsx') AS playauto_product_raw_rows,
    (SELECT COUNT(*) FROM product_code_stage.playauto_sku_raw AS r JOIN latest_sources AS s ON s.source_file_id = r.source_file_id AND s.source_system = 'playauto_xlsx') AS playauto_sku_raw_rows,
    (
      SELECT COUNT(*)
      FROM product_code_stage.playauto_product_raw AS r
      JOIN latest_sources AS s
        ON s.source_file_id = r.source_file_id
       AND s.source_system = 'playauto_xlsx'
      CROSS JOIN LATERAL regexp_split_to_table(coalesce(r.raw_sku_text, ''), E'\r\n|\n|\r') AS sku(sku_line)
      WHERE NULLIF(btrim(sku.sku_line), '') IS NOT NULL
    ) AS expected_playauto_evidence_rows
),
actual AS (
  SELECT
    COUNT(*) FILTER (WHERE e.source_system = 'ably_csv') AS ably_evidence_rows,
    COUNT(*) FILTER (WHERE e.source_system = 'playauto_xlsx') AS playauto_evidence_rows,
    COUNT(*) AS total_evidence_rows
  FROM product_code_stage.channel_option_evidence AS e
  JOIN latest_sources AS s
    ON s.source_file_id = e.source_file_id
)
SELECT
  'evidence_row_count'::text AS section,
  expected.ably_raw_rows,
  actual.ably_evidence_rows,
  expected.playauto_product_raw_rows,
  expected.playauto_sku_raw_rows,
  expected.expected_playauto_evidence_rows,
  actual.playauto_evidence_rows,
  actual.total_evidence_rows,
  CASE
    WHEN expected.ably_raw_rows = 9158
     AND actual.ably_evidence_rows = expected.ably_raw_rows
     AND expected.playauto_product_raw_rows = 4219
     AND expected.playauto_sku_raw_rows = 17968
     AND actual.playauto_evidence_rows = expected.expected_playauto_evidence_rows
    THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS verdict
FROM expected
CROSS JOIN actual;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system IN ('ably_csv', 'playauto_xlsx')
  ORDER BY source_system, created_at DESC
)
SELECT
  'channel_code_count'::text AS section,
  e.channel_code,
  e.source_system,
  COUNT(*)::bigint AS row_count,
  COUNT(*) FILTER (WHERE e.is_active_candidate)::bigint AS active_candidate_count
FROM product_code_stage.channel_option_evidence AS e
JOIN latest_sources AS s
  ON s.source_file_id = e.source_file_id
GROUP BY e.channel_code, e.source_system
ORDER BY e.channel_code, e.source_system;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system IN ('ably_csv', 'playauto_xlsx')
  ORDER BY source_system, created_at DESC
)
SELECT
  'source_file_count'::text AS section,
  e.source_system,
  e.source_file_id,
  COUNT(*)::bigint AS evidence_rows
FROM product_code_stage.channel_option_evidence AS e
JOIN latest_sources AS s
  ON s.source_file_id = e.source_file_id
GROUP BY e.source_system, e.source_file_id
ORDER BY e.source_system;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system IN ('ably_csv', 'playauto_xlsx')
  ORDER BY source_system, created_at DESC
)
SELECT
  'parse_status_count'::text AS section,
  e.source_system,
  e.parse_status,
  COUNT(*)::bigint AS row_count,
  COUNT(*) FILTER (WHERE e.parse_warning IS NOT NULL)::bigint AS parse_warning_count
FROM product_code_stage.channel_option_evidence AS e
JOIN latest_sources AS s
  ON s.source_file_id = e.source_file_id
GROUP BY e.source_system, e.parse_status
ORDER BY e.source_system, e.parse_status;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system IN ('ably_csv', 'playauto_xlsx')
  ORDER BY source_system, created_at DESC
)
SELECT
  'parse_warning_sample'::text AS section,
  e.source_system,
  e.channel_code,
  e.source_row_no,
  e.source_option_line_no,
  e.channel_product_code,
  e.channel_sku_code,
  e.parse_warning
FROM product_code_stage.channel_option_evidence AS e
JOIN latest_sources AS s
  ON s.source_file_id = e.source_file_id
WHERE e.parse_warning IS NOT NULL
ORDER BY e.source_system, e.source_row_no, e.source_option_line_no
LIMIT 25;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system = 'playauto_xlsx'
  ORDER BY source_system, created_at DESC
),
alignment AS (
  SELECT
    e.raw_payload ->> 'alignment_status' AS alignment_status,
    (e.raw_payload ->> 'sku_found_in_dictionary')::boolean AS sku_found_in_dictionary,
    COUNT(*)::bigint AS evidence_rows
  FROM product_code_stage.channel_option_evidence AS e
  JOIN latest_sources AS s
    ON s.source_file_id = e.source_file_id
  WHERE e.source_system = 'playauto_xlsx'
  GROUP BY e.raw_payload ->> 'alignment_status', (e.raw_payload ->> 'sku_found_in_dictionary')::boolean
)
SELECT
  'playauto_alignment_count'::text AS section,
  alignment_status,
  sku_found_in_dictionary,
  evidence_rows,
  CASE
    WHEN sku_found_in_dictionary IS TRUE THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS verdict
FROM alignment
ORDER BY alignment_status, sku_found_in_dictionary;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system IN ('ably_csv', 'playauto_xlsx')
  ORDER BY source_system, created_at DESC
),
checks AS (
  SELECT
    'reviewer_decision_pending' AS check_name,
    COUNT(*) FILTER (WHERE e.reviewer_decision <> 'pending')::bigint AS issue_count
  FROM product_code_stage.channel_option_evidence AS e
  JOIN latest_sources AS s
    ON s.source_file_id = e.source_file_id
  UNION ALL
  SELECT
    'export_allowed_false' AS check_name,
    COUNT(*) FILTER (WHERE e.export_allowed <> false)::bigint AS issue_count
  FROM product_code_stage.channel_option_evidence AS e
  JOIN latest_sources AS s
    ON s.source_file_id = e.source_file_id
  UNION ALL
  SELECT
    'playauto_channel_code_blocked' AS check_name,
    COUNT(*) FILTER (WHERE e.channel_code = 'playauto')::bigint AS issue_count
  FROM product_code_stage.channel_option_evidence AS e
  JOIN latest_sources AS s
    ON s.source_file_id = e.source_file_id
)
SELECT
  'stage_safety_default_check'::text AS section,
  check_name,
  issue_count,
  CASE WHEN issue_count = 0 THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS verdict
FROM checks
ORDER BY check_name;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system IN ('ably_csv', 'playauto_xlsx')
  ORDER BY source_system, created_at DESC
),
missing AS (
  SELECT
    'missing_channel_product_code' AS check_name,
    COUNT(*) FILTER (WHERE e.channel_product_code IS NULL)::bigint AS issue_count
  FROM product_code_stage.channel_option_evidence AS e
  JOIN latest_sources AS s
    ON s.source_file_id = e.source_file_id
  UNION ALL
  SELECT
    'missing_ably_channel_option_code' AS check_name,
    COUNT(*) FILTER (WHERE e.source_system = 'ably_csv' AND e.channel_option_code IS NULL)::bigint AS issue_count
  FROM product_code_stage.channel_option_evidence AS e
  JOIN latest_sources AS s
    ON s.source_file_id = e.source_file_id
  UNION ALL
  SELECT
    'missing_playauto_channel_sku_code' AS check_name,
    COUNT(*) FILTER (WHERE e.source_system = 'playauto_xlsx' AND e.channel_sku_code IS NULL)::bigint AS issue_count
  FROM product_code_stage.channel_option_evidence AS e
  JOIN latest_sources AS s
    ON s.source_file_id = e.source_file_id
)
SELECT
  'required_key_missing_count'::text AS section,
  check_name,
  issue_count,
  CASE WHEN issue_count = 0 THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS verdict
FROM missing
ORDER BY check_name;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system IN ('ably_csv', 'playauto_xlsx')
  ORDER BY source_system, created_at DESC
),
duplicate_channel_option AS (
  SELECT
    e.channel_code,
    e.channel_product_code,
    e.channel_option_code,
    COUNT(*) AS duplicate_count
  FROM product_code_stage.channel_option_evidence AS e
  JOIN latest_sources AS s
    ON s.source_file_id = e.source_file_id
  WHERE e.channel_product_code IS NOT NULL
    AND e.channel_option_code IS NOT NULL
  GROUP BY e.channel_code, e.channel_product_code, e.channel_option_code
  HAVING COUNT(*) > 1
),
duplicate_channel_sku AS (
  SELECT
    e.channel_code,
    e.channel_sku_code,
    COUNT(*) AS duplicate_count
  FROM product_code_stage.channel_option_evidence AS e
  JOIN latest_sources AS s
    ON s.source_file_id = e.source_file_id
  WHERE e.channel_sku_code IS NOT NULL
  GROUP BY e.channel_code, e.channel_sku_code
  HAVING COUNT(*) > 1
)
SELECT
  'duplicate_key_summary'::text AS section,
  (SELECT COUNT(*) FROM duplicate_channel_option)::bigint AS duplicate_channel_product_option_groups,
  (SELECT COALESCE(SUM(duplicate_count), 0) FROM duplicate_channel_option)::bigint AS duplicate_channel_product_option_rows,
  (SELECT COUNT(*) FROM duplicate_channel_sku)::bigint AS duplicate_channel_sku_groups,
  (SELECT COALESCE(SUM(duplicate_count), 0) FROM duplicate_channel_sku)::bigint AS duplicate_channel_sku_rows,
  'REVIEW_METRIC'::text AS verdict;

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
  'stage evidence generation must not create aliases or channel mappings'::text AS note;

WITH latest_sources AS (
  SELECT DISTINCT ON (source_system)
    source_file_id,
    source_system
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system IN ('ably_csv', 'playauto_xlsx')
  ORDER BY source_system, created_at DESC
),
expected_playauto AS (
  SELECT COUNT(*)::bigint AS expected_rows
  FROM product_code_stage.playauto_product_raw AS r
  JOIN latest_sources AS s
    ON s.source_file_id = r.source_file_id
   AND s.source_system = 'playauto_xlsx'
  CROSS JOIN LATERAL regexp_split_to_table(coalesce(r.raw_sku_text, ''), E'\r\n|\n|\r') AS sku(sku_line)
  WHERE NULLIF(btrim(sku.sku_line), '') IS NOT NULL
),
checks AS (
  SELECT 'ably_evidence_count' AS check_name,
    (SELECT COUNT(*) FROM product_code_stage.channel_option_evidence AS e JOIN latest_sources AS s ON s.source_file_id = e.source_file_id AND s.source_system = 'ably_csv') = 9158 AS passed
  UNION ALL
  SELECT 'playauto_evidence_count',
    (SELECT COUNT(*) FROM product_code_stage.channel_option_evidence AS e JOIN latest_sources AS s ON s.source_file_id = e.source_file_id AND s.source_system = 'playauto_xlsx') = (SELECT expected_rows FROM expected_playauto)
  UNION ALL
  SELECT 'no_playauto_channel_code',
    (SELECT COUNT(*) FROM product_code_stage.channel_option_evidence AS e JOIN latest_sources AS s ON s.source_file_id = e.source_file_id WHERE e.channel_code = 'playauto') = 0
  UNION ALL
  SELECT 'reviewer_export_defaults',
    (SELECT COUNT(*) FROM product_code_stage.channel_option_evidence AS e JOIN latest_sources AS s ON s.source_file_id = e.source_file_id WHERE e.reviewer_decision <> 'pending' OR e.export_allowed <> false) = 0
  UNION ALL
  SELECT 'required_key_gaps_classified',
    (SELECT COUNT(*) FROM product_code_stage.channel_option_evidence AS e JOIN latest_sources AS s ON s.source_file_id = e.source_file_id WHERE e.source_system = 'ably_csv' AND e.channel_option_code IS NULL) = 0
    AND (SELECT COUNT(*) FROM product_code_stage.channel_option_evidence AS e JOIN latest_sources AS s ON s.source_file_id = e.source_file_id WHERE e.source_system = 'playauto_xlsx' AND e.channel_sku_code IS NULL) = 0
    AND (SELECT COUNT(*) FROM product_code_stage.channel_option_evidence AS e JOIN latest_sources AS s ON s.source_file_id = e.source_file_id WHERE e.channel_product_code IS NULL AND e.parse_status <> 'warning') = 0
  UNION ALL
  SELECT 'code_alias_sku_mapping_not_created',
    (SELECT COUNT(*) FROM product_code.code_alias WHERE lower(code_system) IN ('ably', 'playauto')) = 0
    AND (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE lower(channel_code) IN ('ably', 'playauto')) = 0
)
SELECT
  'overall_evidence_postcheck_verdict'::text AS section,
  CASE
    WHEN bool_and(passed)
     AND EXISTS (
       SELECT 1
       FROM product_code_stage.channel_option_evidence AS e
       JOIN latest_sources AS s
         ON s.source_file_id = e.source_file_id
       WHERE e.parse_status = 'warning'
     )
    THEN 'PASS_WITH_WARNINGS'
    WHEN bool_and(passed) THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS overall_verdict,
  COUNT(*) FILTER (WHERE passed)::bigint AS passed_check_count,
  COUNT(*) FILTER (WHERE NOT passed)::bigint AS needs_review_check_count,
  string_agg(check_name, ', ' ORDER BY check_name) FILTER (WHERE NOT passed) AS needs_review_checks
FROM checks;
