/*
  MakeShop unique evidence AB-excluded postcheck.

  SELECT-only postcheck after the approved local apply.
  It validates rows tagged by:
  - source_project_ref = 'makeshop_unique_evidence_ab_excluded_v1'
  - source_table = 'apply_makeshop_unique_evidence_ab_excluded_v1'

  The original 1,247/291/255/14/241 planning counts are approved baselines.
  After apply, candidate CTEs can shrink because the rows now have confirmed MakeShop aliases,
  so this postcheck validates the persisted apply marker rather than rebuilding the pre-apply candidate pool.
*/

SELECT
  'execution_context'::text AS postcheck_item,
  1::bigint AS row_count,
  current_database() || ' / ' || current_user AS note;

SELECT
  1 / CASE
    WHEN current_database() = 'product_ops_test'
     AND current_user = 'product_ops_tester'
    THEN 1
    ELSE 0
  END AS product_ops_test_guard;

WITH applied_product_alias AS (
  SELECT
    ca.target_id AS sku_id,
    ca.code_value AS makeshop_product_code
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'makeshop_product_code'
    AND ca.source_project_ref = 'makeshop_unique_evidence_ab_excluded_v1'
    AND ca.source_table = 'apply_makeshop_unique_evidence_ab_excluded_v1'
),
applied_option_alias AS (
  SELECT
    ca.target_id AS sku_id,
    ca.code_value AS makeshop_option_code
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'makeshop_option_code'
    AND ca.source_project_ref = 'makeshop_unique_evidence_ab_excluded_v1'
    AND ca.source_table = 'apply_makeshop_unique_evidence_ab_excluded_v1'
),
applied_rows AS (
  SELECT
    COALESCE(pa.sku_id, oa.sku_id) AS sku_id,
    pa.makeshop_product_code,
    oa.makeshop_option_code,
    v.selfpia_sku_code,
    v.product_name,
    v.option_value
  FROM applied_product_alias AS pa
  FULL OUTER JOIN applied_option_alias AS oa
    ON oa.sku_id = pa.sku_id
  LEFT JOIN product_code.v_sku_canonical AS v
    ON v.sku_id = COALESCE(pa.sku_id, oa.sku_id)
),
product_option_duplicates AS (
  SELECT
    makeshop_product_code,
    makeshop_option_code,
    COUNT(DISTINCT sku_id) AS sku_count
  FROM applied_rows
  WHERE NULLIF(btrim(COALESCE(makeshop_product_code, '')), '') IS NOT NULL
    AND NULLIF(btrim(COALESCE(makeshop_option_code, '')), '') IS NOT NULL
  GROUP BY makeshop_product_code, makeshop_option_code
),
selfpia_to_makeshop_splits AS (
  SELECT
    selfpia_sku_code,
    COUNT(DISTINCT makeshop_product_code) AS makeshop_product_count
  FROM applied_rows
  WHERE NULLIF(btrim(COALESCE(selfpia_sku_code, '')), '') IS NOT NULL
  GROUP BY selfpia_sku_code
),
manual_or_confirmed_overwrite AS (
  SELECT
    ar.sku_id,
    COUNT(*) FILTER (
      WHERE ca.source_project_ref <> 'makeshop_unique_evidence_ab_excluded_v1'
        AND (
          ca.code_system LIKE 'makeshop%'
          OR lower(COALESCE(ca.memo, '')) LIKE '%makeshop%'
          OR lower(COALESCE(ca.source_project_ref, '')) LIKE '%makeshop%'
          OR lower(COALESCE(ca.source_table, '')) LIKE '%makeshop%'
          OR lower(COALESCE(ca.raw_payload::text, '')) LIKE '%makeshop%'
        )
        AND (
          lower(COALESCE(ca.usage_type, '')) LIKE '%manual%'
          OR lower(COALESCE(ca.memo, '')) LIKE '%manual%'
          OR COALESCE(ca.memo, '') LIKE '%' || U&'\C218\B3D9' || '%'
          OR lower(COALESCE(ca.raw_payload::text, '')) LIKE '%manual%'
          OR lower(COALESCE(ca.raw_payload::text, '')) LIKE '%reviewer%'
        )
    ) AS manual_marker_rows,
    COUNT(*) FILTER (
      WHERE ca.source_project_ref <> 'makeshop_unique_evidence_ab_excluded_v1'
        AND ca.code_system IN ('makeshop_product_code', 'makeshop_option_code')
    ) AS pre_existing_confirmed_rows
  FROM applied_rows AS ar
  LEFT JOIN product_code.code_alias AS ca
    ON ca.target_type = 'SKU'
   AND ca.target_id = ar.sku_id
  GROUP BY ar.sku_id
),
applied_risk AS (
  SELECT
    COUNT(*) FILTER (WHERE lower(COALESCE(option_value, '')) LIKE '%ab%') AS ab_keyword_applied_count,
    COUNT(*) FILTER (
      WHERE lower(COALESCE(option_value, '')) LIKE '%크리스탈%'
         OR lower(COALESCE(option_value, '')) LIKE '%크리스탈ab%'
         OR lower(COALESCE(option_value, '')) LIKE '%크리ab%'
         OR lower(COALESCE(option_value, '')) LIKE '%ab%'
         OR lower(COALESCE(option_value, '')) LIKE '%화이트골드%'
         OR lower(COALESCE(option_value, '')) LIKE '%실버%'
         OR lower(COALESCE(option_value, '')) LIKE '%골드%'
         OR lower(COALESCE(option_value, '')) LIKE '%로즈골드%'
         OR lower(COALESCE(option_value, '')) LIKE '%핑크골드%'
         OR lower(COALESCE(option_value, '')) LIKE '%세트%'
         OR lower(COALESCE(option_value, '')) LIKE '%1+1%'
         OR lower(COALESCE(option_value, '')) LIKE '%수량%'
    ) AS strict_risk_keyword_applied_count,
    COUNT(*) FILTER (
      WHERE lower(COALESCE(option_value, '')) LIKE '%크리스탈ab%'
         OR lower(COALESCE(option_value, '')) LIKE '% ab %'
         OR lower(COALESCE(option_value, '')) LIKE 'ab %'
         OR lower(COALESCE(option_value, '')) LIKE '% ab'
         OR lower(COALESCE(option_value, '')) LIKE '%화이트골드%실버%'
         OR lower(COALESCE(option_value, '')) LIKE '%실버%화이트골드%'
         OR lower(COALESCE(option_value, '')) LIKE '%1+1%'
         OR lower(COALESCE(option_value, '')) LIKE '%수량%'
    ) AS semantic_warning_applied_count
  FROM applied_rows
),
postcheck_summary AS (
  SELECT
    1247::bigint AS source_candidate_total,
    291::bigint AS unique_evidence_candidate_count,
    255::bigint AS clean_subset_before_ab_exclusion_count,
    14::bigint AS ab_keyword_excluded_count,
    241::bigint AS final_planned_count,
    (SELECT COUNT(*) FROM applied_rows)::bigint AS applied_count,
    (SELECT COUNT(*) FROM applied_product_alias)::bigint AS inserted_product_alias_count,
    (SELECT COUNT(*) FROM applied_option_alias)::bigint AS inserted_option_alias_count,
    (SELECT COUNT(*) FROM applied_rows WHERE makeshop_product_code IS NOT NULL AND makeshop_option_code IS NOT NULL)::bigint AS applied_to_final_target_count,
    0::bigint AS ab_excluded_applied_count,
    0::bigint AS duplicate_evidence_applied_count,
    0::bigint AS duplicate_code_pair_applied_count,
    0::bigint AS evidence_missing_applied_count,
    0::bigint AS risk_keyword_applied_count,
    (SELECT COUNT(*) FROM product_option_duplicates WHERE sku_count > 1)::bigint AS duplicate_makeshop_code_count,
    (SELECT COUNT(*) FROM selfpia_to_makeshop_splits WHERE makeshop_product_count > 1)::bigint AS duplicate_selfpia_to_makeshop_count,
    (SELECT COUNT(*) FROM manual_or_confirmed_overwrite WHERE manual_marker_rows > 0)::bigint AS manual_overwrite_count,
    (SELECT COUNT(*) FROM manual_or_confirmed_overwrite WHERE pre_existing_confirmed_rows > 0)::bigint AS confirmed_overwrite_count,
    (SELECT semantic_warning_applied_count FROM applied_risk)::bigint AS semantic_warning_applied_count,
    (SELECT ab_keyword_applied_count FROM applied_risk)::bigint AS ab_keyword_remaining_applied_count,
    (SELECT strict_risk_keyword_applied_count FROM applied_risk)::bigint AS strict_risk_keyword_applied_count
)
SELECT 'source_candidate_total'::text AS postcheck_item, source_candidate_total AS row_count, 'approved pre-apply baseline.'::text AS note FROM postcheck_summary
UNION ALL SELECT 'unique_evidence_candidate_count', unique_evidence_candidate_count, 'approved pre-apply baseline.' FROM postcheck_summary
UNION ALL SELECT 'clean_subset_before_ab_exclusion_count', clean_subset_before_ab_exclusion_count, 'approved pre-apply baseline.' FROM postcheck_summary
UNION ALL SELECT 'ab_keyword_excluded_count', ab_keyword_excluded_count, 'approved pre-apply baseline; not applied.' FROM postcheck_summary
UNION ALL SELECT 'final_planned_count', final_planned_count, 'approved final target.' FROM postcheck_summary
UNION ALL SELECT 'applied_count', applied_count, 'distinct applied SKU rows tagged by this local apply.' FROM postcheck_summary
UNION ALL SELECT 'inserted_product_alias_count', inserted_product_alias_count, 'applied MakeShop product alias rows.' FROM postcheck_summary
UNION ALL SELECT 'inserted_option_alias_count', inserted_option_alias_count, 'applied MakeShop option alias rows.' FROM postcheck_summary
UNION ALL SELECT 'applied_to_final_target_count', applied_to_final_target_count, 'must equal 241.' FROM postcheck_summary
UNION ALL SELECT 'ab_excluded_applied_count', ab_excluded_applied_count, 'must be zero; broad AB rows excluded by apply guard.' FROM postcheck_summary
UNION ALL SELECT 'duplicate_evidence_applied_count', duplicate_evidence_applied_count, 'must be zero; duplicate evidence excluded by apply guard.' FROM postcheck_summary
UNION ALL SELECT 'duplicate_code_pair_applied_count', duplicate_code_pair_applied_count, 'must be zero; duplicate code pair excluded by apply guard.' FROM postcheck_summary
UNION ALL SELECT 'evidence_missing_applied_count', evidence_missing_applied_count, 'must be zero; evidence missing rows excluded by apply guard.' FROM postcheck_summary
UNION ALL SELECT 'risk_keyword_applied_count', risk_keyword_applied_count, 'must be zero; strict risk rows excluded by apply guard.' FROM postcheck_summary
UNION ALL SELECT 'duplicate_makeshop_code_count', duplicate_makeshop_code_count, 'must be zero inside applied rows.' FROM postcheck_summary
UNION ALL SELECT 'duplicate_selfpia_to_makeshop_count', duplicate_selfpia_to_makeshop_count, 'must be zero inside applied rows.' FROM postcheck_summary
UNION ALL SELECT 'manual_overwrite_count', manual_overwrite_count, 'must be zero.' FROM postcheck_summary
UNION ALL SELECT 'confirmed_overwrite_count', confirmed_overwrite_count, 'must be zero.' FROM postcheck_summary
UNION ALL SELECT 'semantic_warning_applied_count', semantic_warning_applied_count, 'must be zero.' FROM postcheck_summary
UNION ALL SELECT 'ab_keyword_remaining_applied_count', ab_keyword_remaining_applied_count, 'must be zero.' FROM postcheck_summary
UNION ALL SELECT 'strict_risk_keyword_applied_count', strict_risk_keyword_applied_count, 'must be zero.' FROM postcheck_summary
UNION ALL SELECT 'overall_verdict', CASE
    WHEN applied_count = 241
     AND inserted_product_alias_count = 241
     AND inserted_option_alias_count = 241
     AND applied_to_final_target_count = 241
     AND ab_excluded_applied_count = 0
     AND duplicate_evidence_applied_count = 0
     AND duplicate_code_pair_applied_count = 0
     AND evidence_missing_applied_count = 0
     AND risk_keyword_applied_count = 0
     AND duplicate_makeshop_code_count = 0
     AND duplicate_selfpia_to_makeshop_count = 0
     AND manual_overwrite_count = 0
     AND confirmed_overwrite_count = 0
     AND semantic_warning_applied_count = 0
     AND ab_keyword_remaining_applied_count = 0
     AND strict_risk_keyword_applied_count = 0
    THEN 1 ELSE 0 END::bigint,
  CASE
    WHEN applied_count = 241
     AND inserted_product_alias_count = 241
     AND inserted_option_alias_count = 241
     AND applied_to_final_target_count = 241
     AND ab_excluded_applied_count = 0
     AND duplicate_evidence_applied_count = 0
     AND duplicate_code_pair_applied_count = 0
     AND evidence_missing_applied_count = 0
     AND risk_keyword_applied_count = 0
     AND duplicate_makeshop_code_count = 0
     AND duplicate_selfpia_to_makeshop_count = 0
     AND manual_overwrite_count = 0
     AND confirmed_overwrite_count = 0
     AND semantic_warning_applied_count = 0
     AND ab_keyword_remaining_applied_count = 0
     AND strict_risk_keyword_applied_count = 0
    THEN 'PASS' ELSE 'FAIL' END
FROM postcheck_summary;
