-- =============================================================================
-- precheck_manual_review_export_v1.sql
--
-- Purpose:
--   SELECT-only precheck for manual review export planning.
--   Checks whether the expected relations and columns are visible through
--   information_schema before any real manual review CSV draft is written.
--
-- Safety:
--   No DB write.
--   Do not use as apply script.
--   Run only in an approved local read-only session.
-- =============================================================================

WITH expected_tables AS (
  SELECT *
  FROM (
    VALUES
      ('product_code', 'product_master', 'core product master', 'expected'),
      ('product_code', 'sku_master', 'core SKU master', 'expected'),
      ('product_code', 'code_alias', 'alias store for selfpia, own_sku, confirmed, and candidate channel codes', 'expected'),
      ('product_code', 'product_image', 'image evidence for review CSV', 'expected; may be missing if image patch is not present'),
      ('product_code', 'sku_channel_mapping', 'confirmed channel mapping source', 'expected'),
      ('product_code', 'channel_product', 'channel product layer seen in integration docs', 'optional; may be missing in local product_code schema'),
      ('product_code', 'channel_sku', 'channel option/SKU layer seen in integration docs', 'optional; may be missing in local product_code schema'),
      ('product_code', 'channel_sku_review_draft', 'possible future review draft table', 'optional; may be missing'),
      ('product_code', 'channel_product_mapping', 'name candidate only; confirm actual schema before use', 'possible missing / 확인 필요'),
      ('product_code', 'channel_option_mapping', 'name candidate only; confirm actual schema before use', 'possible missing / 확인 필요'),
      ('product_code', 'v_sku_canonical', 'canonical SKU view used by app queries', 'expected view if local schema draft is present')
  ) AS t(table_schema, table_name, purpose, expectation_note)
),
actual_tables AS (
  SELECT table_schema, table_name, table_type
  FROM information_schema.tables
  WHERE table_schema = 'product_code'
)
SELECT
  'table_check' AS check_area,
  e.table_schema,
  e.table_name,
  COALESCE(a.table_type, '') AS actual_table_type,
  (a.table_name IS NOT NULL) AS exists_bool,
  CASE WHEN a.table_name IS NOT NULL THEN 'PRESENT' ELSE 'MISSING_REVIEW_REQUIRED' END AS status,
  e.purpose,
  e.expectation_note
FROM expected_tables e
LEFT JOIN actual_tables a
  ON a.table_schema = e.table_schema
 AND a.table_name = e.table_name
ORDER BY e.table_schema, e.table_name;

