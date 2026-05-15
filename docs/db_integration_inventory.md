# DB Integration Inventory (사전조사 실행 결과)

> 두 Supabase project 의 SELECT-only 사전조사 결과. 운영 DB 변경 없음.

---

## 0. 메타

| 항목 | Product_code | PR_system |
|---|---|---|
| Supabase project ref | `mrqoqmidnrawflwezxlm` | `vgxocngpykhlkosiaeew` |
| host | `db.mrqoqmidnrawflwezxlm.supabase.co` | `db.vgxocngpykhlkosiaeew.supabase.co` |
| db / user | `postgres` / `postgres` | `postgres` / `postgres` |
| schema | `public` | `public` |
| PG version | 17.6.1.111 | 17.6.1.105 |
| region | ap-northeast-2 | ap-northeast-2 |
| TZ | UTC | UTC |
| created_at | 2026-04-30 | 2026-04-23 |
| 조사 시각 | 2026-05-12 03:56 UTC | 2026-05-12 03:56 UTC |

---

## 1. Product_code (상품코드 DB)

### 1.1 schema

`auth, extensions, graphql, graphql_public, pgbouncer, public, realtime, storage, supabase_migrations, vault` — 운영 데이터는 모두 `public`.

### 1.2 테이블 (exact row count)

| table | rows | size | RLS |
|---|---:|---|---|
| `product_master` | 6,174 | 2.3 MB | OFF |
| `sku_master` | 33,287 | 9.8 MB | OFF |
| `code_alias` | 71,436 | 26 MB | OFF |
| `sku_channel_mapping` | 12,588 | 6.8 MB | OFF |
| `channel_product` | 1,734 | 8.5 MB | OFF |
| `channel_sku` | 14,744 | 12 MB | OFF |
| `channel_template_meta` | 1 | 120 kB | OFF |
| `channel_sku_review_draft` | 970 | 952 kB | ON |
| `product_image` | 39,461 | 11 MB | OFF |
| `sku_bundle_component` | 0 | 32 kB | OFF |

### 1.3 핵심 키 컬럼

| 의미 | 위치 |
|---|---|
| 상품 PK | `product_master.id` (uuid) |
| 상품 비즈니스 키 | `product_master.virtual_product_code` (text, unique) — `VPRD-XXXXXXXX` |
| SKU PK | `sku_master.id` (uuid) |
| SKU 비즈니스 키 | `sku_master.virtual_sku_code` (text, unique) — `VSKU-XXXXXXXX` |
| 상품→SKU | `sku_master.product_id` → `product_master.id` |
| 모든 외부/내부 별칭 | `code_alias.code_value` (target_type + target_id 로 PRODUCT/SKU/SET 식별) |

### 1.4 code_alias 의 code_system 분포 (실측)

| code_system | target_type | rows | distinct |
|---|---|---:|---:|
| `selfpia_sku` | SKU | 33,287 | 33,287 (1:1) |
| `selfpia_product` | PRODUCT | 6,174 | 6,174 (1:1) |
| `own_sku` | SKU | 31,975 | 18,533 (n:m — 같은 own_code 가 여러 SKU 에 매핑됨) |
| `own_product` | - | 0 | - |
| `own_set` | - | 0 | - |
| `smartstore` / `ably` / `makeshop` / `playauto` | - | 0 | - |

> 채널별 alias (smartstore/ably/makeshop/playauto) 는 **아직 한 건도 적재되지 않음**.

### 1.5 selfpia_sku code_value 형식

- 형식: `{selfpia_product_code}-{selfpia_option_no}` (예: `1000-1`, `10000-3`, `1258-1`)
- `code_alias.selfpia_product_code` / `selfpia_option_no` 컬럼에 파싱된 값 보관
- own_sku 형식: `B-1-01`, `CA-3-03_3`, `PI-3-01` 등 (parsed_part1 = 카테고리/그룹, parsed_part2 = 세부번호)

