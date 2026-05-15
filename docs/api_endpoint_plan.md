# API Endpoint Plan

이 문서는 로컬 Docker API skeleton 기준 endpoint 목록과 향후 확장 방향을 정리한다.

## 현재 skeleton endpoints

| Method | Path | 목적 | DB 접근 |
|---|---|---|---|
| GET | `/health` | API/DB 연결 확인 | `SELECT current_database()` |
| GET | `/product-code/skus` | canonical SKU 목록 조회 | `product_code.v_sku_canonical` SELECT |
| GET | `/product-code/skus/:selfpiaSkuCode` | SKU 단건 조회 | `product_code.v_sku_canonical` SELECT |
| GET | `/picking/orders` | 주문 목록 조회 | `picking.orders` SELECT |
| GET | `/picking/order-items` | 주문상품 목록 조회 | `picking.order_items` SELECT |
| GET | `/picking/unmatched` | 미매칭 운영 라인 조회 | `picking.v_order_items_unmatched` SELECT |
| GET | `/mapping/summary` | master match 상태 요약 | `picking.v_order_items_master_match_summary` SELECT |
| GET | `/mapping/unmatched` | staging 미매칭 목록 조회 | `stg.unmatched_order_items` SELECT |
| GET | `/mapping/own-sku/ambiguous` | own_sku 후보 중복 조회 | `stg.v_ambiguous_own_sku_candidates` SELECT |

## Response Granularity Policy

### `/mapping/unmatched`

현재 skeleton의 `GET /mapping/unmatched` 는 **line-level** endpoint 다. 즉 `stg.unmatched_order_items` row를 그대로 반환한다.

의미:

- 같은 `raw_p_code` 가 여러 주문/송장/라인에서 반복되면 여러 row가 반환될 수 있다.
- `9826-*` 가 raw_p_code별로 중복처럼 보이는 경우, 실제 staging row 중복인지 line-level 반복인지는 별도 SQL로 확인해야 한다.
- 원인 확인용 SQL: `sql/local_check_unmatched_duplicates.sql`

추가 설계 후보:

| Method | Path | 목적 |
|---|---|---|
| GET | `/mapping/unmatched?group_by=raw_p_code` | raw_p_code 기준 code-level 집계 |
| GET | `/mapping/unmatched/summary` | 미매칭 사유/status별 요약 |

정책:

- line-level endpoint는 운영 작업/감사용으로 유지한다.
- code-level endpoint는 상품팀 보강 큐와 dashboard용으로 별도 제공한다.

## Query Parameters

### `GET /product-code/skus`

| param | 설명 |
|---|---|
| `search` | selfpia sku, product name, virtual sku 부분 검색 |
| `limit` | 기본 50, 최대 200 |

### `GET /picking/order-items`

| param | 설명 |
|---|---|
| `master_match_status` | `matched`, `unmatched`, `ambiguous`, `legacy_unmatched` |
| `limit` | 기본 50, 최대 200 |

### `GET /mapping/own-sku/ambiguous`

| param | 설명 |
|---|---|
| `limit` | 기본 100, 최대 500 |

## 다음 설계 대상

### Picking write APIs

- `POST /picking/tasks/:taskId/start`
- `POST /picking/tasks/:taskId/complete`
- `POST /picking/tasks/:taskId/exception`

필요 확인:

- 작업자 식별 방식
- tablet session/auth 방식
- 재처리/취소 정책
- audit actor 기록 방식

### Mapping review APIs

- `POST /mapping/unmatched/:id/resolve`
- `POST /mapping/own-sku/candidates/:id/accept`
- `POST /mapping/own-sku/candidates/:id/reject`

주의:

- own_sku 는 1:N 가능성이 있으므로 자동 확정 금지
- Product_code master 직접 수정은 API skeleton 범위 밖
- 보정 결과는 audit 에 남겨야 함

### Inspection APIs

- `POST /inspection/items/:orderItemId/pass`
- `POST /inspection/items/:orderItemId/fail`
- `GET /inspection/items`

현재 원본 `inspection` / `hold_items` 는 0건이므로 신규 업무 설계를 먼저 확정한다.

### CS APIs

- `GET /cs/templates`
- `POST /cs/tickets`
- `POST /cs/tickets/:ticketId/events`

현재 CS 원본 구조가 약하므로 외부 시스템 연동 키와 ticket lifecycle 확인이 필요하다.

## 금지

- 클라이언트에서 PostgreSQL 직접 접속 금지
- API 서버에서 Supabase service role / anon key 사용 금지
- 운영 Supabase DB 수정 금지
- NAS DB 적용 금지


## 실제 Endpoint 응답 상태 (2026-05-12)

