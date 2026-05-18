-- =============================================================================
-- select_manual_review_targets_v1.sql
--
-- Purpose:
--   Read-only draft queries for manual review CSV target discovery.
--
-- Target:
--   Local product_ops_test read model.
--
-- Safety:
--   Read-only draft. This file only contains WITH and SELECT statements.
--   It does not write files and does not change database state.
--
-- Notes:
--   product_code.v_sku_canonical can have more rows than distinct sku_id if
--   alias state changes. Each query builds sku_base with DISTINCT ON (sku_id).
--   source_row_ref can be NULL in initial SKU-level SELECTs. When MakeShop
--   matrix rows are attached later, prefer source_file:row_no and fill
--   candidate_rank, candidate_score, and match_rule_before.
--
-- Image note:
--   Missing image queries assume product_code.product_image exists and local
--   image load is complete. If image load status is unclear, treat missing
--   image rows as reference only.
-- =============================================================================

-- A. Smartstore candidate-only SKU.
-- Finds SKU rows with Smartstore candidate aliases but no confirmed Smartstore
-- productNo or optionNo alias. Candidate values are not export-safe.
WITH sku_base AS (
  SELECT DISTINCT ON (v.sku_id)
    v.sku_id,
    v.selfpia_sku_code AS selfpia_sku,
    v.virtual_sku_code,
    v.product_name,
    v.option_value AS option_name
  FROM product_code.v_sku_canonical v
  ORDER BY v.sku_id, v.selfpia_sku_code NULLS LAST
),
smartstore_alias AS (
  SELECT
    ca.target_id AS sku_id,
    string_agg(DISTINCT ca.code_value, ', ' ORDER BY ca.code_value)
      FILTER (WHERE ca.code_system = 'smartstore_product_no') AS confirmed_product_no,
    string_agg(DISTINCT ca.code_value, ', ' ORDER BY ca.code_value)
      FILTER (WHERE ca.code_system = 'smartstore_option_no') AS confirmed_option_no,
    string_agg(DISTINCT ca.code_value, ', ' ORDER BY ca.code_value)
      FILTER (WHERE ca.code_system = 'smartstore_product_no_candidate') AS candidate_product_no,
    string_agg(DISTINCT ca.code_value, ', ' ORDER BY ca.code_value)
      FILTER (WHERE ca.code_system = 'smartstore_option_no_candidate') AS candidate_option_no,
    string_agg(DISTINCT ca.code_system, ', ' ORDER BY ca.code_system)
      FILTER (WHERE ca.code_system IN ('smartstore_product_no', 'smartstore_option_no')) AS confirmed_code_system,
    string_agg(DISTINCT ca.code_system, ', ' ORDER BY ca.code_system)
      FILTER (WHERE ca.code_system IN ('smartstore_product_no_candidate', 'smartstore_option_no_candidate')) AS candidate_code_system,
    count(*) FILTER (WHERE ca.code_system IN ('smartstore_product_no_candidate', 'smartstore_option_no_candidate')) AS candidate_count
  FROM product_code.code_alias ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system IN (
      'smartstore_product_no',
      'smartstore_option_no',
      'smartstore_product_no_candidate',
      'smartstore_option_no_candidate'
    )
  GROUP BY ca.target_id
),
own_sku_alias AS (
  SELECT ca.target_id AS sku_id, string_agg(DISTINCT ca.code_value, ', ' ORDER BY ca.code_value) AS own_sku
  FROM product_code.code_alias ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
  GROUP BY ca.target_id
),
image_state AS (
  SELECT pi.sku_id, count(*) AS image_count
  FROM product_code.product_image pi
  WHERE pi.sku_id IS NOT NULL
  GROUP BY pi.sku_id
)
SELECT
  'smartstore_candidate_only:' || s.sku_id::text || ':smartstore' AS review_id,
  'A'::text AS source_query_section,
  NULL::text AS source_row_ref,
  'smartstore_candidate_only' AS review_group,
  'P2' AS priority,
  s.sku_id,
  s.selfpia_sku,
  s.virtual_sku_code,
  s.product_name,
  s.option_name,
  o.own_sku,
  CASE WHEN COALESCE(i.image_count, 0) > 0 THEN 'has_image' ELSE 'missing_image' END AS image_status,
  'smartstore' AS channel,
  'smartstore_product_or_option' AS code_system,
  a.confirmed_code_system,
  a.candidate_code_system,
  a.confirmed_product_no,
  a.confirmed_option_no,
  a.candidate_product_no,
  a.candidate_option_no,
  a.candidate_count,
  'candidate_exists_without_confirmed_code' AS candidate_reason,
  'candidate_only' AS match_status,
  NULL::text AS conflict_note,
  'candidate is operating-unconfirmed; do not use for export' AS risk_note,
  false::boolean AS export_allowed,
  'candidate_unreviewed' AS export_blocker_reason,
  'pending'::text AS reviewer_decision,
  NULL::text AS reviewer_note,
  NULL::text AS reviewed_code_value,
  NULL::timestamptz AS reviewed_at
