/*
  Inspect Ably / PlayAuto code evidence v1.

  Scope:
  - SELECT-only diagnostics.
  - Local product_ops_test only.
  - No DDL/DML.
  - No COPY or \copy.
  - No product_code.code_alias change.
  - No product_code.sku_channel_mapping change.

  Notes:
  - PlayAuto SKU candidates use sellpia_####-# while existing selfpia aliases
    commonly use ####-#. This SQL normalizes candidate values by removing a
    leading sellpia_ prefix before joining.
*/

START TRANSACTION READ ONLY;

SELECT
  'guard'::text AS section,
  current_database() AS current_database,
  current_user AS current_user,
  current_setting('transaction_read_only') AS transaction_read_only,
  CASE
    WHEN current_database() = 'product_ops_test'
     AND current_user = 'product_ops_tester'
    THEN 'PASS'
    ELSE 'STOP'
  END AS guard_result,
  'SELECT-only code evidence inspection'::text AS note;

WITH e AS MATERIALIZED (
  SELECT *
  FROM product_code_stage.channel_option_evidence
)
SELECT
  'evidence_total'::text AS section,
  COUNT(*)::bigint AS total_count,
  COUNT(*) FILTER (WHERE channel_code = 'playauto')::bigint AS playauto_channel_code_count,
  COUNT(*) FILTER (WHERE parse_warning IS NOT NULL)::bigint AS warning_bucket_count,
  COUNT(*) FILTER (WHERE channel_product_code IS NULL)::bigint AS channel_product_code_missing_count,
  COUNT(*) FILTER (WHERE channel_option_code IS NULL)::bigint AS channel_option_code_missing_count,
  COUNT(*) FILTER (WHERE seller_product_code IS NOT NULL)::bigint AS seller_product_code_non_null_count,
  COUNT(*) FILTER (WHERE own_sku_code_candidate IS NOT NULL)::bigint AS own_sku_code_candidate_non_null_count,
  COUNT(*) FILTER (WHERE selfpia_sku_candidate IS NOT NULL)::bigint AS selfpia_sku_candidate_non_null_count,
  COUNT(*) FILTER (WHERE channel_sku_code IS NOT NULL)::bigint AS channel_sku_code_non_null_count
FROM e;

WITH e AS MATERIALIZED (
  SELECT *
  FROM product_code_stage.channel_option_evidence
)
SELECT
  'channel_code_count'::text AS section,
  channel_code,
  source_system,
  COUNT(*)::bigint AS row_count,
  COUNT(*) FILTER (WHERE is_active_candidate)::bigint AS active_candidate_count,
  COUNT(*) FILTER (WHERE parse_warning IS NOT NULL)::bigint AS warning_count
FROM e
GROUP BY channel_code, source_system
ORDER BY channel_code, source_system;

WITH e AS MATERIALIZED (
  SELECT *
  FROM product_code_stage.channel_option_evidence
)
SELECT
  'parse_status_count'::text AS section,
  source_system,
  parse_status,
  COUNT(*)::bigint AS row_count,
  COUNT(*) FILTER (WHERE parse_warning IS NOT NULL)::bigint AS parse_warning_count
FROM e
GROUP BY source_system, parse_status
ORDER BY source_system, parse_status;

WITH e AS MATERIALIZED (
  SELECT *
  FROM product_code_stage.channel_option_evidence
)
SELECT
  'candidate_key_availability'::text AS section,
  channel_code,
  source_system,
  COUNT(*)::bigint AS evidence_rows,
  COUNT(*) FILTER (WHERE seller_product_code IS NOT NULL)::bigint AS seller_product_code_non_null,
  COUNT(*) FILTER (WHERE own_sku_code_candidate IS NOT NULL AND own_sku_code_candidate <> '-')::bigint AS own_sku_code_candidate_non_null,
  COUNT(*) FILTER (WHERE selfpia_sku_candidate IS NOT NULL)::bigint AS selfpia_sku_candidate_non_null,
  COUNT(*) FILTER (WHERE channel_sku_code IS NOT NULL)::bigint AS channel_sku_code_non_null,
  COUNT(*) FILTER (WHERE channel_product_code IS NOT NULL)::bigint AS channel_product_code_non_null,
  COUNT(*) FILTER (WHERE channel_option_code IS NOT NULL)::bigint AS channel_option_code_non_null
FROM e
GROUP BY channel_code, source_system
ORDER BY channel_code, source_system;

