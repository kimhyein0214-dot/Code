/*
  Channel presence matching-rate lite summary.

  Purpose:
  - Use only currently available local DB tables.
  - Do not depend on conceptual stage or Excel import tables.
  - Produce channel-level summary counts and rates for Smartstore and MakeShop.

  Safety:
  - SELECT-only.
  - Read-only summary.
  - No file output.
  - No import.
  - No stage relation.
  - No temporary relation.
  - export_allowed remains false.
  - reviewer_decision remains pending.

  Reporting note:
  - channel_absent_or_inactive is not a mismatch rate.
  - It is a channel inactive / historical-item separation rate.
  - Prefer channel_presence_based_auto_match_rate_pct for reporting.
*/

WITH channels AS (
  SELECT *
  FROM (
    VALUES
      ('smartstore'::text),
      ('makeshop'::text)
  ) AS c(channel)
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

sku_universe AS (
  SELECT
    c.channel,
    cs.sku_id,
    cs.product_id,
    cs.selfpia_sku_code,
    cs.selfpia_product_code,
    cs.product_name,
    cs.option_value,
    false::boolean AS export_allowed,
    'pending'::text AS reviewer_decision
  FROM channels AS c
  CROSS JOIN canonical_sku AS cs
),

channel_alias AS (
  SELECT
    ca.target_id AS sku_id,
    CASE
      WHEN ca.code_system LIKE 'smartstore%' THEN 'smartstore'
      WHEN ca.code_system LIKE 'makeshop%' THEN 'makeshop'
      ELSE NULL
    END AS channel,
    COUNT(*) AS alias_rows,
    COUNT(*) FILTER (
      WHERE ca.code_system IN (
        'smartstore_product_no',
        'smartstore_option_no',
        'makeshop_product_code',
        'makeshop_option_code'
      )
    ) AS confirmed_alias_rows,
    COUNT(*) FILTER (
      WHERE ca.code_system IN (
        'smartstore_product_no_candidate',
        'smartstore_option_no_candidate',
        'makeshop_product_code_candidate',
        'makeshop_option_code_candidate'
      )
    ) AS candidate_alias_rows,
    COUNT(DISTINCT ca.code_value) FILTER (
      WHERE ca.code_system IN (
        'smartstore_product_no',
        'smartstore_product_no_candidate',
        'makeshop_product_code',
        'makeshop_product_code_candidate'
      )
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS product_code_alias_distinct_count,
    COUNT(DISTINCT ca.code_value) FILTER (
      WHERE ca.code_system IN (
        'smartstore_option_no',
        'smartstore_option_no_candidate',
        'makeshop_option_code',
        'makeshop_option_code_candidate'
      )
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS option_code_alias_distinct_count
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND (
      ca.code_system LIKE 'smartstore%'
      OR ca.code_system LIKE 'makeshop%'
    )
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY
    ca.target_id,
    CASE
      WHEN ca.code_system LIKE 'smartstore%' THEN 'smartstore'
      WHEN ca.code_system LIKE 'makeshop%' THEN 'makeshop'
      ELSE NULL
    END
),

channel_mapping AS (
  SELECT
    lower(scm.channel_code) AS channel,
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
    ) AS mapping_own_sku_distinct_count
  FROM product_code.sku_channel_mapping AS scm
  WHERE lower(scm.channel_code) IN (
    SELECT channel FROM channels
  )
  GROUP BY
    lower(scm.channel_code),
    scm.sku_id
),

own_sku_alias AS (
  SELECT
    ca.target_id AS sku_id,
    COUNT(DISTINCT ca.code_value) AS own_sku_alias_distinct_count
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.target_id
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
    COALESCE(ca.alias_rows, 0) AS alias_rows,
    COALESCE(ca.confirmed_alias_rows, 0) AS confirmed_alias_rows,
    COALESCE(ca.candidate_alias_rows, 0) AS candidate_alias_rows,
    COALESCE(ca.product_code_alias_distinct_count, 0) AS product_code_alias_distinct_count,
    COALESCE(ca.option_code_alias_distinct_count, 0) AS option_code_alias_distinct_count,
    COALESCE(cm.mapping_rows, 0) AS mapping_rows,
    COALESCE(cm.mapping_identity_rows, 0) AS mapping_identity_rows,
    COALESCE(cm.mapping_product_code_distinct_count, 0) AS mapping_product_code_distinct_count,
    COALESCE(cm.mapping_option_code_distinct_count, 0) AS mapping_option_code_distinct_count,
    COALESCE(cm.mapping_own_sku_distinct_count, 0) AS mapping_own_sku_distinct_count,
    COALESCE(osa.own_sku_alias_distinct_count, 0) AS own_sku_alias_distinct_count,
    COALESCE(osc.max_own_sku_target_count, 0) AS max_own_sku_target_count,
    COALESCE(img.image_rows, 0) AS image_rows,
    su.export_allowed,
    su.reviewer_decision
  FROM sku_universe AS su
  LEFT JOIN channel_alias AS ca
    ON ca.channel = su.channel
   AND ca.sku_id = su.sku_id
  LEFT JOIN channel_mapping AS cm
    ON cm.channel = su.channel
   AND cm.sku_id = su.sku_id
  LEFT JOIN own_sku_alias AS osa
    ON osa.sku_id = su.sku_id
  LEFT JOIN own_sku_conflict_by_sku AS osc
    ON osc.sku_id = su.sku_id
  LEFT JOIN image_by_sku AS img
    ON img.sku_id = su.sku_id
),

classified AS (
  SELECT
    j.*,
    (
      j.alias_rows > 0
      OR j.mapping_rows > 0
    ) AS channel_present_evidence,
    (
      j.confirmed_alias_rows > 0
      OR j.mapping_identity_rows > 0
    ) AS matched_confirmed,
    (
      j.candidate_alias_rows > 0
      AND j.product_code_alias_distinct_count <= 1
      AND j.option_code_alias_distinct_count <= 1
      AND j.max_own_sku_target_count <= 1
    ) AS auto_match_high_confidence,
    (
      (
        j.candidate_alias_rows > 0
        OR j.alias_rows > 0
        OR j.mapping_rows > 0
      )
      AND NOT (
        j.confirmed_alias_rows > 0
        OR j.mapping_identity_rows > 0
      )
      AND (
        j.product_code_alias_distinct_count > 0
        OR j.mapping_product_code_distinct_count > 0
      )
      AND j.max_own_sku_target_count <= 1
    ) AS auto_match_medium_confidence,
    (
      j.product_code_alias_distinct_count > 1
      OR j.option_code_alias_distinct_count > 1
      OR j.mapping_product_code_distinct_count > 1
      OR j.mapping_option_code_distinct_count > 1
      OR j.mapping_own_sku_distinct_count > 1
      OR j.max_own_sku_target_count > 1
    ) AS blocked_risk,
    (
      j.alias_rows = 0
      AND j.mapping_rows = 0
      AND j.image_rows = 0
    ) AS channel_absent_or_inactive,
    (
      j.alias_rows = 0
      AND j.mapping_rows = 0
      AND j.image_rows > 0
    ) AS unknown_need_check
  FROM joined AS j
),

final_classification AS (
  SELECT
    c.*,
    CASE
      WHEN c.matched_confirmed THEN 'matched_confirmed'
      WHEN c.blocked_risk THEN 'blocked_risk'
      WHEN c.auto_match_high_confidence THEN 'auto_match_high_confidence'
      WHEN c.auto_match_medium_confidence THEN 'auto_match_medium_confidence'
      WHEN c.channel_absent_or_inactive THEN 'channel_absent_or_inactive'
      WHEN c.unknown_need_check THEN 'unknown_need_check'
      ELSE 'manual_review_required'
    END AS matching_presence_status,
    false::boolean AS export_allowed_safe,
    'pending'::text AS reviewer_decision_safe
  FROM classified AS c
),

channel_summary AS (
  SELECT
    channel,
    COUNT(*) AS selfpia_total_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status <> 'channel_absent_or_inactive'
    ) AS channel_present_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'channel_absent_or_inactive'
    ) AS channel_absent_or_inactive_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'matched_confirmed'
    ) AS matched_confirmed_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'auto_match_high_confidence'
    ) AS auto_match_high_confidence_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'auto_match_medium_confidence'
    ) AS auto_match_medium_confidence_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'manual_review_required'
    ) AS manual_review_required_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'blocked_risk'
    ) AS blocked_risk_rows,
    COUNT(*) FILTER (
      WHERE matching_presence_status = 'unknown_need_check'
    ) AS unknown_need_check_rows,
    0::bigint AS parse_warning_rows,
    bool_and(export_allowed_safe = false) AS export_allowed_is_always_false,
    bool_and(reviewer_decision_safe = 'pending') AS reviewer_decision_is_always_pending
  FROM final_classification
  GROUP BY channel
),

