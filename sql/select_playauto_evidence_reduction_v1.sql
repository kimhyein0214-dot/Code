/*
  PlayAuto evidence reduction diagnosis.

  Purpose:
  - Use PlayAuto as hub evidence for Smartstore, MakeShop, and Ably review rows.
  - Classify evidence only. Do not promote candidates to confirmed values.
  - Keep export_allowed false and reviewer_decision pending.

  Safety:
  - SELECT-only.
  - Local read-only diagnosis only.
  - No file output.
  - Do not use as an apply script.
*/

WITH canonical_sku AS (
  SELECT
    v.sku_id,
    v.product_id,
    v.selfpia_sku_code,
    v.selfpia_product_code,
    v.selfpia_option_no,
    v.product_name,
    v.option_value
  FROM product_code.v_sku_canonical AS v
),

own_sku_alias AS (
  SELECT
    ca.target_id AS sku_id,
    MIN(ca.code_value) AS own_sku_code_from_alias
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.target_id
),

smartstore_alias AS (
  SELECT
    ca.target_id AS sku_id,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system = 'smartstore_product_no'
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS confirmed_product_no,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system = 'smartstore_option_no'
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS confirmed_option_no,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system = 'smartstore_product_no_candidate'
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS candidate_product_no,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system = 'smartstore_option_no_candidate'
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS candidate_option_no
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system IN (
      'smartstore_product_no',
      'smartstore_option_no',
      'smartstore_product_no_candidate',
      'smartstore_option_no_candidate'
    )
  GROUP BY ca.target_id
),

channel_mapping AS (
  SELECT DISTINCT ON (lower(scm.channel_code), scm.sku_id)
    lower(scm.channel_code) AS source_channel,
    scm.sku_id,
    scm.seller_product_code AS channel_product_code,
    scm.channel_sku_code AS channel_option_code,
    scm.own_sku_code,
    scm.is_primary,
    scm.raw_payload
  FROM product_code.sku_channel_mapping AS scm
  WHERE lower(scm.channel_code) IN (
    'smartstore',
    'makeshop',
    'ably',
    'playauto'
  )
  ORDER BY
    lower(scm.channel_code),
    scm.sku_id,
    scm.is_primary DESC,
    scm.channel_sku_code,
    scm.seller_product_code
),

playauto_alias AS (
  SELECT
    ca.target_id AS sku_id,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system IN (
        'playauto_product_code',
        'playauto_product_code_candidate',
        'playauto_channel_product_code',
        'playauto_channel_product_code_candidate',
        'playauto_product_no',
        'playauto_seller_code',
        'playauto_seller_code_candidate'
      )
      AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS playauto_alias_product_code,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system IN (
        'playauto_option_code',
        'playauto_option_code_candidate',
        'playauto_channel_option_code',
        'playauto_channel_option_code_candidate',
        'playauto_option_no'
      )
      AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS playauto_alias_option_code
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system LIKE 'playauto%'
  GROUP BY ca.target_id
),

playauto_evidence_by_sku AS (
  SELECT
    cs.sku_id,
    'playauto'::text AS playauto_channel_code,
    COALESCE(cm.channel_product_code, pa.playauto_alias_product_code) AS playauto_seller_product_code,
    COALESCE(cm.channel_option_code, pa.playauto_alias_option_code) AS playauto_channel_sku_code,
    COALESCE(cm.own_sku_code, osa.own_sku_code_from_alias) AS playauto_own_sku_code
  FROM canonical_sku AS cs
  LEFT JOIN channel_mapping AS cm
    ON cm.source_channel = 'playauto'
   AND cm.sku_id = cs.sku_id
  LEFT JOIN playauto_alias AS pa
    ON pa.sku_id = cs.sku_id
  LEFT JOIN own_sku_alias AS osa
    ON osa.sku_id = cs.sku_id
  WHERE cm.sku_id IS NOT NULL
     OR pa.sku_id IS NOT NULL
),

