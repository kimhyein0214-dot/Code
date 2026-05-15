# Codex Handoff Status

작성일: 2026-05-12

## 현재 상태

- 운영 Supabase DB 변경 없음
- 운영 Supabase staging 적재 없음
- 로컬 Docker PostgreSQL 에서 cross mapping 실측 완료
- 로컬 Docker PostgreSQL 에서 schema v2 적용 및 validation 확인 완료
- 로컬 Docker API server endpoint 1차 테스트 완료
- `CREATE / ALTER / INSERT / UPDATE / DELETE / DROP / TRUNCATE` 실행 없음
- 운영 DB 변경 없음. 현재 작업은 문서 업데이트만 수행

## 확인한 파일

- `docs/db_integration_inventory.md`
- `docs/nas_postgresql_integration_plan.md`
- `sql/precheck_cross_mapping_v2.sql`
- `sql/schema_nas_postgresql_draft.sql`
- `sql/post_migration_validation.sql`

## 수정/작성한 파일

- `sql/precheck_cross_mapping_v2.sql`
- `sql/export_product_code_selfpia_sku_alias_select_only.sql`
- `sql/export_product_code_own_sku_alias_select_only.sql`
- `sql/export_pr_system_order_items_xmap_select_only.sql`
- `sql/local_cross_mapping_stage_and_measure.sql`
- `sql/schema_nas_postgresql_draft_v2.sql`
- `sql/local_schema_apply_test.sql`
- `sql/post_migration_validation_v2.sql`
- `docker-compose.local-test.yml`
- `.env.local.example`
- `.gitignore`
- `docs/db_integration_inventory.md`
- `docs/nas_postgresql_integration_plan.md`
- `docs/cross_mapping_runbook.md`
- `docs/local_docker_test_runbook.md`
- `docs/schema_decision_log.md`
- `docs/local_schema_test_runbook.md`
- `docs/api_server_design.md`
- `docs/api_endpoint_plan.md`
- `docs/api_local_test_runbook.md`
- `docs/local_seed_sample_plan.md`
- `docs/local_seed_sample_runbook.md`
- `docs/unmatched_order_items_sop.md`
- `docs/codex_handoff_status.md`
- `docs/00_platform_vision.md`
- `docs/01_module_map.md`
- `docs/02_domain_boundaries.md`
- `docs/03_product_management_module.md`
- `docs/04_channel_management_module.md`
- `docs/05_picking_module.md`
- `docs/06_inspection_module.md`
- `docs/07_cs_module.md`
- `docs/08_api_module_design.md`
- `docs/09_frontend_route_structure.md`
- `docs/10_database_schema_boundaries.md`
- `docs/11_change_request_design.md`
- `docs/12_integration_module_design.md`
- `docs/13_order_lifecycle.md`
- `docs/14_product_management_v1_scope.md`
- `.env.api.example`
- `docker-compose.api-local.yml`
- `server/package.json`
- `server/src/server.js`
- `server/src/db.js`
- `server/src/routes/health.js`
- `server/src/routes/product-code.js`
- `server/src/modules/product-management/routes.js`
- `server/src/modules/product-management/service.js`
- `server/src/modules/product-management/repository.js`
- `server/src/shared/errors.js`
- `server/src/routes/picking.js`
- `server/src/routes/mapping.js`
- `sql/local_seed_sample_data.sql`
- `sql/local_seed_sample_validation.sql`
- `sql/local_check_unmatched_duplicates.sql`
- `sql/local_seed_product_management_v1.sql`
- `sql/local_seed_product_management_v1_validation.sql`
- `frontend/admin/package.json`
- `frontend/admin/.env.example`
- `frontend/admin/index.html`
- `frontend/admin/src/main.jsx`
- `frontend/admin/src/App.jsx`
- `frontend/admin/src/api/client.js`
- `frontend/admin/src/pages/products/ProductListPage.jsx`
- `frontend/admin/src/pages/products/ProductDetailPage.jsx`
- `frontend/admin/src/pages/products/AliasSearchPage.jsx`
- `frontend/admin/src/pages/products/ChangeRequestsPlaceholderPage.jsx`
- `frontend/admin/src/components/Layout.jsx`
- `frontend/admin/src/components/StatusBadge.jsx`
- `frontend/admin/src/styles.css`
- `docs/product_management_v1_runbook.md`

## 핵심 결정

- 기존 cross mapping/schema/API skeleton 산출물은 기술검증 자료로만 참고한다.
- 실제 운영 시스템은 모듈형 운영 플랫폼으로 새로 설계한다.
- 데이터 기준/API/auth/audit/common UI는 통합하되, 화면과 코드는 업무별 모듈로 분리한다.
- `integration` schema는 후보가 아니라 필수 운영 schema로 승격한다.
- Product_code master 변경은 직접 수정 금지이며 change request 기반으로 처리한다.
- 주문/피킹/검품/CS 상태 전이는 order lifecycle 문서를 기준으로 API service layer에서만 수행한다.
- 첫 구현 대상은 상품관리 모듈 v1이며 read-only 중심으로 시작한다.
- 상품관리 v1 최종 API namespace는 `/api/products/*`를 권장하고 기존 `/product-code/*`는 migration alias로 유지한다.
- canonical key 는 `selfpia_sku_code` 역할의 `PR_system.order_items.p_code`
- Product_code 연결은 `code_alias.code_system='selfpia_sku' AND code_alias.code_value = p_code` 를 통해 `sku_master.id` 로 수행
- 로컬 실측 기준 직접 매칭률은 99.92% (`6,164 / 6,169`)
- 미매칭 5건은 과거 배송완료 주문으로 보이며 raw `p_code` 보존 및 격리 처리 권장
- 초기 이전 단계의 master FK 는 nullable 또는 `NOT VALID` 로 시작 권장
- Product_code master 는 API 서버 기준 SELECT-only
- picking / inspection / cs 는 API 서버가 read/write
- 클라이언트는 PostgreSQL 직접 접속 금지, Docker API 서버만 경유

## 보류

- `own_sku` fallback 중복 해소 규칙
- 미매칭 `p_code` 보강 SOP 실제 운영 승인
- `inspection` / `hold_items` 0건 테이블의 실제 사용 여부
- CS 신규 구조 설계 여부
- RLS 비활성 상태 대응
- NAS 장애/백업 정책의 운영 수준 확정

## 다음 작업

1. 모듈형 운영 플랫폼 문서를 기준으로 실제 repo/app 구조 결정
2. server module 구조를 `product-management`, `channel-management`, `picking`, `inspection`, `cs`, `integration-settings` 로 분리
3. frontend route shell을 모듈별로 분리
4. API 서버 write boundary와 인증/JWT 설계
5. change request API와 DB conceptual schema를 실제 schema draft로 구체화
6. `integration` schema tables를 schema v3 draft에 반영
7. order lifecycle status enum과 금지 전이를 service layer 정책으로 구현
8. `sql/local_check_unmatched_duplicates.sql` 로 `/mapping/unmatched` 중복 반환 원인 확인
9. 상품관리 v1 구현 전 React/Vite 여부, modules 리팩토링 여부, local seed 확장 여부 결정

## Cross Mapping 준비 상태

- 운영 DB SELECT-only export 파일 분리 완료
- 로컬 Docker PostgreSQL compose 파일 준비 완료
- 로컬/검증 DB 전용 staging/측정 파일 준비 완료
- 운영 DB 변경 없음
- 로컬 Docker PostgreSQL cross mapping 실측 완료
- 직접 매칭률: 99.92%
- 미매칭: 5 lines / 5 distinct p_code

## Local Docker 테스트 상태

- DB명: `product_ops_test`
- host port: `5433`
- compose file: `docker-compose.local-test.yml`
- env example: `.env.local.example`
- CSV 위치: `exports/`
- 로컬 DB 데이터 위치: `docker-data/postgres/`
- NAS 관련 작업: 아직 진행하지 않음

## Schema v2 준비 상태

- schema v2 draft: `sql/schema_nas_postgresql_draft_v2.sql`
- local apply wrapper: `sql/local_schema_apply_test.sql`
- validation v2: `sql/post_migration_validation_v2.sql`
- decision log: `docs/schema_decision_log.md`
- local schema test runbook: `docs/local_schema_test_runbook.md`
- 적용 대상: 로컬 Docker PostgreSQL `product_ops_test` only
- 운영 Supabase / NAS 적용: 아직 하지 않음
- 로컬 적용/validation: 완료
- 주요 인덱스 53개, 주요 view 4개 확인
- schema별 base table count: audit 2, cs 3, inspection 1, picking 5, product_code 5, stg 2

## API Server Skeleton 상태

- design doc: `docs/api_server_design.md`
- endpoint plan: `docs/api_endpoint_plan.md`
- env example: `.env.api.example`
- compose file: `docker-compose.api-local.yml`
- server root: `server/`
- DB target: local Docker PostgreSQL `product_ops_test`
- Supabase key/service role: 사용하지 않음
- 운영 Supabase / NAS 변경: 없음
- endpoint local test: 완료

## Cross Mapping 실측 결과

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


## API Endpoint Local Test Result (2026-05-12)

실행 환경:

| 항목 | 값 |
|---|---|
| Docker PostgreSQL | `product_ops_test_postgres` |
| Docker API | `product_ops_api_local` |
| API port | `8080` |
| DB | `product_ops_test` |
| DB user | `product_ops_tester` |

확인 endpoint:

| Endpoint | 결과 | 판단 |
|---|---|---|
| `GET /health` | 성공 | `ok=true`, DB 연결 확인 |
| `GET /mapping/summary` | 성공 | `data={}`. local data 부족으로 빈 집계 판단 |
| `GET /mapping/unmatched` | 성공 | `9826-*` 미매칭 데이터 반환 |
| `GET /product-code/skus` | 성공 | `data={}`, `limit=50`. sample 미적재 상태 판단 |
| `GET /picking/order-items` | 성공 | `data={}`, `limit=50`. sample 미적재 상태 판단 |

상태 판단:

- API 서버 구동 성공
- route 응답 성공
- PostgreSQL 접근 구조 검증 완료
- 클라이언트가 DB에 직접 접속하지 않는 구조 1차 검증 완료
- 운영 Supabase 변경 없음
- NAS 변경 없음

다음 단계는 로컬 Docker DB 전용 seed/sample data를 적재해 row 반환 endpoint를 재검증하는 것이다.

## Local Seed Sample 준비 상태

- seed plan: `docs/local_seed_sample_plan.md`
- seed runbook: `docs/local_seed_sample_runbook.md`
- seed SQL: `sql/local_seed_sample_data.sql`
- validation SQL: `sql/local_seed_sample_validation.sql`
- 적용 대상: 로컬 Docker PostgreSQL `product_ops_test` only
- 운영 Supabase / NAS 적용 금지
- 실제 운영 데이터 전체 적재 금지
- 목표: `/product-code/skus`, `/picking/order-items`, `/mapping/summary` 가 실제 sample row를 반환하는지 검증
- 실행 상태: 완료
- row 반환 재검증: 완료

## Local Seed API 재검증 결과

