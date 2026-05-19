/*
  MakeShop unique evidence AB-excluded local apply.

  Local-only apply for product_ops_test:
  - Applies only the 241 final planned MakeShop unique-evidence rows.
  - Excludes the full 1,247/291/255 sets, the broad AB 14 rows, duplicate evidence, duplicate code pairs, evidence-missing rows, and strict risk rows.
  - Protects existing confirmed/manual aliases.
  - Production Supabase, NAS PostgreSQL, and remote DBs must not use this file.
*/

BEGIN;

SELECT
  'execution_context'::text AS apply_item,
  1::bigint AS row_count,
  current_database() || ' / ' || current_user AS note;

SELECT
  1 / CASE
    WHEN current_database() = 'product_ops_test'
     AND current_user = 'product_ops_tester'
    THEN 1
    ELSE 0
  END AS product_ops_test_guard;
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

candidate_rows AS (
  SELECT
    CASE
      WHEN p.promotable_to_high_confidence THEN 'auto_match_high_confidence'
      WHEN p.promotable_to_medium_confidence THEN 'auto_match_medium_confidence'
      ELSE 'not_candidate'
    END AS confidence_tier,
    p.sku_id,
    p.sku_id::text AS sku_id_text,
    p.selfpia_sku_code AS selfpia_sku,
    (
      SELECT string_agg(DISTINCT osv.own_sku_code, ', ' ORDER BY osv.own_sku_code)
      FROM own_sku_value_by_sku AS osv
      WHERE osv.sku_id = p.sku_id
    ) AS own_sku,
    p.product_name,
    p.option_value AS option_name,
    p.makeshop_code_key AS makeshop_code_candidate,
    p.makeshop_code_key AS makeshop_product_candidate,
    p.makeshop_option_key AS makeshop_option_candidate,
    p.makeshop_code_candidate_exists,
    p.makeshop_code_and_option_evidence_exists,
    p.sku_count_for_makeshop_code,
    p.duplicate_own_sku_same_product_family,
    p.duplicate_own_sku_cross_product,
    p.duplicate_own_sku_blocked,
    p.duplicate_selfpia_sku_to_makeshop_code,
    p.semantic_true_risk,
    p.channel_absent_or_inactive,
    p.true_conflict_or_residual,
    CASE
      WHEN p.promotable_to_high_confidence THEN 'unique MakeShop code + same product family evidence'
      WHEN p.promotable_to_medium_confidence THEN 'own_sku repeat reclassified with MakeShop or normalization evidence'
      ELSE 'excluded'
    END AS match_reason,
    CASE
      WHEN p.duplicate_own_sku_with_unique_makeshop_code THEN 'makeshop_code_and_option_1to1'
      WHEN p.makeshop_code_candidate_exists THEN 'makeshop_code_candidate'
      WHEN p.option_normalization_absorbable THEN 'option_normalization'
      WHEN p.duplicate_own_sku_same_product_family THEN 'same_product_family_own_sku_repeat'
      WHEN p.quantity_set_true_risk OR p.pair_single_set_risk THEN 'quantity_or_set_wording'
      ELSE 'own_sku_repeat_only'
    END AS evidence_source,
    CASE
      WHEN NOT p.makeshop_code_candidate_exists THEN 'MakeShop code missing; do not apply without extra code evidence'
      WHEN p.semantic_true_risk THEN 'semantic risk remains'
      WHEN p.duplicate_selfpia_sku_to_makeshop_code THEN 'selfpia SKU splits to multiple MakeShop codes'
      WHEN p.channel_absent_or_inactive THEN 'channel absent or inactive'
      WHEN p.true_conflict_or_residual THEN 'remain blocked risk'
      ELSE 'dryrun candidate; sample before apply design'
    END AS risk_note,
    false::boolean AS export_allowed,
    'pending'::text AS reviewer_decision
  FROM promotion AS p
  WHERE p.promotable_to_high_confidence
     OR p.promotable_to_medium_confidence
),
candidate_own_sku_values AS (
  SELECT DISTINCT
    cr.sku_id,
    osv.own_sku_code
  FROM candidate_rows AS cr
  JOIN own_sku_value_by_sku AS osv
    ON osv.sku_id = cr.sku_id
  WHERE NULLIF(btrim(COALESCE(osv.own_sku_code, '')), '') IS NOT NULL
),
candidate_own_sku_makeshop_mapping AS (
  SELECT
    cov.sku_id,
    COUNT(*) AS mapping_rows_by_own_sku,
    COUNT(DISTINCT scm.sku_id) AS mapped_sku_count_by_own_sku,
    COUNT(DISTINCT scm.seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
    ) AS seller_product_code_distinct_by_own_sku,
    COUNT(DISTINCT scm.channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS channel_sku_code_distinct_by_own_sku,
    COUNT(DISTINCT concat_ws('|', scm.seller_product_code, scm.channel_sku_code)) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS code_pair_distinct_by_own_sku,
    MIN(scm.seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
    ) AS sample_seller_product_code_by_own_sku,
    MIN(scm.channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS sample_channel_sku_code_by_own_sku
  FROM candidate_own_sku_values AS cov
  JOIN product_code.sku_channel_mapping AS scm
    ON lower(scm.channel_code) = 'makeshop'
   AND scm.own_sku_code = cov.own_sku_code
  GROUP BY cov.sku_id
),
candidate_source_join_stats AS (
  SELECT
    cr.*,
    COALESCE(cmm.mapping_rows_by_own_sku, 0) AS mapping_rows_by_own_sku,
    COALESCE(cmm.mapped_sku_count_by_own_sku, 0) AS mapped_sku_count_by_own_sku,
    COALESCE(cmm.seller_product_code_distinct_by_own_sku, 0) AS seller_product_code_distinct_by_own_sku,
    COALESCE(cmm.channel_sku_code_distinct_by_own_sku, 0) AS channel_sku_code_distinct_by_own_sku,
    COALESCE(cmm.code_pair_distinct_by_own_sku, 0) AS code_pair_distinct_by_own_sku,
    cmm.sample_seller_product_code_by_own_sku,
    cmm.sample_channel_sku_code_by_own_sku
  FROM candidate_rows AS cr
  LEFT JOIN candidate_own_sku_makeshop_mapping AS cmm
    ON cmm.sku_id = cr.sku_id
),
unique_evidence_candidates AS (
  SELECT
    csj.*,
    csj.sample_seller_product_code_by_own_sku AS dryrun_makeshop_product_code,
    csj.sample_channel_sku_code_by_own_sku AS dryrun_makeshop_option_code
  FROM candidate_source_join_stats AS csj
  WHERE csj.code_pair_distinct_by_own_sku = 1
),
duplicate_evidence_excluded AS (
  SELECT *
  FROM candidate_source_join_stats
  WHERE code_pair_distinct_by_own_sku > 1
),
evidence_missing_excluded AS (
  SELECT *
  FROM candidate_source_join_stats
  WHERE NOT makeshop_code_candidate_exists
    AND code_pair_distinct_by_own_sku <> 1
),
unique_evidence_code_counts AS (
  SELECT
    dryrun_makeshop_product_code,
    dryrun_makeshop_option_code,
    COUNT(DISTINCT sku_id) AS sku_count_for_dryrun_code
  FROM unique_evidence_candidates
  GROUP BY
    dryrun_makeshop_product_code,
    dryrun_makeshop_option_code
),
unique_evidence_selfpia_counts AS (
  SELECT
    selfpia_sku,
    COUNT(DISTINCT dryrun_makeshop_product_code) AS product_count_for_selfpia_sku
  FROM unique_evidence_candidates
  GROUP BY selfpia_sku
),
dryrun_plan AS (
  SELECT
    uec.*,
    COALESCE(uecc.sku_count_for_dryrun_code, 0) AS sku_count_for_dryrun_code,
    COALESCE(uesc.product_count_for_selfpia_sku, 0) AS product_count_for_selfpia_sku,
    false::boolean AS has_existing_confirmed,
    false::boolean AS has_existing_manual,
    (
      uec.semantic_true_risk
      OR uec.risk_note LIKE '%semantic%'
      OR lower(COALESCE(uec.option_name, '')) LIKE '%크리스탈ab%'
      OR lower(COALESCE(uec.option_name, '')) LIKE '% ab %'
      OR lower(COALESCE(uec.option_name, '')) LIKE 'ab %'
      OR lower(COALESCE(uec.option_name, '')) LIKE '% ab'
      OR lower(COALESCE(uec.option_name, '')) LIKE '%화이트골드%실버%'
      OR lower(COALESCE(uec.option_name, '')) LIKE '%실버%화이트골드%'
      OR lower(COALESCE(uec.option_name, '')) LIKE '%1+1%'
      OR lower(COALESCE(uec.option_name, '')) LIKE '%수량%'
    ) AS semantic_or_risk_keyword_warning
  FROM unique_evidence_candidates AS uec
  LEFT JOIN unique_evidence_code_counts AS uecc
    ON uecc.dryrun_makeshop_product_code = uec.dryrun_makeshop_product_code
   AND uecc.dryrun_makeshop_option_code = uec.dryrun_makeshop_option_code
  LEFT JOIN unique_evidence_selfpia_counts AS uesc
    ON uesc.selfpia_sku = uec.selfpia_sku
),
clean_dryrun_plan AS (
  SELECT *
  FROM dryrun_plan
  WHERE NOT has_existing_confirmed
    AND NOT has_existing_manual
    AND sku_count_for_dryrun_code = 1
    AND product_count_for_selfpia_sku = 1
    AND NOT semantic_or_risk_keyword_warning
),
ab_keyword_excluded AS (
  SELECT *
  FROM clean_dryrun_plan
  WHERE lower(COALESCE(option_name, '')) LIKE '%ab%'
),
final_planned_plan AS (
  SELECT *
  FROM clean_dryrun_plan
  WHERE lower(COALESCE(option_name, '')) NOT LIKE '%ab%'
),
duplicate_code_pair_excluded AS (
  SELECT *
  FROM dryrun_plan
  WHERE sku_count_for_dryrun_code > 1
),
risk_keyword_excluded AS (
  SELECT *
  FROM dryrun_plan
  WHERE semantic_or_risk_keyword_warning
),
actual_existing_by_sku AS (
  SELECT
    f.sku_id,
    EXISTS (
      SELECT 1
      FROM product_code.code_alias AS ca
      WHERE ca.target_type = 'SKU'
        AND ca.target_id = f.sku_id
        AND ca.code_system IN ('makeshop_product_code', 'makeshop_option_code')
    ) AS has_existing_confirmed_alias,
    EXISTS (
      SELECT 1
      FROM product_code.code_alias AS ca
      WHERE ca.target_type = 'SKU'
        AND ca.target_id = f.sku_id
        AND (
          ca.code_system LIKE 'makeshop%'
          OR lower(COALESCE(ca.memo, '')) LIKE '%makeshop%'
          OR lower(COALESCE(ca.source_project_ref, '')) LIKE '%makeshop%'
          OR lower(COALESCE(ca.source_table, '')) LIKE '%makeshop%'
          OR lower(COALESCE(ca.raw_payload::text, '')) LIKE '%makeshop%'
        )
        AND (
          lower(COALESCE(ca.usage_type, '')) LIKE '%manual%'
          OR lower(COALESCE(ca.memo, '')) LIKE '%manual%'
          OR COALESCE(ca.memo, '') LIKE '%' || U&'\C218\B3D9' || '%'
          OR lower(COALESCE(ca.raw_payload::text, '')) LIKE '%manual%'
          OR lower(COALESCE(ca.raw_payload::text, '')) LIKE '%reviewer%'
        )
    ) AS has_existing_manual_marker
  FROM final_planned_plan AS f
),
apply_candidates AS (
  SELECT
    f.*,
    COALESCE(ae.has_existing_confirmed_alias, false) AS has_existing_confirmed_alias,
    COALESCE(ae.has_existing_manual_marker, false) AS has_existing_manual_marker,
    (
      lower(COALESCE(f.option_name, '')) LIKE '%크리스탈%'
      OR lower(COALESCE(f.option_name, '')) LIKE '%크리스탈ab%'
      OR lower(COALESCE(f.option_name, '')) LIKE '%크리ab%'
      OR lower(COALESCE(f.option_name, '')) LIKE '%ab%'
      OR lower(COALESCE(f.option_name, '')) LIKE '%화이트골드%'
      OR lower(COALESCE(f.option_name, '')) LIKE '%실버%'
      OR lower(COALESCE(f.option_name, '')) LIKE '%골드%'
      OR lower(COALESCE(f.option_name, '')) LIKE '%로즈골드%'
      OR lower(COALESCE(f.option_name, '')) LIKE '%핑크골드%'
      OR lower(COALESCE(f.option_name, '')) LIKE '%세트%'
      OR lower(COALESCE(f.option_name, '')) LIKE '%1+1%'
      OR lower(COALESCE(f.option_name, '')) LIKE '%수량%'
    ) AS strict_risk_keyword_remaining
  FROM final_planned_plan AS f
  LEFT JOIN actual_existing_by_sku AS ae
    ON ae.sku_id = f.sku_id
),
apply_target AS (
  SELECT *
  FROM apply_candidates
  WHERE NOT has_existing_confirmed_alias
    AND NOT has_existing_manual_marker
    AND sku_count_for_dryrun_code = 1
    AND product_count_for_selfpia_sku = 1
    AND NOT semantic_or_risk_keyword_warning
    AND NOT strict_risk_keyword_remaining
    AND NULLIF(btrim(COALESCE(dryrun_makeshop_product_code, '')), '') IS NOT NULL
    AND NULLIF(btrim(COALESCE(dryrun_makeshop_option_code, '')), '') IS NOT NULL
),
apply_precheck AS (
  SELECT
    (SELECT COUNT(*) FROM candidate_rows) AS source_candidate_total,
    (SELECT COUNT(*) FROM unique_evidence_candidates) AS unique_evidence_candidate_count,
    (SELECT COUNT(*) FROM duplicate_evidence_excluded) AS duplicate_evidence_excluded_count,
    (SELECT COUNT(*) FROM evidence_missing_excluded) AS evidence_missing_excluded_count,
    (SELECT COUNT(*) FROM duplicate_code_pair_excluded) AS duplicate_code_pair_excluded_count,
    (SELECT COUNT(*) FROM risk_keyword_excluded) AS risk_keyword_excluded_count,
    (SELECT COUNT(*) FROM clean_dryrun_plan) AS clean_subset_before_ab_exclusion_count,
    (SELECT COUNT(*) FROM ab_keyword_excluded) AS ab_keyword_excluded_count,
    (SELECT COUNT(*) FROM final_planned_plan) AS final_planned_count,
    (SELECT COUNT(*) FROM apply_candidates WHERE has_existing_confirmed_alias) AS skipped_existing_confirmed_count,
    (SELECT COUNT(*) FROM apply_candidates WHERE has_existing_manual_marker) AS skipped_existing_manual_count,
    (SELECT COUNT(*) FROM final_planned_plan WHERE sku_count_for_dryrun_code > 1) AS duplicate_makeshop_code_count,
    (SELECT COUNT(*) FROM final_planned_plan WHERE product_count_for_selfpia_sku > 1) AS duplicate_selfpia_to_makeshop_count,
    (SELECT COUNT(*) FROM final_planned_plan WHERE semantic_or_risk_keyword_warning) AS semantic_warning_count,
    (SELECT COUNT(*) FROM final_planned_plan WHERE lower(COALESCE(option_name, '')) LIKE '%ab%') AS ab_keyword_remaining_count,
    (SELECT COUNT(*) FROM apply_candidates WHERE strict_risk_keyword_remaining) AS strict_risk_keyword_remaining_count,
    (SELECT COUNT(*) FROM apply_target) AS insert_or_update_planned_count
),
precheck_guard AS (
  SELECT
    *,
    (
      source_candidate_total = 1247
      AND unique_evidence_candidate_count = 291
      AND duplicate_evidence_excluded_count = 18
      AND evidence_missing_excluded_count = 956
      AND duplicate_code_pair_excluded_count = 36
      AND risk_keyword_excluded_count = 8
      AND clean_subset_before_ab_exclusion_count = 255
      AND ab_keyword_excluded_count = 14
      AND final_planned_count = 241
      AND skipped_existing_confirmed_count = 0
      AND skipped_existing_manual_count = 0
      AND duplicate_makeshop_code_count = 0
      AND duplicate_selfpia_to_makeshop_count = 0
      AND semantic_warning_count = 0
      AND ab_keyword_remaining_count = 0
      AND strict_risk_keyword_remaining_count = 0
      AND insert_or_update_planned_count = 241
    ) AS guard_pass
  FROM apply_precheck
),
insert_product_alias AS (
  INSERT INTO product_code.code_alias (
    target_type,
    target_id,
    code_system,
    code_value,
    usage_type,
    is_primary,
    memo,
    raw_payload,
    source_project_ref,
    source_table
  )
  SELECT
    'SKU'::text AS target_type,
    at.sku_id AS target_id,
    'makeshop_product_code'::text AS code_system,
    at.dryrun_makeshop_product_code AS code_value,
    'confirmed'::text AS usage_type,
    false::boolean AS is_primary,
    'local auto match from MakeShop unique evidence AB-excluded dryrun v1'::text AS memo,
    jsonb_build_object(
      'source', 'makeshop_unique_evidence_ab_excluded_v1',
      'confidence_tier', 'auto_match_medium_confidence',
      'selfpia_sku', at.selfpia_sku,
      'own_sku', at.own_sku,
      'guard', 'final_241_no_existing_confirmed_or_manual_no_ab_no_semantic_warning'
    ) AS raw_payload,
    'makeshop_unique_evidence_ab_excluded_v1'::text AS source_project_ref,
    'apply_makeshop_unique_evidence_ab_excluded_v1'::text AS source_table
  FROM apply_target AS at
  WHERE (SELECT guard_pass FROM precheck_guard)
    AND NOT EXISTS (
      SELECT 1
      FROM product_code.code_alias AS ca
      WHERE ca.target_type = 'SKU'
        AND ca.target_id = at.sku_id
        AND ca.code_system = 'makeshop_product_code'
    )
  ON CONFLICT (code_system, code_value, target_type, target_id) DO NOTHING
  RETURNING target_id
),
insert_option_alias AS (
  INSERT INTO product_code.code_alias (
    target_type,
    target_id,
    code_system,
    code_value,
    usage_type,
    is_primary,
    memo,
    raw_payload,
    source_project_ref,
    source_table
  )
  SELECT
    'SKU'::text AS target_type,
    at.sku_id AS target_id,
    'makeshop_option_code'::text AS code_system,
    at.dryrun_makeshop_option_code AS code_value,
    'confirmed'::text AS usage_type,
    false::boolean AS is_primary,
    'local auto match from MakeShop unique evidence AB-excluded dryrun v1'::text AS memo,
    jsonb_build_object(
      'source', 'makeshop_unique_evidence_ab_excluded_v1',
      'confidence_tier', 'auto_match_medium_confidence',
      'selfpia_sku', at.selfpia_sku,
      'own_sku', at.own_sku,
      'guard', 'final_241_no_existing_confirmed_or_manual_no_ab_no_semantic_warning'
    ) AS raw_payload,
    'makeshop_unique_evidence_ab_excluded_v1'::text AS source_project_ref,
    'apply_makeshop_unique_evidence_ab_excluded_v1'::text AS source_table
  FROM apply_target AS at
  WHERE (SELECT guard_pass FROM precheck_guard)
    AND NOT EXISTS (
      SELECT 1
      FROM product_code.code_alias AS ca
      WHERE ca.target_type = 'SKU'
        AND ca.target_id = at.sku_id
        AND ca.code_system = 'makeshop_option_code'
    )
  ON CONFLICT (code_system, code_value, target_type, target_id) DO NOTHING
  RETURNING target_id
),
inserted_skus AS (
  SELECT target_id AS sku_id FROM insert_product_alias
  UNION
  SELECT target_id AS sku_id FROM insert_option_alias
),
apply_summary AS (
  SELECT
    pg.*,
    (SELECT COUNT(*) FROM insert_product_alias) AS inserted_product_alias_count,
    (SELECT COUNT(*) FROM insert_option_alias) AS inserted_option_alias_count,
    (SELECT COUNT(*) FROM inserted_skus) AS applied_count
  FROM precheck_guard AS pg
)
SELECT 'source_candidate_total'::text AS apply_item, source_candidate_total AS row_count, 'original MakeShop medium candidate baseline.'::text AS note FROM apply_summary
UNION ALL SELECT 'unique_evidence_candidate_count', unique_evidence_candidate_count, 'own_sku joins to exactly one existing MakeShop code pair.' FROM apply_summary
UNION ALL SELECT 'clean_subset_before_ab_exclusion_count', clean_subset_before_ab_exclusion_count, 'clean subset before broad AB exclusion.' FROM apply_summary
UNION ALL SELECT 'ab_keyword_excluded_count', ab_keyword_excluded_count, 'broad AB rows excluded.' FROM apply_summary
UNION ALL SELECT 'final_planned_count', final_planned_count, 'final planned rows after broad AB exclusion.' FROM apply_summary
UNION ALL SELECT 'insert_or_update_planned_count', insert_or_update_planned_count, 'planned local apply rows after all guards.' FROM apply_summary
UNION ALL SELECT 'applied_count', applied_count, 'distinct SKU rows that received product and/or option alias rows.' FROM apply_summary
UNION ALL SELECT 'inserted_product_alias_count', inserted_product_alias_count, 'inserted makeshop_product_code alias rows.' FROM apply_summary
UNION ALL SELECT 'inserted_option_alias_count', inserted_option_alias_count, 'inserted makeshop_option_code alias rows.' FROM apply_summary
UNION ALL SELECT 'skipped_existing_confirmed_count', skipped_existing_confirmed_count, 'must be zero; existing confirmed MakeShop aliases are protected.' FROM apply_summary
UNION ALL SELECT 'skipped_existing_manual_count', skipped_existing_manual_count, 'must be zero; existing manual/reviewer rows are protected.' FROM apply_summary
UNION ALL SELECT 'duplicate_makeshop_code_count', duplicate_makeshop_code_count, 'must be zero inside final planned rows.' FROM apply_summary
UNION ALL SELECT 'duplicate_selfpia_to_makeshop_count', duplicate_selfpia_to_makeshop_count, 'must be zero inside final planned rows.' FROM apply_summary
UNION ALL SELECT 'semantic_warning_count', semantic_warning_count, 'must be zero inside final planned rows.' FROM apply_summary
UNION ALL SELECT 'ab_keyword_remaining_count', ab_keyword_remaining_count, 'must be zero inside final planned rows.' FROM apply_summary
UNION ALL SELECT 'strict_risk_keyword_remaining_count', strict_risk_keyword_remaining_count, 'must be zero inside final planned rows.' FROM apply_summary
UNION ALL SELECT 'precheck_guard', CASE WHEN guard_pass THEN 1 ELSE 0 END::bigint, CASE WHEN guard_pass THEN 'PASS' ELSE 'FAIL' END FROM apply_summary;

WITH post_apply_guard AS (
  SELECT
    COUNT(DISTINCT ca.target_id) AS applied_count,
    COUNT(*) FILTER (WHERE ca.code_system = 'makeshop_product_code') AS inserted_product_alias_count,
    COUNT(*) FILTER (WHERE ca.code_system = 'makeshop_option_code') AS inserted_option_alias_count
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.source_project_ref = 'makeshop_unique_evidence_ab_excluded_v1'
    AND ca.source_table = 'apply_makeshop_unique_evidence_ab_excluded_v1'
)
SELECT
  1 / CASE
    WHEN applied_count = 241
     AND inserted_product_alias_count = 241
     AND inserted_option_alias_count = 241
    THEN 1
    ELSE 0
  END AS expected_applied_count_guard
FROM post_apply_guard;

COMMIT;
