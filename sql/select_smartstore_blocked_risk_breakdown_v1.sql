/*
  Smartstore blocked-risk breakdown and promotion estimate.

  Purpose:
  - Diagnose why Smartstore DB-only lite summary classifies many rows as blocked_risk.
  - Split current blocked_risk into true-risk causes and promotion candidates.
  - Estimate representative auto-match rate after high/medium promotion.

  Safety:
  - SELECT-only.
  - Read-only summary.
  - No file output.
  - No import.
  - No stage relation.
  - No temporary relation.
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

own_sku_global_conflict AS (
  SELECT
    ca.code_value AS own_sku_code,
    COUNT(DISTINCT ca.target_id) AS own_sku_target_count
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.code_value
),

own_sku_conflict_by_sku AS (
  SELECT
    ca.target_id AS sku_id,
    MAX(ogc.own_sku_target_count) AS max_own_sku_target_count
  FROM product_code.code_alias AS ca
  JOIN own_sku_global_conflict AS ogc
    ON ogc.own_sku_code = ca.code_value
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
    su.selfpia_sku_code,
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
    COALESCE(osc.max_own_sku_target_count, 0) AS max_own_sku_target_count,
    COALESCE(img.image_rows, 0) AS image_rows,
    su.export_allowed,
    su.reviewer_decision
  FROM sku_universe AS su
  LEFT JOIN smartstore_alias AS sa
    ON sa.sku_id = su.sku_id
  LEFT JOIN smartstore_mapping AS sm
    ON sm.sku_id = su.sku_id
  LEFT JOIN own_sku_conflict_by_sku AS osc
    ON osc.sku_id = su.sku_id
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

diagnosis AS (
  SELECT
    pk.*,
    COALESCE(pop.sku_count_for_product_option, 0) AS sku_count_for_product_option,
    (
      pk.confirmed_alias_rows > 0
      OR pk.mapping_identity_rows > 0
    ) AS matched_confirmed,
    (
      pk.candidate_alias_rows > 0
      AND pk.product_no_distinct_count <= 1
      AND pk.option_no_distinct_count <= 1
      AND pk.max_own_sku_target_count <= 1
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
      AND pk.max_own_sku_target_count <= 1
    ) AS current_auto_match_medium_confidence,
    (
      pk.product_no_distinct_count > 1
      OR pk.option_no_distinct_count > 1
      OR pk.mapping_product_no_distinct_count > 1
      OR pk.mapping_option_no_distinct_count > 1
      OR pk.mapping_own_sku_distinct_count > 1
      OR pk.max_own_sku_target_count > 1
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
      pk.product_no_distinct_count = 0
      AND pk.mapping_product_no_distinct_count = 0
      AND (
        pk.option_no_distinct_count > 0
        OR pk.mapping_option_no_distinct_count > 0
      )
    ) AS product_no_missing_but_option_candidate_exists,
    (
      (
        pk.product_no_distinct_count > 0
        OR pk.mapping_product_no_distinct_count > 0
      )
      AND pk.option_no_distinct_count = 0
      AND pk.mapping_option_no_distinct_count = 0
    ) AS product_no_candidate_exists_option_missing,
    (
      (
        pk.product_no_distinct_count > 0
        OR pk.mapping_product_no_distinct_count > 0
      )
      AND (
        pk.option_no_distinct_count > 0
        OR pk.mapping_option_no_distinct_count > 0
      )
    ) AS product_no_and_option_candidate_exists,
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
      pk.option_text_lower LIKE '%주문제작%'
    ) AS order_made_text_absorbable,
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
      OR pk.option_text_lower LIKE '%크리스탈ab%'
    ) AS ab_token_true_risk,
    (
      pk.option_text_lower LIKE '%화이트골드%'
      AND pk.option_text_lower LIKE '%실버%'
    ) AS white_gold_silver_true_risk,
    (
      pk.option_text_lower LIKE '%세트%'
      OR pk.option_text_lower LIKE '%한쌍%'
      OR pk.option_text_lower LIKE '%낱개%'
      OR pk.option_text_lower LIKE '%5개%'
      OR pk.option_text_lower LIKE '%10개%'
      OR pk.option_text_lower LIKE '%pcs%'
      OR pk.option_text_lower LIKE '% ea%'
    ) AS quantity_set_true_risk,
    (
      COALESCE(pop.sku_count_for_product_option, 0) > 1
    ) AS duplicate_product_option_blocked,
    (
      pk.product_no_distinct_count > 1
      OR pk.mapping_product_no_distinct_count > 1
    ) AS duplicate_selfpia_sku_to_product_blocked,
    (
      pk.mapping_own_sku_distinct_count > 1
      OR pk.max_own_sku_target_count > 1
    ) AS duplicate_own_sku_blocked
  FROM pair_key AS pk
  LEFT JOIN product_option_pair_counts AS pop
    ON pop.product_no_key = pk.product_no_key
   AND pop.option_no_key = pk.option_no_key
),

classified AS (
  SELECT
    d.*,
    (
      d.rose_gold_family_absorbable
      OR d.yellow_gold_family_absorbable
      OR d.order_made_text_absorbable
      OR d.mm_bar_absorbable
      OR d.one_type_absorbable
    ) AS option_normalization_absorbable,
    (
      d.crystal_crystal_ab_true_risk
      OR d.ab_token_true_risk
      OR d.white_gold_silver_true_risk
      OR d.quantity_set_true_risk
      OR d.duplicate_product_option_blocked
      OR d.duplicate_selfpia_sku_to_product_blocked
      OR d.duplicate_own_sku_blocked
    ) AS true_blocked_risk,
    (
      d.current_blocked_risk
      AND NOT d.matched_confirmed
      AND NOT (
        d.crystal_crystal_ab_true_risk
        OR d.ab_token_true_risk
        OR d.white_gold_silver_true_risk
        OR d.quantity_set_true_risk
        OR d.duplicate_product_option_blocked
        OR d.duplicate_selfpia_sku_to_product_blocked
        OR d.duplicate_own_sku_blocked
      )
      AND d.product_no_and_option_candidate_exists
      AND d.sku_count_for_product_option <= 1
      AND d.max_own_sku_target_count <= 1
    ) AS promotable_to_high_confidence,
    (
      d.current_blocked_risk
      AND NOT d.matched_confirmed
      AND NOT (
        d.crystal_crystal_ab_true_risk
        OR d.ab_token_true_risk
        OR d.white_gold_silver_true_risk
        OR d.quantity_set_true_risk
        OR d.duplicate_product_option_blocked
        OR d.duplicate_selfpia_sku_to_product_blocked
        OR d.duplicate_own_sku_blocked
      )
      AND NOT (
        d.product_no_and_option_candidate_exists
        AND d.sku_count_for_product_option <= 1
        AND d.max_own_sku_target_count <= 1
      )
      AND (
        d.product_no_missing_but_option_candidate_exists
        OR d.product_no_candidate_exists_option_missing
        OR d.rose_gold_family_absorbable
        OR d.yellow_gold_family_absorbable
        OR d.order_made_text_absorbable
        OR d.mm_bar_absorbable
        OR d.one_type_absorbable
      )
    ) AS promotable_to_medium_confidence,
    CASE
      WHEN d.matched_confirmed THEN 'matched_confirmed'
      WHEN d.current_blocked_risk THEN 'blocked_risk'
      WHEN d.current_auto_match_high_confidence THEN 'auto_match_high_confidence'
      WHEN d.current_auto_match_medium_confidence THEN 'auto_match_medium_confidence'
      WHEN d.channel_absent_or_inactive THEN 'channel_absent_or_inactive'
      WHEN d.unknown_need_check THEN 'unknown_need_check'
      ELSE 'manual_review_required'
    END AS matching_presence_status,
    false::boolean AS export_allowed_safe,
    'pending'::text AS reviewer_decision_safe
  FROM diagnosis AS d
),

summary AS (
  SELECT
    COUNT(*) AS smartstore_total_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status <> 'channel_absent_or_inactive'
    ) AS smartstore_channel_present_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
    ) AS current_blocked_risk_rows,
    COUNT(*) FILTER (
      WHERE duplicate_product_option_blocked
        AND matching_presence_status = 'blocked_risk'
    ) AS duplicate_product_option_blocked_rows,
    COUNT(*) FILTER (
      WHERE duplicate_selfpia_sku_to_product_blocked
        AND matching_presence_status = 'blocked_risk'
    ) AS duplicate_selfpia_sku_to_product_blocked_rows,
    COUNT(*) FILTER (
      WHERE duplicate_own_sku_blocked
        AND matching_presence_status = 'blocked_risk'
    ) AS duplicate_own_sku_blocked_rows,
    COUNT(*) FILTER (
      WHERE product_no_missing_but_option_candidate_exists
        AND matching_presence_status = 'blocked_risk'
    ) AS product_no_missing_but_option_candidate_exists_rows,
    COUNT(*) FILTER (
      WHERE product_no_candidate_exists_option_missing
        AND matching_presence_status = 'blocked_risk'
    ) AS product_no_candidate_exists_option_missing_rows,
    COUNT(*) FILTER (
      WHERE product_no_and_option_candidate_exists
        AND matching_presence_status = 'blocked_risk'
    ) AS product_no_and_option_candidate_exists_rows,
    COUNT(*) FILTER (
      WHERE option_normalization_absorbable
        AND matching_presence_status = 'blocked_risk'
    ) AS option_normalization_absorbable_rows,
    COUNT(*) FILTER (
      WHERE rose_gold_family_absorbable
        AND matching_presence_status = 'blocked_risk'
    ) AS rose_gold_family_absorbable_rows,
    COUNT(*) FILTER (
      WHERE yellow_gold_family_absorbable
        AND matching_presence_status = 'blocked_risk'
    ) AS yellow_gold_family_absorbable_rows,
    COUNT(*) FILTER (
      WHERE order_made_text_absorbable
        AND matching_presence_status = 'blocked_risk'
    ) AS order_made_text_absorbable_rows,
    COUNT(*) FILTER (
      WHERE mm_bar_absorbable
        AND matching_presence_status = 'blocked_risk'
    ) AS mm_bar_absorbable_rows,
    COUNT(*) FILTER (
      WHERE one_type_absorbable
        AND matching_presence_status = 'blocked_risk'
    ) AS one_type_absorbable_rows,
    COUNT(*) FILTER (
      WHERE crystal_crystal_ab_true_risk
        AND matching_presence_status = 'blocked_risk'
    ) AS crystal_crystal_ab_true_risk_rows,
    COUNT(*) FILTER (
      WHERE ab_token_true_risk
        AND matching_presence_status = 'blocked_risk'
    ) AS ab_token_true_risk_rows,
    COUNT(*) FILTER (
      WHERE white_gold_silver_true_risk
        AND matching_presence_status = 'blocked_risk'
    ) AS white_gold_silver_true_risk_rows,
    COUNT(*) FILTER (
      WHERE quantity_set_true_risk
        AND matching_presence_status = 'blocked_risk'
    ) AS quantity_set_true_risk_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'unknown_need_check'
    ) AS unknown_need_check_rows,
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
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
        AND NOT promotable_to_high_confidence
        AND NOT promotable_to_medium_confidence
    ) AS expected_remain_blocked_risk_rows,
    bool_and(export_allowed_safe = false) AS export_allowed_is_always_false,
    bool_and(reviewer_decision_safe = 'pending') AS reviewer_decision_is_always_pending
  FROM classified
),

summary_rows AS (
  SELECT
    'smartstore_total_rows'::text AS summary_type,
    'smartstore'::text AS channel,
    smartstore_total_rows AS row_count,
    NULL::numeric AS rate_pct,
    'smartstore_total_rows'::text AS denominator_type,
    'All canonical selfpia SKU rows evaluated for Smartstore.'::text AS note
  FROM summary

  UNION ALL SELECT 'smartstore_channel_present_rows', 'smartstore', smartstore_channel_present_rows, NULL::numeric, 'smartstore_channel_present_rows', 'Rows not separated as channel_absent_or_inactive.' FROM summary
  UNION ALL SELECT 'current_blocked_risk_rows', 'smartstore', current_blocked_risk_rows, NULL::numeric, 'smartstore_channel_present_rows', 'Current DB-only lite blocked_risk rows.' FROM summary
  UNION ALL SELECT 'duplicate_product_option_blocked_rows', 'smartstore', duplicate_product_option_blocked_rows, NULL::numeric, 'smartstore_channel_present_rows', 'Same productNo + optionNo pair appears on multiple SKU IDs.' FROM summary
  UNION ALL SELECT 'duplicate_selfpia_sku_to_product_blocked_rows', 'smartstore', duplicate_selfpia_sku_to_product_blocked_rows, NULL::numeric, 'smartstore_channel_present_rows', 'Same selfpia SKU has multiple Smartstore productNo candidates.' FROM summary
  UNION ALL SELECT 'duplicate_own_sku_blocked_rows', 'smartstore', duplicate_own_sku_blocked_rows, NULL::numeric, 'smartstore_channel_present_rows', 'own_sku maps to multiple SKU IDs or conflicting mapping own_sku values.' FROM summary
  UNION ALL SELECT 'product_no_missing_but_option_candidate_exists_rows', 'smartstore', product_no_missing_but_option_candidate_exists_rows, NULL::numeric, 'smartstore_channel_present_rows', 'Option candidate exists but productNo is missing.' FROM summary
  UNION ALL SELECT 'product_no_candidate_exists_option_missing_rows', 'smartstore', product_no_candidate_exists_option_missing_rows, NULL::numeric, 'smartstore_channel_present_rows', 'ProductNo exists but option candidate is missing.' FROM summary
  UNION ALL SELECT 'product_no_and_option_candidate_exists_rows', 'smartstore', product_no_and_option_candidate_exists_rows, NULL::numeric, 'smartstore_channel_present_rows', 'Both productNo and option candidate evidence exist.' FROM summary
  UNION ALL SELECT 'option_normalization_absorbable_rows', 'smartstore', option_normalization_absorbable_rows, NULL::numeric, 'smartstore_channel_present_rows', 'Rows with option text patterns that normalization can absorb.' FROM summary
  UNION ALL SELECT 'rose_gold_family_absorbable_rows', 'smartstore', rose_gold_family_absorbable_rows, NULL::numeric, 'smartstore_channel_present_rows', '핑골/핑크골드/로즈골드/RG family.' FROM summary
  UNION ALL SELECT 'yellow_gold_family_absorbable_rows', 'smartstore', yellow_gold_family_absorbable_rows, NULL::numeric, 'smartstore_channel_present_rows', '골드/옐로우골드/YG family.' FROM summary
  UNION ALL SELECT 'order_made_text_absorbable_rows', 'smartstore', order_made_text_absorbable_rows, NULL::numeric, 'smartstore_channel_present_rows', '주문제작 text can be removed from core option key.' FROM summary
  UNION ALL SELECT 'mm_bar_absorbable_rows', 'smartstore', mm_bar_absorbable_rows, NULL::numeric, 'smartstore_channel_present_rows', '6mm바/8mm바 style option text.' FROM summary
  UNION ALL SELECT 'one_type_absorbable_rows', 'smartstore', one_type_absorbable_rows, NULL::numeric, 'smartstore_channel_present_rows', '원타입/단일옵션 style option text.' FROM summary
  UNION ALL SELECT 'crystal_crystal_ab_true_risk_rows', 'smartstore', crystal_crystal_ab_true_risk_rows, NULL::numeric, 'smartstore_channel_present_rows', '크리스탈AB true-risk rows.' FROM summary
  UNION ALL SELECT 'ab_token_true_risk_rows', 'smartstore', ab_token_true_risk_rows, NULL::numeric, 'smartstore_channel_present_rows', 'AB token true-risk rows.' FROM summary
  UNION ALL SELECT 'white_gold_silver_true_risk_rows', 'smartstore', white_gold_silver_true_risk_rows, NULL::numeric, 'smartstore_channel_present_rows', '화이트골드/실버 true-risk rows.' FROM summary
  UNION ALL SELECT 'quantity_set_true_risk_rows', 'smartstore', quantity_set_true_risk_rows, NULL::numeric, 'smartstore_channel_present_rows', '세트/한쌍/낱개/quantity true-risk rows.' FROM summary
  UNION ALL SELECT 'unknown_need_check_rows', 'smartstore', unknown_need_check_rows, NULL::numeric, 'smartstore_channel_present_rows', 'Presence/evidence is inconclusive.' FROM summary
  UNION ALL SELECT 'promotable_to_high_confidence_rows', 'smartstore', promotable_to_high_confidence_rows, NULL::numeric, 'current_blocked_risk_rows', 'Blocked rows that can move to high confidence under relaxed true-risk filtering.' FROM summary
  UNION ALL SELECT 'promotable_to_medium_confidence_rows', 'smartstore', promotable_to_medium_confidence_rows, NULL::numeric, 'current_blocked_risk_rows', 'Blocked rows that can move to medium confidence after normalization/sample review.' FROM summary
  UNION ALL SELECT 'remain_blocked_risk_rows', 'smartstore', remain_blocked_risk_rows, NULL::numeric, 'current_blocked_risk_rows', 'Blocked rows remaining after high/medium promotion candidates.' FROM summary
  UNION ALL SELECT 'current_auto_match_rows', 'smartstore', current_auto_match_rows, NULL::numeric, 'smartstore_channel_present_rows', 'Current matched + high + medium rows.' FROM summary
  UNION ALL SELECT 'expected_auto_match_rows_after_promotion', 'smartstore', current_auto_match_rows + promotable_to_high_confidence_rows + promotable_to_medium_confidence_rows, NULL::numeric, 'smartstore_channel_present_rows', 'Expected auto-match rows after promotion; still dryrun/approval only.' FROM summary
  UNION ALL SELECT 'expected_remain_blocked_risk_rows', 'smartstore', expected_remain_blocked_risk_rows, NULL::numeric, 'smartstore_channel_present_rows', 'Expected remaining true blocked-risk rows.' FROM summary
  UNION ALL SELECT 'current_channel_presence_based_auto_match_rate_pct', 'smartstore', NULL::bigint, ROUND(100.0 * current_auto_match_rows / NULLIF(smartstore_channel_present_rows, 0), 2), 'smartstore_channel_present_rows', 'Current representative Smartstore auto-match rate.' FROM summary
  UNION ALL SELECT 'expected_channel_presence_based_auto_match_rate_pct_after_promotion', 'smartstore', NULL::bigint, ROUND(100.0 * (current_auto_match_rows + promotable_to_high_confidence_rows + promotable_to_medium_confidence_rows) / NULLIF(smartstore_channel_present_rows, 0), 2), 'smartstore_channel_present_rows', 'Expected representative auto-match rate after promotion.' FROM summary
  UNION ALL SELECT 'expected_auto_match_rate_gain_pct_point', 'smartstore', NULL::bigint, ROUND(100.0 * (promotable_to_high_confidence_rows + promotable_to_medium_confidence_rows) / NULLIF(smartstore_channel_present_rows, 0), 2), 'smartstore_channel_present_rows', 'Expected percentage-point gain after promotion.' FROM summary
  UNION ALL SELECT 'expected_remain_blocked_risk_rate_pct', 'smartstore', NULL::bigint, ROUND(100.0 * expected_remain_blocked_risk_rows / NULLIF(smartstore_channel_present_rows, 0), 2), 'smartstore_channel_present_rows', 'Expected remaining blocked-risk rate after promotion.' FROM summary
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
    WHEN 'smartstore_total_rows' THEN 1
    WHEN 'smartstore_channel_present_rows' THEN 2
    WHEN 'current_blocked_risk_rows' THEN 3
    WHEN 'duplicate_product_option_blocked_rows' THEN 4
    WHEN 'duplicate_selfpia_sku_to_product_blocked_rows' THEN 5
    WHEN 'duplicate_own_sku_blocked_rows' THEN 6
    WHEN 'product_no_missing_but_option_candidate_exists_rows' THEN 7
    WHEN 'product_no_candidate_exists_option_missing_rows' THEN 8
    WHEN 'product_no_and_option_candidate_exists_rows' THEN 9
    WHEN 'option_normalization_absorbable_rows' THEN 10
    WHEN 'rose_gold_family_absorbable_rows' THEN 11
    WHEN 'yellow_gold_family_absorbable_rows' THEN 12
    WHEN 'order_made_text_absorbable_rows' THEN 13
    WHEN 'mm_bar_absorbable_rows' THEN 14
    WHEN 'one_type_absorbable_rows' THEN 15
    WHEN 'crystal_crystal_ab_true_risk_rows' THEN 16
    WHEN 'ab_token_true_risk_rows' THEN 17
    WHEN 'white_gold_silver_true_risk_rows' THEN 18
    WHEN 'quantity_set_true_risk_rows' THEN 19
    WHEN 'unknown_need_check_rows' THEN 20
    WHEN 'promotable_to_high_confidence_rows' THEN 21
    WHEN 'promotable_to_medium_confidence_rows' THEN 22
    WHEN 'remain_blocked_risk_rows' THEN 23
    WHEN 'current_auto_match_rows' THEN 24
    WHEN 'current_channel_presence_based_auto_match_rate_pct' THEN 25
    WHEN 'expected_auto_match_rows_after_promotion' THEN 26
    WHEN 'expected_channel_presence_based_auto_match_rate_pct_after_promotion' THEN 27
    WHEN 'expected_auto_match_rate_gain_pct_point' THEN 28
    WHEN 'expected_remain_blocked_risk_rows' THEN 29
    WHEN 'expected_remain_blocked_risk_rate_pct' THEN 30
    ELSE 99
  END;