### 1.6 핵심 FK

- `product_master.id ← sku_master.product_id`
- `product_master.id ← channel_product.internal_product_id`
- `sku_master.id ← channel_sku.internal_sku_id`
- `sku_master.id ← sku_channel_mapping.sku_id` / `sku_bundle_component.bundle_sku_id` / `component_sku_id`
- `channel_sku.id ← sku_channel_mapping.channel_sku_id`
- `channel_product.id ← channel_sku.channel_product_id`
- `channel_template_meta` ← `channel_product` (channel, template_type)

### 1.7 요청 컬럼 위치 정리

| 요청 키 | Product_code 위치 |
|---|---|
| `selfpia_sku_code` | **컬럼 없음**. `code_alias.code_value WHERE code_system='selfpia_sku'` 에 저장 (33,287건) |
| `selfpia_product_code` | **컬럼 없음** (별칭 row). `code_alias.code_value WHERE code_system='selfpia_product'` 또는 `code_alias.selfpia_product_code` (파싱된 컬럼) |
| `virtual_sku_code` | `sku_master.virtual_sku_code` (text, unique) |
| `virtual_product_code` | `product_master.virtual_product_code` (text, unique) |
| `channel_sku_code` | `channel_sku.channel_sku_code`, `channel_sku.channel_sku_code_raw`, `channel_sku_review_draft.channel_sku_code` |
| `seller_product_code` | `channel_product.seller_product_code_raw` |
| `code_alias 구조` | (id, target_type, target_id, code_system, code_value, parsed_prefix, parsed_part1~4, selfpia_product_code, selfpia_option_no, usage_type, is_primary, memo, created_at) |

### 1.8 Supabase 전용 기능 의존

- **RLS**: `channel_sku_review_draft` 만 enabled, 나머지 9개 테이블 모두 disabled (`anon`/`authenticated` 키로 전체 접근 가능 — 보안 이슈).
- **Auth/Storage/Realtime**: 본 사전조사로는 직접 확인 안 됨. 클라이언트 코드에서 사용 여부 확인 필요.
- **uuid**: `gen_random_uuid()` 기본값 사용 — NAS PG 에서도 `pgcrypto` 또는 `uuid-ossp` 활성 필요.

---

## 2. PR_system (피킹시스템 DB)

### 2.1 schema

운영 데이터는 모두 `public`.

### 2.2 테이블 (exact row count)

| table | rows | size | RLS | 영역 |
|---|---:|---|---|---|
| `orders` | 1,879 | 928 kB | OFF | order header |
| `order_items` | 6,169 | 3.6 MB | OFF | order line |
| `picking` | 1,219 | 568 kB | OFF | picking |
| `inspection` | 0 | 32 kB | OFF | inspection (테이블만 있음) |
| `shortage` | 321 | 256 kB | OFF | shortage |
| `hold_items` | 0 | 40 kB | OFF | hold |
| `cs_templates` | 6 | 32 kB | OFF | cs |
| `products` | 32,094 | 5.4 MB | ON | 상품 master 사본 |
| `sync_log` | 13 | 40 kB | OFF | sync 로그 |

### 2.3 PK / UNIQUE / INDEX 요약

- `orders.ord_no` PK (text)
- `order_items.item_no` PK; FK `ord_no → orders.ord_no`
- `picking.id` PK; UNIQUE `(inv_no, p_code)` x2 (중복 정의)
- `inspection.id` PK; UNIQUE `(inv_no, p_code)`
- `shortage.id` PK; UNIQUE `(inv_no, p_code)`
- `hold_items.id` PK; UNIQUE `(inv_no, p_code)`
- `products.p_code` PK (text)
- `sync_log.id` PK; UNIQUE `sync_date`
- 일반 인덱스: `orders.ord_date`/`inv_no`, `order_items.ord_date`/`inv_no`/`ord_no`/`dnum`, `picking.checked`/`inv_no`, `shortage.inv_no`/`memo_synced`, `inspection.inv_no`, `hold_items.inv_no`/`resolved`