FROM sku_base s
JOIN smartstore_alias a ON a.sku_id = s.sku_id
LEFT JOIN own_sku_alias o ON o.sku_id = s.sku_id
LEFT JOIN image_state i ON i.sku_id = s.sku_id
WHERE a.candidate_count > 0
  AND a.confirmed_code_system IS NULL
ORDER BY s.selfpia_sku NULLS LAST, s.sku_id;

-- B. Smartstore unmapped SKU.
-- Finds SKU rows with no confirmed and no candidate Smartstore productNo or optionNo.
WITH sku_base AS (
  SELECT DISTINCT ON (v.sku_id)
    v.sku_id,
    v.selfpia_sku_code AS selfpia_sku,
    v.virtual_sku_code,
    v.product_name,
    v.option_value AS option_name
  FROM product_code.v_sku_canonical v
  ORDER BY v.sku_id, v.selfpia_sku_code NULLS LAST
),
smartstore_alias AS (
  SELECT
    ca.target_id AS sku_id,
    count(*) FILTER (WHERE ca.code_system IN ('smartstore_product_no', 'smartstore_option_no')) AS confirmed_count,
    count(*) FILTER (WHERE ca.code_system IN ('smartstore_product_no_candidate', 'smartstore_option_no_candidate')) AS candidate_count
  FROM product_code.code_alias ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system IN (
      'smartstore_product_no',
      'smartstore_option_no',
      'smartstore_product_no_candidate',
      'smartstore_option_no_candidate'
    )
  GROUP BY ca.target_id
),
own_sku_alias AS (
  SELECT ca.target_id AS sku_id, string_agg(DISTINCT ca.code_value, ', ' ORDER BY ca.code_value) AS own_sku
  FROM product_code.code_alias ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
  GROUP BY ca.target_id
),
image_state AS (
  SELECT pi.sku_id, count(*) AS image_count
  FROM product_code.product_image pi
  WHERE pi.sku_id IS NOT NULL
  GROUP BY pi.sku_id
)
SELECT
  'smartstore_unmapped:' || s.sku_id::text || ':smartstore' AS review_id,
  'B'::text AS source_query_section,
  NULL::text AS source_row_ref,
  'smartstore_unmapped' AS review_group,
  'P2' AS priority,
  s.sku_id,
  s.selfpia_sku,
  s.virtual_sku_code,
  s.product_name,
  s.option_name,
  o.own_sku,
  CASE WHEN COALESCE(i.image_count, 0) > 0 THEN 'has_image' ELSE 'missing_image' END AS image_status,
  'smartstore' AS channel,
  'smartstore_product_or_option' AS code_system,
  NULL::text AS confirmed_code_system,
  NULL::text AS candidate_code_system,
  NULL::text AS confirmed_product_no,
  NULL::text AS confirmed_option_no,
  NULL::text AS candidate_product_no,
  NULL::text AS candidate_option_no,
  0::integer AS candidate_count,
  'no_confirmed_or_candidate_smartstore_code' AS candidate_reason,
  'unmapped' AS match_status,
  NULL::text AS conflict_note,
  'needs source confirmation before any Smartstore export' AS risk_note,
  false::boolean AS export_allowed,
  'no_confirmed_code' AS export_blocker_reason,
  'pending'::text AS reviewer_decision,
  NULL::text AS reviewer_note,
  NULL::text AS reviewed_code_value,
  NULL::timestamptz AS reviewed_at