| Endpoint | 결과 |
|---|---|
| `GET /product-code/skus?search=LOCAL_TEST` | 성공, LOCAL_TEST SKU 2건 반환 |
| `GET /product-code/skus/LOCAL_TEST_1258-1` | 성공, 단일 SKU 상세 반환 |
| `GET /picking/order-items?master_match_status=matched` | 성공, matched order item 2건 반환 |
| `GET /picking/unmatched` | 성공, unmatched / ambiguous / legacy_unmatched 3건 반환 |
| `GET /mapping/summary` | 성공, matched 2 / unmatched 1 / ambiguous 1 / legacy_unmatched 1 |
| `GET /mapping/own-sku/ambiguous` | 성공, LOCAL_TEST_OWN_AMBIG 후보 2개 반환 |

추가 확인 필요:

- `GET /mapping/unmatched` 에서 기존 `9826-*` legacy_unmatched 가 raw_p_code별로 2번씩 중복 반환됨.
- 원인 후보: `stg.unmatched_order_items` 자체 중복 또는 line-level endpoint 정책.
- 확인 SQL: `sql/local_check_unmatched_duplicates.sql`

## Modular Platform Design 상태

- 작성 완료: `docs/00_platform_vision.md` ~ `docs/10_database_schema_boundaries.md`
- 보강 완료: `docs/11_change_request_design.md`, `docs/12_integration_module_design.md`, `docs/13_order_lifecycle.md`
- 상품관리 v1 범위 확정 문서: `docs/14_product_management_v1_scope.md`
- 핵심 원칙: 한 화면 통합 금지, 업무별 module/route/server module 분리
- 모듈: 상품관리, 채널상품관리, 주문/피킹, 검품, CS/미송, 연동/설정
- 공유 대상: product_code master, sku_id, code_alias, API 인증/권한, audit log, 공통 UI 컴포넌트
- master 직접 수정 금지, change request 기반
- `integration` schema는 필수 schema
- `audit.domain_events`는 상태 전이, change request, 연동 실패/성공을 기록하는 업무 이벤트 로그
- 주문 lifecycle은 `docs/13_order_lifecycle.md` 기준으로 관리

## Product Management v1 Scope

- 첫 구현 대상: 상품관리 모듈
- 범위: read-only SKU 목록, SKU 상세, alias 조회, 상품/SKU/code 검색
- 제외: master 직접 수정, alias 수정, SKU 수정, approval workflow, master writer
- change request: disabled button 또는 placeholder route까지만
- 최종 API namespace 제안: `/api/products/*`
- 기존 `/product-code/*`: v1 기간 migration alias로 유지
- frontend 후보 구조: `frontend/admin/products/`
- server 후보 구조: `server/src/modules/product-management/`

## Product Management v1 구현 준비 상태

- Backend module 생성 완료: `server/src/modules/product-management/`
- Read-only API 등록 완료: `/api/products/*`
- Migration alias 유지: `/product-code/*`
- Startup log에 mounted routes 출력 추가: `/health`, `/api/products`, `/product-code`, `/picking`, `/mapping`
- Docker compose는 `./server:/app` 볼륨을 사용하므로 `server/src/modules/product-management/*`가 컨테이너에 포함됨
- React + Vite admin skeleton 생성 완료: `frontend/admin/`
- Local seed 확장 SQL 작성 완료: `sql/local_seed_product_management_v1.sql`
- Local validation SQL 작성 완료: `sql/local_seed_product_management_v1_validation.sql`
- Runbook 작성 완료: `docs/product_management_v1_runbook.md`
- 운영 Supabase/NAS 변경 없음
- `/api/products` mount 누락 현상 수정 및 컨테이너 재시작 확인 완료
- 확인 완료 endpoint: `/health`, `/product-code/skus?search=LOCAL_TEST_PM`, `/api/products/skus?search=LOCAL_TEST_PM`, `/api/products/skus/by-code/selfpia_sku/LOCAL_TEST_PM_1258-1`
- by-code API는 같은 SKU에 local selfpia alias가 여러 개 있어도 SKU당 1건으로 반환하도록 보정
- 아직 frontend 실행 검증은 별도 테스트 단계로 남김


## v1 UI Polish (2026-05-15)

상품관리 모듈 v1 frontend/admin 화면을 read-only 원칙 내에서 가독성과 read-only 명확성을 개선한다. DB / API / schema / route 표면은 변경하지 않는다.

### 변경 파일

코드:

- `frontend/admin/src/components/CopyButton.jsx` (신규)
- `frontend/admin/src/components/StatusBadge.jsx` (CodeSystemBadge 신규 export 추가)
- `frontend/admin/src/components/Layout.jsx` (사이드바 read-only 안내 + env-banner)
- `frontend/admin/src/pages/products/ProductListPage.jsx`
- `frontend/admin/src/pages/products/ProductDetailPage.jsx`
- `frontend/admin/src/pages/products/AliasSearchPage.jsx`
- `frontend/admin/src/pages/products/ChangeRequestsPlaceholderPage.jsx`
- `frontend/admin/src/styles.css`

문서:

- `docs/product_management_v1_runbook.md` (v1 UI Polish 섹션 추가)
- `docs/codex_handoff_status.md` (본 섹션 추가)

변경 없음:

- `frontend/admin/src/App.jsx` (router 동일)
- `frontend/admin/src/main.jsx`
- `frontend/admin/src/api/client.js`
- `server/`, DB / schema / seed

### 화면별 변경 요약

- 공통 Layout — 사이드바 brand 부제 "v1 read-only", 사이드바 하단 안내, 메인 영역 상단 노란색 READ-ONLY env-banner
- SKU 목록 — 기본 검색어 `LOCAL_TEST_PM`, 예시 chip 3개, 셀 ellipsis + CopyButton, 상품명/옵션 2줄 clamp, empty 안내 보강, hint
- SKU 상세 — Header CopyButton, read-only banner, dl 코드값 CopyButton, alias/mapping 패널 헤더 건수, CodeSystemBadge, Primary pill, 운영 연결 패널 안내 추가
- Alias 검색 — code system select 한글 label, 시스템별 예시 chip 4개, 결과 1건 초과 → "복수 후보 N건" warn notice (own_sku ambiguous 강조), 결과 1건 → ok notice, empty 시 3가지 원인 안내
- Change Requests — readonly-banner-strong, "새 요청" 버튼 disabled 유지 (aria-disabled+title), v1 상태 패널 + v1 범위 밖 항목 패널

### read-only 원칙 재확인

- master 직접 수정 UI 부재
- change request write UI 부재 (버튼 disabled, body 는 안내만)
- DB 직접 접속 없음 (api client 는 `/api/products/*` 만 호출)
- 레거시 `/product-code/*` 라우트는 제거하지 않음

### 검증 (격리된 Linux 샌드박스)

- esbuild bundle dry-run: 0 errors / 0 warnings
- `vite build` 성공: bundle `index-CPcET2fT.js` 252,025 byte / css `index-C6hanVm3.css` 6,380 byte
- `vite dev --port 5175` 기동 후 다음 11 URL 모두 HTTP 200
  - `/`, `/src/main.jsx`, `/src/App.jsx`, `/src/styles.css`
  - `/src/components/Layout.jsx`, `/src/components/StatusBadge.jsx`, `/src/components/CopyButton.jsx`
  - `/src/pages/products/{ProductListPage,ProductDetailPage,AliasSearchPage,ChangeRequestsPlaceholderPage}.jsx`

### 사용자 Windows 호스트에서 확인 필요

- 실제 브라우저에서 4개 라우트 렌더 (`/products`, `/products/:skuId`, `/products/aliases`, `/products/change-requests`)
- 사용자 호스트 `http://localhost:8080` API 컨테이너로부터 SKU 2건 / alias / ambiguous own_sku 2건 / change request placeholder 메시지 렌더
- copy 버튼 동작 (clipboard 권한, fallback)
- 좁은 폭에서 ellipsis 가 줄바꿈으로 전환되는지

### 본 turn 에서 하지 않은 것

- 운영 Supabase / NAS / 로컬 DB schema 변경
- master / code_alias / channel mapping write
- `/product-code/*` 라우트 제거
- GitHub push / `git add`
- 메이크샵·에이블리 코드매칭 (다른 세션에서 진행)

## MakeShop dryrun 준비 (2026-05-15, Claude Opus 4.7)

### 결정 사항 (사용자 승인)

- DDL 즉시 적용: **NO**
- 기존 `sku_channel_mapping` 직접 apply 설계: **NO**
- 최종 구조: `channel_product` / `channel_sku` / `channel_sku_review_draft` 3계층 기반 (이번 turn에는 미적용)
- 이번 turn 범위: 원본 XML 추출 + CSV 검증 + SELECT-only dryrun SQL 초안까지
- XML 파싱 위치: **외부 스크립트(Python stdlib)**. PostgreSQL `xmltable`/`xpath`로 102MB XML 직접 파싱 금지
- 검증 범위 순서: sample100 → full 4923

### 작성한 산출물

| 파일 | 역할 |
|---|---|
| `scripts/extract_makeshop_minimal_csv.py` | SpreadsheetML 2003 XML → CSV. `ss:Index` 희소셀 처리, product-level 컬럼 forward-fill, sample100/full 두 출력. utf-8-sig 인코딩 기본. iterparse + root.clear()로 102MB 메모리 안정. stdlib only. |
| `scripts/validate_makeshop_csv.py` | CSV 11개 지표 출력: row_count, product_uid distinct/blank, sto_id/sto_code blank, bracket hits + unique codes, sto_id 중복 키/행, (product_uid, sto_id) 중복 키/행. |
| `sql/dryrun_makeshop_select_only.sql` | TEMP TABLE + `\copy` + 4 result set (SUMMARY / AUTO_CONFIRM / REVIEW_REQUIRED / CONFLICT). `BEGIN ... ROLLBACK` 래퍼, `product_ops_test` 가드, INSERT/UPDATE/DELETE/ALTER/CREATE(persistent) 일체 없음. |

### MakeShop XML 최소 추출 컬럼

매칭키 후보: `product_uid`, `sto_id`, `sto_code`, `opt_value`

raw/reference 보존만: `barcode`, `product_name`, `status`, `gid`, `ps_num`

own_sku 추출 우선순위:

1. `sto_code` 비어있지 않으면 → 그대로 own_sku 후보로 사용
2. 비어있으면 → `opt_value`에서 `[ALPHA-NN-NN(_N)]` 정규식으로 추출
3. 둘 다 실패 → review_required

forward-fill 대상 (product-level): `product_uid`, `product_name`, `status`, `barcode`, `gid`, `ps_num`

forward-fill 미적용 (option-level): `sto_id`, `sto_code`, `opt_value`

### 자동확정 기준 (auto_confirm)

모두 만족 시:

1. `product_uid`, `sto_id` null/blank 아님
2. own_sku 후보 추출 성공 (sto_code 또는 bracket)
3. own_sku 후보가 `code_alias(target_type='SKU', code_system='own_sku')`에서 **단일 SKU**로 매칭 (match_count = 1)
4. 기존 `sku_channel_mapping(channel_code='makeshop', channel_sku_code=sto_id)` 부재
5. 매칭 SKU의 `sku_master.status`가 inactive/deleted/archive 패턴이 아님

### review 기준 (review_required) — review_reason enum

precedence: `null_key` > `pattern_unmatched` > `own_sku_missing` > `own_sku_not_in_alias` > `own_sku_ambiguous` > `channel_sku_conflict` > `sku_inactive`

