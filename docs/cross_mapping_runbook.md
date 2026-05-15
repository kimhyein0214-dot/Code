# Cross Mapping Runbook

Product_code 와 PR_system 의 SKU 연결률을 운영 DB 변경 없이 측정하는 절차다. 운영 Supabase 에서는 SELECT-only export 만 허용한다. staging 생성과 매칭률 측정은 노트북 Docker PostgreSQL 같은 로컬/검증 DB 에서만 수행한다.

## 1. 원칙

- Product_code project ref: `mrqoqmidnrawflwezxlm`
- PR_system project ref: `vgxocngpykhlkosiaeew`
- 로컬 검증 DB: Docker PostgreSQL, DB `product_ops_test`, host port `5433`
- 운영 DB 금지: `CREATE`, `ALTER`, `DROP`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, staging table 생성, server-side `COPY`
- 운영 DB 허용: export용 `SELECT` 와 context 확인용 `SELECT`
- 로컬/검증 PostgreSQL 전용: `stg_xmap` schema 생성, CSV `\copy`, STEP C-1~C-5
- 실행 전 항상 `current_database()`, `current_schema()`, project ref 를 확인한다.

## 2. 운영 Supabase SELECT-only export

아래 세 파일은 운영 Supabase 에서 실행 가능한 SELECT-only 파일이다.

| CSV | 실행 DB | SQL 파일 | 목적 |
|---|---|---|---|
| `selfpia_sku_alias.csv` | Product_code `mrqoqmidnrawflwezxlm` | `sql/export_product_code_selfpia_sku_alias_select_only.sql` | `order_items.p_code` 직접 매칭 |
| `own_sku_alias.csv` | Product_code `mrqoqmidnrawflwezxlm` | `sql/export_product_code_own_sku_alias_select_only.sql` | fallback 후보 및 모호성 측정 |
| `order_items_xmap.csv` | PR_system `vgxocngpykhlkosiaeew` | `sql/export_pr_system_order_items_xmap_select_only.sql` | 주문상품 라인 기준 입력 |

각 파일은 두 개의 SELECT 를 포함한다.

1. 첫 번째 SELECT: context 확인용. DB/project 를 확인한다.
2. 두 번째 SELECT: CSV export 대상. Supabase SQL Editor 에서 결과를 CSV 로 저장한다.

Supabase CSV export 방법:

1. 올바른 Supabase project 를 연다.
2. 해당 `*_select_only.sql` 파일의 context SELECT 를 실행하고 expected project 를 확인한다.
3. export SELECT 만 실행한다.
4. SQL Editor 결과 테이블에서 CSV 다운로드를 선택한다.
5. 지정 파일명으로 저장한다.

`sql/precheck_cross_mapping_v2.sql` 에도 원본 절차가 남아 있지만, 실제 export 는 위 분리 파일을 우선 사용한다.

## 3. 로컬/검증 PostgreSQL 적재

로컬 또는 검증 PostgreSQL 에서만 아래 파일을 실행한다. 노트북 Docker PostgreSQL 실행 절차는 `docs/local_docker_test_runbook.md` 를 우선 따른다.

- `sql/local_cross_mapping_stage_and_measure.sql`

이 파일에는 `stg_xmap` schema 생성, staging table 생성, psql client-side `\copy` 안내, STEP C-1~C-5 측정 SQL 이 포함되어 있다. 운영 Supabase 에서는 절대 실행하지 않는다.

로컬 적재 방법:

1. `docker compose --env-file .env.local -f docker-compose.local-test.yml up -d` 로 로컬 PostgreSQL 을 띄운다.
2. 로컬/검증 PostgreSQL 에 접속한다.
3. `local_cross_mapping_stage_and_measure.sql` 의 STEP B-1 까지 실행해 staging table 을 만든다.
4. STEP B-2 의 `\copy` 명령을 psql 에서 실행한다.
5. STEP B-3 row count sanity check 를 확인한다.
6. STEP C-1~C-5 를 순서대로 실행한다.

적재 후 기대 기본 행 수:

| staging table | 기대 행 수 |
|---|---:|
| `stg_xmap.selfpia_sku_alias` | 33,287 |
| `stg_xmap.own_sku_alias` | 31,975 |
| `stg_xmap.order_items` | 6,169 |

## 4. 측정 순서

1. STEP C-1: `selfpia_sku_code` 직접 매칭률 측정
2. STEP C-2: 1순위 실패 라인만 대상으로 `own_sku` fallback unique/ambiguous/unmatched 측정
3. STEP C-3: 최종 미매칭 sample 확인
4. STEP C-4: 중복/모호 매칭 sample 확인
5. STEP C-5: 미매칭 `p_code` 형식 분포 확인

## 5. 기록 위치

결과는 `docs/db_integration_inventory.md` 의 `§5.3 STEP C 결과 기록 템플릿` 에 채운다. 실행 상태와 다음 작업은 `docs/codex_handoff_status.md` 에도 갱신한다.

판정:

- 직접 매칭률 100%: `order_items.p_code` 를 canonical key 로 ETL 확정 가능
- 직접 매칭률 100% 미만: 미매칭 라인을 `stg.unmatched_order_items` 로 격리하고 상품팀 보강 SOP 진행
- `own_sku` ambiguous: 자동 확정 금지, 중복 해소 규칙 확정 전 보류

## 6. 실제 실행 결과 (2026-05-12)

노트북 Docker PostgreSQL 로컬 검증 DB (`product_ops_test`) 에서 cross mapping 을 실측했다.

| 항목 | 값 |
|---|---:|
| `selfpia_sku_alias` staging rows | 33,287 |
| `own_sku_alias` staging rows | 31,975 |
| `order_items` staging rows | 6,169 |
| total_lines | 6,169 |
| matched_p1 | 6,164 |
| match_rate_p1_pct | 99.92 |
| unmatched_p1 | 5 |
| distinct_p_code | 2,742 |
| unmatched_distinct_p_code | 5 |

미매칭 p_code 는 `9826-1`, `9826-3`, `9826-26`, `9826-31`, `9826-48` 이다. 상품명은 모두 `925 실버 피어싱 귀걸이 원터치 미니 링피어싱 귓바퀴 93종` 으로 확인되었고, 현재 판단상 배송완료 과거 주문으로 보인다.

판정:

- Product_code 와 PR_system 은 `p_code` / `selfpia_sku` 기준으로 99.92% 직접 연결 가능하다.
- NAS PostgreSQL 통합 가능성은 높다.
- 미매칭 5건은 master FK 강제 실패를 피하기 위해 `stg.unmatched_order_items` 또는 `picking.order_items.master_match_status` 로 격리한다.
- 과거 주문 보존을 위해 raw `p_code` 는 반드시 유지한다.
- 초기 이전 단계에서는 master FK 를 nullable 또는 `NOT VALID` 로 시작한다.

## 7. 절대 금지

- 운영 Supabase 에 `local_cross_mapping_stage_and_measure.sql` 실행 금지
- 운영 Supabase 에 `stg_xmap` 또는 staging table 생성 금지
- 운영 Supabase 에 server-side `COPY` 금지
- 운영 Supabase 또는 NAS 에 `sql/schema_nas_postgresql_draft.sql` 실행 금지
- 운영 Supabase 또는 NAS 에 `sql/post_migration_validation.sql` 실행 금지

`schema_nas_postgresql_draft.sql` 은 cross mapping 이후 로컬 Docker PostgreSQL 에서만 별도 검증한다. NAS 검증은 아직 진행하지 않는다.