WITH e AS MATERIALIZED (
  SELECT *
  FROM product_code_stage.channel_option_evidence
),
candidate_values AS MATERIALIZED (
  SELECT evidence_id, channel_code, source_system, 'selfpia_sku_candidate'::text AS candidate_type, regexp_replace(lower(btrim(selfpia_sku_candidate)), '^sellpia_', '') AS candidate_norm
  FROM e WHERE selfpia_sku_candidate IS NOT NULL
  UNION ALL
  SELECT evidence_id, channel_code, source_system, 'own_sku_code_candidate', regexp_replace(lower(btrim(own_sku_code_candidate)), '^sellpia_', '')
  FROM e WHERE own_sku_code_candidate IS NOT NULL AND own_sku_code_candidate <> '-'
  UNION ALL
  SELECT evidence_id, channel_code, source_system, 'seller_product_code', regexp_replace(lower(btrim(seller_product_code)), '^sellpia_', '')
  FROM e WHERE seller_product_code IS NOT NULL
  UNION ALL
  SELECT evidence_id, channel_code, source_system, 'channel_sku_code', regexp_replace(lower(btrim(channel_sku_code)), '^sellpia_', '')
  FROM e WHERE channel_sku_code IS NOT NULL
),
map_values AS MATERIALIZED (
  SELECT lower(btrim(virtual_sku_code)) AS candidate_norm, id AS sku_id
  FROM product_code.sku_master
  WHERE virtual_sku_code IS NOT NULL
  UNION ALL
  SELECT regexp_replace(lower(btrim(code_value)), '^sellpia_', '') AS candidate_norm, target_id AS sku_id
  FROM product_code.code_alias
  WHERE target_type = 'SKU'
    AND code_value IS NOT NULL
),
candidate_match AS (
  SELECT
    c.candidate_type,
    c.channel_code,
    c.source_system,
    c.evidence_id,
    m.sku_id
  FROM candidate_values AS c
  LEFT JOIN map_values AS m
    ON m.candidate_norm = c.candidate_norm
)
SELECT
  'candidate_match_summary'::text AS section,
  candidate_type,
  channel_code,
  source_system,
  COUNT(*)::bigint AS candidate_rows,
  COUNT(*) FILTER (WHERE sku_id IS NOT NULL)::bigint AS matched_candidate_rows,
  COUNT(DISTINCT evidence_id) FILTER (WHERE sku_id IS NOT NULL)::bigint AS matched_evidence_rows,
  COUNT(DISTINCT evidence_id) FILTER (WHERE sku_id IS NULL)::bigint AS unmatched_evidence_rows
FROM candidate_match
GROUP BY candidate_type, channel_code, source_system
ORDER BY candidate_type, channel_code, source_system;

WITH e AS MATERIALIZED (
  SELECT *
  FROM product_code_stage.channel_option_evidence
),
duplicate_sku AS MATERIALIZED (
  SELECT
    channel_code,
    channel_sku_code
  FROM e
  WHERE channel_sku_code IS NOT NULL
  GROUP BY channel_code, channel_sku_code
  HAVING COUNT(*) > 1
),
candidate_values AS MATERIALIZED (
  SELECT evidence_id, 'selfpia_sku_candidate'::text AS candidate_type, regexp_replace(lower(btrim(selfpia_sku_candidate)), '^sellpia_', '') AS candidate_norm
  FROM e WHERE selfpia_sku_candidate IS NOT NULL
  UNION ALL
  SELECT evidence_id, 'own_sku_code_candidate', regexp_replace(lower(btrim(own_sku_code_candidate)), '^sellpia_', '')
  FROM e WHERE own_sku_code_candidate IS NOT NULL AND own_sku_code_candidate <> '-'
  UNION ALL
  SELECT evidence_id, 'seller_product_code', regexp_replace(lower(btrim(seller_product_code)), '^sellpia_', '')
  FROM e WHERE seller_product_code IS NOT NULL
  UNION ALL
  SELECT evidence_id, 'channel_sku_code', regexp_replace(lower(btrim(channel_sku_code)), '^sellpia_', '')
  FROM e WHERE channel_sku_code IS NOT NULL
),
map_values AS MATERIALIZED (
  SELECT lower(btrim(virtual_sku_code)) AS candidate_norm, id AS sku_id
  FROM product_code.sku_master
  WHERE virtual_sku_code IS NOT NULL
  UNION ALL
  SELECT regexp_replace(lower(btrim(code_value)), '^sellpia_', '') AS candidate_norm, target_id AS sku_id
  FROM product_code.code_alias
  WHERE target_type = 'SKU'
    AND code_value IS NOT NULL
),
match_agg AS MATERIALIZED (
  SELECT
    c.evidence_id,
    COUNT(DISTINCT c.candidate_norm)::bigint AS candidate_value_count,
    COUNT(DISTINCT m.sku_id)::bigint AS matched_sku_count,
    bool_or(c.candidate_type = 'selfpia_sku_candidate' AND m.sku_id IS NOT NULL) AS has_direct_selfpia_match
  FROM candidate_values AS c
  LEFT JOIN map_values AS m
    ON m.candidate_norm = c.candidate_norm
  GROUP BY c.evidence_id
),
classified AS (
  SELECT
    e.channel_code,
    e.source_system,
    COALESCE(m.candidate_value_count, 0) AS candidate_value_count,
    COALESCE(m.matched_sku_count, 0) AS matched_sku_count,
    COALESCE(m.has_direct_selfpia_match, false) AS has_direct_selfpia_match,
    (e.parse_warning IS NOT NULL OR e.channel_product_code IS NULL) AS warning_excluded,
    (d.channel_sku_code IS NOT NULL) AS duplicate_channel_sku_risk,
    (NOT e.is_active_candidate) AS source_not_active
  FROM e
  LEFT JOIN match_agg AS m
    ON m.evidence_id = e.evidence_id
  LEFT JOIN duplicate_sku AS d
    ON d.channel_code = e.channel_code
   AND d.channel_sku_code = e.channel_sku_code
)
SELECT
  'classification_summary'::text AS section,
  channel_code,
  source_system,
  COUNT(*)::bigint AS evidence_rows,
  COUNT(*) FILTER (WHERE has_direct_selfpia_match)::bigint AS direct_evidence_candidate_count,
  COUNT(*) FILTER (WHERE matched_sku_count = 1 AND NOT warning_excluded AND NOT duplicate_channel_sku_risk AND NOT source_not_active)::bigint AS unique_evidence_candidate_count,
  COUNT(*) FILTER (WHERE matched_sku_count > 1 OR duplicate_channel_sku_risk)::bigint AS duplicate_evidence_count,
  COUNT(*) FILTER (WHERE candidate_value_count = 0 OR matched_sku_count = 0)::bigint AS evidence_missing_count,
  COUNT(*) FILTER (WHERE warning_excluded)::bigint AS warning_excluded_count,
  COUNT(*) FILTER (WHERE duplicate_channel_sku_risk)::bigint AS duplicate_channel_sku_risk_count,
  COUNT(*) FILTER (WHERE source_not_active)::bigint AS channel_absent_or_inactive_possible_count
