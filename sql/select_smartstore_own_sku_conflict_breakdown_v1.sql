/*
  Smartstore own_sku conflict breakdown and promotion estimate.

  Purpose:
  - Split Smartstore duplicate_own_sku blocked rows into practical evidence groups.
  - Treat own_sku as strong evidence, but not always as a strict 1:1 SKU key.
  - Estimate the auto-match rate if lower-risk own_sku conflicts move to high/medium confidence.

  Safety:
  - SELECT-only.
  - Read-only summary.
  - No file output.
  - No import.
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

sku_universe AS (
  SELECT
    'smartstore'::text AS channel,
    cs.sku_id,
    cs.product_id,
    cs.selfpia_sku_code,
    cs.selfpia_product_code,
    cs.product_name,
    cs.option_value,
    false::boolean AS export_allowed,
    'pending'::text AS reviewer_decision
  FROM canonical_sku AS cs
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

own_sku_alias_global AS (
  SELECT
    ca.code_value AS own_sku_code,
    COUNT(DISTINCT ca.target_id) AS own_sku_alias_target_count
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.code_value
),

own_sku_alias_conflict_by_sku AS (
  SELECT
    ca.target_id AS sku_id,
    MAX(osg.own_sku_alias_target_count) AS max_own_sku_alias_target_count
  FROM product_code.code_alias AS ca
  JOIN own_sku_alias_global AS osg
    ON osg.own_sku_code = ca.code_value
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.target_id
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

joined AS (
  SELECT
    su.channel,
    su.sku_id,
    su.product_id,
    su.selfpia_sku_code,
    su.selfpia_product_code,
    su.product_name,
    su.option_value,
    COALESCE(sa.alias_rows, 0) AS alias_rows,
    COALESCE(sa.confirmed_alias_rows, 0) AS confirmed_alias_rows,
    COALESCE(sa.candidate_alias_rows, 0) AS candidate_alias_rows,
    COALESCE(sa.product_no_distinct_count, 0) AS product_no_distinct_count,
    COALESCE(sa.option_no_distinct_count, 0) AS option_no_distinct_count,
    sa.product_no_any,
    sa.option_no_any,
    COALESCE(sm.mapping_rows, 0) AS mapping_rows,
    COALESCE(sm.mapping_identity_rows, 0) AS mapping_identity_rows,
    COALESCE(sm.mapping_product_no_distinct_count, 0) AS mapping_product_no_distinct_count,
    COALESCE(sm.mapping_option_no_distinct_count, 0) AS mapping_option_no_distinct_count,
    COALESCE(sm.mapping_own_sku_distinct_count, 0) AS mapping_own_sku_distinct_count,
    sm.mapping_product_no_any,
    sm.mapping_option_no_any,
    COALESCE(oac.max_own_sku_alias_target_count, 0) AS max_own_sku_alias_target_count,
    COALESCE(img.image_rows, 0) AS image_rows,
    su.export_allowed,
    su.reviewer_decision
  FROM sku_universe AS su
  LEFT JOIN smartstore_alias AS sa
    ON sa.sku_id = su.sku_id
  LEFT JOIN smartstore_mapping AS sm
    ON sm.sku_id = su.sku_id
  LEFT JOIN own_sku_alias_conflict_by_sku AS oac
    ON oac.sku_id = su.sku_id
  LEFT JOIN image_by_sku AS img
    ON img.sku_id = su.sku_id
),

pair_key AS (
  SELECT
    j.*,
    COALESCE(j.product_no_any, j.mapping_product_no_any) AS product_no_key,
    COALESCE(j.option_no_any, j.mapping_option_no_any) AS option_no_key,
    lower(COALESCE(j.option_value, '')) AS option_text_lower
  FROM joined AS j
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
    pk.sku_id,
    pk.product_id,
    pk.selfpia_product_code,
    pk.product_no_key,
    pk.option_no_key
  FROM own_sku_value_by_sku AS osv
  JOIN pair_key AS pk
    ON pk.sku_id = osv.sku_id
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
    ) AS own_sku_smartstore_product_count,
    COUNT(DISTINCT product_no_key || '|' || option_no_key) FILTER (
      WHERE NULLIF(btrim(COALESCE(product_no_key, '')), '') IS NOT NULL
        AND NULLIF(btrim(COALESCE(option_no_key, '')), '') IS NOT NULL
    ) AS own_sku_product_option_count
  FROM own_sku_scope
  GROUP BY own_sku_code
),

own_sku_scope_by_sku AS (
  SELECT
    osv.sku_id,
    COUNT(DISTINCT osv.own_sku_code) AS own_sku_code_count,
    MAX(oss.own_sku_sku_count) AS max_own_sku_sku_count,
    MAX(oss.own_sku_product_id_count) AS max_own_sku_product_id_count,
    MAX(oss.own_sku_selfpia_product_count) AS max_own_sku_selfpia_product_count,
    MAX(oss.own_sku_smartstore_product_count) AS max_own_sku_smartstore_product_count,
    MAX(oss.own_sku_product_option_count) AS max_own_sku_product_option_count
  FROM own_sku_value_by_sku AS osv
  JOIN own_sku_scope_stats AS oss
    ON oss.own_sku_code = osv.own_sku_code
  GROUP BY osv.sku_id
),

product_option_pair_counts AS (
  SELECT
    product_no_key,
    option_no_key,
    COUNT(DISTINCT sku_id) AS sku_count_for_product_option
  FROM pair_key
  WHERE NULLIF(btrim(COALESCE(product_no_key, '')), '') IS NOT NULL
    AND NULLIF(btrim(COALESCE(option_no_key, '')), '') IS NOT NULL
  GROUP BY
    product_no_key,
    option_no_key
),

selfpia_sku_counts AS (
  SELECT
    selfpia_sku_code,
    COUNT(DISTINCT sku_id) AS selfpia_sku_target_count
  FROM canonical_sku
  WHERE NULLIF(btrim(COALESCE(selfpia_sku_code, '')), '') IS NOT NULL
  GROUP BY selfpia_sku_code
),

diagnosis AS (
  SELECT
    pk.*,
    COALESCE(oss.own_sku_code_count, 0) AS own_sku_code_count,
    COALESCE(oss.max_own_sku_sku_count, 0) AS max_own_sku_sku_count,
    COALESCE(oss.max_own_sku_product_id_count, 0) AS max_own_sku_product_id_count,
    COALESCE(oss.max_own_sku_selfpia_product_count, 0) AS max_own_sku_selfpia_product_count,
    COALESCE(oss.max_own_sku_smartstore_product_count, 0) AS max_own_sku_smartstore_product_count,
    COALESCE(oss.max_own_sku_product_option_count, 0) AS max_own_sku_product_option_count,
    COALESCE(pop.sku_count_for_product_option, 0) AS sku_count_for_product_option,
    COALESCE(ssc.selfpia_sku_target_count, 0) AS selfpia_sku_target_count,
    (
      pk.confirmed_alias_rows > 0
      OR pk.mapping_identity_rows > 0
    ) AS matched_confirmed,
    (
      pk.candidate_alias_rows > 0
      AND pk.product_no_distinct_count <= 1
      AND pk.option_no_distinct_count <= 1
      AND pk.max_own_sku_alias_target_count <= 1
    ) AS current_auto_match_high_confidence,
    (
      (
        pk.candidate_alias_rows > 0
        OR pk.alias_rows > 0
        OR pk.mapping_rows > 0
      )
      AND NOT (
        pk.confirmed_alias_rows > 0
        OR pk.mapping_identity_rows > 0
      )
      AND (
        pk.product_no_distinct_count > 0
        OR pk.mapping_product_no_distinct_count > 0
      )
      AND pk.max_own_sku_alias_target_count <= 1
    ) AS current_auto_match_medium_confidence,
    (
      pk.product_no_distinct_count > 1
      OR pk.option_no_distinct_count > 1
      OR pk.mapping_product_no_distinct_count > 1
      OR pk.mapping_option_no_distinct_count > 1
      OR pk.mapping_own_sku_distinct_count > 1
      OR pk.max_own_sku_alias_target_count > 1
    ) AS current_blocked_risk,
    (
      pk.alias_rows = 0
      AND pk.mapping_rows = 0
      AND pk.image_rows = 0
    ) AS channel_absent_or_inactive,
    (
      pk.product_no_distinct_count > 1
      OR pk.mapping_product_no_distinct_count > 1
    ) AS duplicate_selfpia_sku_to_product_blocked,
    (
      pk.mapping_own_sku_distinct_count > 1
      OR pk.max_own_sku_alias_target_count > 1
    ) AS duplicate_own_sku_blocked,
    (
      NULLIF(btrim(COALESCE(pk.product_no_key, '')), '') IS NOT NULL
      AND NULLIF(btrim(COALESCE(pk.option_no_key, '')), '') IS NOT NULL
    ) AS product_no_and_option_candidate_exists,
    (
      NULLIF(btrim(COALESCE(pk.product_no_key, '')), '') IS NULL
      AND NULLIF(btrim(COALESCE(pk.option_no_key, '')), '') IS NULL
    ) AS without_product_option_evidence,
    (
      pk.option_text_lower LIKE '%mm바%'
      OR pk.option_text_lower LIKE '%6mm%'
      OR pk.option_text_lower LIKE '%8mm%'
      OR pk.option_text_lower LIKE '%핑골%'
      OR pk.option_text_lower LIKE '%핑크골드%'
      OR pk.option_text_lower LIKE '%로즈골드%'
      OR pk.option_text_lower LIKE '%rose gold%'
      OR pk.option_text_lower LIKE '%주문제작%'
      OR pk.option_text_lower LIKE '%원타입%'
      OR pk.option_text_lower LIKE '%단일옵션%'
      OR pk.option_text_lower LIKE '%one type%'
    ) AS option_normalization_absorbable,
    (
      pk.option_text_lower LIKE '%크리스탈ab%'
      OR pk.option_text_lower LIKE '% ab %'
      OR pk.option_text_lower LIKE 'ab %'
      OR pk.option_text_lower LIKE '% ab'
      OR pk.option_text_lower LIKE '%/ab%'
      OR pk.option_text_lower LIKE '%-ab%'
      OR pk.option_text_lower LIKE '%(ab%'
      OR pk.option_text_lower LIKE '%ab)%'
      OR (
        pk.option_text_lower LIKE '%화이트골드%'
        AND pk.option_text_lower LIKE '%실버%'
      )
    ) AS option_true_risk,
    (
      pk.option_text_lower LIKE '%세트%'
      OR pk.option_text_lower LIKE '%5개%'
      OR pk.option_text_lower LIKE '%10개%'
      OR pk.option_text_lower LIKE '%pcs%'
      OR pk.option_text_lower LIKE '% ea%'
    ) AS quantity_set_risk,
    (
      pk.option_text_lower LIKE '%한쌍%'
      OR pk.option_text_lower LIKE '%낱개%'
      OR pk.option_text_lower LIKE '%pair%'
      OR pk.option_text_lower LIKE '%single%'
    ) AS pair_single_risk
  FROM pair_key AS pk
  LEFT JOIN own_sku_scope_by_sku AS oss
    ON oss.sku_id = pk.sku_id
  LEFT JOIN product_option_pair_counts AS pop
    ON pop.product_no_key = pk.product_no_key
   AND pop.option_no_key = pk.option_no_key
  LEFT JOIN selfpia_sku_counts AS ssc
    ON ssc.selfpia_sku_code = pk.selfpia_sku_code
),

classified AS (
  SELECT
    d.*,
    CASE
      WHEN d.matched_confirmed THEN 'matched_confirmed'
      WHEN d.current_blocked_risk THEN 'blocked_risk'
      WHEN d.current_auto_match_high_confidence THEN 'auto_match_high_confidence'
      WHEN d.current_auto_match_medium_confidence THEN 'auto_match_medium_confidence'
      WHEN d.channel_absent_or_inactive THEN 'channel_absent_or_inactive'
      ELSE 'unknown_need_check'
    END AS matching_presence_status,
    (
      d.duplicate_own_sku_blocked
      AND (
        d.max_own_sku_product_id_count <= 1
        OR d.max_own_sku_selfpia_product_count <= 1
      )
    ) AS duplicate_own_sku_same_product_family,
    (
      d.duplicate_own_sku_blocked
      AND d.max_own_sku_product_id_count > 1
      AND d.max_own_sku_selfpia_product_count > 1
    ) AS duplicate_own_sku_cross_product,
    (
      d.duplicate_own_sku_blocked
      AND d.max_own_sku_selfpia_product_count <= 1
    ) AS duplicate_own_sku_same_selfpia_product,
    (
      d.duplicate_own_sku_blocked
      AND d.max_own_sku_smartstore_product_count <= 1
      AND NULLIF(btrim(COALESCE(d.product_no_key, '')), '') IS NOT NULL
    ) AS duplicate_own_sku_same_smartstore_product,
    (
      d.duplicate_own_sku_blocked
      AND d.product_no_and_option_candidate_exists
      AND d.sku_count_for_product_option = 1
    ) AS duplicate_own_sku_with_unique_product_option,
    (
      d.duplicate_own_sku_blocked
      AND d.selfpia_sku_target_count = 1
    ) AS duplicate_own_sku_with_unique_selfpia_sku,
    (
      d.duplicate_own_sku_blocked
      AND d.product_no_and_option_candidate_exists
    ) AS duplicate_own_sku_with_candidate_product_option,
    (
      d.duplicate_own_sku_blocked
      AND d.without_product_option_evidence
    ) AS duplicate_own_sku_without_product_option_evidence,
    (
      d.duplicate_own_sku_blocked
      AND d.quantity_set_risk
    ) AS duplicate_own_sku_due_quantity_set,
    (
      d.duplicate_own_sku_blocked
      AND d.pair_single_risk
    ) AS duplicate_own_sku_due_pair_single_set,
    (
      d.duplicate_own_sku_blocked
      AND d.channel_absent_or_inactive
    ) AS duplicate_own_sku_due_channel_absent_or_inactive,
    false::boolean AS export_allowed_safe,
    'pending'::text AS reviewer_decision_safe
  FROM diagnosis AS d
),

reclassification AS (
  SELECT
    c.*,
    (
      c.matching_presence_status = 'blocked_risk'
      AND c.duplicate_own_sku_blocked
      AND c.product_no_and_option_candidate_exists
      AND c.sku_count_for_product_option = 1
      AND (
        c.duplicate_own_sku_same_product_family
        OR c.duplicate_own_sku_same_selfpia_product
        OR c.duplicate_own_sku_same_smartstore_product
      )
    ) AS same_product_option_repeat,
    (
      c.matching_presence_status = 'blocked_risk'
      AND c.duplicate_own_sku_blocked
      AND (
        c.quantity_set_risk
        OR c.pair_single_risk
      )
      AND NOT c.option_true_risk
    ) AS set_or_quantity_repeat,
    (
      c.matching_presence_status = 'blocked_risk'
      AND c.duplicate_own_sku_blocked
      AND c.channel_absent_or_inactive
      AND c.alias_rows = 0
      AND c.mapping_rows = 0
      AND c.image_rows = 0
    ) AS stale_or_channel_absent_repeat,
    (
      c.matching_presence_status = 'blocked_risk'
      AND c.duplicate_own_sku_blocked
      AND (
        c.duplicate_selfpia_sku_to_product_blocked
        OR (
          c.product_no_and_option_candidate_exists
          AND c.sku_count_for_product_option > 1
        )
        OR c.option_true_risk
        OR (
          c.duplicate_own_sku_cross_product
          AND NOT c.duplicate_own_sku_same_smartstore_product
          AND NOT c.duplicate_own_sku_with_unique_product_option
        )
        OR (
          c.without_product_option_evidence
          AND NOT c.channel_absent_or_inactive
        )
      )
    ) AS true_cross_product_conflict
  FROM classified AS c
),

promotion AS (
  SELECT
    r.*,
    (
      r.same_product_option_repeat
      AND r.selfpia_sku_target_count = 1
      AND NOT r.duplicate_selfpia_sku_to_product_blocked
      AND NOT r.option_true_risk
      AND NOT r.set_or_quantity_repeat
      AND NOT r.stale_or_channel_absent_repeat
    ) AS own_sku_promotable_to_high_confidence,
    (
      r.matching_presence_status = 'blocked_risk'
      AND r.duplicate_own_sku_blocked
      AND NOT (
        r.same_product_option_repeat
        AND r.selfpia_sku_target_count = 1
        AND NOT r.duplicate_selfpia_sku_to_product_blocked
        AND NOT r.option_true_risk
        AND NOT r.set_or_quantity_repeat
        AND NOT r.stale_or_channel_absent_repeat
      )
      AND NOT r.true_cross_product_conflict
      AND NOT r.stale_or_channel_absent_repeat
      AND (
        r.same_product_option_repeat
        OR r.set_or_quantity_repeat
        OR r.duplicate_own_sku_with_unique_product_option
        OR r.duplicate_own_sku_same_smartstore_product
        OR (
          r.product_no_and_option_candidate_exists
          AND r.option_normalization_absorbable
        )
      )
    ) AS own_sku_promotable_to_medium_confidence
  FROM reclassification AS r
),

final_summary AS (
  SELECT
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
    ) AS smartstore_blocked_risk_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND duplicate_own_sku_blocked
    ) AS duplicate_own_sku_blocked_rows,
    COUNT(*) FILTER (
      WHERE same_product_option_repeat
    ) AS same_product_option_repeat_rows,
    COUNT(*) FILTER (
      WHERE set_or_quantity_repeat
    ) AS set_or_quantity_repeat_rows,
    COUNT(*) FILTER (
      WHERE stale_or_channel_absent_repeat
    ) AS stale_or_channel_absent_repeat_rows,
    COUNT(*) FILTER (
      WHERE true_cross_product_conflict
    ) AS true_cross_product_conflict_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND duplicate_own_sku_same_product_family
    ) AS duplicate_own_sku_same_product_family_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND duplicate_own_sku_cross_product
    ) AS duplicate_own_sku_cross_product_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND duplicate_own_sku_same_selfpia_product
    ) AS duplicate_own_sku_same_selfpia_product_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND duplicate_own_sku_same_smartstore_product
    ) AS duplicate_own_sku_same_smartstore_product_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND duplicate_own_sku_with_unique_product_option
    ) AS duplicate_own_sku_with_unique_product_option_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND duplicate_own_sku_with_unique_selfpia_sku
    ) AS duplicate_own_sku_with_unique_selfpia_sku_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND duplicate_own_sku_with_candidate_product_option
    ) AS duplicate_own_sku_with_candidate_product_option_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND duplicate_own_sku_without_product_option_evidence
    ) AS duplicate_own_sku_without_product_option_evidence_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND duplicate_own_sku_due_quantity_set
    ) AS duplicate_own_sku_due_quantity_set_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND duplicate_own_sku_due_pair_single_set
    ) AS duplicate_own_sku_due_pair_single_set_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND duplicate_own_sku_due_channel_absent_or_inactive
    ) AS duplicate_own_sku_due_channel_absent_or_inactive_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND duplicate_own_sku_blocked
        AND true_cross_product_conflict
    ) AS duplicate_own_sku_true_conflict_rows,
    COUNT(*) FILTER (
      WHERE own_sku_promotable_to_high_confidence
    ) AS own_sku_conflict_promotable_to_high_confidence_rows,
    COUNT(*) FILTER (
      WHERE own_sku_promotable_to_medium_confidence
    ) AS own_sku_conflict_promotable_to_medium_confidence_rows,
    COUNT(*) FILTER (
      WHERE own_sku_promotable_to_high_confidence
    ) AS own_sku_repeat_promotable_to_high_confidence_rows,
    COUNT(*) FILTER (
      WHERE own_sku_promotable_to_medium_confidence
    ) AS own_sku_repeat_promotable_to_medium_confidence_rows,
    COUNT(*) FILTER (
      WHERE stale_or_channel_absent_repeat
    ) AS own_sku_repeat_channel_absent_or_inactive_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND duplicate_own_sku_blocked
        AND NOT own_sku_promotable_to_high_confidence
        AND NOT own_sku_promotable_to_medium_confidence
        AND NOT stale_or_channel_absent_repeat
    ) AS own_sku_conflict_remain_blocked_risk_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND duplicate_own_sku_blocked
        AND NOT own_sku_promotable_to_high_confidence
        AND NOT own_sku_promotable_to_medium_confidence
        AND NOT stale_or_channel_absent_repeat
    ) AS own_sku_repeat_remain_blocked_risk_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status IN (
        'matched_confirmed',
        'auto_match_high_confidence',
        'auto_match_medium_confidence'
      )
    ) AS current_auto_match_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status <> 'channel_absent_or_inactive'
    ) AS smartstore_channel_present_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status <> 'channel_absent_or_inactive'
    ) - COUNT(*) FILTER (
      WHERE stale_or_channel_absent_repeat
    ) AS expected_channel_present_rows_after_own_sku_reclassification,
    bool_and(export_allowed_safe = false) AS export_allowed_is_always_false,
    bool_and(reviewer_decision_safe = 'pending') AS reviewer_decision_is_always_pending
  FROM promotion
),

summary_rows AS (
  SELECT 'smartstore_blocked_risk_rows'::text AS summary_type, 'smartstore'::text AS channel, smartstore_blocked_risk_rows AS row_count, NULL::numeric AS rate_pct, 'smartstore_channel_present_rows'::text AS denominator_type, 'Current Smartstore blocked_risk rows from lite classification.'::text AS note FROM final_summary
  UNION ALL SELECT 'duplicate_own_sku_blocked_rows', 'smartstore', duplicate_own_sku_blocked_rows, NULL::numeric, 'smartstore_blocked_risk_rows', 'Rows blocked because own_sku is duplicated or internally conflicting.' FROM final_summary
  UNION ALL SELECT 'same_product_option_repeat_rows', 'smartstore', same_product_option_repeat_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Duplicate own_sku repeated inside the same product/product-option context.' FROM final_summary
  UNION ALL SELECT 'set_or_quantity_repeat_rows', 'smartstore', set_or_quantity_repeat_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Duplicate own_sku tied to set, pair, single, or quantity wording.' FROM final_summary
  UNION ALL SELECT 'stale_or_channel_absent_repeat_rows', 'smartstore', stale_or_channel_absent_repeat_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Duplicate own_sku with no Smartstore evidence, treated as inactive/historical candidate.' FROM final_summary
  UNION ALL SELECT 'true_cross_product_conflict_rows', 'smartstore', true_cross_product_conflict_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Duplicate own_sku that still looks like cross-product or semantic conflict.' FROM final_summary
  UNION ALL SELECT 'duplicate_own_sku_same_product_family_rows', 'smartstore', duplicate_own_sku_same_product_family_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Duplicate own_sku stays inside one product_id or selfpia product family.' FROM final_summary
  UNION ALL SELECT 'duplicate_own_sku_cross_product_rows', 'smartstore', duplicate_own_sku_cross_product_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Duplicate own_sku crosses product_id and selfpia product families.' FROM final_summary
  UNION ALL SELECT 'duplicate_own_sku_same_selfpia_product_rows', 'smartstore', duplicate_own_sku_same_selfpia_product_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Duplicate own_sku remains inside one selfpia product code.' FROM final_summary
  UNION ALL SELECT 'duplicate_own_sku_same_smartstore_product_rows', 'smartstore', duplicate_own_sku_same_smartstore_product_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Duplicate own_sku remains inside one Smartstore productNo.' FROM final_summary
  UNION ALL SELECT 'duplicate_own_sku_with_unique_product_option_rows', 'smartstore', duplicate_own_sku_with_unique_product_option_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Rows where Smartstore productNo + optionNo pair is unique.' FROM final_summary
  UNION ALL SELECT 'duplicate_own_sku_with_unique_selfpia_sku_rows', 'smartstore', duplicate_own_sku_with_unique_selfpia_sku_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Rows where selfpia_sku maps to one DB SKU.' FROM final_summary
  UNION ALL SELECT 'duplicate_own_sku_with_candidate_product_option_rows', 'smartstore', duplicate_own_sku_with_candidate_product_option_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Rows with both productNo and option evidence.' FROM final_summary
  UNION ALL SELECT 'duplicate_own_sku_without_product_option_evidence_rows', 'smartstore', duplicate_own_sku_without_product_option_evidence_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Rows with own_sku conflict but no productNo/option evidence.' FROM final_summary
  UNION ALL SELECT 'duplicate_own_sku_due_quantity_set_rows', 'smartstore', duplicate_own_sku_due_quantity_set_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Rows with quantity or set wording.' FROM final_summary
  UNION ALL SELECT 'duplicate_own_sku_due_pair_single_set_rows', 'smartstore', duplicate_own_sku_due_pair_single_set_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Rows with pair/single wording such as 한쌍 or 낱개.' FROM final_summary
  UNION ALL SELECT 'duplicate_own_sku_due_channel_absent_or_inactive_rows', 'smartstore', duplicate_own_sku_due_channel_absent_or_inactive_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Rows with no Smartstore evidence except own_sku conflict.' FROM final_summary
  UNION ALL SELECT 'duplicate_own_sku_true_conflict_rows', 'smartstore', duplicate_own_sku_true_conflict_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Rows that remain blocked after own_sku reclassification.' FROM final_summary
  UNION ALL SELECT 'own_sku_conflict_promotable_to_high_confidence_rows', 'smartstore', own_sku_conflict_promotable_to_high_confidence_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'own_sku duplicate rows promotable to high confidence.' FROM final_summary
  UNION ALL SELECT 'own_sku_conflict_promotable_to_medium_confidence_rows', 'smartstore', own_sku_conflict_promotable_to_medium_confidence_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'own_sku duplicate rows promotable to medium confidence.' FROM final_summary
  UNION ALL SELECT 'own_sku_repeat_promotable_to_high_confidence_rows', 'smartstore', own_sku_repeat_promotable_to_high_confidence_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Repeat rows promotable to high confidence under domain reclassification.' FROM final_summary
  UNION ALL SELECT 'own_sku_repeat_promotable_to_medium_confidence_rows', 'smartstore', own_sku_repeat_promotable_to_medium_confidence_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Repeat rows promotable to medium confidence or set warning.' FROM final_summary
  UNION ALL SELECT 'own_sku_repeat_channel_absent_or_inactive_rows', 'smartstore', own_sku_repeat_channel_absent_or_inactive_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Repeat rows separable as channel_absent_or_inactive.' FROM final_summary
  UNION ALL SELECT 'own_sku_repeat_remain_blocked_risk_rows', 'smartstore', own_sku_repeat_remain_blocked_risk_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Repeat rows still blocked after reclassification.' FROM final_summary
  UNION ALL SELECT 'own_sku_conflict_remain_blocked_risk_rows', 'smartstore', own_sku_conflict_remain_blocked_risk_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'own_sku duplicate rows remaining blocked.' FROM final_summary
  UNION ALL SELECT 'current_auto_match_rows', 'smartstore', current_auto_match_rows, NULL::numeric, 'smartstore_channel_present_rows', 'Current matched + high + medium rows.' FROM final_summary
  UNION ALL SELECT 'current_channel_presence_based_auto_match_rate_pct', 'smartstore', NULL::bigint, ROUND(100.0 * current_auto_match_rows / NULLIF(smartstore_channel_present_rows, 0), 2), 'smartstore_channel_present_rows', 'Current representative Smartstore auto-match rate.' FROM final_summary
  UNION ALL SELECT 'own_sku_promotable_to_high_confidence_rows', 'smartstore', own_sku_conflict_promotable_to_high_confidence_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'High confidence promotion count used in the rate estimate.' FROM final_summary
  UNION ALL SELECT 'own_sku_promotable_to_medium_confidence_rows', 'smartstore', own_sku_conflict_promotable_to_medium_confidence_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Medium confidence promotion count used in the rate estimate.' FROM final_summary
  UNION ALL SELECT 'expected_auto_match_rows_after_own_sku_reclassification', 'smartstore', current_auto_match_rows + own_sku_repeat_promotable_to_high_confidence_rows + own_sku_repeat_promotable_to_medium_confidence_rows, NULL::numeric, 'expected_channel_present_rows_after_own_sku_reclassification', 'Expected auto-match rows after own_sku reclassification.' FROM final_summary
  UNION ALL SELECT 'expected_channel_presence_based_auto_match_rate_pct_after_own_sku_reclassification', 'smartstore', NULL::bigint, ROUND(100.0 * (current_auto_match_rows + own_sku_repeat_promotable_to_high_confidence_rows + own_sku_repeat_promotable_to_medium_confidence_rows) / NULLIF(expected_channel_present_rows_after_own_sku_reclassification, 0), 2), 'expected_channel_present_rows_after_own_sku_reclassification', 'Expected representative rate after own_sku reclassification.' FROM final_summary
  UNION ALL SELECT 'expected_auto_match_rate_gain_pct_point', 'smartstore', NULL::bigint, ROUND(100.0 * (current_auto_match_rows + own_sku_repeat_promotable_to_high_confidence_rows + own_sku_repeat_promotable_to_medium_confidence_rows) / NULLIF(expected_channel_present_rows_after_own_sku_reclassification, 0), 2) - ROUND(100.0 * current_auto_match_rows / NULLIF(smartstore_channel_present_rows, 0), 2), 'expected_channel_present_rows_after_own_sku_reclassification', 'Expected percentage-point gain from own_sku reclassification.' FROM final_summary
  UNION ALL SELECT 'expected_remain_blocked_risk_rows', 'smartstore', smartstore_blocked_risk_rows - own_sku_repeat_promotable_to_high_confidence_rows - own_sku_repeat_promotable_to_medium_confidence_rows - own_sku_repeat_channel_absent_or_inactive_rows, NULL::numeric, 'expected_channel_present_rows_after_own_sku_reclassification', 'Expected remaining blocked rows after own_sku reclassification.' FROM final_summary
  UNION ALL SELECT 'expected_remain_blocked_risk_rate_pct', 'smartstore', NULL::bigint, ROUND(100.0 * (smartstore_blocked_risk_rows - own_sku_repeat_promotable_to_high_confidence_rows - own_sku_repeat_promotable_to_medium_confidence_rows - own_sku_repeat_channel_absent_or_inactive_rows) / NULLIF(expected_channel_present_rows_after_own_sku_reclassification, 0), 2), 'expected_channel_present_rows_after_own_sku_reclassification', 'Expected remaining blocked-risk rate after own_sku reclassification.' FROM final_summary
)

SELECT
  summary_type,
  channel,
  row_count,
  rate_pct,
  denominator_type,
  note
FROM summary_rows
ORDER BY
  CASE summary_type
    WHEN 'smartstore_blocked_risk_rows' THEN 1
    WHEN 'duplicate_own_sku_blocked_rows' THEN 2
    WHEN 'same_product_option_repeat_rows' THEN 3
    WHEN 'set_or_quantity_repeat_rows' THEN 4
    WHEN 'stale_or_channel_absent_repeat_rows' THEN 5
    WHEN 'true_cross_product_conflict_rows' THEN 6
    WHEN 'duplicate_own_sku_same_product_family_rows' THEN 7
    WHEN 'duplicate_own_sku_cross_product_rows' THEN 8
    WHEN 'duplicate_own_sku_same_selfpia_product_rows' THEN 9
    WHEN 'duplicate_own_sku_same_smartstore_product_rows' THEN 10
    WHEN 'duplicate_own_sku_with_unique_product_option_rows' THEN 11
    WHEN 'duplicate_own_sku_with_unique_selfpia_sku_rows' THEN 12
    WHEN 'duplicate_own_sku_with_candidate_product_option_rows' THEN 13
    WHEN 'duplicate_own_sku_without_product_option_evidence_rows' THEN 14
    WHEN 'duplicate_own_sku_due_quantity_set_rows' THEN 15
    WHEN 'duplicate_own_sku_due_pair_single_set_rows' THEN 16
    WHEN 'duplicate_own_sku_due_channel_absent_or_inactive_rows' THEN 17
    WHEN 'duplicate_own_sku_true_conflict_rows' THEN 18
    WHEN 'own_sku_conflict_promotable_to_high_confidence_rows' THEN 19
    WHEN 'own_sku_conflict_promotable_to_medium_confidence_rows' THEN 20
    WHEN 'own_sku_repeat_promotable_to_high_confidence_rows' THEN 21
    WHEN 'own_sku_repeat_promotable_to_medium_confidence_rows' THEN 22
    WHEN 'own_sku_repeat_channel_absent_or_inactive_rows' THEN 23
    WHEN 'own_sku_repeat_remain_blocked_risk_rows' THEN 24
    WHEN 'own_sku_conflict_remain_blocked_risk_rows' THEN 25
    WHEN 'current_auto_match_rows' THEN 26
    WHEN 'current_channel_presence_based_auto_match_rate_pct' THEN 27
    WHEN 'own_sku_promotable_to_high_confidence_rows' THEN 28
    WHEN 'own_sku_promotable_to_medium_confidence_rows' THEN 29
    WHEN 'expected_auto_match_rows_after_own_sku_reclassification' THEN 30
    WHEN 'expected_channel_presence_based_auto_match_rate_pct_after_own_sku_reclassification' THEN 31
    WHEN 'expected_auto_match_rate_gain_pct_point' THEN 32
    WHEN 'expected_remain_blocked_risk_rows' THEN 33
    WHEN 'expected_remain_blocked_risk_rate_pct' THEN 34
    ELSE 99
  END;
