# Change Request Design

## 목적

`product_code` master는 모든 모듈이 공유하는 기준 데이터다. 화면에서 master를 즉시 수정하면 주문, 피킹, 검품, CS, 채널 연동이 서로 다른 기준을 보게 되고, 과거 주문 재현성과 audit 추적도 깨진다.

따라서 master 변경은 직접 수정이 아니라 change request를 통해 요청, 검토, 승인, 반영, 기록한다.

## 직접 수정 금지 이유

- SKU 기준 변경은 주문상품 매칭, 피킹, 검품, CS 조회에 즉시 영향을 준다.
- `code_alias` 변경은 selfpia, own_sku, 채널 코드 매칭률과 미매칭 처리에 영향을 준다.
- 잘못된 master 수정은 과거 주문을 현재 기준으로 오염시킬 수 있다.
- 변경 사유, 승인자, 적용 시각, 적용 전후 값을 audit에 남겨야 한다.
- API 서버 외부에서 DB를 직접 수정하면 권한과 책임 경계가 사라진다.

## Conceptual Structure

### change_request

요청 단위의 header다.

주요 필드:

- `id`
- `request_no`
- `request_type`
- `status`
- `title`
- `reason`
- `source_module`
- `requested_by`
- `reviewed_by`
- `approved_by`
- `submitted_at`
- `reviewed_at`
- `approved_at`
- `applied_at`
- `cancelled_at`
- `rejected_at`

### change_request_item

실제 변경 대상 단위다. 하나의 request는 여러 item을 가질 수 있다.

주요 필드:

- `id`
- `change_request_id`
- `target_schema`
- `target_table`
- `target_pk`
- `target_key`
- `before_data`
- `after_data`
- `validation_status`
- `validation_message`
- `item_status`

### review

검토 의견과 승인/반려 판단을 남긴다.

주요 필드:

- `id`
- `change_request_id`
- `reviewer_id`
- `decision`
- `comment`
- `created_at`

### apply_log

승인된 request가 실제 master writer에 의해 반영된 결과를 남긴다.

주요 필드:

- `id`
- `change_request_id`
- `change_request_item_id`
- `applied_by`
- `applied_at`
- `target_schema`
- `target_table`
- `target_pk`
- `before_data`
- `after_data`
- `result`
- `error_message`
- `audit_event_id`

## Request Type

| request_type | 설명 | 대표 소유 모듈 |
|---|---|---|
| `alias_add` | 새 alias 추가 | 상품관리, 채널상품관리 |
| `alias_update` | 기존 alias 값/우선순위/활성 상태 변경 | 상품관리, 채널상품관리 |
| `sku_update` | SKU 속성 변경 | 상품관리 |
| `product_update` | 상품 master 속성 변경 | 상품관리 |
| `channel_mapping_update` | 채널 상품/옵션과 내부 SKU 매핑 변경 | 채널상품관리 |
| `unmatched_resolution` | 미매칭 주문상품의 master 연결 보강 | 주문/피킹, 상품관리 |
| `merge_candidate` | 중복 SKU/상품 병합 후보 검토 | 상품관리 |

## Status

| status | 의미 | 쓰기 주체 |
|---|---|---|
| `draft` | 작성 중 | 요청자 |
| `submitted` | 검토 요청됨 | 요청자 |
| `approved` | 승인 완료, 반영 대기 | 승인자 |
| `applied` | master writer가 반영 완료 | master writer |
| `rejected` | 반려됨 | 승인자 |
| `cancelled` | 요청자가 취소 | 요청자 |

허용 전이:

- `draft` -> `submitted`
- `draft` -> `cancelled`
- `submitted` -> `approved`
- `submitted` -> `rejected`
- `submitted` -> `cancelled`
- `approved` -> `applied`

금지 전이:

- `draft` -> `applied`
- `submitted` -> `applied`
- `rejected` -> `approved`
- `cancelled` -> `submitted`
- `applied` 이후의 모든 상태 변경

## 승인/반영 흐름

1. 각 업무 모듈이 변경 필요성을 발견한다.
2. API 서버가 change request draft를 생성한다.
3. 요청자가 item을 추가하고 validation을 실행한다.
4. 요청자가 `submitted`로 전환한다.
5. 승인자가 before/after, 영향 범위, 중복 가능성, 미매칭 해소 여부를 검토한다.
6. 승인자는 `approved` 또는 `rejected`로 결정한다.
7. `approved` request만 master writer가 transaction으로 반영한다.
8. 반영 결과를 `apply_log`와 `audit.domain_events`에 기록한다.
9. 연결된 모듈은 변경 이벤트를 읽어 cache refresh 또는 재매칭을 수행한다.

## Audit 연동

모든 상태 변경은 audit에 남긴다.

기록 대상:

- request 생성
- item 추가/수정/삭제
- 제출
- 승인/반려/취소
- master 반영 시도
- master 반영 성공/실패

`audit.domain_events`에는 다음 공통 필드를 둔다.

- `event_id`
- `event_type`
- `module`
- `actor_id`
- `request_id`
- `target_schema`
- `target_table`
- `target_pk`
- `before_data`
- `after_data`
- `created_at`

## API 초안

| Method | Endpoint | 설명 |
|---|---|---|
| `GET` | `/api/change-requests` | 요청 목록 |
| `POST` | `/api/change-requests` | draft 생성 |
| `GET` | `/api/change-requests/:id` | 요청 상세 |
| `POST` | `/api/change-requests/:id/items` | item 추가 |
| `PATCH` | `/api/change-requests/:id/items/:itemId` | item 수정 |
| `POST` | `/api/change-requests/:id/submit` | 제출 |
| `POST` | `/api/change-requests/:id/approve` | 승인 |
| `POST` | `/api/change-requests/:id/reject` | 반려 |
| `POST` | `/api/change-requests/:id/cancel` | 취소 |
| `POST` | `/api/change-requests/:id/apply` | 승인 건 반영 |
| `GET` | `/api/change-requests/:id/audit` | 관련 audit 조회 |

## DB Conceptual Schema

초기 후보 schema 위치:

- `product_code.change_requests`
- `product_code.change_request_items`
- `product_code.change_request_reviews`
- `product_code.change_request_apply_logs`

대안:

- change request가 master뿐 아니라 채널 매핑, 미매칭 해소, 병합 후보까지 다루므로 `audit` 또는 별도 `workflow` schema도 검토 가능하다.
- 단, 운영 초안에서는 master 변경 workflow와 가장 가까운 `product_code`에 둔다.

## 지금 만들 것

- request type/status enum 설계
- change request API skeleton
- validation rule 초안
- audit event 공통 포맷
- product/alias/channel mapping 변경 요청 화면

## 나중에 만들 것

- 승인자 role matrix
- request 영향 범위 preview
- bulk change request import
- 병합 후보 자동 탐지
- 이벤트 기반 cache refresh