### 2.4 상품 식별 컬럼 (order_items 6,169 라인 기준)

| 컬럼 | filled | distinct | 형식 sample |
|---|---:|---:|---|
| `p_code` | 6,169 (100%) | 2,742 | `1258-1`, `9552-23`, `10521-38` |
| `p_dpcode` | 5,837 (94.6%) | 2,549 | `[CA-03-03_3]`, `[P] A-04-16 ]` |
| `prod_code` | 5,837 (94.6%) | 2,549 | (= p_dpcode) |
| `p_option` | 4,379 (71.0%) | 2,699 | `6mm[CA-3-03_3]` |
| `p_name` | 6,169 (100%) | 1,438 | 상품명 텍스트 |

- `p_code` 패턴 분포: **100% 가 `^[0-9]+-[0-9]+$`** (= selfpia_sku 와 동일 형식)
- `p_dpcode` / `prod_code` 는 채널 옵션 코드(own_sku) 의 표시형 (`[...]`로 감싸짐)

### 2.5 요청 컬럼 존재 여부

| 컬럼명 | PR_system 존재 |
|---|---|
| `selfpia_sku_code` | 컬럼명 없음. 값은 `order_items.p_code` 에 동일 형식으로 저장됨 |
| `selfpia_product_code` | 컬럼명 없음. p_code 의 `-` 앞부분이 이에 해당 |
| `virtual_sku_code` | 없음 |
| `channel_sku_code` | 없음 |
| `seller_product_code` | 없음 |
| `own_code` | `products.own_code` (27,189 / 32,094 filled, 15,968 distinct) |

### 2.6 운영 테이블 연결 키 패턴

- `orders.ord_no` <-> `order_items.ord_no` (FK 있음)
- `orders.inv_no` / `order_items.inv_no` / `picking.inv_no` / `inspection.inv_no` / `shortage.inv_no` / `hold_items.inv_no` — **FK 없음**, 운영 로직으로만 연결
- `picking` / `inspection` / `shortage` / `hold_items` 모두 `(inv_no, p_code)` 단위로 UNIQUE — 같은 송장의 같은 상품 1행 원칙
- `products.p_code` 가 master 사본 PK, 그러나 `order_items.p_code` 와 FK 로 강제되지 않음

### 2.7 상태값

- `orders.o_cs_status`: 전체 `''` (현재 미사용)
- `order_items.o_status`: `송장입력`(4232), `배송완료`(1790), `재고매칭`(116), `상품매칭`(31)
- `shortage.status` default `'배송대기'`
- `picking.checked` / `is_checked` (bool)
- `inspection.passed` (bool)
- `hold_items.resolved` (bool)

### 2.8 검품 / CS 연결 컬럼

- 검품: `inspection.inv_no`, `item_no`, `ord_no`, `p_code` — orders/order_items 와 inv_no/ord_no/p_code 로 연결되지만 FK 없음
- CS: 별도 ticket 테이블 없음. `cs_templates` (6건) 만 있음. 실제 CS 처리는 `shortage.cs_memo`, `orders.o_cs_status` 컬럼으로 분산되어 보임.

### 2.9 Supabase 전용 기능 의존

- **RLS**: `products` 만 enabled, 나머지 8개 운영 테이블 disabled (보안 이슈)
- **Auth/Realtime/Storage**: 사전조사로는 직접 확인 안 됨. HTML/태블릿 클라이언트 코드에서 supabase-js Realtime/Auth 사용 여부 점검 필요

---

## 3. 두 DB 의 겹침 / 충돌

### 3.1 동명 테이블

