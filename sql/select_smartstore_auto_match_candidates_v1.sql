/*
  Smartstore auto-match candidate dryrun preparation.

  Purpose:
  - Extract summary and limited samples for high/medium confidence candidates.
  - Include channel_absent_or_inactive and remain_blocked_risk buckets for exclusion.
  - Prepare validation/dryrun review only; never confirm or export candidates here.

  Safety:
  - SELECT-only.
  - Read-only summary and limited sample rows.
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
    COUNT(DISTINCT osv.own_sku_code) AS own_sku_code_count,
    MAX(oss.own_sku_sku_count) AS max_own_sku_sku_count,
    MAX(oss.own_sku_product_id_count) AS max_own_sku_product_id_count,
    MAX(oss.own_sku_selfpia_product_count) AS max_own_sku_selfpia_product_count,
    MAX(oss.own_sku_smartstore_product_count) AS max_own_sku_smartstore_product_count
  FROM own_sku_value_by_sku AS osv
  JOIN own_sku_scope_stats AS oss
    ON oss.own_sku_code = osv.own_sku_code
  GROUP BY osv.sku_id
),

own_sku_alias_conflict_by_sku AS (
  SELECT
    osv.sku_id,
    MAX(oss.own_sku_sku_count) AS max_own_sku_target_count
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
    'smartstore'::text AS channel,
    cs.sku_id,
    cs.product_id,
    cs.selfpia_sku_code,
    cs.selfpia_product_code,
    cs.product_name,
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
    COALESCE(osc.max_own_sku_target_count, 0) AS max_own_sku_target_count,
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
  LEFT JOIN own_sku_alias_conflict_by_sku AS osc
    ON osc.sku_id = cs.sku_id
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
      (
        b.candidate_alias_rows > 0
        OR b.alias_rows > 0
        OR b.mapping_rows > 0
      )
      AND NOT (
        b.confirmed_alias_rows > 0
        OR b.mapping_identity_rows > 0
      )
      AND (
        b.product_no_distinct_count > 0
        OR b.mapping_product_no_distinct_count > 0
      )
      AND b.max_own_sku_target_count <= 1
    ) AS current_auto_match_medium_confidence,
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
    ) AS duplicate_selfpia_sku_to_product_blocked,
    (
      b.mapping_own_sku_distinct_count > 1
      OR b.max_own_sku_target_count > 1
    ) AS duplicate_own_sku_blocked,
    (
      NULLIF(btrim(COALESCE(b.product_no_candidate, '')), '') IS NOT NULL
      AND NULLIF(btrim(COALESCE(b.option_no_candidate, '')), '') IS NOT NULL
    ) AS product_no_and_option_candidate_exists,
    (
      b.option_text_lower LIKE '%mm바%'
      OR b.option_text_lower LIKE '%6mm%'
      OR b.option_text_lower LIKE '%8mm%'
      OR b.option_text_lower LIKE '%핑골%'
      OR b.option_text_lower LIKE '%핑크골드%'
      OR b.option_text_lower LIKE '%로즈골드%'
      OR b.option_text_lower LIKE '%rose gold%'
      OR b.option_text_lower LIKE '%주문제작%'
      OR b.option_text_lower LIKE '%원타입%'
      OR b.option_text_lower LIKE '%단일옵션%'
      OR b.option_text_lower LIKE '%one type%'
    ) AS option_normalization_absorbable,
    (
      b.option_text_lower LIKE '%크리스탈ab%'
      OR b.option_text_lower LIKE '% ab %'
      OR b.option_text_lower LIKE 'ab %'
      OR b.option_text_lower LIKE '% ab'
      OR b.option_text_lower LIKE '%/ab%'
      OR b.option_text_lower LIKE '%-ab%'
      OR b.option_text_lower LIKE '%(ab%'
      OR b.option_text_lower LIKE '%ab)%'
      OR (
        b.option_text_lower LIKE '%화이트골드%'
        AND b.option_text_lower LIKE '%실버%'
      )
    ) AS option_true_risk,
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
    ) AS set_or_quantity_text
  FROM base AS b
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
      WHEN d.current_auto_match_medium_confidence THEN 'auto_match_medium_confidence'
      WHEN d.channel_absent_or_inactive THEN 'channel_absent_or_inactive'
      ELSE 'unknown_need_check'
    END AS current_status,
    (
      d.duplicate_own_sku_blocked
      AND d.product_no_and_option_candidate_exists
      AND d.sku_count_for_product_option = 1
      AND (
        d.max_own_sku_product_id_count <= 1
        OR d.max_own_sku_selfpia_product_count <= 1
        OR d.max_own_sku_smartstore_product_count <= 1
      )
    ) AS same_product_option_repeat,
    (
      d.duplicate_own_sku_blocked
      AND d.set_or_quantity_text
      AND NOT d.option_true_risk
    ) AS set_or_quantity_repeat,
    (
      d.duplicate_own_sku_blocked
      AND d.channel_absent_or_inactive
    ) AS stale_or_channel_absent_repeat,
    (
      d.duplicate_own_sku_blocked
      AND (
        d.duplicate_selfpia_sku_to_product_blocked
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
        AND NOT c.duplicate_selfpia_sku_to_product_blocked
        AND NOT c.option_true_risk
        AND NOT c.set_or_quantity_repeat
      THEN 'auto_match_high_confidence'
      WHEN c.current_status = 'blocked_risk'
        AND c.duplicate_own_sku_blocked
        AND NOT c.true_cross_product_conflict
        AND NOT c.stale_or_channel_absent_repeat
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
      WHEN c.current_status = 'blocked_risk'
        AND c.stale_or_channel_absent_repeat
      THEN 'channel_absent_or_inactive'
      WHEN c.current_status = 'blocked_risk'
      THEN 'remain_blocked_risk'
      ELSE c.current_status
    END AS dryrun_bucket,
    CASE
      WHEN c.same_product_option_repeat THEN 'same_product_option_repeat'
      WHEN c.set_or_quantity_repeat THEN 'set_or_quantity_repeat'
      WHEN c.stale_or_channel_absent_repeat THEN 'stale_or_channel_absent_repeat'
      WHEN c.true_cross_product_conflict THEN 'true_cross_product_conflict'
      WHEN c.current_status = 'matched_confirmed' THEN 'existing_confirmed_evidence'
      ELSE 'db_only_lite_evidence'
    END AS candidate_source,
    CASE
      WHEN c.option_true_risk THEN 'blocked: semantic option risk remains'
      WHEN c.duplicate_selfpia_sku_to_product_blocked THEN 'blocked: selfpia SKU splits to multiple productNo values'
      WHEN c.sku_count_for_product_option > 1 THEN 'blocked: productNo + optionNo maps to multiple SKU rows'
      WHEN c.stale_or_channel_absent_repeat THEN 'excluded: channel absent or inactive candidate'
      WHEN c.set_or_quantity_repeat THEN 'medium/set warning: set or quantity wording'
      WHEN c.same_product_option_repeat THEN 'candidate: repeated own_sku inside same product-option context'
      ELSE 'candidate: dryrun validation required'
    END AS risk_note,
    false::boolean AS export_allowed_safe,
    'pending'::text AS reviewer_decision_safe
  FROM classified AS c
),

summary_rows AS (
  SELECT
    'summary'::text AS output_section,
    dryrun_bucket AS confidence_tier,
    candidate_source,
    COUNT(*) AS candidate_count,
    NULL::text AS sample_sku_id,
    NULL::text AS sample_selfpia_sku_code,
    NULL::text AS sample_product_no_candidate,
    NULL::text AS sample_option_no_candidate,
    CASE
      WHEN dryrun_bucket = 'auto_match_high_confidence'
        AND candidate_source = 'db_only_lite_evidence'
      THEN 'current high confidence candidates from lite summary'
      WHEN dryrun_bucket = 'auto_match_high_confidence'
      THEN 'new high confidence candidates for dryrun'
      WHEN dryrun_bucket = 'auto_match_medium_confidence'
      THEN 'medium confidence candidates for dryrun/sample review'
      WHEN dryrun_bucket = 'channel_absent_or_inactive'
      THEN 'excluded from apply target as channel absent or inactive'
      WHEN dryrun_bucket = 'remain_blocked_risk'
      THEN 'not an apply target; manual review or hold'
      ELSE 'dryrun validation required'
    END AS risk_note,
    false::boolean AS export_allowed,
    'pending'::text AS reviewer_decision
  FROM candidates
  WHERE dryrun_bucket IN (
    'auto_match_high_confidence',
    'auto_match_medium_confidence',
    'channel_absent_or_inactive',
    'remain_blocked_risk'
  )
  GROUP BY
    dryrun_bucket,
    candidate_source
),

sample_rows AS (
  SELECT
    'sample'::text AS output_section,
    dryrun_bucket AS confidence_tier,
    candidate_source,
    NULL::bigint AS candidate_count,
    sku_id::text AS sample_sku_id,
    selfpia_sku_code AS sample_selfpia_sku_code,
    product_no_candidate AS sample_product_no_candidate,
    option_no_candidate AS sample_option_no_candidate,
    risk_note,
    false::boolean AS export_allowed,
    'pending'::text AS reviewer_decision
  FROM (
    SELECT
      c.*,
      ROW_NUMBER() OVER (
        PARTITION BY dryrun_bucket, candidate_source
        ORDER BY sku_id
      ) AS sample_rank
    FROM candidates AS c
    WHERE dryrun_bucket IN (
      'auto_match_high_confidence',
      'auto_match_medium_confidence',
      'channel_absent_or_inactive',
      'remain_blocked_risk'
    )
  ) AS ranked
  WHERE sample_rank <= 5
)

SELECT
  output_section,
  confidence_tier,
  candidate_source,
  candidate_count,
  sample_sku_id,
  sample_selfpia_sku_code,
  sample_product_no_candidate,
  sample_option_no_candidate,
  risk_note,
  export_allowed,
  reviewer_decision
FROM summary_rows

UNION ALL

SELECT
  output_section,
  confidence_tier,
  candidate_source,
  candidate_count,
  sample_sku_id,
  sample_selfpia_sku_code,
  sample_product_no_candidate,
  sample_option_no_candidate,
  risk_note,
  export_allowed,
  reviewer_decision
FROM sample_rows
ORDER BY
  output_section,
  confidence_tier,
  candidate_source,
  sample_sku_id NULLS FIRST;
