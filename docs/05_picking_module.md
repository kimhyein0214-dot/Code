# Picking Module

## 책임

주문/피킹 모듈은 주문, 주문상품, 피킹 작업, 결품/보류의 운영 상태를 관리한다. 태블릿 현장 사용이 핵심이며 빠른 조회와 단순한 행동 버튼이 중요하다.

## 소유 화면

- `/picking`
- `/picking/orders`
- `/picking/tasks`
- `/picking/tasks/:taskId`
- `/picking/shortage`
- `/picking/holds`

태블릿 현장용 화면이 중심이며, 일부 PC 관리자 조회 화면을 둘 수 있다.

## 호출 API

- `GET /api/picking/orders`
- `GET /api/picking/order-items`
- `GET /api/picking/tasks`
- `POST /api/picking/tasks/:taskId/start`
- `POST /api/picking/tasks/:taskId/complete`
- `POST /api/picking/tasks/:taskId/exception`
- `POST /api/picking/shortage`
- `POST /api/picking/holds`

## 읽는 데이터

- `picking.orders`
- `picking.order_items`
- `picking.picking_tasks`
- `picking.shortage`
- `picking.hold_items`
- `product_code.v_sku_canonical`

## 쓰는 데이터

- `picking.picking_tasks`
- `picking.shortage`
- `picking.hold_items`
- `picking.order_items.master_match_status`는 ETL/mapping workflow에서만 변경
- `audit.row_changes`

## 다른 모듈과 연결

- 상품관리: SKU/alias lookup
- 검품: 피킹 완료 라인을 검품으로 전달
- CS/미송: 결품, 미송, 보류 상태 전달
- 연동/설정: 주문 수집 job에서 order/order_items 생성

## 지금 만들 것

- 태블릿 피킹 task list
- 피킹 시작/완료/예외 API
- 결품 등록
- raw_p_code 보존과 master_match_status 표시

## 나중에 만들 것

- barcode/QR scanner 최적화
- offline queue
- 작업자별 workload
- wave picking