FROM sku_base s
LEFT JOIN smartstore_alias a ON a.sku_id = s.sku_id
LEFT JOIN own_sku_alias o ON o.sku_id = s.sku_id
LEFT JOIN image_state i ON i.sku_id = s.sku_id
WHERE COALESCE(a.confirmed_count, 0) = 0
  AND COALESCE(a.candidate_count, 0) = 0
ORDER BY s.selfpia_sku NULLS LAST, s.sku_id;

-- C. MakeShop unmapped SKU.
-- Finds SKU rows without product_code.sku_channel_mapping for channel_code makeshop.
WITH sku_base AS (
  SELECT DISTINCT ON (v.sku_id)
    v.sku_id,
    v.selfpia_sku_code AS selfpia_sku,
    v.virtual_sku_code,
    v.product_name,
    v.option_value AS option_name
  FROM product_code.v_sku_canonical v
  ORDER BY v.sku_id, v.selfpia_sku_code NULLS LAST
),
makeshop_mapping AS (
  SELECT scm.sku_id, count(*) AS mapping_count
  FROM product_code.sku_channel_mapping scm
  WHERE scm.channel_code = 'makeshop'
  GROUP BY scm.sku_id
),
own_sku_alias AS (
  SELECT ca.target_id AS sku_id, string_agg(DISTINCT ca.code_value, ', ' ORDER BY ca.code_value) AS own_sku
  FROM product_code.code_alias ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
  GROUP BY ca.target_id
),
image_state AS (
  SELECT pi.sku_id, count(*) AS image_count
  FROM product_code.product_image pi
  WHERE pi.sku_id IS NOT NULL
  GROUP BY pi.sku_id
)
SELECT
  'makeshop_missing_mapping:' || s.sku_id::text || ':makeshop' AS review_id,
  'C'::text AS source_query_section,
  NULL::text AS source_row_ref,
  'makeshop_missing_mapping' AS review_group,
  'P2' AS priority,
  s.sku_id,
  s.selfpia_sku,
  s.virtual_sku_code,
  s.product_name,
  s.option_name,
  o.own_sku,
  CASE WHEN COALESCE(i.image_count, 0) > 0 THEN 'has_image' ELSE 'missing_image' END AS image_status,
  'makeshop' AS channel,
  'makeshop_channel_mapping' AS code_system,
  NULL::text AS confirmed_code_system,
  NULL::text AS candidate_code_system,
  NULL::text AS confirmed_product_no,
  NULL::text AS confirmed_option_no,
  NULL::text AS candidate_product_no,
  NULL::text AS candidate_option_no,
  0::integer AS candidate_count,
  'no_makeshop_sku_channel_mapping' AS candidate_reason,
  'missing_mapping' AS match_status,
  NULL::text AS conflict_note,
  'own_sku alone must not auto-confirm MakeShop mapping' AS risk_note,
  false::boolean AS export_allowed,
  'channel_mapping_missing' AS export_blocker_reason,
  'pending'::text AS reviewer_decision,
  NULL::text AS reviewer_note,
  NULL::text AS reviewed_code_value,
  NULL::timestamptz AS reviewed_at
