# CS Module

## 책임

CS/미송 모듈은 결품, 미송, 고객 문의, 교환/반품/환불 요청을 ticket과 event로 관리한다. 현재 원본은 `cs_templates` 외 실운영 ticket 구조가 약하므로 신규 설계 영역으로 분리한다.

## 소유 화면

- `/cs`
- `/cs/tickets`
- `/cs/tickets/:ticketId`
- `/cs/shortage`
- `/cs/templates`

PC 관리자용 화면이다.

## 호출 API

- `GET /api/cs/tickets`
- `POST /api/cs/tickets`
- `GET /api/cs/tickets/:ticketId`
- `POST /api/cs/tickets/:ticketId/events`
- `GET /api/cs/templates`
- `POST /api/cs/templates`
- `GET /api/cs/shortage`

## 읽는 데이터

- `cs.tickets`
- `cs.ticket_events`
- `cs.templates`
- `picking.orders`
- `picking.order_items`
- `picking.shortage`
- `product_code.v_sku_canonical`

## 쓰는 데이터

- `cs.tickets`
- `cs.ticket_events`
- `cs.templates`
- `picking.shortage.cs_memo`는 직접 수정 대신 CS event에서 동기화할지 확인 필요
- `audit.row_changes`

## 다른 모듈과 연결

- 주문/피킹: 결품/보류/미송 상태를 ticket으로 연결
- 검품: fail/hold 결과를 CS로 연결
- 상품관리: 문의 상품 lookup
- 연동/설정: 택배사/채널 CS 연동

## 지금 만들 것

- ticket list/detail
- shortage queue
- template read
- event append API

## 나중에 만들 것

- 외부 CS/택배/환불 시스템 연동
- SLA/status 자동화
- message template 변수 치환
- 고객 응대 이력 검색