summary_rows AS (
  SELECT
    'selfpia_total_rows'::text AS summary_type,
    channel,
    selfpia_total_rows AS row_count,
    NULL::numeric AS rate_pct,
    'selfpia_total_rows'::text AS denominator_type,
    'All canonical selfpia SKU rows considered for the channel.'::text AS note
  FROM channel_summary

  UNION ALL
  SELECT
    'channel_present_rows',
    channel,
    channel_present_rows,
    NULL::numeric,
    'channel_present_rows',
    'Rows with channel evidence or unresolved presence; excludes channel_absent_or_inactive.'
  FROM channel_summary

  UNION ALL
  SELECT
    'channel_absent_or_inactive_rows',
    channel,
    channel_absent_or_inactive_rows,
    NULL::numeric,
    'selfpia_total_rows',
    'Not a mismatch count; possible channel inactive or historical item.'
  FROM channel_summary

  UNION ALL
  SELECT
    'matched_confirmed_rows',
    channel,
    matched_confirmed_rows,
    NULL::numeric,
    'channel_present_rows',
    'Confirmed alias or sku_channel_mapping identity exists.'
  FROM channel_summary

  UNION ALL
  SELECT
    'auto_match_high_confidence_rows',
    channel,
    auto_match_high_confidence_rows,
    NULL::numeric,
    'channel_present_rows',
    'Candidate alias/mapping evidence appears one-to-one; still not applied.'
  FROM channel_summary

  UNION ALL
  SELECT
    'auto_match_medium_confidence_rows',
    channel,
    auto_match_medium_confidence_rows,
    NULL::numeric,
    'channel_present_rows',
    'Channel evidence exists but needs summary/sample review.'
  FROM channel_summary

  UNION ALL
  SELECT
    'manual_review_required_rows',
    channel,
    manual_review_required_rows,
    NULL::numeric,
    'channel_present_rows',
    'Channel evidence exists but matching evidence is insufficient.'
  FROM channel_summary

  UNION ALL
  SELECT
    'blocked_risk_rows',
    channel,
    blocked_risk_rows,
    NULL::numeric,
    'channel_present_rows',
    'Duplicate or conflict risk; do not auto-match.'
  FROM channel_summary

  UNION ALL
  SELECT
    'unknown_need_check_rows',
    channel,
    unknown_need_check_rows,
    NULL::numeric,
    'channel_present_rows',
    'Presence evidence is inconclusive; needs check.'
  FROM channel_summary

  UNION ALL
  SELECT
    'parse_warning_rows',
    channel,
    parse_warning_rows,
    NULL::numeric,
    'channel_present_rows',
    'DB-only lite query has no parser input; retained as zero for schema parity.'
  FROM channel_summary

  UNION ALL
  SELECT
    'selfpia_total_based_auto_match_rate_pct',
    channel,
    NULL::bigint,
    ROUND(
      100.0 * (
        matched_confirmed_rows
        + auto_match_high_confidence_rows
        + auto_match_medium_confidence_rows
      ) / NULLIF(selfpia_total_rows, 0),
      2
    ),
    'selfpia_total_rows',
    'Reference only; can look low because selfpia includes historical/non-operated items.'
  FROM channel_summary

  UNION ALL
  SELECT
    'channel_presence_based_auto_match_rate_pct',
    channel,
    NULL::bigint,
    ROUND(
      100.0 * (
        matched_confirmed_rows
        + auto_match_high_confidence_rows
        + auto_match_medium_confidence_rows
      ) / NULLIF(channel_present_rows, 0),
      2
    ),
    'channel_present_rows',
    'Recommended representative auto-match rate.'
  FROM channel_summary

  UNION ALL
  SELECT
    'channel_presence_based_manual_review_rate_pct',
    channel,
    NULL::bigint,
    ROUND(
      100.0 * (
        manual_review_required_rows
        + unknown_need_check_rows
      ) / NULLIF(channel_present_rows, 0),
      2
    ),
    'channel_present_rows',
    'Manual review rate among channel-present or unknown rows.'
  FROM channel_summary

  UNION ALL
  SELECT
    'channel_absent_or_inactive_rate_pct',
    channel,
    NULL::bigint,
    ROUND(
      100.0 * channel_absent_or_inactive_rows / NULLIF(selfpia_total_rows, 0),
      2
    ),
    'selfpia_total_rows',
    'Channel inactive / historical-item separation rate; not mismatch rate.'
  FROM channel_summary
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
  channel,
  CASE summary_type
    WHEN 'selfpia_total_rows' THEN 1
    WHEN 'channel_present_rows' THEN 2
    WHEN 'channel_absent_or_inactive_rows' THEN 3
    WHEN 'matched_confirmed_rows' THEN 4
    WHEN 'auto_match_high_confidence_rows' THEN 5
    WHEN 'auto_match_medium_confidence_rows' THEN 6
    WHEN 'manual_review_required_rows' THEN 7
    WHEN 'blocked_risk_rows' THEN 8
    WHEN 'unknown_need_check_rows' THEN 9
    WHEN 'parse_warning_rows' THEN 10
    WHEN 'selfpia_total_based_auto_match_rate_pct' THEN 11
    WHEN 'channel_presence_based_auto_match_rate_pct' THEN 12
    WHEN 'channel_presence_based_manual_review_rate_pct' THEN 13
    WHEN 'channel_absent_or_inactive_rate_pct' THEN 14
    ELSE 99
  END;