FROM sku_base s
LEFT JOIN makeshop_mapping m ON m.sku_id = s.sku_id
LEFT JOIN own_sku_alias o ON o.sku_id = s.sku_id
LEFT JOIN image_state i ON i.sku_id = s.sku_id
WHERE COALESCE(m.mapping_count, 0) = 0
ORDER BY s.selfpia_sku NULLS LAST, s.sku_id;

-- D. SKU with neither Smartstore nor MakeShop connection.
-- Priority review target for channel connection gaps.
WITH sku_base AS (
  SELECT DISTINCT ON (v.sku_id)
    v.sku_id,
    v.selfpia_sku_code AS selfpia_sku,
    v.virtual_sku_code,
    v.product_name,
    v.option_value AS option_name
  FROM product_code.v_sku_canonical v
  ORDER BY v.sku_id, v.selfpia_sku_code NULLS LAST
),
smartstore_alias AS (
  SELECT
    ca.target_id AS sku_id,
    count(*) FILTER (WHERE ca.code_system IN ('smartstore_product_no', 'smartstore_option_no')) AS confirmed_count,
    count(*) FILTER (WHERE ca.code_system IN ('smartstore_product_no_candidate', 'smartstore_option_no_candidate')) AS candidate_count
  FROM product_code.code_alias ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system IN (
      'smartstore_product_no',
      'smartstore_option_no',
      'smartstore_product_no_candidate',
      'smartstore_option_no_candidate'
    )
  GROUP BY ca.target_id
),
makeshop_mapping AS (
  SELECT scm.sku_id, count(*) AS mapping_count
  FROM product_code.sku_channel_mapping scm
  WHERE scm.channel_code = 'makeshop'
  GROUP BY scm.sku_id
),
own_sku_alias AS (
  SELECT ca.target_id AS sku_id, string_agg(DISTINCT ca.code_value, ', ' ORDER BY ca.code_value) AS own_sku
  FROM product_code.code_alias ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
  GROUP BY ca.target_id
),
image_state AS (
  SELECT pi.sku_id, count(*) AS image_count
  FROM product_code.product_image pi
  WHERE pi.sku_id IS NOT NULL
  GROUP BY pi.sku_id
)
SELECT
  'smartstore_and_makeshop_missing:' || s.sku_id::text || ':multi' AS review_id,
  'D'::text AS source_query_section,
  NULL::text AS source_row_ref,
  'smartstore_and_makeshop_missing' AS review_group,
  'P1' AS priority,
  s.sku_id,
  s.selfpia_sku,
  s.virtual_sku_code,
  s.product_name,
  s.option_name,
  o.own_sku,
  CASE WHEN COALESCE(i.image_count, 0) > 0 THEN 'has_image' ELSE 'missing_image' END AS image_status,
  'smartstore,makeshop' AS channel,
  'channel_connection' AS code_system,
  NULL::text AS confirmed_code_system,
  NULL::text AS candidate_code_system,
  NULL::text AS confirmed_product_no,
  NULL::text AS confirmed_option_no,
  NULL::text AS candidate_product_no,
  NULL::text AS candidate_option_no,
  0::integer AS candidate_count,
  'no_smartstore_code_and_no_makeshop_mapping' AS candidate_reason,
  'unmapped_both_channels' AS match_status,
  'both Smartstore code and MakeShop mapping are missing' AS conflict_note,
  'highest channel connection gap; review before export planning' AS risk_note,
  false::boolean AS export_allowed,
  'channel_mapping_missing' AS export_blocker_reason,
  'pending'::text AS reviewer_decision,
  NULL::text AS reviewer_note,
  NULL::text AS reviewed_code_value,
  NULL::timestamptz AS reviewed_at
FROM sku_base s
LEFT JOIN smartstore_alias a ON a.sku_id = s.sku_id
LEFT JOIN makeshop_mapping m ON m.sku_id = s.sku_id
LEFT JOIN own_sku_alias o ON o.sku_id = s.sku_id
LEFT JOIN image_state i ON i.sku_id = s.sku_id
WHERE COALESCE(a.confirmed_count, 0) = 0
  AND COALESCE(a.candidate_count, 0) = 0
  AND COALESCE(m.mapping_count, 0) = 0
