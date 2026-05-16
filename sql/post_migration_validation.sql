-- =============================================================================
-- post_migration_validation.sql
-- 대상: NAS PostgreSQL (이전 후 검증용)
-- 목적: row count / 키 무결성 / 매칭률 / 누락치 점검
-- 주의: SELECT-only. 데이터 변경 없음.
-- 사용 시점: NAS 로 데이터 이전 완료 직후, Docker API 서버 트래픽 전환 전.
-- =============================================================================

-- ============================================================
-- [V-0] DB 컨텍스트
-- ============================================================
SELECT current_database() AS db, current_user AS usr, version() AS pgver, now() AS checked_at;

-- ============================================================
-- [V-1] schema 존재 확인
-- ============================================================
SELECT nspname
FROM pg_namespace
WHERE nspname IN ('product_code','picking','inspection','cs','audit','stg')
ORDER BY 1;

-- ============================================================
-- [V-2] 통합 후 vs 원본 row count 비교
-- 원본 사전조사 [P-4][K-3] 결과와 대조용. 아래 값은 *예시*. 실제 테이블명으로 치환.
-- ============================================================
SELECT 'product_code.sku_master'           AS tbl, count(*) FROM product_code.sku_master
UNION ALL SELECT 'product_code.sku_channel_mapping', count(*) FROM product_code.sku_channel_mapping
UNION ALL SELECT 'product_code.sku_bundle',          count(*) FROM product_code.sku_bundle
UNION ALL SELECT 'picking.orders',                   count(*) FROM picking.orders
UNION ALL SELECT 'picking.order_items',              count(*) FROM picking.order_items
UNION ALL SELECT 'picking.picking_tasks',            count(*) FROM picking.picking_tasks
UNION ALL SELECT 'inspection.inspections',           count(*) FROM inspection.inspections
UNION ALL SELECT 'cs.tickets',                       count(*) FROM cs.tickets
UNION ALL SELECT 'cs.ticket_events',                 count(*) FROM cs.ticket_events;

-- ============================================================
-- [V-3] master 무결성: 중복 PK / NULL PK
-- ============================================================
SELECT 'master_null_pk'  AS check_name, count(*) AS n
FROM product_code.sku_master WHERE selfpia_sku_code IS NULL
UNION ALL
SELECT 'master_dup_pk',                 count(*) - count(DISTINCT selfpia_sku_code)
FROM product_code.sku_master;

-- ============================================================
-- [V-4] channel mapping 무결성
-- ============================================================
SELECT 'mapping_orphan_master' AS check_name, count(*) AS n
FROM product_code.sku_channel_mapping m
LEFT JOIN product_code.sku_master s ON m.selfpia_sku_code = s.selfpia_sku_code
WHERE s.selfpia_sku_code IS NULL
UNION ALL
SELECT 'mapping_dup_channel_csku',
       count(*) - count(DISTINCT (channel_code, channel_sku_code))
FROM product_code.sku_channel_mapping
WHERE channel_sku_code IS NOT NULL;

-- ============================================================
-- [V-5] 주문상품 → master FK 연결률 (NAS 통합 후 100% 기대)
-- ============================================================
WITH base AS (
  SELECT
    count(*) AS total_lines,
    count(*) FILTER (WHERE selfpia_sku_code IS NULL)                       AS null_sku_lines,
    count(*) FILTER (
      WHERE selfpia_sku_code NOT IN (SELECT selfpia_sku_code FROM product_code.sku_master)
    ) AS orphan_sku_lines
  FROM picking.order_items
)
SELECT
  total_lines,
  null_sku_lines,
  orphan_sku_lines,
  round(100.0 * (total_lines - null_sku_lines - orphan_sku_lines) / NULLIF(total_lines,0), 2) AS match_rate_pct
FROM base;

-- ============================================================
-- [V-6] 주문 → 주문상품 정합성
-- ============================================================
SELECT 'orders_without_items' AS check_name, count(*) AS n
FROM picking.orders o
LEFT JOIN picking.order_items i ON i.order_id = o.order_id
WHERE i.order_id IS NULL
UNION ALL
SELECT 'items_without_order',
       count(*)
FROM picking.order_items i
LEFT JOIN picking.orders o ON o.order_id = i.order_id
WHERE o.order_id IS NULL;

-- ============================================================
-- [V-7] picking_tasks 무결성
-- ============================================================
SELECT 'tasks_orphan_oitem' AS check_name, count(*) AS n
FROM picking.picking_tasks pt
LEFT JOIN picking.order_items oi ON oi.order_item_id = pt.order_item_id
WHERE oi.order_item_id IS NULL
UNION ALL
SELECT 'tasks_status_unknown',
       count(*)
FROM picking.picking_tasks
WHERE status NOT IN ('queued','in_progress','picked','exception');

-- ============================================================
-- [V-8] 검품 / CS 무결성
-- ============================================================
SELECT 'inspections_orphan' AS check_name, count(*) AS n
FROM inspection.inspections ins
LEFT JOIN picking.order_items oi ON oi.order_item_id = ins.order_item_id
WHERE oi.order_item_id IS NULL
UNION ALL
SELECT 'tickets_orphan_order',
       count(*)
FROM cs.tickets t
LEFT JOIN picking.orders o ON o.order_id = t.order_id
WHERE t.order_id IS NOT NULL AND o.order_id IS NULL;

-- ============================================================
-- [V-9] 주문 상태 분포 (이전 후 비정상 상태 출현 여부 확인)
-- ============================================================
SELECT status, count(*) AS n
FROM picking.orders
GROUP BY 1
ORDER BY n DESC;

-- ============================================================
-- [V-10] 인덱스 / PK 존재 확인 (운영 적용 후 빠진 인덱스 점검)
-- ============================================================
SELECT
  schemaname, tablename, indexname
FROM pg_indexes
WHERE schemaname IN ('product_code','picking','inspection','cs','audit')
ORDER BY 1,2,3;

-- ============================================================
-- [V-11] 권한 점검: app_api 가 무엇을 SELECT/INSERT 가능한지
-- ============================================================
SELECT
  grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'app_api'
ORDER BY table_schema, table_name, privilege_type;

-- ============================================================
-- [V-12] 시퀀스 최댓값 vs 시퀀스 currval (이전 시 ID 충돌 방지)
-- ============================================================
SELECT
  sequence_schema || '.' || sequence_name AS seq,
  last_value
FROM (
  SELECT
    s.relname AS sequence_name,
    n.nspname AS sequence_schema,
    (SELECT last_value FROM pg_sequences WHERE schemaname = n.nspname AND sequencename = s.relname) AS last_value
  FROM pg_class s
  JOIN pg_namespace n ON n.oid = s.relnamespace
  WHERE s.relkind = 'S'
    AND n.nspname IN ('product_code','picking','inspection','cs','audit')
) q
ORDER BY 1;
