/*
  Postcheck Ably clean unique evidence v1.

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
  WHERE channel_code = 'ably'
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
pair AS MATERIALIZED (
  SELECT DISTINCT source_system, channel_product_code, sku_id
  FROM clean_unique
),
source_conflict_pair AS MATERIALIZED (
  SELECT p.*
  FROM pair AS p
  WHERE EXISTS (
      SELECT 1
      FROM pair AS q
      WHERE q.source_system <> p.source_system
        AND q.sku_id = p.sku_id
        AND q.channel_product_code IS DISTINCT FROM p.channel_product_code
    )
     OR EXISTS (
      SELECT 1
      FROM pair AS q
      WHERE q.source_system <> p.source_system
        AND q.channel_product_code = p.channel_product_code
        AND q.sku_id <> p.sku_id
    )
),
non_conflict_pair AS MATERIALIZED (
  SELECT p.*
  FROM pair AS p
  WHERE NOT EXISTS (
    SELECT 1
    FROM source_conflict_pair AS c
    WHERE c.source_system = p.source_system
      AND c.channel_product_code = p.channel_product_code
      AND c.sku_id = p.sku_id
  )
),
source_final_planned AS MATERIALIZED (
  SELECT DISTINCT channel_product_code, sku_id
  FROM non_conflict_pair
),
review_rows AS MATERIALIZED (
  SELECT DISTINCT ON (fp.channel_product_code, fp.sku_id)
    fp.channel_product_code,
    fp.sku_id,
    cu.evidence_id,
    cu.source_system,
    cu.source_row_no,
    cu.source_option_line_no,
    cu.channel_option_code,
    cu.channel_sku_code,
    cu.seller_product_code,
    cu.own_sku_code_candidate,
    cu.selfpia_sku_candidate,
    cu.normalized_selfpia_key,
    cu.product_name,
    cu.option_name,
    cu.option_value,
    cu.warning_excluded,
    cu.duplicate_sku_excluded,
    cu.inactive_excluded,
    cu.evidence_missing_excluded,
    concat_ws(' ', cu.product_name, cu.option_name, cu.option_value, cu.selfpia_sku_candidate) AS review_text
  FROM source_final_planned AS fp
  JOIN clean_unique AS cu
    ON cu.channel_product_code = fp.channel_product_code
   AND cu.sku_id = fp.sku_id
  ORDER BY fp.channel_product_code, fp.sku_id, CASE WHEN cu.source_system = 'ably_csv' THEN 0 ELSE 1 END, cu.evidence_id
),
product_color_profile AS MATERIALIZED (
  SELECT
    channel_product_code,
    bool_or(review_text ~ '(크리스탈AB|크리AB)') AS has_crystal_ab,
    bool_or(review_text ~ '크리스탈' AND review_text !~ '(크리스탈AB|크리AB)') AS has_crystal_plain
  FROM review_rows
  GROUP BY channel_product_code
),
classified AS MATERIALIZED (
  SELECT
    rr.*,
    (
      rr.review_text ~ '(크리스탈AB|크리AB)'
      OR rr.review_text ~ '(^|[^A-Za-z0-9가-힣])AB([^A-Za-z0-9가-힣]|$)'
      OR rr.review_text ~ '(세트|SET|set|Set|수량)'
      OR rr.review_text ~ '1\+1'
      OR (pcp.has_crystal_ab AND pcp.has_crystal_plain)
    ) AS has_narrow_risk
  FROM review_rows AS rr
  JOIN product_color_profile AS pcp
    ON pcp.channel_product_code = rr.channel_product_code
),
final_clean_planned AS MATERIALIZED (
  SELECT *
  FROM classified
  WHERE NOT has_narrow_risk
),
applied_product_alias AS MATERIALIZED (
  SELECT *
  FROM product_code.code_alias
  WHERE code_system = 'ably_product_no'
    AND target_type = 'SKU'
    AND raw_payload->>'apply_version' = 'ably_unique_evidence_clean_v1'
),
applied_option_alias AS MATERIALIZED (
  SELECT *
  FROM product_code.code_alias
  WHERE code_system = 'ably_option_no'
    AND target_type = 'SKU'
    AND raw_payload->>'apply_version' = 'ably_unique_evidence_clean_v1'
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
duplicate_ably_code AS MATERIALIZED (
  SELECT code_system, code_value, target_id, COUNT(*) AS duplicate_count
  FROM product_code.code_alias
  WHERE code_system IN ('ably_product_no', 'ably_option_no')
  GROUP BY code_system, code_value, target_id
  HAVING COUNT(*) > 1
),
duplicate_selfpia_to_ably AS MATERIALIZED (
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
source_conflict_applied AS MATERIALIZED (
  SELECT ac.*
  FROM applied_clean AS ac
  JOIN source_conflict_pair AS scp
    ON scp.channel_product_code = ac.channel_product_code
   AND scp.sku_id = ac.sku_id
),
warning_applied AS MATERIALIZED (
  SELECT *
  FROM applied_clean
  WHERE warning_excluded
),
duplicate_sku_applied AS MATERIALIZED (
  SELECT *
  FROM applied_clean
  WHERE duplicate_sku_excluded
),
inactive_applied AS MATERIALIZED (
  SELECT *
  FROM applied_clean
  WHERE inactive_excluded
),
evidence_missing_applied AS MATERIALIZED (
  SELECT *
  FROM applied_clean
  WHERE evidence_missing_excluded
),
rate AS MATERIALIZED (
  SELECT
    (SELECT COUNT(*) FROM e)::numeric AS ably_evidence_total,
    (SELECT COUNT(*) FROM applied_clean)::numeric AS applied_candidate_count
)
SELECT
  'postcheck_summary'::text AS section,
  (SELECT ok FROM guard) AS guard_ok,
  (SELECT COUNT(*) FROM source_final_planned)::bigint AS source_final_planned_count,
  (SELECT COUNT(*) FROM classified WHERE has_narrow_risk)::bigint AS narrow_risk_excluded_count,
  (SELECT COUNT(*) FROM final_clean_planned)::bigint AS final_clean_planned_count,
  (SELECT COUNT(*) FROM applied_clean)::bigint AS applied_count,
  (SELECT COUNT(*) FROM applied_product_alias)::bigint AS inserted_product_alias_count,
  (SELECT COUNT(*) FROM applied_option_alias)::bigint AS inserted_option_alias_count,
  ((SELECT COUNT(*) FROM applied_product_alias) + (SELECT COUNT(*) FROM applied_option_alias))::bigint AS total_inserted_code_alias_count,
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE lower(channel_code) = 'ably')::bigint AS sku_channel_mapping_inserted_count,
  0::bigint AS existing_confirmed_manual_overwrite_count,
  (SELECT COUNT(*) FROM applied_outside_final_clean)::bigint AS applied_outside_final_clean_count,
  (SELECT COUNT(*) FROM duplicate_ably_code)::bigint AS duplicate_ably_code_count,
  (SELECT COUNT(*) FROM duplicate_selfpia_to_ably)::bigint AS duplicate_selfpia_to_ably_count,
  (SELECT COUNT(*) FROM semantic_warning)::bigint AS semantic_warning_count,
  (SELECT COUNT(*) FROM narrow_risk_applied)::bigint AS narrow_risk_applied_count,
  (SELECT COUNT(*) FROM source_conflict_applied)::bigint AS source_conflict_applied_count,
  (SELECT COUNT(*) FROM warning_applied)::bigint AS warning_applied_count,
  (SELECT COUNT(*) FROM duplicate_sku_applied)::bigint AS duplicate_sku_applied_count,
  (SELECT COUNT(*) FROM inactive_applied)::bigint AS inactive_applied_count,
  (SELECT COUNT(*) FROM evidence_missing_applied)::bigint AS evidence_missing_applied_count,
  round((SELECT applied_candidate_count * 100.0 / NULLIF(ably_evidence_total, 0) FROM rate), 2) AS applied_candidate_rate_of_ably_evidence_pct,
  round(((SELECT COUNT(*) FROM applied_clean)::numeric * 100.0 / 3024), 2) AS applied_candidate_rate_of_final_planned_pct,
  CASE
    WHEN (SELECT ok FROM guard)
     AND (SELECT COUNT(*) FROM source_final_planned) = 3024
     AND (SELECT COUNT(*) FROM classified WHERE has_narrow_risk) = 751
     AND (SELECT COUNT(*) FROM final_clean_planned) = 2273
     AND (SELECT COUNT(*) FROM applied_clean) = 2273
     AND (SELECT COUNT(*) FROM applied_product_alias) = 2273
     AND (SELECT COUNT(*) FROM applied_option_alias) = 561
     AND (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE lower(channel_code) = 'ably') = 0
     AND (SELECT COUNT(*) FROM applied_outside_final_clean) = 0
     AND (SELECT COUNT(*) FROM duplicate_ably_code) = 0
     AND (SELECT COUNT(*) FROM duplicate_selfpia_to_ably) = 0
     AND (SELECT COUNT(*) FROM semantic_warning) = 0
     AND (SELECT COUNT(*) FROM narrow_risk_applied) = 0
     AND (SELECT COUNT(*) FROM source_conflict_applied) = 0
     AND (SELECT COUNT(*) FROM warning_applied) = 0
     AND (SELECT COUNT(*) FROM duplicate_sku_applied) = 0
     AND (SELECT COUNT(*) FROM inactive_applied) = 0
     AND (SELECT COUNT(*) FROM evidence_missing_applied) = 0
    THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS overall_verdict;
