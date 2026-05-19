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

validation_summary AS (
  SELECT
    COUNT(*) FILTER (WHERE promotable_to_high_confidence OR promotable_to_medium_confidence) AS candidate_total,
    COUNT(*) FILTER (WHERE promotable_to_high_confidence) AS high_candidate_count,
    COUNT(*) FILTER (WHERE promotable_to_medium_confidence AND NOT promotable_to_high_confidence) AS medium_candidate_count,
    COUNT(*) FILTER (WHERE (promotable_to_high_confidence OR promotable_to_medium_confidence) AND makeshop_code_and_option_evidence_exists AND sku_count_for_makeshop_code > 1) AS duplicate_makeshop_code_count,
    COUNT(*) FILTER (WHERE (promotable_to_high_confidence OR promotable_to_medium_confidence) AND duplicate_selfpia_sku_to_makeshop_code) AS duplicate_selfpia_to_makeshop_count,
    COUNT(*) FILTER (WHERE (promotable_to_high_confidence OR promotable_to_medium_confidence) AND duplicate_own_sku_blocked) AS own_sku_multi_conflict_count,
    COUNT(*) FILTER (WHERE (promotable_to_high_confidence OR promotable_to_medium_confidence) AND (semantic_true_risk OR quantity_set_true_risk)) AS semantic_warning_count,
    COUNT(*) FILTER (WHERE matching_presence_status = 'blocked_risk' AND NOT promotable_to_high_confidence AND NOT promotable_to_medium_confidence) AS blocked_risk_residual_count,
    COUNT(*) FILTER (WHERE matching_presence_status = 'channel_absent_or_inactive') AS channel_absent_or_inactive_excluded_count,
    bool_and(export_allowed_safe = false) AS export_allowed_is_always_false,
    bool_and(reviewer_decision_safe = 'pending') AS reviewer_decision_is_always_pending
  FROM promotion
)
SELECT 'candidate_total'::text AS validation_item, candidate_total AS row_count, 'high + medium candidates before dryrun.'::text AS note FROM validation_summary
UNION ALL SELECT 'high_candidate_count', high_candidate_count, 'expected zero for current MakeShop DB-only evidence.' FROM validation_summary
UNION ALL SELECT 'medium_candidate_count', medium_candidate_count, 'medium confidence candidates.' FROM validation_summary
UNION ALL SELECT 'duplicate_makeshop_code_count', duplicate_makeshop_code_count, 'must be zero before dryrun.' FROM validation_summary
UNION ALL SELECT 'duplicate_selfpia_to_makeshop_count', duplicate_selfpia_to_makeshop_count, 'must be zero before dryrun.' FROM validation_summary
UNION ALL SELECT 'own_sku_multi_conflict_count', own_sku_multi_conflict_count, 'expected non-zero: own_sku repeat is reclassified, not direct confirmation.' FROM validation_summary
UNION ALL SELECT 'semantic_warning_count', semantic_warning_count, 'must be zero inside dryrun candidates.' FROM validation_summary
UNION ALL SELECT 'blocked_risk_residual_count', blocked_risk_residual_count, 'not an apply target.' FROM validation_summary
UNION ALL SELECT 'channel_absent_or_inactive_excluded_count', channel_absent_or_inactive_excluded_count, 'excluded from apply target.' FROM validation_summary
UNION ALL SELECT 'export_allowed_is_always_false', CASE WHEN export_allowed_is_always_false THEN 1 ELSE 0 END, '1 means export_allowed remains false.' FROM validation_summary
UNION ALL SELECT 'reviewer_decision_is_always_pending', CASE WHEN reviewer_decision_is_always_pending THEN 1 ELSE 0 END, '1 means reviewer_decision remains pending.' FROM validation_summary;
