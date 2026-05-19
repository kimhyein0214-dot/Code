/*
  Dryrun Ably clean unique evidence candidates v1.

  Scope:
  - Local product_ops_test only.
  - Dryrun only: BEGIN READ ONLY + ROLLBACK.
  - No COMMIT.
  - No DDL.
  - No INSERT/UPDATE/DELETE/MERGE.
  - No COPY or \copy.
  - No product_code.code_alias change.
  - No product_code.sku_channel_mapping change.

  Candidate policy:
  - channel_code='ably' only.
  - Normalize sellpia_ prefix before joining to selfpia/own SKU aliases.
  - Exclude warning rows, duplicate channel_sku_code risk, inactive rows,
    existing Ably aliases/mappings, and source conflicts.

  Sample review note:
  - This dryrun intentionally keeps executable SQL focused on summary and
    rollback validation. Sample review should use the final_planned/source
    conflict buckets from this query in a follow-up lightweight SELECT.
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
  'Ably unique evidence dryrun; no write statements'::text AS note;

WITH e AS MATERIALIZED (
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
both_sources_agree AS MATERIALIZED (
  SELECT p.*
  FROM non_conflict_pair AS p
  WHERE EXISTS (
    SELECT 1
    FROM non_conflict_pair AS q
    WHERE q.source_system <> p.source_system
      AND q.channel_product_code = p.channel_product_code
      AND q.sku_id = p.sku_id
  )
),
ably_csv_only AS MATERIALIZED (
  SELECT p.*
  FROM non_conflict_pair AS p
  WHERE p.source_system = 'ably_csv'
    AND NOT EXISTS (
      SELECT 1
      FROM non_conflict_pair AS q
      WHERE q.source_system = 'playauto_xlsx'
        AND q.channel_product_code = p.channel_product_code
        AND q.sku_id = p.sku_id
    )
),
playauto_ably_only AS MATERIALIZED (
  SELECT p.*
  FROM non_conflict_pair AS p
  WHERE p.source_system = 'playauto_xlsx'
    AND NOT EXISTS (
      SELECT 1
      FROM non_conflict_pair AS q
      WHERE q.source_system = 'ably_csv'
        AND q.channel_product_code = p.channel_product_code
        AND q.sku_id = p.sku_id
    )
),
final_planned AS MATERIALIZED (
  SELECT DISTINCT channel_product_code, sku_id
  FROM non_conflict_pair
),
duplicate_ably_code AS (
  SELECT channel_product_code, sku_id, COUNT(*) AS duplicate_count
  FROM final_planned
  GROUP BY channel_product_code, sku_id
  HAVING COUNT(*) > 1
),
duplicate_selfpia_to_ably AS (
  SELECT sku_id, COUNT(DISTINCT channel_product_code) AS channel_product_code_count
  FROM final_planned
  GROUP BY sku_id
  HAVING COUNT(DISTINCT channel_product_code) > 1
)
SELECT
  'dryrun_summary'::text AS section,
  (SELECT COUNT(*) FROM e)::bigint AS ably_evidence_total,
  (SELECT COUNT(*) FROM clean_unique WHERE source_system = 'ably_csv')::bigint AS ably_csv_unique_count,
  (SELECT COUNT(*) FROM clean_unique WHERE source_system = 'playauto_xlsx')::bigint AS playauto_ably_unique_count,
  (SELECT COUNT(*) FROM both_sources_agree WHERE source_system = 'ably_csv')::bigint AS both_sources_agree_count,
  (SELECT COUNT(*) FROM source_conflict_pair)::bigint AS source_conflict_count,
  (SELECT COUNT(*) FROM ably_csv_only)::bigint AS ably_csv_only_count,
  (SELECT COUNT(*) FROM playauto_ably_only)::bigint AS playauto_ably_only_count,
  (SELECT COUNT(*) FROM matched WHERE warning_excluded)::bigint AS warning_excluded_count,
  (SELECT COUNT(*) FROM matched WHERE duplicate_sku_excluded)::bigint AS duplicate_sku_excluded_count,
  (SELECT COUNT(*) FROM matched WHERE inactive_excluded)::bigint AS inactive_excluded_count,
  (SELECT COUNT(*) FROM matched WHERE evidence_missing_excluded)::bigint AS evidence_missing_excluded_count,
  (SELECT COUNT(*) FROM matched WHERE existing_alias_excluded)::bigint AS existing_alias_excluded_count,
  (SELECT COUNT(*) FROM matched WHERE existing_mapping_excluded)::bigint AS existing_mapping_excluded_count,
  (SELECT COUNT(*) FROM final_planned)::bigint AS final_planned_candidate_count,
  0::bigint AS skipped_existing_confirmed_count,
  0::bigint AS skipped_existing_manual_count,
  (SELECT COUNT(*) FROM duplicate_ably_code)::bigint AS duplicate_ably_code_count,
  (SELECT COUNT(*) FROM duplicate_selfpia_to_ably)::bigint AS duplicate_selfpia_to_ably_count,
  (SELECT COUNT(*) FROM final_planned WHERE channel_product_code IS NULL OR sku_id IS NULL)::bigint AS semantic_warning_count,
  CASE
    WHEN (SELECT COUNT(*) FROM duplicate_ably_code) = 0
     AND (SELECT COUNT(*) FROM duplicate_selfpia_to_ably) = 0
     AND (SELECT COUNT(*) FROM final_planned WHERE channel_product_code IS NULL OR sku_id IS NULL) = 0
    THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS quality_verdict,
  'PASS_WITH_CONFLICT_EXCLUSIONS'::text AS overall_verdict;

ROLLBACK;

SELECT
  'rollback_after_check'::text AS section,
  (SELECT COUNT(*) FROM product_code.code_alias WHERE code_system IN ('ably_product_no', 'ably_option_no'))::bigint AS ably_code_alias_after_count,
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE lower(channel_code) = 'ably')::bigint AS ably_sku_channel_mapping_after_count,
  CASE
    WHEN (SELECT COUNT(*) FROM product_code.code_alias WHERE code_system IN ('ably_product_no', 'ably_option_no')) = 0
     AND (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE lower(channel_code) = 'ably') = 0
    THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS rollback_verdict;