ORDER BY s.selfpia_sku NULLS LAST, s.sku_id;

-- E. SKU without product image.
-- Assumes product_code.product_image exists and local image load is complete.
-- If image load status is unclear, treat this section as reference only.
WITH sku_base AS (
  SELECT DISTINCT ON (v.sku_id)
    v.sku_id,
    v.selfpia_sku_code AS selfpia_sku,
    v.virtual_sku_code,
    v.product_name,
    v.option_value AS option_name
  FROM product_code.v_sku_canonical v
  ORDER BY v.sku_id, v.selfpia_sku_code NULLS LAST
),
own_sku_alias AS (
  SELECT ca.target_id AS sku_id, string_agg(DISTINCT ca.code_value, ', ' ORDER BY ca.code_value) AS own_sku
  FROM product_code.code_alias ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
  GROUP BY ca.target_id
),
image_state AS (
  SELECT pi.sku_id, count(*) AS image_count
  FROM product_code.product_image pi
  WHERE pi.sku_id IS NOT NULL
  GROUP BY pi.sku_id
)
SELECT
  'missing_image:' || s.sku_id::text || ':asset' AS review_id,
  'E'::text AS source_query_section,
  NULL::text AS source_row_ref,
  'missing_image' AS review_group,
  'P3' AS priority,
  s.sku_id,
  s.selfpia_sku,
  s.virtual_sku_code,
  s.product_name,
  s.option_name,
  o.own_sku,
  'missing_image' AS image_status,
  'asset' AS channel,
  'product_image' AS code_system,
  NULL::text AS confirmed_code_system,
  NULL::text AS candidate_code_system,
  NULL::text AS confirmed_product_no,
  NULL::text AS confirmed_option_no,
  NULL::text AS candidate_product_no,
  NULL::text AS candidate_option_no,
  0::integer AS candidate_count,
  'no_product_image_for_sku' AS candidate_reason,
  'missing_asset' AS match_status,
  NULL::text AS conflict_note,
  'image missing can block human review and channel content quality' AS risk_note,
  false::boolean AS export_allowed,
  'image_missing' AS export_blocker_reason,
  'pending'::text AS reviewer_decision,
  NULL::text AS reviewer_note,
  NULL::text AS reviewed_code_value,
  NULL::timestamptz AS reviewed_at
FROM sku_base s
LEFT JOIN own_sku_alias o ON o.sku_id = s.sku_id
LEFT JOIN image_state i ON i.sku_id = s.sku_id
WHERE COALESCE(i.image_count, 0) = 0
ORDER BY s.selfpia_sku NULLS LAST, s.sku_id;

