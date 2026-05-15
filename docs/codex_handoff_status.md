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

## Frontend Smoke Test 상태 (2026-05-15)

수행 환경: 격리된 Linux 샌드박스 (사용자 Windows Docker/브라우저 미접근).

샌드박스에서 `frontend/admin`을 `/tmp/feadmin`로 복제 후 코드 정합성 + 빌드 + dev server 응답까지 확인.

- `npm install` 성공: vite 6.4.2, react 19.2.6, react-dom 19.2.6, react-router-dom 7.15.1, @vitejs/plugin-react 4.7.0
- `npx vite build` 성공: 43 modules transformed, bundle 241.73 kB / gzip 76.14 kB
- `npx vite` dev server 기동 성공, `/`, `/src/main.jsx?import`, `/src/App.jsx?import`, `/src/pages/products/ProductListPage.jsx?import` 모두 HTTP 200
- frontend의 API client → service.js/repository.js 응답 shape 정적 검증 통과
  - `ProductListPage.search` 기본값 `LOCAL_TEST`는 service layer `%LOCAL_TEST%` wrap으로 LOCAL_TEST_PM_* 포함 → 변경 불요
  - `AliasSearchPage` 기본 codeValue `LOCAL_TEST_PM_1258-1` seed에 직접 존재 → 변경 불요
  - `ChangeRequestsPlaceholderPage`가 참조하는 `result.meta.message` 키는 service.js와 일치
- `vite.config.js`는 부재하지만 Vite 6 기본 esbuild가 `.jsx` 자동 변환을 수행하므로 빌드/실행 OK. `@vitejs/plugin-react`는 등록되지 않아 React Refresh(HMR)는 비활성 — v1 read-only UI 범위에서 영향 없음.

수정한 파일: 없음 (코드 변경 없음, 문서만 갱신).

사용자 Windows 호스트에서 아직 미수행:

- `docker ps`, `docker logs product_ops_api_local`
- 브라우저 `http://localhost:5173/products` 등 4개 라우트 실제 렌더링
- 사용자 호스트의 API 컨테이너로부터 실제 SKU 2건 렌더링 확인

다음 작업자가 수행해야 할 검증 절차는 `docs/product_management_v1_runbook.md`의 "사용자 Windows 호스트 검증 절차" 섹션 참조.

운영 DB / NAS / schema 변경: 없음.
Local DB 변경: 없음 (seed 재적용 불요, 기존 LOCAL_TEST_PM seed 유지).

## React Runtime ReferenceError 수정 (2026-05-15)

브라우저 검증 중 `Uncaught ReferenceError: React is not defined at App.jsx:10` 발생.

원인: Vite 6 기본 esbuild가 classic JSX transform(`React.createElement`)로 컴파일하지만 각 JSX 파일에 `React` import가 누락된 상태였음. `main.jsx`만 React를 import하고 있었음.

수정 파일 (코드만, DB/API 변경 없음):

- `frontend/admin/src/App.jsx`
- `frontend/admin/src/components/Layout.jsx`
- `frontend/admin/src/components/StatusBadge.jsx`
- `frontend/admin/src/pages/products/ProductListPage.jsx`
- `frontend/admin/src/pages/products/ProductDetailPage.jsx`
- `frontend/admin/src/pages/products/AliasSearchPage.jsx`
- `frontend/admin/src/pages/products/ChangeRequestsPlaceholderPage.jsx`

각 파일 상단에 `import React from 'react';` 또는 기존 named import에 `React`를 추가하는 형태로 처리.

후속 권장 (v1 외 별도 작업): `frontend/admin/vite.config.js`에 `@vitejs/plugin-react`를 등록해 automatic JSX runtime + HMR을 활성화하면 각 파일의 React import 자체가 불필요해진다. 본 v1 read-only 검증에서는 미적용.

운영 DB / NAS / schema 변경: 없음.

## Windows 호스트 실측 검증 완료 (2026-05-15)