| Product_code | PR_system | 의미 | 통합 방향 |
|---|---|---|---|
| `product_master` (6,174) | `products` (32,094) | 서로 다른 개념 — Product_code 는 "상품 단위" master, PR_system 은 옵션 단위 사본 (sku_master 와 대응) | schema 분리 후 PR_system 의 `products` 는 `picking.legacy_products` 또는 제거 후 code_alias 참조로 대체 |

### 3.2 같은 개념, 다른 이름

| 개념 | Product_code | PR_system | 통합 명칭 |
|---|---|---|---|
| SKU 식별 코드 | `code_alias.code_value` WHERE `code_system='selfpia_sku'` | `order_items.p_code` (= picking/shortage/inspection/products.p_code) | `selfpia_sku_code` (canonical) |
| 상품 식별 코드 | `code_alias.selfpia_product_code` (parsed) 또는 `code_alias.code_value WHERE code_system='selfpia_product'` | `p_code` 의 `-` 앞부분 | `selfpia_product_code` (canonical) |
| 자체 채널 옵션코드 | `code_alias.code_value WHERE code_system='own_sku'` 또는 `channel_sku.extracted_own_code` | `order_items.p_dpcode` / `prod_code` (대괄호 포함), `products.own_code` (정제됨) | `own_sku_code` |

### 3.3 dtype 차이

- Product_code 의 SKU id 는 **uuid**, PR_system 은 **text(NNN-NN)**. 통합 시 master <-> 운영 매핑을 위해 `picking.order_items.selfpia_sku_code text` 로 두고, `product_code.code_alias` 또는 `sku_master.virtual_sku_code` 와 텍스트로 매칭하는 방식 권장.

---

## 4. 연결 키 매핑 가설

| 피킹 컬럼 (PR_system) | 매칭 우선순위 | 매칭 대상 (Product_code) | 비고 |
|---|---:|---|---|
| `order_items.p_code` | 1 | `code_alias.code_value` WHERE `code_system='selfpia_sku'` → `target_id` (uuid) → `sku_master.id` | **형식 100% 일치 확인**. 매칭률 매우 높을 것으로 예상. |
| `order_items.p_dpcode` / `prod_code` (대괄호 제거) | 2 | `code_alias.code_value` WHERE `code_system='own_sku'` (n:m 주의) | 1순위로 못 잡힐 때 fallback. own_sku 는 중복 매칭 가능. |
| `products.own_code` | 3 | `code_alias.code_value` WHERE `code_system='own_sku'` | 자체 사본 비교용. |

> `selfpia_sku_code` 라는 컬럼명을 그대로 쓰는 **단일 컬럼은 양쪽 DB 어디에도 존재하지 않음**. 모두 별도 컬럼명에 같은 값이 저장되어 있는 구조.

---

## 5. 매칭률 사전 측정

> 두 DB 는 별도 Supabase project 이므로 단일 SQL JOIN 불가. 정량 매칭률은 cross_mapping STEP 으로 로컬/검증 DB 에서 측정.
>
> **정성적 매칭 가능성**:
> - PR_system 의 `order_items.p_code` 가 **100% (6,169/6,169 라인) `NNN-NN` 형식**.
> - Product_code 의 `code_alias` 에 `selfpia_sku` 33,287 distinct entry 존재.
> - PR_system distinct p_code = 2,742 « selfpia_sku distinct 33,287 → 형식 일치 + master 풀이 충분히 큼 → 매칭률 95% 이상 예상.

### 5.1 cross mapping 실측 상태

상태: **완료**. 노트북 Docker PostgreSQL 로컬 검증 DB (`product_ops_test`) 에서 STEP A export CSV 를 staging 적재한 뒤 STEP C-1 직접 매칭률을 측정함.

운영 DB 에서는 SELECT-only export 만 수행했다. 운영 Supabase 에 staging table 생성, `COPY` 적재, `CREATE`, `DROP`, cross-project JOIN 은 수행하지 않았다.

### 5.2 export 해야 하는 CSV

