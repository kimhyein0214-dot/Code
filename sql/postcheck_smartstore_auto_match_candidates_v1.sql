/*
  Smartstore auto-match postcheck draft.

  Run this only after a separately approved local apply.
  This file is SELECT-only and expects future applied rows to carry:
  - source_project_ref = 'smartstore_auto_match_dryrun_v1'
  - Smartstore channel code systems or sku_channel_mapping channel_code = 'smartstore'
*/

WITH applied_alias AS (
  SELECT
    ca.target_id AS sku_id,
    COUNT(*) AS applied_alias_rows,
    COUNT(*) FILTER (
      WHERE ca.code_system = 'smartstore_product_no'
    ) AS applied_product_no_rows,
    COUNT(*) FILTER (
      WHERE ca.code_system = 'smartstore_option_no'
    ) AS applied_option_no_rows,
    COUNT(DISTINCT ca.code_value) FILTER (
      WHERE ca.code_system = 'smartstore_product_no'
    ) AS applied_product_no_distinct_count,
    COUNT(DISTINCT ca.code_value) FILTER (
      WHERE ca.code_system = 'smartstore_option_no'
    ) AS applied_option_no_distinct_count
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.source_project_ref = 'smartstore_auto_match_dryrun_v1'
    AND ca.code_system IN ('smartstore_product_no', 'smartstore_option_no')
  GROUP BY ca.target_id
),

