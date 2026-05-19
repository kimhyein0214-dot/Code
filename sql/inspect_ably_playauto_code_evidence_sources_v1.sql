/*
  Ably / PlayAuto code evidence source inspection.

  Purpose:
  - Inspect whether local DB already contains Ably or PlayAuto product/option/code evidence.
  - Discover exact channel_code / code_system values.
  - Estimate whether selfpia_sku / own_sku based auto-match candidates can be built.

  Safety:
  - SELECT-only.
  - Read-only summary/sample output.
  - No apply SQL.
  - No file output.
  - No import/export.
  - No stage relation.
  - export_allowed remains false.
  - reviewer_decision remains pending.
*/

SELECT
  'guard'::text AS section,
  current_database() AS current_database,
  current_user AS current_user,
  current_setting('transaction_read_only') AS transaction_read_only,
  CASE
    WHEN current_database() = 'product_ops_test'
      THEN 'PASS: local product_ops_test database'
    ELSE 'STOP: not product_ops_test'
  END AS database_guard,
  'Run inside BEGIN READ ONLY and end with ROLLBACK.'::text AS note;

WITH possible_columns AS (
  SELECT
    c.table_schema,
    c.table_name,
    c.column_name,
    c.data_type,
    c.ordinal_position
  FROM information_schema.columns AS c
  WHERE c.table_schema = 'product_code'
    AND (
      lower(c.table_name) ~ '(ably|a_bly|a-bly|playauto|play_auto|play-auto|channel|mapping|alias)'
      OR lower(c.column_name) ~ '(ably|a_bly|a-bly|playauto|play_auto|play-auto|channel|seller|product|product_no|productno|goods|goodsno|option|option_no|optionno|code|sku|own|selfpia)'
    )
)
SELECT
  'catalog_candidate_column'::text AS section,
  table_schema,
  table_name,
  column_name,
  data_type,
  NULL::text AS channel_group,
  NULL::text AS channel_code,
  NULL::bigint AS row_count,
  NULL::bigint AS non_null_count,
  NULL::bigint AS distinct_count,
  'Possible Ably/PlayAuto/code evidence column from information_schema.'::text AS note
FROM possible_columns
ORDER BY table_schema, table_name, ordinal_position;

WITH channel_distribution AS (
  SELECT
    lower(COALESCE(channel_code, '')) AS channel_code,
    CASE
      WHEN lower(COALESCE(channel_code, '')) ~ '(^|[^a-z0-9])a[-_ ]?bly([^a-z0-9]|$)'
        OR lower(COALESCE(channel_code, '')) LIKE '%ably%'
      THEN 'ably'
      WHEN lower(COALESCE(channel_code, '')) LIKE '%playauto%'
        OR lower(COALESCE(channel_code, '')) LIKE '%play_auto%'
        OR lower(COALESCE(channel_code, '')) LIKE '%play-auto%'
        OR lower(COALESCE(channel_code, '')) LIKE '%play auto%'
      THEN 'playauto'
      ELSE 'other'
    END AS channel_group,
    COUNT(*) AS row_count,
    COUNT(DISTINCT sku_id) AS distinct_sku_id_count,
    COUNT(seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(seller_product_code, '')), '') IS NOT NULL
    ) AS seller_product_code_non_null_count,
    COUNT(DISTINCT seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(seller_product_code, '')), '') IS NOT NULL
    ) AS seller_product_code_distinct_count,
    COUNT(channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(channel_sku_code, '')), '') IS NOT NULL
    ) AS channel_sku_code_non_null_count,
    COUNT(DISTINCT channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(channel_sku_code, '')), '') IS NOT NULL
    ) AS channel_sku_code_distinct_count,
    COUNT(own_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(own_sku_code, '')), '') IS NOT NULL
    ) AS own_sku_code_non_null_count,
    COUNT(DISTINCT own_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(own_sku_code, '')), '') IS NOT NULL
    ) AS own_sku_code_distinct_count
  FROM product_code.sku_channel_mapping
  GROUP BY lower(COALESCE(channel_code, ''))
)
SELECT
  'sku_channel_mapping_channel_distribution'::text AS section,
  'product_code'::text AS table_schema,
  'sku_channel_mapping'::text AS table_name,
  'channel_code'::text AS column_name,
  NULL::text AS data_type,
  channel_group,
  channel_code,
  row_count::bigint,
  distinct_sku_id_count::bigint AS non_null_count,
  seller_product_code_distinct_count::bigint AS distinct_count,
  concat(
    'sku_id_distinct=', distinct_sku_id_count,
    '; seller_product_non_null=', seller_product_code_non_null_count,
    '; seller_product_distinct=', seller_product_code_distinct_count,
    '; channel_sku_non_null=', channel_sku_code_non_null_count,
    '; channel_sku_distinct=', channel_sku_code_distinct_count,
    '; own_sku_non_null=', own_sku_code_non_null_count,
    '; own_sku_distinct=', own_sku_code_distinct_count
  ) AS note