사용자 Windows 호스트에서 상품관리 모듈 v1 전체 스택 검증 완료.

Docker / DB:

- Docker Desktop Running
- `product_ops_test_postgres` Running / healthy, host port `5433 → 5432`
- `product_ops_api_local` Running, host port `8080`
- Compose 명령: `docker compose -f docker-compose.local-test.yml -f docker-compose.api-local.yml up -d`

API:

- API 컨테이너 startup log: `Mounted routes: /health, /api/products, /product-code, /picking, /mapping`
- `GET /health` 200, DB=`product_ops_test` / user=`product_ops_tester` 확인
- `GET /api/products/skus?search=LOCAL_TEST_PM` 200
- `GET /api/products/skus/by-code/selfpia_sku/LOCAL_TEST_PM_1258-1` 200
- `GET /api/products/skus/by-code/own_sku/LOCAL_TEST_PM_OWN_AMBIG` 200, ambiguous 후보 2건

Frontend:

- `frontend/admin`에서 `npm.cmd install`, `npm.cmd run dev`로 dev server 기동 성공
- `http://localhost:5173/products` SKU 목록 정상 렌더
- `/products/:skuId` 상세 정상
- `/products/aliases` 정상
- `/products/change-requests` placeholder 표시, 새 요청 버튼 disabled, write 기능 부재 확인

환경 이슈와 해결 (코드 문제 아님, runbook의 "PowerShell 운영 팁" 섹션 참조):

- PowerShell 실행 정책으로 `npm install` 차단 → `npm.cmd install` 사용
- PowerShell `curl`은 `Invoke-WebRequest` alias → `curl.exe` 사용
- 초기 빈 화면 + `React is not defined` → 7개 JSX 파일에 `React` import 추가하여 해결

DB 변경: 없음. Schema 변경: 없음. NAS 적용: 없음. Seed 재적용: 없음.

v1 read-only 원칙 유지 확인:

- master 직접 수정 UI 부재
- change request write UI 부재 (placeholder + disabled)
- 클라이언트가 DB에 직접 접속하지 않고 `/api/*`로만 호출
- `/product-code/*` legacy 라우트 유지

## .gitignore 보강 (2026-05-15)

기존에는 server 측 `node_modules`, `package-lock.json`만 무시했음. frontend 측이 누락되어 있어 다음을 추가:

- `frontend/admin/node_modules/`
- `frontend/admin/.env`
- `frontend/admin/dist/`

## package-lock.json 정책 결정 (2026-05-15)

`package-lock.json`은 재현성 우선을 위해 npm 권장에 따라 commit 대상으로 전환 (server, frontend/admin 모두). 기존 `.gitignore`의 `server/package-lock.json` 라인 제거. `node_modules/`, `.env`, `dist/`는 계속 ignore 유지.

## 변경 파일 인벤토리 (2026-05-15 turn)

코드 변경:

- `frontend/admin/src/App.jsx` — `import React from 'react';` 추가
- `frontend/admin/src/components/Layout.jsx` — `import React from 'react';` 추가
- `frontend/admin/src/components/StatusBadge.jsx` — `import React from 'react';` 추가
- `frontend/admin/src/pages/products/ProductListPage.jsx` — `React` named import 추가
- `frontend/admin/src/pages/products/ProductDetailPage.jsx` — `React` named import 추가
- `frontend/admin/src/pages/products/AliasSearchPage.jsx` — `React` named import 추가
- `frontend/admin/src/pages/products/ChangeRequestsPlaceholderPage.jsx` — `React` named import 추가

설정 변경:

- `.gitignore` — frontend `node_modules`, `package-lock.json`, `.env`, `dist` 추가

문서 변경:

- `docs/product_management_v1_runbook.md` — Windows 호스트 실측 결과, PowerShell 운영 팁, 재현 절차 갱신
- `docs/codex_handoff_status.md` — 본 섹션 포함 Windows 실측 반영

생성하지 않은 항목: `frontend/admin/vite.config.js` (자동 JSX runtime 전환은 별도 작업)
DB / API 코드 변경: 없음.