WITH expected_columns AS (
  SELECT *
  FROM (
    VALUES
      ('product_code', 'product_master', 'id', 'product_id source'),
      ('product_code', 'product_master', 'virtual_product_code', 'internal product code evidence'),
      ('product_code', 'product_master', 'product_name', 'product_name for manual review CSV'),
      ('product_code', 'product_master', 'status', 'product status evidence'),
      ('product_code', 'product_master', 'raw_payload', 'source evidence preservation'),
      ('product_code', 'sku_master', 'id', 'sku_id source'),
      ('product_code', 'sku_master', 'product_id', 'product linkage'),
      ('product_code', 'sku_master', 'virtual_sku_code', 'internal SKU code evidence'),
      ('product_code', 'sku_master', 'option_value', 'option_name source'),
      ('product_code', 'sku_master', 'status', 'SKU status evidence'),
      ('product_code', 'sku_master', 'raw_payload', 'source evidence preservation'),
      ('product_code', 'code_alias', 'id', 'alias row id'),
      ('product_code', 'code_alias', 'target_type', 'PRODUCT/SKU target separation'),
      ('product_code', 'code_alias', 'target_id', 'product_id or sku_id linkage'),
      ('product_code', 'code_alias', 'code_system', 'confirmed/candidate system separation'),
      ('product_code', 'code_alias', 'code_value', 'code value source'),
      ('product_code', 'code_alias', 'selfpia_product_code', 'selfpia product alias context'),
      ('product_code', 'code_alias', 'selfpia_option_no', 'selfpia option alias context'),
      ('product_code', 'code_alias', 'is_primary', 'primary alias signal'),
      ('product_code', 'code_alias', 'usage_type', 'possible alias usage classification'),
      ('product_code', 'code_alias', 'memo', 'manual evidence memo'),
      ('product_code', 'code_alias', 'raw_payload', 'source evidence preservation'),
      ('product_code', 'sku_channel_mapping', 'id', 'mapping id'),
      ('product_code', 'sku_channel_mapping', 'sku_id', 'sku linkage'),
      ('product_code', 'sku_channel_mapping', 'channel_code', 'channel discriminator'),
      ('product_code', 'sku_channel_mapping', 'channel_sku_code', 'channel option code / optionNo candidate source'),
      ('product_code', 'sku_channel_mapping', 'seller_product_code', 'channel product code / productNo candidate source'),
      ('product_code', 'sku_channel_mapping', 'own_sku_code', 'own_sku evidence'),
      ('product_code', 'sku_channel_mapping', 'is_primary', 'primary mapping signal'),
      ('product_code', 'sku_channel_mapping', 'raw_payload', 'source evidence preservation'),
      ('product_code', 'product_image', 'id', 'image row id'),
      ('product_code', 'product_image', 'sku_id', 'image to SKU linkage'),
      ('product_code', 'product_image', 'product_id', 'image to product linkage'),
      ('product_code', 'product_image', 'selfpia_sku_code', 'image to selfpia SKU linkage'),
      ('product_code', 'product_image', 'selfpia_product_code', 'image to selfpia product linkage'),
      ('product_code', 'product_image', 'image_url', 'image_url for review evidence'),
      ('product_code', 'product_image', 'thumbnail_url', 'thumbnail evidence'),
      ('product_code', 'product_image', 'is_primary', 'primary image signal'),
      ('product_code', 'product_image', 'sort_order', 'image order signal'),
      ('product_code', 'channel_product', 'channel', 'channel discriminator if layered channel tables exist'),
      ('product_code', 'channel_product', 'channel_product_code', 'channel product code / productNo source'),
      ('product_code', 'channel_product', 'channel_product_name', 'channel product name evidence'),
      ('product_code', 'channel_product', 'seller_product_code_raw', 'seller product raw evidence'),
      ('product_code', 'channel_sku', 'channel', 'channel discriminator if layered channel tables exist'),
      ('product_code', 'channel_sku', 'channel_sku_code', 'channel option code / optionNo source'),
      ('product_code', 'channel_sku', 'channel_option_id', 'Smartstore optionNo evidence seen in docs'),
      ('product_code', 'channel_sku', 'channel_product_id', 'channel product linkage'),
      ('product_code', 'channel_sku', 'extracted_own_code', 'own_sku candidate evidence'),
      ('product_code', 'channel_sku_review_draft', 'status', 'review draft status if table exists'),
      ('product_code', 'channel_sku_review_draft', 'review_status', 'reviewer decision status if table exists'),
      ('product_code', 'channel_sku_review_draft', 'decision_status', 'alternate reviewer decision status name'),
      ('product_code', 'channel_sku_review_draft', 'export_allowed', 'export gate if review draft table exists'),
      ('product_code', 'channel_sku_review_draft', 'reviewer_decision', 'manual decision if review draft table exists'),
      ('product_code', 'v_sku_canonical', 'sku_id', 'canonical sku id'),
      ('product_code', 'v_sku_canonical', 'product_id', 'canonical product id'),
      ('product_code', 'v_sku_canonical', 'selfpia_sku_code', 'selfpia_sku alias'),
      ('product_code', 'v_sku_canonical', 'selfpia_product_code', 'selfpia product alias'),
      ('product_code', 'v_sku_canonical', 'selfpia_option_no', 'selfpia option alias'),
      ('product_code', 'v_sku_canonical', 'product_name', 'canonical product name'),
      ('product_code', 'v_sku_canonical', 'option_value', 'canonical option name')
  ) AS t(table_schema, table_name, column_name, purpose)
),
actual_columns AS (
  SELECT table_schema, table_name, column_name, data_type, ordinal_position
  FROM information_schema.columns
  WHERE table_schema = 'product_code'
)
SELECT
  'column_check' AS check_area,
  e.table_schema,
  e.table_name,
  e.column_name,
  COALESCE(a.data_type, '') AS data_type,
  a.ordinal_position,
  (a.column_name IS NOT NULL) AS exists_bool,
  CASE WHEN a.column_name IS NOT NULL THEN 'PRESENT' ELSE 'MISSING_REVIEW_REQUIRED' END AS status,
  e.purpose