playauto_evidence_by_own_sku AS (
  SELECT DISTINCT ON (playauto_own_sku_code)
    playauto_own_sku_code,
    playauto_channel_code,
    playauto_seller_product_code,
    playauto_channel_sku_code
  FROM playauto_evidence_by_sku
  WHERE NULLIF(btrim(playauto_own_sku_code), '') IS NOT NULL
  ORDER BY
    playauto_own_sku_code,
    playauto_seller_product_code NULLS LAST,
    playauto_channel_sku_code NULLS LAST
),

review_targets AS (
  SELECT
    'smartstore'::text AS source_channel,
    CASE
      WHEN sa.confirmed_product_no IS NULL
       AND sa.confirmed_option_no IS NULL
       AND sa.candidate_product_no IS NULL
       AND sa.candidate_option_no IS NULL THEN 'smartstore_missing'
      ELSE 'smartstore_candidate_or_unreviewed'
    END AS review_reason,
    cs.sku_id,
    cs.selfpia_sku_code,
    cs.selfpia_product_code,
    cs.selfpia_option_no,
    cs.product_name,
    cs.option_value,
    COALESCE(sm.own_sku_code, osa.own_sku_code_from_alias) AS own_sku_code,
    sa.candidate_product_no,
    sa.candidate_option_no
  FROM canonical_sku AS cs
  LEFT JOIN smartstore_alias AS sa
    ON sa.sku_id = cs.sku_id
  LEFT JOIN channel_mapping AS sm
    ON sm.source_channel = 'smartstore'
   AND sm.sku_id = cs.sku_id
  LEFT JOIN own_sku_alias AS osa
    ON osa.sku_id = cs.sku_id
  WHERE sa.confirmed_product_no IS NULL
     OR sa.confirmed_option_no IS NULL
     OR sa.candidate_product_no IS NOT NULL
     OR sa.candidate_option_no IS NOT NULL

  UNION ALL

  SELECT
    'makeshop'::text AS source_channel,
    'makeshop_missing'::text AS review_reason,
    cs.sku_id,
    cs.selfpia_sku_code,
    cs.selfpia_product_code,
    cs.selfpia_option_no,
    cs.product_name,
    cs.option_value,
    COALESCE(mm.own_sku_code, osa.own_sku_code_from_alias) AS own_sku_code,
    mm.channel_product_code AS candidate_product_no,
    mm.channel_option_code AS candidate_option_no
  FROM canonical_sku AS cs
  LEFT JOIN channel_mapping AS mm
    ON mm.source_channel = 'makeshop'
   AND mm.sku_id = cs.sku_id
  LEFT JOIN own_sku_alias AS osa
    ON osa.sku_id = cs.sku_id
  WHERE mm.channel_product_code IS NULL
     OR mm.channel_option_code IS NULL

  UNION ALL

  SELECT
    'ably'::text AS source_channel,
    'ably_missing'::text AS review_reason,
    cs.sku_id,
    cs.selfpia_sku_code,
    cs.selfpia_product_code,
    cs.selfpia_option_no,
    cs.product_name,
    cs.option_value,
    COALESCE(am.own_sku_code, osa.own_sku_code_from_alias) AS own_sku_code,
    am.channel_product_code AS candidate_product_no,
    am.channel_option_code AS candidate_option_no
  FROM canonical_sku AS cs
  LEFT JOIN channel_mapping AS am
    ON am.source_channel = 'ably'
   AND am.sku_id = cs.sku_id
  LEFT JOIN own_sku_alias AS osa
    ON osa.sku_id = cs.sku_id
  WHERE am.channel_product_code IS NULL
     OR am.channel_option_code IS NULL
),

