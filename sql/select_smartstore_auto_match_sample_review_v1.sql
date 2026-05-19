/*
  Smartstore auto-match sample review.

  Purpose:
  - Return limited sample rows for human review before dryrun.
  - Split samples by high/medium, own_sku repeat, option normalization, 1:1 product option, random, and edge buckets.
  - Do not apply, export, import, confirm, or change reviewer decisions.

  Safety:
  - SELECT-only.
  - Read-only sample rows.
  - No file output.
  - No import/export.
  - No stage relation.
  - export_allowed remains false.
  - reviewer_decision remains pending.
*/

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
    U&'\D06C\B9AC\C2A4\D0C8'::text AS crystal_ko,
    U&'\D06C\B9AC\C2A4\D0C8ab'::text AS crystal_ab_ko_lower,
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

own_sku_by_sku AS (
  SELECT
    sku_id,
    string_agg(DISTINCT own_sku_code, ', ' ORDER BY own_sku_code) AS own_sku
  FROM own_sku_value_by_sku
  GROUP BY sku_id
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
    cs.product_id,
    cs.selfpia_sku_code,
    cs.selfpia_product_code,
    cs.product_name,
    cs.option_value,
    COALESCE(os.own_sku, '') AS own_sku,
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
    false::boolean AS export_allowed_safe,
    'pending'::text AS reviewer_decision_safe
  FROM canonical_sku AS cs
  LEFT JOIN smartstore_alias AS sa
    ON sa.sku_id = cs.sku_id
  LEFT JOIN smartstore_mapping AS sm
    ON sm.sku_id = cs.sku_id
  LEFT JOIN own_sku_by_sku AS os
    ON os.sku_id = cs.sku_id
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
    ) AS option_true_risk,
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
    ) AS set_or_quantity_text,
    kt.order_made,
    kt.ping_gold,
    kt.pink_gold,
    kt.rose_gold_ko,
    kt.gold_ko,
    kt.yellow_gold_ko,
    kt.bar_ko
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
    CASE
      WHEN d.matched_confirmed THEN 'matched_confirmed'
      WHEN d.current_blocked_risk THEN 'blocked_risk'
      WHEN d.current_auto_match_high_confidence THEN 'auto_match_high_confidence'
      WHEN d.channel_absent_or_inactive THEN 'channel_absent_or_inactive'
      ELSE 'unknown_need_check'
    END AS current_status,
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
      AND d.set_or_quantity_text
      AND NOT d.option_true_risk
    ) AS set_or_quantity_repeat,
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
        OR d.option_true_risk
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
      WHEN c.current_status = 'blocked_risk'
        AND c.same_product_option_repeat
        AND c.selfpia_sku_target_count = 1
        AND NOT c.duplicate_selfpia_sku_to_product
        AND NOT c.option_true_risk
        AND NOT c.set_or_quantity_repeat
      THEN 'auto_match_high_confidence'
      WHEN c.current_status = 'blocked_risk'
        AND c.own_sku_multi_sku_conflict
        AND NOT c.true_cross_product_conflict
        AND NOT c.stale_or_channel_absent_repeat
        AND NOT c.option_true_risk
        AND (
          c.same_product_option_repeat
          OR c.set_or_quantity_repeat
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
      ELSE 'other'
    END AS confidence_tier,
    CASE
      WHEN c.option_true_risk THEN 'semantic option warning remains'
      WHEN c.duplicate_selfpia_sku_to_product THEN 'selfpia SKU has multiple productNo candidates'
      WHEN c.sku_count_for_product_option > 1 THEN 'productNo + optionNo maps to multiple SKU rows'
      WHEN c.set_or_quantity_repeat THEN 'set or quantity wording; sample before dryrun'
      WHEN c.same_product_option_repeat THEN 'own_sku repeat inside same product-option context'
      WHEN c.option_normalization_absorbable THEN 'option normalization absorbable'
      ELSE 'dryrun sample review'
    END AS risk_note,
    regexp_replace(
      lower(
        replace(
          replace(
            replace(
              replace(
                replace(
                  replace(
                    replace(COALESCE(c.option_value, ''), c.order_made, ''),
                    '6mm' || c.bar_ko,
                    '6mm'
                  ),
                  '8mm' || c.bar_ko,
                  '8mm'
                ),
                c.ping_gold,
                c.rose_gold_ko
              ),
              c.pink_gold,
              c.rose_gold_ko
            ),
            c.yellow_gold_ko,
            c.gold_ko
          ),
          'rose gold',
          c.rose_gold_ko
        )
      ),
      '[[:space:]\(\)\[\]\{\}\-_/]+',
      '',
      'g'
    ) AS normalized_option_text
  FROM classified AS c
),

