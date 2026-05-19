/*
  Local-only Ably / PlayAuto stage import workflow draft v1.

  DO NOT EXECUTE IN THIS STEP.

  This file documents a future local import workflow. It intentionally avoids
  direct file import commands. Source CSV/XLSX parsing should be handled by a
  reviewed local parser that produces structured rows for local-only staging.

  Safety:
  - No operating Supabase.
  - No NAS PostgreSQL.
  - No remote DB.
  - No source CSV/XLSX changes.
  - No source CSV/XLSX git add.
  - No direct file import command in this draft.
  - No automatic confirmation.
  - reviewer_decision remains pending.
  - export_allowed remains false.
*/

SELECT
  'workflow_header' AS section,
  'local product_ops_test only' AS target,
  'draft_only_do_not_execute' AS execution_status,
  'source files are parsed outside SQL by a reviewed local parser; this SQL records target flow and rules' AS note;

WITH workflow_steps AS (
  SELECT *
  FROM (
    VALUES
      (1, 'review_schema_draft', 'Review product_code_stage schema draft. Do not apply yet.'),
      (2, 'local_schema_apply_dryrun', 'Prepare a separate reviewed local migration dryrun.'),
      (3, 'source_file_registration', 'Assign one source_file_id per source file batch in a future approved local step.'),
      (4, 'raw_preservation_load', 'Load parsed row payloads into raw tables in a future approved local step.'),
      (5, 'ably_normalization', 'Normalize Ably raw rows into option-level channel evidence.'),
      (6, 'playauto_account_split', 'Split PlayAuto mall account into actual channel_code and channel_account.'),
      (7, 'playauto_multiline_explode', 'Explode PlayAuto option, SKU, quantity, and option status lines.'),
      (8, 'status_normalization', 'Normalize sale/display/option statuses and inactive buckets.'),
      (9, 'validation', 'Run validate_local_stage_ably_playauto_import_v1.sql.'),
      (10, 'code_evidence_inspection', 'Inspect joins to selfpia_sku, own_sku, and existing channel mappings.'),
      (11, 'unique_evidence_dryrun', 'Generate candidate classifications without apply.'),
      (12, 'sample_review', 'Review samples before any local apply SQL is written.')
  ) AS s(step_no, step_name, step_description)
)
SELECT
  'workflow_step' AS section,
  step_no,
  step_name,
  step_description
FROM workflow_steps
ORDER BY step_no;

WITH source_file_plan AS (
  SELECT *
  FROM (
    VALUES
      ('ably_csv', 'ably_all_csv', 'csv', 9158, 29, 'register basename and hash only; do not store original file in git'),
      ('playauto_xlsx', 'playauto_all_marketplaces_xlsx', 'xlsx', 4219, 95, 'register workbook basename and hash; main sheet row count'),
      ('playauto_xlsx', 'playauto_sku_products_sheet', 'xlsx_sheet', 17968, 4, 'same source_file_id or child sheet metadata for SKU dictionary')
  ) AS p(source_system, source_file_label, source_kind, expected_rows, expected_columns, note)
)
SELECT
  'source_file_registration_plan' AS section,
  source_system,
  source_file_label,
  source_kind,
  expected_rows,
  expected_columns,
  note
FROM source_file_plan
ORDER BY source_system, source_file_label;

WITH ably_mapping AS (
  SELECT *
  FROM (
    VALUES
      ('product_no', 'channel_product_code', 'required', 'Ably product identity; 956 distinct observed'),
      ('option_no', 'channel_option_code', 'required', 'Ably option identity; 9,158 distinct observed'),
      ('seller_product_code', 'seller_product_code', 'optional_candidate', 'product-level; normalize blank and dash to null'),
      ('solution_unique_code', 'own_sku_code_candidate', 'optional_candidate', 'possible own_sku or selfpia evidence after uniqueness check'),
      ('product_name', 'product_name', 'required_support', 'support only; never auto-confirm by name'),
      ('option1_option2_full_option_name', 'option_name_option_value', 'required_support', 'option text and bracket-code evidence'),
      ('stock_qty', 'stock_qty_raw', 'required_status', 'numeric parse required later'),
      ('soldout_status', 'sale_status_raw_or_option_status_raw', 'required_status', 'inactive split required'),
      ('display_status', 'display_status_raw', 'required_status', 'hidden split required')
  ) AS m(source_field, canonical_field, requirement, note)
)
SELECT
  'ably_canonical_mapping' AS section,
  source_field,
  canonical_field,
  requirement,
  note
FROM ably_mapping;

