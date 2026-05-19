/*
  Apply Coupang clean unique evidence v1.

  Scope:
  - Local product_ops_test only.
  - Applies only 539 clean Coupang candidates.
  - Inserts product_code.code_alias rows only.
  - Does not insert coupang_option_no.
  - Does not insert into product_code.sku_channel_mapping.
  - No DDL.
  - No COPY or \copy.
  - No source file import.

  Safety:
  - Fails before COMMIT if the exact precheck and insert counts are not met.
  - Fails if any existing Coupang alias or Coupang sku_channel_mapping row exists.
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
  txid_current()::text AS apply_txid,
  CASE WHEN (SELECT ok FROM guard) THEN 'PASS' ELSE 'STOP' END AS guard_result,
  'Coupang clean unique evidence local apply'::text AS note;

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
    (sfp.review_text ~ '(크리스탈AB|크리AB)') AS has_crystal_ab,
    (sfp.review_text ~ '(^|[^A-Za-z0-9가-힣])AB([^A-Za-z0-9가-힣]|$)') AS has_standalone_ab,
    (sfp.review_text ~ '(세트|SET|set|Set|수량)') AS has_set_or_quantity,
    (sfp.review_text ~ '1\+1') AS has_one_plus_one,
    (pcp.has_crystal_ab AND pcp.has_crystal_plain) AS has_crystal_vs_crystal_ab_conflict,
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
duplicate_coupang_code AS MATERIALIZED (
  SELECT channel_product_code, sku_id, COUNT(*) AS duplicate_count
  FROM final_clean_planned
  GROUP BY channel_product_code, sku_id
  HAVING COUNT(*) > 1
),
duplicate_selfpia_to_coupang AS MATERIALIZED (
  SELECT sku_id, COUNT(DISTINCT channel_product_code) AS channel_product_code_count
  FROM final_clean_planned
  GROUP BY sku_id
  HAVING COUNT(DISTINCT channel_product_code) > 1
),
semantic_warning AS MATERIALIZED (
  SELECT *
  FROM final_clean_planned
  WHERE channel_product_code IS NULL
     OR sku_id IS NULL
     OR normalized_selfpia_key IS NULL
),
narrow_risk_remaining AS MATERIALIZED (
  SELECT *
  FROM final_clean_planned
  WHERE has_narrow_risk
),
warning_remaining AS MATERIALIZED (
  SELECT *
  FROM final_clean_planned
  WHERE warning_excluded
),
inactive_remaining AS MATERIALIZED (
  SELECT *
  FROM final_clean_planned
  WHERE inactive_excluded
),
precheck AS MATERIALIZED (
  SELECT
    (SELECT ok FROM guard) AS guard_ok,
    (SELECT coupang_code_alias_before_count FROM before_counts) AS coupang_code_alias_before_count,
    (SELECT coupang_sku_channel_mapping_before_count FROM before_counts) AS coupang_sku_channel_mapping_before_count,
    (SELECT COUNT(*) FROM source_final_planned)::bigint AS source_final_planned_count,
    (SELECT COUNT(*) FROM classified WHERE has_narrow_risk)::bigint AS narrow_risk_excluded_count,
    (SELECT COUNT(*) FROM final_clean_planned)::bigint AS final_clean_planned_count,
    (SELECT COUNT(*) FROM final_clean_planned WHERE channel_product_code IS NOT NULL)::bigint AS planned_product_alias_count,
    (SELECT COUNT(*) FROM final_clean_planned WHERE channel_option_code IS NOT NULL)::bigint AS planned_option_alias_count,
    0::bigint AS planned_sku_channel_mapping_count,
    0::bigint AS skipped_existing_confirmed_count,
    0::bigint AS skipped_existing_manual_count,
    (SELECT COUNT(*) FROM matched WHERE existing_alias_excluded)::bigint AS existing_alias_excluded_count,
    (SELECT COUNT(*) FROM matched WHERE existing_mapping_excluded)::bigint AS existing_mapping_excluded_count,
    (SELECT COUNT(*) FROM duplicate_coupang_code)::bigint AS duplicate_coupang_code_count,
    (SELECT COUNT(*) FROM duplicate_selfpia_to_coupang)::bigint AS duplicate_selfpia_to_coupang_count,
    (SELECT COUNT(*) FROM semantic_warning)::bigint AS semantic_warning_count,
    (SELECT COUNT(*) FROM narrow_risk_remaining)::bigint AS narrow_risk_remaining_count,
    (SELECT COUNT(*) FROM warning_remaining)::bigint AS warning_remaining_count,
    (SELECT COUNT(*) FROM inactive_remaining)::bigint AS inactive_remaining_count
),
precheck_verdict AS MATERIALIZED (
  SELECT
    *,
    (
      guard_ok
      AND coupang_code_alias_before_count = 0
      AND coupang_sku_channel_mapping_before_count = 0
      AND source_final_planned_count = 565
      AND narrow_risk_excluded_count = 26
      AND final_clean_planned_count = 539
      AND planned_product_alias_count = 539
      AND planned_option_alias_count = 0
      AND planned_sku_channel_mapping_count = 0
      AND skipped_existing_confirmed_count = 0
      AND skipped_existing_manual_count = 0
      AND existing_alias_excluded_count = 0
      AND existing_mapping_excluded_count = 0
      AND duplicate_coupang_code_count = 0
      AND duplicate_selfpia_to_coupang_count = 0
      AND semantic_warning_count = 0
      AND narrow_risk_remaining_count = 0
      AND warning_remaining_count = 0
      AND inactive_remaining_count = 0
    ) AS ok
  FROM precheck
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
    fcp.sku_id,
    'coupang_product_no'::text,
    fcp.channel_product_code,
    'channel_product_code'::text,
    false,
    'local apply: Coupang clean unique evidence v1'::text,
    jsonb_build_object(
      'apply_version', 'coupang_unique_evidence_clean_v1',
      'apply_txid', txid_current()::text,
      'source', 'product_code_stage.channel_option_evidence',
      'source_system', fcp.source_system,
      'source_row_no', fcp.source_row_no,
      'source_option_line_no', fcp.source_option_line_no,
      'evidence_id', fcp.evidence_id,
      'selfpia_sku_candidate', fcp.selfpia_sku_candidate,
      'narrow_risk_excluded', false
    ),
    'channel_option_evidence'::text
  FROM final_clean_planned AS fcp
  WHERE (SELECT ok FROM precheck_verdict)
    AND fcp.channel_product_code IS NOT NULL
  RETURNING id
)
SELECT
  'apply_summary'::text AS section,
  (SELECT guard_ok FROM precheck_verdict) AS guard_ok,
  (SELECT ok FROM precheck_verdict) AS precheck_ok,
  (SELECT coupang_code_alias_before_count FROM precheck_verdict) AS coupang_code_alias_before_count,
  (SELECT coupang_sku_channel_mapping_before_count FROM precheck_verdict) AS coupang_sku_channel_mapping_before_count,
  (SELECT source_final_planned_count FROM precheck_verdict) AS source_final_planned_count,
  (SELECT narrow_risk_excluded_count FROM precheck_verdict) AS narrow_risk_excluded_count,
  (SELECT final_clean_planned_count FROM precheck_verdict) AS final_clean_planned_count,
  (SELECT planned_product_alias_count FROM precheck_verdict) AS planned_product_alias_count,
  (SELECT planned_option_alias_count FROM precheck_verdict) AS planned_option_alias_count,
  (SELECT planned_sku_channel_mapping_count FROM precheck_verdict) AS planned_sku_channel_mapping_count,
  (SELECT skipped_existing_confirmed_count FROM precheck_verdict) AS skipped_existing_confirmed_count,
  (SELECT skipped_existing_manual_count FROM precheck_verdict) AS skipped_existing_manual_count,
  (SELECT existing_alias_excluded_count FROM precheck_verdict) AS existing_alias_excluded_count,
  (SELECT existing_mapping_excluded_count FROM precheck_verdict) AS existing_mapping_excluded_count,
  (SELECT duplicate_coupang_code_count FROM precheck_verdict) AS duplicate_coupang_code_count,
  (SELECT duplicate_selfpia_to_coupang_count FROM precheck_verdict) AS duplicate_selfpia_to_coupang_count,
  (SELECT semantic_warning_count FROM precheck_verdict) AS semantic_warning_count,
  (SELECT narrow_risk_remaining_count FROM precheck_verdict) AS narrow_risk_remaining_count,
  (SELECT warning_remaining_count FROM precheck_verdict) AS warning_remaining_count,
  (SELECT inactive_remaining_count FROM precheck_verdict) AS inactive_remaining_count,
  (SELECT COUNT(*) FROM product_alias_insert)::bigint AS inserted_product_alias_count,
  0::bigint AS inserted_option_alias_count,
  (SELECT COUNT(*) FROM product_alias_insert)::bigint AS total_inserted_code_alias_count,
  0::bigint AS inserted_sku_channel_mapping_count,
  CASE
    WHEN (SELECT ok FROM precheck_verdict)
     AND (SELECT COUNT(*) FROM product_alias_insert) = 539
    THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS apply_insert_verdict;

SELECT
  'commit_guard'::text AS section,
  1 / CASE
    WHEN current_database() = 'product_ops_test'
     AND current_user = 'product_ops_tester'
     AND (SELECT COUNT(*) FROM product_code.code_alias WHERE raw_payload->>'apply_version' = 'coupang_unique_evidence_clean_v1' AND raw_payload->>'apply_txid' = txid_current()::text AND code_system = 'coupang_product_no') = 539
     AND (SELECT COUNT(*) FROM product_code.code_alias WHERE raw_payload->>'apply_version' = 'coupang_unique_evidence_clean_v1' AND raw_payload->>'apply_txid' = txid_current()::text AND code_system = 'coupang_option_no') = 0
     AND (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE lower(channel_code) = 'coupang') = 0
    THEN 1
    ELSE 0
  END AS must_be_one,
  'PASS'::text AS commit_guard_verdict;

COMMIT;
