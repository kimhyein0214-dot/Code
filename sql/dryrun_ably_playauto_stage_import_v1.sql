/*
  Ably / PlayAuto stage import dryrun design.

  This script is intentionally read-only. It does not import source files,
  does not define stage tables, and does not change data.

  Intended execution pattern:
    begin read only;
    \i sql/dryrun_ably_playauto_stage_import_v1.sql
    rollback;

  Source column labels are ASCII on purpose so the script can be piped through
  Windows shells without corrupting SQL string literals. The Korean source
  column names are documented in docs/ably_playauto_stage_import_dryrun_plan_v1.md.
*/

SELECT
  'guard'::text AS section,
  current_database() AS current_database,
  current_user AS current_user,
  current_setting('transaction_read_only') AS transaction_read_only,
  CASE
    WHEN current_database() = 'product_ops_test'
      THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS dryrun_verdict,
  CASE
    WHEN current_database() = 'product_ops_test'
      THEN 'local product_ops_test database confirmed'
    ELSE 'not product_ops_test; stop before any future local stage import'
  END AS note;

WITH required_columns AS (
  SELECT *
  FROM (
    VALUES
      ('product_code', 'sku_master', 'id', 'sku_id target'),
      ('product_code', 'sku_master', 'product_id', 'product family join'),
      ('product_code', 'sku_master', 'virtual_sku_code', 'fallback sku text'),
      ('product_code', 'sku_master', 'option_value', 'db option text support'),
      ('product_code', 'product_master', 'id', 'product_id target'),
      ('product_code', 'product_master', 'virtual_product_code', 'fallback product text'),
      ('product_code', 'product_master', 'product_name', 'db product text support'),
      ('product_code', 'code_alias', 'target_type', 'alias target scope'),
      ('product_code', 'code_alias', 'target_id', 'alias target id'),
      ('product_code', 'code_alias', 'code_system', 'alias system'),
      ('product_code', 'code_alias', 'code_value', 'alias value'),
      ('product_code', 'code_alias', 'selfpia_product_code', 'product family support'),
      ('product_code', 'sku_channel_mapping', 'sku_id', 'mapping sku target'),
      ('product_code', 'sku_channel_mapping', 'channel_code', 'marketplace channel'),
      ('product_code', 'sku_channel_mapping', 'seller_product_code', 'channel product or seller code'),
      ('product_code', 'sku_channel_mapping', 'channel_sku_code', 'channel option or sku code'),
      ('product_code', 'sku_channel_mapping', 'own_sku_code', 'own_sku support')
  ) AS r(table_schema, table_name, column_name, required_for)
),
column_check AS (
  SELECT
    rc.*,
    ic.column_name IS NOT NULL AS is_present,
    ic.data_type
  FROM required_columns AS rc
  LEFT JOIN information_schema.columns AS ic
    ON ic.table_schema = rc.table_schema
   AND ic.table_name = rc.table_name
   AND ic.column_name = rc.column_name
)
SELECT
  'schema_required_column_check'::text AS section,
  table_schema,
  table_name,
  column_name,
  data_type,
  CASE WHEN is_present THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS dryrun_verdict,
  required_for AS note
FROM column_check
ORDER BY table_schema, table_name, column_name;

WITH conceptual_stage_targets AS (
  SELECT *
  FROM (
    VALUES
      ('stg', 'stage_ably_source_raw', 'raw preservation layer for Ably CSV'),
      ('stg', 'stage_ably_options', 'normalized Ably option-level evidence'),
      ('stg', 'stage_playauto_source_raw', 'raw preservation layer for PlayAuto workbook rows'),
      ('stg', 'stage_playauto_options', 'normalized PlayAuto option-level evidence after line explode'),
      ('stg', 'stage_playauto_sku_dictionary', 'PlayAuto SKU product dictionary'),
      ('stg', 'channel_source_raw', 'optional future unified raw source table'),
      ('stg', 'channel_source_option_evidence', 'optional future unified option evidence table')
  ) AS t(table_schema, table_name, intended_role)
),
target_name_check AS (
  SELECT
    t.*,
    it.table_name IS NOT NULL AS relation_already_exists
  FROM conceptual_stage_targets AS t
  LEFT JOIN information_schema.tables AS it
    ON it.table_schema = t.table_schema
   AND it.table_name = t.table_name
)
SELECT
  'conceptual_stage_target_name_check'::text AS section,
  table_schema,
  table_name,
  intended_role,
  CASE
    WHEN relation_already_exists THEN 'NEEDS_REVIEW'
    ELSE 'PASS'
  END AS dryrun_verdict,
  CASE
    WHEN relation_already_exists THEN 'name already exists; inspect before designing local stage table'
    ELSE 'name is free in current schema; no name collision detected'
  END AS note
