/*
  Channel presence matching-rate SELECT draft.

  Purpose:
  - Separate true channel matching work from selfpia SKUs that may be
    absent, deleted, hidden, or non-operated in a channel.
  - Report both selfpia-total matching rate and channel-presence matching rate.

  Safety:
  - SELECT-only.
  - Read-only design.
  - No file output.
  - No import.
  - No stage creation.
  - export_allowed remains false.
  - reviewer_decision remains pending.

  Stage note:
  - stage_excel_smartstore_evidence, stage_excel_cross_channel_evidence,
    and stage_playauto_smartstore_evidence are conceptual future evidence
    relations. Stage relation is conceptual / not executable until stage
    import or a lite version is created. Do not create them in this script.
*/

WITH channels AS (
  SELECT *
  FROM (
    VALUES
      ('smartstore'::text),
      ('makeshop'::text),
      ('ably'::text),
      ('playauto'::text)
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
      WHEN ca.code_system LIKE 'ably%' THEN 'ably'
      WHEN ca.code_system LIKE 'playauto%' THEN 'playauto'
      ELSE NULL
    END AS channel,
    COUNT(*) AS channel_alias_rows,
    COUNT(*) FILTER (
      WHERE ca.code_system IN (
        'smartstore_product_no',
        'smartstore_option_no',
        'makeshop_product_code',
        'makeshop_option_code',
        'ably_product_code',
        'ably_option_code',
        'playauto_product_code',
        'playauto_option_code'
      )
    ) AS confirmed_alias_rows,
    COUNT(*) FILTER (
      WHERE ca.code_system LIKE '%candidate%'
    ) AS candidate_alias_rows
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND (
      ca.code_system LIKE 'smartstore%'
      OR ca.code_system LIKE 'makeshop%'
      OR ca.code_system LIKE 'ably%'
      OR ca.code_system LIKE 'playauto%'
    )
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY
    ca.target_id,
    CASE
      WHEN ca.code_system LIKE 'smartstore%' THEN 'smartstore'
      WHEN ca.code_system LIKE 'makeshop%' THEN 'makeshop'
      WHEN ca.code_system LIKE 'ably%' THEN 'ably'
      WHEN ca.code_system LIKE 'playauto%' THEN 'playauto'
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
    ) AS mapping_identity_rows
  FROM product_code.sku_channel_mapping AS scm
  WHERE lower(scm.channel_code) IN (
    SELECT channel FROM channels
  )
  GROUP BY
    lower(scm.channel_code),
    scm.sku_id
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

/*
  Conceptual future Excel/source evidence.
  These stage relations are not created here.
*/
excel_smartstore_evidence AS (
  SELECT
    'smartstore'::text AS channel,
    s.normalized_selfpia_sku_code AS selfpia_sku_code,
    COUNT(*) AS evidence_rows,
    COUNT(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(s.smartstore_product_no_candidate, '')), '') IS NOT NULL
    ) AS product_no_evidence_rows,
    COUNT(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(s.raw_option_text, s.normalized_option_text, '')), '') IS NOT NULL
    ) AS option_text_evidence_rows,
    COUNT(*) FILTER (
      WHERE s.evidence_level IN ('auto_match_high_confidence', 'excel_parse_good_candidate')
    ) AS high_like_evidence_rows,
    COUNT(*) FILTER (
      WHERE s.evidence_level IN ('auto_match_medium_confidence', 'strong_candidate')
    ) AS medium_like_evidence_rows,
    COUNT(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(s.parse_warning, '')), '') IS NOT NULL
    ) AS parse_warning_rows
  FROM stage_excel_smartstore_evidence AS s
  GROUP BY s.normalized_selfpia_sku_code
),

excel_cross_channel_evidence AS (
  SELECT
    e.source_channel AS channel,
    e.normalized_selfpia_sku_code AS selfpia_sku_code,
    COUNT(*) AS evidence_rows,
    COUNT(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(e.channel_product_code, e.channel_option_code, '')), '') IS NOT NULL
    ) AS channel_code_evidence_rows,
    COUNT(*) FILTER (
      WHERE e.evidence_level = 'auto_match_high_confidence'
    ) AS high_like_evidence_rows,
    COUNT(*) FILTER (
      WHERE e.evidence_level = 'auto_match_medium_confidence'
    ) AS medium_like_evidence_rows,
    COUNT(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(e.parse_warning, '')), '') IS NOT NULL
    ) AS parse_warning_rows
  FROM stage_excel_cross_channel_evidence AS e
  WHERE e.source_channel IN (
    SELECT channel FROM channels
  )
  GROUP BY
    e.source_channel,
    e.normalized_selfpia_sku_code
),

