/*
  Manual review target SELECT draft only.

  Purpose:
  - Review candidate and missing mapping rows for Smartstore, MakeShop, Ably, and PlayAuto.
  - This query is not a CSV export command and must not be treated as upload-ready output.
  - All candidate and unreviewed rows are blocked with export_allowed = false.

  Safety:
  - SELECT-only.
  - No schema changes.
  - No temp tables.
  - No data writes.
  - No file output.

  Precheck basis:
  - Use only product_code.v_sku_canonical, product_code.sku_master,
    product_code.product_master, product_code.code_alias,
    product_code.product_image, product_code.sku_channel_mapping.
  - Do not use product_code.channel_product, channel_product_mapping,
    channel_option_mapping, channel_sku, or channel_sku_review_draft.

  Static review note:
  - MakeShop traceability is read from raw_payload text keys where safe.
  - candidate_rank and candidate_score stay NULL placeholders until reviewed
    payload keys and formats are confirmed.
*/

WITH review_channels AS (
  SELECT *
  FROM (
    VALUES
      ('smartstore'::text),
      ('makeshop'::text),
      ('ably'::text),
      ('playauto'::text)
  ) AS c(source_channel)
),

canonical_sku AS (
  SELECT
    v.sku_id,
    v.product_id,
    v.selfpia_sku_code,
    v.selfpia_product_code,
    v.selfpia_option_no,
    v.product_name,
    v.option_value AS option_name,
    v.option_value
  FROM product_code.v_sku_canonical AS v
),