FROM expected_columns e
LEFT JOIN actual_columns a
  ON a.table_schema = e.table_schema
 AND a.table_name = e.table_name
 AND a.column_name = e.column_name
ORDER BY e.table_schema, e.table_name, e.column_name;

WITH expected_code_systems AS (
  SELECT *
  FROM (
    VALUES
      ('selfpia_product', 'confirmed/local base product alias'),
      ('selfpia_sku', 'confirmed/local base SKU alias'),
      ('own_sku', 'own SKU evidence; not enough for automatic confirmation by itself'),
      ('smartstore_product_no', 'Smartstore confirmed productNo'),
      ('smartstore_product_no_candidate', 'Smartstore candidate productNo; not export source'),
      ('smartstore_option_no', 'Smartstore confirmed optionNo'),
      ('smartstore_option_no_candidate', 'Smartstore candidate optionNo; not export source'),
      ('makeshop_channel_code', 'MakeShop related confirmed/evidence code candidate'),
      ('makeshop_product_uid', 'MakeShop product UID candidate system name'),
      ('makeshop_option_no', 'MakeShop option id candidate system name'),
      ('ably_product_no', 'Ably confirmed product number'),
      ('ably_option_no', 'Ably confirmed option number'),
      ('ably_product_no_candidate', 'Ably candidate product number; not export source'),
      ('ably_option_no_candidate', 'Ably candidate option number; not export source'),
      ('ably_seller_code_candidate', 'Ably seller/solution/bracket code candidate'),
      ('playauto_product_code', 'PlayAuto internal product code'),
      ('playauto_option_code', 'PlayAuto internal option/SKU code'),
      ('playauto_channel_product_code', 'actual marketplace product code through PlayAuto'),
      ('playauto_channel_option_code', 'actual marketplace option code through PlayAuto'),
      ('playauto_product_code_candidate', 'PlayAuto internal product candidate'),
      ('playauto_option_code_candidate', 'PlayAuto internal option candidate'),
      ('playauto_channel_product_code_candidate', 'marketplace product candidate through PlayAuto'),
      ('playauto_channel_option_code_candidate', 'marketplace option candidate through PlayAuto')
  ) AS t(code_system, note)
),
code_alias_shape AS (
  SELECT
    EXISTS (
      SELECT 1
      FROM information_schema.tables
      WHERE table_schema = 'product_code'
        AND table_name = 'code_alias'
    ) AS has_code_alias_table,
    EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'product_code'
        AND table_name = 'code_alias'
        AND column_name = 'code_system'
    ) AS has_code_system_column,
    EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'product_code'
        AND table_name = 'code_alias'
        AND column_name = 'code_value'
    ) AS has_code_value_column
)
SELECT
  'code_system_readiness_check' AS check_area,
  e.code_system,
  s.has_code_alias_table,
  s.has_code_system_column,
  s.has_code_value_column,
  CASE
    WHEN s.has_code_alias_table AND s.has_code_system_column AND s.has_code_value_column
      THEN 'DISTRIBUTION_QUERY_CAN_BE_REVIEWED'
    ELSE 'CODE_ALIAS_STRUCTURE_MISSING_REVIEW_REQUIRED'
  END AS status,
  e.note
