# Inspection Module

## 책임

검품 모듈은 피킹 완료 후 상품 검수 결과를 기록한다. 현재 원본 `inspection`과 `hold_items`는 0건이므로 legacy 이관보다 신규 업무 설계를 우선한다.

## 소유 화면

- `/inspection`
- `/inspection/queue`
- `/inspection/items/:orderItemId`
- `/inspection/history`

태블릿/PC 혼합 화면이다. 현장 검품은 태블릿, 이력/리포트는 PC가 적합하다.

## 호출 API

- `GET /api/inspection/queue`
- `GET /api/inspection/items/:orderItemId`
- `POST /api/inspection/items/:orderItemId/pass`
- `POST /api/inspection/items/:orderItemId/fail`
- `POST /api/inspection/items/:orderItemId/hold`
- `GET /api/inspection/history`

## 읽는 데이터

- `picking.order_items`
- `picking.picking_tasks`
- `inspection.inspections`
- `product_code.v_sku_canonical`

## 쓰는 데이터

- `inspection.inspections`
- 필요 시 `picking.hold_items`
- `audit.row_changes`

## 다른 모듈과 연결

- 주문/피킹: 피킹 완료 라인을 검품 queue로 받는다.
- CS/미송: 검품 실패/보류는 CS ticket 또는 hold로 이어질 수 있다.
- 상품관리: SKU/옵션/이미지 조회.

## 지금 만들 것

- 검품 queue 조회
- pass/fail/hold 기록 API
- 검품 이력 read view

## 나중에 만들 것

- 검품 사진 저장
- 불량 사유 표준화
- 작업자별 검품 통계
- CS 자동 ticket 생성

