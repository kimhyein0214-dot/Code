/*
  Validate Smartstore auto-match candidates before dryrun.

  Purpose:
  - Count high/medium candidates and residual risks before any apply step.
  - Confirm excluded buckets stay excluded.
  - Produce count-only validation output.

  Safety:
  - SELECT-only.
  - Read-only summary.
  - No file output.
  - No import/export.
  - No stage relation.
  - export_allowed remains false.
  - reviewer_decision remains pending.
*/

WITH canonical_sku AS (
  SELECT
    v.sku_id,
    v.product_id,
    v.selfpia_sku_code,
    v.selfpia_product_code,
    v.product_name,
    v.option_value
  FROM product_code.v_sku_canonical AS v
),

smartstore_alias AS (
  SELECT
    ca.target_id AS sku_id,
    COUNT(*) AS alias_rows,
    COUNT(*) FILTER (
      WHERE ca.code_system IN ('smartstore_product_no', 'smartstore_option_no')
    ) AS confirmed_alias_rows,
    COUNT(*) FILTER (
      WHERE ca.code_system IN ('smartstore_product_no_candidate', 'smartstore_option_no_candidate')
    ) AS candidate_alias_rows,
    COUNT(DISTINCT ca.code_value) FILTER (
      WHERE ca.code_system IN ('smartstore_product_no', 'smartstore_product_no_candidate')
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS product_no_distinct_count,
    COUNT(DISTINCT ca.code_value) FILTER (
      WHERE ca.code_system IN ('smartstore_option_no', 'smartstore_option_no_candidate')
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS option_no_distinct_count,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system IN ('smartstore_product_no', 'smartstore_product_no_candidate')
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS product_no_any,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system IN ('smartstore_option_no', 'smartstore_option_no_candidate')
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS option_no_any
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system LIKE 'smartstore%'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.target_id
),

smartstore_mapping AS (
  SELECT
    scm.sku_id,
    COUNT(*) AS mapping_rows,
    COUNT(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS mapping_identity_rows,
    COUNT(DISTINCT scm.seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
    ) AS mapping_product_no_distinct_count,
    COUNT(DISTINCT scm.channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS mapping_option_no_distinct_count,
    COUNT(DISTINCT scm.own_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.own_sku_code, '')), '') IS NOT NULL
    ) AS mapping_own_sku_distinct_count,
    MIN(scm.seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
    ) AS mapping_product_no_any,
    MIN(scm.channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS mapping_option_no_any
  FROM product_code.sku_channel_mapping AS scm
  WHERE lower(scm.channel_code) = 'smartstore'
  GROUP BY scm.sku_id
),

own_sku_value_by_sku AS (
  SELECT DISTINCT
    ca.target_id AS sku_id,
    ca.code_value AS own_sku_code
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL

  UNION

  SELECT DISTINCT
    scm.sku_id,
    scm.own_sku_code
  FROM product_code.sku_channel_mapping AS scm
  WHERE lower(scm.channel_code) = 'smartstore'
    AND NULLIF(btrim(COALESCE(scm.own_sku_code, '')), '') IS NOT NULL
),

own_sku_scope AS (
  SELECT
    osv.own_sku_code,
    cs.sku_id,
    cs.product_id,
    cs.selfpia_product_code,
    COALESCE(sa.product_no_any, sm.mapping_product_no_any) AS product_no_key,
    COALESCE(sa.option_no_any, sm.mapping_option_no_any) AS option_no_key
  FROM own_sku_value_by_sku AS osv
  JOIN canonical_sku AS cs
    ON cs.sku_id = osv.sku_id
  LEFT JOIN smartstore_alias AS sa
    ON sa.sku_id = osv.sku_id
  LEFT JOIN smartstore_mapping AS sm
    ON sm.sku_id = osv.sku_id
),

own_sku_scope_stats AS (
  SELECT
    own_sku_code,
    COUNT(DISTINCT sku_id) AS own_sku_sku_count,
    COUNT(DISTINCT product_id) FILTER (
      WHERE product_id IS NOT NULL
    ) AS own_sku_product_id_count,
    COUNT(DISTINCT selfpia_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(selfpia_product_code, '')), '') IS NOT NULL
    ) AS own_sku_selfpia_product_count,
    COUNT(DISTINCT product_no_key) FILTER (
      WHERE NULLIF(btrim(COALESCE(product_no_key, '')), '') IS NOT NULL
    ) AS own_sku_smartstore_product_count
  FROM own_sku_scope
  GROUP BY own_sku_code
),

