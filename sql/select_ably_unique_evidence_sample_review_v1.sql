/*
  Select Ably unique evidence sample review v1.

  Scope:
  - SELECT-only.
  - Local product_ops_test only.
  - No DDL/DML.
  - No INSERT/UPDATE/DELETE/MERGE.
  - No COPY or \copy.
  - No code_alias or sku_channel_mapping mutation.
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
  'Ably sample review; SELECT-only'::text AS note;

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
risk_regex AS (
  SELECT '(크리스탈AB|크리AB|AB|크리스탈|화이트골드|실버|골드|로즈골드|핑크골드|세트|1\+1|수량)'::text AS pattern
),
review_rows AS MATERIALIZED (
  SELECT
    cu.evidence_id,
    cu.source_system,
    cu.source_row_no,
    cu.source_option_line_no,
    cu.channel_product_code,
    cu.channel_option_code,
    cu.channel_sku_code,
    cu.seller_product_code,
    cu.own_sku_code_candidate,
    cu.selfpia_sku_candidate,
    cu.normalized_selfpia_key,
    cu.sku_id,
    cu.product_name,
    cu.option_name,
    cu.option_value,
    cu.sale_status_raw,
    cu.display_status_raw,
    cu.option_status_raw,
    (concat_ws(' ', cu.product_name, cu.option_name, cu.option_value, cu.selfpia_sku_candidate) ~ (SELECT pattern FROM risk_regex)) AS has_risk_keyword,
    substring(concat_ws(' ', cu.product_name, cu.option_name, cu.option_value, cu.selfpia_sku_candidate) from (SELECT pattern FROM risk_regex)) AS risk_keyword_match
  FROM clean_unique AS cu
),
final_sample AS MATERIALIZED (
  SELECT DISTINCT ON (fp.channel_product_code, fp.sku_id) rr.*
  FROM final_planned AS fp
  JOIN review_rows AS rr
    ON rr.channel_product_code = fp.channel_product_code
   AND rr.sku_id = fp.sku_id
  ORDER BY fp.channel_product_code, fp.sku_id, CASE WHEN rr.source_system = 'ably_csv' THEN 0 ELSE 1 END, rr.evidence_id
  LIMIT 100
),
both_sample AS MATERIALIZED (
  SELECT DISTINCT ON (c.channel_product_code, c.sku_id) c.*
  FROM both_sources_agree AS b
  JOIN review_rows AS c
    ON c.source_system = 'ably_csv'
   AND c.channel_product_code = b.channel_product_code
   AND c.sku_id = b.sku_id
  ORDER BY c.channel_product_code, c.sku_id, c.evidence_id
  LIMIT 100
),
csv_only_sample AS MATERIALIZED (
  SELECT DISTINCT ON (rr.channel_product_code, rr.sku_id) rr.*
  FROM ably_csv_only AS b
  JOIN review_rows AS rr
    ON rr.source_system = b.source_system
   AND rr.channel_product_code = b.channel_product_code
   AND rr.sku_id = b.sku_id
  ORDER BY rr.channel_product_code, rr.sku_id, rr.evidence_id
  LIMIT 100
),
playauto_only_sample AS MATERIALIZED (
  SELECT DISTINCT ON (rr.channel_product_code, rr.sku_id) rr.*
  FROM playauto_ably_only AS b
  JOIN review_rows AS rr
    ON rr.source_system = b.source_system
   AND rr.channel_product_code = b.channel_product_code
   AND rr.sku_id = b.sku_id
  ORDER BY rr.channel_product_code, rr.sku_id, rr.evidence_id
  LIMIT 100
),
conflict_sample AS MATERIALIZED (
  SELECT DISTINCT ON (rr.source_system, rr.channel_product_code, rr.sku_id) rr.*
  FROM source_conflict_pair AS b
  JOIN review_rows AS rr
    ON rr.source_system = b.source_system
   AND rr.channel_product_code = b.channel_product_code
   AND rr.sku_id = b.sku_id
  ORDER BY rr.source_system, rr.channel_product_code, rr.sku_id, rr.evidence_id
  LIMIT 100
)
SELECT
  'sample_review_summary'::text AS section,
  NULL::integer AS sample_rank,
  jsonb_build_object(
    'final_planned_count', (SELECT COUNT(*) FROM final_planned),
    'source_conflict_count', (SELECT COUNT(*) FROM source_conflict_pair),
    'both_sources_agree_count', (SELECT COUNT(*) FROM both_sources_agree WHERE source_system = 'ably_csv'),
    'ably_csv_only_count', (SELECT COUNT(*) FROM ably_csv_only),
    'playauto_ably_only_count', (SELECT COUNT(*) FROM playauto_ably_only),
    'warning_excluded_count', (SELECT COUNT(*) FROM matched WHERE warning_excluded),
    'duplicate_sku_excluded_count', (SELECT COUNT(*) FROM matched WHERE duplicate_sku_excluded),
    'inactive_excluded_count', (SELECT COUNT(*) FROM matched WHERE inactive_excluded),
    'evidence_missing_count', (SELECT COUNT(*) FROM matched WHERE evidence_missing_excluded),
    'final_planned_sample_count', (SELECT COUNT(*) FROM final_sample),
    'source_conflict_sample_count', (SELECT COUNT(*) FROM conflict_sample),
    'final_planned_sample_risk_keyword_count', (SELECT COUNT(*) FROM final_sample WHERE has_risk_keyword),
    'final_planned_all_risk_keyword_evidence_count', (
      SELECT COUNT(*)
      FROM review_rows AS rr
      JOIN final_planned AS fp
        ON fp.channel_product_code = rr.channel_product_code
       AND fp.sku_id = rr.sku_id
      WHERE rr.has_risk_keyword
    )
  ) AS payload
UNION ALL
SELECT 'final_planned_sample', row_number() OVER (ORDER BY channel_product_code, sku_id)::integer, to_jsonb(final_sample) FROM final_sample
UNION ALL
SELECT 'both_sources_agree_sample', row_number() OVER (ORDER BY channel_product_code, sku_id)::integer, to_jsonb(both_sample) FROM both_sample
UNION ALL
SELECT 'ably_csv_only_sample', row_number() OVER (ORDER BY channel_product_code, sku_id)::integer, to_jsonb(csv_only_sample) FROM csv_only_sample
UNION ALL
SELECT 'playauto_ably_only_sample', row_number() OVER (ORDER BY channel_product_code, sku_id)::integer, to_jsonb(playauto_only_sample) FROM playauto_only_sample
UNION ALL
SELECT 'source_conflict_sample', row_number() OVER (ORDER BY source_system, channel_product_code, sku_id)::integer, to_jsonb(conflict_sample) FROM conflict_sample
UNION ALL
SELECT 'warning_excluded_sample', row_number() OVER (ORDER BY evidence_id)::integer, to_jsonb(w)
FROM (
  SELECT evidence_id, source_system, source_row_no, source_option_line_no, channel_product_code, channel_option_code, channel_sku_code, seller_product_code, selfpia_sku_candidate, product_name, option_value, parse_warning
  FROM matched
  WHERE warning_excluded
  ORDER BY evidence_id
  LIMIT 50
) AS w
UNION ALL
SELECT 'duplicate_sku_excluded_sample', row_number() OVER (ORDER BY channel_sku_code, evidence_id)::integer, to_jsonb(d)
FROM (
  SELECT evidence_id, source_system, source_row_no, source_option_line_no, channel_product_code, channel_option_code, channel_sku_code, seller_product_code, selfpia_sku_candidate, product_name, option_value
  FROM matched
  WHERE duplicate_sku_excluded
  ORDER BY channel_sku_code, evidence_id
  LIMIT 50
) AS d
UNION ALL
SELECT 'inactive_excluded_sample', row_number() OVER (ORDER BY evidence_id)::integer, to_jsonb(i)
FROM (
  SELECT evidence_id, source_system, source_row_no, source_option_line_no, channel_product_code, channel_option_code, channel_sku_code, seller_product_code, selfpia_sku_candidate, product_name, option_value, sale_status_raw, display_status_raw, option_status_raw
  FROM matched
  WHERE inactive_excluded
  ORDER BY evidence_id
  LIMIT 50
) AS i
UNION ALL
SELECT 'evidence_missing_sample', row_number() OVER (ORDER BY evidence_id)::integer, to_jsonb(m)
FROM (
  SELECT evidence_id, source_system, source_row_no, source_option_line_no, channel_product_code, channel_option_code, channel_sku_code, seller_product_code, selfpia_sku_candidate, product_name, option_value
  FROM matched
  WHERE evidence_missing_excluded
  ORDER BY evidence_id
  LIMIT 50
) AS m
ORDER BY section, sample_rank NULLS FIRST;

ROLLBACK;
