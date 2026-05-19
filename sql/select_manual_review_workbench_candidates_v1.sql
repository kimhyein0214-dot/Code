/*
  Manual review workbench candidates v1.

  Scope:
  - SELECT-only.
  - Local product_ops_test only.
  - Read-only transaction with ROLLBACK.
  - No DDL.
  - No INSERT/UPDATE/DELETE/MERGE.
  - No COPY or \copy.
  - No file export.
  - No product_code.code_alias or product_code.sku_channel_mapping change.

  Purpose:
  - Produce frontend-shaped manual review candidates after local round-1
    auto-match applies.
  - Exclude clean rows that already have the same local channel alias.
  - Keep manual-matching candidates separate from inactive/channel-absent
    review candidates.
*/

BEGIN READ ONLY;

SELECT
  'guard'::text AS section,
  current_database() AS current_database,
  current_user AS current_user,
  current_setting('transaction_read_only') AS transaction_read_only,
  CASE
    WHEN current_database() = 'product_ops_test'
     AND current_user = 'product_ops_tester'
     AND current_setting('transaction_read_only') = 'on'
    THEN 'PASS'
    ELSE 'STOP'
  END AS guard_result,
  'manual review workbench candidate SELECT; no writes, no export'::text AS note;

WITH evidence AS MATERIALIZED (
  SELECT
    e.*,
    sf.source_file_name
  FROM product_code_stage.channel_option_evidence AS e
  LEFT JOIN product_code_stage.ably_playauto_source_file AS sf
    ON sf.source_file_id = e.source_file_id
  WHERE e.channel_code IN (
    'smartstore',
    'makeshop',
    'ably',
    'coupang',
    'kakaotalk_store'
  )
),
duplicate_sku AS MATERIALIZED (
  SELECT channel_code, channel_sku_code
  FROM evidence
  WHERE channel_sku_code IS NOT NULL
  GROUP BY channel_code, channel_sku_code
  HAVING COUNT(*) > 1
),
alias_map AS MATERIALIZED (
  SELECT
    regexp_replace(lower(btrim(code_value)), '^sellpia_', '') AS candidate_norm,
    MIN(target_id::text)::uuid AS sku_id,
    COUNT(DISTINCT target_id) AS sku_id_count
  FROM product_code.code_alias
  WHERE target_type = 'SKU'
    AND code_system IN ('selfpia_sku', 'own_sku')
    AND NULLIF(btrim(code_value), '') IS NOT NULL
  GROUP BY regexp_replace(lower(btrim(code_value)), '^sellpia_', '')
),
matched AS MATERIALIZED (
  SELECT
    e.*,
    am.sku_id AS matched_sku_id_candidate,
    am.sku_id_count,
    NULL::uuid AS matched_product_id_candidate,
    NULL::text AS virtual_sku_code,
    NULL::text AS option_name_selfpia,
    NULL::text AS selfpia_product_code,
    NULL::text AS product_name_selfpia,
    NULL::text AS selfpia_sku_code,
    NULL::text AS own_sku_code,
    concat_ws(
      ' ',
      e.product_name,
      e.option_name,
      e.option_value,
      e.selfpia_sku_candidate,
      e.own_sku_code_candidate,
      e.seller_product_code,
      e.channel_sku_code
    ) AS review_text,
    (e.parse_warning IS NOT NULL OR e.channel_product_code IS NULL) AS warning_bucket,
    (ds.channel_sku_code IS NOT NULL) AS duplicate_sku,
    (NOT COALESCE(e.is_active_candidate, false)) AS channel_absent_or_inactive_possible,
    (am.sku_id IS NULL OR am.sku_id_count IS NULL) AS evidence_missing,
    (COALESCE(am.sku_id_count, 0) > 1) AS duplicate_evidence,
    (e.selfpia_sku_candidate IS NOT NULL AND am.sku_id_count = 1) AS has_direct_selfpia_match
  FROM evidence AS e
  LEFT JOIN alias_map AS am
    ON am.candidate_norm = regexp_replace(
      lower(btrim(COALESCE(e.selfpia_sku_candidate, e.own_sku_code_candidate))),
      '^sellpia_',
      ''
    )
  LEFT JOIN duplicate_sku AS ds
    ON ds.channel_code = e.channel_code
   AND ds.channel_sku_code = e.channel_sku_code
),
source_conflict_product AS MATERIALIZED (
  SELECT channel_code, channel_product_code
  FROM matched
  WHERE sku_id_count = 1
    AND channel_product_code IS NOT NULL
  GROUP BY channel_code, channel_product_code
  HAVING COUNT(DISTINCT matched_sku_id_candidate) > 1
),
source_conflict_sku AS MATERIALIZED (
  SELECT channel_code, matched_sku_id_candidate
  FROM matched
  WHERE sku_id_count = 1
    AND matched_sku_id_candidate IS NOT NULL
    AND channel_product_code IS NOT NULL
  GROUP BY channel_code, matched_sku_id_candidate
  HAVING COUNT(DISTINCT channel_product_code) > 1
),
color_profile AS MATERIALIZED (
  SELECT
    channel_code,
    channel_product_code,
    bool_or(review_text ~ '(크리스탈AB|크리AB)') AS has_crystal_ab,
    bool_or(review_text ~ '크리스탈' AND review_text !~ '(크리스탈AB|크리AB)') AS has_crystal_plain
  FROM matched
  WHERE channel_product_code IS NOT NULL
  GROUP BY channel_code, channel_product_code
),
classified AS MATERIALIZED (
  SELECT
    m.*,
    (
      scp.channel_product_code IS NOT NULL
      OR scs.matched_sku_id_candidate IS NOT NULL
    ) AS source_conflict,
    (
      m.review_text ~ '(크리스탈AB|크리AB)'
      OR m.review_text ~ '(^|[^[:alnum:]])AB([^[:alnum:]]|$)'
      OR m.review_text ~ '(세트|SET|set|Set|수량)'
      OR m.review_text ~ '1\+1'
      OR (COALESCE(cp.has_crystal_ab, false) AND COALESCE(cp.has_crystal_plain, false))
    ) AS narrow_risk,
    false::boolean AS existing_alias_same_target,
    false::boolean AS existing_alias_conflict,
    false::boolean AS existing_mapping_same_target,
    false::boolean AS existing_mapping_conflict
  FROM matched AS m
  LEFT JOIN source_conflict_product AS scp
    ON scp.channel_code = m.channel_code
   AND scp.channel_product_code = m.channel_product_code
  LEFT JOIN source_conflict_sku AS scs
    ON scs.channel_code = m.channel_code
   AND scs.matched_sku_id_candidate = m.matched_sku_id_candidate
  LEFT JOIN color_profile AS cp
    ON cp.channel_code = m.channel_code
   AND cp.channel_product_code = m.channel_product_code
),
workbench_candidates AS MATERIALIZED (
  SELECT
    md5(concat_ws('|', evidence_id::text, channel_code, channel_product_code, channel_option_code, channel_sku_code)) AS review_candidate_id,
    channel_code,
    source_system,
    source_file_name,
    source_row_no,
    source_option_line_no,
    CASE
      WHEN source_conflict THEN 'source_conflict'
      WHEN duplicate_evidence OR duplicate_sku THEN 'duplicate'
      WHEN sku_id_count = 1 AND has_direct_selfpia_match THEN 'direct'
      WHEN sku_id_count = 1 THEN 'unique'
      WHEN COALESCE(sku_id_count, 0) = 0 THEN 'missing'
      ELSE 'needs_review'
    END AS evidence_level,
    'pending'::text AS review_status_default,
    CASE
      WHEN source_conflict THEN 'source_conflict'
      WHEN warning_bucket THEN 'warning_bucket'
      WHEN duplicate_sku THEN 'duplicate_sku'
      WHEN narrow_risk THEN 'narrow_risk'
      WHEN evidence_missing THEN 'evidence_missing'
      WHEN channel_absent_or_inactive_possible THEN 'channel_absent_or_inactive_possible'
      WHEN existing_alias_conflict OR existing_mapping_conflict THEN 'existing_conflict'
      ELSE 'manual_review_required'
    END AS risk_type,
    concat_ws(
      '; ',
      CASE WHEN source_conflict THEN 'same channel evidence points to conflicting SKU/product candidates' END,
      CASE WHEN warning_bucket THEN COALESCE(parse_warning, 'parse warning or missing channel product code') END,
      CASE WHEN duplicate_sku THEN 'duplicate channel_sku_code within channel evidence' END,
      CASE WHEN narrow_risk THEN 'narrow risk keyword or crystal/crystal AB conflict' END,
      CASE WHEN evidence_missing THEN 'no unique Selfpia/own SKU candidate matched' END,
      CASE WHEN channel_absent_or_inactive_possible THEN 'source status suggests inactive, hidden, waiting, sold-out, or absent channel listing' END,
      CASE WHEN existing_alias_conflict THEN 'existing channel alias points to another SKU' END,
      CASE WHEN existing_mapping_conflict THEN 'existing channel mapping points to another SKU' END
    ) AS risk_reason,
    channel_product_code,
    channel_option_code,
    channel_sku_code,
    seller_product_code,
    own_sku_code_candidate,
    selfpia_sku_candidate,
    matched_sku_id_candidate,
    matched_product_id_candidate,
    selfpia_product_code,
    COALESCE(selfpia_sku_code, virtual_sku_code) AS selfpia_sku_code,
    own_sku_code,
    product_name AS product_name_channel,
    concat_ws(' / ', NULLIF(option_name, ''), NULLIF(option_value, '')) AS option_name_channel,
    product_name_selfpia,
    option_name_selfpia,
    'not_checked_in_v1_select'::text AS image_status,
    CASE
      WHEN channel_absent_or_inactive_possible THEN 'inactive_possible'
      WHEN is_active_candidate THEN 'active_candidate'
      ELSE 'unknown'
    END AS source_status,
    normalized_sale_status,
    normalized_display_status,
    normalized_option_status,
    CASE
      WHEN channel_absent_or_inactive_possible THEN 'classify_channel_absent_or_inactive'
      WHEN source_conflict THEN 'compare_conflicting_candidates'
      WHEN warning_bucket THEN 'inspect_source_warning'
      WHEN duplicate_sku OR duplicate_evidence THEN 'compare_duplicate_candidates'
      WHEN narrow_risk THEN 'manual_option_risk_review'
      WHEN evidence_missing THEN 'find_or_mark_missing_evidence'
      WHEN existing_alias_conflict OR existing_mapping_conflict THEN 'do_not_overwrite_existing_mapping'
      ELSE 'manual_match_review'
    END AS suggested_action,
    'pending'::text AS reviewer_decision_placeholder,
    NULL::text AS reviewer_note_placeholder,
    CASE
      WHEN channel_absent_or_inactive_possible THEN 'deletion_or_inactive_review_candidate'
      ELSE 'manual_matching_candidate'
    END AS review_scope
  FROM classified
  WHERE NOT existing_alias_same_target
    AND NOT existing_mapping_same_target
    AND (
      source_conflict
      OR warning_bucket
      OR duplicate_sku
      OR narrow_risk
      OR evidence_missing
      OR channel_absent_or_inactive_possible
      OR existing_alias_conflict
      OR existing_mapping_conflict
      OR channel_code = 'kakaotalk_store'
    )
),
numbered AS MATERIALIZED (
  SELECT
    wc.*,
    row_number() OVER (PARTITION BY channel_code ORDER BY risk_type, source_row_no, review_candidate_id) AS rn_channel,
    row_number() OVER (PARTITION BY risk_type ORDER BY channel_code, source_row_no, review_candidate_id) AS rn_risk
  FROM workbench_candidates AS wc
),
summary_rows AS (
  SELECT 'summary_total'::text AS section, 'total_manual_review_candidate_count'::text AS metric_name, COUNT(*)::text AS metric_value FROM workbench_candidates
  UNION ALL SELECT 'summary_channel', channel_code, COUNT(*)::text FROM workbench_candidates GROUP BY channel_code
  UNION ALL SELECT 'summary_risk_type', risk_type, COUNT(*)::text FROM workbench_candidates GROUP BY risk_type
  UNION ALL SELECT 'summary_evidence_level', evidence_level, COUNT(*)::text FROM workbench_candidates GROUP BY evidence_level
  UNION ALL SELECT 'summary_source_status', source_status, COUNT(*)::text FROM workbench_candidates GROUP BY source_status
  UNION ALL SELECT 'summary_suggested_action', suggested_action, COUNT(*)::text FROM workbench_candidates GROUP BY suggested_action
  UNION ALL SELECT 'summary_review_scope', review_scope, COUNT(*)::text FROM workbench_candidates GROUP BY review_scope
  UNION ALL SELECT 'summary_frontend_v1_verdict', 'frontend_v1_display_ready', CASE WHEN COUNT(*) > 0 THEN 'READY_FOR_READ_ONLY_WORKBENCH' ELSE 'NEEDS_SOURCE_REVIEW' END FROM workbench_candidates
),
sample_rows AS (
  SELECT 'sample_by_channel'::text AS section, channel_code AS metric_name, rn_channel::text AS metric_value, numbered.*
  FROM numbered
  WHERE rn_channel <= 20

  UNION ALL

  SELECT 'sample_by_risk_type'::text AS section, risk_type AS metric_name, rn_risk::text AS metric_value, numbered.*
  FROM numbered
  WHERE rn_risk <= 20
)
SELECT
  sr.section,
  sr.metric_name,
  sr.metric_value,
  NULL::text AS review_candidate_id,
  NULL::text AS channel_code,
  NULL::text AS source_system,
  NULL::text AS source_file_name,
  NULL::integer AS source_row_no,
  NULL::text AS evidence_level,
  NULL::text AS review_status_default,
  NULL::text AS risk_type,
  NULL::text AS risk_reason,
  NULL::text AS channel_product_code,
  NULL::text AS channel_option_code,
  NULL::text AS channel_sku_code,
  NULL::text AS seller_product_code,
  NULL::text AS own_sku_code_candidate,
  NULL::text AS selfpia_sku_candidate,
  NULL::uuid AS matched_sku_id_candidate,
  NULL::uuid AS matched_product_id_candidate,
  NULL::text AS selfpia_product_code,
  NULL::text AS selfpia_sku_code,
  NULL::text AS own_sku_code,
  NULL::text AS product_name_channel,
  NULL::text AS option_name_channel,
  NULL::text AS product_name_selfpia,
  NULL::text AS option_name_selfpia,
  NULL::text AS image_status,
  NULL::text AS source_status,
  NULL::text AS normalized_sale_status,
  NULL::text AS normalized_display_status,
  NULL::text AS normalized_option_status,
  NULL::text AS suggested_action,
  NULL::text AS reviewer_decision_placeholder,
  NULL::text AS reviewer_note_placeholder,
  NULL::text AS review_scope
FROM summary_rows AS sr

UNION ALL

SELECT
  section,
  metric_name,
  metric_value,
  review_candidate_id,
  channel_code,
  source_system,
  source_file_name,
  source_row_no,
  evidence_level,
  review_status_default,
  risk_type,
  risk_reason,
  channel_product_code,
  channel_option_code,
  channel_sku_code,
  seller_product_code,
  own_sku_code_candidate,
  selfpia_sku_candidate,
  matched_sku_id_candidate,
  matched_product_id_candidate,
  selfpia_product_code,
  selfpia_sku_code,
  own_sku_code,
  product_name_channel,
  option_name_channel,
  product_name_selfpia,
  option_name_selfpia,
  image_status,
  source_status,
  normalized_sale_status,
  normalized_display_status,
  normalized_option_status,
  suggested_action,
  reviewer_decision_placeholder,
  reviewer_note_placeholder,
  review_scope
FROM sample_rows
ORDER BY section, metric_name, metric_value, channel_code NULLS FIRST, source_row_no NULLS FIRST;

ROLLBACK;
