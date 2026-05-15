# Database Schema Boundaries

## 원칙

DB는 업무 영역별 schema로 나눈다. 운영 데이터는 `public`에 몰아넣지 않는다.

## Schema 경계

| schema | 책임 | 쓰기 주체 |
|---|---|---|
| `product_code` | SKU master, product master, code alias, channel mapping | master writer / 승인 workflow |
| `picking` | orders, order_items, picking tasks, shortage, holds | picking API / order import |
| `inspection` | inspection result | inspection API |
| `cs` | tickets, events, templates | CS API |
| `integration` | external accounts, scraper jobs, sync status | integration API |
| `audit` | row changes, domain events, sync log | API server |
| `stg` | migration/import staging | ETL only |

`integration` schema는 운영 설계의 필수 schema다. v2 draft 적용 여부와 별개로 실제 운영 플랫폼에서는 외부 계정, sync job, scraper run, import/export file, bookmarklet client, 연동 로그를 독립 schema로 관리한다.

상세 설계는 `docs/12_integration_module_design.md`를 기준으로 한다.

## Shared keys

- `sku_id`: 내부 SKU 연결 키
- `selfpia_sku_code`: 외부/운영에서 보이는 canonical text code
- `code_alias`: selfpia, own_sku, channel code, seller code 매핑
- `order_item_id`: 피킹/검품/CS 연결 키

## Product master 정책

- `product_code`는 모든 모듈이 읽을 수 있다.
- 일반 API는 `product_code`를 직접 수정하지 못한다.
- 수정은 change request -> 승인 -> master writer -> audit 순서로 처리한다.

## 운영 데이터 정책

- `picking.order_items.raw_p_code`는 삭제하지 않는다.
- `master_match_status`로 matched/unmatched/ambiguous/legacy_unmatched 상태를 표현한다.
- 초기 FK는 nullable 또는 `NOT VALID`로 시작할 수 있다.
- 미매칭은 `stg.unmatched_order_items` 또는 운영 상태 컬럼으로 격리한다.

## Audit

모든 쓰기 작업은 다음을 남긴다.

- actor
- module
- action
- target schema/table/pk
- before/after
- request id
- source IP/device

## 지금 만들 것

- schema별 소유권 문서화
- API 권한 matrix
- change request table 설계
- integration schema 상세 초안

## 나중에 만들 것

- row level security 또는 API-level policy
- archive/retention policy
- read replica/reporting schema
- PITR/backup validation