FROM target_name_check
ORDER BY table_schema, table_name;

WITH canonical_fields AS (
  SELECT *
  FROM (
    VALUES
      (1, 'source_file_id', 'text or uuid', 'required', 'stable source batch id for dedupe and audit'),
      (2, 'source_system', 'text', 'required', 'ably_csv or playauto_xlsx'),
      (3, 'source_file_name', 'text', 'required', 'basename only; source file itself is not stored in git'),
      (4, 'source_sheet_name', 'text', 'required', 'csv for Ably, workbook sheet for PlayAuto'),
      (5, 'source_row_no', 'integer', 'required', 'source row reference'),
      (6, 'source_option_line_no', 'integer', 'optional', 'PlayAuto exploded line number'),
      (7, 'channel_code', 'text', 'required', 'actual marketplace channel, not playauto by default'),
      (8, 'channel_account', 'text', 'optional', 'store/account value from source'),
      (9, 'channel_product_code', 'text', 'required when active', 'marketplace product code'),
      (10, 'channel_option_code', 'text', 'required for Ably active rows', 'marketplace option code where available'),
      (11, 'seller_product_code', 'text', 'optional', 'seller/source product code'),
      (12, 'channel_sku_code', 'text', 'optional', 'source SKU or channel SKU code'),
      (13, 'own_sku_code', 'text', 'optional', 'own_sku evidence candidate'),
      (14, 'selfpia_sku_code', 'text', 'optional', 'selfpia_sku evidence candidate'),
      (15, 'product_name', 'text', 'required', 'source product text support'),
      (16, 'option_name', 'text', 'optional', 'source option text support'),
      (17, 'option_value', 'text', 'optional', 'normalized option value'),
      (18, 'sale_status', 'text', 'optional', 'source sale status'),
      (19, 'display_status', 'text', 'optional', 'source display status'),
      (20, 'stock_status', 'text', 'optional', 'source stock or option status'),
      (21, 'stock_qty', 'numeric', 'optional', 'parsed stock quantity'),
      (22, 'raw_payload', 'jsonb', 'required', 'raw row payload for traceability'),
      (23, 'parse_status', 'text', 'required', 'ok, warning, or error'),
      (24, 'parse_warning', 'text', 'optional', 'reason for warning or block'),
      (25, 'reviewer_decision', 'text', 'required', 'pending in dryrun'),
      (26, 'export_allowed', 'boolean', 'required', 'false in dryrun')
  ) AS f(sort_order, field_name, suggested_type, required_level, dryrun_note)
)
SELECT
  'canonical_stage_field_definition'::text AS section,
  field_name,
  suggested_type,
  required_level,
  'PASS'::text AS dryrun_verdict,
  dryrun_note AS note
FROM canonical_fields
ORDER BY sort_order;

WITH ably_required_fields AS (
  SELECT *
  FROM (
    VALUES
      (1, 'ably_product_no', 'channel_product_code', 'required', 'nonblank; 956 distinct observed'),
      (2, 'ably_option_no', 'channel_option_code', 'required', 'nonblank and option-level unique; 9,158 distinct observed'),
      (3, 'ably_seller_product_code', 'seller_product_code', 'optional_candidate', 'normalize blank and dash; product-level caution'),
      (4, 'ably_solution_unique_code', 'own_sku_code_or_selfpia_sku_candidate', 'optional_candidate', 'join only after uniqueness check; 4,691 distinct observed'),
      (5, 'ably_product_name', 'product_name', 'required', 'support evidence only'),
      (6, 'ably_option1', 'option_value_or_text_evidence', 'required', 'support evidence and bracket-code source'),
      (7, 'ably_option2', 'option_value_or_text_evidence', 'required', 'support evidence'),
      (8, 'ably_full_option_name', 'option_name', 'required', 'support evidence and bracket-code source'),
      (9, 'ably_stock_qty', 'stock_qty', 'required', 'numeric status support'),
      (10, 'ably_soldout_status', 'stock_status', 'required', 'separate inactive rows'),
      (11, 'ably_display_status', 'display_status', 'required', 'separate hidden rows')
  ) AS f(sort_order, source_column, canonical_field, requirement_level, validation_rule)
)
SELECT
  'ably_required_source_field'::text AS section,
  source_column,
  canonical_field,
  requirement_level,
  'PASS'::text AS dryrun_verdict,
  validation_rule AS note
FROM ably_required_fields
ORDER BY sort_order;