-- F. SKU without own_sku alias.
-- Finds SKU rows with no own_sku code_alias. own_sku absence is evidence gap,
-- not a reason to infer channel mapping automatically.
WITH sku_base AS (
  SELECT DISTINCT ON (v.sku_id)
    v.sku_id,
    v.selfpia_sku_code AS selfpia_sku,
    v.virtual_sku_code,
    v.product_name,
    v.option_value AS option_name
  FROM product_code.v_sku_canonical v
  ORDER BY v.sku_id, v.selfpia_sku_code NULLS LAST
),
own_sku_alias AS (
  SELECT
    ca.target_id AS sku_id,
    string_agg(DISTINCT ca.code_value, ', ' ORDER BY ca.code_value) AS own_sku,
    count(*) AS own_sku_count
  FROM product_code.code_alias ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
  GROUP BY ca.target_id
),
image_state AS (
  SELECT pi.sku_id, count(*) AS image_count
  FROM product_code.product_image pi
  WHERE pi.sku_id IS NOT NULL
  GROUP BY pi.sku_id
)
SELECT
  'missing_own_sku:' || s.sku_id::text || ':asset' AS review_id,
  'F'::text AS source_query_section,
  NULL::text AS source_row_ref,
  'missing_own_sku' AS review_group,
  'P3' AS priority,
  s.sku_id,
  s.selfpia_sku,
  s.virtual_sku_code,
  s.product_name,
  s.option_name,
  o.own_sku,
  CASE WHEN COALESCE(i.image_count, 0) > 0 THEN 'has_image' ELSE 'missing_image' END AS image_status,
  'asset' AS channel,
  'own_sku' AS code_system,
  NULL::text AS confirmed_code_system,
  NULL::text AS candidate_code_system,
  NULL::text AS confirmed_product_no,
  NULL::text AS confirmed_option_no,
  NULL::text AS candidate_product_no,
  NULL::text AS candidate_option_no,
  0::integer AS candidate_count,
  'no_own_sku_alias_for_sku' AS candidate_reason,
  'missing_asset' AS match_status,
  NULL::text AS conflict_note,
  'own_sku gap must be reviewed separately; no automatic channel confirmation' AS risk_note,
  false::boolean AS export_allowed,
  'own_sku_missing' AS export_blocker_reason,
  'pending'::text AS reviewer_decision,
  NULL::text AS reviewer_note,
  NULL::text AS reviewed_code_value,
  NULL::timestamptz AS reviewed_at
FROM sku_base s
LEFT JOIN own_sku_alias o ON o.sku_id = s.sku_id
LEFT JOIN image_state i ON i.sku_id = s.sku_id
WHERE COALESCE(o.own_sku_count, 0) = 0
ORDER BY s.selfpia_sku NULLS LAST, s.sku_id;

-- G. SKU with both confirmed and candidate Smartstore aliases.
-- Finds rows where candidate cleanup or conflict review is needed.
WITH sku_base AS (
  SELECT DISTINCT ON (v.sku_id)
    v.sku_id,
    v.selfpia_sku_code AS selfpia_sku,
    v.virtual_sku_code,
    v.product_name,
    v.option_value AS option_name
  FROM product_code.v_sku_canonical v
  ORDER BY v.sku_id, v.selfpia_sku_code NULLS LAST
),
smartstore_alias AS (
  SELECT
    ca.target_id AS sku_id,
    string_agg(DISTINCT ca.code_value, ', ' ORDER BY ca.code_value)
      FILTER (WHERE ca.code_system = 'smartstore_product_no') AS confirmed_product_no,
    string_agg(DISTINCT ca.code_value, ', ' ORDER BY ca.code_value)
      FILTER (WHERE ca.code_system = 'smartstore_option_no') AS confirmed_option_no,
    string_agg(DISTINCT ca.code_value, ', ' ORDER BY ca.code_value)
      FILTER (WHERE ca.code_system = 'smartstore_product_no_candidate') AS candidate_product_no,
    string_agg(DISTINCT ca.code_value, ', ' ORDER BY ca.code_value)
      FILTER (WHERE ca.code_system = 'smartstore_option_no_candidate') AS candidate_option_no,
    string_agg(DISTINCT ca.code_system, ', ' ORDER BY ca.code_system)
      FILTER (WHERE ca.code_system IN ('smartstore_product_no', 'smartstore_option_no')) AS confirmed_code_system,
    string_agg(DISTINCT ca.code_system, ', ' ORDER BY ca.code_system)
      FILTER (WHERE ca.code_system IN ('smartstore_product_no_candidate', 'smartstore_option_no_candidate')) AS candidate_code_system,
    count(*) FILTER (WHERE ca.code_system IN ('smartstore_product_no', 'smartstore_option_no')) AS confirmed_count,
    count(*) FILTER (WHERE ca.code_system IN ('smartstore_product_no_candidate', 'smartstore_option_no_candidate')) AS candidate_count
  FROM product_code.code_alias ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system IN (
      'smartstore_product_no',
      'smartstore_option_no',
      'smartstore_product_no_candidate',
      'smartstore_option_no_candidate'
    )
  GROUP BY ca.target_id
),
own_sku_alias AS (
  SELECT ca.target_id AS sku_id, string_agg(DISTINCT ca.code_value, ', ' ORDER BY ca.code_value) AS own_sku
  FROM product_code.code_alias ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
  GROUP BY ca.target_id
),
image_state AS (
  SELECT pi.sku_id, count(*) AS image_count
  FROM product_code.product_image pi
  WHERE pi.sku_id IS NOT NULL
  GROUP BY pi.sku_id
)
SELECT
  'smartstore_confirmed_with_candidate:' || s.sku_id::text || ':smartstore' AS review_id,
  'G'::text AS source_query_section,
  NULL::text AS source_row_ref,
  'smartstore_confirmed_with_candidate' AS review_group,
  'P1' AS priority,
  s.sku_id,
  s.selfpia_sku,
  s.virtual_sku_code,
  s.product_name,
  s.option_name,
  o.own_sku,
  CASE WHEN COALESCE(i.image_count, 0) > 0 THEN 'has_image' ELSE 'missing_image' END AS image_status,
  'smartstore' AS channel,
  'smartstore_product_or_option' AS code_system,
  a.confirmed_code_system,
  a.candidate_code_system,
  a.confirmed_product_no,
  a.confirmed_option_no,
  a.candidate_product_no,
  a.candidate_option_no,
  a.candidate_count,
  'confirmed_code_exists_but_candidate_remains' AS candidate_reason,
  'confirmed_with_candidate' AS match_status,
  'confirmed and candidate Smartstore code coexist; verify productNo and optionNo separately' AS conflict_note,
  'review candidate cleanup; verify productNo and optionNo are not mixed' AS risk_note,
  false::boolean AS export_allowed,
  'conflict_confirmed_and_candidate' AS export_blocker_reason,
  'pending'::text AS reviewer_decision,
  NULL::text AS reviewer_note,
  NULL::text AS reviewed_code_value,
  NULL::timestamptz AS reviewed_at