applied_mapping AS (
  SELECT
    scm.sku_id,
    COUNT(*) AS applied_mapping_rows,
    COUNT(DISTINCT scm.seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
    ) AS applied_product_no_distinct_count,
    COUNT(DISTINCT scm.channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS applied_option_no_distinct_count
  FROM product_code.sku_channel_mapping AS scm
  WHERE lower(scm.channel_code) = 'smartstore'
    AND COALESCE(scm.raw_payload::text, '') LIKE '%smartstore_auto_match_dryrun_v1%'
  GROUP BY scm.sku_id
),

applied_rows AS (
  SELECT
    COALESCE(aa.sku_id, am.sku_id) AS sku_id,
    COALESCE(aa.applied_alias_rows, 0) AS applied_alias_rows,
    COALESCE(am.applied_mapping_rows, 0) AS applied_mapping_rows,
    GREATEST(
      COALESCE(aa.applied_product_no_distinct_count, 0),
      COALESCE(am.applied_product_no_distinct_count, 0)
    ) AS applied_product_no_distinct_count,
    GREATEST(
      COALESCE(aa.applied_option_no_distinct_count, 0),
      COALESCE(am.applied_option_no_distinct_count, 0)
    ) AS applied_option_no_distinct_count
  FROM applied_alias AS aa
  FULL OUTER JOIN applied_mapping AS am
    ON am.sku_id = aa.sku_id
),

product_option_duplicates AS (
  SELECT
    COALESCE(ca_product.code_value, scm.seller_product_code) AS product_no,
    COALESCE(ca_option.code_value, scm.channel_sku_code) AS option_no,
    COUNT(DISTINCT ar.sku_id) AS sku_count
  FROM applied_rows AS ar
  LEFT JOIN product_code.code_alias AS ca_product
    ON ca_product.target_type = 'SKU'
   AND ca_product.target_id = ar.sku_id
   AND ca_product.code_system = 'smartstore_product_no'
  LEFT JOIN product_code.code_alias AS ca_option
    ON ca_option.target_type = 'SKU'
   AND ca_option.target_id = ar.sku_id
   AND ca_option.code_system = 'smartstore_option_no'
  LEFT JOIN product_code.sku_channel_mapping AS scm
    ON scm.sku_id = ar.sku_id
   AND lower(scm.channel_code) = 'smartstore'
  WHERE NULLIF(btrim(COALESCE(ca_product.code_value, scm.seller_product_code, '')), '') IS NOT NULL
    AND NULLIF(btrim(COALESCE(ca_option.code_value, scm.channel_sku_code, '')), '') IS NOT NULL
  GROUP BY
    COALESCE(ca_product.code_value, scm.seller_product_code),
    COALESCE(ca_option.code_value, scm.channel_sku_code)
),

selfpia_product_splits AS (
  SELECT
    v.selfpia_sku_code,
    COUNT(DISTINCT COALESCE(ca_product.code_value, scm.seller_product_code)) AS product_no_count
  FROM applied_rows AS ar
  JOIN product_code.v_sku_canonical AS v
    ON v.sku_id = ar.sku_id
  LEFT JOIN product_code.code_alias AS ca_product
    ON ca_product.target_type = 'SKU'
   AND ca_product.target_id = ar.sku_id
   AND ca_product.code_system = 'smartstore_product_no'
  LEFT JOIN product_code.sku_channel_mapping AS scm
    ON scm.sku_id = ar.sku_id
   AND lower(scm.channel_code) = 'smartstore'
  WHERE NULLIF(btrim(COALESCE(v.selfpia_sku_code, '')), '') IS NOT NULL
  GROUP BY v.selfpia_sku_code
),

manual_or_confirmed_overwrite AS (
  SELECT
    ar.sku_id,
    COUNT(*) FILTER (
      WHERE lower(COALESCE(ca.usage_type, '')) LIKE '%manual%'
         OR lower(COALESCE(ca.memo, '')) LIKE '%manual%'
         OR COALESCE(ca.memo, '') LIKE '%' || U&'\C218\B3D9' || '%'
         OR lower(COALESCE(ca.raw_payload::text, '')) LIKE '%manual%'
         OR lower(COALESCE(ca.raw_payload::text, '')) LIKE '%reviewer%'
    ) AS manual_marker_rows,
    COUNT(*) FILTER (
      WHERE ca.source_project_ref <> 'smartstore_auto_match_dryrun_v1'
        AND ca.code_system IN ('smartstore_product_no', 'smartstore_option_no')
    ) AS pre_existing_confirmed_rows
  FROM applied_rows AS ar
  LEFT JOIN product_code.code_alias AS ca
    ON ca.target_type = 'SKU'
   AND ca.target_id = ar.sku_id
  GROUP BY ar.sku_id
),

summary AS (
  SELECT
    COUNT(*) FROM applied_rows
)

SELECT
  'smartstore_auto_matched_count'::text AS postcheck_item,
  (SELECT COUNT(*) FROM applied_rows)::bigint AS row_count,
  'rows tagged by future approved apply marker.'::text AS note
UNION ALL
SELECT
  'duplicate_productNo_optionNo_residual',
  COUNT(*)::bigint,
  'must be zero.'
FROM product_option_duplicates
WHERE sku_count > 1
UNION ALL
SELECT
  'duplicate_selfpia_sku_to_productNo_residual',
  COUNT(*)::bigint,
  'must be zero.'
FROM selfpia_product_splits
WHERE product_no_count > 1
UNION ALL
SELECT
  'manual_overwrite_count',
  COUNT(*)::bigint,
  'must be zero.'
FROM manual_or_confirmed_overwrite
WHERE manual_marker_rows > 0
UNION ALL
SELECT
  'confirmed_overwrite_count',
  COUNT(*)::bigint,
  'must be zero.'
FROM manual_or_confirmed_overwrite
WHERE pre_existing_confirmed_rows > 0
UNION ALL
SELECT
  'blocked_risk_accidentally_applied_count',
  0::bigint,
  'placeholder: future apply must tag only approved dryrun candidates.'
UNION ALL
SELECT
  'channel_absent_or_inactive_accidentally_applied_count',
  0::bigint,
  'placeholder: future apply must exclude channel absent or inactive rows.'
UNION ALL
SELECT
  'semantic_warning_accidentally_applied_count',
  0::bigint,
  'placeholder: future apply must exclude semantic warning rows.'
UNION ALL
SELECT
  'final_verdict',
  CASE
    WHEN NOT EXISTS (SELECT 1 FROM product_option_duplicates WHERE sku_count > 1)
     AND NOT EXISTS (SELECT 1 FROM selfpia_product_splits WHERE product_no_count > 1)
     AND NOT EXISTS (SELECT 1 FROM manual_or_confirmed_overwrite WHERE manual_marker_rows > 0)
     AND NOT EXISTS (SELECT 1 FROM manual_or_confirmed_overwrite WHERE pre_existing_confirmed_rows > 0)
    THEN 1::bigint
    ELSE 0::bigint
  END,
  CASE
    WHEN NOT EXISTS (SELECT 1 FROM product_option_duplicates WHERE sku_count > 1)
     AND NOT EXISTS (SELECT 1 FROM selfpia_product_splits WHERE product_no_count > 1)
     AND NOT EXISTS (SELECT 1 FROM manual_or_confirmed_overwrite WHERE manual_marker_rows > 0)
     AND NOT EXISTS (SELECT 1 FROM manual_or_confirmed_overwrite WHERE pre_existing_confirmed_rows > 0)
    THEN 'PASS'
    ELSE 'FAIL'
  END;
