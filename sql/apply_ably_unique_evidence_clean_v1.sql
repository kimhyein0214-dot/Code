/*
  Apply Ably clean unique evidence v1.

  Scope:
  - Local product_ops_test only.
  - Applies only 2,273 clean Ably candidates.
  - Inserts product_code.code_alias rows only.
  - Does not insert into product_code.sku_channel_mapping.
  - No DDL.
  - No COPY or \copy.
  - No source file import.

  Safety:
  - Fails before COMMIT if the exact precheck and insert counts are not met.
  - Fails if any existing Ably alias or Ably sku_channel_mapping row exists.
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
  'Ably clean unique evidence local apply'::text AS note;

WITH guard AS MATERIALIZED (
  SELECT
    current_database() = 'product_ops_test'
    AND current_user = 'product_ops_tester' AS ok
),
before_counts AS MATERIALIZED (
  SELECT
    (SELECT COUNT(*) FROM product_code.code_alias WHERE code_system IN ('ably_product_no', 'ably_option_no'))::bigint AS ably_code_alias_before_count,
    (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE lower(channel_code) = 'ably')::bigint AS ably_sku_channel_mapping_before_count
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
    (am.sku_id IS NULL OR am.sku_id_count <> 1) AS evidence_missing_excluded,
    EXISTS (
      SELECT 1
      FROM product_code.code_alias AS ca
      WHERE ca.target_type = 'SKU'
        AND ca.code_system IN ('ably_product_no', 'ably_option_no')
        AND ca.code_value IN (e.channel_product_code, e.channel_option_code)
    ) AS existing_alias_excluded,
    EXISTS (
      SELECT 1
      FROM product_code.sku_channel_mapping AS scm
      WHERE lower(scm.channel_code) = 'ably'
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
    cu.sale_status_raw,
    cu.display_status_raw,
    cu.option_status_raw,
    cu.warning_excluded,
    cu.duplicate_sku_excluded,
    cu.inactive_excluded,
    cu.evidence_missing_excluded,
    cu.existing_alias_excluded,
    cu.existing_mapping_excluded,
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
duplicate_ably_code AS MATERIALIZED (
  SELECT channel_product_code, sku_id, COUNT(*) AS duplicate_count
  FROM final_clean_planned
  GROUP BY channel_product_code, sku_id
  HAVING COUNT(*) > 1
),
duplicate_selfpia_to_ably AS MATERIALIZED (
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
source_conflict_remaining AS MATERIALIZED (
  SELECT fcp.*
  FROM final_clean_planned AS fcp
  JOIN source_conflict_pair AS scp
    ON scp.channel_product_code = fcp.channel_product_code
   AND scp.sku_id = fcp.sku_id
),
warning_remaining AS MATERIALIZED (
  SELECT *
  FROM final_clean_planned
  WHERE warning_excluded
),
duplicate_sku_remaining AS MATERIALIZED (
  SELECT *
  FROM final_clean_planned
  WHERE duplicate_sku_excluded
),
inactive_remaining AS MATERIALIZED (
  SELECT *
  FROM final_clean_planned
  WHERE inactive_excluded
),
precheck AS MATERIALIZED (
  SELECT
    (SELECT ok FROM guard) AS guard_ok,
    (SELECT ably_code_alias_before_count FROM before_counts) AS ably_code_alias_before_count,
    (SELECT ably_sku_channel_mapping_before_count FROM before_counts) AS ably_sku_channel_mapping_before_count,
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
    (SELECT COUNT(*) FROM duplicate_ably_code)::bigint AS duplicate_ably_code_count,
    (SELECT COUNT(*) FROM duplicate_selfpia_to_ably)::bigint AS duplicate_selfpia_to_ably_count,
    (SELECT COUNT(*) FROM semantic_warning)::bigint AS semantic_warning_count,
    (SELECT COUNT(*) FROM narrow_risk_remaining)::bigint AS narrow_risk_remaining_count,
    (SELECT COUNT(*) FROM source_conflict_remaining)::bigint AS source_conflict_remaining_count,
    (SELECT COUNT(*) FROM warning_remaining)::bigint AS warning_remaining_count,
    (SELECT COUNT(*) FROM duplicate_sku_remaining)::bigint AS duplicate_sku_remaining_count,
    (SELECT COUNT(*) FROM inactive_remaining)::bigint AS inactive_remaining_count
),
precheck_verdict AS MATERIALIZED (
  SELECT
    *,
    (
      guard_ok
      AND ably_code_alias_before_count = 0
      AND ably_sku_channel_mapping_before_count = 0
      AND source_final_planned_count = 3024
      AND narrow_risk_excluded_count = 751
      AND final_clean_planned_count = 2273
      AND planned_product_alias_count = 2273
      AND planned_option_alias_count = 561
      AND planned_sku_channel_mapping_count = 0
      AND skipped_existing_confirmed_count = 0
      AND skipped_existing_manual_count = 0
      AND existing_alias_excluded_count = 0
      AND existing_mapping_excluded_count = 0
      AND duplicate_ably_code_count = 0
      AND duplicate_selfpia_to_ably_count = 0
      AND semantic_warning_count = 0
      AND narrow_risk_remaining_count = 0
      AND source_conflict_remaining_count = 0
      AND warning_remaining_count = 0
      AND duplicate_sku_remaining_count = 0
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
    'ably_product_no'::text,
    fcp.channel_product_code,
    'channel_product_code'::text,
    false,
    'local apply: Ably clean unique evidence v1'::text,
    jsonb_build_object(
      'apply_version', 'ably_unique_evidence_clean_v1',
      'apply_txid', txid_current()::text,
      'source', 'product_code_stage.channel_option_evidence',
      'source_system', fcp.source_system,
      'source_row_no', fcp.source_row_no,
      'evidence_id', fcp.evidence_id,
      'selfpia_sku_candidate', fcp.selfpia_sku_candidate,
      'narrow_risk_excluded', false
    ),
    'channel_option_evidence'::text
  FROM final_clean_planned AS fcp
  WHERE (SELECT ok FROM precheck_verdict)
    AND fcp.channel_product_code IS NOT NULL
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
    fcp.sku_id,
    'ably_option_no'::text,
    fcp.channel_option_code,
    'channel_option_code'::text,
    false,
    'local apply: Ably clean unique evidence v1'::text,
    jsonb_build_object(
      'apply_version', 'ably_unique_evidence_clean_v1',
      'apply_txid', txid_current()::text,
      'source', 'product_code_stage.channel_option_evidence',
      'source_system', fcp.source_system,
      'source_row_no', fcp.source_row_no,
      'source_option_line_no', fcp.source_option_line_no,
      'evidence_id', fcp.evidence_id,
      'channel_product_code', fcp.channel_product_code,
      'selfpia_sku_candidate', fcp.selfpia_sku_candidate,
      'narrow_risk_excluded', false
    ),
    'channel_option_evidence'::text
  FROM final_clean_planned AS fcp
  WHERE (SELECT ok FROM precheck_verdict)
    AND fcp.channel_option_code IS NOT NULL
  RETURNING id
)
SELECT
  'apply_summary'::text AS section,
  (SELECT guard_ok FROM precheck_verdict) AS guard_ok,
  (SELECT ok FROM precheck_verdict) AS precheck_ok,
  (SELECT ably_code_alias_before_count FROM precheck_verdict) AS ably_code_alias_before_count,
  (SELECT ably_sku_channel_mapping_before_count FROM precheck_verdict) AS ably_sku_channel_mapping_before_count,
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
  (SELECT duplicate_ably_code_count FROM precheck_verdict) AS duplicate_ably_code_count,
  (SELECT duplicate_selfpia_to_ably_count FROM precheck_verdict) AS duplicate_selfpia_to_ably_count,
  (SELECT semantic_warning_count FROM precheck_verdict) AS semantic_warning_count,
  (SELECT narrow_risk_remaining_count FROM precheck_verdict) AS narrow_risk_remaining_count,
  (SELECT source_conflict_remaining_count FROM precheck_verdict) AS source_conflict_remaining_count,
  (SELECT warning_remaining_count FROM precheck_verdict) AS warning_remaining_count,
  (SELECT duplicate_sku_remaining_count FROM precheck_verdict) AS duplicate_sku_remaining_count,
  (SELECT inactive_remaining_count FROM precheck_verdict) AS inactive_remaining_count,
  (SELECT COUNT(*) FROM product_alias_insert)::bigint AS inserted_product_alias_count,
  (SELECT COUNT(*) FROM option_alias_insert)::bigint AS inserted_option_alias_count,
  ((SELECT COUNT(*) FROM product_alias_insert) + (SELECT COUNT(*) FROM option_alias_insert))::bigint AS total_inserted_code_alias_count,
  0::bigint AS inserted_sku_channel_mapping_count,
  CASE
    WHEN (SELECT ok FROM precheck_verdict)
     AND (SELECT COUNT(*) FROM product_alias_insert) = 2273
     AND (SELECT COUNT(*) FROM option_alias_insert) = 561
    THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS apply_insert_verdict;

SELECT
  'commit_guard'::text AS section,
  1 / CASE
    WHEN current_database() = 'product_ops_test'
     AND current_user = 'product_ops_tester'
     AND (SELECT COUNT(*) FROM product_code.code_alias WHERE raw_payload->>'apply_version' = 'ably_unique_evidence_clean_v1' AND raw_payload->>'apply_txid' = txid_current()::text AND code_system = 'ably_product_no') = 2273
     AND (SELECT COUNT(*) FROM product_code.code_alias WHERE raw_payload->>'apply_version' = 'ably_unique_evidence_clean_v1' AND raw_payload->>'apply_txid' = txid_current()::text AND code_system = 'ably_option_no') = 561
     AND (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE lower(channel_code) = 'ably') = 0
    THEN 1
    ELSE 0
  END AS must_be_one,
  'PASS'::text AS commit_guard_verdict;

COMMIT;