FROM sku_base s
JOIN smartstore_alias a ON a.sku_id = s.sku_id
LEFT JOIN own_sku_alias o ON o.sku_id = s.sku_id
LEFT JOIN image_state i ON i.sku_id = s.sku_id
WHERE a.confirmed_count > 0
  AND a.candidate_count > 0
ORDER BY s.selfpia_sku NULLS LAST, s.sku_id;

-- H. Manual review target summary count.
-- Counts current local read model groups by distinct sku_id and keeps outputs
-- reference groups marked as output_row_count.
WITH sku_base AS (
  SELECT DISTINCT ON (v.sku_id)
    v.sku_id
  FROM product_code.v_sku_canonical v
  ORDER BY v.sku_id, v.selfpia_sku_code NULLS LAST
),
smartstore_alias AS (
  SELECT
    ca.target_id AS sku_id,
    count(*) FILTER (WHERE ca.code_system IN ('smartstore_product_no', 'smartstore_option_no')) AS confirmed_count,
    count(*) FILTER (WHERE ca.code_system IN ('smartstore_product_no_candidate', 'smartstore_option_no_candidate')) AS candidate_count
  FROM product_code.code_alias ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system IN (
      'smartstore_product_no',
      'smartstore_option_no',
      'smartstore_product_no_candidate',
      'smartstore_option_no_candidate'
    )
  GROUP BY ca.target_id
),
makeshop_mapping AS (
  SELECT scm.sku_id, count(*) AS mapping_count
  FROM product_code.sku_channel_mapping scm
  WHERE scm.channel_code = 'makeshop'
  GROUP BY scm.sku_id
),
own_sku_alias AS (
  SELECT ca.target_id AS sku_id, count(*) AS own_sku_count
  FROM product_code.code_alias ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
  GROUP BY ca.target_id
),
image_state AS (
  SELECT pi.sku_id, count(*) AS image_count
  FROM product_code.product_image pi
  WHERE pi.sku_id IS NOT NULL
  GROUP BY pi.sku_id
),
classified AS (
  SELECT
    s.sku_id,
    COALESCE(a.confirmed_count, 0) AS smartstore_confirmed_count,
    COALESCE(a.candidate_count, 0) AS smartstore_candidate_count,
    COALESCE(m.mapping_count, 0) AS makeshop_mapping_count,
    COALESCE(o.own_sku_count, 0) AS own_sku_count,
    COALESCE(i.image_count, 0) AS image_count
  FROM sku_base s
  LEFT JOIN smartstore_alias a ON a.sku_id = s.sku_id
  LEFT JOIN makeshop_mapping m ON m.sku_id = s.sku_id
  LEFT JOIN own_sku_alias o ON o.sku_id = s.sku_id
  LEFT JOIN image_state i ON i.sku_id = s.sku_id
)
SELECT
  metric_name,
  target_count,
  count_basis,
  false::boolean AS export_allowed_default,
  note
