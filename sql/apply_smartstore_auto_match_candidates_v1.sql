/*
  Smartstore auto-match local apply workflow.

  This file is intentionally local-only:
  - It must run only on product_ops_test as product_ops_tester.
  - It promotes dryrun-passed Smartstore auto-match candidates to local confirmed aliases.
  - It protects existing confirmed and manual evidence.
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

WITH korean_terms AS (
  SELECT
    U&'\D551\ACE8'::text AS ping_gold,
    U&'\D551\D06C\ACE8\B4DC'::text AS pink_gold,
    U&'\B85C\C988\ACE8\B4DC'::text AS rose_gold_ko,
    U&'\ACE8\B4DC'::text AS gold_ko,
    U&'\C610\B85C\C6B0\ACE8\B4DC'::text AS yellow_gold_ko,
    U&'\C8FC\BB38\C81C\C791'::text AS order_made,
    U&'\C6D0\D0C0\C785'::text AS one_type_ko,
    U&'\B2E8\C77C\C635\C158'::text AS single_option_ko,
    U&'\D654\C774\D2B8\ACE8\B4DC'::text AS white_gold_ko,
    U&'\C2E4\BC84'::text AS silver_ko,
    U&'\C138\D2B8'::text AS set_ko,
    U&'\D55C\C30D'::text AS pair_ko,
    U&'\B0B1\AC1C'::text AS single_piece_ko,
    U&'\BC14'::text AS bar_ko
),

canonical_sku AS (
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

manual_alias AS (
  SELECT
    ca.target_id AS sku_id,
    COUNT(*) AS manual_alias_rows
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND (
      lower(COALESCE(ca.usage_type, '')) LIKE '%manual%'
      OR lower(COALESCE(ca.memo, '')) LIKE '%manual%'
      OR COALESCE(ca.memo, '') LIKE '%' || U&'\C218\B3D9' || '%'
      OR lower(COALESCE(ca.raw_payload::text, '')) LIKE '%manual%'
      OR lower(COALESCE(ca.raw_payload::text, '')) LIKE '%reviewer%'
    )
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
    COALESCE(sa.product_no_any, sm.mapping_product_no_any) AS product_no_key
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
    COALESCE(ma.manual_alias_rows, 0) AS manual_alias_rows,
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
    lower(COALESCE(cs.option_value, '')) AS option_text_lower
  FROM canonical_sku AS cs
  LEFT JOIN smartstore_alias AS sa
    ON sa.sku_id = cs.sku_id
  LEFT JOIN manual_alias AS ma
    ON ma.sku_id = cs.sku_id
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

diagnosis AS (
  SELECT
    b.*,
    COALESCE(pop.sku_count_for_product_option, 0) AS sku_count_for_product_option,
    COALESCE(ssc.selfpia_sku_target_count, 0) AS selfpia_sku_target_count,
    (
      b.confirmed_alias_rows > 0
      OR b.mapping_identity_rows > 0
    ) AS existing_confirmed_guard,
    (b.manual_alias_rows > 0) AS existing_manual_guard,
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
    ) AS product_no_and_option_candidate_exists,
    (
      b.option_text_lower LIKE '%6mm%'
      OR b.option_text_lower LIKE '%8mm%'
      OR b.option_text_lower LIKE '%' || kt.bar_ko || '%'
      OR b.option_text_lower LIKE '%' || kt.ping_gold || '%'
      OR b.option_text_lower LIKE '%' || kt.pink_gold || '%'
      OR b.option_text_lower LIKE '%' || kt.rose_gold_ko || '%'
      OR b.option_text_lower LIKE '%rose gold%'
      OR b.option_text_lower LIKE '%' || kt.yellow_gold_ko || '%'
      OR b.option_text_lower LIKE '%yellow gold%'
      OR b.option_text_lower LIKE '%' || kt.order_made || '%'
      OR b.option_text_lower LIKE '%' || kt.one_type_ko || '%'
      OR b.option_text_lower LIKE '%' || kt.single_option_ko || '%'
      OR b.option_text_lower LIKE '%one type%'
    ) AS option_normalization_absorbable,
    (
      b.option_text_lower ~ '(^|[^[:alnum:]])ab([^[:alnum:]]|$)'
      OR (
        b.option_text_lower LIKE '%' || kt.white_gold_ko || '%'
        AND b.option_text_lower LIKE '%' || kt.silver_ko || '%'
      )
    ) AS semantic_warning,
    (
      b.option_text_lower LIKE '%' || kt.set_ko || '%'
      OR b.option_text_lower LIKE '%' || kt.pair_ko || '%'
      OR b.option_text_lower LIKE '%' || kt.single_piece_ko || '%'
      OR b.option_text_lower LIKE '%5' || U&'\AC1C' || '%'
      OR b.option_text_lower LIKE '%10' || U&'\AC1C' || '%'
      OR b.option_text_lower LIKE '%pcs%'
      OR b.option_text_lower LIKE '% ea%'
      OR b.option_text_lower LIKE '%pair%'
      OR b.option_text_lower LIKE '%single%'
    ) AS quantity_set_warning
  FROM base AS b
  CROSS JOIN korean_terms AS kt
  LEFT JOIN product_option_pair_counts AS pop
    ON pop.product_no_candidate = b.product_no_candidate
   AND pop.option_no_candidate = b.option_no_candidate
  LEFT JOIN selfpia_sku_counts AS ssc
    ON ssc.selfpia_sku_code = b.selfpia_sku_code
),

classified AS (
  SELECT
    d.*,
    (
      d.own_sku_multi_sku_conflict
      AND d.product_no_and_option_candidate_exists
      AND d.sku_count_for_product_option = 1
      AND (
        d.max_own_sku_product_id_count <= 1
        OR d.max_own_sku_selfpia_product_count <= 1
        OR d.max_own_sku_smartstore_product_count <= 1
      )
    ) AS same_product_option_repeat,
    (
      d.own_sku_multi_sku_conflict
      AND d.channel_absent_or_inactive
    ) AS stale_or_channel_absent_repeat,
    (
      d.own_sku_multi_sku_conflict
      AND (
        d.duplicate_selfpia_sku_to_product
        OR (
          d.product_no_and_option_candidate_exists
          AND d.sku_count_for_product_option > 1
        )
        OR d.semantic_warning
        OR (
          d.max_own_sku_product_id_count > 1
          AND d.max_own_sku_selfpia_product_count > 1
          AND d.max_own_sku_smartstore_product_count > 1
          AND NOT (
            d.product_no_and_option_candidate_exists
            AND d.sku_count_for_product_option = 1
          )
        )
      )
    ) AS true_cross_product_conflict
  FROM diagnosis AS d
),

candidates AS (
  SELECT
    c.*,
    CASE
      WHEN c.existing_confirmed_guard THEN 'matched_confirmed'
      WHEN c.current_blocked_risk
        AND c.same_product_option_repeat
        AND c.selfpia_sku_target_count = 1
        AND NOT c.duplicate_selfpia_sku_to_product
        AND NOT c.semantic_warning
        AND NOT c.quantity_set_warning
      THEN 'auto_match_high_confidence'
      WHEN c.current_blocked_risk
        AND c.own_sku_multi_sku_conflict
        AND NOT c.true_cross_product_conflict
        AND NOT c.stale_or_channel_absent_repeat
        AND NOT c.semantic_warning
        AND (
          c.same_product_option_repeat
          OR c.quantity_set_warning
          OR (
            c.product_no_and_option_candidate_exists
            AND c.sku_count_for_product_option = 1
          )
          OR (
            c.product_no_and_option_candidate_exists
            AND c.option_normalization_absorbable
          )
        )
      THEN 'auto_match_medium_confidence'
      WHEN c.current_blocked_risk
        AND c.stale_or_channel_absent_repeat
      THEN 'channel_absent_or_inactive'
      WHEN c.current_blocked_risk THEN 'remain_blocked_risk'
      ELSE 'unknown_need_check'
    END AS dryrun_bucket
  FROM classified AS c
),

planned_candidates AS (
  SELECT
    c.*,
    (
      c.dryrun_bucket IN ('auto_match_high_confidence', 'auto_match_medium_confidence')
    ) AS is_promoted_candidate,
    (
      c.dryrun_bucket IN ('auto_match_high_confidence', 'auto_match_medium_confidence')
      AND NOT c.existing_confirmed_guard
      AND NOT c.existing_manual_guard
      AND NOT c.semantic_warning
      AND NOT c.quantity_set_warning
      AND NOT c.duplicate_selfpia_sku_to_product
      AND c.sku_count_for_product_option <= 1
      AND NOT c.channel_absent_or_inactive
    ) AS is_planned_for_later_apply
  FROM candidates AS c
),

apply_target AS (
  SELECT *
  FROM planned_candidates
  WHERE is_planned_for_later_apply
    AND NULLIF(btrim(COALESCE(product_no_candidate, '')), '') IS NOT NULL
    AND NULLIF(btrim(COALESCE(option_no_candidate, '')), '') IS NOT NULL
),

apply_precheck AS (
  SELECT
    COUNT(*) FILTER (WHERE is_promoted_candidate) AS candidate_total,
    COUNT(*) FILTER (WHERE dryrun_bucket = 'auto_match_high_confidence') AS high_candidate_count,
    COUNT(*) FILTER (WHERE dryrun_bucket = 'auto_match_medium_confidence') AS medium_candidate_count,
    COUNT(*) FILTER (
      WHERE is_planned_for_later_apply
        AND NULLIF(btrim(COALESCE(product_no_candidate, '')), '') IS NOT NULL
        AND NULLIF(btrim(COALESCE(option_no_candidate, '')), '') IS NOT NULL
    ) AS insert_or_update_planned_count,
    COUNT(*) FILTER (WHERE is_promoted_candidate AND existing_confirmed_guard) AS skipped_existing_confirmed_count,
    COUNT(*) FILTER (WHERE is_promoted_candidate AND existing_manual_guard) AS skipped_existing_manual_count,
    COUNT(*) FILTER (WHERE dryrun_bucket = 'remain_blocked_risk') AS skipped_blocked_risk_count,
    COUNT(*) FILTER (WHERE dryrun_bucket = 'channel_absent_or_inactive') AS skipped_channel_absent_or_inactive_count,
    COUNT(*) FILTER (
      WHERE is_promoted_candidate
        AND product_no_and_option_candidate_exists
        AND sku_count_for_product_option > 1
    ) AS duplicate_product_option_count,
    COUNT(*) FILTER (
      WHERE is_promoted_candidate
        AND duplicate_selfpia_sku_to_product
    ) AS duplicate_selfpia_product_count,
    COUNT(*) FILTER (
      WHERE is_promoted_candidate
        AND own_sku_multi_sku_conflict
    ) AS own_sku_multi_conflict_count,
    COUNT(*) FILTER (
      WHERE is_promoted_candidate
        AND (semantic_warning OR quantity_set_warning)
    ) AS semantic_warning_count,
    COUNT(*) FILTER (
      WHERE is_planned_for_later_apply
        AND NULLIF(btrim(COALESCE(product_no_candidate, '')), '') IS NOT NULL
        AND NULLIF(btrim(COALESCE(option_no_candidate, '')), '') IS NOT NULL
    ) AS expected_after_count
  FROM planned_candidates
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
    'smartstore_product_no'::text AS code_system,
    at.product_no_candidate AS code_value,
    'confirmed'::text AS usage_type,
    false::boolean AS is_primary,
    'local auto match from Smartstore high/medium confidence dryrun v1'::text AS memo,
    jsonb_build_object(
      'source', 'smartstore_auto_match_candidates_v1',
      'confidence_tier', at.dryrun_bucket,
      'selfpia_sku', at.selfpia_sku_code,
      'guard', 'no_existing_confirmed_or_manual_no_semantic_warning'
    ) AS raw_payload,
    'smartstore_auto_match_dryrun_v1'::text AS source_project_ref,
    'apply_smartstore_auto_match_candidates_v1'::text AS source_table
  FROM apply_target AS at
  WHERE NOT EXISTS (
    SELECT 1
    FROM product_code.code_alias AS ca
    WHERE ca.target_type = 'SKU'
      AND ca.target_id = at.sku_id
      AND ca.code_system = 'smartstore_product_no'
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
    'smartstore_option_no'::text AS code_system,
    at.option_no_candidate AS code_value,
    'confirmed'::text AS usage_type,
    false::boolean AS is_primary,
    'local auto match from Smartstore high/medium confidence dryrun v1'::text AS memo,
    jsonb_build_object(
      'source', 'smartstore_auto_match_candidates_v1',
      'confidence_tier', at.dryrun_bucket,
      'selfpia_sku', at.selfpia_sku_code,
      'guard', 'no_existing_confirmed_or_manual_no_semantic_warning'
    ) AS raw_payload,
    'smartstore_auto_match_dryrun_v1'::text AS source_project_ref,
    'apply_smartstore_auto_match_candidates_v1'::text AS source_table
  FROM apply_target AS at
  WHERE NOT EXISTS (
    SELECT 1
    FROM product_code.code_alias AS ca
    WHERE ca.target_type = 'SKU'
      AND ca.target_id = at.sku_id
      AND ca.code_system = 'smartstore_option_no'
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
    ap.*,
    (SELECT COUNT(*) FROM insert_product_alias) AS inserted_product_alias_count,
    (SELECT COUNT(*) FROM insert_option_alias) AS inserted_option_alias_count,
    (SELECT COUNT(*) FROM inserted_skus) AS applied_count
  FROM apply_precheck AS ap
)

SELECT 'candidate_total'::text AS apply_item, candidate_total AS row_count, 'high + medium candidates considered by this apply.'::text AS note FROM apply_summary
UNION ALL SELECT 'high_candidate_count', high_candidate_count, 'high confidence candidates before skip guards.' FROM apply_summary
UNION ALL SELECT 'medium_candidate_count', medium_candidate_count, 'medium confidence candidates before skip guards.' FROM apply_summary
UNION ALL SELECT 'insert_or_update_planned_count', insert_or_update_planned_count, 'planned local apply rows after confirmed/manual/risk guards.' FROM apply_summary
UNION ALL SELECT 'applied_count', applied_count, 'distinct SKU rows that received product and/or option alias rows.' FROM apply_summary
UNION ALL SELECT 'inserted_product_alias_count', inserted_product_alias_count, 'inserted smartstore_product_no alias rows.' FROM apply_summary
UNION ALL SELECT 'inserted_option_alias_count', inserted_option_alias_count, 'inserted smartstore_option_no alias rows.' FROM apply_summary
UNION ALL SELECT 'skipped_existing_confirmed_count', skipped_existing_confirmed_count, 'candidate rows skipped because confirmed Smartstore evidence already exists.' FROM apply_summary
UNION ALL SELECT 'skipped_existing_manual_count', skipped_existing_manual_count, 'candidate rows skipped because manual/reviewer evidence appears to exist.' FROM apply_summary
UNION ALL SELECT 'skipped_blocked_risk_count', skipped_blocked_risk_count, 'blocked risk rows excluded from apply.' FROM apply_summary
UNION ALL SELECT 'skipped_channel_absent_or_inactive_count', skipped_channel_absent_or_inactive_count, 'channel absent/inactive rows excluded from apply.' FROM apply_summary
UNION ALL SELECT 'duplicate_product_option_count', duplicate_product_option_count, 'must be zero inside planned rows.' FROM apply_summary
UNION ALL SELECT 'duplicate_selfpia_product_count', duplicate_selfpia_product_count, 'must be zero inside planned rows.' FROM apply_summary
UNION ALL SELECT 'own_sku_multi_conflict_count', own_sku_multi_conflict_count, 'expected non-zero; own_sku repeats are reclassified evidence, not direct confirmation.' FROM apply_summary
UNION ALL SELECT 'semantic_warning_count', semantic_warning_count, 'semantic or quantity warning rows are not applied.' FROM apply_summary
UNION ALL SELECT 'expected_after_count', expected_after_count, 'expected applied SKU count for this local apply.' FROM apply_summary;

WITH post_apply_guard AS (
  SELECT
    COUNT(DISTINCT ca.target_id) AS applied_count
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.source_project_ref = 'smartstore_auto_match_dryrun_v1'
    AND ca.source_table = 'apply_smartstore_auto_match_candidates_v1'
)
SELECT
  1 / CASE WHEN applied_count = 6684 THEN 1 ELSE 0 END AS expected_applied_count_guard
FROM post_apply_guard;

COMMIT;