own_sku_scope_by_sku AS (
  SELECT
    osv.sku_id,
    MAX(oss.own_sku_sku_count) AS max_own_sku_target_count,
    MAX(oss.own_sku_product_id_count) AS max_own_sku_product_id_count,
    MAX(oss.own_sku_selfpia_product_count) AS max_own_sku_selfpia_product_count,
    MAX(oss.own_sku_smartstore_product_count) AS max_own_sku_smartstore_product_count
  FROM own_sku_value_by_sku AS osv
  JOIN own_sku_scope_stats AS oss
    ON oss.own_sku_code = osv.own_sku_code
  GROUP BY osv.sku_id
),

image_by_sku AS (
  SELECT
    pi.sku_id,
    COUNT(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(pi.image_url, '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(pi.thumbnail_url, '')), '') IS NOT NULL
    ) AS image_rows
  FROM product_code.product_image AS pi
  WHERE pi.sku_id IS NOT NULL
  GROUP BY pi.sku_id
),

base AS (
  SELECT
    cs.sku_id,
    cs.selfpia_sku_code,
    cs.option_value,
    COALESCE(sa.alias_rows, 0) AS alias_rows,
    COALESCE(sa.confirmed_alias_rows, 0) AS confirmed_alias_rows,
    COALESCE(sa.candidate_alias_rows, 0) AS candidate_alias_rows,
    COALESCE(sa.product_no_distinct_count, 0) AS product_no_distinct_count,
    COALESCE(sa.option_no_distinct_count, 0) AS option_no_distinct_count,
    COALESCE(sa.product_no_any, sm.mapping_product_no_any) AS product_no_candidate,
    COALESCE(sa.option_no_any, sm.mapping_option_no_any) AS option_no_candidate,
    COALESCE(sm.mapping_rows, 0) AS mapping_rows,
    COALESCE(sm.mapping_identity_rows, 0) AS mapping_identity_rows,
    COALESCE(sm.mapping_product_no_distinct_count, 0) AS mapping_product_no_distinct_count,
    COALESCE(sm.mapping_option_no_distinct_count, 0) AS mapping_option_no_distinct_count,
    COALESCE(sm.mapping_own_sku_distinct_count, 0) AS mapping_own_sku_distinct_count,
    COALESCE(oss.max_own_sku_target_count, 0) AS max_own_sku_target_count,
    COALESCE(oss.max_own_sku_product_id_count, 0) AS max_own_sku_product_id_count,
    COALESCE(oss.max_own_sku_selfpia_product_count, 0) AS max_own_sku_selfpia_product_count,
    COALESCE(oss.max_own_sku_smartstore_product_count, 0) AS max_own_sku_smartstore_product_count,
    COALESCE(img.image_rows, 0) AS image_rows,
    lower(COALESCE(cs.option_value, '')) AS option_text_lower,
    false::boolean AS export_allowed,
    'pending'::text AS reviewer_decision
  FROM canonical_sku AS cs
  LEFT JOIN smartstore_alias AS sa
    ON sa.sku_id = cs.sku_id
  LEFT JOIN smartstore_mapping AS sm
    ON sm.sku_id = cs.sku_id
  LEFT JOIN own_sku_scope_by_sku AS oss
    ON oss.sku_id = cs.sku_id
  LEFT JOIN image_by_sku AS img
    ON img.sku_id = cs.sku_id
),

product_option_pair_counts AS (
  SELECT
    product_no_candidate,
    option_no_candidate,
    COUNT(DISTINCT sku_id) AS sku_count_for_product_option
  FROM base
  WHERE NULLIF(btrim(COALESCE(product_no_candidate, '')), '') IS NOT NULL
    AND NULLIF(btrim(COALESCE(option_no_candidate, '')), '') IS NOT NULL
  GROUP BY
    product_no_candidate,
    option_no_candidate
),

selfpia_sku_counts AS (
  SELECT
    selfpia_sku_code,
    COUNT(DISTINCT sku_id) AS selfpia_sku_target_count
  FROM canonical_sku
  WHERE NULLIF(btrim(COALESCE(selfpia_sku_code, '')), '') IS NOT NULL
  GROUP BY selfpia_sku_code
),

candidates AS (
  SELECT
    b.*,
    COALESCE(pop.sku_count_for_product_option, 0) AS sku_count_for_product_option,
    COALESCE(ssc.selfpia_sku_target_count, 0) AS selfpia_sku_target_count,
    (
      b.confirmed_alias_rows > 0
      OR b.mapping_identity_rows > 0
    ) AS matched_confirmed,
    (
      b.candidate_alias_rows > 0
      AND b.product_no_distinct_count <= 1
      AND b.option_no_distinct_count <= 1
      AND b.max_own_sku_target_count <= 1
    ) AS current_auto_match_high_confidence,
    (
      b.product_no_distinct_count > 1
      OR b.option_no_distinct_count > 1
      OR b.mapping_product_no_distinct_count > 1
      OR b.mapping_option_no_distinct_count > 1
      OR b.mapping_own_sku_distinct_count > 1
      OR b.max_own_sku_target_count > 1
    ) AS current_blocked_risk,
    (
      b.alias_rows = 0
      AND b.mapping_rows = 0
      AND b.image_rows = 0
    ) AS channel_absent_or_inactive,
    (
      b.product_no_distinct_count > 1
      OR b.mapping_product_no_distinct_count > 1
    ) AS duplicate_selfpia_sku_to_product,
    (
      b.mapping_own_sku_distinct_count > 1
      OR b.max_own_sku_target_count > 1
    ) AS own_sku_multi_sku_conflict,
    (
      NULLIF(btrim(COALESCE(b.product_no_candidate, '')), '') IS NOT NULL
      AND NULLIF(btrim(COALESCE(b.option_no_candidate, '')), '') IS NOT NULL
      AND COALESCE(pop.sku_count_for_product_option, 0) > 1
    ) AS duplicate_product_option,
    (
      b.option_text_lower LIKE '%크리스탈ab%'
    ) AS crystal_crystal_ab_warning,
    (
      b.option_text_lower LIKE '% ab %'
      OR b.option_text_lower LIKE 'ab %'
      OR b.option_text_lower LIKE '% ab'
      OR b.option_text_lower LIKE '%/ab%'
      OR b.option_text_lower LIKE '%-ab%'
      OR b.option_text_lower LIKE '%(ab%'
      OR b.option_text_lower LIKE '%ab)%'
    ) AS ab_warning,
    (
      b.option_text_lower LIKE '%화이트골드%'
      AND b.option_text_lower LIKE '%실버%'
    ) AS whitegold_silver_warning,
    (
      b.option_text_lower LIKE '%세트%'
      OR b.option_text_lower LIKE '%5개%'
      OR b.option_text_lower LIKE '%10개%'
      OR b.option_text_lower LIKE '%pcs%'
      OR b.option_text_lower LIKE '% ea%'
      OR b.option_text_lower LIKE '%한쌍%'
      OR b.option_text_lower LIKE '%낱개%'
      OR b.option_text_lower LIKE '%pair%'
      OR b.option_text_lower LIKE '%single%'
    ) AS quantity_set_warning,
    false::boolean AS export_allowed_safe,
    'pending'::text AS reviewer_decision_safe
  FROM base AS b
  LEFT JOIN product_option_pair_counts AS pop
    ON pop.product_no_candidate = b.product_no_candidate
   AND pop.option_no_candidate = b.option_no_candidate
  LEFT JOIN selfpia_sku_counts AS ssc
    ON ssc.selfpia_sku_code = b.selfpia_sku_code
),

bucketed AS (
  SELECT
    c.*,
    CASE
      WHEN c.matched_confirmed THEN 'matched_confirmed'
      WHEN c.current_blocked_risk
        AND c.own_sku_multi_sku_conflict
        AND c.selfpia_sku_target_count = 1
        AND NULLIF(btrim(COALESCE(c.product_no_candidate, '')), '') IS NOT NULL
        AND NULLIF(btrim(COALESCE(c.option_no_candidate, '')), '') IS NOT NULL
        AND c.sku_count_for_product_option = 1
        AND NOT c.duplicate_selfpia_sku_to_product
        AND NOT c.crystal_crystal_ab_warning
        AND NOT c.ab_warning
        AND NOT c.whitegold_silver_warning
        AND NOT c.quantity_set_warning
        AND (
          c.max_own_sku_product_id_count <= 1
          OR c.max_own_sku_selfpia_product_count <= 1
          OR c.max_own_sku_smartstore_product_count <= 1
        )
      THEN 'auto_match_high_confidence'
      WHEN c.current_blocked_risk
        AND c.own_sku_multi_sku_conflict
        AND NOT c.duplicate_selfpia_sku_to_product
        AND NOT c.duplicate_product_option
        AND NOT c.crystal_crystal_ab_warning
        AND NOT c.ab_warning
        AND NOT c.whitegold_silver_warning
        AND NOT c.channel_absent_or_inactive
        AND (
          c.quantity_set_warning
          OR (
            NULLIF(btrim(COALESCE(c.product_no_candidate, '')), '') IS NOT NULL
            AND NULLIF(btrim(COALESCE(c.option_no_candidate, '')), '') IS NOT NULL
            AND c.sku_count_for_product_option = 1
          )
          OR NULLIF(btrim(COALESCE(c.product_no_candidate, '')), '') IS NOT NULL
          OR NULLIF(btrim(COALESCE(c.option_no_candidate, '')), '') IS NOT NULL
        )
      THEN 'auto_match_medium_confidence'
      WHEN c.current_blocked_risk
        AND c.own_sku_multi_sku_conflict
        AND c.channel_absent_or_inactive
      THEN 'channel_absent_or_inactive'
      WHEN c.current_blocked_risk THEN 'remain_blocked_risk'
      ELSE 'other'
    END AS dryrun_bucket
  FROM candidates AS c
),

validation_summary AS (
  SELECT
    COUNT(*) FILTER (
      WHERE dryrun_bucket IN ('auto_match_high_confidence', 'auto_match_medium_confidence')
    ) AS candidate_total,
    COUNT(*) FILTER (
      WHERE dryrun_bucket = 'auto_match_high_confidence'
    ) AS high_count,
    COUNT(*) FILTER (
      WHERE dryrun_bucket = 'auto_match_medium_confidence'
    ) AS medium_count,
    COUNT(*) FILTER (
      WHERE dryrun_bucket IN ('auto_match_high_confidence', 'auto_match_medium_confidence')
        AND duplicate_product_option
    ) AS duplicate_product_no_option_no_count,
    COUNT(*) FILTER (
      WHERE dryrun_bucket IN ('auto_match_high_confidence', 'auto_match_medium_confidence')
        AND duplicate_selfpia_sku_to_product
    ) AS duplicate_selfpia_sku_to_product_no_count,
    COUNT(*) FILTER (
      WHERE dryrun_bucket IN ('auto_match_high_confidence', 'auto_match_medium_confidence')
        AND own_sku_multi_sku_conflict
    ) AS own_sku_multi_sku_conflict_count,
    COUNT(*) FILTER (
      WHERE dryrun_bucket = 'remain_blocked_risk'
    ) AS blocked_risk_residual_count,
    COUNT(*) FILTER (
      WHERE dryrun_bucket = 'channel_absent_or_inactive'
    ) AS channel_absent_or_inactive_excluded_count,
    COUNT(*) FILTER (
      WHERE dryrun_bucket IN ('auto_match_high_confidence', 'auto_match_medium_confidence')
        AND crystal_crystal_ab_warning
    ) AS crystal_crystal_ab_warning_count,
    COUNT(*) FILTER (
      WHERE dryrun_bucket IN ('auto_match_high_confidence', 'auto_match_medium_confidence')
        AND ab_warning
    ) AS ab_warning_count,
    COUNT(*) FILTER (
      WHERE dryrun_bucket IN ('auto_match_high_confidence', 'auto_match_medium_confidence')
        AND whitegold_silver_warning
    ) AS whitegold_silver_warning_count,
    COUNT(*) FILTER (
      WHERE dryrun_bucket IN ('auto_match_high_confidence', 'auto_match_medium_confidence')
        AND quantity_set_warning
    ) AS quantity_set_warning_count,
    bool_and(export_allowed_safe = false) AS export_allowed_is_always_false,
    bool_and(reviewer_decision_safe = 'pending') AS reviewer_decision_is_always_pending
  FROM bucketed
)

SELECT 'candidate_total'::text AS validation_item, candidate_total AS row_count, 'high + medium candidates before dryrun.'::text AS note FROM validation_summary
UNION ALL SELECT 'high_count', high_count, 'high confidence candidates.'
FROM validation_summary
UNION ALL SELECT 'medium_count', medium_count, 'medium confidence candidates.'
FROM validation_summary
UNION ALL SELECT 'duplicate_productNo_optionNo_count', duplicate_product_no_option_no_count, 'must be zero before dryrun.'
FROM validation_summary
UNION ALL SELECT 'duplicate_selfpia_sku_to_productNo_count', duplicate_selfpia_sku_to_product_no_count, 'must be zero before dryrun.'
FROM validation_summary
UNION ALL SELECT 'own_sku_multi_sku_conflict_count', own_sku_multi_sku_conflict_count, 'expected non-zero: own_sku duplicate is reclassified, not confirmed.'
FROM validation_summary
UNION ALL SELECT 'blocked_risk_residual_count', blocked_risk_residual_count, 'not an apply target.'
FROM validation_summary
UNION ALL SELECT 'channel_absent_or_inactive_excluded_count', channel_absent_or_inactive_excluded_count, 'excluded from apply target.'
FROM validation_summary
UNION ALL SELECT 'crystal_crystalAB_warning_count', crystal_crystal_ab_warning_count, 'must be zero inside high/medium candidates.'
FROM validation_summary
UNION ALL SELECT 'AB_warning_count', ab_warning_count, 'must be zero inside high/medium candidates.'
FROM validation_summary
UNION ALL SELECT 'whitegold_silver_warning_count', whitegold_silver_warning_count, 'must be zero inside high/medium candidates.'
FROM validation_summary
UNION ALL SELECT 'quantity_set_warning_count', quantity_set_warning_count, 'medium/set warning count inside candidates.'
FROM validation_summary
UNION ALL SELECT 'export_allowed_is_always_false', CASE WHEN export_allowed_is_always_false THEN 1 ELSE 0 END, '1 means export_allowed remains false.'
FROM validation_summary
UNION ALL SELECT 'reviewer_decision_is_always_pending', CASE WHEN reviewer_decision_is_always_pending THEN 1 ELSE 0 END, '1 means reviewer_decision remains pending.'
FROM validation_summary;