FROM (
  SELECT
    'smartstore_candidate_only' AS metric_name,
    count(*) AS target_count,
    'distinct_sku_count' AS count_basis,
    'candidate rows are not export source' AS note
  FROM classified
  WHERE smartstore_candidate_count > 0 AND smartstore_confirmed_count = 0
  UNION ALL
  SELECT
    'smartstore_unmapped',
    count(*),
    'distinct_sku_count',
    'no confirmed or candidate Smartstore code'
  FROM classified
  WHERE smartstore_candidate_count = 0 AND smartstore_confirmed_count = 0
  UNION ALL
  SELECT
    'makeshop_missing_mapping',
    count(*),
    'distinct_sku_count',
    'no MakeShop channel mapping'
  FROM classified
  WHERE makeshop_mapping_count = 0
  UNION ALL
  SELECT
    'smartstore_and_makeshop_missing',
    count(*),
    'distinct_sku_count',
    'both primary channel links are missing'
  FROM classified
  WHERE smartstore_candidate_count = 0
    AND smartstore_confirmed_count = 0
    AND makeshop_mapping_count = 0
  UNION ALL
  SELECT
    'missing_image',
    count(*),
    'distinct_sku_count',
    'depends on product_image local load status'
  FROM classified
  WHERE image_count = 0
  UNION ALL
  SELECT
    'missing_own_sku',
    count(*),
    'distinct_sku_count',
    'own_sku evidence gap'
  FROM classified
  WHERE own_sku_count = 0
  UNION ALL
  SELECT
    'smartstore_confirmed_with_candidate',
    count(*),
    'distinct_sku_count',
    'candidate cleanup or conflict review needed'
  FROM classified
  WHERE smartstore_confirmed_count > 0 AND smartstore_candidate_count > 0
  UNION ALL
  SELECT 'makeshop_review_required_outputs_reference', 19408::bigint, 'output_row_count', 'reference only from existing MakeShop outputs'
  UNION ALL
  SELECT 'makeshop_ambiguous_weak_top1_outputs_reference', 12585::bigint, 'output_row_count', 'reference only from existing MakeShop outputs'
  UNION ALL
  SELECT 'makeshop_ambiguous_manual_outputs_reference', 3192::bigint, 'output_row_count', 'reference only from existing MakeShop outputs'
  UNION ALL
  SELECT 'makeshop_not_in_alias_outputs_reference', 592::bigint, 'output_row_count', 'reference only from existing MakeShop outputs'
  UNION ALL
  SELECT 'makeshop_null_key_outputs_reference', 2289::bigint, 'output_row_count', 'reference only from existing MakeShop outputs'
  UNION ALL
  SELECT 'makeshop_pattern_loose_outputs_reference', 750::bigint, 'output_row_count', 'reference only from existing MakeShop outputs'
) summary_rows
ORDER BY metric_name;