playauto_smartstore_evidence AS (
  SELECT
    'smartstore'::text AS channel,
    p.normalized_selfpia_sku_code AS selfpia_sku_code,
    COUNT(*) AS evidence_rows,
    COUNT(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(p.smartstore_product_no_candidate, '')), '') IS NOT NULL
    ) AS product_no_evidence_rows,
    COUNT(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(p.raw_option_text, p.normalized_option_text, '')), '') IS NOT NULL
    ) AS option_text_evidence_rows,
    COUNT(*) FILTER (
      WHERE p.confidence_tier = 'auto_match_high_confidence'
    ) AS high_like_evidence_rows,
    COUNT(*) FILTER (
      WHERE p.confidence_tier = 'auto_match_medium_confidence'
    ) AS medium_like_evidence_rows,
    COUNT(*) FILTER (
      WHERE p.confidence_tier = 'blocked_risk'
    ) AS blocked_risk_rows,
    COUNT(*) FILTER (
      WHERE p.confidence_tier = 'parse_warning'
    ) AS parse_warning_rows
  FROM stage_playauto_smartstore_evidence AS p
  GROUP BY p.normalized_selfpia_sku_code
),

presence_join AS (
  SELECT
    su.channel,
    su.sku_id,
    su.selfpia_sku_code,
    su.product_name,
    su.option_value,
    COALESCE(ca.channel_alias_rows, 0) AS channel_alias_rows,
    COALESCE(ca.confirmed_alias_rows, 0) AS confirmed_alias_rows,
    COALESCE(ca.candidate_alias_rows, 0) AS candidate_alias_rows,
    COALESCE(cm.mapping_rows, 0) AS mapping_rows,
    COALESCE(cm.mapping_identity_rows, 0) AS mapping_identity_rows,
    COALESCE(img.image_rows, 0) AS image_rows,
    COALESCE(ese.evidence_rows, 0) AS excel_smartstore_evidence_rows,
    COALESCE(ese.product_no_evidence_rows, 0) AS excel_smartstore_product_no_rows,
    COALESCE(ese.option_text_evidence_rows, 0) AS excel_smartstore_option_text_rows,
    COALESCE(ese.high_like_evidence_rows, 0) AS excel_smartstore_high_like_rows,
    COALESCE(ese.medium_like_evidence_rows, 0) AS excel_smartstore_medium_like_rows,
    COALESCE(ese.parse_warning_rows, 0) AS excel_smartstore_parse_warning_rows,
    COALESCE(ece.evidence_rows, 0) AS cross_channel_evidence_rows,
    COALESCE(ece.channel_code_evidence_rows, 0) AS cross_channel_code_evidence_rows,
    COALESCE(ece.high_like_evidence_rows, 0) AS cross_channel_high_like_rows,
    COALESCE(ece.medium_like_evidence_rows, 0) AS cross_channel_medium_like_rows,
    COALESCE(ece.parse_warning_rows, 0) AS cross_channel_parse_warning_rows,
    COALESCE(pse.evidence_rows, 0) AS playauto_evidence_rows,
    COALESCE(pse.product_no_evidence_rows, 0) AS playauto_product_no_rows,
    COALESCE(pse.option_text_evidence_rows, 0) AS playauto_option_text_rows,
    COALESCE(pse.high_like_evidence_rows, 0) AS playauto_high_like_rows,
    COALESCE(pse.medium_like_evidence_rows, 0) AS playauto_medium_like_rows,
    COALESCE(pse.blocked_risk_rows, 0) AS playauto_blocked_risk_rows,
    COALESCE(pse.parse_warning_rows, 0) AS playauto_parse_warning_rows,
    su.export_allowed,
    su.reviewer_decision
  FROM sku_universe AS su
  LEFT JOIN channel_alias AS ca
    ON ca.channel = su.channel
   AND ca.sku_id = su.sku_id
  LEFT JOIN channel_mapping AS cm
    ON cm.channel = su.channel
   AND cm.sku_id = su.sku_id
  LEFT JOIN image_by_sku AS img
    ON img.sku_id = su.sku_id
  LEFT JOIN excel_smartstore_evidence AS ese
    ON ese.channel = su.channel
   AND ese.selfpia_sku_code = su.selfpia_sku_code
  LEFT JOIN excel_cross_channel_evidence AS ece
    ON ece.channel = su.channel
   AND ece.selfpia_sku_code = su.selfpia_sku_code
  LEFT JOIN playauto_smartstore_evidence AS pse
    ON pse.channel = su.channel
   AND pse.selfpia_sku_code = su.selfpia_sku_code
),

