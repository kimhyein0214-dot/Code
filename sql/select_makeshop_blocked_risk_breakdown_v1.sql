/*
  MakeShop blocked-risk breakdown and promotion estimate.

  Purpose:
  - Diagnose MakeShop blocked_risk and unknown_need_check buckets with DB-only evidence.
  - Split duplicate own_sku conflicts into practical reclassification groups.
  - Estimate MakeShop auto-match rate after high/medium promotion.

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

sku_universe AS (
  SELECT
    'makeshop'::text AS channel,
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

makeshop_alias AS (
  SELECT
    ca.target_id AS sku_id,
    COUNT(*) AS alias_rows,
    COUNT(*) FILTER (
      WHERE ca.code_system IN ('makeshop_product_code', 'makeshop_option_code')
    ) AS confirmed_alias_rows,
    COUNT(*) FILTER (
      WHERE ca.code_system IN ('makeshop_product_code_candidate', 'makeshop_option_code_candidate')
    ) AS candidate_alias_rows,
    COUNT(DISTINCT ca.code_value) FILTER (
      WHERE ca.code_system IN ('makeshop_product_code', 'makeshop_product_code_candidate')
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS product_code_distinct_count,
    COUNT(DISTINCT ca.code_value) FILTER (
      WHERE ca.code_system IN ('makeshop_option_code', 'makeshop_option_code_candidate')
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS option_code_distinct_count,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system IN ('makeshop_product_code', 'makeshop_product_code_candidate')
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS product_code_any,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system IN ('makeshop_option_code', 'makeshop_option_code_candidate')
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS option_code_any
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system LIKE 'makeshop%'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.target_id
),

makeshop_mapping AS (
  SELECT
    scm.sku_id,
    COUNT(*) AS mapping_rows,
    COUNT(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS mapping_identity_rows,
    COUNT(DISTINCT scm.seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
    ) AS mapping_product_code_distinct_count,
    COUNT(DISTINCT scm.channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS mapping_option_code_distinct_count,
    COUNT(DISTINCT scm.own_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.own_sku_code, '')), '') IS NOT NULL
    ) AS mapping_own_sku_distinct_count,
    MIN(scm.seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
    ) AS mapping_product_code_any,
    MIN(scm.channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS mapping_option_code_any
  FROM product_code.sku_channel_mapping AS scm
  WHERE lower(scm.channel_code) = 'makeshop'
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
  WHERE lower(scm.channel_code) = 'makeshop'
    AND NULLIF(btrim(COALESCE(scm.own_sku_code, '')), '') IS NOT NULL
),

own_sku_scope AS (
  SELECT
    osv.own_sku_code,
    su.sku_id,
    su.product_id,
    su.selfpia_product_code,
    COALESCE(ma.product_code_any, mm.mapping_product_code_any) AS makeshop_code_key,
    COALESCE(ma.option_code_any, mm.mapping_option_code_any) AS makeshop_option_key
  FROM own_sku_value_by_sku AS osv
  JOIN sku_universe AS su
    ON su.sku_id = osv.sku_id
  LEFT JOIN makeshop_alias AS ma
    ON ma.sku_id = osv.sku_id
  LEFT JOIN makeshop_mapping AS mm
    ON mm.sku_id = osv.sku_id
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
    COUNT(DISTINCT makeshop_code_key) FILTER (
      WHERE NULLIF(btrim(COALESCE(makeshop_code_key, '')), '') IS NOT NULL
    ) AS own_sku_makeshop_code_count
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
    MAX(oss.own_sku_makeshop_code_count) AS max_own_sku_makeshop_code_count
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

joined AS (
  SELECT
    su.channel,
    su.sku_id,
    su.product_id,
    su.selfpia_sku_code,
    su.selfpia_product_code,
    su.product_name,
    su.option_value,
    COALESCE(ma.alias_rows, 0) AS alias_rows,
    COALESCE(ma.confirmed_alias_rows, 0) AS confirmed_alias_rows,
    COALESCE(ma.candidate_alias_rows, 0) AS candidate_alias_rows,
    COALESCE(ma.product_code_distinct_count, 0) AS product_code_distinct_count,
    COALESCE(ma.option_code_distinct_count, 0) AS option_code_distinct_count,
    ma.product_code_any,
    ma.option_code_any,
    COALESCE(mm.mapping_rows, 0) AS mapping_rows,
    COALESCE(mm.mapping_identity_rows, 0) AS mapping_identity_rows,
    COALESCE(mm.mapping_product_code_distinct_count, 0) AS mapping_product_code_distinct_count,
    COALESCE(mm.mapping_option_code_distinct_count, 0) AS mapping_option_code_distinct_count,
    COALESCE(mm.mapping_own_sku_distinct_count, 0) AS mapping_own_sku_distinct_count,
    mm.mapping_product_code_any,
    mm.mapping_option_code_any,
    COALESCE(oss.own_sku_code_count, 0) AS own_sku_code_count,
    COALESCE(oss.max_own_sku_sku_count, 0) AS max_own_sku_sku_count,
    COALESCE(oss.max_own_sku_product_id_count, 0) AS max_own_sku_product_id_count,
    COALESCE(oss.max_own_sku_selfpia_product_count, 0) AS max_own_sku_selfpia_product_count,
    COALESCE(oss.max_own_sku_makeshop_code_count, 0) AS max_own_sku_makeshop_code_count,
    COALESCE(img.image_rows, 0) AS image_rows,
    su.export_allowed,
    su.reviewer_decision
  FROM sku_universe AS su
  LEFT JOIN makeshop_alias AS ma
    ON ma.sku_id = su.sku_id
  LEFT JOIN makeshop_mapping AS mm
    ON mm.sku_id = su.sku_id
  LEFT JOIN own_sku_scope_by_sku AS oss
    ON oss.sku_id = su.sku_id
  LEFT JOIN image_by_sku AS img
    ON img.sku_id = su.sku_id
),

pair_key AS (
  SELECT
    j.*,
    COALESCE(j.product_code_any, j.mapping_product_code_any) AS makeshop_code_key,
    COALESCE(j.option_code_any, j.mapping_option_code_any) AS makeshop_option_key,
    lower(COALESCE(j.option_value, '')) AS option_text_lower
  FROM joined AS j
),

makeshop_code_counts AS (
  SELECT
    makeshop_code_key,
    makeshop_option_key,
    COUNT(DISTINCT sku_id) AS sku_count_for_makeshop_code
  FROM pair_key
  WHERE NULLIF(btrim(COALESCE(makeshop_code_key, '')), '') IS NOT NULL
    AND NULLIF(btrim(COALESCE(makeshop_option_key, '')), '') IS NOT NULL
  GROUP BY
    makeshop_code_key,
    makeshop_option_key
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
    COALESCE(mcc.sku_count_for_makeshop_code, 0) AS sku_count_for_makeshop_code,
    COALESCE(ssc.selfpia_sku_target_count, 0) AS selfpia_sku_target_count,
    (
      pk.confirmed_alias_rows > 0
      OR pk.mapping_identity_rows > 0
    ) AS matched_confirmed,
    (
      pk.candidate_alias_rows > 0
      AND pk.product_code_distinct_count <= 1
      AND pk.option_code_distinct_count <= 1
      AND pk.max_own_sku_sku_count <= 1
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
        pk.product_code_distinct_count > 0
        OR pk.mapping_product_code_distinct_count > 0
      )
      AND pk.max_own_sku_sku_count <= 1
    ) AS current_auto_match_medium_confidence,
    (
      pk.product_code_distinct_count > 1
      OR pk.option_code_distinct_count > 1
      OR pk.mapping_product_code_distinct_count > 1
      OR pk.mapping_option_code_distinct_count > 1
      OR pk.mapping_own_sku_distinct_count > 1
      OR pk.max_own_sku_sku_count > 1
    ) AS current_blocked_risk,
    (
      pk.alias_rows = 0
      AND pk.mapping_rows = 0
      AND pk.image_rows = 0
    ) AS channel_absent_or_inactive,
    (
      pk.alias_rows = 0
      AND pk.mapping_rows = 0
      AND pk.image_rows > 0
    ) AS unknown_need_check,
    (
      pk.product_code_distinct_count > 1
      OR pk.mapping_product_code_distinct_count > 1
    ) AS duplicate_selfpia_sku_to_makeshop_code,
    (
      pk.mapping_own_sku_distinct_count > 1
      OR pk.max_own_sku_sku_count > 1
    ) AS duplicate_own_sku_blocked,
    (
      NULLIF(btrim(COALESCE(pk.makeshop_code_key, '')), '') IS NOT NULL
    ) AS makeshop_code_candidate_exists,
    (
      NULLIF(btrim(COALESCE(pk.makeshop_code_key, '')), '') IS NOT NULL
      AND (
        NULLIF(btrim(COALESCE(pk.makeshop_option_key, '')), '') IS NOT NULL
        OR NULLIF(btrim(COALESCE(pk.option_value, '')), '') IS NOT NULL
      )
    ) AS makeshop_code_and_option_evidence_exists,
    (
      pk.option_text_lower LIKE '%핑골%'
      OR pk.option_text_lower LIKE '%핑크골드%'
      OR pk.option_text_lower LIKE '%로즈골드%'
      OR pk.option_text_lower LIKE '%rose gold%'
      OR pk.option_text_lower LIKE '%rg%'
    ) AS rose_gold_family_absorbable,
    (
      pk.option_text_lower LIKE '%옐로우골드%'
      OR pk.option_text_lower LIKE '%yellow gold%'
      OR pk.option_text_lower LIKE '%yg%'
      OR (
        pk.option_text_lower LIKE '%골드%'
        AND pk.option_text_lower NOT LIKE '%핑골%'
        AND pk.option_text_lower NOT LIKE '%핑크골드%'
        AND pk.option_text_lower NOT LIKE '%로즈골드%'
        AND pk.option_text_lower NOT LIKE '%rose gold%'
        AND pk.option_text_lower NOT LIKE '%화이트골드%'
      )
    ) AS yellow_gold_family_absorbable,
    (
      pk.option_text_lower LIKE '%mm바%'
      OR pk.option_text_lower LIKE '%6mm%'
      OR pk.option_text_lower LIKE '%8mm%'
    ) AS mm_bar_absorbable,
    (
      pk.option_text_lower LIKE '%원타입%'
      OR pk.option_text_lower LIKE '%단일옵션%'
      OR pk.option_text_lower LIKE '%one type%'
    ) AS one_type_absorbable,
    (
      pk.option_text_lower LIKE '%크리스탈ab%'
    ) AS crystal_crystal_ab_true_risk,
    (
      pk.option_text_lower LIKE '% ab %'
      OR pk.option_text_lower LIKE 'ab %'
      OR pk.option_text_lower LIKE '% ab'
      OR pk.option_text_lower LIKE '%/ab%'
      OR pk.option_text_lower LIKE '%-ab%'
      OR pk.option_text_lower LIKE '%(ab%'
      OR pk.option_text_lower LIKE '%ab)%'
    ) AS ab_token_true_risk,
    (
      pk.option_text_lower LIKE '%화이트골드%'
      AND pk.option_text_lower LIKE '%실버%'
    ) AS white_gold_silver_true_risk,
    (
      pk.option_text_lower LIKE '%세트%'
      OR pk.option_text_lower LIKE '%5개%'
      OR pk.option_text_lower LIKE '%10개%'
      OR pk.option_text_lower LIKE '%pcs%'
      OR pk.option_text_lower LIKE '% ea%'
    ) AS quantity_set_true_risk,
    (
      pk.option_text_lower LIKE '%한쌍%'
      OR pk.option_text_lower LIKE '%낱개%'
      OR pk.option_text_lower LIKE '%pair%'
      OR pk.option_text_lower LIKE '%single%'
    ) AS pair_single_set_risk
  FROM pair_key AS pk
  LEFT JOIN makeshop_code_counts AS mcc
    ON mcc.makeshop_code_key = pk.makeshop_code_key
   AND mcc.makeshop_option_key = pk.makeshop_option_key
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
      WHEN d.unknown_need_check THEN 'unknown_need_check'
      ELSE 'manual_review_required'
    END AS matching_presence_status,
    (
      d.rose_gold_family_absorbable
      OR d.yellow_gold_family_absorbable
      OR d.mm_bar_absorbable
      OR d.one_type_absorbable
    ) AS option_normalization_absorbable,
    (
      d.crystal_crystal_ab_true_risk
      OR d.ab_token_true_risk
      OR d.white_gold_silver_true_risk
    ) AS semantic_true_risk,
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
      AND d.makeshop_code_and_option_evidence_exists
      AND d.sku_count_for_makeshop_code = 1
    ) AS duplicate_own_sku_with_unique_makeshop_code,
    (
      d.duplicate_own_sku_blocked
      AND NOT d.makeshop_code_candidate_exists
    ) AS duplicate_own_sku_without_makeshop_evidence,
    (
      d.duplicate_own_sku_blocked
      AND d.quantity_set_true_risk
    ) AS duplicate_own_sku_due_quantity_set,
    (
      d.duplicate_own_sku_blocked
      AND d.pair_single_set_risk
    ) AS duplicate_own_sku_due_pair_single_set,
    (
      d.duplicate_own_sku_blocked
      AND d.channel_absent_or_inactive
    ) AS duplicate_own_sku_due_channel_absent_or_inactive,
    false::boolean AS export_allowed_safe,
    'pending'::text AS reviewer_decision_safe
  FROM diagnosis AS d
),

promotion AS (
  SELECT
    c.*,
    (
      c.matching_presence_status = 'blocked_risk'
      AND c.duplicate_own_sku_blocked
      AND c.selfpia_sku_target_count = 1
      AND c.makeshop_code_and_option_evidence_exists
      AND c.sku_count_for_makeshop_code = 1
      AND NOT c.duplicate_selfpia_sku_to_makeshop_code
      AND NOT c.semantic_true_risk
      AND NOT c.quantity_set_true_risk
      AND (
        c.duplicate_own_sku_same_product_family
        OR c.duplicate_own_sku_same_selfpia_product
      )
    ) AS promotable_to_high_confidence,
    (
      c.matching_presence_status = 'blocked_risk'
      AND c.duplicate_own_sku_blocked
      AND NOT (
        c.selfpia_sku_target_count = 1
        AND c.makeshop_code_and_option_evidence_exists
        AND c.sku_count_for_makeshop_code = 1
        AND NOT c.duplicate_selfpia_sku_to_makeshop_code
        AND NOT c.semantic_true_risk
        AND NOT c.quantity_set_true_risk
        AND (
          c.duplicate_own_sku_same_product_family
          OR c.duplicate_own_sku_same_selfpia_product
        )
      )
      AND NOT c.duplicate_selfpia_sku_to_makeshop_code
      AND NOT c.semantic_true_risk
      AND NOT c.channel_absent_or_inactive
      AND (
        c.duplicate_own_sku_with_unique_makeshop_code
        OR c.option_normalization_absorbable
        OR c.quantity_set_true_risk
        OR c.pair_single_set_risk
        OR (
          c.makeshop_code_candidate_exists
          AND c.duplicate_own_sku_same_product_family
        )
      )
    ) AS promotable_to_medium_confidence,
    (
      c.matching_presence_status = 'blocked_risk'
      AND c.duplicate_own_sku_blocked
      AND (
        c.duplicate_selfpia_sku_to_makeshop_code
        OR (
          c.makeshop_code_and_option_evidence_exists
          AND c.sku_count_for_makeshop_code > 1
        )
        OR c.semantic_true_risk
        OR (
          c.duplicate_own_sku_cross_product
          AND NOT c.duplicate_own_sku_with_unique_makeshop_code
        )
        OR (
          NOT c.makeshop_code_candidate_exists
          AND NOT c.channel_absent_or_inactive
        )
      )
    ) AS true_conflict_or_residual
  FROM classified AS c
),

summary AS (
  SELECT
    COUNT(*) AS makeshop_total_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status <> 'channel_absent_or_inactive'
    ) AS makeshop_channel_present_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
    ) AS current_blocked_risk_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'unknown_need_check'
    ) AS unknown_need_check_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND duplicate_own_sku_blocked
    ) AS duplicate_own_sku_blocked_rows,
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
        AND duplicate_own_sku_with_unique_makeshop_code
    ) AS duplicate_own_sku_with_unique_makeshop_code_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND duplicate_own_sku_without_makeshop_evidence
    ) AS duplicate_own_sku_without_makeshop_evidence_rows,
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
        AND NOT promotable_to_high_confidence
        AND NOT promotable_to_medium_confidence
    ) AS duplicate_own_sku_true_conflict_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND makeshop_code_candidate_exists
    ) AS makeshop_code_candidate_exists_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND option_normalization_absorbable
    ) AS option_normalization_absorbable_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND rose_gold_family_absorbable
    ) AS rose_gold_family_absorbable_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND yellow_gold_family_absorbable
    ) AS yellow_gold_family_absorbable_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND mm_bar_absorbable
    ) AS mm_bar_absorbable_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND one_type_absorbable
    ) AS one_type_absorbable_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND crystal_crystal_ab_true_risk
    ) AS crystal_crystal_ab_true_risk_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND ab_token_true_risk
    ) AS ab_token_true_risk_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND white_gold_silver_true_risk
    ) AS white_gold_silver_true_risk_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND quantity_set_true_risk
    ) AS quantity_set_true_risk_rows,
    COUNT(*) FILTER (
      WHERE promotable_to_high_confidence
    ) AS promotable_to_high_confidence_rows,
    COUNT(*) FILTER (
      WHERE promotable_to_medium_confidence
    ) AS promotable_to_medium_confidence_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND NOT promotable_to_high_confidence
        AND NOT promotable_to_medium_confidence
    ) AS remain_blocked_risk_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status IN (
        'matched_confirmed',
        'auto_match_high_confidence',
        'auto_match_medium_confidence'
      )
    ) AS current_auto_match_rows,
    bool_and(export_allowed_safe = false) AS export_allowed_is_always_false,
    bool_and(reviewer_decision_safe = 'pending') AS reviewer_decision_is_always_pending
  FROM promotion
),

summary_rows AS (
  SELECT 'makeshop_total_rows'::text AS summary_type, 'makeshop'::text AS channel, makeshop_total_rows AS row_count, NULL::numeric AS rate_pct, 'makeshop_total_rows'::text AS denominator_type, 'All canonical selfpia SKU rows evaluated for MakeShop.'::text AS note FROM summary
  UNION ALL SELECT 'makeshop_channel_present_rows', 'makeshop', makeshop_channel_present_rows, NULL::numeric, 'makeshop_channel_present_rows', 'Rows not separated as channel_absent_or_inactive.' FROM summary
  UNION ALL SELECT 'current_blocked_risk_rows', 'makeshop', current_blocked_risk_rows, NULL::numeric, 'makeshop_channel_present_rows', 'Current MakeShop blocked_risk rows.' FROM summary
  UNION ALL SELECT 'unknown_need_check_rows', 'makeshop', unknown_need_check_rows, NULL::numeric, 'makeshop_channel_present_rows', 'Presence/evidence remains inconclusive.' FROM summary
  UNION ALL SELECT 'duplicate_own_sku_blocked_rows', 'makeshop', duplicate_own_sku_blocked_rows, NULL::numeric, 'current_blocked_risk_rows', 'Rows blocked because own_sku repeats or conflicts.' FROM summary
  UNION ALL SELECT 'duplicate_own_sku_same_product_family_rows', 'makeshop', duplicate_own_sku_same_product_family_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Duplicate own_sku stays inside one product_id or selfpia product family.' FROM summary
  UNION ALL SELECT 'duplicate_own_sku_cross_product_rows', 'makeshop', duplicate_own_sku_cross_product_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Duplicate own_sku crosses product_id and selfpia product families.' FROM summary
  UNION ALL SELECT 'duplicate_own_sku_same_selfpia_product_rows', 'makeshop', duplicate_own_sku_same_selfpia_product_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Duplicate own_sku stays inside one selfpia product.' FROM summary
  UNION ALL SELECT 'duplicate_own_sku_with_unique_makeshop_code_rows', 'makeshop', duplicate_own_sku_with_unique_makeshop_code_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'MakeShop code + option evidence maps to one SKU.' FROM summary
  UNION ALL SELECT 'duplicate_own_sku_without_makeshop_evidence_rows', 'makeshop', duplicate_own_sku_without_makeshop_evidence_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'own_sku duplicate has no MakeShop code evidence.' FROM summary
  UNION ALL SELECT 'duplicate_own_sku_due_quantity_set_rows', 'makeshop', duplicate_own_sku_due_quantity_set_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Rows with quantity/set wording.' FROM summary
  UNION ALL SELECT 'duplicate_own_sku_due_pair_single_set_rows', 'makeshop', duplicate_own_sku_due_pair_single_set_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Rows with pair/single wording such as 한쌍 or 낱개.' FROM summary
  UNION ALL SELECT 'duplicate_own_sku_due_channel_absent_or_inactive_rows', 'makeshop', duplicate_own_sku_due_channel_absent_or_inactive_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Rows with no MakeShop evidence except own_sku conflict.' FROM summary
  UNION ALL SELECT 'duplicate_own_sku_true_conflict_rows', 'makeshop', duplicate_own_sku_true_conflict_rows, NULL::numeric, 'duplicate_own_sku_blocked_rows', 'Rows that remain blocked after own_sku reclassification.' FROM summary
  UNION ALL SELECT 'makeshop_code_candidate_exists_rows', 'makeshop', makeshop_code_candidate_exists_rows, NULL::numeric, 'current_blocked_risk_rows', 'Blocked rows with MakeShop code evidence.' FROM summary
  UNION ALL SELECT 'option_normalization_absorbable_rows', 'makeshop', option_normalization_absorbable_rows, NULL::numeric, 'current_blocked_risk_rows', 'Rows with option text that normalization can absorb.' FROM summary
  UNION ALL SELECT 'rose_gold_family_absorbable_rows', 'makeshop', rose_gold_family_absorbable_rows, NULL::numeric, 'current_blocked_risk_rows', '핑골/핑크골드/로즈골드/RG family.' FROM summary
  UNION ALL SELECT 'yellow_gold_family_absorbable_rows', 'makeshop', yellow_gold_family_absorbable_rows, NULL::numeric, 'current_blocked_risk_rows', '골드/옐로우골드/YG family.' FROM summary
  UNION ALL SELECT 'mm_bar_absorbable_rows', 'makeshop', mm_bar_absorbable_rows, NULL::numeric, 'current_blocked_risk_rows', '6mm바/8mm바 option text.' FROM summary
  UNION ALL SELECT 'one_type_absorbable_rows', 'makeshop', one_type_absorbable_rows, NULL::numeric, 'current_blocked_risk_rows', '원타입/단일옵션 option text.' FROM summary
  UNION ALL SELECT 'crystal_crystal_ab_true_risk_rows', 'makeshop', crystal_crystal_ab_true_risk_rows, NULL::numeric, 'current_blocked_risk_rows', '크리스탈AB true-risk rows.' FROM summary
  UNION ALL SELECT 'ab_token_true_risk_rows', 'makeshop', ab_token_true_risk_rows, NULL::numeric, 'current_blocked_risk_rows', 'AB token true-risk rows.' FROM summary
  UNION ALL SELECT 'white_gold_silver_true_risk_rows', 'makeshop', white_gold_silver_true_risk_rows, NULL::numeric, 'current_blocked_risk_rows', '화이트골드/실버 true-risk rows.' FROM summary
  UNION ALL SELECT 'quantity_set_true_risk_rows', 'makeshop', quantity_set_true_risk_rows, NULL::numeric, 'current_blocked_risk_rows', '세트/수량 true-risk rows.' FROM summary
  UNION ALL SELECT 'promotable_to_high_confidence_rows', 'makeshop', promotable_to_high_confidence_rows, NULL::numeric, 'current_blocked_risk_rows', 'Blocked rows promotable to high confidence.' FROM summary
  UNION ALL SELECT 'promotable_to_medium_confidence_rows', 'makeshop', promotable_to_medium_confidence_rows, NULL::numeric, 'current_blocked_risk_rows', 'Blocked rows promotable to medium confidence.' FROM summary
  UNION ALL SELECT 'remain_blocked_risk_rows', 'makeshop', remain_blocked_risk_rows, NULL::numeric, 'current_blocked_risk_rows', 'Rows remaining blocked after reclassification.' FROM summary
  UNION ALL SELECT 'current_auto_match_rows', 'makeshop', current_auto_match_rows, NULL::numeric, 'makeshop_channel_present_rows', 'Current matched + high + medium rows.' FROM summary
  UNION ALL SELECT 'current_channel_presence_based_auto_match_rate_pct', 'makeshop', NULL::bigint, ROUND(100.0 * current_auto_match_rows / NULLIF(makeshop_channel_present_rows, 0), 2), 'makeshop_channel_present_rows', 'Current representative MakeShop auto-match rate.' FROM summary
  UNION ALL SELECT 'makeshop_promotable_to_high_confidence_rows', 'makeshop', promotable_to_high_confidence_rows, NULL::numeric, 'current_blocked_risk_rows', 'High confidence promotion count.' FROM summary
  UNION ALL SELECT 'makeshop_promotable_to_medium_confidence_rows', 'makeshop', promotable_to_medium_confidence_rows, NULL::numeric, 'current_blocked_risk_rows', 'Medium confidence promotion count.' FROM summary
  UNION ALL SELECT 'expected_auto_match_rows_after_reclassification', 'makeshop', current_auto_match_rows + promotable_to_high_confidence_rows + promotable_to_medium_confidence_rows, NULL::numeric, 'makeshop_channel_present_rows', 'Expected auto-match rows after reclassification.' FROM summary
  UNION ALL SELECT 'expected_channel_presence_based_auto_match_rate_pct_after_reclassification', 'makeshop', NULL::bigint, ROUND(100.0 * (current_auto_match_rows + promotable_to_high_confidence_rows + promotable_to_medium_confidence_rows) / NULLIF(makeshop_channel_present_rows, 0), 2), 'makeshop_channel_present_rows', 'Expected representative rate after reclassification.' FROM summary
  UNION ALL SELECT 'expected_auto_match_rate_gain_pct_point', 'makeshop', NULL::bigint, ROUND(100.0 * (promotable_to_high_confidence_rows + promotable_to_medium_confidence_rows) / NULLIF(makeshop_channel_present_rows, 0), 2), 'makeshop_channel_present_rows', 'Expected percentage-point gain from reclassification.' FROM summary
  UNION ALL SELECT 'expected_remain_blocked_risk_rows', 'makeshop', remain_blocked_risk_rows, NULL::numeric, 'makeshop_channel_present_rows', 'Expected remaining blocked rows.' FROM summary
  UNION ALL SELECT 'expected_remain_blocked_risk_rate_pct', 'makeshop', NULL::bigint, ROUND(100.0 * remain_blocked_risk_rows / NULLIF(makeshop_channel_present_rows, 0), 2), 'makeshop_channel_present_rows', 'Expected remaining blocked-risk rate.' FROM summary
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
    WHEN 'makeshop_total_rows' THEN 1
    WHEN 'makeshop_channel_present_rows' THEN 2
    WHEN 'current_blocked_risk_rows' THEN 3
    WHEN 'unknown_need_check_rows' THEN 4
    WHEN 'duplicate_own_sku_blocked_rows' THEN 5
    WHEN 'duplicate_own_sku_same_product_family_rows' THEN 6
    WHEN 'duplicate_own_sku_cross_product_rows' THEN 7
    WHEN 'duplicate_own_sku_same_selfpia_product_rows' THEN 8
    WHEN 'duplicate_own_sku_with_unique_makeshop_code_rows' THEN 9
    WHEN 'duplicate_own_sku_without_makeshop_evidence_rows' THEN 10
    WHEN 'duplicate_own_sku_due_quantity_set_rows' THEN 11
    WHEN 'duplicate_own_sku_due_pair_single_set_rows' THEN 12
    WHEN 'duplicate_own_sku_due_channel_absent_or_inactive_rows' THEN 13
    WHEN 'duplicate_own_sku_true_conflict_rows' THEN 14
    WHEN 'makeshop_code_candidate_exists_rows' THEN 15
    WHEN 'option_normalization_absorbable_rows' THEN 16
    WHEN 'rose_gold_family_absorbable_rows' THEN 17
    WHEN 'yellow_gold_family_absorbable_rows' THEN 18
    WHEN 'mm_bar_absorbable_rows' THEN 19
    WHEN 'one_type_absorbable_rows' THEN 20
    WHEN 'crystal_crystal_ab_true_risk_rows' THEN 21
    WHEN 'ab_token_true_risk_rows' THEN 22
    WHEN 'white_gold_silver_true_risk_rows' THEN 23
    WHEN 'quantity_set_true_risk_rows' THEN 24
    WHEN 'promotable_to_high_confidence_rows' THEN 25
    WHEN 'promotable_to_medium_confidence_rows' THEN 26
    WHEN 'remain_blocked_risk_rows' THEN 27
    WHEN 'current_auto_match_rows' THEN 28
    WHEN 'current_channel_presence_based_auto_match_rate_pct' THEN 29
    WHEN 'makeshop_promotable_to_high_confidence_rows' THEN 30
    WHEN 'makeshop_promotable_to_medium_confidence_rows' THEN 31
    WHEN 'expected_auto_match_rows_after_reclassification' THEN 32
    WHEN 'expected_channel_presence_based_auto_match_rate_pct_after_reclassification' THEN 33
    WHEN 'expected_auto_match_rate_gain_pct_point' THEN 34
    WHEN 'expected_remain_blocked_risk_rows' THEN 35
    WHEN 'expected_remain_blocked_risk_rate_pct' THEN 36
    ELSE 99
  END;