evidence_joined AS (
  SELECT
    rt.source_channel,
    rt.review_reason,
    rt.sku_id,
    rt.selfpia_sku_code,
    rt.selfpia_product_code,
    rt.selfpia_option_no,
    rt.product_name,
    rt.option_value,
    rt.own_sku_code,
    rt.candidate_product_no,
    rt.candidate_option_no,
    COALESCE(pes.playauto_channel_code, peo.playauto_channel_code) AS playauto_channel_code,
    COALESCE(pes.playauto_seller_product_code, peo.playauto_seller_product_code) AS playauto_seller_product_code,
    COALESCE(pes.playauto_channel_sku_code, peo.playauto_channel_sku_code) AS playauto_channel_sku_code,
    COALESCE(pes.playauto_own_sku_code, rt.own_sku_code) AS playauto_own_sku_code
  FROM review_targets AS rt
  LEFT JOIN playauto_evidence_by_sku AS pes
    ON pes.sku_id = rt.sku_id
  LEFT JOIN playauto_evidence_by_own_sku AS peo
    ON peo.playauto_own_sku_code = rt.own_sku_code
   AND pes.sku_id IS NULL
),

diagnosis AS (
  SELECT
    ej.source_channel,
    ej.review_reason,
    ej.sku_id,
    ej.selfpia_sku_code,
    ej.selfpia_product_code,
    ej.selfpia_option_no,
    ej.product_name,
    ej.option_value,
    ej.own_sku_code,
    ej.candidate_product_no,
    ej.candidate_option_no,
    ej.playauto_channel_code,
    ej.playauto_seller_product_code,
    ej.playauto_channel_sku_code,
    ej.playauto_own_sku_code,
    CASE
      WHEN ej.playauto_channel_code IS NULL THEN 'no_playauto_evidence'
      WHEN ej.playauto_seller_product_code IS NULL
        OR ej.playauto_channel_sku_code IS NULL THEN 'playauto_structure_needs_mapping'
      WHEN ej.source_channel = 'smartstore'
        AND ej.candidate_product_no IS NOT NULL
        AND ej.candidate_option_no IS NOT NULL
        AND ej.candidate_product_no = ej.playauto_seller_product_code
        AND ej.candidate_option_no = ej.playauto_channel_sku_code THEN 'playauto_supported_auto_confirm_candidate'
      WHEN ej.source_channel = 'smartstore'
        AND (
          (ej.candidate_product_no IS NOT NULL AND ej.candidate_product_no <> ej.playauto_seller_product_code)
          OR (ej.candidate_option_no IS NOT NULL AND ej.candidate_option_no <> ej.playauto_channel_sku_code)
        ) THEN 'playauto_conflict_review_required'
      ELSE 'playauto_supported_review_relaxed'
    END AS evidence_status,
    CASE
      WHEN ej.playauto_channel_code IS NULL THEN 'No PlayAuto SKU or own_sku evidence found.'
      WHEN ej.playauto_seller_product_code IS NULL
        OR ej.playauto_channel_sku_code IS NULL THEN 'PlayAuto evidence exists, but product/option mapping is incomplete.'
      WHEN ej.source_channel = 'smartstore'
        AND ej.candidate_product_no IS NOT NULL
        AND ej.candidate_option_no IS NOT NULL
        AND ej.candidate_product_no = ej.playauto_seller_product_code
        AND ej.candidate_option_no = ej.playauto_channel_sku_code THEN 'Smartstore candidate pair matches PlayAuto evidence.'
      WHEN ej.source_channel = 'smartstore'
        AND (
          (ej.candidate_product_no IS NOT NULL AND ej.candidate_product_no <> ej.playauto_seller_product_code)
          OR (ej.candidate_option_no IS NOT NULL AND ej.candidate_option_no <> ej.playauto_channel_sku_code)
        ) THEN 'Smartstore candidate and PlayAuto evidence differ.'
      ELSE 'PlayAuto evidence exists for SKU or own_sku and can reduce review lookup effort.'
    END AS evidence_reason,
    false::boolean AS export_allowed,
    'pending'::text AS reviewer_decision
  FROM evidence_joined AS ej
)