FROM classified
GROUP BY channel_code, source_system
ORDER BY channel_code, source_system;

WITH e AS MATERIALIZED (
  SELECT *
  FROM product_code_stage.channel_option_evidence
),
duplicate_sku AS (
  SELECT
    channel_code,
    channel_sku_code,
    COUNT(*) AS duplicate_rows
  FROM e
  WHERE channel_sku_code IS NOT NULL
  GROUP BY channel_code, channel_sku_code
  HAVING COUNT(*) > 1
)
SELECT
  'duplicate_channel_sku_risk_summary'::text AS section,
  COUNT(*)::bigint AS duplicate_channel_sku_groups,
  COALESCE(SUM(duplicate_rows), 0)::bigint AS duplicate_channel_sku_rows
FROM duplicate_sku;

WITH e AS MATERIALIZED (
  SELECT *
  FROM product_code_stage.channel_option_evidence
),
existing AS (
  SELECT
    e.evidence_id,
    scm.sku_id AS existing_mapping_sku_id,
    ca.target_id AS existing_alias_sku_id
  FROM e
  LEFT JOIN product_code.sku_channel_mapping AS scm
    ON lower(scm.channel_code) = lower(e.channel_code)
   AND (
      (e.channel_sku_code IS NOT NULL AND scm.channel_sku_code = e.channel_sku_code)
      OR (e.seller_product_code IS NOT NULL AND scm.seller_product_code = e.seller_product_code)
      OR (e.own_sku_code_candidate IS NOT NULL AND scm.own_sku_code = e.own_sku_code_candidate)
   )
  LEFT JOIN product_code.code_alias AS ca
    ON ca.target_type = 'SKU'
   AND e.channel_code = 'smartstore'
   AND ca.code_system IN ('smartstore_product_no', 'smartstore_product_no_candidate')
   AND e.channel_product_code IS NOT NULL
   AND ca.code_value = e.channel_product_code
)
SELECT
  'existing_mapping_alias_summary'::text AS section,
  COUNT(DISTINCT evidence_id) FILTER (WHERE existing_mapping_sku_id IS NOT NULL)::bigint AS existing_channel_mapping_present_count,
  COUNT(DISTINCT evidence_id) FILTER (WHERE existing_alias_sku_id IS NOT NULL)::bigint AS existing_channel_alias_present_count,
  COUNT(DISTINCT evidence_id) FILTER (
    WHERE existing_mapping_sku_id IS NOT NULL
      AND existing_alias_sku_id IS NOT NULL
      AND existing_mapping_sku_id <> existing_alias_sku_id
  )::bigint AS existing_confirmed_manual_conflict_count
FROM existing;