| review_reason | 트리거 |
|---|---|
| null_key | `product_uid` 또는 `sto_id` null/blank |
| pattern_unmatched | `sto_code` blank + `opt_value` 존재하나 bracket 정규식 실패 |
| own_sku_missing | own_sku 후보 자체가 없음 (sto_code blank + opt_value blank/bracket 실패) |
| own_sku_not_in_alias | 후보 있으나 `code_alias`에 매칭 없음 (match_count = 0) |
| own_sku_ambiguous | 후보 1개가 SKU 2개 이상에 매칭 (match_count > 1) |
| channel_sku_conflict | 기존 `sku_channel_mapping`에 (makeshop, sto_id) 존재 — sku 동일 여부 무관, 전부 review |
| sku_inactive | 매칭 SKU의 status가 inactive/deleted/archive 패턴 |

### 사용자 실행 절차 (sample100 dryrun)

```powershell
# 1. XML → CSV 추출 (workspace 루트에서)
python scripts\extract_makeshop_minimal_csv.py `
  --input-xml "data\메이크샵_ALL_변경양식.xml" `
  --output-full outputs\makeshop_minimal_full.csv `
  --output-sample outputs\makeshop_minimal_sample100.csv `
  --sample-rows 100

# 2. CSV 구조 검증
python scripts\validate_makeshop_csv.py outputs\makeshop_minimal_sample100.csv

# 3. dryrun SQL 실행 (sample100, default)
$env:PGPASSWORD = '<password>'
psql -h localhost -p 5433 -U product_ops_tester -d product_ops_test `
     -v ON_ERROR_STOP=1 `
     -f sql\dryrun_makeshop_select_only.sql

# 4. (sample 검증 OK 후) full 4923 dryrun
psql -h localhost -p 5433 -U product_ops_tester -d product_ops_test `
     -v ON_ERROR_STOP=1 `
     -v CSV_PATH="'outputs/makeshop_minimal_full.csv'" `
     -f sql\dryrun_makeshop_select_only.sql
```

XML 파일 경로(`data\메이크샵_ALL_변경양식.xml`)는 사용자 환경에 맞게 조정 필요. 스크립트는 경로를 인자로 받습니다.

### 다음 단계

1. 사용자 호스트에서 sample100 추출/검증/dryrun 실행
2. SUMMARY / AUTO_CONFIRM / REVIEW_REQUIRED / CONFLICT 결과 4종 첨부 → Claude가 분포 분석
3. own_sku 추출 성공률, ambiguous 비율, channel_sku_conflict 발생 여부에 따라 다음 결정:
   - 분류 기준 보강 (예: 새 review_reason 추가)
   - bracket 정규식 변형 필요 여부
   - DDL 적용 (channel_product/channel_sku/channel_sku_review_draft) 시점
4. sample 결과 안정되면 full 4923으로 확장
5. full 결과에서 자동확정 비율 충분하면 별도 turn에서 apply SQL 설계 (그 단계도 사용자 명시 승인 필요)

### 본 turn 변경 없음

- 운영 DB / NAS / Schema / Seed / API / Frontend 동작 코드: 모두 변경 없음
- `product_ops_test` DB: 본 turn에는 접근 없음 (SQL은 사용자가 직접 실행)
- DDL: 미적용 (3개 신규 테이블은 향후 별도 승인 단계)

## MakeShop full dryrun complete / next diagnostics (2026-05-15)

### full dryrun 결과

입력 CSV:

- `outputs/makeshop_minimal_full.csv`
- row 기준: full dryrun 출력 `30,586` rows

dryrun SQL:

- `sql/dryrun_makeshop_select_only.sql`
- TEMP TABLE + `\copy` + `BEGIN ... ROLLBACK`
- `channel_sku_code = product_uid || '-' || sto_id` composite 방식
- `product_ops_test` guard 포함
- DB 영구 변경 없음

SUMMARY:

| 항목 | 값 |
|---|---:|
| total_rows | 30,586 |
| auto_confirm | 11,089 |
| review_required | 19,497 |
| r_null_key | 2,288 |
| r_pattern_unmatched | 1,354 |
| r_own_sku_missing | 0 |
| r_own_sku_not_in_alias | 489 |
| r_own_sku_ambiguous | 15,366 |
| r_channel_sku_conflict | 0 |
| r_sku_inactive | 0 |

SUMMARY by extraction_method:

| extraction_method | rows | auto_confirm | review_required |
|---|---:|---:|---:|
| `(none)` | 3,613 | 0 | 3,613 |
| `opt_value_bracket` | 4,792 | 2,392 | 2,400 |
| `opt_values_bracket` | 22,181 | 8,697 | 13,484 |

CONFLICT:

- `0` rows
- composite `channel_sku_code` 기준 기존 `sku_channel_mapping` 충돌은 full dryrun 기준 없음

### 현재 판단

- MakeShop pipeline 자체는 정상으로 판단
- `product_uid || '-' || sto_id` composite key는 기존 channel mapping과 conflict 0
- `auto_confirm` 11,089건은 apply 후보일 수 있으나, apply 전에 `own_sku` alias 적재 상태/품질 검증 필요
- 가장 큰 review 원인은 `own_sku_ambiguous` 15,366건
- `own_sku_not_in_alias` 489건은 alias 누락 후보로 별도 전수 export 필요
- `null_key` 2,288건은 대부분 `sto_id` blank인 product-level/meta row 후보
- `pattern_unmatched` 1,354건은 샘플 확인 후 정규식 보강 여부 판단

### 이번 진단 SQL 산출물

| 파일 | 목적 |
|---|---|
| `sql/check_local_own_sku_coverage.sql` | `product_code.code_alias`의 `code_system='own_sku'` 적재 상태, target 분포, ambiguous bucket, MakeShop 후보와 alias 교집합 확인 |
| `sql/diagnose_makeshop_composite_uniqueness.sql` | full CSV 내부에서 `product_uid || '-' || sto_id` composite key unique 여부 최종 확인 |
| `sql/diagnose_makeshop_ambiguous_own_sku.sql` | `own_sku_ambiguous` 원인 분석: own_sku별 발생 row, candidate SKU 수, extraction method 분포, 반복 패턴 |
| `sql/export_makeshop_review_samples.sql` | review reason별 CSV export: null_key/pattern_unmatched sample, own_sku_not_in_alias full, own_sku_ambiguous sample |
| `sql/export_makeshop_auto_confirm_candidates.sql` | apply가 아닌 auto_confirm 후보 CSV export |

### 금지 상태 유지

- 운영 Supabase 접근/변경 금지
- 운영 DB / 로컬 DB 영구 변경 금지
- apply SQL 작성 금지
- `sku_channel_mapping` 실제 INSERT 금지
- `channel_product` / `channel_sku` / `channel_sku_review_draft` DDL 생성/적용 금지
- API / Frontend 동작 코드 변경 금지
- 이번 진단은 SELECT, TEMP TABLE, `\copy`, `BEGIN`, `ROLLBACK` 범위만 사용

### 사용자 실행 명령

공통 사전 복사:

```powershell
docker cp .\outputs\makeshop_minimal_full.csv product_ops_test_postgres:/tmp/makeshop_minimal_full.csv
```

진단 SQL 실행 패턴:

```powershell
docker cp .\sql\check_local_own_sku_coverage.sql product_ops_test_postgres:/tmp/check_local_own_sku_coverage.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/check_local_own_sku_coverage.sql 2>&1 |
  Tee-Object -FilePath .\outputs\check_local_own_sku_coverage_result.txt
