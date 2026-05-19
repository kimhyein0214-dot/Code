/*
  Create Ably / PlayAuto normalized channel option evidence v1.

  Scope:
  - Local product_ops_test only.
  - Inserts only into product_code_stage.channel_option_evidence.
  - Does not modify product_code.code_alias.
  - Does not modify product_code.sku_channel_mapping.
  - This is stage evidence, not automatic matching apply.

  Safety:
  - reviewer_decision remains default pending.
  - export_allowed remains default false.
  - PlayAuto is branched by raw_mall_account; channel_code='playauto' is never inserted.
*/

BEGIN;

SELECT
  'guard'::text AS section,
  current_database() AS current_database,
  current_user AS current_user,
  CASE
    WHEN current_database() = 'product_ops_test'
     AND current_user = 'product_ops_tester'
    THEN 'PASS'
    ELSE 'STOP'
  END AS guard_result,
  'local channel option evidence apply guard'::text AS note;

DO $guard$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION 'blocked: current database is %, expected product_ops_test', current_database();
  END IF;

  IF current_user <> 'product_ops_tester' THEN
    RAISE EXCEPTION 'blocked: current user is %, expected product_ops_tester', current_user;
  END IF;
END
$guard$;

DO $source_guard$
DECLARE
  ably_source_count bigint;
  playauto_source_count bigint;
  existing_evidence_count bigint;
BEGIN
  SELECT COUNT(*) INTO ably_source_count
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system = 'ably_csv';

  SELECT COUNT(*) INTO playauto_source_count
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system = 'playauto_xlsx';

  IF ably_source_count < 1 THEN
    RAISE EXCEPTION 'blocked: no ably_csv source file registered';
  END IF;

  IF playauto_source_count < 1 THEN
    RAISE EXCEPTION 'blocked: no playauto_xlsx source file registered';
  END IF;

  WITH latest_sources AS (
    SELECT DISTINCT ON (source_system)
      source_file_id,
      source_system
    FROM product_code_stage.ably_playauto_source_file
    WHERE source_system IN ('ably_csv', 'playauto_xlsx')
    ORDER BY source_system, created_at DESC
  )
  SELECT COUNT(*) INTO existing_evidence_count
  FROM product_code_stage.channel_option_evidence AS e
  JOIN latest_sources AS s
    ON s.source_file_id = e.source_file_id;

  IF existing_evidence_count > 0 THEN
    RAISE EXCEPTION 'blocked: channel_option_evidence already exists for latest Ably/PlayAuto source files: % rows', existing_evidence_count;
  END IF;
END
$source_guard$;