classified AS (
  SELECT
    pj.*,
    (
      pj.channel_alias_rows > 0
      OR pj.mapping_rows > 0
      OR pj.excel_smartstore_evidence_rows > 0
      OR pj.cross_channel_evidence_rows > 0
      OR pj.playauto_evidence_rows > 0
    ) AS channel_present_evidence,
    (
      pj.confirmed_alias_rows > 0
      OR pj.mapping_identity_rows > 0
    ) AS matched_confirmed,
    (
      pj.excel_smartstore_high_like_rows > 0
      OR pj.cross_channel_high_like_rows > 0
      OR pj.playauto_high_like_rows > 0
    ) AS auto_match_high_confidence,
    (
      pj.excel_smartstore_medium_like_rows > 0
      OR pj.cross_channel_medium_like_rows > 0
      OR pj.playauto_medium_like_rows > 0
      OR (
        pj.candidate_alias_rows > 0
        AND pj.confirmed_alias_rows = 0
        AND pj.mapping_identity_rows = 0
      )
    ) AS auto_match_medium_confidence,
    (
      pj.playauto_blocked_risk_rows > 0
    ) AS blocked_risk,
    (
      pj.excel_smartstore_parse_warning_rows > 0
      OR pj.cross_channel_parse_warning_rows > 0
      OR pj.playauto_parse_warning_rows > 0
    ) AS parse_warning,
    (
      pj.channel_alias_rows = 0
      AND pj.mapping_rows = 0
      AND pj.excel_smartstore_evidence_rows = 0
      AND pj.cross_channel_evidence_rows = 0
      AND pj.playauto_evidence_rows = 0
    ) AS channel_absent_or_inactive,
    (
      pj.channel_alias_rows = 0
      AND pj.mapping_rows = 0
      AND (
        pj.excel_smartstore_evidence_rows > 0
        OR pj.cross_channel_evidence_rows > 0
        OR pj.playauto_evidence_rows > 0
        OR pj.image_rows > 0
      )
      AND pj.confirmed_alias_rows = 0
      AND pj.mapping_identity_rows = 0
    ) AS unknown_need_check
  FROM presence_join AS pj
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
      WHEN c.parse_warning THEN 'parse_warning'
      ELSE 'manual_review_required'
    END AS matching_presence_status,
    (
      NOT c.channel_absent_or_inactive
    ) AS channel_present_for_reporting,
    false::boolean AS export_allowed_safe,
    'pending'::text AS reviewer_decision_safe
  FROM classified AS c
)

SELECT
  channel,
  COUNT(*) AS total_review_rows,
  COUNT(*) AS selfpia_total_rows,
  COUNT(*) FILTER (
    WHERE channel_present_for_reporting
  ) AS channel_present_rows,
  COUNT(*) FILTER (
    WHERE matching_presence_status = 'channel_absent_or_inactive'
  ) AS channel_absent_or_inactive_rows,
  COUNT(*) FILTER (
    WHERE matching_presence_status = 'unknown_need_check'
  ) AS unknown_need_check_rows,
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
    WHERE matching_presence_status = 'parse_warning'
  ) AS parse_warning_rows,
  ROUND(
    100.0 * COUNT(*) FILTER (
      WHERE matching_presence_status IN (
        'matched_confirmed',
        'auto_match_high_confidence',
        'auto_match_medium_confidence'
      )
    ) / NULLIF(COUNT(*), 0),
    2
  ) AS selfpia_total_based_auto_match_rate_pct,
  ROUND(
    100.0 * COUNT(*) FILTER (
      WHERE matching_presence_status IN (
        'matched_confirmed',
        'auto_match_high_confidence',
        'auto_match_medium_confidence'
      )
    ) / NULLIF(
      COUNT(*) FILTER (
        WHERE channel_present_for_reporting
      ),
      0
    ),
    2
  ) AS channel_presence_based_auto_match_rate_pct,
  ROUND(
    100.0 * COUNT(*) FILTER (
      WHERE matching_presence_status IN (
        'manual_review_required',
        'unknown_need_check'
      )
    ) / NULLIF(
      COUNT(*) FILTER (
        WHERE channel_present_for_reporting
      ),
      0
    ),
    2
  ) AS channel_presence_based_manual_review_rate_pct,
  ROUND(
    100.0 * COUNT(*) FILTER (
      WHERE matching_presence_status = 'channel_absent_or_inactive'
    ) / NULLIF(COUNT(*), 0),
    2
  ) AS channel_absent_or_inactive_rate_pct,
  bool_and(export_allowed_safe = false) AS export_allowed_is_always_false,
  bool_and(reviewer_decision_safe = 'pending') AS reviewer_decision_is_always_pending
FROM final_classification
GROUP BY channel
ORDER BY channel;