## 다음 구현 후보 (사용자 결정 필요)

상품관리 v1이 로컬 검증 완료된 시점에서 다음 단계 후보를 정리한다. 모두 v1 read-only 원칙과 master 직접 수정 금지를 유지한다.

### 후보 A — 상품관리 v1 UI polish (read-only)

- 범위: 화면 가독성/사용성 개선만, 데이터/스키마/API 변경 없음
- 작업:
  - 테이블 가로 스크롤 컨테이너 보강 (긴 `virtual_sku_code`, `selfpia_sku_code` 대비)
  - 긴 코드 셀에 ellipsis + copy-to-clipboard 버튼
  - 상세 화면 alias / channel mapping 카드 가독성 (zebra row, sticky header)
  - `/products` 기본 검색어를 `LOCAL_TEST_PM`으로 좁힐지 결정 (현재 `LOCAL_TEST`는 prior seed도 포함)
  - empty / loading / error 상태 UX 보강
- 리스크: 낮음. 코드는 frontend만, DB/API 변경 없음
- 예상 작업량: 작음 (1 세션)
- 적합한 시점: 지금 (검증 직후 폴리시 작업)

### 후보 B — 채널상품관리 모듈 v1 스캐폴드 (read-only)

- 범위: `/api/channels/*` namespace 신설, 채널상품/채널SKU/채널-SKU 매핑 조회
- 작업:
  - 설계 문서 `docs/15_channel_management_v1_scope.md` 작성 (스마트스토어/에이블리/메이크샵/플레이오토 확장 가정)
  - server 측 `server/src/modules/channel-management/` 추가 (routes/service/repository)
  - 기존 `product_code.sku_channel_mapping` view 활용, raw 데이터 보존
  - frontend `/channels`, `/channels/:channelCode` 라우트 추가
  - change request 연동은 v1에서 placeholder만
- 리스크: 중간. 모듈 경계 + 채널별 의미 통일 필요
- 예상 작업량: 중간 (2-3 세션)
- 적합한 시점: 상품관리 v1 폴리시 완료 후

### 후보 C — 피킹 모듈 v1 read-only API 연결

- 범위: 기존 `/picking/*` 라우트를 `/api/picking/*` 신규 namespace에서 read-only로 노출, 태블릿 UI는 별도 후속 작업
- 작업:
  - `/api/picking/order-items`, `/api/picking/unmatched` 등 read-only 라우트 추가 (legacy `/picking/*` 유지)
  - product_code `sku_master`와의 join view 확인
  - `9826-*` legacy unmatched 정책 유지, raw `p_code` 보존
  - frontend는 상품관리 상세 페이지의 "운영 연결" 패널에 link만 유지 (실제 피킹 UI는 후속)
- 리스크: 낮음~중간. DB schema 변경 없음, view 추가만 검토
- 예상 작업량: 작음~중간 (1-2 세션)
- 적합한 시점: 채널 모듈 또는 상품관리 폴리시 이후

### 후보 D — 통합 DB / NAS PostgreSQL 이전 설계 문서 보강

- 범위: 문서만, 실제 DB 변경/이전 없음
- 작업:
  - `docs/10_database_schema_boundaries.md` 보강 (`integration`, `audit`, `cs`, `inspection`, `picking` schema 책임 매트릭스)
  - NAS PostgreSQL 이전 전제 (백업, 복구, RPO/RTO) 문서화
  - Docker API server 유지 기준의 schema 배치 다이어그램
  - "대표님이 AI로 유지보수하기 쉬운 구조" 관점에서 코드/문서 구조 권장사항 정리
- 리스크: 매우 낮음 (문서 작업)
- 예상 작업량: 중간 (2 세션)
- 적합한 시점: 코드 작업 중 휴식기 / 의사결정 정렬이 필요한 시점

### 권장 순서