FROM channel_distribution
WHERE channel_group IN ('ably', 'playauto')
   OR channel_code LIKE '%ably%'
   OR channel_code LIKE '%play%'
ORDER BY channel_group, channel_code;

WITH code_alias_distribution AS (
  SELECT
    ca.code_system,
    CASE
      WHEN lower(COALESCE(ca.code_system, '')) LIKE '%ably%'
        OR lower(COALESCE(ca.code_system, '')) LIKE '%a_bly%'
        OR lower(COALESCE(ca.code_system, '')) LIKE '%a-bly%'
      THEN 'ably'
      WHEN lower(COALESCE(ca.code_system, '')) LIKE '%playauto%'
        OR lower(COALESCE(ca.code_system, '')) LIKE '%play_auto%'
        OR lower(COALESCE(ca.code_system, '')) LIKE '%play-auto%'
      THEN 'playauto'
      ELSE 'other'
    END AS channel_group,
    COUNT(*) AS row_count,
    COUNT(ca.code_value) FILTER (
      WHERE NULLIF(btrim(COALESCE(ca.code_value, '')), '') IS NOT NULL
    ) AS code_value_non_null_count,
    COUNT(DISTINCT ca.code_value) FILTER (
      WHERE NULLIF(btrim(COALESCE(ca.code_value, '')), '') IS NOT NULL
    ) AS code_value_distinct_count,
    COUNT(DISTINCT ca.target_id) AS distinct_target_id_count
  FROM product_code.code_alias AS ca
  WHERE lower(COALESCE(ca.code_system, '')) LIKE '%ably%'
     OR lower(COALESCE(ca.code_system, '')) LIKE '%a_bly%'
     OR lower(COALESCE(ca.code_system, '')) LIKE '%a-bly%'
     OR lower(COALESCE(ca.code_system, '')) LIKE '%playauto%'
     OR lower(COALESCE(ca.code_system, '')) LIKE '%play_auto%'
     OR lower(COALESCE(ca.code_system, '')) LIKE '%play-auto%'
  GROUP BY ca.code_system
)
SELECT
  'code_alias_code_system_distribution'::text AS section,
  'product_code'::text AS table_schema,
  'code_alias'::text AS table_name,
  'code_system'::text AS column_name,
  NULL::text AS data_type,
  channel_group,
  code_system AS channel_code,
  row_count::bigint,
  code_value_non_null_count::bigint AS non_null_count,
  code_value_distinct_count::bigint AS distinct_count,
  concat('target_id_distinct=', distinct_target_id_count) AS note
FROM code_alias_distribution
ORDER BY channel_group, code_system;