WITH playauto_required_fields AS (
  SELECT *
  FROM (
    VALUES
      (1, 'playauto_mall_account', 'channel_code_and_channel_account', 'required', 'split to actual marketplace; never default to playauto'),
      (2, 'playauto_seller_management_code', 'seller_product_code_or_source_product_code', 'required', 'source product-level code candidate'),
      (3, 'playauto_online_product_name', 'product_name', 'required', 'support evidence only'),
      (4, 'playauto_mall_product_no', 'channel_product_code', 'required_when_active', 'blank can be pending or inactive evidence'),
      (5, 'playauto_product_status_readonly', 'sale_status', 'required', 'active/inactive/pending classifier'),
      (6, 'playauto_option', 'option_name', 'required', 'multi-line explode; may include header line'),
      (7, 'playauto_sku', 'channel_sku_code_or_own_sku_candidate', 'required_for_sku_evidence', 'multi-line explode and dictionary validation'),
      (8, 'playauto_option_status', 'stock_status', 'required', 'multi-line option active flag'),
      (9, 'playauto_sku_products_sku_code', 'sku_dictionary_code', 'required_for_validation', 'validate main sheet SKU lines'),
      (10, 'playauto_sku_products_attribute', 'option_value_support', 'optional_support', 'support evidence only')
  ) AS f(sort_order, source_column, canonical_field, requirement_level, validation_rule)
)
SELECT
  'playauto_required_source_field'::text AS section,
  source_column,
  canonical_field,
  requirement_level,
  'PASS'::text AS dryrun_verdict,
  validation_rule AS note
FROM playauto_required_fields
ORDER BY sort_order;

WITH validation_rules AS (
  SELECT *
  FROM (
    VALUES
      (1, 'source_file_id', 'source_file_id is present and stable per file batch', 'NEEDS_REVIEW', 'required before any real local stage load'),
      (2, 'channel_code_normalization', 'PlayAuto account strings map to ably, smartstore, coupang, kakaotalk_store', 'PASS', 'known values from analysis are mappable'),
      (3, 'channel_account_split', 'right side of playauto_mall_account is preserved', 'PASS', 'needed for account-specific evidence'),
      (4, 'channel_product_code_non_null', 'active Ably and active PlayAuto rows have channel_product_code', 'NEEDS_REVIEW', 'source files have blanks in PlayAuto pending rows'),
      (5, 'channel_option_code_non_null', 'active Ably rows have channel_option_code', 'PASS', 'Ably option number is nonblank and unique in analysis'),
      (6, 'seller_product_code_normalization', 'trim spaces and convert blank or dash to null', 'NEEDS_REVIEW', 'must be implemented in parser'),
      (7, 'own_sku_code_normalization', 'trim brackets and normalize blank or dash before joining', 'NEEDS_REVIEW', 'must be implemented in parser'),
      (8, 'sku_multiline_explode', 'PlayAuto SKU and option status are exploded to option-level rows', 'NEEDS_REVIEW', 'line alignment must be validated'),
      (9, 'status_normalization', 'sale, display, stock, and option statuses are normalized', 'NEEDS_REVIEW', 'policy mapping must be explicit'),
      (10, 'duplicate_source_row_detection', 'dedupe by source_file_id plus channel identity fields', 'NEEDS_REVIEW', 'requires source_file_id and row hash'),
      (11, 'option_level_uniqueness', 'one source option identity maps to at most one active candidate sku_id', 'NEEDS_REVIEW', 'requires staged evidence'),
      (12, 'inactive_channel_absent_split', 'hidden, pending, stopped, sold out, and option inactive rows are bucketed before unmatched', 'NEEDS_REVIEW', 'requires status normalization')
  ) AS r(sort_order, check_name, check_description, default_verdict, note)
)
SELECT
  'pre_import_validation_rule'::text AS section,
  check_name,
  check_description,
  default_verdict AS dryrun_verdict,
  note
FROM validation_rules
ORDER BY sort_order;

