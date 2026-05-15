# Schema Decision Log

작성일: 2026-05-12

## 배경

Product_code 와 PR_system 의 cross mapping 을 노트북 Docker PostgreSQL (`product_ops_test`) 에서 실측했다.

| 항목 | 값 |
|---|---:|
| `selfpia_sku_alias` | 33,287 rows |
| `own_sku_alias` | 31,975 rows |
| `order_items` | 6,169 rows |
| total_lines | 6,169 |
| matched_p1 | 6,164 |
| match_rate_p1_pct | 99.92 |
| unmatched_p1 | 5 |
| distinct_p_code | 2,742 |
| unmatched_distinct_p_code | 5 |

미매칭 p_code: `9826-1`, `9826-3`, `9826-26`, `9826-31`, `9826-48`.
상품명: `925 실버 피어싱 귀걸이 원터치 미니 링피어싱 귓바퀴 93종`.
현재 판단상 배송완료 과거 주문으로 보인다.

## 결정

### product_code

- Product_code 원본 구조를 존중해 `sku_master` 와 `code_alias` 를 유지한다.
- `selfpia_sku_code` 는 Product_code 원본 단일 컬럼이 아니므로 `code_alias(code_system='selfpia_sku')` 로 보관한다.
- 조회 편의를 위해 `product_code.v_sku_canonical` view 를 제공한다.
- selfpia_sku alias 는 실측상 1:1 이므로 partial unique index 로 보호한다.

### picking

- `picking.order_items.raw_p_code` 를 NOT NULL 로 보존한다.
- `sku_id` 와 `selfpia_sku_code` 는 초기 이전 단계에서 nullable 로 둔다.
- `master_match_status` 를 추가하고 값은 `matched`, `unmatched`, `ambiguous`, `legacy_unmatched` 로 제한한다.
- 미매칭 5건은 `legacy_unmatched` 로 격리할 수 있게 설계한다.

### FK

- 초기 이전 단계에서 master FK 실패를 막기 위해 `picking.order_items.sku_id -> product_code.sku_master.id` FK 는 `NOT VALID` 로 시작한다.
- master 보강 이후 `VALIDATE CONSTRAINT` 또는 NOT NULL 전환을 별도 단계에서 검토한다.
- raw `p_code` 는 FK 전략과 무관하게 절대 삭제하지 않는다.

### unmatched / ambiguous

- `stg.unmatched_order_items` 를 두어 미매칭 p_code, 상품명, 옵션명, 주문번호, 상태값, raw 값을 보존한다.
- `stg.own_sku_match_candidates` 와 `stg.v_ambiguous_own_sku_candidates` 로 own_sku 후보 검수를 지원한다.
- own_sku 는 1:N 가능성이 있으므로 자동 확정하지 않는다.

### inspection / hold_items / cs

- `inspection` 과 `hold_items` 는 원본 0건이므로 과도한 legacy 이관보다 신규 설계 영역으로 둔다.
- CS 는 `cs_templates` 외 실운영 ticket 구조가 약하므로 `cs.templates`, `cs.tickets`, `cs.ticket_events` 로 신규 구조를 잡는다.

## 보류 / 확인 필요

- own_sku fallback STEP C-2/C-4의 실제 unique/ambiguous/unmatched 수치
- 미매칭 5건을 Product_code master 에 보강할지, 영구 legacy_unmatched 로 둘지
- `picking.order_items.master_match_status` 방식과 `stg.unmatched_order_items` 격리 방식 중 운영 ETL 기본값
- PR_system 원본의 모든 컬럼을 raw_payload 로 충분히 보존할지, 별도 typed column 을 더 둘지
- CS 외부 시스템 연동 키
- 검품 사진 저장 위치와 이전 방식
- API 서버 권한에서 DELETE 허용 여부

## 로컬 적용 결과

실행 환경:

- DB: `product_ops_test`
- user: `product_ops_tester`
- runtime: Docker PostgreSQL
- 운영 Supabase 변경 없음
- NAS 변경 없음

확인 결과:

| 항목 | 결과 |
|---|---:|
| 주요 인덱스 | 53개 생성 확인 |
| 주요 view | 4개 생성 확인 |
| audit base tables | 2 |
| cs base tables | 3 |
| inspection base tables | 1 |
| picking base tables | 5 |
| product_code base tables | 5 |
| stg base tables | 2 |

생성 확인된 주요 view:

- `picking.v_order_items_master_match_summary`
- `picking.v_order_items_unmatched`
- `product_code.v_sku_canonical`
- `stg.v_ambiguous_own_sku_candidates`

메모:

- `/d` 오타로 인한 syntax error 1건이 있었으나 schema 적용/validation과 무관하다.
- schema v2는 로컬 Docker PostgreSQL 적용 테스트를 통과했다.

## 금지

- 이 v2 schema 는 아직 NAS 에 적용하지 않는다.
- 운영 Supabase 에 적용하지 않는다.
- 로컬 Docker PostgreSQL 에서만 적용 테스트한다.
