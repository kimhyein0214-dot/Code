/*
  Dryrun Coupang unique evidence candidates v1.

  Scope:
  - Local product_ops_test only.
  - Dryrun only: BEGIN + ROLLBACK.
  - No COMMIT.
  - No DDL.
  - No COPY or \copy.
  - No product_code.sku_channel_mapping mutation.
  - product_code.code_alias INSERT is executed only inside this transaction
    and must be fully rolled back.

  Candidate policy:
  - channel_code='coupang' only.
  - PlayAuto is only the source system; never store channel_code='playauto'.
  - Normalize sellpia_ prefix before joining to selfpia/own SKU aliases.
  - Existing Ably aliases are not used as SKU match evidence.
*/

BEGIN;

WITH guard AS MATERIALIZED (
  SELECT
    current_database() = 'product_ops_test'
    AND current_user = 'product_ops_tester' AS ok
)
SELECT
  'guard'::text AS section,
  current_database() AS current_database,
  current_user AS current_user,
  current_setting('transaction_read_only') AS transaction_read_only,
  CASE WHEN (SELECT ok FROM guard) THEN 'PASS' ELSE 'STOP' END AS guard_result,
  'Coupang unique evidence dryrun; writes are rolled back'::text AS note;

WITH guard AS MATERIALIZED (
  SELECT
    current_database() = 'product_ops_test'
    AND current_user = 'product_ops_tester' AS ok
),
before_counts AS MATERIALIZED (
  SELECT
    (SELECT COUNT(*) FROM product_code.code_alias WHERE code_system IN ('coupang_product_no', 'coupang_option_no'))::bigint AS coupang_code_alias_before_count,
    (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE lower(channel_code) = 'coupang')::bigint AS coupang_sku_channel_mapping_before_count
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
risk_classified AS MATERIALIZED (
  SELECT
    fp.*,
    (
      fp.review_text ~ '(크리스탈|크리스탈AB|크리AB|화이트골드|실버|골드|로즈골드|핑크골드|세트|수량)'
      OR fp.review_text ~ '(^|[^A-Za-z0-9가-힣])AB([^A-Za-z0-9가-힣]|$)'
      OR fp.review_text ~ '1\+1'
    ) AS has_risk_keyword
  FROM final_planned AS fp
),
duplicate_coupang_code AS MATERIALIZED (
  SELECT channel_product_code, sku_id, COUNT(*) AS duplicate_count
  FROM final_planned
  GROUP BY channel_product_code, sku_id
  HAVING COUNT(*) > 1
),
duplicate_selfpia_to_coupang AS MATERIALIZED (
  SELECT sku_id, COUNT(DISTINCT channel_product_code) AS channel_product_code_count
  FROM final_planned
  GROUP BY sku_id
  HAVING COUNT(DISTINCT channel_product_code) > 1
),
semantic_warning AS MATERIALIZED (
  SELECT *
  FROM final_planned
  WHERE channel_product_code IS NULL
     OR sku_id IS NULL
     OR normalized_selfpia_key IS NULL
),
product_alias_insert AS (
  INSERT INTO product_code.code_alias (
    target_type,
    target_id,
    code_system,
    code_value,
    usage_type,
    is_primary,
    memo,
    raw_payload,
    source_table
  )
  SELECT
    'SKU'::text,
    fp.sku_id,
    'coupang_product_no'::text,
    fp.channel_product_code,
    'channel_product_code'::text,
    false,
    'dryrun only: Coupang unique evidence candidates v1'::text,
    jsonb_build_object(
      'dryrun', true,
      'source', 'product_code_stage.channel_option_evidence',
      'source_system', fp.source_system,
      'source_row_no', fp.source_row_no,
      'source_option_line_no', fp.source_option_line_no,
      'evidence_id', fp.evidence_id,
      'selfpia_sku_candidate', fp.selfpia_sku_candidate,
      'risk_keyword', rc.has_risk_keyword
    ),
    'channel_option_evidence'::text
  FROM final_planned AS fp
  JOIN risk_classified AS rc
    ON rc.evidence_id = fp.evidence_id
  WHERE (SELECT ok FROM guard)
    AND fp.channel_product_code IS NOT NULL
  RETURNING id
),
option_alias_insert AS (
  INSERT INTO product_code.code_alias (
    target_type,
    target_id,
    code_system,
    code_value,
    usage_type,
    is_primary,
    memo,
    raw_payload,
    source_table
  )
  SELECT
    'SKU'::text,
    fp.sku_id,
    'coupang_option_no'::text,
    fp.channel_option_code,
    'channel_option_code'::text,
    false,
    'dryrun only: Coupang unique evidence candidates v1'::text,
    jsonb_build_object(
      'dryrun', true,
      'source', 'product_code_stage.channel_option_evidence',
      'source_system', fp.source_system,
      'source_row_no', fp.source_row_no,
      'source_option_line_no', fp.source_option_line_no,
      'evidence_id', fp.evidence_id,
      'channel_product_code', fp.channel_product_code,
      'selfpia_sku_candidate', fp.selfpia_sku_candidate,
      'risk_keyword', rc.has_risk_keyword
    ),
    'channel_option_evidence'::text
  FROM final_planned AS fp
  JOIN risk_classified AS rc
    ON rc.evidence_id = fp.evidence_id
  WHERE (SELECT ok FROM guard)
    AND fp.channel_option_code IS NOT NULL
  RETURNING id
)
SELECT
  'dryrun_summary'::text AS section,
  (SELECT ok FROM guard) AS guard_ok,
  (SELECT coupang_code_alias_before_count FROM before_counts) AS coupang_code_alias_before_count,
  (SELECT coupang_sku_channel_mapping_before_count FROM before_counts) AS coupang_sku_channel_mapping_before_count,
  (SELECT COUNT(*) FROM e)::bigint AS coupang_evidence_total,
  (SELECT COUNT(*) FROM clean_unique)::bigint AS coupang_unique_candidate_count,
  (SELECT COUNT(*) FROM matched WHERE warning_excluded)::bigint AS warning_excluded_count,
  (SELECT COUNT(*) FROM matched WHERE duplicate_sku_excluded)::bigint AS duplicate_sku_excluded_count,
  (SELECT COUNT(*) FROM matched WHERE inactive_excluded)::bigint AS inactive_excluded_count,
  (SELECT COUNT(*) FROM matched WHERE evidence_missing_excluded)::bigint AS evidence_missing_excluded_count,
  0::bigint AS skipped_existing_confirmed_count,
  0::bigint AS skipped_existing_manual_count,
  (SELECT COUNT(*) FROM matched WHERE existing_alias_excluded)::bigint AS existing_alias_excluded_count,
  (SELECT COUNT(*) FROM matched WHERE existing_mapping_excluded)::bigint AS existing_mapping_excluded_count,
  (SELECT COUNT(*) FROM duplicate_coupang_code)::bigint AS duplicate_coupang_code_count,
  (SELECT COUNT(*) FROM duplicate_selfpia_to_coupang)::bigint AS duplicate_selfpia_to_coupang_count,
  (SELECT COUNT(*) FROM semantic_warning)::bigint AS semantic_warning_count,
  (SELECT COUNT(*) FROM risk_classified WHERE has_risk_keyword)::bigint AS risk_keyword_count,
  (SELECT COUNT(*) FROM final_planned)::bigint AS final_planned_candidate_count,
  (SELECT COUNT(*) FROM product_alias_insert)::bigint AS dryrun_inserted_product_alias_count,
  (SELECT COUNT(*) FROM option_alias_insert)::bigint AS dryrun_inserted_option_alias_count,
  0::bigint AS dryrun_inserted_sku_channel_mapping_count,
  CASE
    WHEN (SELECT ok FROM guard)
     AND (SELECT coupang_code_alias_before_count FROM before_counts) = 0
     AND (SELECT coupang_sku_channel_mapping_before_count FROM before_counts) = 0
     AND (SELECT COUNT(*) FROM e) = 1283
     AND (SELECT COUNT(*) FROM clean_unique) = 565
     AND (SELECT COUNT(*) FROM final_planned) = 565
     AND (SELECT COUNT(*) FROM duplicate_coupang_code) = 0
     AND (SELECT COUNT(*) FROM duplicate_selfpia_to_coupang) = 0
     AND (SELECT COUNT(*) FROM semantic_warning) = 0
     AND (SELECT COUNT(*) FROM product_alias_insert) = 565
    THEN 'PASS_WITH_RISK_REVIEW'
    ELSE 'NEEDS_REVIEW'
  END AS overall_verdict;

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
final_planned AS MATERIALIZED (
  SELECT DISTINCT ON (channel_product_code, sku_id)
    *
  FROM clean_unique
  ORDER BY channel_product_code, sku_id, evidence_id
),
risk_classified AS MATERIALIZED (
  SELECT
    fp.*,
    (
      fp.review_text ~ '(크리스탈|크리스탈AB|크리AB|화이트골드|실버|골드|로즈골드|핑크골드|세트|수량)'
      OR fp.review_text ~ '(^|[^A-Za-z0-9가-힣])AB([^A-Za-z0-9가-힣]|$)'
      OR fp.review_text ~ '1\+1'
    ) AS has_risk_keyword
  FROM final_planned AS fp
),
samples AS (
  SELECT
    'final_planned_sample'::text AS section,
    row_number() OVER (ORDER BY channel_product_code, sku_id)::integer AS sample_rank,
    to_jsonb(s) AS payload
  FROM (
    SELECT evidence_id, channel_product_code, channel_option_code, sku_id, selfpia_sku_candidate, product_name, option_value, source_row_no
    FROM final_planned
    ORDER BY channel_product_code, sku_id
    LIMIT 100
  ) AS s
  UNION ALL
  SELECT
    'risk_keyword_sample',
    row_number() OVER (ORDER BY channel_product_code, sku_id)::integer,
    to_jsonb(s)
  FROM (
    SELECT evidence_id, channel_product_code, channel_option_code, sku_id, selfpia_sku_candidate, product_name, option_value, review_text
    FROM risk_classified
    WHERE has_risk_keyword
    ORDER BY channel_product_code, sku_id
    LIMIT 100
  ) AS s
  UNION ALL
  SELECT
    'duplicate_excluded_sample',
    row_number() OVER (ORDER BY channel_product_code, sku_id NULLS LAST)::integer,
    to_jsonb(s)
  FROM (
    SELECT evidence_id, channel_product_code, sku_id, channel_sku_code, selfpia_sku_candidate, product_name, option_value
    FROM matched
    WHERE duplicate_sku_excluded
    ORDER BY channel_product_code, evidence_id
    LIMIT 50
  ) AS s
  UNION ALL
  SELECT
    'evidence_missing_sample',
    row_number() OVER (ORDER BY channel_product_code, evidence_id)::integer,
    to_jsonb(s)
  FROM (
    SELECT evidence_id, channel_product_code, sku_id, channel_sku_code, selfpia_sku_candidate, product_name, option_value
    FROM matched
    WHERE evidence_missing_excluded
    ORDER BY channel_product_code, evidence_id
    LIMIT 50
  ) AS s
  UNION ALL
  SELECT
    'inactive_sample',
    row_number() OVER (ORDER BY channel_product_code, evidence_id)::integer,
    to_jsonb(s)
  FROM (
    SELECT evidence_id, channel_product_code, sku_id, channel_sku_code, selfpia_sku_candidate, product_name, option_value, sale_status_raw, option_status_raw
    FROM matched
    WHERE inactive_excluded
    ORDER BY channel_product_code, evidence_id
    LIMIT 50
  ) AS s
)
SELECT *
FROM samples
ORDER BY section, sample_rank;

ROLLBACK;

SELECT
  'rollback_after_check'::text AS section,
  (SELECT COUNT(*) FROM product_code.code_alias WHERE code_system IN ('coupang_product_no', 'coupang_option_no'))::bigint AS rollback_after_code_alias_count,
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE lower(channel_code) = 'coupang')::bigint AS rollback_after_sku_channel_mapping_count,
  CASE
    WHEN (SELECT COUNT(*) FROM product_code.code_alias WHERE code_system IN ('coupang_product_no', 'coupang_option_no')) = 0
     AND (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE lower(channel_code) = 'coupang') = 0
    THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS rollback_verdict,
  CASE
    WHEN (SELECT COUNT(*) FROM product_code.code_alias WHERE code_system IN ('coupang_product_no', 'coupang_option_no')) = 0
     AND (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE lower(channel_code) = 'coupang') = 0
    THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS overall_verdict;