WITH latest_ably AS (
  SELECT DISTINCT ON (source_system)
    source_file_id
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system = 'ably_csv'
  ORDER BY source_system, created_at DESC
),
normalized AS (
  SELECT
    r.source_file_id,
    'ably_csv'::text AS source_system,
    'ably_csv'::text AS source_sheet_name,
    r.source_row_no,
    1::integer AS source_option_line_no,
    'ably'::text AS channel_code,
    'pink_rocket@naver.com'::text AS channel_account,
    NULLIF(btrim(r.raw_product_no), '') AS channel_product_code,
    NULLIF(btrim(r.raw_option_no), '') AS channel_option_code,
    NULLIF(btrim(r.raw_seller_product_code), '') AS seller_product_code,
    NULL::text AS channel_sku_code,
    NULLIF(regexp_replace(btrim(coalesce(r.raw_solution_unique_code, '')), '\s+', '', 'g'), '') AS own_sku_code_candidate,
    CASE
      WHEN NULLIF(regexp_replace(btrim(coalesce(r.raw_solution_unique_code, '')), '\s+', '', 'g'), '') ILIKE 'sellpia_%'
      THEN NULLIF(regexp_replace(btrim(coalesce(r.raw_solution_unique_code, '')), '\s+', '', 'g'), '')
      ELSE NULL
    END AS selfpia_sku_candidate,
    NULLIF(btrim(r.raw_product_name), '') AS product_name,
    COALESCE(NULLIF(btrim(r.raw_full_option_name), ''), NULLIF(btrim(r.raw_option1), '')) AS option_name,
    NULLIF(
      concat_ws(
        ' / ',
        NULLIF(btrim(r.raw_option1), ''),
        NULLIF(btrim(r.raw_option2), '')
      ),
      ''
    ) AS option_value,
    r.raw_soldout_status AS sale_status_raw,
    r.raw_display_status AS display_status_raw,
    r.raw_soldout_status AS option_status_raw,
    r.raw_stock_qty AS stock_qty_raw,
    CASE
      WHEN r.raw_soldout_status = '품절아님' THEN 'active'
      WHEN r.raw_soldout_status = '품절' THEN 'inactive'
      ELSE 'needs_review'
    END AS normalized_sale_status,
    CASE
      WHEN r.raw_display_status = '진열' THEN 'active'
      WHEN r.raw_display_status = '미진열' THEN 'inactive'
      ELSE 'needs_review'
    END AS normalized_display_status,
    CASE
      WHEN r.raw_soldout_status = '품절아님' THEN 'active'
      WHEN r.raw_soldout_status = '품절' THEN 'inactive'
      ELSE 'needs_review'
    END AS normalized_option_status,
    (r.raw_display_status = '진열' AND r.raw_soldout_status = '품절아님') AS is_active_candidate,
    r.raw_payload || jsonb_build_object(
      'normalized_from', 'ably_raw',
      'evidence_line_strategy', 'one_raw_row_to_one_option_evidence'
    ) AS raw_payload,
    CASE
      WHEN NULLIF(btrim(r.raw_product_no), '') IS NULL
        OR NULLIF(btrim(r.raw_option_no), '') IS NULL THEN 'warning'
      ELSE 'ok'
    END AS parse_status,
    NULLIF(
      concat_ws(
        '; ',
        CASE WHEN NULLIF(btrim(r.raw_product_no), '') IS NULL THEN 'missing channel_product_code' END,
        CASE WHEN NULLIF(btrim(r.raw_option_no), '') IS NULL THEN 'missing channel_option_code' END
      ),
      ''
    ) AS parse_warning
  FROM product_code_stage.ably_raw AS r
  JOIN latest_ably AS s
    ON s.source_file_id = r.source_file_id
)
INSERT INTO product_code_stage.channel_option_evidence (
  source_file_id,
  source_system,
  source_sheet_name,
  source_row_no,
  source_option_line_no,
  channel_code,
  channel_account,
  channel_product_code,
  channel_option_code,
  seller_product_code,
  channel_sku_code,
  own_sku_code_candidate,
  selfpia_sku_candidate,
  product_name,
  option_name,
  option_value,
  sale_status_raw,
  display_status_raw,
  option_status_raw,
  stock_qty_raw,
  normalized_sale_status,
  normalized_display_status,
  normalized_option_status,
  is_active_candidate,
  raw_payload,
  parse_status,
  parse_warning
)
SELECT
  source_file_id,
  source_system,
  source_sheet_name,
  source_row_no,
  source_option_line_no,
  channel_code,
  channel_account,
  channel_product_code,
  channel_option_code,
  seller_product_code,
  channel_sku_code,
  own_sku_code_candidate,
  selfpia_sku_candidate,
  product_name,
  option_name,
  option_value,
  sale_status_raw,
  display_status_raw,
  option_status_raw,
  stock_qty_raw,
  normalized_sale_status,
  normalized_display_status,
  normalized_option_status,
  is_active_candidate,
  raw_payload,
  parse_status,
  parse_warning
FROM normalized;

