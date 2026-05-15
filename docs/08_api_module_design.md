# API Module Design

## 원칙

API 서버는 모듈형으로 구성한다. 하나의 `app.js` 또는 `server.js`에 모든 업무 로직을 넣지 않는다.

## 권장 서버 구조

```text
server/
  src/
    app.js
    db/
      pool.js
      transaction.js
    modules/
      product-management/
        routes.js
        service.js
        repository.js
      channel-management/
        routes.js
        service.js
        repository.js
      picking/
        routes.js
        service.js
        repository.js
      inspection/
        routes.js
        service.js
        repository.js
      cs/
        routes.js
        service.js
        repository.js
      integration-settings/
        routes.js
        service.js
        repository.js
    shared/
      auth/
      permissions/
      audit/
      product-lookup/
      errors/
```

현재 `server/src/routes/*`는 skeleton이며, 다음 단계에서 `modules/*` 구조로 확장한다.

## 공통 규칙

- route는 request/response만 담당한다.
- service는 업무 규칙을 담당한다.
- repository는 SQL만 담당한다.
- 모든 쓰기 service는 audit을 호출한다.
- Product_code master 직접 수정 API는 만들지 않는다.
- master 변경은 change request API로만 시작한다.
- 모든 쓰기 API는 `audit.domain_events`에 업무 이벤트를 남긴다.

## audit.domain_events

`audit.domain_events`는 모듈 간 운영 흐름을 추적하는 공통 이벤트 로그다. row 변경 이력보다 한 단계 높은 업무 이벤트를 기록한다.

대표 이벤트:

- `change_request.submitted`
- `change_request.approved`
- `change_request.applied`
- `order.imported`
- `order_item.master_matched`
- `order_item.master_unmatched`
- `picking.started`
- `picking.completed`
- `inspection.completed`
- `cs.ticket_opened`
- `integration.sync_failed`

공통 필드:

- `event_id`
- `event_type`
- `module`
- `actor_id`
- `request_id`
- `correlation_id`
- `target_schema`
- `target_table`
- `target_pk`
- `payload`
- `created_at`

API service layer는 상태 전이, 외부 연동, change request 반영 시 이 이벤트를 기록한다.

## 모듈별 API namespace

| 모듈 | API namespace |
|---|---|
| 상품관리 | `/api/products/*` |
| 채널상품관리 | `/api/channels/*` |
| 주문/피킹 | `/api/picking/*` |
| 검품 | `/api/inspection/*` |
| CS/미송 | `/api/cs/*` |
| 연동/설정 | `/api/integrations/*`, `/api/settings/*` |

## 읽는 데이터

- 각 모듈은 자기 schema와 shared lookup만 읽는다.
- cross-module 조회는 service를 통해 수행한다.

## 쓰는 데이터

- 각 모듈은 자기 schema만 쓴다.
- shared master 쓰기는 change request 승인 workflow로 제한한다.

## 지금 만들 것

- module directory 분리
- health endpoint 유지
- product lookup service
- audit middleware 초안

## 나중에 만들 것

- auth/JWT
- role based permission
- request id propagation
- module별 integration test
