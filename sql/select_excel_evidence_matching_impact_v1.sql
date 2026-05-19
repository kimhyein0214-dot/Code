/*
  Excel evidence matching impact diagnosis.

  Purpose:
  - Read-only draft for a future stage relation.
  - It assumes stg.excel_evidence_match_stage already exists.
  - It summarizes how much manual review could be reduced by Excel evidence.
  - Candidate values are diagnostic evidence only.

  Safety:
  - SELECT-only.
  - No file output.
  - No remote connection.
  - export_allowed remains false.
  - reviewer_decision remains pending.
*/

WITH expected_stage AS (
  SELECT
    s.source_file,
    s.source_sheet,
    s.row_no,
    s.source_channel,
    s.raw_seller_management_code,
    s.normalized_selfpia_product_code,
    s.normalized_selfpia_sku_code,
    s.raw_product_name,
    s.normalized_product_name,
    s.raw_option_text,
    s.normalized_option_text,
    s.extracted_own_sku,
    s.smartstore_product_no_candidate,
    s.playauto_sku_code,
    s.raw_price,
    s.raw_stock,
    s.parse_status,
    s.parse_warning,
    s.match_status,
    s.safety_note,
    false::boolean AS export_allowed,
    'pending'::text AS reviewer_decision
  FROM stg.excel_evidence_match_stage AS s
),

selfpia_alias AS (
  SELECT
    ca.code_value AS selfpia_sku_code,
    ca.target_id AS sku_id,
    ca.selfpia_product_code
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'selfpia_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
),

own_sku_alias AS (
  SELECT
    ca.code_value AS own_sku_code,
    ca.target_id AS sku_id
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
),

stage_joined AS (
  SELECT
    es.*,
    sa.sku_id AS selfpia_joined_sku_id,
    oa.sku_id AS own_sku_joined_sku_id,
    v.product_id,
    v.product_name AS db_product_name,
    v.option_value AS db_option_text,
    lower(regexp_replace(COALESCE(es.normalized_product_name, es.raw_product_name, ''), '[^[:alnum:]가-힣]+', '', 'g')) AS stage_product_name_key,
    lower(regexp_replace(COALESCE(v.product_name, ''), '[^[:alnum:]가-힣]+', '', 'g')) AS db_product_name_key,
    lower(regexp_replace(COALESCE(es.normalized_option_text, es.raw_option_text, ''), '[^[:alnum:]가-힣]+', '', 'g')) AS stage_option_key,
    lower(regexp_replace(COALESCE(v.option_value, ''), '[^[:alnum:]가-힣]+', '', 'g')) AS db_option_key
  FROM expected_stage AS es
  LEFT JOIN selfpia_alias AS sa
    ON sa.selfpia_sku_code = es.normalized_selfpia_sku_code
  LEFT JOIN own_sku_alias AS oa
    ON oa.own_sku_code = es.extracted_own_sku
  LEFT JOIN product_code.v_sku_canonical AS v
    ON v.sku_id = COALESCE(sa.sku_id, oa.sku_id)
),

product_no_by_selfpia_sku AS (
  SELECT
    normalized_selfpia_sku_code,
    COUNT(DISTINCT smartstore_product_no_candidate) AS product_no_count_per_selfpia_sku
  FROM stage_joined
  WHERE NULLIF(btrim(COALESCE(normalized_selfpia_sku_code, '')), '') IS NOT NULL
    AND NULLIF(btrim(COALESCE(smartstore_product_no_candidate, '')), '') IS NOT NULL
  GROUP BY normalized_selfpia_sku_code
),

selfpia_sku_by_product_option AS (
  SELECT
    smartstore_product_no_candidate,
    stage_option_key,
    COUNT(DISTINCT normalized_selfpia_sku_code) AS selfpia_sku_count_per_product_option
  FROM stage_joined
  WHERE NULLIF(btrim(COALESCE(smartstore_product_no_candidate, '')), '') IS NOT NULL
    AND NULLIF(btrim(COALESCE(stage_option_key, '')), '') IS NOT NULL
    AND NULLIF(btrim(COALESCE(normalized_selfpia_sku_code, '')), '') IS NOT NULL
  GROUP BY
    smartstore_product_no_candidate,
    stage_option_key
),