WITH existing_channel_evidence AS (
  SELECT
    'code_alias'::text AS evidence_source,
    CASE
      WHEN ca.code_system LIKE 'ably%' THEN 'ably'
      WHEN ca.code_system LIKE 'playauto%' THEN 'playauto'
      ELSE 'other'
    END AS evidence_group,
    COUNT(*) AS row_count,
    COUNT(DISTINCT ca.code_system) AS system_count,
    COUNT(DISTINCT ca.code_value) FILTER (
      WHERE NULLIF(btrim(COALESCE(ca.code_value, '')), '') IS NOT NULL
    ) AS code_value_count,
    COUNT(DISTINCT ca.target_id) AS target_count
  FROM product_code.code_alias AS ca
  WHERE ca.code_system LIKE 'ably%'
     OR ca.code_system LIKE 'playauto%'
  GROUP BY
    CASE
      WHEN ca.code_system LIKE 'ably%' THEN 'ably'
      WHEN ca.code_system LIKE 'playauto%' THEN 'playauto'
      ELSE 'other'
    END

  UNION ALL

  SELECT
    'sku_channel_mapping'::text AS evidence_source,
    CASE
      WHEN lower(COALESCE(scm.channel_code, '')) LIKE '%ably%' THEN 'ably'
      WHEN lower(COALESCE(scm.channel_code, '')) LIKE '%playauto%' THEN 'playauto'
      ELSE 'other'
    END AS evidence_group,
    COUNT(*) AS row_count,
    COUNT(DISTINCT scm.channel_code) AS system_count,
    COUNT(DISTINCT concat_ws('|', scm.seller_product_code, scm.channel_sku_code)) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS code_value_count,
    COUNT(DISTINCT scm.sku_id) AS target_count
  FROM product_code.sku_channel_mapping AS scm
  WHERE lower(COALESCE(scm.channel_code, '')) LIKE '%ably%'
     OR lower(COALESCE(scm.channel_code, '')) LIKE '%playauto%'
  GROUP BY
    CASE
      WHEN lower(COALESCE(scm.channel_code, '')) LIKE '%ably%' THEN 'ably'
      WHEN lower(COALESCE(scm.channel_code, '')) LIKE '%playauto%' THEN 'playauto'
      ELSE 'other'
    END
),
expected_groups AS (
  SELECT *
  FROM (
    VALUES
      ('code_alias', 'ably'),
      ('code_alias', 'playauto'),
      ('sku_channel_mapping', 'ably'),
      ('sku_channel_mapping', 'playauto')
  ) AS g(evidence_source, evidence_group)
)
SELECT
  'existing_ably_playauto_evidence_conflict_check'::text AS section,
  eg.evidence_source,
  eg.evidence_group,
  COALESCE(ece.row_count, 0)::bigint AS row_count,
  COALESCE(ece.system_count, 0)::bigint AS system_count,
  COALESCE(ece.code_value_count, 0)::bigint AS code_value_count,
  COALESCE(ece.target_count, 0)::bigint AS target_count,
  CASE
    WHEN COALESCE(ece.row_count, 0) = 0 THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS dryrun_verdict,
  CASE
    WHEN COALESCE(ece.row_count, 0) = 0 THEN 'no existing Ably/PlayAuto evidence found; source stage can be designed as first evidence path'
    ELSE 'existing evidence found; inspect for conflicts before any stage seed or candidate generation'
  END AS note
FROM expected_groups AS eg
LEFT JOIN existing_channel_evidence AS ece
  ON ece.evidence_source = eg.evidence_source
 AND ece.evidence_group = eg.evidence_group
ORDER BY eg.evidence_source, eg.evidence_group;

WITH scm_channels AS (
  SELECT
    lower(COALESCE(channel_code, '')) AS channel_code,
    COUNT(*) AS row_count,
    COUNT(DISTINCT sku_id) AS sku_count,
    COUNT(DISTINCT seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(seller_product_code, '')), '') IS NOT NULL
    ) AS seller_product_count,
    COUNT(DISTINCT channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(channel_sku_code, '')), '') IS NOT NULL
    ) AS channel_sku_count
  FROM product_code.sku_channel_mapping
  GROUP BY lower(COALESCE(channel_code, ''))
),
channel_expectations AS (
  SELECT *
  FROM (
    VALUES
      ('ably', 'expected new channel from Ably source'),
      ('smartstore', 'existing channel may already have mappings'),
      ('coupang', 'PlayAuto source account present but current DB may have no mapping'),
      ('kakaotalk_store', 'PlayAuto source account present but current DB may have no mapping'),
      ('playauto', 'should not be used as final marketplace channel by default')
  ) AS c(channel_code, expectation)
)
SELECT
  'target_channel_collision_check'::text AS section,
  ce.channel_code,
  COALESCE(sc.row_count, 0)::bigint AS existing_mapping_rows,
  COALESCE(sc.sku_count, 0)::bigint AS existing_sku_count,
  COALESCE(sc.seller_product_count, 0)::bigint AS existing_seller_product_count,
  COALESCE(sc.channel_sku_count, 0)::bigint AS existing_channel_sku_count,
  CASE
    WHEN ce.channel_code = 'playauto' AND COALESCE(sc.row_count, 0) > 0 THEN 'NEEDS_REVIEW'
    WHEN ce.channel_code IN ('ably', 'coupang', 'kakaotalk_store') AND COALESCE(sc.row_count, 0) = 0 THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS dryrun_verdict,
  ce.expectation AS note