```

나머지 파일도 같은 방식으로 실행:

- `sql/diagnose_makeshop_composite_uniqueness.sql` → `outputs/diagnose_makeshop_composite_uniqueness_result.txt`
- `sql/diagnose_makeshop_ambiguous_own_sku.sql` → `outputs/diagnose_makeshop_ambiguous_own_sku_result.txt`
- `sql/export_makeshop_review_samples.sql` → `outputs/export_makeshop_review_samples_result.txt`
- `sql/export_makeshop_auto_confirm_candidates.sql` → `outputs/export_makeshop_auto_confirm_candidates_result.txt`

export SQL 실행 후 컨테이너 `/tmp` CSV 회수:

```powershell
docker cp product_ops_test_postgres:/tmp/makeshop_review_null_key_sample.csv .\outputs\makeshop_review_null_key_sample.csv
docker cp product_ops_test_postgres:/tmp/makeshop_review_pattern_unmatched_sample.csv .\outputs\makeshop_review_pattern_unmatched_sample.csv
docker cp product_ops_test_postgres:/tmp/makeshop_review_own_sku_not_in_alias_full.csv .\outputs\makeshop_review_own_sku_not_in_alias_full.csv
docker cp product_ops_test_postgres:/tmp/makeshop_review_own_sku_ambiguous_sample.csv .\outputs\makeshop_review_own_sku_ambiguous_sample.csv
docker cp product_ops_test_postgres:/tmp/makeshop_auto_confirm_candidates.csv .\outputs\makeshop_auto_confirm_candidates.csv
```

PowerShell에서는 `< file.sql` 리다이렉션을 쓰지 않고, `docker cp` + `docker exec ... psql -f` 방식을 사용한다.

### 다음 판단 기준

1. `own_sku` coverage가 충분한지: `code_alias(code_system='own_sku')`에서 unique_1 비중이 높고 MakeShop 후보의 unique alias match가 충분한지 확인
2. composite key가 batch 내부 unique인지: duplicate channel_sku_code keys/rows가 0이면 `product_uid || '-' || sto_id` 유지 가능
3. ambiguous 축소 기준: ambiguous top 100, opt_values fallback 반복 패턴, 같은 product_uid 내 반복 own_sku를 보고 정규식/후보 우선순위/수동 리뷰 기준 결정
4. auto_confirm export로 넘어갈지: coverage, uniqueness, ambiguous 원인이 납득 가능하고 `auto_confirm` 후보 CSV 표본이 정상일 때만 다음 단계 검토

## Product Management v1 UI Polish round 2 (2026-05-15)

frontend/admin 상품관리 v1 화면을 card/list preview UI로 개선했다. 이번 작업은 이미지 연결 전 placeholder 단계이며 read-only 원칙을 유지했다.

수정/작성 파일:

- `frontend/admin/src/components/EmptyImagePlaceholder.jsx`
- `frontend/admin/src/components/ProductThumbnail.jsx`
- `frontend/admin/src/components/ProductMetaChips.jsx`
- `frontend/admin/src/components/ProductCardRow.jsx`
- `frontend/admin/src/pages/products/ProductListPage.jsx`
- `frontend/admin/src/pages/products/ProductDetailPage.jsx`
- `frontend/admin/src/pages/products/AliasSearchPage.jsx`
- `frontend/admin/src/styles.css`
- `docs/product_management_v1_runbook.md`
- `docs/codex_handoff_status.md`

화면 변경:

- SKU 목록: 기존 테이블을 96px 이미지 슬롯이 있는 카드형 리스트로 전환. Selfpia SKU / Virtual SKU chip과 status badge, copy button 유지.
- SKU 상세: 상단 preview 헤더에 큰 이미지 placeholder, 상품명, 옵션, meta chip, status badge 추가. alias / channel mapping 패널 유지.
- Alias 검색: 결과 리스트에 64px placeholder 썸네일 추가. ambiguous notice, code system badge, copy button 유지.
- Change Requests: 코드 변경 없음. disabled/read-only 상태 유지.

이미지 placeholder:

- `ProductThumbnail`은 `src`가 없거나 `img onError` 발생 시 `EmptyImagePlaceholder`를 렌더한다.
- 현재 API에 `thumbnail_url` / `image_url` 필드가 없으므로 placeholder만 표시된다.
- 추후 API 응답에 이미지 URL이 추가되면 컴포넌트 props 그대로 연결 가능하다.

검증:

- `npm.cmd run build` 성공.
- Vite build: 48 modules transformed, css `9.95 kB`, js `254.40 kB`.
- React Router dependency의 `"use client"` ignored 경고 2건은 빌드 성공 상태에서 발생하는 dependency warning으로 남음.

다음 단계:

- 운영 Supabase에 있는 `product_image` 데이터를 local DB로 export/import할지 결정 필요.
- DB schema에 `product_code.product_image` 또는 equivalent image table/view를 추가하는 patch 필요 여부 결정.
- API list/detail/by-code 응답에 `thumbnail_url` 또는 `image_url` 추가 필요.
- 실제 이미지 연결은 별도 승인 후 진행.

## Product Management v1 image connection step 2 preparation (2026-05-15)

상품관리 v1 실제 이미지 연결을 위한 상태 점검과 SQL 초안 작성까지만 진행했다. `product_image` export CSV가 없고 local DB에도 image table이 없으므로 DB apply/import, API join 변경, frontend 변경은 하지 않았다.

### 상태 점검

- `server/src/modules/product-management/repository.js`: 현재 `product_code.v_sku_canonical` 중심 조회. `image_url` / `thumbnail_url` 응답 없음.
- frontend image 연결 지점:
  - `ProductCardRow`: `product.thumbnail_url || product.image_url`
  - `ProductDetailPage`: `sku.thumbnail_url || sku.image_url`
  - `AliasSearchPage`: `row.thumbnail_url || row.image_url`
- local DB:
  - `product_code.product_image`: 없음.
  - `product_master`: 6,175 rows.
  - `sku_master`: 33,289 rows.
  - `code_alias`: 65,273 rows.
  - `v_sku_canonical`: 33,291 rows.
- image/export 파일 검색:
  - `rg --files exports outputs sql scripts | rg "image|product_image|thumbnail"` 결과 없음.

### 작성한 파일

- `sql/export_product_code_product_image_select_only.sql`
- `sql/schema_local_patch_product_image.sql`
- `sql/precheck_product_image_import.sql`
- `sql/stage_product_image_import.sql`
- `sql/dryrun_product_image_import.sql`
- `sql/postcheck_product_image_import.sql`
- `docs/product_management_v1_runbook.md`
- `docs/codex_handoff_status.md`

### 검증

- Docker container 확인: `product_ops_test_postgres`, `product_ops_api_local` running.
- `precheck_product_image_import.sql` read-only 실행 성공.
- `postcheck_product_image_import.sql` read-only 실행 성공.
- postcheck는 `product_code.product_image` 미존재 상태에서 notice를 출력하고 image rows 0건으로 통과.
- `1258-1`, `11258-1`, `LOCAL_TEST_PM_1258-1` postcheck sample은 모두 `thumbnail_url` / `image_url` null.

### 변경하지 않은 것

- DB schema apply 없음.
- product_image import 없음.
- API repository 변경 없음.
- frontend 변경 없음.
- 운영 Supabase / NAS 변경 없음.
- Git add / commit / push 없음.

### 다음 승인 필요

1. 운영 Supabase product_image source 구조 확인 및 SELECT-only export.
2. export CSV 확보 후 local-only schema patch 적용.
3. stage/dryrun 결과 검토.
4. apply SQL 작성 승인.
5. local image table/data 준비 후 API `thumbnail_url` / `image_url` join 변경.

## Product Management v1 image CSV coverage and dryrun (2026-05-15)

`exports/selfpia_image_url.csv` 확보 후 local Docker PostgreSQL에서 TEMP coverage 진단과 dryrun insert simulation을 실행했다. persistent DB 변경은 하지 않았다.

### Source CSV

- File: `exports/selfpia_image_url.csv`
- Original file name: `셀피아코드-이미지url-자사코드.csv`
- Columns: `p_code`, `image_url`, `updated_at`, `own_code`
- Mapping: `p_code` -> `product_code.code_alias(code_system='selfpia_sku', code_value=p_code)` -> `sku_master.id`
- `own_code`는 key로 사용하지 않음.

### Created/updated SQL

- `sql/precheck_product_image_csv_coverage.sql`
- `sql/schema_local_patch_product_image.sql`
- `sql/stage_product_image_import.sql`
- `sql/dryrun_product_image_import.sql`
- `sql/postcheck_product_image_import.sql`

### Coverage summary

| Metric | Value |
|---|---:|
| CSV rows | 32,094 |
| distinct p_code | 32,094 |
| duplicated p_code | 0 |
| blank image_url | 12,762 |
| blank own_code | 5,080 |
| matched distinct p_code | 32,062 |
| unmatched distinct p_code | 32 |
| rows with image and matched SKU | 19,331 |
| rows with image but unmatched SKU | 1 |
| blank image but matched SKU | 12,731 |
| SKUs with image rows | 19,331 |
| SKUs with multiple image rows | 0 |
| image URLs reused by multiple SKUs | 0 |

### Dryrun summary

| Metric | Value |
|---|---:|
| rows with image URL | 19,332 |
| ready insert rows | 19,331 |
| image orphan rows | 1 |
| simulated insert rows | 19,331 |
| duplicate primary image SKUs | 0 |
| reused image URL count | 0 |

Sample results:

- `1000-1`: image URL present.
- `1258-1`: image URL present.
- `11258-1`: no image URL in CSV.
- `LOCAL_TEST_PM_1258-1`: no image URL in CSV.
- unmatched image sample: `8276-2`.

no=99 `OVERALL` verdict: `REVIEW` because `image_orphan_rows = 1`.

### Current stop point

- No apply SQL was created.
- No schema DDL was applied.
- No product_image rows were inserted.
- No API repository change.
- No frontend change.
- Next user decision:
  1. Apply while skipping unmatched image rows, or
  2. Backfill/fix missing alias for `8276-2` first and rerun dryrun.

### User decision and updated dryrun

User approved skipping unmatched image row `8276-2` and proceeding with local-only apply preparation.

Updated files:

- `sql/dryrun_product_image_import.sql`
- `sql/apply_product_image_import.sql`
- `sql/postcheck_product_image_import.sql`
- `docs/product_management_v1_runbook.md`
- `docs/codex_handoff_status.md`

Updated dryrun result:

| Metric | Value |
|---|---:|
| ready insert rows | 19,331 |
| image orphan rows | 1 |
| skipped orphan image rows | 1 |
| skipped p_code | `8276-2` |
| duplicate primary image SKUs | 0 |
| no=99 OVERALL | PASS |

Current state:

- `sql/apply_product_image_import.sql` exists.
- Apply has not been executed.
- `product_code.product_image` has not been created/applied in DB by this step.
- API repository has not been changed.
- Frontend has not been changed.

Next local execution order:

1. Copy CSV and SQL files into `product_ops_test_postgres:/tmp`.
2. Run `sql/schema_local_patch_product_image.sql`.
3. Run `sql/apply_product_image_import.sql`.
4. Run `sql/postcheck_product_image_import.sql`.
5. If postcheck passes, update API repository to add `thumbnail_url` / `image_url`.

## Product Management v1 image API join complete (2026-05-15)

After local DB image apply/postcheck succeeded, API repository was updated to include `thumbnail_url` and `image_url` in read-only product responses.

### Confirmed local DB state

- `product_code.product_image` exists.
- image rows: 19,331.
- primary rows: 19,331.
- duplicate primary image SKUs: 0.
- skipped orphan image rows: 1 (`8276-2`).
- postcheck overall: PASS.

### Code changed

- `server/src/modules/product-management/repository.js`

Changed functions:

- `listSkus`
- `getSkuById`
- `findSkusByCode`
- `searchProducts`

No endpoint paths changed. `/api/products/*` and `/product-code/*` remain mounted.

### Join strategy

All image lookups use `LEFT JOIN LATERAL` with `LIMIT 1` so SKU rows do not duplicate. The lookup uses `product_code.product_image.sku_id`, ordered by:

1. `is_primary DESC`
2. `sort_order ASC`
3. `id ASC`

Rows without images return `thumbnail_url: null` and `image_url: null`.

### Verification

API container restarted:

```powershell
docker restart product_ops_api_local
```

API checks:

- `GET /api/products/skus?search=1258-1&limit=5`
  - `1258-1`: image URL present.
  - `11258-1`: image URL null.
- `GET /api/products/skus?search=1000-1&limit=5`
  - `1000-1`: image URL present.
- `GET /api/products/skus?search=11258-1&limit=5`
  - image URL null.
- `GET /api/products/skus/by-code/selfpia_sku/1258-1`
  - image URL present.
- `GET /api/products/search?q=1258-1&type=all&limit=5`
  - image fields included.
- `GET /product-code/skus/1258-1`
  - migration alias still works and includes image fields.

Frontend check:

- `npm.cmd run build` succeeded.
- `/products` search `1258-1`: 4 cards, 1 image tag, 3 placeholders.
- `/products` search `1000-1`: 1 card, 1 image tag, 0 placeholders.
- `/products` search `11258-1`: 1 card, 0 image tags, 1 placeholder.

Remote image pixel loading was not fully confirmed in headless Chrome during the short check, but API image URLs were rendered into `<img src>` and null-image placeholder behavior was confirmed.

## MakeShop auto_confirm 후보군 검증 단계 (2026-05-15)

### 현재 판단

full dryrun 및 review/export 진단 기준:

| 항목 | 값 |
|---|---:|
| total_rows | 30,586 |
| auto_confirm | 11,089 |
| review_required | 19,497 |
| null_key | 2,288 |
| pattern_unmatched | 1,354 |
| own_sku_not_in_alias | 489 |
| own_sku_ambiguous | 15,366 |
| channel_sku_conflict | 0 |
| sku_inactive | 0 |

- `auto_confirm` 11,089건은 apply 후보군으로 볼 수 있으나, 아직 apply 미승인 상태이다.
- composite `channel_sku_code = product_uid || '-' || sto_id`는 batch 내부 duplicate 0으로 확인됐다.
- `own_sku_ambiguous`는 `own_sku` alias 자체가 SKU unique key가 아닌 구조와 `opt_values` 첫 bracket 반복이 주요 원인이다.
- `pattern_unmatched`에는 `EE-9-14-03`, `GN-01-01-2`처럼 4-part hyphen 코드가 섞여 있어 추가 regex 진단이 필요하다.
- `own_sku_not_in_alias` 489건은 245 distinct own_sku alias 누락 후보로 별도 보강 검토 대상이다.

### 이번 추가 진단 SQL 산출물

| 파일 | 목적 |
|---|---|
| `sql/diagnose_makeshop_pattern_unmatched_regex.sql` | `pattern_unmatched` 1,354건을 대상으로 4-part hyphen/underscore 확장 regex가 own_sku 후보를 회수할 수 있는지 측정 |
| `sql/diagnose_makeshop_auto_confirm_quality.sql` | auto_confirm 11,089건의 matched SKU 품질 검수: SKU/Product master 컬럼, extraction method별 sample, repeated own_sku/SKU 이상 징후 |
| `sql/diagnose_makeshop_ambiguous_reduction_candidates.sql` | ambiguous 행의 candidate SKU pool을 master/alias/selfpia 컬럼과 함께 펼쳐 2차 축소 기준 후보를 탐색 |

### 금지 상태 유지

- apply SQL 작성 금지
- DDL 작성/적용 금지
- `sku_channel_mapping` 실제 INSERT 금지
- 운영 Supabase 접근/변경 금지
- 운영 DB / 로컬 DB 영구 변경 금지
- API / Frontend 동작 코드 변경 금지
- 이번 진단 SQL은 SELECT, TEMP TABLE, `\copy`, `BEGIN`, `ROLLBACK`만 사용

### 사용자 실행 명령

공통 사전 복사:

```powershell
docker cp .\outputs\makeshop_minimal_full.csv product_ops_test_postgres:/tmp/makeshop_minimal_full.csv
```

pattern_unmatched regex 진단:

```powershell
docker cp .\sql\diagnose_makeshop_pattern_unmatched_regex.sql product_ops_test_postgres:/tmp/diagnose_makeshop_pattern_unmatched_regex.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/diagnose_makeshop_pattern_unmatched_regex.sql 2>&1 |
  Tee-Object -FilePath .\outputs\diagnose_makeshop_pattern_unmatched_regex_result.txt
```

auto_confirm 품질 진단:

```powershell
docker cp .\sql\diagnose_makeshop_auto_confirm_quality.sql product_ops_test_postgres:/tmp/diagnose_makeshop_auto_confirm_quality.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/diagnose_makeshop_auto_confirm_quality.sql 2>&1 |
  Tee-Object -FilePath .\outputs\diagnose_makeshop_auto_confirm_quality_result.txt
```

ambiguous 축소 후보 진단:

```powershell
docker cp .\sql\diagnose_makeshop_ambiguous_reduction_candidates.sql product_ops_test_postgres:/tmp/diagnose_makeshop_ambiguous_reduction_candidates.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/diagnose_makeshop_ambiguous_reduction_candidates.sql 2>&1 |
  Tee-Object -FilePath .\outputs\diagnose_makeshop_ambiguous_reduction_candidates_result.txt
```

PowerShell에서는 `< file.sql` 리다이렉션을 쓰지 않고, `docker cp` + `docker exec ... psql -f` 방식을 사용한다. SQL 내부 CSV 경로는 `/tmp/makeshop_minimal_full.csv` literal path를 사용한다.

### 다음 판단 기준

1. 추가 regex로 `pattern_unmatched` 중 `unique_1` alias match가 얼마나 회수되는지 확인한다.
2. auto_confirm 후보에서 repeated `matched_sku_id` / repeated `own_sku_code`가 실제 중복 위험인지, 정상적인 다채널/동일 SKU 반복인지 표본 검수한다.
3. ambiguous candidate SKU의 `option_value`, `virtual_sku_code`, selfpia alias가 MakeShop `opt_values` 토큰과 구분 가능한지 확인한다.
4. 위 진단이 안정적이면 이후 별도 승인 단계에서만 apply 설계를 검토한다.

## MakeShop dryrun v2 preparation (2026-05-15)

### 목적

기존 full dryrun 결과를 바탕으로 apply가 아닌 SELECT-only 보강 dryrun을 준비했다.

v2 목적:

- 기존 auto_confirm 11,089건을 `auto_confirm_existing_regex`로 보존
- 4-part bracket code(`EE-9-14-03`, `PC-23-01-1`, `GN-01-01-2`)를 기존 regex 뒤에 추가
- 추가 regex로 unique_1 매칭되는 후보를 `auto_confirm_new_regex_candidate`로 분리
- loose 4-part regex는 자동확정에 사용하지 않고 `review_loose_regex_only` 진단으로만 사용
- 기존 auto_confirm 중 `matched_sku_id` 3회 이상 반복 케이스는 제외하지 않고 review flag로 노출
- ambiguous는 자동해소하지 않고 candidate option/selfpia token diagnostic만 출력

### 기존 full dryrun 요약

| 항목 | 값 |
|---|---:|
| total_rows | 30,586 |
| auto_confirm | 11,089 |
| review_required | 19,497 |
| null_key | 2,288 |
| pattern_unmatched | 1,354 |
| own_sku_not_in_alias | 489 |
| own_sku_ambiguous | 15,366 |
| channel_sku_conflict | 0 |
| sku_inactive | 0 |

### 추가 진단 판단 반영

- 추가 regex는 최대 623 rows에서 후보를 잡았고, 그중 unique_1 row는 90건으로 추정됐다.
- 다만 같은 row가 여러 regex/source에 중복 hit되므로 v2에서는 후보 선택 우선순위를 명시했다.
- 후보 선택 우선순위:
  1. `sto_code`
  2. `opt_value` existing bracket
  3. `opt_values` existing bracket
  4. `opt_value` 4-part bracket
  5. `opt_values` 4-part bracket
  6. loose 4-part regex는 diagnostic only
- auto_confirm 기존 후보에서 repeated matched_sku 3+ key는 14개로 확인됐고, apply blocker 여부는 아직 미정이다.

### 작성 파일

| 파일 | 목적 |
|---|---|
| `sql/dryrun_makeshop_select_only_v2.sql` | SELECT-only v2 dryrun. 4-part regex 회수, repeated auto flag, ambiguous token diagnostic, conflict sample 출력 |

### 금지 상태 유지

- apply SQL 작성 금지
- DDL 작성/적용 금지
- `sku_channel_mapping` 실제 INSERT 금지
- 운영 Supabase 접근/변경 금지
- 운영 DB / 로컬 DB 영구 변경 금지
- API / Frontend 동작 코드 변경 금지
- v2 SQL은 SELECT, TEMP TABLE, `\copy`, `BEGIN`, `ROLLBACK`만 사용

### 사용자 실행 명령

```powershell
docker cp .\outputs\makeshop_minimal_full.csv product_ops_test_postgres:/tmp/makeshop_minimal_full.csv

docker cp .\sql\dryrun_makeshop_select_only_v2.sql product_ops_test_postgres:/tmp/dryrun_makeshop_select_only_v2.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/dryrun_makeshop_select_only_v2.sql 2>&1 |
  Tee-Object -FilePath .\outputs\dryrun_makeshop_select_only_v2_result.txt
```

PowerShell에서는 `< file.sql` 리다이렉션을 쓰지 않고, `docker cp` + `docker exec ... psql -f` 방식을 사용한다. SQL 내부 CSV 경로는 `/tmp/makeshop_minimal_full.csv` literal path를 사용한다.

### v2 이후 판단 기준

1. 기존 auto_confirm 11,089건이 `auto_confirm_existing_regex`로 그대로 유지되는지 확인한다.
2. 추가 regex unique_1 후보가 실제로 몇 건인지 확인한다.
3. repeated matched_sku 3+ flag가 apply blocker인지 단순 review flag인지 결정한다.
4. ambiguous 자동해소는 계속 금지할지, token scoring 진단을 더 깊게 할지 결정한다.
5. v2 결과가 안정적이면 다음 단계에서만 `auto_confirm export v2` 작성 여부를 검토한다.

## MakeShop auto_confirm export v2 (2026-05-15)

### 목적

v2 dryrun 결과를 바탕으로 apply가 아닌 SELECT-only CSV export SQL을 작성했다.

Export 대상:

- `auto_confirm_existing_regex`
- `auto_confirm_new_regex_candidate`

Export 제외:

- `null_key`
- `pattern_unmatched`
- `own_sku_not_in_alias`
- `own_sku_ambiguous`
- `loose_regex_only`
- `channel_sku_conflict`
- `sku_inactive`

### v2 dryrun 기준값

| 항목 | 값 |
|---|---:|
| total_rows | 30,587 |
| auto_confirm_existing_regex | 11,089 |
| auto_confirm_new_regex_candidate | 90 |
| v2 auto_confirm 후보 합계 | 11,179 |
| channel_sku_conflict | 0 |
| sku_inactive | 0 |
| loose_regex_only | 18 |
| repeated matched_sku 3+ rows | 42 |
| repeated matched_sku 3+ keys | 14 |

### 판단 유지

- 기존 11,089건은 `auto_confirm_existing_regex`로 유지한다.
- 신규 90건은 bracketed 4-part regex 기반 `auto_confirm_new_regex_candidate`로 분리한다.
- loose 4-part regex는 자동확정에서 제외한다.
- ambiguous 자동해소 금지는 유지한다.
- repeated `matched_sku_id` 3+는 apply blocker가 아니라 review flag로 취급한다.

### 작성 파일

| 파일 | 목적 |
|---|---|
| `sql/export_makeshop_auto_confirm_candidates_v2.sql` | SELECT-only v2 auto_confirm 후보 11,179건 CSV export. `BEGIN` / `ROLLBACK`, product_ops_test guard, TEMP TABLE, `\copy TO`만 사용 |

### 금지 상태 유지

- apply SQL 작성 금지
- DDL 작성/적용 금지
- `sku_channel_mapping` 실제 INSERT 금지
- 운영 Supabase 접근/변경 금지
- 운영 DB / 로컬 DB 영구 변경 금지
- API / Frontend 동작 코드 변경 금지

### 사용자 실행 명령

```powershell
docker cp .\outputs\makeshop_minimal_full.csv product_ops_test_postgres:/tmp/makeshop_minimal_full.csv

docker cp .\sql\export_makeshop_auto_confirm_candidates_v2.sql product_ops_test_postgres:/tmp/export_makeshop_auto_confirm_candidates_v2.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/export_makeshop_auto_confirm_candidates_v2.sql 2>&1 |
  Tee-Object -FilePath .\outputs\export_makeshop_auto_confirm_candidates_v2_result.txt

docker cp product_ops_test_postgres:/tmp/makeshop_auto_confirm_candidates_v2.csv .\outputs\makeshop_auto_confirm_candidates_v2.csv
```

PowerShell에서는 `< file.sql` 리다이렉션을 쓰지 않고, `docker cp` + `docker exec ... psql -f` 방식을 사용한다. SQL 내부 CSV 경로는 `/tmp/makeshop_minimal_full.csv` literal path를 사용한다.

### 다음 판단 기준

1. export rows가 11,179인지 확인한다.
2. duplicate `channel_sku_code`가 0인지 확인한다.
3. `new_regex_candidate` 90건의 표본이 실제 own_sku 코드로 타당한지 확인한다.
4. repeated `matched_sku_id` 3+ 42 rows / 14 keys가 단순 review flag인지 확인한다.
5. export CSV 검수 후 별도 승인 단계에서만 apply 설계로 넘어갈지 판단한다.

## MakeShop auto_confirm v2 검수 및 v3 보정 준비 (2026-05-15)

### v2 export 검수 결과

`outputs/export_makeshop_auto_confirm_candidates_v2_result.txt` 및 `outputs/makeshop_auto_confirm_candidates_v2.csv` 기준:

| 항목 | 값 |
|---|---:|
| export rows | 11,179 |
| duplicate channel_sku_code | 0 |
| existing_regex | 11,089 |
| new_regex_candidate | 90 |
| repeated matched_sku 3+ rows | 42 |
| repeated matched_sku 3+ keys | 14 |

v2 export 자체의 총량, duplicate, 분포, repeated flag는 기대값과 일치했다.

### 발견한 위험

MakeShop CSV에서 `opt_value`가 전체 옵션 목록이고 `opt_values`가 실제 선택 옵션인 케이스가 있다. v2 우선순위는 `opt_value` bracket을 `opt_values` bracket보다 먼저 선택하므로, 전체 옵션 목록의 첫 bracket code를 잘못 잡을 수 있다.

확인된 위험 row:

- 총 8건
- `existing_regex`: 7건
- `new_regex_candidate`: 1건

대표 사례:

| channel_sku_code | v2 선택 own_sku | opt_values 실제 선택 후보 |
|---|---|---|
| `961868-1` | `EE-10-04-01` | `진주볼/왼쪽[EE-10-05-01]` |

이 때문에 v2 CSV는 그대로 apply 후보로 확정하지 않는다.

### v3 목적

v3는 `opt_values`가 실제 선택 옵션에 더 가깝다는 판단을 반영해 bracket code 추출 우선순위를 보정한다.

v3 우선순위:

1. `sto_code`, nonblank일 때만
2. `opt_values` existing bracket
3. `opt_values` 4-part bracket
4. `opt_value` existing bracket
5. `opt_value` 4-part bracket
6. loose regex는 자동확정 제외, diagnostic only

### 작성 파일

| 파일 | 목적 |
|---|---|
| `sql/dryrun_makeshop_select_only_v3.sql` | SELECT-only v3 dryrun. opt_values 우선순위 보정 및 v2/v3 변경 지표 출력 |
| `sql/export_makeshop_auto_confirm_candidates_v3.sql` | SELECT-only v3 auto_confirm CSV export. v2 선택 코드/SKU 및 changed flag 포함 |

### 금지 상태 유지

- apply SQL 작성 금지
- DDL 작성/적용 금지
- `sku_channel_mapping` 실제 적재 금지
- 운영 Supabase 접근/변경 금지
- 운영 DB / 로컬 DB 영구 변경 금지
- API / Frontend 동작 코드 변경 금지

### 사용자 실행 명령

```powershell
docker cp .\outputs\makeshop_minimal_full.csv product_ops_test_postgres:/tmp/makeshop_minimal_full.csv

docker cp .\sql\dryrun_makeshop_select_only_v3.sql product_ops_test_postgres:/tmp/dryrun_makeshop_select_only_v3.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/dryrun_makeshop_select_only_v3.sql 2>&1 |
  Tee-Object -FilePath .\outputs\dryrun_makeshop_select_only_v3_result.txt

docker cp .\sql\export_makeshop_auto_confirm_candidates_v3.sql product_ops_test_postgres:/tmp/export_makeshop_auto_confirm_candidates_v3.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/export_makeshop_auto_confirm_candidates_v3.sql 2>&1 |
  Tee-Object -FilePath .\outputs\export_makeshop_auto_confirm_candidates_v3_result.txt

docker cp product_ops_test_postgres:/tmp/makeshop_auto_confirm_candidates_v3.csv .\outputs\makeshop_auto_confirm_candidates_v3.csv
```

### 다음 판단 기준

1. v3 export rows가 몇 건인지 확인한다.
2. v2 대비 auto 후보가 얼마나 바뀌었는지 확인한다.
3. `changed_matched_sku_id_rows`가 몇 건인지 확인한다.
4. 기존 위험 8건이 v3에서 `opt_values` 기준으로 해결됐는지 확인한다.
5. v3 new regex 후보가 여전히 타당한지 표본 검수한다.
6. 그 후에야 apply 설계 여부를 별도 승인 단계에서 판단한다.

## MakeShop auto_confirm v3 apply dryrun preparation (2026-05-15)

### 현재 판단

v3 검수 결과 `outputs/makeshop_auto_confirm_candidates_v3.csv`는 apply 후보로 볼 수 있다. 단, 즉시 apply하지 않고 apply 설계안과 rollback 기반 dryrun apply SQL을 먼저 준비했다.

v3 기준:

| 항목 | 값 |
|---|---:|
| total auto_confirm candidates | 11,179 |
| existing_regex | 11,088 |
| new_regex_candidate | 91 |
| duplicate channel_sku_code | 0 |
| conflict | 0 |
| changed_matched_sku_id_rows | 8 |
| selected_code_not_in_opt_values_rows | 0 |
| repeated matched_sku 3+ | 42 rows / 14 keys |

위험 8건은 v3에서 `opt_values` 우선순위로 보정 완료됐다. repeated matched_sku 3+는 apply blocker가 아니라 review flag로 유지한다.

### 작성 파일

| 파일 | 목적 |
|---|---|
| `docs/makeshop_auto_confirm_apply_plan.md` | v3 auto_confirm 후보를 `product_code.sku_channel_mapping`에 반영하기 위한 설계안. 실제 apply SQL 아님 |
| `sql/dryrun_apply_makeshop_auto_confirm_v3.sql` | `/tmp/makeshop_auto_confirm_candidates_v3.csv`를 TEMP TABLE에 적재하고, `information_schema` 기반 컬럼 확인 후 transaction 안에서 INSERT simulation 후 ROLLBACK |

### 설계 요약

- source CSV: `outputs/makeshop_auto_confirm_candidates_v3.csv`
- container source: `/tmp/makeshop_auto_confirm_candidates_v3.csv`
- expected rows: 11,179
- target table: `product_code.sku_channel_mapping`
- `channel_code`: `makeshop`
- `channel_sku_code`: `product_uid || '-' || sto_id`
- `seller_product_code`: `seller_product_code_raw`
- internal SKU: `matched_sku_id`
- optional metadata: `own_sku_code`, `extraction_method`, `regex_pattern_used`, `auto_confirm_type`, repeated flag, changed_from_v2 flag 등은 target 컬럼 또는 `raw_payload`가 있으면 저장하고, 없으면 dryrun result set에만 표시한다.

### Conflict policy

- 기존 mapping 없음: insert candidate
- 동일 `channel_code + channel_sku_code`가 같은 SKU로 존재: idempotent skip
- 동일 key가 다른 SKU로 존재: conflict, insert 제외
- source duplicate key / null required key / missing matched SKU: blocker

### 금지 상태 유지

- 실제 apply SQL 작성 금지
- DDL 작성/적용 금지
- 운영 Supabase 접근/변경 금지
- 운영 DB / API / Frontend 변경 금지
- `dryrun_apply_makeshop_auto_confirm_v3.sql`은 INSERT simulation을 포함하지만 transaction 끝에서 반드시 `ROLLBACK`한다.

### 사용자 실행 명령

```powershell
docker cp .\outputs\makeshop_auto_confirm_candidates_v3.csv product_ops_test_postgres:/tmp/makeshop_auto_confirm_candidates_v3.csv

docker cp .\sql\dryrun_apply_makeshop_auto_confirm_v3.sql product_ops_test_postgres:/tmp/dryrun_apply_makeshop_auto_confirm_v3.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/dryrun_apply_makeshop_auto_confirm_v3.sql 2>&1 |
  Tee-Object -FilePath .\outputs\dryrun_apply_makeshop_auto_confirm_v3_result.txt
```

PowerShell에서는 `< file.sql` 리다이렉션을 쓰지 않고, `docker cp` + `docker exec ... psql -f` 방식을 사용한다.

### 다음 단계

1. `outputs/dryrun_apply_makeshop_auto_confirm_v3_result.txt`를 검수한다.
2. dryrun apply 결과가 PASS인지 확인한다.
3. 사용자 명시 승인 후에만 실제 apply SQL 작성을 검토한다.

## MakeShop auto_confirm v3 real local apply SQL prepared (2026-05-15)

### 현재 상태

`dryrun_apply_makeshop_auto_confirm_v3.sql` 결과가 PASS로 확인되어, 사용자 승인 하에 로컬 `product_ops_test` DB 전용 실제 apply SQL과 postcheck SQL을 작성했다.

중요: SQL 파일만 작성했으며, 실행은 하지 않았다.

### Dryrun apply PASS 기준

| 항목 | 값 |
|---|---:|
| source_rows | 11,179 |
| insert_candidate_rows | 11,179 |
| idempotent_existing_rows | 0 |
| conflict_existing_different_sku_rows | 0 |
| duplicate_source_channel_sku_code | 0 |
| null_required_key_rows | 0 |
| missing_matched_sku_rows | 0 |
| inserted_rows in dryrun transaction | 11,179 |
| delta in dryrun transaction | 11,179 |
| expected_delta_matches | true |
| rollback | complete |

### 작성 파일

| 파일 | 목적 |
|---|---|
| `sql/apply_makeshop_auto_confirm_v3.sql` | 로컬 `product_ops_test` 전용 실제 apply SQL. `/tmp/makeshop_auto_confirm_candidates_v3.csv`를 staging TEMP table에 적재하고 11,179건 clean insert 조건을 만족할 때만 `product_code.sku_channel_mapping`에 insert 후 `COMMIT` |
| `sql/postcheck_makeshop_auto_confirm_v3.sql` | apply 후 read-only postcheck. 11,179건 반영, missing/conflict/duplicate/null key 여부 확인 |

### Apply SQL 정책

- 실제 apply 대상: 로컬 `product_ops_test` DB
- 운영 DB 접근/변경 금지
- persistent DDL 없음
- API/Frontend 변경 없음
- target table: `product_code.sku_channel_mapping`
- source: `/tmp/makeshop_auto_confirm_candidates_v3.csv`
- expected insert rows: 11,179
- channel_code: `makeshop`
- conflict policy:
  - source duplicate key 있으면 fail
  - null required key / missing matched SKU 있으면 fail
  - 기존 같은 key + 같은 SKU도 first apply에서는 fail
  - 기존 같은 key + 다른 SKU는 fail
  - clean 11,179 insert 후보일 때만 commit

### 사용자 실행 명령

실제 apply는 rollback dryrun이 아니라 `COMMIT`되는 로컬 DB 변경이다.

```powershell
docker cp .\outputs\makeshop_auto_confirm_candidates_v3.csv product_ops_test_postgres:/tmp/makeshop_auto_confirm_candidates_v3.csv

docker cp .\sql\apply_makeshop_auto_confirm_v3.sql product_ops_test_postgres:/tmp/apply_makeshop_auto_confirm_v3.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/apply_makeshop_auto_confirm_v3.sql 2>&1 |
  Tee-Object -FilePath .\outputs\apply_makeshop_auto_confirm_v3_result.txt
```

Postcheck:

```powershell
docker cp .\sql\postcheck_makeshop_auto_confirm_v3.sql product_ops_test_postgres:/tmp/postcheck_makeshop_auto_confirm_v3.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/postcheck_makeshop_auto_confirm_v3.sql 2>&1 |
  Tee-Object -FilePath .\outputs\postcheck_makeshop_auto_confirm_v3_result.txt
```

### 다음 판단 기준

1. apply result에서 `COMMIT` 완료 여부 확인.
2. apply postcheck에서:
   - source rows = 11,179
   - matched_source_rows = 11,179
   - missing_mapping_rows = 0
   - conflict_rows = 0
   - duplicate_channel_sku_code_keys = 0
   - null_key_or_missing_sku_rows = 0
3. postcheck PASS 후에도 운영 DB 적용은 별도 설계/승인 단계에서만 검토한다.

## MakeShop auto_confirm v3 local apply PASS and review plan (2026-05-15)

### 완료 상태

로컬 `product_ops_test` DB에서 MakeShop `auto_confirm v3` apply 및 postcheck가 PASS로 확인됐다.

| 항목 | 값 |
|---|---:|
| target table | `product_code.sku_channel_mapping` |
| channel_code | `makeshop` |
| inserted_rows | 11,179 |
| makeshop_mapping_rows | 11,179 |
| matched_source_rows | 11,179 |
| duplicate channel_sku_code | 0 |
| conflict rows | 0 |
| missing mapping rows | 0 |
| null key / missing SKU | 0 |
| new_regex_candidate_rows | 91 |
| changed_from_v2_rows | 8 |
| repeated matched_sku 3+ rows | 42 |

`apply_makeshop_auto_confirm_v3.sql`은 `COMMIT` 완료되었고, `postcheck_makeshop_auto_confirm_v3.sql`은 read-only postcheck로 정상 완료됐다.

### 이번 설계 산출물

| 파일 | 목적 |
|---|---|
| `docs/makeshop_review_required_plan.md` | MakeShop 잔여 `review_required` 대상 분류 및 후속 처리 전략 |

### 남은 review_required 처리 방향

- `null_key`: SKU mapping 제외. product-level/meta row 여부 진단.
- `pattern_unmatched`: regex 보강 후보와 manual review 후보 분리.
- `own_sku_not_in_alias`: alias 누락 후보 export 후 별도 alias backfill 설계.
- `own_sku_ambiguous`: 자동해소 금지 유지. `opt_values` token, `sku_master.option_value`, selfpia alias, product_uid context, barcode scope를 사용해 2차 매칭 기준 설계.

### 다음 SQL 제안

아직 작성/실행/적용하지 않는다. 다음 단계에서 SELECT-only 진단 SQL로 진행한다.

- `sql/diagnose_makeshop_review_required_v3_summary.sql`
- `sql/export_makeshop_review_required_v3_samples.sql`
- `sql/diagnose_makeshop_own_sku_not_in_alias_backfill.sql`
- `sql/diagnose_makeshop_ambiguous_token_scoring.sql`
- `sql/diagnose_makeshop_ambiguous_barcode_scope.sql`
- `sql/export_makeshop_ambiguous_manual_review_matrix.sql`

### 금지 상태 유지

- 운영 DB 반영 금지.
- review 대상 apply 금지.
- DDL 금지.
- API/Frontend 변경 금지.

## MakeShop review diagnostics stage 1 prepared (2026-05-15)

### 목적

MakeShop `auto_confirm v3` 로컬 apply PASS 이후 남은 `review_required` 대상에 대해, apply가 아닌 SELECT-only 1차 진단 SQL을 준비했다.

### 작성 파일

| 파일 | 목적 |
|---|---|
| `sql/diagnose_makeshop_review_required_v3_summary.sql` | v3 기준 전체 CSV를 재분류하고, 이미 로컬 apply된 MakeShop mapping 11,179건과의 overlap 및 review reason별 규모 확인 |
| `sql/diagnose_makeshop_own_sku_not_in_alias_backfill.sql` | `own_sku_not_in_alias` row/code를 전수 진단하고, normalized alias 유사 매칭 기반 alias backfill 후보 CSV export |
| `sql/diagnose_makeshop_ambiguous_token_scoring.sql` | `own_sku_ambiguous` candidate SKU matrix를 펼치고 `opt_values` vs `sku_master.option_value` token score를 계산해 자동해소 가능성 후보와 수동검토 후보를 diagnostic label로 분리 |

### 출력 CSV

| 파일 | 생성 위치 |
|---|---|
| own_sku alias backfill 후보 | `/tmp/makeshop_own_sku_not_in_alias_backfill_candidates.csv` |

### 금지 상태 유지

- review 대상 apply 금지
- 운영 DB 반영 금지
- DDL 금지
- API/Frontend 변경 금지
- DB 영구 변경 금지
- 이번 SQL들은 `product_ops_test` guard, `BEGIN` / `ROLLBACK`, `CREATE TEMP TABLE`, SELECT / `\copy TO` 중심으로 작성

### 사용자 실행 명령

```powershell
docker cp .\outputs\makeshop_minimal_full.csv product_ops_test_postgres:/tmp/makeshop_minimal_full.csv

docker cp .\sql\diagnose_makeshop_review_required_v3_summary.sql product_ops_test_postgres:/tmp/diagnose_makeshop_review_required_v3_summary.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/diagnose_makeshop_review_required_v3_summary.sql 2>&1 |
  Tee-Object -FilePath .\outputs\diagnose_makeshop_review_required_v3_summary_result.txt

docker cp .\sql\diagnose_makeshop_own_sku_not_in_alias_backfill.sql product_ops_test_postgres:/tmp/diagnose_makeshop_own_sku_not_in_alias_backfill.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/diagnose_makeshop_own_sku_not_in_alias_backfill.sql 2>&1 |
  Tee-Object -FilePath .\outputs\diagnose_makeshop_own_sku_not_in_alias_backfill_result.txt

docker cp product_ops_test_postgres:/tmp/makeshop_own_sku_not_in_alias_backfill_candidates.csv .\outputs\makeshop_own_sku_not_in_alias_backfill_candidates.csv

docker cp .\sql\diagnose_makeshop_ambiguous_token_scoring.sql product_ops_test_postgres:/tmp/diagnose_makeshop_ambiguous_token_scoring.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/diagnose_makeshop_ambiguous_token_scoring.sql 2>&1 |
  Tee-Object -FilePath .\outputs\diagnose_makeshop_ambiguous_token_scoring_result.txt
```

PowerShell에서는 `< file.sql` 리다이렉션을 쓰지 않고, `docker cp` + `docker exec ... psql -f` 방식을 사용한다.

### 다음 판단 기준

1. review_required reason별 최종 rows 확정
2. already applied MakeShop mapping과 review 대상 overlap이 없는지 확인
3. `own_sku_not_in_alias` normalized alias unique 후보가 실제 backfill 가능한지 검수
4. ambiguous token scoring에서 strong unique top1 후보가 충분히 있는지 확인
5. barcode scope / manual review matrix SQL 작성 여부 결정
## Product Management v1 admin UI refresh (2026-05-15)

### 목적

frontend/admin 상품관리 v1 UI를 read-only 원칙 안에서 깔끔한 관리자 UI로 개편했다. 방향은 밝은 회색 배경, 흰 카드, 넉넉한 spacing, 약한 shadow, 명확한 텍스트 위계, 파란 계열 단일 강조색이다. 토스 스타일에서 영감을 받은 정돈감만 참고했고, 브랜드/화면을 복제하지 않았다.

### 변경 파일

- `frontend/admin/src/styles.css`
- `frontend/admin/src/components/Layout.jsx`
- `frontend/admin/src/components/ProductCardRow.jsx`
- `frontend/admin/src/components/ProductThumbnail.jsx`
- `frontend/admin/src/components/ProductMetaChips.jsx`
- `frontend/admin/src/components/CopyButton.jsx`
- `frontend/admin/src/components/EmptyImagePlaceholder.jsx`
- `frontend/admin/src/pages/products/ProductListPage.jsx`
- `frontend/admin/src/pages/products/ProductDetailPage.jsx`
- `frontend/admin/src/pages/products/AliasSearchPage.jsx`
- `frontend/admin/src/pages/products/ChangeRequestsPlaceholderPage.jsx`
- `docs/product_management_v1_runbook.md`
- `docs/codex_handoff_status.md`

### 화면별 변경

- 공통: 최대폭 1180px, 부드러운 회색 배경, white card surface, read-only banner, 가벼운 sidebar로 정리.
- SKU 목록: 검색 영역을 section card로 묶고, 예시 chip을 정돈했다. 결과는 thumbnail, 상품명, 옵션, 상태, 주요 코드 chip, 상세 이동 affordance가 보이는 card row로 정리했다.
- SKU 상세: 상단 hero card에 이미지, 상품명, 옵션, 상태, 주요 코드를 배치했다. 하단 SKU 정보, 운영 연결, alias, channel mapping panel의 radius/spacing/heading을 통일했다.
- Alias 검색: 검색 조건 card와 결과 card를 분리하고, 썸네일, code system badge, matched code copy, 상품명/옵션 위계를 정리했다.
- Change Requests: read-only placeholder를 더 명확하게 정리하고 새 요청 버튼 disabled 상태를 유지했다.

### 유지한 원칙

- 운영 Supabase 변경 없음.
- NAS 변경 없음.
- DB schema/data 변경 없음.
- API endpoint 변경 없음.
- master write 기능 추가 없음.
- change request write 기능 추가 없음.
- `/api/products/*` 제거 없음.
- `/product-code/*` 제거 없음.
- GitHub push / commit / `git add .` 없음.

### 검증 결과

- `npm.cmd run build`: 성공. React Router dependency의 `"use client"` ignore 경고 2건은 기존 non-blocking 경고.
- 5173 dev server: 기존 실행 중인 Vite 서버가 `http://localhost:5173/products`에 200 응답.
- Browser 확인:
  - `/products`: 렌더 확인.
  - `/products/aliases`: header/search/example/render 확인.
  - `/products/change-requests`: placeholder와 disabled 새 요청 버튼 확인.
  - `/products/:skuId`: hero card, SKU 정보, Alias, Channel Mapping panel 확인.
- SKU 목록 검색:
  - `1258-1`: card 4건.
  - `1000-1`: card 1건.
  - `11258-1`: card 1건.
- `피어싱`: card 50건.
- `LOCAL_TEST_PM`: card 2건.

## MakeShop review_required manual matrix export v1 prepared (2026-05-15)

### 현재 판단

MakeShop `auto_confirm v3` local apply 이후 남은 `review_required` 19,408건에 대해서 추가 자동 apply는 금지한다. 다음 단계는 사람이 검수할 수 있는 CSV matrix export다.

사용자 확인 결과:

| 항목 | 값 |
|---|---:|
| total rows | 30,587 |
| already applied MakeShop rows | 11,179 |
| review_required rows | 19,408 |
| unapplied auto candidate rows | 0 |
| existing mapping different SKU | 0 |
| own_sku_ambiguous | 15,777 |
| null_key | 2,289 |
| pattern_unmatched | 732 |
| own_sku_not_in_alias | 592 |
| loose_regex_only | 18 |

Ambiguous token scoring 판단:

- strong 자동해소 후보: 0
- weak top1 후보: 12,585 rows. 자동반영 금지, manual review 우선순위로만 사용.
- manual review required: 3,211 rows.

`own_sku_not_in_alias` 판단:

- rows: 594 진단 결과가 있었으나, v3 review summary 기준 export는 already-applied overlap을 제외한 `own_sku_not_in_alias` review reason 기준으로 수행한다.
- distinct own_sku code: 284
- alias backfill 자동 후보: 0
- 자동 alias backfill 불가, manual review / alias 후보 목록으로 관리.

### 작성 파일

| 파일 | 목적 |
|---|---|
| `sql/export_makeshop_review_manual_matrix_v1.sql` | `/tmp/makeshop_minimal_full.csv`를 v3 기준으로 재분류하고, 이미 apply된 11,179건을 제외한 review 대상만 5개 CSV로 export |
| `docs/codex_handoff_status.md` | 본 상태 및 실행 명령 기록 |

### Export CSV

| CSV | 대상 |
|---|---|
| `/tmp/makeshop_review_ambiguous_weak_top1_matrix.csv` | ambiguous 중 top1 후보가 1개 있으나 strong 조건은 아닌 weak 후보 |
| `/tmp/makeshop_review_ambiguous_manual_matrix.csv` | ambiguous 중 후보 복수, 동률, 점수 불충분으로 수동 검수 필요한 대상 |
| `/tmp/makeshop_review_not_in_alias_matrix.csv` | own_sku 후보는 있으나 `code_alias(code_system='own_sku')`에 없는 코드별 대표 row |
| `/tmp/makeshop_review_null_key_matrix.csv` | product_uid 또는 sto_id가 비어 SKU mapping 제외 후보인 row |
| `/tmp/makeshop_review_pattern_loose_matrix.csv` | pattern_unmatched 및 loose_regex_only row |

### Safety

- 운영 DB 변경 금지 유지.
- 로컬 DB 영구 변경 없음.
- SQL은 `product_ops_test` guard를 포함한다.
- `BEGIN` / `ROLLBACK` 사용.
- `CREATE TEMP TABLE`만 사용.
- persistent `INSERT` / `UPDATE` / `DELETE` / `ALTER` / `DROP` / `TRUNCATE` 없음.
- review 대상 apply SQL 작성 없음.
- DDL 적용 없음.
- 운영 DB / API / Frontend 변경 없음.

### 실행 명령

```powershell
docker cp .\outputs\makeshop_minimal_full.csv product_ops_test_postgres:/tmp/makeshop_minimal_full.csv

docker cp .\sql\export_makeshop_review_manual_matrix_v1.sql product_ops_test_postgres:/tmp/export_makeshop_review_manual_matrix_v1.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/export_makeshop_review_manual_matrix_v1.sql 2>&1 |
  Tee-Object -FilePath .\outputs\export_makeshop_review_manual_matrix_v1_result.txt
```

### CSV 회수 명령

```powershell
docker cp product_ops_test_postgres:/tmp/makeshop_review_ambiguous_weak_top1_matrix.csv .\outputs\makeshop_review_ambiguous_weak_top1_matrix.csv

docker cp product_ops_test_postgres:/tmp/makeshop_review_ambiguous_manual_matrix.csv .\outputs\makeshop_review_ambiguous_manual_matrix.csv

docker cp product_ops_test_postgres:/tmp/makeshop_review_not_in_alias_matrix.csv .\outputs\makeshop_review_not_in_alias_matrix.csv

docker cp product_ops_test_postgres:/tmp/makeshop_review_null_key_matrix.csv .\outputs\makeshop_review_null_key_matrix.csv

docker cp product_ops_test_postgres:/tmp/makeshop_review_pattern_loose_matrix.csv .\outputs\makeshop_review_pattern_loose_matrix.csv
```

### 다음 판단 기준

1. export summary가 기존 진단값과 맞는지 확인한다.
   - total rows 30,587
   - already applied 11,179
   - review_required 19,408
   - unapplied_auto_candidate 0
2. weak top1 matrix 12,585건은 자동 apply 후보가 아니라 검수 우선순위 목록으로만 사용한다.
3. ambiguous manual matrix 3,211건은 candidate option/selfpia alias/token score를 보고 수동 판단 기준을 설계한다.
4. not_in_alias matrix는 alias 누락 후보 CSV로 관리하되, 자동 alias backfill은 계속 금지한다.
5. null_key matrix는 SKU mapping 제외 또는 product-level/meta row 여부를 분류한다.
6. pattern/loose matrix는 regex 보강 가치가 있는 패턴만 별도 진단한다.
7. review 대상 apply SQL은 별도 승인 전까지 작성하지 않는다.

## Product detail seller code summary UI (2026-05-15)

### 목적

상품 상세 화면에서 `SKU 정보`, `Alias`, `Channel Mapping`으로 분산되어 있던 코드 연결 정보를 사용자 관점의 `판매처별 코드 요약` 표로 먼저 보여주도록 개선했다. raw alias / raw mapping은 삭제하지 않고 하단 보조 정보로 유지했다.

### 수정 파일

- `frontend/admin/src/pages/products/ProductDetailPage.jsx`
- `frontend/admin/src/styles.css`
- `docs/product_management_v1_runbook.md`
- `docs/codex_handoff_status.md`

### 요약표 구성 방식

| 구분 | 판매처 | 상품코드 | 옵션코드 또는 SKU 코드 | 자사코드 | 상태 |
|---|---|---|---|---|---|
| 기준 | Sellpia | `selfpia_product_code` | `selfpia_sku_code` | `own_sku` alias 첫 값 | 기준 |
| 채널 | MakeShop | `seller_product_code` | `channel_sku_code` | `own_sku_code` | 연결됨 |
| 채널 | Smartstore | smartstore mapping의 `seller_product_code` 또는 없음 | `smartstore_option_no` alias / `channel_sku_code` 또는 없음 | own_sku | 연결됨 / 후보 / 미매핑 |
| 채널 | 기타 | channel mapping 값 | channel mapping 값 | own_sku_code | 연결됨 |

Smartstore는 실제 코드가 없어도 숨기지 않고 `미매핑` row로 표시한다.

### 기존 표 처리

- 기존 `Alias` 표는 `Raw Alias` 보조 카드로 유지.
- 기존 `Channel Mapping` 표는 `Raw Channel Mapping` 보조 카드로 유지.
- 두 raw 표 모두 read-only이며 요약표 산출 근거 확인용이다.

### read-only / safety

- DB schema 변경 없음.
- API endpoint 변경 없음.
- local DB 데이터 변경 없음.
- write 기능 추가 없음.
- GitHub push / `git add .` / commit 없음.
- `sku_id` UUID는 요약표에 노출하지 않고 `SKU 정보`의 `내부 ID`로만 작게 표시.

### 검증 결과

- `npm.cmd run build`: 성공. React Router dependency `"use client"` ignore 경고 2건은 기존 non-blocking 경고.
- Browser 확인:
  - `1000-3` (`d4c0a5bf-73f1-4203-a6f8-9a27a44f58da`, image): `판매처별 코드 요약`, Sellpia, MakeShop, Smartstore `미매핑`, raw tables 확인.
  - `1258-1` (`8d76dbe6-31cc-4682-bf34-190d27eaf37a`, image): `판매처별 코드 요약`, Sellpia, MakeShop, Smartstore `미매핑`, raw tables 확인.
  - `11258-1` (`8f4b3764-0c40-4836-bb60-89e44679b710`, no image): placeholder, `판매처별 코드 요약`, Sellpia, MakeShop, Smartstore `미매핑`, raw tables 확인.
- 세 샘플 모두 요약표 내 UUID 미노출 확인.

## Product detail v2 connection review UI (2026-05-15)

### 목적

상품 상세 화면을 실제 검수자가 한눈에 연결 상태를 이해할 수 있도록 v2로 다듬었다. DB/API/schema/data 변경 없이 React UI 구성과 CSS만 변경했다.

### 수정 파일

- `frontend/admin/src/pages/products/ProductDetailPage.jsx`
- `frontend/admin/src/styles.css`
- `docs/product_management_v1_runbook.md`
- `docs/codex_handoff_status.md`

### 연결 상태 요약 구성

`판매처별 코드 요약` 위에 `연결 상태 요약` 카드를 추가했다.

- 기준 SKU: `selfpia_sku_code`
- 자사코드: `own_sku` alias 첫 값, 없으면 `없음`
- 연결 채널: `sku_channel_mapping.channel_code`별 개수. 예: `MakeShop 1개`
- 미매핑 채널: 판매처별 요약 row 중 `미매핑` 상태인 판매처. 현재 Smartstore 미매핑 표시.
- 이미지: `thumbnail_url` 또는 `image_url` 존재 여부에 따라 `있음` / `없음`

### 상태 badge 구성

상태별 class를 분리했다.

- `기준`: `status-reference`
- `연결됨`: `status-connected`
- `후보`: `status-candidate`
- `미매핑`: `status-unmapped`
- `확인필요`: `status-needs-review`

### Smartstore candidate 처리

- confirmed `smartstore_option_no` alias 또는 `smartstore` channel mapping이 있으면 confirmed row를 우선 표시한다.
- `code_alias.code_system = 'smartstore_option_no_candidate'` alias가 있으면 `후보` row로 표시한다.
- confirmed와 candidate가 둘 다 있으면 candidate는 `confirmed 값 우선, 후보는 참고용` 비고로 낮춰 표시한다.
- 확정값처럼 보이지 않도록 상태는 `후보`, 비고는 `자동 후보 / 운영 미확정` 계열로 표시한다.

### Raw 정보 처리

- Raw Alias와 Raw Channel Mapping은 제거하지 않았다.
- 두 섹션은 `details` 기반 접기/펼치기 보조 카드로 변경했다.
- raw 데이터 확인 기능은 유지한다.

### 검증 결과

- `npm.cmd run build`: 성공. React Router dependency `"use client"` ignore 경고 2건은 기존 non-blocking 경고.
- Browser 확인:
  - `/products`: 정상 렌더, `SKU ID` 라벨 미노출.
  - `/products/aliases`: 정상 렌더, Smartstore option no 검색 준비 유지.
  - `/products/change-requests`: 정상 렌더.
  - `1000-3`: 연결 상태 요약, MakeShop row, Smartstore 미매핑, 이미지 있음, raw 접기/펼치기 확인.
  - `1258-1`: 연결 상태 요약, MakeShop row, Smartstore 미매핑, 이미지 있음, raw 접기/펼치기 확인.
  - `11258-1`: 연결 상태 요약, MakeShop row, Smartstore 미매핑, placeholder, raw 접기/펼치기 확인.
- 세 상세 샘플 모두 UUID가 메인 요약과 판매처별 요약 표에 노출되지 않음을 확인했다.

### 금지 상태 유지

- 운영 Supabase 변경 없음.
- NAS 변경 없음.
- DB schema/data 변경 없음.
- API endpoint 변경 없음.
- local DB import/apply 없음.
- write 기능 추가 없음.
- change request write 기능 추가 없음.
- GitHub push / `git add .` / commit 없음.

## Product list connection status UI (2026-05-15)

### 목적

상품 목록(`/products`)에서 상세 화면으로 들어가기 전에 검수자가 SKU별 연결 상태를 빠르게 판단할 수 있도록 카드 row에 판매처/이미지/자사코드 상태 badge를 추가했다. 상세 화면의 `판매처별 코드 요약`과 톤을 맞추되, 목록에서는 핵심 상태만 압축해서 보여준다.

### 수정 파일

- `frontend/admin/src/pages/products/ProductListPage.jsx`
- `frontend/admin/src/components/ProductCardRow.jsx`
- `frontend/admin/src/styles.css`
- `docs/product_management_v1_runbook.md`
- `docs/codex_handoff_status.md`

### 목록 카드 표시 방식

- 목록 API는 그대로 유지한다.
- `ProductListPage`가 목록 조회 후 표시된 SKU의 기존 상세 API를 read-only로 보강 조회해 `aliases`와 `channel_mappings`만 카드에 전달한다.
- `ProductCardRow`는 다음 badge를 표시한다.
  - `MakeShop 연결됨` / `MakeShop 미매핑`
  - `Smartstore 연결됨` / `Smartstore 후보` / `Smartstore 미매핑`
  - `이미지 있음` / `이미지 없음`
  - `자사코드 있음` / `자사코드 없음`

### UUID 처리

- 목록 카드의 핵심 정보는 `selfpia_sku_code`, `own_sku_code`, `selfpia_product_code`, `virtual_sku_code` 중심이다.
- `sku_id` UUID는 목록 메인 카드에 표시하지 않는다.

### 유지 원칙

- DB schema/data 변경 없음.
- API endpoint 변경 없음.
- local DB import/apply 없음.
- ProductDetailPage 변경 없음.
- AliasSearchPage / ChangeRequestsPlaceholderPage 변경 없음.
- GitHub push / `git add .` / commit 없음.
