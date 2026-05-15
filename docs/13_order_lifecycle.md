# Order Lifecycle

## 목적

주문, 피킹, 검품, CS/미송은 같은 주문상품을 바라보지만 소유 모듈과 상태 전이 책임은 분리한다. 이 문서는 주문 수집부터 배송완료까지 상태 흐름, 소유 모듈, 읽고 쓰는 테이블, 금지 전이를 정의한다.

## 핵심 원칙

- 주문 원본 값은 보존한다.
- `raw_p_code`는 삭제하거나 덮어쓰지 않는다.
- master 매칭 실패는 주문을 버리는 사유가 아니라 상태로 격리한다.
- 피킹 화면은 상품 master를 직접 수정하지 않는다.
- 검품 화면은 주문 원본을 직접 수정하지 않는다.
- CS는 주문/검품 상태를 참고하지만 임의로 피킹 완료나 검품 완료를 만들지 않는다.
- 상태 전이는 API 서버 service layer에서만 수행한다.

## Lifecycle

| 단계 | 대표 상태 | 소유 모듈 | 읽는 테이블 | 쓰는 테이블 |
|---|---|---|---|---|
| 주문 수집 | `imported` | 연동/설정 | `integration.sync_job_runs`, 외부 파일 | `picking.orders`, `picking.order_items`, `audit.domain_events` |
| 주문상품 생성 | `created` | 주문/피킹 | `picking.orders`, import payload | `picking.order_items` |
| master 매칭 | `matched`, `unmatched`, `ambiguous`, `legacy_unmatched` | 주문/피킹 | `product_code.code_alias`, `product_code.sku_master` | `picking.order_items.master_match_status`, `stg.unmatched_order_items` |
| 피킹대기 | `picking_pending` | 주문/피킹 | `picking.order_items`, `product_code.v_sku_canonical` | `picking.picking_tasks` |
| 피킹중 | `picking_in_progress` | 주문/피킹 | `picking.picking_tasks` | `picking.picking_tasks`, `audit.domain_events` |
| 피킹완료 | `picking_completed` | 주문/피킹 | `picking.picking_tasks` | `picking.picking_tasks`, `picking.order_items` |
| 검품대기 | `inspection_pending` | 검품 | `picking.order_items`, `picking.picking_tasks` | `inspection.inspection_tasks` |
| 검품완료 | `inspection_completed` | 검품 | `inspection.inspection_tasks` | `inspection.inspection_results`, `picking.order_items` |
| 결품/보류 | `shortage`, `hold` | 주문/피킹, 검품 | `picking.order_items`, `inspection.inspection_results` | `picking.shortage`, `picking.hold_items`, `cs.tickets` 후보 |
| CS ticket 연결 | `cs_open`, `cs_resolved` | CS/미송 | `picking.order_items`, `inspection.inspection_results` | `cs.tickets`, `cs.ticket_events` |
| 출고/배송완료 | `shipped`, `delivered` | 주문/피킹, 연동/설정 | `picking.order_items`, 외부 배송 상태 | `picking.orders`, `picking.order_items`, `integration.sync_job_runs` |

## 상태 전이

기본 흐름:

```text
imported
  -> created
  -> matched | unmatched | ambiguous | legacy_unmatched
  -> picking_pending
  -> picking_in_progress
  -> picking_completed
  -> inspection_pending
  -> inspection_completed
  -> shipped
  -> delivered
```

예외 흐름:

```text
picking_pending -> shortage
picking_in_progress -> shortage
inspection_pending -> hold
inspection_completed -> cs_open
shortage -> cs_open
hold -> cs_open
cs_open -> cs_resolved
cs_resolved -> picking_pending | shipped | cancelled
```

## 단계별 상세

### 주문 수집

소유 모듈: 연동/설정

연동 job이 외부 주문 데이터를 수집한다. 수집 결과는 `integration.sync_job_runs`에 남기고, 주문 생성은 주문/피킹 module service를 통해 수행한다.

금지:

- scraper가 `picking.order_items`를 직접 임의 수정
- 실패 run을 성공 run으로 덮어쓰기

### 주문상품 생성

소유 모듈: 주문/피킹

원본 주문번호, 상품명, 옵션명, `raw_p_code`, 수량, 상태를 보존한다.

금지:

- `raw_p_code` 정규화 결과로 원본 값을 대체
- master 매칭 실패 주문상품 삭제

### master 매칭

소유 모듈: 주문/피킹

1순위는 `raw_p_code`와 `product_code.code_alias(code_system='selfpia_sku')` 직접 매칭이다. 실패 시 `own_sku` fallback은 후보로만 사용하며 자동 확정하지 않는다.

금지:

- ambiguous 후보를 matched로 자동 전환
- 미매칭을 이유로 주문 라인 삭제
- 상품관리 승인 없이 `code_alias` 직접 추가

### 피킹

소유 모듈: 주문/피킹

피킹 현장 화면은 태블릿용이다. 피킹은 master lookup을 읽을 수 있지만 master를 수정하지 않는다.

금지:

- `unmatched` 또는 `ambiguous` 라인을 정상 matched와 같은 방식으로 자동 피킹 완료
- 검품 완료 후 피킹 상태 되돌리기

### 검품

소유 모듈: 검품

검품은 태블릿/PC 혼합 화면이다. 피킹 완료 라인을 기준으로 수량, 상품, 누락, 오배송을 확인한다.

금지:

- 검품 화면에서 주문 원본 수량 수정
- CS ticket 없이 hold 사유를 제거

### 결품/보류

소유 모듈: 주문/피킹, 검품

결품은 피킹 중 발견될 수 있고, 보류는 검품 중 발견될 수 있다. 고객 응대가 필요한 경우 CS ticket으로 연결한다.

금지:

- 결품/보류 상태에서 배송완료 직접 전환
- 사유 없는 hold 해제

### CS ticket 연결

소유 모듈: CS/미송

CS는 주문상품, 피킹, 검품 상태를 읽고 ticket을 관리한다. CS 처리 결과가 운영 상태 변경을 요구하면 해당 module API를 호출하거나 change request/SOP로 넘긴다.

금지:

- CS가 `product_code` master 직접 수정
- CS가 검품 결과를 직접 삭제

### 출고/배송완료

소유 모듈: 주문/피킹, 연동/설정

출고/배송 상태는 내부 처리 결과와 외부 배송 상태를 함께 본다.

금지:

- `inspection_completed` 전 배송완료 전환
- `cs_open` 상태에서 자동 배송완료

## 상태 전이 금지 규칙

- `unmatched` -> `matched`는 change request 또는 명시적 resolution 없이 금지
- `ambiguous` -> `matched`는 후보 검수 없이 금지
- `legacy_unmatched`는 과거 주문 보존 상태이며 자동 보정 금지
- `inspection_completed` 이후 `picking_in_progress`로 되돌리기 금지
- `shipped` 이후 주문상품 핵심 값 수정 금지
- `delivered` 이후 master match status 수정은 audit 사유 필수
- `cs_open` 상태에서 `shipped`/`delivered` 자동 전이 금지

## 지금 만들 것

- order lifecycle status enum 초안
- module별 상태 전이 service
- `audit.domain_events` 상태 변경 기록
- unmatched/ambiguous/legacy_unmatched 처리 화면 연결

## 나중에 만들 것

- shipment carrier 연동 상태
- CS SLA와 lifecycle 연결
- 상태별 role permission matrix
- 되돌리기 요청 workflow
- 운영 dashboard와 exception queue