WITH latest_playauto AS (
  SELECT DISTINCT ON (source_system)
    source_file_id
  FROM product_code_stage.ably_playauto_source_file
  WHERE source_system = 'playauto_xlsx'
  ORDER BY source_system, created_at DESC
),
sku_dictionary AS (
  SELECT DISTINCT
    source_file_id,
    NULLIF(btrim(raw_sku_code), '') AS sku_code
  FROM product_code_stage.playauto_sku_raw
  WHERE NULLIF(btrim(raw_sku_code), '') IS NOT NULL
),
base AS (
  SELECT
    p.*,
    CASE p.raw_mall_account
      WHEN '스마트스토어=w_ground' THEN 'smartstore'
      WHEN '에이블리=pink_rocket@naver.com' THEN 'ably'
      WHEN '쿠팡=wworks2010' THEN 'coupang'
      WHEN '카카오톡 스토어=pink_rocket@naver.com' THEN 'kakaotalk_store'
      ELSE 'unknown'
    END AS mapped_channel_code,
    cardinality(regexp_split_to_array(coalesce(p.raw_sku_text, ''), E'\r\n|\n|\r')) AS sku_line_count_raw,
    cardinality(regexp_split_to_array(coalesce(p.raw_option_text, ''), E'\r\n|\n|\r')) AS option_line_count_raw,
    cardinality(regexp_split_to_array(coalesce(p.raw_option_status, ''), E'\r\n|\n|\r')) AS option_status_line_count_raw,
    NULLIF(btrim((regexp_split_to_array(coalesce(p.raw_option_text, ''), E'\r\n|\n|\r'))[1]), '') AS option_header
  FROM product_code_stage.playauto_product_raw AS p
  JOIN latest_playauto AS s
    ON s.source_file_id = p.source_file_id
),
sku_lines AS (
  SELECT
    b.source_file_id,
    b.source_sheet_name,
    b.source_row_no,
    sku.line_no::integer,
    NULLIF(btrim(sku.sku_line), '') AS sku_code
  FROM base AS b
  CROSS JOIN LATERAL regexp_split_to_table(coalesce(b.raw_sku_text, ''), E'\r\n|\n|\r')
    WITH ORDINALITY AS sku(sku_line, line_no)
  WHERE NULLIF(btrim(sku.sku_line), '') IS NOT NULL
),
option_lines AS (
  SELECT
    b.source_file_id,
    b.source_sheet_name,
    b.source_row_no,
    opt.line_no::integer,
    NULLIF(btrim(opt.option_line), '') AS option_line_text
  FROM base AS b
  CROSS JOIN LATERAL regexp_split_to_table(coalesce(b.raw_option_text, ''), E'\r\n|\n|\r')
    WITH ORDINALITY AS opt(option_line, line_no)
),
status_lines AS (
  SELECT
    b.source_file_id,
    b.source_sheet_name,
    b.source_row_no,
    status_line.line_no::integer,
    NULLIF(btrim(status_line.option_status_line), '') AS option_status_line_text
  FROM base AS b
  CROSS JOIN LATERAL regexp_split_to_table(coalesce(b.raw_option_status, ''), E'\r\n|\n|\r')
    WITH ORDINALITY AS status_line(option_status_line, line_no)
),
aligned AS (
  SELECT
    b.*,
    sku.line_no AS sku_line_no,
    sku.sku_code,
    CASE
      WHEN b.option_line_count_raw = b.sku_line_count_raw + 1
       AND b.option_status_line_count_raw = b.sku_line_count_raw
      THEN 'header_option_aligned'
      WHEN b.option_line_count_raw = b.sku_line_count_raw
       AND b.option_status_line_count_raw = b.sku_line_count_raw
      THEN 'direct_aligned'
      ELSE 'line_count_needs_review'
    END AS alignment_status,
    CASE
      WHEN b.option_line_count_raw = b.sku_line_count_raw + 1 THEN sku.line_no + 1
      ELSE sku.line_no
    END AS option_lookup_line_no,
    CASE
      WHEN b.option_status_line_count_raw = b.sku_line_count_raw THEN sku.line_no
      ELSE NULL
    END AS status_lookup_line_no,
    opt.option_line_text,
    status_line.option_status_line_text,
    (d.sku_code IS NOT NULL) AS sku_found_in_dictionary
  FROM base AS b
  JOIN sku_lines AS sku
    ON sku.source_file_id = b.source_file_id
   AND sku.source_sheet_name = b.source_sheet_name
   AND sku.source_row_no = b.source_row_no
  LEFT JOIN option_lines AS opt
    ON opt.source_file_id = b.source_file_id
   AND opt.source_sheet_name = b.source_sheet_name
   AND opt.source_row_no = b.source_row_no
   AND opt.line_no = CASE
      WHEN b.option_line_count_raw = b.sku_line_count_raw + 1 THEN sku.line_no + 1
      ELSE sku.line_no
    END
  LEFT JOIN status_lines AS status_line
    ON status_line.source_file_id = b.source_file_id
   AND status_line.source_sheet_name = b.source_sheet_name
   AND status_line.source_row_no = b.source_row_no
   AND status_line.line_no = CASE
      WHEN b.option_status_line_count_raw = b.sku_line_count_raw THEN sku.line_no
      ELSE NULL
    END
  LEFT JOIN sku_dictionary AS d
    ON d.source_file_id = b.source_file_id
   AND d.sku_code = sku.sku_code
),
normalized AS (
  SELECT
    source_file_id,
    'playauto_xlsx'::text AS source_system,
    source_sheet_name,
    source_row_no,
    sku_line_no AS source_option_line_no,
    mapped_channel_code AS channel_code,
    raw_mall_account AS channel_account,
    NULLIF(btrim(raw_mall_product_no), '') AS channel_product_code,
    NULL::text AS channel_option_code,
    NULLIF(btrim(raw_seller_management_code), '') AS seller_product_code,
    sku_code AS channel_sku_code,
    sku_code AS own_sku_code_candidate,
    CASE WHEN sku_code ILIKE 'sellpia_%' THEN sku_code ELSE NULL END AS selfpia_sku_candidate,
    NULLIF(btrim(raw_online_product_name), '') AS product_name,
    option_header AS option_name,
    option_line_text AS option_value,
    raw_product_status AS sale_status_raw,
    NULL::text AS display_status_raw,
    option_status_line_text AS option_status_raw,
    raw_option_sale_qty AS stock_qty_raw,
    CASE
      WHEN raw_product_status = '판매중' THEN 'active'
      WHEN raw_product_status IN ('판매대기', '수정대기', '승인대기', '일시품절', '판매중지') THEN 'inactive'
      ELSE 'needs_review'
    END AS normalized_sale_status,
    NULL::text AS normalized_display_status,
    CASE
      WHEN option_status_line_text = 'Y' THEN 'active'
      WHEN option_status_line_text = 'N' THEN 'inactive'
      ELSE 'needs_review'
    END AS normalized_option_status,
    (
      raw_product_status = '판매중'
      AND option_status_line_text = 'Y'
      AND mapped_channel_code <> 'unknown'
      AND sku_found_in_dictionary
      AND alignment_status IN ('header_option_aligned', 'direct_aligned')
    ) AS is_active_candidate,
    raw_payload || jsonb_build_object(
      'normalized_from', 'playauto_product_raw',
      'sku_line_no', sku_line_no,
      'sku_line_count_raw', sku_line_count_raw,
      'option_line_count_raw', option_line_count_raw,
      'option_status_line_count_raw', option_status_line_count_raw,
      'option_lookup_line_no', option_lookup_line_no,
      'status_lookup_line_no', status_lookup_line_no,
      'alignment_status', alignment_status,
      'sku_found_in_dictionary', sku_found_in_dictionary
    ) AS raw_payload,
    CASE
      WHEN mapped_channel_code = 'unknown'
        OR NULLIF(btrim(raw_mall_product_no), '') IS NULL
        OR sku_code IS NULL
        OR option_line_text IS NULL
        OR alignment_status = 'line_count_needs_review'
        OR NOT sku_found_in_dictionary THEN 'warning'
      ELSE 'ok'
    END AS parse_status,
    NULLIF(
      concat_ws(
        '; ',
        CASE WHEN mapped_channel_code = 'unknown' THEN 'unknown channel mapping from raw_mall_account' END,
        CASE WHEN NULLIF(btrim(raw_mall_product_no), '') IS NULL THEN 'missing channel_product_code' END,
        CASE WHEN sku_code IS NULL THEN 'missing sku line' END,
        CASE WHEN option_line_text IS NULL THEN 'missing aligned option line' END,
        CASE WHEN alignment_status = 'line_count_needs_review'
          THEN concat('line count needs review: sku=', sku_line_count_raw, ', option=', option_line_count_raw, ', status=', option_status_line_count_raw)
        END,
        CASE WHEN NOT sku_found_in_dictionary THEN 'sku not found in SKU상품 dictionary' END
      ),
      ''
    ) AS parse_warning
  FROM aligned
)
INSERT INTO product_code_stage.channel_option_evidence (
  source_file_id,
  source_system,
  source_sheet_name,
  source_row_no,
  source_option_line_no,
  channel_code,
  channel_account,
  channel_product_code,
  channel_option_code,
  seller_product_code,
  channel_sku_code,
  own_sku_code_candidate,
  selfpia_sku_candidate,
  product_name,
  option_name,
  option_value,
  sale_status_raw,
  display_status_raw,
  option_status_raw,
  stock_qty_raw,
  normalized_sale_status,
  normalized_display_status,
  normalized_option_status,
  is_active_candidate,
  raw_payload,
  parse_status,
  parse_warning
)
SELECT
  source_file_id,
  source_system,
  source_sheet_name,
  source_row_no,
  source_option_line_no,
  channel_code,
  channel_account,
  channel_product_code,
  channel_option_code,
  seller_product_code,
  channel_sku_code,
  own_sku_code_candidate,
  selfpia_sku_candidate,
  product_name,
  option_name,
  option_value,
  sale_status_raw,
  display_status_raw,
  option_status_raw,
  stock_qty_raw,
  normalized_sale_status,
  normalized_display_status,
  normalized_option_status,
  is_active_candidate,
  raw_payload,
  parse_status,
  parse_warning