WITH e AS MATERIALIZED (
  SELECT *
  FROM product_code_stage.channel_option_evidence
)
SELECT
  'sample_ably_unique_evidence'::text AS section,
  evidence_id,
  source_row_no,
  channel_product_code,
  channel_option_code,
  seller_product_code,
  own_sku_code_candidate,
  selfpia_sku_candidate,
  product_name,
  option_value
FROM e
WHERE source_system = 'ably_csv'
  AND parse_warning IS NULL
  AND is_active_candidate
  AND selfpia_sku_candidate IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM product_code.code_alias AS ca
    WHERE ca.target_type = 'SKU'
      AND ca.code_system = 'selfpia_sku'
      AND ca.code_value = regexp_replace(e.selfpia_sku_candidate, '^sellpia_', '')
  )
ORDER BY evidence_id
LIMIT 50;

WITH e AS MATERIALIZED (
  SELECT *
  FROM product_code_stage.channel_option_evidence
)
SELECT
  'sample_playauto_ably_unique_candidate'::text AS section,
  evidence_id,
  source_row_no,
  source_option_line_no,
  channel_product_code,
  channel_sku_code,
  seller_product_code,
  product_name,
  option_name,
  option_value
FROM e
WHERE source_system = 'playauto_xlsx'
  AND channel_code = 'ably'
  AND parse_warning IS NULL
  AND is_active_candidate
ORDER BY evidence_id
LIMIT 50;

WITH e AS MATERIALIZED (
  SELECT *
  FROM product_code_stage.channel_option_evidence
)
SELECT
  'sample_warning_bucket'::text AS section,
  evidence_id,
  source_system,
  channel_code,
  source_row_no,
  source_option_line_no,
  channel_product_code,
  channel_sku_code,
  parse_warning
FROM e
WHERE parse_warning IS NOT NULL
ORDER BY evidence_id
LIMIT 50;

WITH e AS MATERIALIZED (
  SELECT *
  FROM product_code_stage.channel_option_evidence
),
duplicate_sku AS (
  SELECT channel_code, channel_sku_code
  FROM e
  WHERE channel_sku_code IS NOT NULL
  GROUP BY channel_code, channel_sku_code
  HAVING COUNT(*) > 1
)
SELECT
  'sample_duplicate_channel_sku'::text AS section,
  e.channel_code,
  e.channel_sku_code,
  e.evidence_id,
  e.source_row_no,
  e.source_option_line_no,
  e.channel_product_code,
  e.product_name,
  e.option_value
FROM e
JOIN duplicate_sku AS d
  ON d.channel_code = e.channel_code
 AND d.channel_sku_code = e.channel_sku_code
ORDER BY e.channel_code, e.channel_sku_code, e.evidence_id
LIMIT 50;

WITH e AS MATERIALIZED (
  SELECT *
  FROM product_code_stage.channel_option_evidence
)
SELECT
  'sample_evidence_missing'::text AS section,
  evidence_id,
  source_system,
  channel_code,
  source_row_no,
  channel_product_code,
  channel_option_code,
  channel_sku_code,
  seller_product_code,
  own_sku_code_candidate
FROM e
WHERE (selfpia_sku_candidate IS NULL AND own_sku_code_candidate IS NULL AND channel_sku_code IS NULL)
   OR own_sku_code_candidate = '-'
ORDER BY evidence_id
LIMIT 50;

WITH e AS MATERIALIZED (
  SELECT *
  FROM product_code_stage.channel_option_evidence
)
SELECT
  'sample_inactive_status'::text AS section,
  evidence_id,
  source_system,
  channel_code,
  source_row_no,
  source_option_line_no,
  channel_product_code,
  channel_sku_code,
  sale_status_raw,
  display_status_raw,
  option_status_raw,
  normalized_sale_status,
  normalized_display_status,
  normalized_option_status
FROM e
WHERE NOT is_active_candidate
ORDER BY evidence_id
LIMIT 50;

WITH e AS MATERIALIZED (
  SELECT *
  FROM product_code_stage.channel_option_evidence
)
SELECT
  'sample_smartstore_overlap'::text AS section,
  e.evidence_id,
  e.source_row_no,
  e.channel_product_code,
  e.channel_sku_code,
  e.seller_product_code,
  e.product_name,
  e.option_value,
  ca_product.target_id AS existing_product_alias_sku_id
FROM e
JOIN product_code.code_alias AS ca_product
  ON ca_product.target_type = 'SKU'
 AND ca_product.code_system IN ('smartstore_product_no', 'smartstore_product_no_candidate')
 AND e.channel_product_code IS NOT NULL
 AND ca_product.code_value = e.channel_product_code
WHERE e.channel_code = 'smartstore'
ORDER BY e.evidence_id
LIMIT 50;

COMMIT;