로컬 Docker API 컨테이너(`product_ops_api_local`)와 로컬 Docker PostgreSQL(`product_ops_test_postgres`) 기준으로 endpoint 응답을 확인했다.

| Method | Path | 상태 | 실제 응답/관찰 |
|---|---|---|---|
| GET | `/health` | 성공 | `ok=true`, DB 연결 확인 |
| GET | `/mapping/summary` | 성공 | `data={}`. 로컬 DB에 운영 mapping 집계용 데이터가 충분히 없어 빈 결과로 판단 |
| GET | `/mapping/unmatched` | 성공 | `9826-*` 미매칭 데이터 반환 확인 |
| GET | `/product-code/skus` | 성공 | `data={}`, `limit=50`. `product_code.sku_master` sample 미적재 상태로 판단 |
| GET | `/picking/order-items` | 성공 | `data={}`, `limit=50`. `picking.order_items` sample 미적재 상태로 판단 |

테스트 판단:

- route wiring 정상
- API 서버 DB 연결 정상
- `stg.unmatched_order_items` 계열 미매칭 조회 정상
- 빈 결과 endpoint는 route/API 오류가 아니라 local sample data 미적재 상태로 판단

다음 endpoint 검증 계획:

1. 로컬 Docker DB 전용 sample seed 작성
2. `product_code.sku_master`, `product_code.code_alias`, `picking.order_items`에 최소 row 적재
3. `GET /product-code/skus`가 실제 SKU row를 반환하는지 확인
4. `GET /picking/order-items`가 실제 picking row를 반환하는지 확인
5. 운영 Supabase 및 NAS에는 seed 적용 금지

## Seed 후 Endpoint 재검증 결과 (2026-05-12)

로컬 Docker DB 전용 sample seed 적재 후 API endpoint를 재검증했다.

| Method | Path | 상태 | 실제 응답/관찰 |
|---|---|---|---|
| GET | `/product-code/skus?search=LOCAL_TEST` | 성공 | `LOCAL_TEST` SKU 2건 반환 |
| GET | `/product-code/skus/LOCAL_TEST_1258-1` | 성공 | 단일 SKU 상세 반환 |
| GET | `/picking/order-items?master_match_status=matched` | 성공 | matched order item 2건 반환 |
| GET | `/picking/unmatched` | 성공 | unmatched / ambiguous / legacy_unmatched 3건 반환 |
| GET | `/mapping/summary` | 성공 | matched 2 / unmatched 1 / ambiguous 1 / legacy_unmatched 1 |
| GET | `/mapping/own-sku/ambiguous` | 성공 | `LOCAL_TEST_OWN_AMBIG` 후보 2개 반환 |

추가 확인 필요:

- `GET /mapping/unmatched` 에서 기존 `9826-*` legacy_unmatched 가 raw_p_code별로 2번씩 중복 반환됨.
- 확인할 원인: staging row 자체 중복인지, line-level endpoint라 같은 raw_p_code의 여러 line이 반환되는 것인지.
- 확인 SQL: `sql/local_check_unmatched_duplicates.sql`.
# Product Management v1 API (2026-05-13)

최종 상품관리 namespace는 `/api/products/*` 로 둔다. 기존 `/product-code/*` 는 v1 기간 migration alias로 유지한다.

| Method | Path | 목적 | DB 접근 |
|---|---|---|---|
| GET | `/api/products/skus` | SKU 목록/검색 | `product_code.v_sku_canonical`, `product_code.code_alias` SELECT |
| GET | `/api/products/skus/:skuId` | SKU 상세 | `product_code.v_sku_canonical`, `product_code.code_alias`, `product_code.sku_channel_mapping` SELECT |
| GET | `/api/products/skus/by-code/:codeSystem/:codeValue` | alias/code 기반 SKU 조회 | `product_code.code_alias`, `product_code.v_sku_canonical` SELECT |
| GET | `/api/products/skus/:skuId/aliases` | SKU별 alias 조회 | `product_code.code_alias` SELECT |
| GET | `/api/products/search` | 상품/SKU/alias/channel code 통합 검색 | `product_code.v_sku_canonical`, `product_code.code_alias`, `product_code.sku_channel_mapping` SELECT |
| GET | `/api/products/change-requests` | change request placeholder | write 없음 |

Migration alias:

| Existing | New | 정책 |
|---|---|---|
| GET `/product-code/skus` | GET `/api/products/skus` | v1 기간 유지 |
| GET `/product-code/skus/:selfpiaSkuCode` | GET `/api/products/skus/by-code/selfpia_sku/:selfpiaSkuCode` | v1 기간 유지 |

금지:

- Product_code master 직접 수정
- change request POST/approval/apply
- 운영 Supabase/NAS 적용