image_by_sku AS (
  SELECT
    pi.sku_id,
    COUNT(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(pi.image_url, '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(pi.thumbnail_url, '')), '') IS NOT NULL
    ) AS image_count,
    MIN(COALESCE(NULLIF(btrim(pi.thumbnail_url), ''), NULLIF(btrim(pi.image_url), ''))) AS representative_image_url
  FROM product_code.product_image AS pi
  WHERE pi.sku_id IS NOT NULL
  GROUP BY pi.sku_id
),

image_by_product AS (
  SELECT
    pi.product_id,
    COUNT(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(pi.image_url, '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(pi.thumbnail_url, '')), '') IS NOT NULL
    ) AS image_count,
    MIN(COALESCE(NULLIF(btrim(pi.thumbnail_url), ''), NULLIF(btrim(pi.image_url), ''))) AS representative_image_url
  FROM product_code.product_image AS pi
  WHERE pi.product_id IS NOT NULL
  GROUP BY pi.product_id
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

smartstore_sku_alias AS (
  SELECT
    ca.target_id AS sku_id,
    MIN(ca.code_value) FILTER (WHERE ca.code_system = 'smartstore_product_no') AS confirmed_product_no_from_sku,
    MIN(ca.code_value) FILTER (WHERE ca.code_system = 'smartstore_product_no_candidate') AS candidate_product_no_from_sku,
    MIN(ca.code_value) FILTER (WHERE ca.code_system = 'smartstore_option_no') AS confirmed_option_no,
    MIN(ca.code_value) FILTER (WHERE ca.code_system = 'smartstore_option_no_candidate') AS candidate_option_no
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system IN (
      'smartstore_product_no',
      'smartstore_product_no_candidate',
      'smartstore_option_no',
      'smartstore_option_no_candidate'
    )
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.target_id
),

smartstore_product_alias AS (
  SELECT
    ca.target_id AS product_id,
    MIN(ca.code_value) FILTER (WHERE ca.code_system = 'smartstore_product_no') AS confirmed_product_no_from_product,
    MIN(ca.code_value) FILTER (WHERE ca.code_system = 'smartstore_product_no_candidate') AS candidate_product_no_from_product
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'PRODUCT'
    AND ca.code_system IN (
      'smartstore_product_no',
      'smartstore_product_no_candidate'
    )
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
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
    SELECT source_channel FROM review_channels
  )
  ORDER BY
    lower(scm.channel_code),
    scm.sku_id,
    scm.is_primary DESC,
    scm.channel_sku_code,
    scm.seller_product_code
),

review_base AS (
  SELECT
    rc.source_channel,
    cs.sku_id,
    cs.product_id,
    cs.selfpia_sku_code,
    cs.selfpia_product_code,
    cs.selfpia_option_no,
    cs.product_name,
    cs.option_name,
    cs.option_value,
    COALESCE(cm.own_sku_code, osa.own_sku_code_from_alias) AS own_sku_code,
    cm.channel_product_code,
    cm.channel_option_code,
    cm.raw_payload,
    COALESCE(spa.confirmed_product_no_from_product, ssa.confirmed_product_no_from_sku) AS smartstore_confirmed_product_no,
    COALESCE(ssa.confirmed_option_no, NULL::text) AS smartstore_confirmed_option_no,
    COALESCE(spa.candidate_product_no_from_product, ssa.candidate_product_no_from_sku) AS smartstore_candidate_product_no,
    COALESCE(ssa.candidate_option_no, NULL::text) AS smartstore_candidate_option_no,
    COALESCE(ibs.image_count, ibp.image_count, 0) AS image_count,
    COALESCE(ibs.representative_image_url, ibp.representative_image_url) AS representative_image_url
  FROM review_channels AS rc
  JOIN canonical_sku AS cs
    ON true
  LEFT JOIN channel_mapping AS cm
    ON cm.source_channel = rc.source_channel
   AND cm.sku_id = cs.sku_id
  LEFT JOIN own_sku_alias AS osa
    ON osa.sku_id = cs.sku_id
  LEFT JOIN smartstore_sku_alias AS ssa
    ON ssa.sku_id = cs.sku_id
  LEFT JOIN smartstore_product_alias AS spa
    ON spa.product_id = cs.product_id
  LEFT JOIN image_by_sku AS ibs
    ON ibs.sku_id = cs.sku_id
  LEFT JOIN image_by_product AS ibp
    ON ibp.product_id = cs.product_id
),

smartstore_review AS (
  SELECT
    'smartstore'::text AS source_channel,
    CASE
      WHEN rb.image_count = 0 THEN 'image_missing'
      WHEN COALESCE(rb.own_sku_code, '') = '' THEN 'own_sku_missing'
      WHEN rb.smartstore_confirmed_product_no IS NULL
       AND rb.smartstore_confirmed_option_no IS NULL
       AND rb.smartstore_candidate_product_no IS NULL
       AND rb.smartstore_candidate_option_no IS NULL THEN 'smartstore_missing'
      ELSE 'smartstore_candidate_or_unreviewed'
    END AS review_reason,
    rb.sku_id,
    rb.product_id,
    rb.selfpia_sku_code,
    rb.selfpia_product_code,
    rb.selfpia_option_no,
    rb.product_name,
    rb.option_name,
    rb.option_value,
    rb.own_sku_code,
    rb.smartstore_confirmed_product_no AS confirmed_product_no,
    rb.smartstore_confirmed_option_no AS confirmed_option_no,
    rb.smartstore_candidate_product_no AS candidate_product_no,
    rb.smartstore_candidate_option_no AS candidate_option_no,
    NULL::text AS source_row_ref,
    NULL::integer AS candidate_rank,
    NULL::numeric AS candidate_score,
    NULL::text AS match_rule_before,
    (rb.image_count = 0)::boolean AS image_missing,
    (COALESCE(rb.own_sku_code, '') = '')::boolean AS own_sku_missing,
    rb.representative_image_url,
    false::boolean AS export_allowed,
    'pending'::text AS reviewer_decision,
    rb.raw_payload
  FROM review_base AS rb
  WHERE rb.source_channel = 'smartstore'
    AND (
      rb.smartstore_confirmed_product_no IS NULL
      OR rb.smartstore_confirmed_option_no IS NULL
      OR rb.smartstore_candidate_product_no IS NOT NULL
      OR rb.smartstore_candidate_option_no IS NOT NULL
      OR rb.image_count = 0
      OR COALESCE(rb.own_sku_code, '') = ''
    )
),

makeshop_review AS (
  SELECT
    'makeshop'::text AS source_channel,
    CASE
      WHEN rb.image_count = 0 THEN 'image_missing'
      WHEN COALESCE(rb.own_sku_code, '') = '' THEN 'own_sku_missing'
      WHEN rb.channel_product_code IS NULL OR rb.channel_option_code IS NULL THEN 'makeshop_missing'
      ELSE 'makeshop_review_required'
    END AS review_reason,
    rb.sku_id,
    rb.product_id,
    rb.selfpia_sku_code,
    rb.selfpia_product_code,
    rb.selfpia_option_no,
    rb.product_name,
    rb.option_name,
    rb.option_value,
    rb.own_sku_code,
    NULL::text AS confirmed_product_no,
    NULL::text AS confirmed_option_no,
    rb.channel_product_code AS candidate_product_no,
    rb.channel_option_code AS candidate_option_no,
    rb.raw_payload ->> 'source_row_ref' AS source_row_ref,
    NULL::integer AS candidate_rank,
    NULL::numeric AS candidate_score,
    rb.raw_payload ->> 'match_rule_before' AS match_rule_before,
    (rb.image_count = 0)::boolean AS image_missing,
    (COALESCE(rb.own_sku_code, '') = '')::boolean AS own_sku_missing,
    rb.representative_image_url,
    false::boolean AS export_allowed,
    'pending'::text AS reviewer_decision,
    rb.raw_payload
  FROM review_base AS rb
  WHERE rb.source_channel = 'makeshop'
    AND (
      rb.channel_product_code IS NULL
      OR rb.channel_option_code IS NULL
      OR rb.image_count = 0
      OR COALESCE(rb.own_sku_code, '') = ''
    )
),

ably_review AS (
  SELECT
    'ably'::text AS source_channel,
    CASE
      WHEN rb.image_count = 0 THEN 'image_missing'
      WHEN COALESCE(rb.own_sku_code, '') = '' THEN 'own_sku_missing'
      WHEN rb.channel_product_code IS NULL OR rb.channel_option_code IS NULL THEN 'ably_missing'
      ELSE 'ably_candidate_or_unreviewed'
    END AS review_reason,
    rb.sku_id,
    rb.product_id,
    rb.selfpia_sku_code,
    rb.selfpia_product_code,
    rb.selfpia_option_no,
    rb.product_name,
    rb.option_name,
    rb.option_value,
    rb.own_sku_code,
    NULL::text AS confirmed_product_no,
    NULL::text AS confirmed_option_no,
    rb.channel_product_code AS candidate_product_no,
    rb.channel_option_code AS candidate_option_no,
    NULL::text AS source_row_ref,
    NULL::integer AS candidate_rank,
    NULL::numeric AS candidate_score,
    NULL::text AS match_rule_before,
    (rb.image_count = 0)::boolean AS image_missing,
    (COALESCE(rb.own_sku_code, '') = '')::boolean AS own_sku_missing,
    rb.representative_image_url,
    false::boolean AS export_allowed,
    'pending'::text AS reviewer_decision,
    rb.raw_payload
  FROM review_base AS rb
  WHERE rb.source_channel = 'ably'
    /* Ably option_no uniqueness must be rechecked before any reviewed export design. */
    AND (
      rb.channel_option_code IS NULL
      OR rb.image_count = 0
      OR COALESCE(rb.own_sku_code, '') = ''
    )
),

playauto_review AS (
  SELECT
    'playauto'::text AS source_channel,
    CASE
      WHEN rb.image_count = 0 THEN 'image_missing'
      WHEN COALESCE(rb.own_sku_code, '') = '' THEN 'own_sku_missing'
      WHEN rb.channel_product_code IS NULL OR rb.channel_option_code IS NULL THEN 'playauto_missing'
      ELSE 'playauto_candidate_or_unreviewed'
    END AS review_reason,
    rb.sku_id,
    rb.product_id,
    rb.selfpia_sku_code,
    rb.selfpia_product_code,
    rb.selfpia_option_no,
    rb.product_name,
    rb.option_name,
    rb.option_value,
    rb.own_sku_code,
    NULL::text AS confirmed_product_no,
    NULL::text AS confirmed_option_no,
    rb.channel_product_code AS candidate_product_no,
    rb.channel_option_code AS candidate_option_no,
    NULL::text AS source_row_ref,
    NULL::integer AS candidate_rank,
    NULL::numeric AS candidate_score,
    NULL::text AS match_rule_before,
    (rb.image_count = 0)::boolean AS image_missing,
    (COALESCE(rb.own_sku_code, '') = '')::boolean AS own_sku_missing,
    rb.representative_image_url,
    false::boolean AS export_allowed,
    'pending'::text AS reviewer_decision,
    rb.raw_payload
  FROM review_base AS rb
  WHERE rb.source_channel = 'playauto'
    /* PlayAuto multi-line alignment must be validated before any reviewed export design. */
    AND (
      rb.channel_product_code IS NULL
      OR rb.channel_option_code IS NULL
      OR rb.image_count = 0
      OR COALESCE(rb.own_sku_code, '') = ''
    )
)

SELECT *
FROM smartstore_review
UNION ALL
SELECT *
FROM makeshop_review
UNION ALL
SELECT *
FROM ably_review
UNION ALL
SELECT *
FROM playauto_review
ORDER BY
  source_channel,
  review_reason,
  selfpia_product_code,
  selfpia_sku_code;