review_bucket_source AS (
  SELECT
    'high_confidence_sample'::text AS sample_bucket,
    c.*
  FROM candidates AS c
  WHERE c.confidence_tier = 'auto_match_high_confidence'

  UNION ALL
  SELECT
    'medium_confidence_sample',
    c.*
  FROM candidates AS c
  WHERE c.confidence_tier = 'auto_match_medium_confidence'

  UNION ALL
  SELECT
    'own_sku_repeat_promoted_sample',
    c.*
  FROM candidates AS c
  WHERE c.confidence_tier IN ('auto_match_high_confidence', 'auto_match_medium_confidence')
    AND c.own_sku_multi_sku_conflict

  UNION ALL
  SELECT
    'same_product_family_repeat_sample',
    c.*
  FROM candidates AS c
  WHERE c.confidence_tier IN ('auto_match_high_confidence', 'auto_match_medium_confidence')
    AND c.same_product_option_repeat

  UNION ALL
  SELECT
    'option_normalization_sample',
    c.*
  FROM candidates AS c
  WHERE c.confidence_tier IN ('auto_match_high_confidence', 'auto_match_medium_confidence')
    AND c.option_normalization_absorbable

  UNION ALL
  SELECT
    'product_option_one_to_one_sample',
    c.*
  FROM candidates AS c
  WHERE c.confidence_tier IN ('auto_match_high_confidence', 'auto_match_medium_confidence')
    AND c.product_no_and_option_candidate_exists
    AND c.sku_count_for_product_option = 1

  UNION ALL
  SELECT
    'random_sample',
    c.*
  FROM candidates AS c
  WHERE c.confidence_tier IN ('auto_match_high_confidence', 'auto_match_medium_confidence')

  UNION ALL
  SELECT
    'risk_edge_sample',
    c.*
  FROM candidates AS c
  WHERE c.confidence_tier IN ('auto_match_high_confidence', 'auto_match_medium_confidence')
    AND (
      c.own_sku_multi_sku_conflict
      OR c.set_or_quantity_repeat
      OR c.option_normalization_absorbable
      OR c.sku_count_for_product_option = 1
    )
),

ranked_samples AS (
  SELECT
    rbs.*,
    COUNT(*) OVER (
      PARTITION BY sample_bucket
    ) AS bucket_candidate_count,
    ROW_NUMBER() OVER (
      PARTITION BY sample_bucket
      ORDER BY
        CASE
          WHEN sample_bucket = 'random_sample' THEN md5(sku_id::text || sample_bucket)
          ELSE lpad(COALESCE(selfpia_sku_code, ''), 32, '0') || sku_id::text
        END
    ) AS sample_rank
  FROM review_bucket_source AS rbs
)

SELECT
  sample_bucket,
  confidence_tier,
  bucket_candidate_count,
  sku_id::text AS sku_id,
  selfpia_sku_code AS selfpia_sku,
  own_sku,
  product_name,
  option_value AS option_name,
  product_no_candidate AS smartstore_product_no_candidate,
  option_no_candidate AS smartstore_option_no_candidate,
  COALESCE(option_no_candidate, option_value) AS option_text_candidate,
  normalized_option_text,
  CASE
    WHEN confidence_tier = 'auto_match_high_confidence'
      THEN 'selfpia 1:1 + productNo/option 1:1 + no semantic warning'
    WHEN confidence_tier = 'auto_match_medium_confidence'
      THEN 'own_sku repeat reclassified; sample before dryrun'
    ELSE 'sample review only'
  END AS match_reason,
  risk_note,
  CASE
    WHEN sample_bucket = 'high_confidence_sample'
      THEN 'Confirm product name, option name, and productNo/optionNo are the same target.'
    WHEN sample_bucket = 'medium_confidence_sample'
      THEN 'Confirm own_sku repeat is a normal same-product or option repeat.'
    WHEN sample_bucket = 'own_sku_repeat_promoted_sample'
      THEN 'Check that repeated own_sku does not imply a different product family.'
    WHEN sample_bucket = 'same_product_family_repeat_sample'
      THEN 'Check that repeated own_sku stays inside the same product family.'
    WHEN sample_bucket = 'option_normalization_sample'
      THEN 'Check that normalization only removes harmless wording differences.'
    WHEN sample_bucket = 'product_option_one_to_one_sample'
      THEN 'Check that productNo + option candidate is unique and stable.'
    WHEN sample_bucket = 'risk_edge_sample'
      THEN 'Check the edge reason carefully before dryrun.'
    ELSE 'Spot-check product, option, and own_sku evidence.'
  END AS reviewer_check_point
FROM ranked_samples
WHERE sample_rank <= 20
ORDER BY
  CASE sample_bucket
    WHEN 'high_confidence_sample' THEN 1
    WHEN 'medium_confidence_sample' THEN 2
    WHEN 'own_sku_repeat_promoted_sample' THEN 3
    WHEN 'same_product_family_repeat_sample' THEN 4
    WHEN 'option_normalization_sample' THEN 5
    WHEN 'product_option_one_to_one_sample' THEN 6
    WHEN 'random_sample' THEN 7
    WHEN 'risk_edge_sample' THEN 8
    ELSE 99
  END,
  sample_rank;