SELECT
  source_channel,
  review_reason,
  sku_id,
  selfpia_sku_code,
  selfpia_product_code,
  selfpia_option_no,
  product_name,
  option_value,
  own_sku_code,
  candidate_product_no,
  candidate_option_no,
  playauto_channel_code,
  playauto_seller_product_code,
  playauto_channel_sku_code,
  playauto_own_sku_code,
  evidence_status,
  evidence_reason,
  export_allowed,
  reviewer_decision
FROM diagnosis
ORDER BY
  source_channel,
  evidence_status,
  review_reason,
  selfpia_product_code,
  selfpia_option_no,
  selfpia_sku_code;

WITH canonical_sku AS (
  SELECT
    v.sku_id,
    v.selfpia_sku_code,
    v.selfpia_product_code,
    v.selfpia_option_no,
    v.product_name,
    v.option_value
  FROM product_code.v_sku_canonical AS v
),

own_sku_alias AS (
  SELECT
    ca.target_id AS sku_id,
    MIN(ca.code_value) AS own_sku_code_from_alias
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.target_id
),

smartstore_alias AS (
  SELECT
    ca.target_id AS sku_id,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system = 'smartstore_product_no'
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS confirmed_product_no,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system = 'smartstore_option_no'
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS confirmed_option_no,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system = 'smartstore_product_no_candidate'
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS candidate_product_no,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system = 'smartstore_option_no_candidate'
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS candidate_option_no
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system IN (
      'smartstore_product_no',
      'smartstore_option_no',
      'smartstore_product_no_candidate',
      'smartstore_option_no_candidate'
    )
  GROUP BY ca.target_id
),

channel_mapping AS (
  SELECT DISTINCT ON (lower(scm.channel_code), scm.sku_id)
    lower(scm.channel_code) AS source_channel,
    scm.sku_id,
    scm.seller_product_code AS channel_product_code,
    scm.channel_sku_code AS channel_option_code,
    scm.own_sku_code,
    scm.is_primary
  FROM product_code.sku_channel_mapping AS scm
  WHERE lower(scm.channel_code) IN (
    'smartstore',
    'makeshop',
    'ably',
    'playauto'
  )
  ORDER BY
    lower(scm.channel_code),
    scm.sku_id,
    scm.is_primary DESC,
    scm.channel_sku_code,
    scm.seller_product_code
),

playauto_alias AS (
  SELECT
    ca.target_id AS sku_id,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system IN (
        'playauto_product_code',
        'playauto_product_code_candidate',
        'playauto_channel_product_code',
        'playauto_channel_product_code_candidate',
        'playauto_product_no',
        'playauto_seller_code',
        'playauto_seller_code_candidate'
      )
      AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS playauto_alias_product_code,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system IN (
        'playauto_option_code',
        'playauto_option_code_candidate',
        'playauto_channel_option_code',
        'playauto_channel_option_code_candidate',
        'playauto_option_no'
      )
      AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS playauto_alias_option_code
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system LIKE 'playauto%'
  GROUP BY ca.target_id
),

playauto_evidence_by_sku AS (
  SELECT
    cs.sku_id,
    'playauto'::text AS playauto_channel_code,
    COALESCE(cm.channel_product_code, pa.playauto_alias_product_code) AS playauto_seller_product_code,
    COALESCE(cm.channel_option_code, pa.playauto_alias_option_code) AS playauto_channel_sku_code,
    COALESCE(cm.own_sku_code, osa.own_sku_code_from_alias) AS playauto_own_sku_code
  FROM canonical_sku AS cs
  LEFT JOIN channel_mapping AS cm
    ON cm.source_channel = 'playauto'
   AND cm.sku_id = cs.sku_id
  LEFT JOIN playauto_alias AS pa
    ON pa.sku_id = cs.sku_id
  LEFT JOIN own_sku_alias AS osa
    ON osa.sku_id = cs.sku_id
  WHERE cm.sku_id IS NOT NULL
     OR pa.sku_id IS NOT NULL
),

