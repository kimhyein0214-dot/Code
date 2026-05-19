/*
  Ably / PlayAuto source file requirements inspection.

  Purpose:
  - SELECT-only diagnosis for the current local product_code schema.
  - Show which existing DB keys are needed before Ably / PlayAuto source
    evidence can become auto-match candidates.
  - This file does not read source CSV/XLSX files and does not import them.

  Safety:
  - SELECT-only.
  - No DDL.
  - No INSERT/UPDATE/DELETE/MERGE.
  - No import/export.
  - Intended for local product_ops_test only, preferably inside:
      BEGIN READ ONLY;
      \i sql/inspect_ably_playauto_source_file_requirements_v1.sql
      ROLLBACK;
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
  'Run inside BEGIN READ ONLY and end with ROLLBACK. This script is SELECT-only.'::text AS note;

WITH required_tables AS (
  SELECT *
  FROM (
    VALUES
      ('product_code'::text, 'sku_master'::text),
      ('product_code'::text, 'product_master'::text),
      ('product_code'::text, 'code_alias'::text),
      ('product_code'::text, 'sku_channel_mapping'::text),
      ('product_code'::text, 'v_sku_canonical'::text)
  ) AS t(table_schema, table_name)
)
SELECT
  'required_relation_presence'::text AS section,
  rt.table_schema,
  rt.table_name,
  CASE WHEN c.table_name IS NULL THEN 'missing' ELSE 'present' END AS status,
  NULL::bigint AS row_count,
  'Required local relation for source evidence inspection.'::text AS note
FROM required_tables AS rt
LEFT JOIN information_schema.tables AS c
  ON c.table_schema = rt.table_schema
 AND c.table_name = rt.table_name
ORDER BY rt.table_schema, rt.table_name;

WITH required_columns AS (
  SELECT *
  FROM (
    VALUES
      ('product_code', 'sku_master', 'id', 'local sku_id target'),
      ('product_code', 'sku_master', 'product_id', 'joins product_master'),
      ('product_code', 'sku_master', 'virtual_sku_code', 'fallback internal SKU text'),
      ('product_code', 'sku_master', 'option_value', 'option text support'),
      ('product_code', 'product_master', 'id', 'local product_id target'),
      ('product_code', 'product_master', 'virtual_product_code', 'fallback internal product text'),
      ('product_code', 'product_master', 'product_name', 'product text support'),
      ('product_code', 'code_alias', 'target_type', 'SKU / PRODUCT alias scope'),
      ('product_code', 'code_alias', 'target_id', 'joins sku_master or product_master'),
      ('product_code', 'code_alias', 'code_system', 'selfpia_sku / own_sku / channel aliases'),
      ('product_code', 'code_alias', 'code_value', 'joinable code value'),
      ('product_code', 'code_alias', 'selfpia_product_code', 'product-family support'),
      ('product_code', 'sku_channel_mapping', 'sku_id', 'confirmed channel mapping target'),
      ('product_code', 'sku_channel_mapping', 'channel_code', 'actual marketplace channel'),
      ('product_code', 'sku_channel_mapping', 'seller_product_code', 'channel product/seller code'),
      ('product_code', 'sku_channel_mapping', 'channel_sku_code', 'channel option/SKU code'),
      ('product_code', 'sku_channel_mapping', 'own_sku_code', 'own_sku evidence carried on mapping')
  ) AS c(table_schema, table_name, column_name, required_for)
)
SELECT
  'required_column_presence'::text AS section,
  rc.table_schema,
  rc.table_name,
  rc.column_name,
  CASE WHEN ic.column_name IS NULL THEN 'missing' ELSE 'present' END AS status,
  ic.data_type,
  rc.required_for AS note
FROM required_columns AS rc
LEFT JOIN information_schema.columns AS ic
  ON ic.table_schema = rc.table_schema
 AND ic.table_name = rc.table_name
 AND ic.column_name = rc.column_name
ORDER BY rc.table_schema, rc.table_name, rc.column_name;

SELECT
  'master_relation_counts'::text AS section,
  'product_code.sku_master'::text AS relation_name,
  COUNT(*)::bigint AS row_count,
  COUNT(DISTINCT sm.id)::bigint AS distinct_id_count,
  COUNT(DISTINCT sm.product_id)::bigint AS distinct_product_id_count,
  COUNT(sm.virtual_sku_code) FILTER (
    WHERE NULLIF(btrim(COALESCE(sm.virtual_sku_code, '')), '') IS NOT NULL
  )::bigint AS nonblank_code_count,
  'sku_id is the target key for source evidence.'::text AS note
FROM product_code.sku_master AS sm

UNION ALL

SELECT
  'master_relation_counts'::text AS section,
  'product_code.product_master'::text AS relation_name,
  COUNT(*)::bigint AS row_count,
  COUNT(DISTINCT pm.id)::bigint AS distinct_id_count,
  COUNT(DISTINCT pm.id)::bigint AS distinct_product_id_count,
  COUNT(pm.virtual_product_code) FILTER (
    WHERE NULLIF(btrim(COALESCE(pm.virtual_product_code, '')), '') IS NOT NULL
  )::bigint AS nonblank_code_count,
  'product_id supports product-family validation.'::text AS note
FROM product_code.product_master AS pm;

WITH alias_systems AS (
  SELECT
    ca.code_system,
    COUNT(*) AS row_count,
    COUNT(DISTINCT ca.code_value) FILTER (
      WHERE NULLIF(btrim(COALESCE(ca.code_value, '')), '') IS NOT NULL
    ) AS distinct_code_value_count,
    COUNT(DISTINCT ca.target_id) AS distinct_target_id_count
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND (
      ca.code_system IN ('selfpia_sku', 'own_sku')
      OR ca.code_system LIKE 'ably%'
      OR ca.code_system LIKE 'playauto%'
      OR ca.code_system LIKE 'smartstore%'
      OR ca.code_system LIKE 'makeshop%'
    )
  GROUP BY ca.code_system
)
SELECT
  'alias_system_distribution'::text AS section,
  code_system,
  row_count::bigint,
  distinct_code_value_count::bigint,
  distinct_target_id_count::bigint,
  CASE
    WHEN code_system = 'selfpia_sku' THEN 'Primary direct join candidate for staged source codes.'
    WHEN code_system = 'own_sku' THEN 'Useful fallback, but must be checked for duplicate target_ids.'
    WHEN code_system LIKE 'ably%' THEN 'Existing Ably evidence, if any.'
    WHEN code_system LIKE 'playauto%' THEN 'Existing PlayAuto evidence, if any.'
    ELSE 'Existing cross-channel evidence for comparison.'
  END AS note
FROM alias_systems
ORDER BY
  CASE
    WHEN code_system = 'selfpia_sku' THEN 1
    WHEN code_system = 'own_sku' THEN 2
    WHEN code_system LIKE 'ably%' THEN 3
    WHEN code_system LIKE 'playauto%' THEN 4
    ELSE 5
  END,
  code_system;

WITH own_sku_targets AS (
  SELECT
    ca.code_value AS own_sku_code,
    COUNT(DISTINCT ca.target_id) AS target_sku_count,
    COUNT(DISTINCT v.product_id) AS target_product_count,
    COUNT(DISTINCT v.selfpia_product_code) AS target_selfpia_product_count
  FROM product_code.code_alias AS ca
  LEFT JOIN product_code.v_sku_canonical AS v
    ON v.sku_id = ca.target_id
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
    AND NULLIF(btrim(COALESCE(ca.code_value, '')), '') IS NOT NULL
  GROUP BY ca.code_value
)
SELECT
  'own_sku_uniqueness_profile'::text AS section,
  CASE
    WHEN target_sku_count = 1 THEN 'unique_own_sku'
    WHEN target_sku_count > 1 AND target_product_count <= 1 THEN 'duplicate_same_product'
    WHEN target_sku_count > 1 THEN 'duplicate_cross_product'
    ELSE 'unknown'
  END AS bucket,
  COUNT(*)::bigint AS own_sku_value_count,
  SUM(target_sku_count)::bigint AS summed_target_sku_count,
  MAX(target_sku_count)::bigint AS max_target_sku_count,
  'Staged Ably/PlayAuto own_sku-like codes can auto-confirm only from unique_own_sku unless additional evidence resolves duplicates.'::text AS note
FROM own_sku_targets
GROUP BY
  CASE
    WHEN target_sku_count = 1 THEN 'unique_own_sku'
    WHEN target_sku_count > 1 AND target_product_count <= 1 THEN 'duplicate_same_product'
    WHEN target_sku_count > 1 THEN 'duplicate_cross_product'
    ELSE 'unknown'
  END
ORDER BY bucket;

WITH channel_distribution AS (
  SELECT
    lower(COALESCE(scm.channel_code, '')) AS channel_code,
    COUNT(*) AS row_count,
    COUNT(DISTINCT scm.sku_id) AS distinct_sku_id_count,
    COUNT(DISTINCT scm.seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
    ) AS distinct_seller_product_code_count,
    COUNT(DISTINCT scm.channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS distinct_channel_sku_code_count,
    COUNT(DISTINCT scm.own_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.own_sku_code, '')), '') IS NOT NULL
    ) AS distinct_own_sku_code_count
  FROM product_code.sku_channel_mapping AS scm
  GROUP BY lower(COALESCE(scm.channel_code, ''))
)
SELECT
  'sku_channel_mapping_distribution'::text AS section,
  channel_code,
  row_count::bigint,
  distinct_sku_id_count::bigint,
  distinct_seller_product_code_count::bigint,
  distinct_channel_sku_code_count::bigint,
  distinct_own_sku_code_count::bigint,
  CASE
    WHEN channel_code LIKE '%ably%' THEN 'Existing Ably channel mapping evidence.'
    WHEN channel_code LIKE '%playauto%' THEN 'Do not treat this as final marketplace unless intentionally modeled as source system.'
    ELSE 'Existing channel mapping evidence for comparison.'
  END AS note
FROM channel_distribution
WHERE channel_code LIKE '%ably%'
   OR channel_code LIKE '%playauto%'
   OR channel_code LIKE '%smartstore%'
   OR channel_code LIKE '%makeshop%'
   OR channel_code LIKE '%coupang%'
   OR channel_code LIKE '%kakao%'
ORDER BY channel_code;

WITH source_requirements AS (
  SELECT *
  FROM (
    VALUES
      ('ably_csv', '상품 번호', 'channel_product_code', 'Required for Ably product identity.'),
      ('ably_csv', '옵션 번호', 'channel_option_code', 'Required for Ably option identity.'),
      ('ably_csv', '판매자 상품코드', 'seller_product_code', 'Candidate only; likely product-level.'),
      ('ably_csv', '솔루션사 고유코드', 'own_sku_code_or_selfpia_sku_code', 'Candidate code; must join uniquely.'),
      ('ably_csv', '옵션1/옵션2/전체 옵션명 bracket code', 'own_sku_code_or_selfpia_sku_code', 'Extracted candidate; must join uniquely.'),
      ('ably_csv', '상품명/전체 옵션명', 'product_option_text_support', 'Support only; never direct identity.'),
      ('ably_csv', '품절상태/진열상태/재고수량', 'channel_presence_status', 'Separate inactive/absent from true unmatched.'),
      ('playauto_xlsx', '쇼핑몰(계정)', 'channel_code/channel_account', 'Required first; PlayAuto is source system, not final channel.'),
      ('playauto_xlsx', '판매자관리코드', 'seller_product_code', 'PlayAuto internal management code candidate.'),
      ('playauto_xlsx', '쇼핑몰 상품번호', 'channel_product_code', 'Marketplace product code; blank rows are likely inactive/pending.'),
      ('playauto_xlsx', 'SKU exploded line', 'own_sku_code_or_selfpia_sku_code_or_channel_sku_code', 'Must validate against SKU상품.SKU코드 and uniqueness.'),
      ('playauto_xlsx', '옵션 exploded line', 'option_name', 'Support text; line alignment required.'),
      ('playauto_xlsx', '상품상태/옵션 상태', 'channel_presence_status', 'Separate active, inactive, and pending evidence.'),
      ('playauto_xlsx', 'SKU상품.SKU코드', 'sku_dictionary_code', 'Validates main-sheet SKU lines.')
  ) AS r(source_system, source_column, canonical_field, requirement_note)
)
SELECT
  'source_file_required_fields'::text AS section,
  source_system,
  source_column,
  canonical_field,
  requirement_note,
  'No source file import is performed by this SQL.'::text AS safety_note
FROM source_requirements
ORDER BY source_system, canonical_field, source_column;

WITH join_paths AS (
  SELECT *
  FROM (
    VALUES
      (
        'selfpia_sku_direct',
        'stage.selfpia_sku_code or extracted bracket code',
        'product_code.code_alias(code_system=''selfpia_sku'', target_type=''SKU'')',
        'auto-match possible when one source option maps to exactly one sku_id and channel code identity is unique'
      ),
      (
        'own_sku_unique',
        'stage.own_sku_code, Ably 솔루션사 고유코드, or PlayAuto exploded SKU',
        'product_code.code_alias(code_system=''own_sku'', target_type=''SKU'')',
        'auto-match possible only when own_sku maps to one sku_id or duplicate is resolved by product/option evidence'
      ),
      (
        'existing_channel_mapping',
        'stage.channel_code + channel_product_code + channel_option_code',
        'product_code.sku_channel_mapping',
        'used to avoid duplicate confirmed mapping and to detect already-confirmed rows'
      ),
      (
        'product_option_support',
        'stage.product_name + option_name',
        'product_code.v_sku_canonical / product_master / sku_master',
        'supporting evidence only; not sufficient for automatic confirmation'
      ),
      (
        'channel_absent_or_inactive',
        'stage.sale_status + display_status + stock_status',
        'source status fields',
        'bucket before unmatched so inactive rows do not depress active matching rate'
      )
  ) AS p(join_path, source_key, db_relation, classification_rule)
)
SELECT
  'recommended_join_paths'::text AS section,
  join_path,
  source_key,
  db_relation,
  classification_rule
FROM join_paths
ORDER BY join_path;

SELECT
  'canonical_sample'::text AS section,
  v.sku_id,
  v.product_id,
  v.selfpia_sku_code,
  v.selfpia_product_code,
  pm.virtual_product_code,
  pm.product_name,
  sm.virtual_sku_code,
  sm.option_value,
  own.own_sku_values,
  scm.channel_mapping_summary,
  'Sample of fields needed to evaluate future staged Ably/PlayAuto source evidence.'::text AS note
FROM product_code.v_sku_canonical AS v
JOIN product_code.sku_master AS sm
  ON sm.id = v.sku_id
LEFT JOIN product_code.product_master AS pm
  ON pm.id = sm.product_id
LEFT JOIN LATERAL (
  SELECT string_agg(DISTINCT ca.code_value, ', ' ORDER BY ca.code_value) AS own_sku_values
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.target_id = v.sku_id
    AND ca.code_system = 'own_sku'
    AND NULLIF(btrim(COALESCE(ca.code_value, '')), '') IS NOT NULL
) AS own ON true
LEFT JOIN LATERAL (
  SELECT string_agg(
    DISTINCT concat_ws(':', scm.channel_code, scm.seller_product_code, scm.channel_sku_code),
    ' | '
    ORDER BY concat_ws(':', scm.channel_code, scm.seller_product_code, scm.channel_sku_code)
  ) AS channel_mapping_summary
  FROM product_code.sku_channel_mapping AS scm
  WHERE scm.sku_id = v.sku_id
) AS scm ON true
ORDER BY v.selfpia_sku_code
LIMIT 30;