1. 후보 A (UI polish + 검색어 정리) — 검증 직후 빠르게 마감 (1 세션)
2. 후보 C (피킹 read-only API) — 모듈 패턴 재사용성 검증 (1-2 세션)
3. 후보 B (채널상품관리 스캐폴드) — 채널 의미 통일 설계 후 진입 (2-3 세션)
4. 후보 D (DB 이전 문서) — 병행 가능, 실제 NAS 이전은 별도 승인 절차

대규모 모듈 확장 전에 A로 마감 정돈을 한 번 거쳐 v1 패턴(read-only, change request placeholder)을 다른 모듈에서도 그대로 재사용할 수 있게 한다.

## Channel Mapping Precheck — MakeShop / Ably (2026-05-15)

- 작업명: channel mapping precheck for makeshop / ably
- 실행 주체: Claude Opus 4.7 (Cowork 세션)
- 이번 턴 범위: SELECT-only SQL 작성 + 메이크샵 원본 XML 구조 파악 + handoff 갱신
- DB 변경: 없음 (SELECT-only SQL 만 작성. dryrun/apply 미작성)
- 운영 Supabase / NAS / schema: 변경 없음
- 대상 DB: 로컬 Docker `product_ops_test_postgres` / `product_ops_test`

### 생성/수정 파일

- 신규 `sql/inventory_channel_mapping_precheck.sql` — product_code schema 의 channel 관련 테이블/컬럼 존재 여부, code_alias/channel_*/sku_channel_mapping 의 채널 분포, selfpia_sku/own_sku 매칭 풀 분포, makeshop/ably/메이크샵/에이블리 변형 검색을 한 번에 점검하는 SELECT-only inventory
- 신규 `sql/precheck_makeshop_channel_mapping.sql` — 메이크샵 전용 SELECT-only precheck. 기존 makeshop 데이터 존재 여부, 매칭 후보 키 컬럼 존재 여부, own_sku 모호성 분포, 매칭 가설 출력
- 수정 `docs/codex_handoff_status.md` — 본 섹션 추가

### MakeShop XML 구조 파싱 결과

원본 파일: `메이크샵_ALL_변경양식.xml` (102 MB, UTF-8, MS Office 2003 XML Spreadsheet)

- Workbook 시트: 1개 (`Sheet1`)
- 컬럼 수: 136
- 헤더 구성: row 1 = 한글 설명, row 2 = 영문 필드명, row 3 이후 = 데이터
- 데이터 행 수: 30,587
- 행 형식: 한 상품이 여러 row 에 걸친다. **product 레벨 컬럼(`product_uid`, `barcode`, `product_name` 등)은 상품의 첫 행에만 채워지고, 이후 옵션 row 들은 옵션 셀만 채운다.** 적재 시 forward-fill 필요.
- 셀 형식: `<Cell ss:Index="N">` 으로 sparse 가능. 파서는 ss:Index 를 반드시 처리해야 한다.

#### 핵심 컬럼

| col | 영문 | 한글 | 의미 / 본 분석에서의 역할 |
|---:|---|---|---|
| 5 | `product_uid` | 상품 고유번호 | **MakeShop 내부 product id**. 4,923 distinct (=4,923 makeshop 상품). 매칭 후보 키. |
| 11 | `gid` | 스타일코드 | 39 rows 만 채워짐 — 매칭 부적합. |
| 13 | `product_name` | 상품명 | 참조용. |
| 21 | `opt_value` | 옵션값 | **bracket 안에 own_sku-like 코드** 다수 포함. 31,730 rows 에 bracket 매칭. |
| 30 | `opt_values` | 옵션 조합 값 | opt_value 와 보완 관계. |
| 40 | `sto_code` | 관리코드 | **0 rows** — 본 데이터에서 비어있음. selfpia/own 직접 매칭 불가. |
| 41 | `sto_note` | 옵션비고 | 참조용. |
| 44 | `sto_id` | 옵션 번호 | **MakeShop 옵션 id**. 28,298 rows. (product_uid, sto_id) 쌍 4,898 distinct(=옵션 단위 키 후보). |
| 86 | `supply_product_name` | 도매 사입 상품명 | 0 rows. |
| 126 | `ps_num` | 상품제품코드 | 0 rows — 사용 불가. |
| 132 | `barcode` | 상품 바코드 | 4,923 rows — 상품 1건당 1개. |

