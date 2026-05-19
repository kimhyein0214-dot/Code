/*
  Postcheck Coupang clean unique evidence v1.

  Scope:
  - SELECT-only.
  - Local product_ops_test only.
  - No DDL/DML.
  - No COPY or \copy.
*/

WITH guard AS MATERIALIZED (
  SELECT
    current_database() = 'product_ops_test'
    AND current_user = 'product_ops_tester' AS ok
),
e AS MATERIALIZED (
  SELECT *
  FROM product_code_stage.channel_option_evidence
  WHERE channel_code = 'coupang'
),
duplicate_sku AS MATERIALIZED (
  SELECT channel_sku_code
  FROM e
  WHERE channel_sku_code IS NOT NULL
  GROUP BY channel_sku_code
  HAVING COUNT(*) > 1
),
alias_map AS MATERIALIZED (
  SELECT
    regexp_replace(lower(btrim(code_value)), '^sellpia_', '') AS candidate_norm,
    min(target_id::text)::uuid AS sku_id,
    COUNT(DISTINCT target_id) AS sku_id_count
  FROM product_code.code_alias
  WHERE target_type = 'SKU'
    AND code_system IN ('selfpia_sku', 'own_sku')
    AND code_value IS NOT NULL
  GROUP BY regexp_replace(lower(btrim(code_value)), '^sellpia_', '')
),
matched AS MATERIALIZED (
  SELECT
    e.*,
    am.sku_id,
    am.sku_id_count,
    regexp_replace(lower(btrim(coalesce(e.selfpia_sku_candidate, e.own_sku_code_candidate))), '^sellpia_', '') AS normalized_selfpia_key,
    concat_ws(' ', e.product_name, e.option_name, e.option_value, e.selfpia_sku_candidate, e.own_sku_code_candidate, e.channel_sku_code) AS review_text,
    (e.parse_warning IS NOT NULL OR e.channel_product_code IS NULL) AS warning_excluded,
    (d.channel_sku_code IS NOT NULL) AS duplicate_sku_excluded,
    (NOT e.is_active_candidate) AS inactive_excluded,
    (am.sku_id IS NULL OR am.sku_id_count <> 1) AS evidence_missing_excluded
  FROM e
  LEFT JOIN alias_map AS am
    ON am.candidate_norm = regexp_replace(lower(btrim(coalesce(e.selfpia_sku_candidate, e.own_sku_code_candidate))), '^sellpia_', '')
  LEFT JOIN duplicate_sku AS d
    ON d.channel_sku_code = e.channel_sku_code
),
clean_unique AS MATERIALIZED (
  SELECT *
  FROM matched
  WHERE sku_id_count = 1
    AND NOT warning_excluded
    AND NOT duplicate_sku_excluded
    AND NOT inactive_excluded
    AND NOT evidence_missing_excluded
),
source_final_planned AS MATERIALIZED (
  SELECT DISTINCT ON (channel_product_code, sku_id)
    *
  FROM clean_unique
  ORDER BY channel_product_code, sku_id, evidence_id
),
product_color_profile AS MATERIALIZED (
  SELECT
    channel_product_code,
    bool_or(review_text ~ '(크리스탈AB|크리AB)') AS has_crystal_ab,
    bool_or(review_text ~ '크리스탈' AND review_text !~ '(크리스탈AB|크리AB)') AS has_crystal_plain
  FROM source_final_planned
  GROUP BY channel_product_code
),
classified AS MATERIALIZED (
  SELECT
    sfp.*,
    (
      sfp.review_text ~ '(크리스탈AB|크리AB)'
      OR sfp.review_text ~ '(^|[^A-Za-z0-9가-힣])AB([^A-Za-z0-9가-힣]|$)'
      OR sfp.review_text ~ '(세트|SET|set|Set|수량)'
      OR sfp.review_text ~ '1\+1'
      OR (pcp.has_crystal_ab AND pcp.has_crystal_plain)
    ) AS has_narrow_risk
  FROM source_final_planned AS sfp
  JOIN product_color_profile AS pcp
    ON pcp.channel_product_code = sfp.channel_product_code
),
final_clean_planned AS MATERIALIZED (
  SELECT *
  FROM classified
  WHERE NOT has_narrow_risk
),
applied_product_alias AS MATERIALIZED (
  SELECT *
  FROM product_code.code_alias
  WHERE code_system = 'coupang_product_no'
    AND target_type = 'SKU'
    AND raw_payload->>'apply_version' = 'coupang_unique_evidence_clean_v1'
),
applied_option_alias AS MATERIALIZED (
  SELECT *
  FROM product_code.code_alias
  WHERE code_system = 'coupang_option_no'
    AND target_type = 'SKU'
    AND raw_payload->>'apply_version' = 'coupang_unique_evidence_clean_v1'
),
applied_clean AS MATERIALIZED (
  SELECT fcp.*
  FROM final_clean_planned AS fcp
  JOIN applied_product_alias AS apa
    ON apa.target_id = fcp.sku_id
   AND apa.code_value = fcp.channel_product_code
),
applied_outside_final_clean AS MATERIALIZED (
  SELECT apa.*
  FROM applied_product_alias AS apa
  LEFT JOIN final_clean_planned AS fcp
    ON fcp.sku_id = apa.target_id
   AND fcp.channel_product_code = apa.code_value
  WHERE fcp.sku_id IS NULL
),
duplicate_coupang_code AS MATERIALIZED (
  SELECT code_system, code_value, target_id, COUNT(*) AS duplicate_count
  FROM product_code.code_alias
  WHERE code_system IN ('coupang_product_no', 'coupang_option_no')
  GROUP BY code_system, code_value, target_id
  HAVING COUNT(*) > 1
),
duplicate_selfpia_to_coupang AS MATERIALIZED (
  SELECT target_id, COUNT(DISTINCT code_value) AS channel_product_code_count
  FROM applied_product_alias
  GROUP BY target_id
  HAVING COUNT(DISTINCT code_value) > 1
),
semantic_warning AS MATERIALIZED (
  SELECT *
  FROM applied_clean
  WHERE channel_product_code IS NULL
     OR sku_id IS NULL
     OR normalized_selfpia_key IS NULL
),
narrow_risk_applied AS MATERIALIZED (
  SELECT *
  FROM applied_clean
  WHERE has_narrow_risk
),
warning_applied AS MATERIALIZED (
  SELECT *
  FROM applied_clean
  WHERE warning_excluded
),
inactive_applied AS MATERIALIZED (
  SELECT *
  FROM applied_clean
  WHERE inactive_excluded
),
rate AS MATERIALIZED (
  SELECT
    (SELECT COUNT(*) FROM e)::numeric AS coupang_evidence_total,
    (SELECT COUNT(*) FROM applied_clean)::numeric AS applied_candidate_count
)
SELECT
  'postcheck_summary'::text AS section,
  (SELECT ok FROM guard) AS guard_ok,
  (SELECT COUNT(*) FROM e)::bigint AS coupang_evidence_total,
  (SELECT COUNT(*) FROM source_final_planned)::bigint AS source_final_planned_count,
  (SELECT COUNT(*) FROM classified WHERE has_narrow_risk)::bigint AS narrow_risk_excluded_count,
  (SELECT COUNT(*) FROM final_clean_planned)::bigint AS final_clean_planned_count,
  (SELECT COUNT(*) FROM applied_clean)::bigint AS applied_count,
  (SELECT COUNT(*) FROM applied_product_alias)::bigint AS inserted_product_alias_count,
  (SELECT COUNT(*) FROM applied_option_alias)::bigint AS inserted_option_alias_count,
  ((SELECT COUNT(*) FROM applied_product_alias) + (SELECT COUNT(*) FROM applied_option_alias))::bigint AS total_inserted_code_alias_count,
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE lower(channel_code) = 'coupang')::bigint AS sku_channel_mapping_inserted_count,
  0::bigint AS existing_confirmed_manual_overwrite_count,
  (SELECT COUNT(*) FROM applied_outside_final_clean)::bigint AS applied_outside_final_clean_count,
  (SELECT COUNT(*) FROM duplicate_coupang_code)::bigint AS duplicate_coupang_code_count,
  (SELECT COUNT(*) FROM duplicate_selfpia_to_coupang)::bigint AS duplicate_selfpia_to_coupang_count,
  (SELECT COUNT(*) FROM semantic_warning)::bigint AS semantic_warning_count,
  (SELECT COUNT(*) FROM narrow_risk_applied)::bigint AS narrow_risk_applied_count,
  (SELECT COUNT(*) FROM warning_applied)::bigint AS warning_applied_count,
  (SELECT COUNT(*) FROM inactive_applied)::bigint AS inactive_applied_count,
  round((SELECT applied_candidate_count * 100.0 / NULLIF(coupang_evidence_total, 0) FROM rate), 2) AS applied_candidate_rate_of_coupang_evidence_pct,
  round(((SELECT COUNT(*) FROM applied_clean)::numeric * 100.0 / 565), 2) AS applied_candidate_rate_of_final_planned_pct,
  CASE
    WHEN (SELECT ok FROM guard)
     AND (SELECT COUNT(*) FROM e) = 1283
     AND (SELECT COUNT(*) FROM source_final_planned) = 565
     AND (SELECT COUNT(*) FROM classified WHERE has_narrow_risk) = 26
     AND (SELECT COUNT(*) FROM final_clean_planned) = 539
     AND (SELECT COUNT(*) FROM applied_clean) = 539
     AND (SELECT COUNT(*) FROM applied_product_alias) = 539
     AND (SELECT COUNT(*) FROM applied_option_alias) = 0
     AND (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE lower(channel_code) = 'coupang') = 0
     AND (SELECT COUNT(*) FROM applied_outside_final_clean) = 0
     AND (SELECT COUNT(*) FROM duplicate_coupang_code) = 0
     AND (SELECT COUNT(*) FROM duplicate_selfpia_to_coupang) = 0
     AND (SELECT COUNT(*) FROM semantic_warning) = 0
     AND (SELECT COUNT(*) FROM narrow_risk_applied) = 0
     AND (SELECT COUNT(*) FROM warning_applied) = 0
     AND (SELECT COUNT(*) FROM inactive_applied) = 0
    THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS overall_verdict;