option_candidates_by_selfpia_sku AS (
  SELECT
    normalized_selfpia_sku_code,
    stage_option_key,
    COUNT(*) AS normalized_option_candidate_count
  FROM stage_joined
  WHERE NULLIF(btrim(COALESCE(normalized_selfpia_sku_code, '')), '') IS NOT NULL
    AND NULLIF(btrim(COALESCE(stage_option_key, '')), '') IS NOT NULL
  GROUP BY
    normalized_selfpia_sku_code,
    stage_option_key
),

duplication_checks AS (
  SELECT
    sj.*,
    COALESCE(pns.product_no_count_per_selfpia_sku, 0) AS product_no_count_per_selfpia_sku,
    COALESCE(spo.selfpia_sku_count_per_product_option, 0) AS selfpia_sku_count_per_product_option,
    COALESCE(ocs.normalized_option_candidate_count, 0) AS normalized_option_candidate_count
  FROM stage_joined AS sj
  LEFT JOIN product_no_by_selfpia_sku AS pns
    ON pns.normalized_selfpia_sku_code = sj.normalized_selfpia_sku_code
  LEFT JOIN selfpia_sku_by_product_option AS spo
    ON spo.smartstore_product_no_candidate = sj.smartstore_product_no_candidate
   AND spo.stage_option_key = sj.stage_option_key
  LEFT JOIN option_candidates_by_selfpia_sku AS ocs
    ON ocs.normalized_selfpia_sku_code = sj.normalized_selfpia_sku_code
   AND ocs.stage_option_key = sj.stage_option_key
),

diagnosis AS (
  SELECT
    dc.*,
    (
      dc.stage_product_name_key <> ''
      AND dc.db_product_name_key <> ''
      AND dc.stage_product_name_key = dc.db_product_name_key
    ) AS product_name_support,
    (
      dc.stage_option_key <> ''
      AND dc.db_option_key <> ''
      AND dc.stage_option_key = dc.db_option_key
      AND COALESCE(dc.normalized_option_candidate_count, 0) = 1
    ) AS normalized_option_match_candidate,
    (
      COALESCE(dc.parse_warning, '') ILIKE '%crystal%'
      OR COALESCE(dc.parse_warning, '') ILIKE '%크리스탈%'
      OR COALESCE(dc.raw_option_text, '') LIKE '%크리스탈AB%'
      OR (
        COALESCE(dc.raw_option_text, '') LIKE '%크리스탈%'
        AND COALESCE(dc.raw_option_text, '') NOT LIKE '%크리스탈AB%'
      )
    ) AS crystal_crystal_ab_safety,
    (
      COALESCE(dc.parse_warning, '') ILIKE '%ab%'
      OR COALESCE(dc.raw_option_text, '') ~* '(^|[^[:alnum:]])AB([^[:alnum:]]|$)'
    ) AS ab_token_warning,
    (
      COALESCE(dc.parse_warning, '') LIKE '%화이트골드%'
      OR COALESCE(dc.parse_warning, '') LIKE '%실버%'
      OR COALESCE(dc.raw_option_text, '') LIKE '%화이트골드%'
      OR COALESCE(dc.raw_option_text, '') LIKE '%실버%'
    ) AS white_gold_silver_warning,
    (
      COALESCE(dc.parse_warning, '') ILIKE '%multiline%'
      OR COALESCE(dc.parse_warning, '') LIKE '%줄 수%'
      OR COALESCE(dc.safety_note, '') ILIKE '%multiline%'
    ) AS multiline_alignment_warning,
    (
      COALESCE(dc.product_no_count_per_selfpia_sku, 0) > 1
      OR COALESCE(dc.selfpia_sku_count_per_product_option, 0) > 1
      OR COALESCE(dc.normalized_option_candidate_count, 0) > 1
    ) AS conflict_or_duplicate
  FROM duplication_checks AS dc
),