FROM channel_expectations AS ce
LEFT JOIN scm_channels AS sc
  ON sc.channel_code = ce.channel_code
ORDER BY ce.channel_code;

WITH alias_profile AS (
  SELECT
    ca.code_system,
    COUNT(*) AS row_count,
    COUNT(DISTINCT ca.code_value) FILTER (
      WHERE NULLIF(btrim(COALESCE(ca.code_value, '')), '') IS NOT NULL
    ) AS distinct_code_value_count,
    COUNT(DISTINCT ca.target_id) AS distinct_target_count
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system IN ('selfpia_sku', 'own_sku')
  GROUP BY ca.code_system
),
own_sku_duplicate_profile AS (
  SELECT
    COUNT(*) FILTER (WHERE target_count = 1) AS unique_own_sku_count,
    COUNT(*) FILTER (WHERE target_count > 1) AS duplicate_own_sku_count,
    MAX(target_count) AS max_targets_per_own_sku
  FROM (
    SELECT
      ca.code_value,
      COUNT(DISTINCT ca.target_id) AS target_count
    FROM product_code.code_alias AS ca
    WHERE ca.target_type = 'SKU'
      AND ca.code_system = 'own_sku'
      AND NULLIF(btrim(COALESCE(ca.code_value, '')), '') IS NOT NULL
    GROUP BY ca.code_value
  ) AS x
)
SELECT
  'join_key_readiness_check'::text AS section,
  ap.code_system,
  ap.row_count::bigint,
  ap.distinct_code_value_count::bigint,
  ap.distinct_target_count::bigint,
  CASE
    WHEN ap.code_system = 'selfpia_sku' AND ap.distinct_code_value_count = ap.distinct_target_count THEN 'PASS'
    WHEN ap.code_system = 'own_sku' THEN 'NEEDS_REVIEW'
    ELSE 'NEEDS_REVIEW'
  END AS dryrun_verdict,
  CASE
    WHEN ap.code_system = 'selfpia_sku' THEN 'selfpia_sku is the safest direct join key if source supplies exact value'
    WHEN ap.code_system = 'own_sku' THEN concat(
      'own_sku requires duplicate handling; unique_values=',
      COALESCE(odp.unique_own_sku_count, 0),
      ', duplicate_values=',
      COALESCE(odp.duplicate_own_sku_count, 0),
      ', max_targets=',
      COALESCE(odp.max_targets_per_own_sku, 0)
    )
    ELSE 'unexpected alias system'
  END AS note
FROM alias_profile AS ap
CROSS JOIN own_sku_duplicate_profile AS odp
ORDER BY ap.code_system;

WITH final_checks AS (
  SELECT 'database_guard' AS check_name, current_database() = 'product_ops_test' AS passed
  UNION ALL
  SELECT 'required_schema_columns_present', NOT EXISTS (
    SELECT 1
    FROM (
      VALUES
        ('product_code', 'sku_master', 'id'),
        ('product_code', 'product_master', 'id'),
        ('product_code', 'code_alias', 'code_system'),
        ('product_code', 'code_alias', 'code_value'),
        ('product_code', 'sku_channel_mapping', 'channel_code'),
        ('product_code', 'sku_channel_mapping', 'channel_sku_code')
    ) AS r(table_schema, table_name, column_name)
    LEFT JOIN information_schema.columns AS ic
      ON ic.table_schema = r.table_schema
     AND ic.table_name = r.table_name
     AND ic.column_name = r.column_name
    WHERE ic.column_name IS NULL
  )
  UNION ALL
  SELECT 'no_existing_playauto_final_channel_required', true
  UNION ALL
  SELECT 'source_file_id_policy_defined', false
  UNION ALL
  SELECT 'playauto_multiline_policy_defined', false
  UNION ALL
  SELECT 'inactive_status_policy_defined', false
)
SELECT
  'dryrun_design_verdict'::text AS section,
  CASE
    WHEN bool_and(passed) THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS dryrun_verdict,
  COUNT(*) FILTER (WHERE passed)::bigint AS passed_check_count,
  COUNT(*) FILTER (WHERE NOT passed)::bigint AS needs_review_check_count,
  string_agg(check_name, ', ' ORDER BY check_name) FILTER (WHERE NOT passed) AS needs_review_checks,
  'NEEDS_REVIEW is expected at this design stage until source_file_id, PlayAuto multi-line, and inactive-status policies are implemented in a future local stage dryrun.'::text AS note
FROM final_checks;
