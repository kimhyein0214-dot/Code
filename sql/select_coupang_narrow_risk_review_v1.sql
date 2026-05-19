/*
  Select Coupang narrow risk review v1.

  Scope:
  - SELECT-only.
  - Local product_ops_test only.
  - BEGIN READ ONLY + ROLLBACK.
  - No DDL/DML.
  - No INSERT/UPDATE/DELETE/MERGE.
  - No COPY or \copy.
  - No code_alias or sku_channel_mapping mutation.

  Purpose:
  - Review only narrow risk patterns inside the Coupang final planned 565
    candidates before writing any apply dryrun.
  - Coupang evidence currently has no channel_option_code, so review is
    product-alias oriented.
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
  'Coupang narrow risk review; SELECT-only'::text AS note;

WITH e AS MATERIALIZED (
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
    (am.sku_id IS NULL OR am.sku_id_count <> 1) AS evidence_missing_excluded,
    EXISTS (
      SELECT 1
      FROM product_code.code_alias AS ca
      WHERE ca.target_type = 'SKU'
        AND ca.code_system IN ('coupang_product_no', 'coupang_option_no')
        AND ca.code_value IN (e.channel_product_code, e.channel_option_code)
    ) AS existing_alias_excluded,
    EXISTS (
      SELECT 1
      FROM product_code.sku_channel_mapping AS scm
      WHERE lower(scm.channel_code) = 'coupang'
        AND (
          scm.channel_sku_code = e.channel_sku_code
          OR scm.seller_product_code = e.seller_product_code
          OR scm.own_sku_code = e.own_sku_code_candidate
        )
    ) AS existing_mapping_excluded
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
    AND NOT existing_alias_excluded
    AND NOT existing_mapping_excluded
),
final_planned AS MATERIALIZED (
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
  FROM final_planned
  GROUP BY channel_product_code
),
classified AS MATERIALIZED (
  SELECT
    fp.*,
    (fp.review_text ~ '(실버|골드|핑크골드|로즈골드|옐로우골드|크리스탈)') AS has_broad_risk_keyword,
    (
      fp.review_text ~ '(크리스탈|크리스탈AB|크리AB|화이트골드|실버|골드|로즈골드|핑크골드|세트|수량)'
      OR fp.review_text ~ '(^|[^A-Za-z0-9가-힣])AB([^A-Za-z0-9가-힣]|$)'
      OR fp.review_text ~ '1\+1'
    ) AS has_any_risk_keyword,
    (fp.review_text ~ '(크리스탈AB|크리AB)') AS has_crystal_ab,
    (fp.review_text ~ '(^|[^A-Za-z0-9가-힣])AB([^A-Za-z0-9가-힣]|$)') AS has_standalone_ab,
    (fp.review_text ~ '(세트|SET|set|Set|수량)') AS has_set_or_quantity,
    (fp.review_text ~ '1\+1') AS has_one_plus_one,
    (pcp.has_crystal_ab AND pcp.has_crystal_plain) AS has_crystal_vs_crystal_ab_conflict,
    (
      fp.review_text ~ '(크리스탈AB|크리AB)'
      OR fp.review_text ~ '(^|[^A-Za-z0-9가-힣])AB([^A-Za-z0-9가-힣]|$)'
      OR fp.review_text ~ '(세트|SET|set|Set|수량)'
      OR fp.review_text ~ '1\+1'
      OR (pcp.has_crystal_ab AND pcp.has_crystal_plain)
    ) AS has_narrow_risk
  FROM final_planned AS fp
  JOIN product_color_profile AS pcp
    ON pcp.channel_product_code = fp.channel_product_code
),
after_exclusion AS MATERIALIZED (
  SELECT *
  FROM classified
  WHERE NOT has_narrow_risk
),
duplicate_after_exclusion AS MATERIALIZED (
  SELECT channel_product_code, sku_id, COUNT(*) AS duplicate_count
  FROM after_exclusion
  GROUP BY channel_product_code, sku_id
  HAVING COUNT(*) > 1
),
semantic_warning_after_exclusion AS MATERIALIZED (
  SELECT *
  FROM after_exclusion
  WHERE channel_product_code IS NULL
     OR sku_id IS NULL
     OR normalized_selfpia_key IS NULL
),
samples AS (
  SELECT
    'narrow_risk_summary'::text AS section,
    NULL::integer AS sample_rank,
    jsonb_build_object(
      'final_planned_candidate_count', (SELECT COUNT(*) FROM classified),
      'broad_risk_keyword_count', (SELECT COUNT(*) FROM classified WHERE has_any_risk_keyword),
      'narrow_risk_candidate_count', (SELECT COUNT(*) FROM classified WHERE has_narrow_risk),
      'standalone_ab_count', (SELECT COUNT(*) FROM classified WHERE has_standalone_ab),
      'crystal_ab_count', (SELECT COUNT(*) FROM classified WHERE has_crystal_ab),
      'crystal_vs_crystal_ab_conflict_count', (SELECT COUNT(*) FROM classified WHERE has_crystal_vs_crystal_ab_conflict),
      'set_or_quantity_count', (SELECT COUNT(*) FROM classified WHERE has_set_or_quantity),
      'one_plus_one_count', (SELECT COUNT(*) FROM classified WHERE has_one_plus_one),
      'safe_broad_color_only_count', (SELECT COUNT(*) FROM classified WHERE has_broad_risk_keyword AND NOT has_narrow_risk),
      'final_planned_after_narrow_risk_exclusion_count', (SELECT COUNT(*) FROM after_exclusion),
      'duplicate_after_exclusion_count', (SELECT COUNT(*) FROM duplicate_after_exclusion),
      'semantic_warning_after_exclusion_count', (SELECT COUNT(*) FROM semantic_warning_after_exclusion),
      'apply_dryrun_ready_verdict',
        CASE
          WHEN (SELECT COUNT(*) FROM classified) = 565
           AND (SELECT COUNT(*) FROM duplicate_after_exclusion) = 0
           AND (SELECT COUNT(*) FROM semantic_warning_after_exclusion) = 0
          THEN 'READY_WITH_NARROW_RISK_EXCLUSION'
          ELSE 'NEEDS_REVIEW'
        END
    ) AS payload
  UNION ALL
  SELECT
    'narrow_risk_sample',
    row_number() OVER (ORDER BY channel_product_code, sku_id)::integer,
    to_jsonb(s)
  FROM (
    SELECT evidence_id, channel_product_code, sku_id, selfpia_sku_candidate, product_name, option_value, review_text,
           has_crystal_ab, has_standalone_ab, has_set_or_quantity, has_one_plus_one, has_crystal_vs_crystal_ab_conflict
    FROM classified
    WHERE has_narrow_risk
    ORDER BY channel_product_code, sku_id
    LIMIT 100
  ) AS s
  UNION ALL
  SELECT
    'standalone_ab_sample',
    row_number() OVER (ORDER BY channel_product_code, sku_id)::integer,
    to_jsonb(s)
  FROM (
    SELECT evidence_id, channel_product_code, sku_id, selfpia_sku_candidate, product_name, option_value, review_text
    FROM classified
    WHERE has_standalone_ab
    ORDER BY channel_product_code, sku_id
    LIMIT 100
  ) AS s
  UNION ALL
  SELECT
    'crystal_ab_sample',
    row_number() OVER (ORDER BY channel_product_code, sku_id)::integer,
    to_jsonb(s)
  FROM (
    SELECT evidence_id, channel_product_code, sku_id, selfpia_sku_candidate, product_name, option_value, review_text
    FROM classified
    WHERE has_crystal_ab
    ORDER BY channel_product_code, sku_id
    LIMIT 100
  ) AS s
  UNION ALL
  SELECT
    'crystal_vs_crystal_ab_conflict_sample',
    row_number() OVER (ORDER BY channel_product_code, sku_id)::integer,
    to_jsonb(s)
  FROM (
    SELECT evidence_id, channel_product_code, sku_id, selfpia_sku_candidate, product_name, option_value, review_text
    FROM classified
    WHERE has_crystal_vs_crystal_ab_conflict
    ORDER BY channel_product_code, sku_id
    LIMIT 100
  ) AS s
  UNION ALL
  SELECT
    'set_quantity_one_plus_one_sample',
    row_number() OVER (ORDER BY channel_product_code, sku_id)::integer,
    to_jsonb(s)
  FROM (
    SELECT evidence_id, channel_product_code, sku_id, selfpia_sku_candidate, product_name, option_value, review_text
    FROM classified
    WHERE has_set_or_quantity OR has_one_plus_one
    ORDER BY channel_product_code, sku_id
    LIMIT 100
  ) AS s
  UNION ALL
  SELECT
    'safe_broad_color_only_sample',
    row_number() OVER (ORDER BY channel_product_code, sku_id)::integer,
    to_jsonb(s)
  FROM (
    SELECT evidence_id, channel_product_code, sku_id, selfpia_sku_candidate, product_name, option_value, review_text
    FROM classified
    WHERE has_broad_risk_keyword
      AND NOT has_narrow_risk
    ORDER BY channel_product_code, sku_id
    LIMIT 50
  ) AS s
  UNION ALL
  SELECT
    'final_after_exclusion_sample',
    row_number() OVER (ORDER BY channel_product_code, sku_id)::integer,
    to_jsonb(s)
  FROM (
    SELECT evidence_id, channel_product_code, sku_id, selfpia_sku_candidate, product_name, option_value, review_text
    FROM after_exclusion
    ORDER BY channel_product_code, sku_id
    LIMIT 100
  ) AS s
  UNION ALL
  SELECT
    'warning_excluded_sample',
    row_number() OVER (ORDER BY channel_product_code, evidence_id)::integer,
    to_jsonb(s)
  FROM (
    SELECT evidence_id, channel_product_code, sku_id, selfpia_sku_candidate, product_name, option_value, parse_warning
    FROM matched
    WHERE warning_excluded
    ORDER BY channel_product_code, evidence_id
    LIMIT 50
  ) AS s
  UNION ALL
  SELECT
    'inactive_excluded_sample',
    row_number() OVER (ORDER BY channel_product_code, evidence_id)::integer,
    to_jsonb(s)
  FROM (
    SELECT evidence_id, channel_product_code, sku_id, selfpia_sku_candidate, product_name, option_value, sale_status_raw, option_status_raw
    FROM matched
    WHERE inactive_excluded
    ORDER BY channel_product_code, evidence_id
    LIMIT 50
  ) AS s
)
SELECT *
FROM samples
ORDER BY section, sample_rank NULLS FIRST;

ROLLBACK;