FROM expected_code_systems e
CROSS JOIN code_alias_shape s
ORDER BY e.code_system;

-- Optional distribution query for an approved local read-only session.
-- This block references product_code.code_alias directly and can fail when the
-- table or columns are absent. Keep it commented until table_check and
-- column_check show the required structure.
--
-- SELECT
--   'code_system_distribution' AS check_area,
--   code_system,
--   target_type,
--   COUNT(*) AS rows,
--   COUNT(DISTINCT code_value) AS distinct_code_value,
--   COUNT(DISTINCT target_id) AS distinct_target_id
-- FROM product_code.code_alias
-- WHERE code_system IN (
--   'selfpia_product',
--   'selfpia_sku',
--   'own_sku',
--   'smartstore_product_no',
--   'smartstore_product_no_candidate',
--   'smartstore_option_no',
--   'smartstore_option_no_candidate',
--   'makeshop_channel_code',
--   'makeshop_product_uid',
--   'makeshop_option_no',
--   'ably_product_no',
--   'ably_option_no',
--   'ably_product_no_candidate',
--   'ably_option_no_candidate',
--   'ably_seller_code_candidate',
--   'playauto_product_code',
--   'playauto_option_code',
--   'playauto_channel_product_code',
--   'playauto_channel_option_code',
--   'playauto_product_code_candidate',
--   'playauto_option_code_candidate',
--   'playauto_channel_product_code_candidate',
--   'playauto_channel_option_code_candidate'
-- )
-- GROUP BY code_system, target_type
-- ORDER BY code_system, target_type;

WITH structure_flags AS (
  SELECT
    EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'product_code' AND table_name = 'sku_master'
    ) AS has_sku_master,
    EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'product_code' AND table_name = 'product_master'
    ) AS has_product_master,
    EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'product_code' AND table_name = 'code_alias'
    ) AS has_code_alias,
    EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'product_code' AND table_name = 'sku_channel_mapping'
    ) AS has_sku_channel_mapping,
    EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'product_code' AND table_name = 'product_image'
    ) AS has_product_image,
    EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'product_code' AND table_name = 'code_alias' AND column_name = 'code_system'
    ) AS has_alias_code_system,
    EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'product_code' AND table_name = 'sku_channel_mapping' AND column_name = 'channel_code'
    ) AS has_channel_code,
    EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'product_code' AND table_name = 'sku_channel_mapping' AND column_name = 'channel_sku_code'
    ) AS has_channel_option_code_source,
    EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'product_code' AND table_name = 'sku_channel_mapping' AND column_name = 'seller_product_code'
    ) AS has_channel_product_code_source,
    EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'product_code' AND table_name = 'sku_channel_mapping' AND column_name = 'own_sku_code'
    ) AS has_own_sku_code_source
)
SELECT
  'final_overall' AS check_area,
  CASE
    WHEN has_sku_master
     AND has_product_master
     AND has_code_alias
     AND has_sku_channel_mapping
     AND has_alias_code_system
     AND has_channel_code
     AND has_channel_option_code_source
     AND has_channel_product_code_source
      THEN 'STRUCTURE_PRECHECK_READY_TO_RUN'
    ELSE 'RUN_AND_REVIEW_REQUIRED'
  END AS result,
  CONCAT(
    'core tables: sku_master=', has_sku_master,
    ', product_master=', has_product_master,
    ', code_alias=', has_code_alias,
    ', sku_channel_mapping=', has_sku_channel_mapping,
    '; product_image=', has_product_image,
    '; alias code_system=', has_alias_code_system,
    '; channel_code=', has_channel_code,
    '; channel option source=', has_channel_option_code_source,
    '; channel product source=', has_channel_product_code_source,
    '; own_sku source=', has_own_sku_code_source,
    '. Review table_check and column_check before drafting any manual review export SELECT.'
  ) AS note
FROM structure_flags;