playauto_evidence_by_own_sku AS (
  SELECT DISTINCT ON (playauto_own_sku_code)
    playauto_own_sku_code,
    playauto_channel_code,
    playauto_seller_product_code,
    playauto_channel_sku_code
  FROM playauto_evidence_by_sku
  WHERE NULLIF(btrim(playauto_own_sku_code), '') IS NOT NULL
  ORDER BY
    playauto_own_sku_code,
    playauto_seller_product_code NULLS LAST,
    playauto_channel_sku_code NULLS LAST
),

review_targets AS (
  SELECT
    'smartstore'::text AS source_channel,
    CASE
      WHEN sa.confirmed_product_no IS NULL
       AND sa.confirmed_option_no IS NULL
       AND sa.candidate_product_no IS NULL
       AND sa.candidate_option_no IS NULL THEN 'smartstore_missing'
      ELSE 'smartstore_candidate_or_unreviewed'
    END AS review_reason,
    cs.sku_id,
    cs.selfpia_sku_code,
    cs.selfpia_product_code,
    cs.selfpia_option_no,
    COALESCE(sm.own_sku_code, osa.own_sku_code_from_alias) AS own_sku_code,
    sa.candidate_product_no,
    sa.candidate_option_no
  FROM canonical_sku AS cs
  LEFT JOIN smartstore_alias AS sa
    ON sa.sku_id = cs.sku_id
  LEFT JOIN channel_mapping AS sm
    ON sm.source_channel = 'smartstore'
   AND sm.sku_id = cs.sku_id
  LEFT JOIN own_sku_alias AS osa
    ON osa.sku_id = cs.sku_id
  WHERE sa.confirmed_product_no IS NULL
     OR sa.confirmed_option_no IS NULL
     OR sa.candidate_product_no IS NOT NULL
     OR sa.candidate_option_no IS NOT NULL

  UNION ALL

  SELECT
    'makeshop'::text AS source_channel,
    'makeshop_missing'::text AS review_reason,
    cs.sku_id,
    cs.selfpia_sku_code,
    cs.selfpia_product_code,
    cs.selfpia_option_no,
    COALESCE(mm.own_sku_code, osa.own_sku_code_from_alias) AS own_sku_code,
    mm.channel_product_code AS candidate_product_no,
    mm.channel_option_code AS candidate_option_no
  FROM canonical_sku AS cs
  LEFT JOIN channel_mapping AS mm
    ON mm.source_channel = 'makeshop'
   AND mm.sku_id = cs.sku_id
  LEFT JOIN own_sku_alias AS osa
    ON osa.sku_id = cs.sku_id
  WHERE mm.channel_product_code IS NULL
     OR mm.channel_option_code IS NULL

  UNION ALL

  SELECT
    'ably'::text AS source_channel,
    'ably_missing'::text AS review_reason,
    cs.sku_id,
    cs.selfpia_sku_code,
    cs.selfpia_product_code,
    cs.selfpia_option_no,
    COALESCE(am.own_sku_code, osa.own_sku_code_from_alias) AS own_sku_code,
    am.channel_product_code AS candidate_product_no,
    am.channel_option_code AS candidate_option_no
  FROM canonical_sku AS cs
  LEFT JOIN channel_mapping AS am
    ON am.source_channel = 'ably'
   AND am.sku_id = cs.sku_id
  LEFT JOIN own_sku_alias AS osa
    ON osa.sku_id = cs.sku_id
  WHERE am.channel_product_code IS NULL
     OR am.channel_option_code IS NULL
),