classified AS (
  SELECT
    d.*,
    CASE
      WHEN NULLIF(btrim(COALESCE(d.normalized_selfpia_sku_code, '')), '') IS NULL THEN 'manual_review_required'
      WHEN d.selfpia_joined_sku_id IS NULL THEN 'manual_review_required'
      WHEN NULLIF(btrim(COALESCE(d.extracted_own_sku, '')), '') IS NOT NULL
       AND d.own_sku_joined_sku_id IS DISTINCT FROM d.selfpia_joined_sku_id THEN 'manual_review_required'
      WHEN NULLIF(btrim(COALESCE(d.smartstore_product_no_candidate, '')), '') IS NULL THEN 'manual_review_required'
      WHEN d.conflict_or_duplicate THEN 'manual_review_required'
      WHEN d.crystal_crystal_ab_safety THEN 'manual_review_required'
      WHEN d.ab_token_warning THEN 'manual_review_required'
      WHEN d.white_gold_silver_warning THEN 'manual_review_required'
      WHEN d.multiline_alignment_warning THEN 'manual_review_required'
      WHEN NOT d.normalized_option_match_candidate THEN 'manual_review_required'
      WHEN NOT d.product_name_support THEN 'manual_review_required'
      ELSE 'auto_confirm_ready_candidate'
    END AS diagnostic_match_status,
    false::boolean AS export_allowed_safe,
    'pending'::text AS reviewer_decision_safe
  FROM diagnosis AS d
)

SELECT
  'summary'::text AS section,
  COUNT(*) AS total_stage_rows,
  COUNT(*) FILTER (
    WHERE NULLIF(btrim(COALESCE(normalized_selfpia_sku_code, '')), '') IS NOT NULL
  ) AS parsed_selfpia_sku_count,
  COUNT(*) FILTER (
    WHERE NULLIF(btrim(COALESCE(extracted_own_sku, '')), '') IS NOT NULL
  ) AS parsed_own_sku_count,
  COUNT(*) FILTER (
    WHERE NULLIF(btrim(COALESCE(smartstore_product_no_candidate, '')), '') IS NOT NULL
  ) AS parsed_smartstore_product_no_count,
  COUNT(*) FILTER (
    WHERE selfpia_joined_sku_id IS NOT NULL
  ) AS selfpia_sku_joined_to_db_count,
  COUNT(*) FILTER (
    WHERE own_sku_joined_sku_id IS NOT NULL
  ) AS own_sku_joined_to_db_count,
  COUNT(*) FILTER (
    WHERE product_name_support
  ) AS product_name_support_count,
  COUNT(*) FILTER (
    WHERE normalized_option_match_candidate
  ) AS normalized_option_match_candidate_count,
  COUNT(*) FILTER (
    WHERE diagnostic_match_status = 'auto_confirm_ready_candidate'
  ) AS auto_confirm_ready_candidate_count,
  COUNT(*) FILTER (
    WHERE diagnostic_match_status = 'manual_review_required'
  ) AS manual_review_required_count,
  COUNT(*) FILTER (
    WHERE conflict_or_duplicate
  ) AS conflict_or_duplicate_count,
  COUNT(*) FILTER (
    WHERE crystal_crystal_ab_safety
  ) AS crystal_crystal_ab_safety_count,
  COUNT(*) FILTER (
    WHERE ab_token_warning
  ) AS ab_token_warning_count,
  COUNT(*) FILTER (
    WHERE white_gold_silver_warning
  ) AS white_gold_silver_warning_count,
  COUNT(*) FILTER (
    WHERE multiline_alignment_warning
  ) AS multiline_alignment_warning_count,
  bool_and(export_allowed_safe = false) AS export_allowed_is_always_false,
  bool_and(reviewer_decision_safe = 'pending') AS reviewer_decision_is_always_pending
FROM classified;