| 파일명 | 실행 위치 | SQL 블록 | 예상 행 수 | 목적 |
|---|---|---|---:|---|
| `selfpia_sku_alias.csv` | Product_code `mrqoqmidnrawflwezxlm` | `sql/export_product_code_selfpia_sku_alias_select_only.sql` | 33,287 | `order_items.p_code` 와 직접 매칭 |
| `own_sku_alias.csv` | Product_code `mrqoqmidnrawflwezxlm` | `sql/export_product_code_own_sku_alias_select_only.sql` | 31,975 | 1순위 실패 시 fallback 후보 및 모호성 측정 |
| `order_items_xmap.csv` | PR_system `vgxocngpykhlkosiaeew` | `sql/export_pr_system_order_items_xmap_select_only.sql` | 6,169 | 운영 주문상품 라인 기준 매칭률 측정 |

각 export 전 `current_database()`, `current_schema()`, Supabase project ref 를 확인한다.

로컬/검증 DB 전용 실행 파일: `sql/local_cross_mapping_stage_and_measure.sql`.
권장 로컬 검증 환경: `docker-compose.local-test.yml` 로 실행하는 노트북 Docker PostgreSQL (`product_ops_test`, host port `5433`).

### 5.3 STEP C 결과

| 항목 | 값 | 비고 |
|---|---:|---|
| staging `selfpia_sku_alias` rows | 33,287 | Product_code export |
| staging `own_sku_alias` rows | 31,975 | Product_code export |
| staging `order_items` rows | 6,169 | PR_system export |
| total order item lines | 6,169 | STEP C-1 `total_lines` |
| selfpia_sku 직접 매칭 lines | 6,164 | STEP C-1 `matched_p1` |
| selfpia_sku 직접 매칭률 | 99.92% | STEP C-1 `match_rate_p1_pct` |
| selfpia_sku 미매칭 lines | 5 | STEP C-1 `unmatched_p1` |
| distinct p_code | 2,742 | STEP C-1 `distinct_p_code` |
| 미매칭 p_code distinct | 5 | STEP C-1 `unmatched_distinct_p_code` |
| own_sku fallback unique match | 확인 필요 | STEP C-2 결과 미전달 |
| own_sku fallback ambiguous | 확인 필요 | STEP C-2/C-4 결과 미전달 |
| own_sku fallback unmatched | 확인 필요 | STEP C-2 결과 미전달 |
| own_sku key 없음 | 확인 필요 | STEP C-2 결과 미전달 |
| 미매칭 주요 pattern | `NNN-NN` 5건 | p_code 모두 selfpia_sku 형식 |

미매칭 p_code:

| p_code | 상품명 | 현재 판단 |
|---|---|---|
| `9826-1` | 925 실버 피어싱 귀걸이 원터치 미니 링피어싱 귓바퀴 93종 | 배송완료 과거 주문으로 추정 |
| `9826-3` | 925 실버 피어싱 귀걸이 원터치 미니 링피어싱 귓바퀴 93종 | 배송완료 과거 주문으로 추정 |
| `9826-26` | 925 실버 피어싱 귀걸이 원터치 미니 링피어싱 귓바퀴 93종 | 배송완료 과거 주문으로 추정 |
| `9826-31` | 925 실버 피어싱 귀걸이 원터치 미니 링피어싱 귓바퀴 93종 | 배송완료 과거 주문으로 추정 |
| `9826-48` | 925 실버 피어싱 귀걸이 원터치 미니 링피어싱 귓바퀴 93종 | 배송완료 과거 주문으로 추정 |

### 5.4 결과 해석 기준

