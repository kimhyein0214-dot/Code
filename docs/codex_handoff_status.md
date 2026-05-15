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