#### bracket 패턴 (own_sku 후보)

`opt_value` / `opt_values` 안에 `[ALPHA-DIGITS-DIGITS]` 또는 `[ALPHA-DIGITS-DIGITS_DIGIT]` 형식 bracket 이 다수. 샘플:

`PE-25-21`, `NA-3-10_3`, `NA-3-10_4`, `PI-7-01` ~ `PI-7-07`, `EF-7-09_2` ~ `EF-7-10_5`, `GPA-1-02_5` ~ `GPA-2-04_5`, `SA-3-03_4`, `SA-3-06_5` …

이 패턴은 Product_code DB inventory 의 `own_sku` 형식(`B-1-01`, `CA-3-03_3`, `PI-3-01`)과 일치 → 메이크샵 옵션의 **internal SKU 매칭 1차 후보는 bracket 추출 own_sku** 다. 단, code_alias inventory 에서 own_sku 는 31,975 rows / 18,533 distinct(n:m) 였으므로 **bracket 매칭은 자동 확정 불가**, ambiguous 후보는 검수 분리 필요.

#### 매칭 후보 키 가설 (precheck 결과로 확정 필요)

| no | source | target 후보 | 비고 |
|---:|---|---|---|
| 1 | `product_uid` | `sku_channel_mapping.seller_product_code` (channel_code=`makeshop`) 또는 `channel_product.seller_product_code_raw` | MakeShop 상품 id |
| 2 | `sto_id` | `sku_channel_mapping.channel_sku_code` 또는 `channel_sku.channel_sku_code_raw` | MakeShop 옵션 id |
| 3 | `sto_code` | `code_alias(own_sku)` | **본 데이터에서 빈값** — 사용 불가 |
| 4 | bracket(`opt_value`) | `code_alias(own_sku)` → `sku_master.id` | own_sku 는 n:m → ambiguous 발생 가능 |
| 5 | `barcode` | 보조 키 / 보강용 | selfpia 측 매칭 풀 존재 여부는 precheck 결과로 확인 |
| 6 | `gid`, `ps_num` | 보류 | rows 부족으로 매칭 부적합 |

#### 파싱 방식 제안 (다음 턴에 staging 설계 시 참고. 이번 턴에는 생성/적재 금지)

- Python `xml.etree.ElementTree.iterparse` 로 row 단위 스트리밍 파싱
- `Cell.ss:Index` 반드시 처리
- product 레벨 컬럼은 forward-fill (마지막 비어있지 않은 product_uid 를 옵션 row 들이 상속)
- bracket 추출 regex: `\[([A-Z]+-\d+-\d+(?:_\d+)?)\]`
- 한 row 의 `opt_value` 가 콤마로 분리된 멀티옵션 텍스트(`싱글/크리스탈[PI-7-01],싱글/블랙[PI-7-02]`) 가능 → split 후 옵션 단위로 재구성
- 적재는 staging table 에만, 본 schema 직접 INSERT/UPDATE 금지. **본 턴에서는 어떤 적재/생성 SQL 도 작성하지 않는다.**

### 에이블리 메모 (이번 턴 미확정)

`에이블리 ALL.csv` (3.5 MB, 9,158 데이터 행) 헤더:

`상품 번호, 판매자 상품코드, 상품명, 브랜드, 에이블리 판매가, 에이블리 할인 판매가, 에이블리 최종 판매가(앱), 4910 판매가, 4910 할인 판매가, 4910 현재 판매가, 옵션 번호, 솔루션사 고유코드, 옵션1, 옵션2, 전체 옵션명, 재고수량, 안전재고, 재고 소진시 판매 방식, 품절상태, 진열상태, 카테고리, 상품등록일, 배송 타입, 택배사, 반품 배송비(편도), 도서산간추가배송비(편도), 성별, 병행수입 여부, 주문제작 여부`

