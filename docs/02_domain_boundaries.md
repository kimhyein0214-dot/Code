# Domain Boundaries

## 경계 원칙

각 모듈은 자기 업무 상태만 소유한다. 다른 모듈의 데이터를 직접 수정하지 않는다. 필요한 참조는 `sku_id`, `order_item_id`, `ticket_id` 같은 안정된 키로 연결한다.

## 소유권

| 데이터 | 소유 모듈 | 읽는 모듈 | 쓰는 모듈 |
|---|---|---|---|
| SKU master | 상품관리 | 전체 | change request 승인자 |
| code alias | 상품관리/채널상품관리 | 전체 | change request 또는 연동 job |
| channel mapping | 채널상품관리 | 상품관리, CS | 채널상품관리 |
| orders/order_items | 주문/피킹 | 검품, CS | 주문/피킹/연동 |
| picking tasks | 주문/피킹 | 검품, CS | 주문/피킹 |
| inspections | 검품 | 주문/피킹, CS | 검품 |
| tickets/events | CS/미송 | 주문/피킹, 검품 | CS/미송 |
| scraper/sync state | 연동/설정 | 관리자 | 연동/설정 |
| audit log | 플랫폼 | 관리자 | API 서버 |

## 연결 지점

- 상품관리 -> 모든 모듈: `sku_id`, `code_alias`
- 주문/피킹 -> 검품: `order_item_id`
- 주문/피킹 -> CS: `order_id`, `order_item_id`, `raw_p_code`
- 채널상품관리 -> CS: channel item/seller product lookup
- 연동/설정 -> 상품/주문: sync job output

## 주문 Lifecycle 참조

주문, 피킹, 검품, CS는 같은 주문상품을 참조하지만 상태 전이 책임은 분리한다. 주문 수집부터 배송완료까지의 상태 흐름, 소유 모듈, 읽고 쓰는 테이블, 금지 전이는 `docs/13_order_lifecycle.md`를 기준으로 한다.

핵심 연결:

- 연동/설정은 주문 수집과 sync run을 소유한다.
- 주문/피킹은 주문상품 생성, master 매칭, 피킹 상태를 소유한다.
- 검품은 검품대기/검품완료/보류 상태를 소유한다.
- CS는 ticket과 미송/고객 응대 상태를 소유한다.
- 상태 전이는 각 모듈 API service layer에서만 수행한다.

## 금지

- CS 모듈이 SKU master를 직접 수정하지 않는다.
- 피킹 화면에서 상품 master를 편집하지 않는다.
- 검품 화면에서 주문 원장을 수정하지 않는다.
- 연동 모듈이 audit 없이 운영 테이블을 덮어쓰지 않는다.

## 지금 만들 것

- domain별 API namespace
- shared lookup service
- audit event 공통 포맷

## 나중에 만들 것

- event-driven sync
- 승인 workflow
- module별 data retention policy