- `selfpia_sku` 직접 매칭률은 99.92% 로, Product_code 와 PR_system 은 p_code/selfpia_sku 기준으로 직접 통합 가능성이 높다.
- 직접 미매칭 5건은 `stg.unmatched_order_items` 로 격리하거나 `picking.order_items.master_match_status` 로 관리한다.
- 과거 주문 보존을 위해 raw `p_code` 는 반드시 유지한다.
- 초기 이전 단계에서는 master FK 를 nullable 로 두거나 `NOT VALID` FK 로 시작하는 것을 권장한다.
- `own_sku` 는 자동 확정이 아니라 보강 후보로만 사용한다.
- `own_sku` fallback 에서 `candidate_count > 1` 인 라인은 자동 매칭 금지. 별도 중복 해소 규칙 확정 전까지 보류한다.
- `p_code` 형식이 `NNN-NN` 인데 Product_code 에 없으면 상품코드 master 누락 가능성이 높다. 상품팀 보강 SOP 로 넘긴다.

---

## 6. 통합 schema 매핑 (요약)

| 원본 | NAS 통합 위치 (제안) | 비고 |
|---|---|---|
| Product_code.`product_master` | `product_code.product_master` | virtual_product_code 유지 |
| Product_code.`sku_master` | `product_code.sku_master` | virtual_sku_code 유지 |
| Product_code.`code_alias` | `product_code.code_alias` | 모든 외부/내부 코드 alias |
| Product_code.`sku_channel_mapping` | `product_code.sku_channel_mapping` |  |
| Product_code.`channel_product` / `channel_sku` / `channel_template_meta` | `product_code.*` (그대로) |  |
| Product_code.`product_image` | `product_code.product_image` |  |
| Product_code.`channel_sku_review_draft` | `product_code.channel_sku_review_draft` 또는 `stg.*` | 임시성 테이블 |
| PR_system.`orders` | `picking.orders` | PK ord_no 유지 |
| PR_system.`order_items` | `picking.order_items` | + `selfpia_sku_id uuid` 컬럼 (FK → sku_master.id) 추가, p_code 는 raw 로 보존 |
| PR_system.`picking` | `picking.picking_tasks` |  |
| PR_system.`inspection` | `inspection.inspections` |  |
| PR_system.`shortage` | `picking.shortage` 또는 `cs.shortage` | 결품 추적 — CS 와 운영 양쪽 성격 |
| PR_system.`hold_items` | `picking.hold_items` |  |
| PR_system.`cs_templates` | `cs.templates` |  |
| PR_system.`products` | **삭제 후 product_code.* 로 대체** 또는 `stg.legacy_products` 보존 | NAS 통합 후엔 master 사본 불필요 |
| PR_system.`sync_log` | `audit.sync_log` 또는 폐기 |  |

---

## 7. 보류 / 확인 필요 항목

- [ ] **CS 영역**이 현재 PR_system 에 거의 없음 (`cs_templates` 6건 + `orders.o_cs_status` 미사용 + `shortage.cs_memo`). NAS 통합 시 CS 테이블 신규 설계 필요.
- [ ] `inspection`, `hold_items` 가 모두 0건 — 신규 기능인지 미사용 기능인지 확인.
- [ ] `orders.o_cs_status` 가 전체 `''` — 이 컬럼을 유지할지 폐기할지 결정.
- [ ] `picking.picking_inv_no_p_code_key` 와 `picking_inv_pcode_unique` UNIQUE 인덱스 **중복 정의** — NAS 이전 시 하나로 통합.
- [ ] Product_code 의 채널 alias (smartstore/ably/makeshop/playauto) 가 0건 — 향후 적재 계획 확인.
- [ ] 양쪽 다 **RLS 비활성 테이블 다수** (Product_code 9개, PR_system 8개) → Supabase anon/authenticated 키로 노출 중. NAS 이전 전에도 즉시 조치 권장 (API 서버 경유 원칙이라면 anon 키 회수 또는 RLS 정책 추가).
- [ ] Supabase Realtime / Auth / Storage / Edge Functions 의존 여부는 클라이언트 코드 점검 필요.
- [ ] `order_items.p_code` 와 `code_alias(selfpia_sku)` 의 실제 매칭률 — cross_mapping STEP 으로 측정.