evidence_joined AS (
  SELECT
    rt.source_channel,
    rt.review_reason,
    rt.sku_id,
    rt.candidate_product_no,
    rt.candidate_option_no,
    COALESCE(pes.playauto_channel_code, peo.playauto_channel_code) AS playauto_channel_code,
    COALESCE(pes.playauto_seller_product_code, peo.playauto_seller_product_code) AS playauto_seller_product_code,
    COALESCE(pes.playauto_channel_sku_code, peo.playauto_channel_sku_code) AS playauto_channel_sku_code
  FROM review_targets AS rt
  LEFT JOIN playauto_evidence_by_sku AS pes
    ON pes.sku_id = rt.sku_id
  LEFT JOIN playauto_evidence_by_own_sku AS peo
    ON peo.playauto_own_sku_code = rt.own_sku_code
   AND pes.sku_id IS NULL
),

diagnosis AS (
  SELECT
    ej.source_channel,
    ej.review_reason,
    CASE
      WHEN ej.playauto_channel_code IS NULL THEN 'no_playauto_evidence'
      WHEN ej.playauto_seller_product_code IS NULL
        OR ej.playauto_channel_sku_code IS NULL THEN 'playauto_structure_needs_mapping'
      WHEN ej.source_channel = 'smartstore'
        AND ej.candidate_product_no IS NOT NULL
        AND ej.candidate_option_no IS NOT NULL
        AND ej.candidate_product_no = ej.playauto_seller_product_code
        AND ej.candidate_option_no = ej.playauto_channel_sku_code THEN 'playauto_supported_auto_confirm_candidate'
      WHEN ej.source_channel = 'smartstore'
        AND (
          (ej.candidate_product_no IS NOT NULL AND ej.candidate_product_no <> ej.playauto_seller_product_code)
          OR (ej.candidate_option_no IS NOT NULL AND ej.candidate_option_no <> ej.playauto_channel_sku_code)
        ) THEN 'playauto_conflict_review_required'
      ELSE 'playauto_supported_review_relaxed'
    END AS evidence_status
  FROM evidence_joined AS ej
),

summary_rows AS (
  SELECT
    10 AS summary_order,
    'evidence_status_count'::text AS summary_area,
    NULL::text AS source_channel,
    evidence_status,
    COUNT(*)::bigint AS row_count
  FROM diagnosis
  GROUP BY evidence_status

  UNION ALL

  SELECT
    20 AS summary_order,
    'source_channel_evidence_status_count'::text AS summary_area,
    source_channel,
    evidence_status,
    COUNT(*)::bigint AS row_count
  FROM diagnosis
  GROUP BY source_channel, evidence_status

  UNION ALL

  SELECT
    30 AS summary_order,
    'smartstore_candidate_with_playauto_evidence_count'::text AS summary_area,
    source_channel,
    NULL::text AS evidence_status,
    COUNT(*)::bigint AS row_count
  FROM diagnosis
  WHERE source_channel = 'smartstore'
    AND review_reason = 'smartstore_candidate_or_unreviewed'
    AND evidence_status <> 'no_playauto_evidence'
  GROUP BY source_channel

  UNION ALL

  SELECT
    40 AS summary_order,
    'makeshop_missing_with_playauto_evidence_count'::text AS summary_area,
    source_channel,
    NULL::text AS evidence_status,
    COUNT(*)::bigint AS row_count
  FROM diagnosis
  WHERE source_channel = 'makeshop'
    AND review_reason = 'makeshop_missing'
    AND evidence_status <> 'no_playauto_evidence'
  GROUP BY source_channel

  UNION ALL

  SELECT
    50 AS summary_order,
    'ably_missing_with_playauto_evidence_count'::text AS summary_area,
    source_channel,
    NULL::text AS evidence_status,
    COUNT(*)::bigint AS row_count
  FROM diagnosis
  WHERE source_channel = 'ably'
    AND review_reason = 'ably_missing'
    AND evidence_status <> 'no_playauto_evidence'
  GROUP BY source_channel
)

SELECT
  summary_area,
  source_channel,
  evidence_status,
  row_count
FROM summary_rows
ORDER BY
  summary_order,
  source_channel NULLS FIRST,
  evidence_status NULLS FIRST;
