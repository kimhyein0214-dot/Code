-- =============================================================================
-- export_unmatched_selfpia_product_review_candidates_v1.sql
--
-- Purpose:
--   Export Excel review candidates for unmatched Selfpia SKUs/products.
--   This is a review-candidate list, not a confirmed removal list.
--
-- Target:
--   Local Docker PostgreSQL database only: product_ops_test
--
-- Output:
--   /exports/unmatched_selfpia_product_review_candidates_v1.csv
--   The Docker compose volume maps /exports to local exports/.
--
-- Safety:
--   - psql product_ops_test guard.
--   - SELECT-based COPY export only.
--   - No persistent database changes.
--   - Ably/PlayAuto are marked source_not_loaded because their source stage
--     import is not part of the final matching basis for this export.
--   - Selfpia/own SKU code columns are exported as Excel-safe text formulas
--     so values such as 2234-07-01 do not auto-convert to dates.
-- =============================================================================

\set ON_ERROR_STOP on
\pset pager off

SELECT current_database() = 'product_ops_test' AS product_ops_test_guard \gset
\if :product_ops_test_guard
\else
  \echo Refusing export: current database is not product_ops_test.
  \quit 1
\endif

COPY (
WITH sku_base AS (
  SELECT DISTINCT ON (v.sku_id)
    v.sku_id,
    v.product_id,
    v.selfpia_product_code,
    v.selfpia_sku_code,
    v.product_name,
    '옵션'::text AS option_name,
    v.option_value,
    v.sku_status
  FROM product_code.v_sku_canonical AS v
  WHERE v.sku_id IS NOT NULL
    AND NULLIF(btrim(COALESCE(v.selfpia_sku_code, '')), '') IS NOT NULL
  ORDER BY v.sku_id, v.selfpia_sku_code NULLS LAST
),
own_sku_state AS (
  SELECT
    ca.target_id AS sku_id,
    string_agg(DISTINCT ca.code_value, ', ' ORDER BY ca.code_value) AS own_sku_code,
    count(DISTINCT ca.code_value) AS own_sku_count
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.target_id
),
smartstore_sku_state AS (
  SELECT
    ca.target_id AS sku_id,
    count(*) FILTER (
      WHERE ca.code_system IN ('smartstore_product_no', 'smartstore_option_no')
    ) AS confirmed_count,
    count(*) FILTER (
      WHERE ca.code_system IN ('smartstore_product_no_candidate', 'smartstore_option_no_candidate')
    ) AS candidate_count
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system IN (
      'smartstore_product_no',
      'smartstore_option_no',
      'smartstore_product_no_candidate',
      'smartstore_option_no_candidate'
    )
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.target_id
),
smartstore_product_state AS (
  SELECT
    ca.target_id AS product_id,
    count(*) FILTER (WHERE ca.code_system = 'smartstore_product_no') AS confirmed_count,
    count(*) FILTER (WHERE ca.code_system = 'smartstore_product_no_candidate') AS candidate_count
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'PRODUCT'
    AND ca.code_system IN ('smartstore_product_no', 'smartstore_product_no_candidate')
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.target_id
),
makeshop_state AS (
  SELECT
    scm.sku_id,
    count(*) AS mapping_count
  FROM product_code.sku_channel_mapping AS scm
  WHERE lower(scm.channel_code) = 'makeshop'
    AND scm.sku_id IS NOT NULL
  GROUP BY scm.sku_id
),
image_by_sku AS (
  SELECT
    pi.sku_id,
    count(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(pi.image_url, '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(pi.thumbnail_url, '')), '') IS NOT NULL
    ) AS image_count
  FROM product_code.product_image AS pi
  WHERE pi.sku_id IS NOT NULL
  GROUP BY pi.sku_id
),
image_by_product AS (
  SELECT
    pi.product_id,
    count(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(pi.image_url, '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(pi.thumbnail_url, '')), '') IS NOT NULL
    ) AS image_count
  FROM product_code.product_image AS pi
  WHERE pi.product_id IS NOT NULL
  GROUP BY pi.product_id
),
classified AS (
  SELECT
    s.*,
    COALESCE(o.own_sku_code, '') AS own_sku_code,
    COALESCE(o.own_sku_count, 0) AS own_sku_count,
    COALESCE(ss.confirmed_count, 0) + COALESCE(sp.confirmed_count, 0) AS smartstore_confirmed_count,
    COALESCE(ss.candidate_count, 0) + COALESCE(sp.candidate_count, 0) AS smartstore_candidate_count,
    COALESCE(m.mapping_count, 0) AS makeshop_mapping_count,
    COALESCE(ibs.image_count, ibp.image_count, 0) AS image_count
  FROM sku_base AS s
  LEFT JOIN own_sku_state AS o
    ON o.sku_id = s.sku_id
  LEFT JOIN smartstore_sku_state AS ss
    ON ss.sku_id = s.sku_id
  LEFT JOIN smartstore_product_state AS sp
    ON sp.product_id = s.product_id
  LEFT JOIN makeshop_state AS m
    ON m.sku_id = s.sku_id
  LEFT JOIN image_by_sku AS ibs
    ON ibs.sku_id = s.sku_id
  LEFT JOIN image_by_product AS ibp
    ON ibp.product_id = s.product_id
),
review_candidates AS (
  SELECT
    CASE
      WHEN own_sku_count <> 1 AND image_count = 0 THEN 'P1_높음'
      WHEN own_sku_count <> 1 THEN 'P1_높음'
      WHEN image_count = 0 THEN 'P2_중간'
      ELSE 'P3_낮음'
    END AS review_priority,
    selfpia_product_code,
    selfpia_sku_code,
    product_id,
    sku_id,
    product_name,
    option_name,
    option_value,
    NULLIF(own_sku_code, '') AS own_sku_code,
    CASE
      WHEN smartstore_confirmed_count > 0 THEN 'confirmed_connected'
      WHEN smartstore_candidate_count > 0 THEN 'candidate_only_not_confirmed'
      ELSE 'no_connection'
    END AS smartstore_status,
    CASE
      WHEN makeshop_mapping_count > 0 THEN 'connected'
      ELSE 'no_connection'
    END AS makeshop_status,
    'source_not_loaded'::text AS ably_playauto_status,
    CASE
      WHEN image_count > 0 THEN 'has_image'
      ELSE 'missing_image'
    END AS image_status,
    CASE
      WHEN own_sku_count = 0 AND image_count = 0
        THEN 'no_confirmed_smartstore_and_no_makeshop_mapping; own_sku_missing; image_missing'
      WHEN own_sku_count = 0
        THEN 'no_confirmed_smartstore_and_no_makeshop_mapping; own_sku_missing'
      WHEN own_sku_count > 1 AND image_count = 0
        THEN 'no_confirmed_smartstore_and_no_makeshop_mapping; own_sku_ambiguous; image_missing'
      WHEN own_sku_count > 1
        THEN 'no_confirmed_smartstore_and_no_makeshop_mapping; own_sku_ambiguous'
      WHEN image_count = 0
        THEN 'no_confirmed_smartstore_and_no_makeshop_mapping; image_missing'
      ELSE 'channel_absent_or_inactive_possible'
    END AS unmatched_reason,
    '삭제 확정 아님. 과거 판매 이력, 미운영/비노출 상품, 판매처 원본자료 미반영 상품이 섞일 수 있음. Ably/PlayAuto는 source_not_loaded로 최종 판단에서 제외.'::text AS caution_note,
    ''::text AS review_result,
    ''::text AS reviewer_note
  FROM classified
  WHERE smartstore_confirmed_count = 0
    AND makeshop_mapping_count = 0
),
excel_export AS (
  SELECT
    review_priority,
    CASE
      WHEN selfpia_product_code IS NULL THEN NULL
      ELSE '="' || replace(selfpia_product_code, '"', '""') || '"'
    END AS selfpia_product_code,
    CASE
      WHEN selfpia_sku_code IS NULL THEN NULL
      ELSE '="' || replace(selfpia_sku_code, '"', '""') || '"'
    END AS selfpia_sku_code,
    product_id,
    sku_id,
    product_name,
    option_name,
    option_value,
    CASE
      WHEN own_sku_code IS NULL THEN NULL
      ELSE '="' || replace(own_sku_code, '"', '""') || '"'
    END AS own_sku_code,
    smartstore_status,
    makeshop_status,
    ably_playauto_status,
    image_status,
    unmatched_reason,
    caution_note,
    review_result,
    reviewer_note
  FROM review_candidates
)
SELECT
  review_priority AS "검토우선순위",
  selfpia_product_code AS "셀피아상품코드",
  selfpia_sku_code AS "셀피아SKU코드",
  product_id AS "상품ID",
  sku_id AS "SKUID",
  product_name AS "상품명",
  option_name AS "옵션명",
  option_value AS "옵션값",
  own_sku_code AS "자사코드",
  smartstore_status AS "스마트스토어연결상태",
  makeshop_status AS "메이크샵연결상태",
  ably_playauto_status AS "에이블리_플레이오토상태",
  image_status AS "이미지연결상태",
  unmatched_reason AS "미연결사유",
  caution_note AS "주의메모",
  review_result AS "삭제검토결과",
  reviewer_note AS "검토자메모"
FROM excel_export
ORDER BY
  CASE review_priority
    WHEN 'P1_높음' THEN 1
    WHEN 'P2_중간' THEN 2
    ELSE 3
  END,
  selfpia_product_code NULLS LAST,
  selfpia_sku_code NULLS LAST,
  product_id,
  sku_id
) TO '/exports/unmatched_selfpia_product_review_candidates_v1.csv' WITH (FORMAT CSV, HEADER true, ENCODING 'UTF8');

WITH sku_base AS (
  SELECT DISTINCT ON (v.sku_id)
    v.sku_id,
    v.product_id,
    v.selfpia_sku_code
  FROM product_code.v_sku_canonical AS v
  WHERE v.sku_id IS NOT NULL
    AND NULLIF(btrim(COALESCE(v.selfpia_sku_code, '')), '') IS NOT NULL
  ORDER BY v.sku_id, v.selfpia_sku_code NULLS LAST
),
own_sku_state AS (
  SELECT ca.target_id AS sku_id, count(DISTINCT ca.code_value) AS own_sku_count
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.target_id
),
smartstore_sku_state AS (
  SELECT
    ca.target_id AS sku_id,
    count(*) FILTER (
      WHERE ca.code_system IN ('smartstore_product_no', 'smartstore_option_no')
    ) AS confirmed_count,
    count(*) FILTER (
      WHERE ca.code_system IN ('smartstore_product_no_candidate', 'smartstore_option_no_candidate')
    ) AS candidate_count
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system IN (
      'smartstore_product_no',
      'smartstore_option_no',
      'smartstore_product_no_candidate',
      'smartstore_option_no_candidate'
    )
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.target_id
),
smartstore_product_state AS (
  SELECT
    ca.target_id AS product_id,
    count(*) FILTER (WHERE ca.code_system = 'smartstore_product_no') AS confirmed_count,
    count(*) FILTER (WHERE ca.code_system = 'smartstore_product_no_candidate') AS candidate_count
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'PRODUCT'
    AND ca.code_system IN ('smartstore_product_no', 'smartstore_product_no_candidate')
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.target_id
),
makeshop_state AS (
  SELECT scm.sku_id, count(*) AS mapping_count
  FROM product_code.sku_channel_mapping AS scm
  WHERE lower(scm.channel_code) = 'makeshop'
    AND scm.sku_id IS NOT NULL
  GROUP BY scm.sku_id
),
image_by_sku AS (
  SELECT
    pi.sku_id,
    count(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(pi.image_url, '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(pi.thumbnail_url, '')), '') IS NOT NULL
    ) AS image_count
  FROM product_code.product_image AS pi
  WHERE pi.sku_id IS NOT NULL
  GROUP BY pi.sku_id
),
image_by_product AS (
  SELECT
    pi.product_id,
    count(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(pi.image_url, '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(pi.thumbnail_url, '')), '') IS NOT NULL
    ) AS image_count
  FROM product_code.product_image AS pi
  WHERE pi.product_id IS NOT NULL
  GROUP BY pi.product_id
),
classified AS (
  SELECT
    s.sku_id,
    COALESCE(o.own_sku_count, 0) AS own_sku_count,
    COALESCE(ss.confirmed_count, 0) + COALESCE(sp.confirmed_count, 0) AS smartstore_confirmed_count,
    COALESCE(ss.candidate_count, 0) + COALESCE(sp.candidate_count, 0) AS smartstore_candidate_count,
    COALESCE(m.mapping_count, 0) AS makeshop_mapping_count,
    COALESCE(ibs.image_count, ibp.image_count, 0) AS image_count
  FROM sku_base AS s
  LEFT JOIN own_sku_state AS o
    ON o.sku_id = s.sku_id
  LEFT JOIN smartstore_sku_state AS ss
    ON ss.sku_id = s.sku_id
  LEFT JOIN smartstore_product_state AS sp
    ON sp.product_id = s.product_id
  LEFT JOIN makeshop_state AS m
    ON m.sku_id = s.sku_id
  LEFT JOIN image_by_sku AS ibs
    ON ibs.sku_id = s.sku_id
  LEFT JOIN image_by_product AS ibp
    ON ibp.product_id = s.product_id
),
review_candidates AS (
  SELECT
    CASE
      WHEN own_sku_count <> 1 AND image_count = 0 THEN 'P1_높음'
      WHEN own_sku_count <> 1 THEN 'P1_높음'
      WHEN image_count = 0 THEN 'P2_중간'
      ELSE 'P3_낮음'
    END AS review_priority,
    CASE
      WHEN smartstore_confirmed_count > 0 THEN 'confirmed_connected'
      WHEN smartstore_candidate_count > 0 THEN 'candidate_only_not_confirmed'
      ELSE 'no_connection'
    END AS smartstore_status,
    CASE WHEN makeshop_mapping_count > 0 THEN 'connected' ELSE 'no_connection' END AS makeshop_status
  FROM classified
  WHERE smartstore_confirmed_count = 0
    AND makeshop_mapping_count = 0
)
SELECT 'row_count' AS summary_type, 'all' AS bucket_1, NULL::text AS bucket_2, count(*) AS row_count
FROM review_candidates
UNION ALL
SELECT 'review_priority', review_priority, NULL::text, count(*)
FROM review_candidates
GROUP BY review_priority
UNION ALL
SELECT 'smartstore_makeshop_status', smartstore_status, makeshop_status, count(*)
FROM review_candidates
GROUP BY smartstore_status, makeshop_status
ORDER BY summary_type, bucket_1, bucket_2;