FROM normalized;

DO $result_guard$
DECLARE
  ably_count bigint;
  playauto_count bigint;
  playauto_channel_count bigint;
BEGIN
  SELECT COUNT(*) INTO ably_count
  FROM product_code_stage.channel_option_evidence
  WHERE source_system = 'ably_csv';

  SELECT COUNT(*) INTO playauto_count
  FROM product_code_stage.channel_option_evidence
  WHERE source_system = 'playauto_xlsx';

  SELECT COUNT(*) INTO playauto_channel_count
  FROM product_code_stage.channel_option_evidence
  WHERE channel_code = 'playauto';

  IF ably_count <> 9158 THEN
    RAISE EXCEPTION 'Ably evidence row count mismatch: %, expected 9158', ably_count;
  END IF;

  IF playauto_count <> 32082 THEN
    RAISE EXCEPTION 'PlayAuto evidence row count mismatch: %, expected 32082', playauto_count;
  END IF;

  IF playauto_channel_count <> 0 THEN
    RAISE EXCEPTION 'blocked: channel_code=playauto evidence rows exist: %', playauto_channel_count;
  END IF;
END
$result_guard$;

SELECT
  'channel_option_evidence_apply_summary'::text AS section,
  COUNT(*)::bigint AS total_evidence_rows,
  COUNT(*) FILTER (WHERE source_system = 'ably_csv')::bigint AS ably_evidence_rows,
  COUNT(*) FILTER (WHERE source_system = 'playauto_xlsx')::bigint AS playauto_evidence_rows,
  COUNT(*) FILTER (WHERE channel_code = 'playauto')::bigint AS playauto_channel_code_rows,
  COUNT(*) FILTER (WHERE parse_status = 'warning')::bigint AS warning_rows,
  'PASS'::text AS apply_verdict
FROM product_code_stage.channel_option_evidence
WHERE source_system IN ('ably_csv', 'playauto_xlsx');

COMMIT;