미확정 후보 (전부 열어둠. 에이블리 전용 precheck 작성 시 확정):

- `솔루션사 고유코드` = selfpia_sku 후보
- `솔루션사 고유코드` = own_sku 후보
- `솔루션사 고유코드` = channel-side raw code 후보
- `전체 옵션명` 안의 `[EE-8-04_4]` 같은 bracket 값 = own_sku 후보
- `옵션 번호` = ably_option_code 후보 (예: `183276147`)
- `상품 번호` = ably_product_code 후보 (예: `2420824`)
- `판매자 상품코드` = 4910/selfpia product code 후보 (예: `9070`, `9135`)

이번 턴에서는 ably 전용 precheck SQL 을 만들지 않는다. 메이크샵 결과 회신 후 별도 턴에서 작성한다.

### 사용자가 다음에 실행할 명령

```powershell
# 컨테이너 기동 확인
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 필요 시 기동
docker compose -f docker-compose.local-test.yml -f docker-compose.api-local.yml up -d

# (방법 A) 컨테이너 안에서 실행
docker exec -i product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  < sql/inventory_channel_mapping_precheck.sql

docker exec -i product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  < sql/precheck_makeshop_channel_mapping.sql

# (방법 B) host 의 psql 사용
psql -h localhost -p 5433 -U product_ops_tester -d product_ops_test `
  -f sql/inventory_channel_mapping_precheck.sql

psql -h localhost -p 5433 -U product_ops_tester -d product_ops_test `
  -f sql/precheck_makeshop_channel_mapping.sql
```

### 사용자가 회신해야 할 결과

다음 세 가지를 그대로 회신해주면 다음 턴에서 메이크샵 staging 설계와 dry-run SQL 을 확정할 수 있다.

1. `inventory_channel_mapping_precheck.sql` 의 전체 출력 (각 `\echo` 헤더 포함)
2. `precheck_makeshop_channel_mapping.sql` 의 전체 출력 (각 `\echo` 헤더 포함). 일부 SELECT 는 테이블/컬럼 부재로 ERROR 가 날 수 있으며 ERROR 메시지도 그대로 회신
3. 본 문서 "MakeShop XML 구조 파싱 결과" 의 컬럼 해석이 실 운영 의미와 일치하는지 확인 (특히 `sto_id`=옵션 번호, `sto_code`=관리코드, `opt_value bracket`=own_sku)

### 다음 턴 예정 작업

- precheck 결과 기반으로 메이크샵 staging 구조 확정 (channel 명 `makeshop` 사용 여부, sku_channel_mapping vs code_alias 어느 쪽으로 적재할지, channel_product/channel_sku 테이블 부재 시 대안)
- 메이크샵 dryrun SQL 작성 (`sql/dryrun_makeshop_channel_mapping.sql`)
  - BEGIN/ROLLBACK 트랜잭션, no=1..N + no=99 OVERALL verdict
  - bracket 매칭 ambiguous 후보 / 자동 확정 후보 / 미매칭 분리
- 사용자 dryrun 결과 회신 → 명시적 승인 후에만 apply SQL 작성
- 이후 에이블리 전용 precheck → dryrun → 승인 → apply 순서 진행
- 두 채널은 같은 SQL 에 섞지 않음

### 절대 하지 않은 것 / 하지 않을 것 (재확인)

- 운영 Supabase 변경 (없음)
- NAS PostgreSQL 변경 (없음)
- 로컬 DB schema 변경 (없음)
- INSERT/UPDATE/DELETE/ALTER/DROP/CREATE/TRUNCATE/COPY (한 줄도 없음)
- dryrun/apply SQL 작성 (이번 턴 미작성)
- master 테이블 직접 수정 (없음)
- ambiguous 후보 자동 확정 (적용 단계 자체가 없음)