WITH target_channels AS (
  SELECT 'ably'::text AS channel_group
  UNION ALL
  SELECT 'playauto'::text
),
canonical_sku AS (
  SELECT
    v.sku_id,
    v.product_id,
    v.selfpia_sku_code,
    v.selfpia_product_code,
    v.product_name,
    v.option_value
  FROM product_code.v_sku_canonical AS v
),
own_sku_value_by_sku AS (
  SELECT DISTINCT
    ca.target_id AS sku_id,
    ca.code_value AS own_sku_code
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL

  UNION

  SELECT DISTINCT
    scm.sku_id,
    scm.own_sku_code
  FROM product_code.sku_channel_mapping AS scm
  WHERE NULLIF(btrim(COALESCE(scm.own_sku_code, '')), '') IS NOT NULL
),
channel_mapping AS (
  SELECT
    CASE
      WHEN lower(COALESCE(scm.channel_code, '')) ~ '(^|[^a-z0-9])a[-_ ]?bly([^a-z0-9]|$)'
        OR lower(COALESCE(scm.channel_code, '')) LIKE '%ably%'
      THEN 'ably'
      WHEN lower(COALESCE(scm.channel_code, '')) LIKE '%playauto%'
        OR lower(COALESCE(scm.channel_code, '')) LIKE '%play_auto%'
        OR lower(COALESCE(scm.channel_code, '')) LIKE '%play-auto%'
        OR lower(COALESCE(scm.channel_code, '')) LIKE '%play auto%'
      THEN 'playauto'
      ELSE NULL
    END AS channel_group,
    scm.channel_code,
    scm.sku_id,
    scm.seller_product_code,
    scm.channel_sku_code,
    scm.own_sku_code
  FROM product_code.sku_channel_mapping AS scm
),
channel_mapping_filtered AS (
  SELECT *
  FROM channel_mapping
  WHERE channel_group IN ('ably', 'playauto')
),
channel_mapping_by_sku AS (
  SELECT
    channel_group,
    sku_id,
    COUNT(*) AS mapping_rows,
    COUNT(DISTINCT seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(seller_product_code, '')), '') IS NOT NULL
    ) AS seller_product_code_distinct_count,
    COUNT(DISTINCT channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(channel_sku_code, '')), '') IS NOT NULL
    ) AS channel_sku_code_distinct_count,
    COUNT(DISTINCT concat_ws('|', seller_product_code, channel_sku_code)) FILTER (
      WHERE NULLIF(btrim(COALESCE(seller_product_code, '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(channel_sku_code, '')), '') IS NOT NULL
    ) AS code_pair_distinct_count,
    MIN(seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(seller_product_code, '')), '') IS NOT NULL
    ) AS sample_seller_product_code,
    MIN(channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(channel_sku_code, '')), '') IS NOT NULL
    ) AS sample_channel_sku_code,
    MIN(own_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(own_sku_code, '')), '') IS NOT NULL
    ) AS sample_own_sku_code
  FROM channel_mapping_filtered
  GROUP BY channel_group, sku_id
),
channel_mapping_by_own_sku AS (
  SELECT
    cmf.channel_group,
    osv.sku_id AS candidate_sku_id,
    COUNT(*) AS mapping_rows_by_own_sku,
    COUNT(DISTINCT cmf.sku_id) AS mapped_sku_count_by_own_sku,
    COUNT(DISTINCT cmf.seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(cmf.seller_product_code, '')), '') IS NOT NULL
    ) AS seller_product_code_distinct_by_own_sku,
    COUNT(DISTINCT cmf.channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(cmf.channel_sku_code, '')), '') IS NOT NULL
    ) AS channel_sku_code_distinct_by_own_sku,
    COUNT(DISTINCT concat_ws('|', cmf.seller_product_code, cmf.channel_sku_code)) FILTER (
      WHERE NULLIF(btrim(COALESCE(cmf.seller_product_code, '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(cmf.channel_sku_code, '')), '') IS NOT NULL
    ) AS code_pair_distinct_by_own_sku,
    MIN(cmf.seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(cmf.seller_product_code, '')), '') IS NOT NULL
    ) AS sample_seller_product_code_by_own_sku,
    MIN(cmf.channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(cmf.channel_sku_code, '')), '') IS NOT NULL
    ) AS sample_channel_sku_code_by_own_sku
  FROM own_sku_value_by_sku AS osv
  JOIN channel_mapping_filtered AS cmf
    ON cmf.own_sku_code = osv.own_sku_code
  WHERE NULLIF(btrim(COALESCE(osv.own_sku_code, '')), '') IS NOT NULL
  GROUP BY cmf.channel_group, osv.sku_id
),
channel_alias_by_sku AS (
  SELECT
    CASE
      WHEN lower(COALESCE(ca.code_system, '')) LIKE '%ably%'
        OR lower(COALESCE(ca.code_system, '')) LIKE '%a_bly%'
        OR lower(COALESCE(ca.code_system, '')) LIKE '%a-bly%'
      THEN 'ably'
      WHEN lower(COALESCE(ca.code_system, '')) LIKE '%playauto%'
        OR lower(COALESCE(ca.code_system, '')) LIKE '%play_auto%'
        OR lower(COALESCE(ca.code_system, '')) LIKE '%play-auto%'
      THEN 'playauto'
      ELSE NULL
    END AS channel_group,
    ca.target_id AS sku_id,
    COUNT(*) AS alias_rows,
    COUNT(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(ca.code_value, '')), '') IS NOT NULL
    ) AS alias_identity_rows
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND (
      lower(COALESCE(ca.code_system, '')) LIKE '%ably%'
      OR lower(COALESCE(ca.code_system, '')) LIKE '%a_bly%'
      OR lower(COALESCE(ca.code_system, '')) LIKE '%a-bly%'
      OR lower(COALESCE(ca.code_system, '')) LIKE '%playauto%'
      OR lower(COALESCE(ca.code_system, '')) LIKE '%play_auto%'
      OR lower(COALESCE(ca.code_system, '')) LIKE '%play-auto%'
    )
  GROUP BY 1, ca.target_id
),
manual_alias_by_sku AS (
  SELECT
    ca.target_id AS sku_id,
    COUNT(*) AS manual_alias_rows
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND (
      lower(COALESCE(ca.usage_type, '')) LIKE '%manual%'
      OR lower(COALESCE(ca.memo, '')) LIKE '%manual%'
      OR COALESCE(ca.memo, '') LIKE '%' || U&'\C218\B3D9' || '%'
      OR lower(COALESCE(ca.raw_payload::text, '')) LIKE '%manual%'
      OR lower(COALESCE(ca.raw_payload::text, '')) LIKE '%reviewer%'
    )
  GROUP BY ca.target_id
),
candidate_universe AS (
  SELECT
    tc.channel_group,
    cs.sku_id,
    cs.product_id,
    cs.selfpia_sku_code,
    cs.selfpia_product_code,
    cs.product_name,
    cs.option_value,
    osv.own_sku_code,
    COALESCE(cmbs.mapping_rows, 0) AS direct_mapping_rows,
    COALESCE(cabs.alias_rows, 0) AS direct_alias_rows,
    COALESCE(cmbos.mapping_rows_by_own_sku, 0) AS mapping_rows_by_own_sku,
    COALESCE(cmbos.code_pair_distinct_by_own_sku, 0) AS code_pair_distinct_by_own_sku,
    cmbos.sample_seller_product_code_by_own_sku,
    cmbos.sample_channel_sku_code_by_own_sku,
    COALESCE(ma.manual_alias_rows, 0) AS manual_alias_rows,
    COALESCE(cmbs.seller_product_code_distinct_count, 0) AS direct_seller_product_code_distinct_count,
    COALESCE(cmbs.channel_sku_code_distinct_count, 0) AS direct_channel_sku_code_distinct_count,
    COALESCE(cmbs.code_pair_distinct_count, 0) AS direct_code_pair_distinct_count,
    cmbs.sample_seller_product_code,
    cmbs.sample_channel_sku_code
  FROM target_channels AS tc
  CROSS JOIN canonical_sku AS cs
  LEFT JOIN own_sku_value_by_sku AS osv
    ON osv.sku_id = cs.sku_id
  LEFT JOIN channel_mapping_by_sku AS cmbs
    ON cmbs.channel_group = tc.channel_group
   AND cmbs.sku_id = cs.sku_id
  LEFT JOIN channel_mapping_by_own_sku AS cmbos
    ON cmbos.channel_group = tc.channel_group
   AND cmbos.candidate_sku_id = cs.sku_id
  LEFT JOIN channel_alias_by_sku AS cabs
    ON cabs.channel_group = tc.channel_group
   AND cabs.sku_id = cs.sku_id
  LEFT JOIN manual_alias_by_sku AS ma
    ON ma.sku_id = cs.sku_id
),
code_pair_counts AS (
  SELECT
    channel_group,
    COALESCE(sample_seller_product_code, sample_seller_product_code_by_own_sku) AS product_code,
    COALESCE(sample_channel_sku_code, sample_channel_sku_code_by_own_sku) AS option_code,
    COUNT(DISTINCT sku_id) AS sku_count
  FROM candidate_universe
  WHERE (
      direct_mapping_rows > 0
      OR direct_alias_rows > 0
      OR code_pair_distinct_by_own_sku = 1
    )
    AND NULLIF(btrim(COALESCE(sample_seller_product_code, sample_seller_product_code_by_own_sku, '')), '') IS NOT NULL
    AND NULLIF(btrim(COALESCE(sample_channel_sku_code, sample_channel_sku_code_by_own_sku, '')), '') IS NOT NULL
  GROUP BY
    channel_group,
    COALESCE(sample_seller_product_code, sample_seller_product_code_by_own_sku),
    COALESCE(sample_channel_sku_code, sample_channel_sku_code_by_own_sku)
),
classified AS (
  SELECT
    cu.*,
    COALESCE(cpc.sku_count, 0) AS sku_count_for_code_pair,
    (
      lower(COALESCE(cu.option_value, '')) LIKE '%크리스탈ab%'
      OR lower(COALESCE(cu.option_value, '')) LIKE '% ab %'
      OR lower(COALESCE(cu.option_value, '')) LIKE 'ab %'
      OR lower(COALESCE(cu.option_value, '')) LIKE '% ab'
      OR lower(COALESCE(cu.option_value, '')) LIKE '%화이트골드%실버%'
      OR lower(COALESCE(cu.option_value, '')) LIKE '%실버%화이트골드%'
      OR lower(COALESCE(cu.option_value, '')) LIKE '%1+1%'
      OR lower(COALESCE(cu.option_value, '')) LIKE '%수량%'
    ) AS semantic_warning,
    (
      direct_mapping_rows > 0
      OR direct_alias_rows > 0
    ) AS matched_confirmed_like,
    (
      direct_mapping_rows = 0
      AND direct_alias_rows = 0
      AND code_pair_distinct_by_own_sku = 1
      AND COALESCE(cpc.sku_count, 0) = 1
      AND manual_alias_rows = 0
    ) AS unique_own_sku_candidate,
    (
      direct_mapping_rows = 0
      AND direct_alias_rows = 0
      AND code_pair_distinct_by_own_sku > 1
    ) AS duplicate_own_sku_evidence,
    (
      COALESCE(cpc.sku_count, 0) > 1
    ) AS duplicate_code_pair_risk
  FROM candidate_universe AS cu
  LEFT JOIN code_pair_counts AS cpc
    ON cpc.channel_group = cu.channel_group
   AND cpc.product_code = COALESCE(cu.sample_seller_product_code, cu.sample_seller_product_code_by_own_sku)
   AND cpc.option_code = COALESCE(cu.sample_channel_sku_code, cu.sample_channel_sku_code_by_own_sku)
),
summary_metrics AS (
  SELECT
    channel_group,
    COUNT(DISTINCT sku_id)::bigint AS selfpia_total_rows,
    COUNT(DISTINCT sku_id) FILTER (WHERE matched_confirmed_like)::bigint AS direct_mapping_rows,
    COUNT(DISTINCT sku_id) FILTER (WHERE direct_mapping_rows > 0)::bigint AS direct_sku_channel_mapping_rows,
    COUNT(DISTINCT sku_id) FILTER (WHERE direct_alias_rows > 0)::bigint AS direct_code_alias_rows,
    COUNT(DISTINCT sku_id) FILTER (WHERE mapping_rows_by_own_sku > 0)::bigint AS own_sku_join_to_existing_mapping_rows,
    COUNT(DISTINCT sku_id) FILTER (WHERE unique_own_sku_candidate AND NOT semantic_warning)::bigint AS unique_own_sku_evidence_candidate_rows,
    COUNT(DISTINCT sku_id) FILTER (WHERE duplicate_own_sku_evidence)::bigint AS duplicate_own_sku_evidence_rows,
    COUNT(DISTINCT sku_id) FILTER (WHERE duplicate_code_pair_risk)::bigint AS duplicate_code_pair_risk_rows,
    COUNT(DISTINCT sku_id) FILTER (WHERE semantic_warning)::bigint AS semantic_warning_rows,
    COUNT(DISTINCT sku_id) FILTER (WHERE manual_alias_rows > 0)::bigint AS manual_marker_rows,
    COUNT(DISTINCT sku_id) FILTER (
      WHERE direct_mapping_rows = 0
        AND direct_alias_rows = 0
        AND mapping_rows_by_own_sku = 0
    )::bigint AS evidence_missing_rows
  FROM classified
  GROUP BY channel_group
),
summary_rows AS (
  SELECT tc.channel_group, 'selfpia_total_rows'::text AS summary_type, COALESCE(sm.selfpia_total_rows, 0)::bigint AS row_count, 'All canonical selfpia SKU rows considered.'::text AS note FROM target_channels AS tc LEFT JOIN summary_metrics AS sm ON sm.channel_group = tc.channel_group
  UNION ALL SELECT tc.channel_group, 'direct_mapping_rows', COALESCE(sm.direct_mapping_rows, 0)::bigint, 'SKU rows with direct channel mapping or code alias evidence.' FROM target_channels AS tc LEFT JOIN summary_metrics AS sm ON sm.channel_group = tc.channel_group
  UNION ALL SELECT tc.channel_group, 'direct_sku_channel_mapping_rows', COALESCE(sm.direct_sku_channel_mapping_rows, 0)::bigint, 'SKU rows with direct sku_channel_mapping evidence.' FROM target_channels AS tc LEFT JOIN summary_metrics AS sm ON sm.channel_group = tc.channel_group
  UNION ALL SELECT tc.channel_group, 'direct_code_alias_rows', COALESCE(sm.direct_code_alias_rows, 0)::bigint, 'SKU rows with direct code_alias evidence.' FROM target_channels AS tc LEFT JOIN summary_metrics AS sm ON sm.channel_group = tc.channel_group
  UNION ALL SELECT tc.channel_group, 'own_sku_join_to_existing_mapping_rows', COALESCE(sm.own_sku_join_to_existing_mapping_rows, 0)::bigint, 'SKU rows whose own_sku joins to existing channel mapping evidence.' FROM target_channels AS tc LEFT JOIN summary_metrics AS sm ON sm.channel_group = tc.channel_group
  UNION ALL SELECT tc.channel_group, 'unique_own_sku_evidence_candidate_rows', COALESCE(sm.unique_own_sku_evidence_candidate_rows, 0)::bigint, 'Possible auto-match candidates: own_sku maps to one channel code pair and no manual marker.' FROM target_channels AS tc LEFT JOIN summary_metrics AS sm ON sm.channel_group = tc.channel_group
  UNION ALL SELECT tc.channel_group, 'duplicate_own_sku_evidence_rows', COALESCE(sm.duplicate_own_sku_evidence_rows, 0)::bigint, 'own_sku maps to multiple channel code pairs; keep out of auto-match.' FROM target_channels AS tc LEFT JOIN summary_metrics AS sm ON sm.channel_group = tc.channel_group
  UNION ALL SELECT tc.channel_group, 'duplicate_code_pair_risk_rows', COALESCE(sm.duplicate_code_pair_risk_rows, 0)::bigint, 'same channel product/option code pair touches multiple SKU rows.' FROM target_channels AS tc LEFT JOIN summary_metrics AS sm ON sm.channel_group = tc.channel_group
  UNION ALL SELECT tc.channel_group, 'semantic_warning_rows', COALESCE(sm.semantic_warning_rows, 0)::bigint, 'risk keyword rows among candidate universe.' FROM target_channels AS tc LEFT JOIN summary_metrics AS sm ON sm.channel_group = tc.channel_group
  UNION ALL SELECT tc.channel_group, 'manual_marker_rows', COALESCE(sm.manual_marker_rows, 0)::bigint, 'rows with manual/reviewer marker; do not overwrite.' FROM target_channels AS tc LEFT JOIN summary_metrics AS sm ON sm.channel_group = tc.channel_group
  UNION ALL SELECT tc.channel_group, 'evidence_missing_rows', COALESCE(sm.evidence_missing_rows, 0)::bigint, 'no direct channel evidence and no own_sku join evidence; likely needs source import or channel_absent split.' FROM target_channels AS tc LEFT JOIN summary_metrics AS sm ON sm.channel_group = tc.channel_group
),
sample_rows AS (
  SELECT
    'direct_mapping_sample'::text AS sample_bucket,
    channel_group,
    sku_id::text AS sku_id,
    selfpia_sku_code,
    own_sku_code,
    product_name,
    option_value,
    COALESCE(sample_seller_product_code, sample_seller_product_code_by_own_sku) AS product_code_candidate,
    COALESCE(sample_channel_sku_code, sample_channel_sku_code_by_own_sku) AS option_code_candidate,
    'direct channel mapping or alias exists'::text AS evidence_source,
    CASE WHEN semantic_warning THEN 'semantic warning' ELSE 'none' END AS risk_note,
    ROW_NUMBER() OVER (PARTITION BY channel_group ORDER BY selfpia_sku_code, sku_id) AS sample_rank
  FROM classified
  WHERE matched_confirmed_like

  UNION ALL

  SELECT
    'unique_own_sku_candidate_sample',
    channel_group,
    sku_id::text,
    selfpia_sku_code,
    own_sku_code,
    product_name,
    option_value,
    COALESCE(sample_seller_product_code, sample_seller_product_code_by_own_sku),
    COALESCE(sample_channel_sku_code, sample_channel_sku_code_by_own_sku),
    'own_sku joins exactly one channel code pair',
    CASE WHEN semantic_warning THEN 'semantic warning' ELSE 'none' END,
    ROW_NUMBER() OVER (PARTITION BY channel_group ORDER BY selfpia_sku_code, sku_id)
  FROM classified
  WHERE unique_own_sku_candidate
    AND NOT semantic_warning

  UNION ALL

  SELECT
    'duplicate_own_sku_evidence_sample',
    channel_group,
    sku_id::text,
    selfpia_sku_code,
    own_sku_code,
    product_name,
    option_value,
    COALESCE(sample_seller_product_code, sample_seller_product_code_by_own_sku),
    COALESCE(sample_channel_sku_code, sample_channel_sku_code_by_own_sku),
    'own_sku maps to multiple code pairs',
    'duplicate evidence; do not auto-match',
    ROW_NUMBER() OVER (PARTITION BY channel_group ORDER BY selfpia_sku_code, sku_id)
  FROM classified
  WHERE duplicate_own_sku_evidence

  UNION ALL

  SELECT
    'evidence_missing_sample',
    channel_group,
    sku_id::text,
    selfpia_sku_code,
    own_sku_code,
    product_name,
    option_value,
    NULL::text,
    NULL::text,
    'no direct mapping and no own_sku channel evidence',
    'needs source evidence or channel_absent classification',
    ROW_NUMBER() OVER (PARTITION BY channel_group ORDER BY selfpia_sku_code, sku_id)
  FROM classified
  WHERE direct_mapping_rows = 0
    AND direct_alias_rows = 0
    AND mapping_rows_by_own_sku = 0
)
SELECT
  'summary'::text AS result_kind,
  s.summary_type,
  s.channel_group,
  s.row_count,
  s.note,
  NULL::text AS sample_bucket,
  NULL::text AS sku_id,
  NULL::text AS selfpia_sku,
  NULL::text AS own_sku,
  NULL::text AS product_name,
  NULL::text AS option_name,
  NULL::text AS product_code_candidate,
  NULL::text AS option_code_candidate,
  NULL::text AS evidence_source,
  NULL::text AS risk_note,
  NULL::bigint AS sample_rank
FROM summary_rows AS s

UNION ALL

SELECT
  'sample',
  NULL::text,
  sr.channel_group,
  NULL::bigint,
  NULL::text,
  sr.sample_bucket,
  sr.sku_id,
  sr.selfpia_sku_code,
  sr.own_sku_code,
  sr.product_name,
  sr.option_value,
  sr.product_code_candidate,
  sr.option_code_candidate,
  sr.evidence_source,
  sr.risk_note,
  sr.sample_rank::bigint
FROM sample_rows AS sr
WHERE sr.sample_rank <= 20
ORDER BY
  result_kind,
  channel_group,
  summary_type,
  sample_bucket,
  sample_rank;