WITH playauto_account_mapping AS (
  SELECT *
  FROM (
    VALUES
      ('smartstore=w_ground', 'smartstore', 'w_ground'),
      ('ably=pink_rocket@naver.com', 'ably', 'pink_rocket@naver.com'),
      ('coupang=wworks2010', 'coupang', 'wworks2010'),
      ('kakaotalk_store=pink_rocket@naver.com', 'kakaotalk_store', 'pink_rocket@naver.com')
  ) AS m(raw_account_key, channel_code, channel_account)
)
SELECT
  'playauto_channel_branching_rule' AS section,
  raw_account_key,
  channel_code,
  channel_account,
  CASE
    WHEN channel_code = 'playauto' THEN 'blocked'
    ELSE 'allowed_actual_marketplace'
  END AS rule_status
FROM playauto_account_mapping;

WITH playauto_mapping AS (
  SELECT *
  FROM (
    VALUES
      ('mall_account', 'channel_code_channel_account', 'required', 'branch by actual marketplace before matching'),
      ('seller_management_code', 'seller_product_code', 'required_candidate', 'source product code candidate'),
      ('online_product_name', 'product_name', 'required_support', 'support only; never auto-confirm by name'),
      ('mall_product_no', 'channel_product_code', 'required_when_active', 'blank can be pending/inactive evidence'),
      ('option_text', 'option_name', 'required_support', 'multi-line; may include header/group line'),
      ('sku_text', 'channel_sku_code_or_own_sku_code_candidate', 'required_for_sku_evidence', 'multi-line; validate against SKU dictionary'),
      ('product_status', 'sale_status_raw', 'required_status', 'active/inactive/pending split'),
      ('option_status', 'option_status_raw', 'required_status', 'multi-line Y/N option active flag')
  ) AS m(source_field, canonical_field, requirement, note)
)
SELECT
  'playauto_canonical_mapping' AS section,
  source_field,
  canonical_field,
  requirement,
  note
FROM playauto_mapping;

WITH playauto_explode_rules AS (
  SELECT *
  FROM (
    VALUES
      (1, 'split_lines', 'Split SKU, option status, option price, option sale qty, and outbound qty by CRLF/LF/CR.'),
      (2, 'option_header_detection', 'Option text may contain a header/group line; allow option line count to equal SKU line count or SKU line count plus one.'),
      (3, 'line_alignment', 'After optional header removal, line counts must align across SKU, option status, price, quantity, and outbound fields.'),
      (4, 'dictionary_validation', 'Every nonblank exploded SKU should exist in playauto_sku_raw.raw_sku_code for the same source file.'),
      (5, 'warning_policy', 'Rows with unaligned lines or missing dictionary SKU become parse_status=warning or error and are blocked from auto-confirm.'),
      (6, 'traceability', 'Every exploded row keeps source_row_no and source_option_line_no.')
  ) AS r(rule_no, rule_name, rule_description)
)
SELECT
  'playauto_multiline_explode_rule' AS section,
  rule_no,
  rule_name,
  rule_description
FROM playauto_explode_rules
ORDER BY rule_no;

WITH status_rules AS (
  SELECT *
  FROM (
    VALUES
      ('ably', 'soldout_status_not_soldout_and_display_visible', 'active_candidate'),
      ('ably', 'soldout_or_hidden_or_zero_stock_policy_match', 'channel_absent_or_inactive'),
      ('playauto', 'product_status_sale_active_and_option_status_y', 'active_candidate'),
      ('playauto', 'waiting_edit_waiting_sale_waiting_approval_temporarily_soldout_stopped', 'channel_absent_or_inactive'),
      ('playauto', 'option_status_n', 'channel_absent_or_inactive')
  ) AS r(source_system, raw_status_condition, normalized_bucket)
)
SELECT
  'status_normalization_rule' AS section,
  source_system,
  raw_status_condition,
  normalized_bucket
FROM status_rules
ORDER BY source_system, raw_status_condition;

WITH blocked_auto_confirm_rules AS (
  SELECT *
  FROM (
    VALUES
      ('name_only_match', 'blocked', 'Product/option text is support evidence only.'),
      ('unknown_playauto_account', 'blocked', 'Unknown account cannot determine channel_code.'),
      ('playauto_as_channel_code', 'blocked', 'Use actual marketplace channel, not playauto.'),
      ('existing_confirmed_or_manual_mapping', 'blocked', 'Do not overwrite confirmed/manual mappings.'),
      ('own_sku_multiple_targets', 'blocked', 'own_sku duplicates require review.'),
      ('parse_warning_or_error', 'blocked', 'Parser warnings are not auto-confirmable.')
  ) AS r(rule_name, action, note)
)
SELECT
  'auto_confirm_block_rule' AS section,
  rule_name,
  action,
  note
FROM blocked_auto_confirm_rules
ORDER BY rule_name;
