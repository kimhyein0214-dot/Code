# Product Management v1 Runbook

## 목적

상품관리 모듈 v1을 로컬 Docker PostgreSQL과 로컬 API 서버 기준으로 검증한다. v1은 read-only이며 master 직접 수정, change request POST, 승인, master writer는 포함하지 않는다.

금지:

- 운영 Supabase 변경
- NAS PostgreSQL 적용
- 실제 master UPDATE
- 운영 데이터 전체 적재

## 구조

Backend:

```text
server/src/modules/product-management/
  routes.js
  service.js
  repository.js
server/src/shared/errors.js
```

Frontend:

```text
frontend/admin/
  package.json
  index.html
  .env.example
  src/
    App.jsx
    main.jsx
    api/client.js
    pages/products/
    components/
    styles.css
```

## Local Seed

적용 대상은 `product_ops_test` only다.

```powershell
psql "$env:DATABASE_URL" -f sql/local_seed_product_management_v1.sql
psql "$env:DATABASE_URL" -f sql/local_seed_product_management_v1_validation.sql
```

포함 sample:

- `LOCAL_TEST_PM_1258-1`, `LOCAL_TEST_PM_1258-2` selfpia_sku
- `LOCAL_TEST_PM_1258` selfpia_product
- `LOCAL_TEST_PM_OWN_001` own_sku
- `LOCAL_TEST_SMARTSTORE_OPTION_001` channel code alias
- `LOCAL_TEST_PM_OWN_AMBIG` ambiguous own_sku 후보
- `LOCAL_TEST_SMARTSTORE` channel mapping

## API Server 실행

```powershell
cd server
npm install
npm run dev
```

기본 API port는 `8080`이다. `.env.api` 또는 실행 환경의 `DATABASE_URL`은 local Docker PostgreSQL `product_ops_test`를 가리켜야 한다.

Docker compose 실행 시 `docker-compose.api-local.yml`은 `./server:/app` 볼륨을 사용한다. 따라서 `server/src/modules/product-management/*` 파일은 컨테이너 `/app/src/modules/product-management/*`로 포함된다.

컨테이너 재기동:

```powershell
docker compose -f docker-compose.local-test.yml -f docker-compose.api-local.yml up -d --force-recreate api
docker logs product_ops_api_local --tail 50
```

startup log에 다음 mount가 보여야 한다.

```text
Mounted routes: /health, /api/products, /product-code, /picking, /mapping
```

## API 확인

```text
GET http://localhost:8080/health
GET http://localhost:8080/api/products/skus?search=LOCAL_TEST_PM
GET http://localhost:8080/api/products/skus/by-code/selfpia_sku/LOCAL_TEST_PM_1258-1
GET http://localhost:8080/api/products/skus/by-code/own_sku/LOCAL_TEST_PM_OWN_AMBIG
GET http://localhost:8080/api/products/skus/by-code/smartstore_option_no/LOCAL_TEST_SMARTSTORE_OPTION_001
GET http://localhost:8080/api/products/search?q=LOCAL_TEST_SMARTSTORE_OPTION_001&type=channel_code
GET http://localhost:8080/api/products/change-requests
```

Migration alias:

```text
GET http://localhost:8080/product-code/skus?search=LOCAL_TEST_PM
GET http://localhost:8080/product-code/skus/LOCAL_TEST_PM_1258-1
```

## Frontend 실행

```powershell
cd frontend/admin
Copy-Item .env.example .env
npm install
npm run dev
```

기본 URL:

```text
http://localhost:5173/products
```

기본 API base URL:

```text
VITE_API_BASE_URL=http://localhost:8080
```

## 화면 확인

- `/products`: SKU 목록
- `/products/:skuId`: SKU 상세, alias panel, channel mapping
- `/products/aliases`: code system/value 검색
- `/products/change-requests`: disabled placeholder

## 기대 결과

- SKU 목록에서 `LOCAL_TEST_PM` SKU 2건 조회
- SKU 상세에서 alias와 channel mapping 표시
- alias 검색에서 selfpia_sku, own_sku, smartstore_option_no 조회
- ambiguous own_sku 조회 시 2개 후보 반환
- change request 화면은 read-only placeholder

## API Route Mount 확인 결과

2026-05-13 확인:

- startup log에 `Mounted routes: /health, /api/products, /product-code, /picking, /mapping` 출력 확인
- `GET /health` 성공
- `GET /product-code/skus?search=LOCAL_TEST_PM` 성공
- `GET /api/products/skus?search=LOCAL_TEST_PM` 성공
- `GET /api/products/skus/by-code/selfpia_sku/LOCAL_TEST_PM_1258-1` 성공

참고:

- `node --watch src/server.js`는 import된 repository 파일 변경을 즉시 재시작하지 않을 수 있다.
- API 코드 변경 후에는 Docker API 컨테이너 재시작을 권장한다.

## 아직 하지 않은 것

- 운영 DB 적용
- NAS 적용
- master write API
- change request POST/approval/apply
- 인증/JWT/권한
- 실제 운영 데이터 전체 적재

## Frontend 코드/빌드 Smoke Test 결과

2026-05-15 확인 (격리된 Linux 샌드박스 기준, 사용자 Windows Docker/브라우저 미접근).

격리 샌드박스에서 `frontend/admin`을 `/tmp/feadmin`으로 복제 후 검증한 결과:

- `npm install` 성공 (vite 6.4.2, react 19.2.6, react-dom 19.2.6, react-router-dom 7.15.1, @vitejs/plugin-react 4.7.0 설치)
- `npx vite build` 성공 (43 modules transformed, `dist/assets/index-*.js` 241.73 kB)
- `npx vite --port 5174` dev server 기동 성공 (`VITE v6.4.2 ready`)
- `GET /` HTTP 200, `index.html` 서빙 확인
- `GET /src/main.jsx?import` HTTP 200, JSX → JS 변환 확인
- `GET /src/App.jsx?import` HTTP 200
- `GET /src/pages/products/ProductListPage.jsx?import` HTTP 200 (`useEffect`, `useState` import + JSX 변환 확인)

판단:

- 의존성 구성, JSX 변환 경로, route 진입 코드(`App.jsx`)는 정상이다.
- `vite.config.js`가 없는 상태에서 Vite 6 기본 esbuild는 `.jsx`를 classic JSX transform(`React.createElement`)으로 변환한다. 빌드/서빙 자체는 동작하지만 런타임에 각 JSX 파일에서 `React`가 scope에 있어야 한다. 추가로 `@vitejs/plugin-react`가 미등록이라 React Refresh(HMR)는 비활성.

## 2026-05-15 브라우저 런타임 이슈 및 수정

증상:

- 사용자 Windows 호스트에서 `npm run dev` 실행 후 `http://localhost:5173/products` 접속 시 빈 화면.
- DevTools Console: `Uncaught ReferenceError: React is not defined at App.jsx:10`.

원인:

- Vite 6 기본 esbuild의 classic JSX transform이 `<Layout>` 등 JSX를 `React.createElement(...)`로 컴파일하지만, `App.jsx`를 비롯한 JSX 파일에 `import React from 'react'`가 누락되어 런타임에 `React`가 ReferenceError.
- `main.jsx`만 `React.StrictMode`를 직접 사용해 React를 import했고, 나머지 파일은 named import만 했음.

수정 (코드만, DB/API 변경 없음):

| 파일 | 변경 |
|---|---|
| `frontend/admin/src/App.jsx` | 상단에 `import React from 'react';` 추가 |
| `frontend/admin/src/components/Layout.jsx` | 상단에 `import React from 'react';` 추가 |
| `frontend/admin/src/components/StatusBadge.jsx` | 상단에 `import React from 'react';` 추가 |
| `frontend/admin/src/pages/products/ProductListPage.jsx` | `import { useEffect, useState } from 'react'` → `import React, { useEffect, useState } from 'react'` |
| `frontend/admin/src/pages/products/ProductDetailPage.jsx` | `import { useEffect, useState } from 'react'` → `import React, { useEffect, useState } from 'react'` |
| `frontend/admin/src/pages/products/AliasSearchPage.jsx` | `import { useState } from 'react'` → `import React, { useState } from 'react'` |
| `frontend/admin/src/pages/products/ChangeRequestsPlaceholderPage.jsx` | `import { useEffect, useState } from 'react'` → `import React, { useEffect, useState } from 'react'` |

검증 절차:

```powershell
cd frontend\admin
npm.cmd run dev
# 브라우저: http://localhost:5173/products 새로고침
# DevTools Console: ReferenceError 사라짐 확인
# Network: /api/products/skus?search=LOCAL_TEST&limit=50 200 OK 확인
```

대안 (follow-up, 본 v1에서는 미적용):

- `frontend/admin/vite.config.js`를 추가하고 `@vitejs/plugin-react`를 등록하면 자동 JSX runtime(`react/jsx-runtime`)이 활성화되어 각 파일의 `import React from 'react'` 자체가 불필요해진다. React Refresh(HMR)도 활성화된다.
- 예시:

```js
// frontend/admin/vite.config.js
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()]
});
```

- 본 변경은 의존성/빌드 거동을 바꾸므로 v1 검증 완료 후 별도 작업으로 진행 권장.

## Windows 호스트 실측 검증 결과 (2026-05-15 완료)

다음 항목은 사용자 Windows 호스트(`Asia/Seoul`)에서 실제로 실행/확인되었다.

실행 환경:

| 항목 | 값 |
|---|---|
| Docker Desktop | Running |
| Postgres container | `product_ops_test_postgres` Running / healthy |
| API container | `product_ops_api_local` Running |
| API port (host → container) | `8080` |
| Postgres port (host → container) | `5433 → 5432` |
| DB | `product_ops_test` |
| DB user | `product_ops_tester` |
| Frontend port | `5173` |
| Frontend API base URL | `http://localhost:8080` |
| Timezone | Asia/Seoul |

Compose 실행:

```powershell
docker compose -f docker-compose.local-test.yml -f docker-compose.api-local.yml up -d
```

API container startup log 확인:

```text
Product Ops API listening on :8080
Mounted routes: /health, /api/products, /product-code, /picking, /mapping
```

API 응답 검증 (PowerShell 실측, `curl.exe` 사용):

| Endpoint | 결과 |
|---|---|
| `GET /health` | 200, `product_ops_test` / `product_ops_tester` 식별 정보 노출 |
| `GET /api/products/skus?search=LOCAL_TEST_PM` | 200, LOCAL_TEST_PM seed 응답 |
| `GET /api/products/skus/by-code/selfpia_sku/LOCAL_TEST_PM_1258-1` | 200, 단일 SKU 응답 |
| `GET /api/products/skus/by-code/own_sku/LOCAL_TEST_PM_OWN_AMBIG` | 200, ambiguous 후보 2건 응답 |

Frontend 실측:

```powershell
cd frontend\admin
npm.cmd install
npm.cmd run dev
```

| 라우트 | 결과 |
|---|---|
| `http://localhost:5173/products` | SKU 목록 정상 렌더, LOCAL_TEST / LOCAL_TEST_PM seed 표시 |
| `http://localhost:5173/products/:skuId` | SKU 상세, alias, channel mapping 패널 정상 |
| `http://localhost:5173/products/aliases` | code system 4종 selector + 기본 검색 정상 |
| `http://localhost:5173/products/change-requests` | placeholder 안내 + "새 요청" 버튼 disabled, write 기능 부재 확인 |

발생한 환경 이슈와 해결 (코드 문제 아님):

- PowerShell 실행 정책으로 `npm install`이 막힘 → `npm.cmd install`, `npm.cmd run dev` 사용으로 우회.
- PowerShell의 `curl`은 `Invoke-WebRequest` alias라 헤더/보안 경고 발생 → `curl.exe` 사용으로 표준 cURL 호출.
- 초기 빈 화면 + `React is not defined at App.jsx:10` 콘솔 에러 발생 → JSX 파일들에 `React` import 누락이 원인. 7개 JSX 파일에 import 추가하여 해결 (위 "2026-05-15 브라우저 런타임 이슈 및 수정" 섹션 참조).

DB / NAS / Schema 변경 여부:

- 운영 Supabase DB 변경: 없음
- Local Docker DB `product_ops_test` schema 변경: 없음
- NAS PostgreSQL 변경: 없음
- Seed 재적용: 없음 (기존 LOCAL_TEST / LOCAL_TEST_PM seed 유지)

v1 read-only 원칙 유지 확인:

- master 직접 수정 UI: 없음
- change request write UI: 없음 (placeholder + disabled 버튼만)
- 클라이언트 → DB 직접 접속: 없음 (모두 `/api/*` 경유)
- `/product-code/*` legacy 라우트: 유지

## PowerShell 운영 팁

이 프로젝트를 Windows + PowerShell 환경에서 다룰 때 반복되는 함정:

- `npm` 대신 `npm.cmd` 사용 (실행 정책 회피)
- `npx` 대신 `npx.cmd` 사용 (필요 시)
- `curl` 대신 `curl.exe` 사용 (표준 cURL 호출, `Invoke-WebRequest` 우회)
- 경로 구분자는 PowerShell에서는 `\` 사용 (`cd frontend\admin`)
- `.env` 복사는 `Copy-Item .env.example .env -Force`

## Frontend 화면-API 정합성 정적 검증

코드 정적 검증 결과 frontend와 backend의 응답 shape이 일치한다.

- `ProductListPage` → `GET /api/products/skus?search=...&limit=50` → `result.data[*]`의 `sku_id`, `selfpia_sku_code`, `product_name`, `option_value`, `virtual_sku_code`, `sku_status` 컬럼이 `v_sku_canonical`과 일치
- `ProductDetailPage` → `GET /api/products/skus/:skuId` → `result.data`의 `aliases[]`, `channel_mappings[]` 키가 `service.js#getSkuDetail` 반환과 일치
- `AliasSearchPage` → `GET /api/products/skus/by-code/:codeSystem/:codeValue` → `result.data[*]`의 `matched_code_system`, `matched_code_value` 컬럼이 `repository.js#findSkusByCode`와 일치
- `ChangeRequestsPlaceholderPage` → `GET /api/products/change-requests` → `result.meta.message` 키가 `service.js#getChangeRequestPlaceholder`와 일치
- `ProductListPage`의 기본 검색어 `'LOCAL_TEST'`는 service layer에서 `'%LOCAL_TEST%'`로 wrap되어 `LOCAL_TEST_PM_*` seed를 모두 포함. 변경 불요.
- `AliasSearchPage`의 기본 codeValue `'LOCAL_TEST_PM_1258-1'`은 seed에 직접 존재. 변경 불요.

## 재현용 Windows 호스트 검증 절차

```powershell
# 1. compose 기동
docker compose -f docker-compose.local-test.yml -f docker-compose.api-local.yml up -d

# 2. 컨테이너 상태 / 로그
docker ps --filter "name=product_ops_"
docker logs product_ops_api_local --tail 20
# 기대: "Mounted routes: /health, /api/products, /product-code, /picking, /mapping"

# 3. API 응답 확인 (PowerShell에서는 curl.exe)
curl.exe http://localhost:8080/health
curl.exe "http://localhost:8080/api/products/skus?search=LOCAL_TEST_PM"
curl.exe "http://localhost:8080/api/products/skus/by-code/selfpia_sku/LOCAL_TEST_PM_1258-1"
curl.exe "http://localhost:8080/api/products/skus/by-code/own_sku/LOCAL_TEST_PM_OWN_AMBIG"
curl.exe "http://localhost:8080/api/products/change-requests"
curl.exe "http://localhost:8080/product-code/skus?search=LOCAL_TEST_PM"

# 4. Frontend (PowerShell에서는 npm.cmd)
cd frontend\admin
Copy-Item .env.example .env -Force
npm.cmd install
npm.cmd run dev

# 5. 브라우저
# http://localhost:5173/products
# http://localhost:5173/products/<sku_id>
# http://localhost:5173/products/aliases
# http://localhost:5173/products/change-requests
```

검증 후 확인할 항목:

- `/products`: 빈 결과면 (a) seed 미적재 또는 (b) API 미응답. `curl http://localhost:8080/api/products/skus?search=LOCAL_TEST_PM`로 분리 진단.
- `/products/:skuId`: SKU ID URL은 `/products` 목록에서 행 클릭으로만 진입 (UUID 직접 입력 금지).
- `/products/aliases`: `codeSystem=own_sku`, `codeValue=LOCAL_TEST_PM_OWN_AMBIG`로 변경 시 2건 후보 반환 확인.
- `/products/change-requests`: meta.message 텍스트가 표시되고 모든 버튼 disabled 유지.

본 섹션은 코드 정합성 / 빌드 / dev server 응답까지의 격리 샌드박스 검증 결과만 기록한다.

샌드박스(Linux 격리 환경)에서 frontend/admin 의 src + index.html + package.json 을 별도 디렉토리로 복제한 뒤 npm install / vite build / vite dev 를 차례로 실행했다. 사용자 Windows 호스트의 실제 브라우저 검증은 별도로 진행한다.

- `npm install` 성공 (vite 6.4.2 외 기존 deps)
- `vite build` 성공: bundle `index-CPcET2fT.js` 252,025 byte / css `index-C6hanVm3.css` 6,380 byte
- `vite dev --port 5175` 기동 후 아래 URL 모두 HTTP 200 응답
  - `/`
  - `/src/main.jsx`
  - `/src/App.jsx`
  - `/src/components/Layout.jsx`
  - `/src/components/StatusBadge.jsx`
  - `/src/components/CopyButton.jsx`
  - `/src/styles.css`
  - `/src/pages/products/ProductListPage.jsx`
  - `/src/pages/products/ProductDetailPage.jsx`
  - `/src/pages/products/AliasSearchPage.jsx`
  - `/src/pages/products/ChangeRequestsPlaceholderPage.jsx`

샌드박스에서 검증하지 못한 항목 (사용자 Windows 호스트에서 수행):

- 실제 브라우저(Chromium 계열)에서의 라우트 4개 렌더링
- 사용자 Windows 호스트의 `http://localhost:8080` API 컨테이너로부터 실제 SKU 2건 / alias 표시 / ambiguous own_sku 2건 / change request placeholder 메시지 렌더링
- 새로 추가된 `CopyButton` 동작 (navigator.clipboard 권한 / fallback execCommand)
- read-only 상단 배너 노출 (모든 페이지 상단)


## v1 UI Polish (2026-05-15)

상품관리 v1 read-only 원칙을 유지하면서 화면 가독성과 read-only 명확성을 개선한다. 운영 DB / NAS / schema / master / change request write 는 변경하지 않는다. `/api/products/*` 와 `/product-code/*` 라우트 표면도 변경하지 않는다.

### 코드 변경 파일

- `frontend/admin/src/components/CopyButton.jsx` (신규) — navigator.clipboard 기반 한 글자 복사 버튼. 폴백으로 hidden textarea + execCommand. 빈 값 자동 disabled.
- `frontend/admin/src/components/StatusBadge.jsx` — 기존 `StatusBadge` 유지 + `CodeSystemBadge` 신규 export. 채널/코드시스템별 색상 분리 (selfpia / own / smartstore / makeshop / ably / playauto).
- `frontend/admin/src/components/Layout.jsx` — 사이드바 brand 부제 "v1 read-only", 사이드바 하단 read-only 안내, 메인 영역 상단에 노란색 READ-ONLY env-banner.
- `frontend/admin/src/pages/products/ProductListPage.jsx` — 기본 검색어 `LOCAL_TEST_PM`, 예시 chip, ellipsis + CopyButton, ellipsis-2 (2줄 clamp), empty 메시지 보강, hint 추가.
- `frontend/admin/src/pages/products/ProductDetailPage.jsx` — loading 상태 분리, header CopyButton, read-only banner, dl 각 코드값 CopyButton, alias/mapping 패널 헤더 건수, CodeSystemBadge, Primary pill.
- `frontend/admin/src/pages/products/AliasSearchPage.jsx` — code system select 한글 label, 시스템별 예시 chip 4개, 결과 1건 초과 시 "복수 후보 N건" warn notice, 1건이면 ok notice, empty 시 3가지 원인 안내.
- `frontend/admin/src/pages/products/ChangeRequestsPlaceholderPage.jsx` — readonly-banner-strong, 새 요청 버튼 disabled+aria-disabled, v1 상태 패널, v1 범위 밖 항목 패널.
- `frontend/admin/src/styles.css` — env-banner, readonly-banner, chip, examples, sticky/zebra table, ellipsis, cell-code, copy-button, code-system-* badge variants, pill, hint, muted, panel-header, bullet-list, empty-hints, 1100px / 900px 반응형.

### 변경하지 않은 파일

- `frontend/admin/src/App.jsx` (router 구성 동일)
- `frontend/admin/src/main.jsx`
- `frontend/admin/src/api/client.js`
- `server/`
- DB / schema / seed / API route 정의

### read-only 원칙 재확인

- master 직접 수정 UI 부재
- change request write UI 부재 (버튼 disabled)
- DB 직접 접속 없음 (api client 는 `/api/products/*` 만 호출)
- 레거시 `/product-code/*` 라우트 제거하지 않음

### 샌드박스 검증 결과 (2026-05-15)

- esbuild bundle dry-run: 0 errors / 0 warnings
- `vite build`: bundle `index-CPcET2fT.js` 252,025 byte / css `index-C6hanVm3.css` 6,380 byte
- `vite dev --port 5175` 기동 후 11 URL 모두 HTTP 200 (`/`, `/src/main.jsx`, `/src/App.jsx`, `/src/styles.css`, 컴포넌트 3개, 페이지 4개)

### 본 turn 에서 하지 않은 것

- 운영 Supabase DB 변경
- NAS PostgreSQL 적용
- 로컬 DB schema 변경 / seed 재적용
- master / code_alias / channel mapping write
- `/product-code/*` 라우트 제거
- GitHub push / git add
- 메이크샵·에이블리 코드매칭 (다른 세션 진행)

## v1 UI Polish round 2 — card layout + image slot placeholder (2026-05-15)

상품관리 v1 frontend/admin 화면을 스마트스토어 preview 느낌의 카드/리스트형 UI로 개선했다. 이번 라운드는 이미지 연결 전 단계이며 DB, API, schema, seed, NAS, 운영 Supabase는 변경하지 않았다.

### 변경 범위

- `ProductListPage`: 테이블 중심 SKU 목록을 96px 이미지 슬롯이 있는 카드형 리스트로 변경. 검색 toolbar, 예시 chip, loading/error/empty 상태는 유지.
- `ProductDetailPage`: 상단에 큰 이미지 placeholder와 상품명/옵션/코드 chip/status를 묶은 preview형 상세 헤더 추가. 기존 alias/channel mapping 패널은 유지.
- `AliasSearchPage`: 검색 결과를 작은 썸네일 placeholder가 붙은 리스트로 변경. ambiguous notice, code system badge, copy button 유지.
- 신규 컴포넌트: `EmptyImagePlaceholder`, `ProductThumbnail`, `ProductMetaChips`, `ProductCardRow`.
- `styles.css`: product card, thumbnail, placeholder, meta chip, hover shadow, responsive layout 스타일 추가.

### 이미지 처리

- 현재 API 응답에는 `image_url` / `thumbnail_url`이 없으므로 모든 상품은 placeholder로 표시된다.
- `ProductThumbnail`은 추후 `thumbnail_url` 또는 `image_url`이 들어오면 그대로 `img`로 렌더한다.
- `img` 로딩 실패 또는 404 발생 시 `EmptyImagePlaceholder`로 fallback한다.

### 검증

- `npm.cmd run build` 성공.
- Vite build 결과: 48 modules transformed, css `9.95 kB`, js `254.40 kB`.
- React Router dependency의 `"use client"` directive ignored 경고 2건은 기존 번들러 경고로 판단하며 빌드는 성공.

### 다음 단계: 실제 이미지 연결

- local DB에 `product_code.product_image` 또는 대응 이미지 source 적재 필요.
- API list/detail/by-code 응답에 `thumbnail_url` 또는 `image_url` 필드 추가 필요.
- DB schema patch와 운영/로컬 export-import 절차는 별도 승인 후 진행.

## v1 image connection step 2 preparation (2026-05-15)

실제 이미지 연결을 위한 상태 점검과 SQL 초안 작성까지만 진행했다. 현재 workspace에는 `product_image` export CSV가 없고, local DB에도 `product_code.product_image` 테이블이 없으므로 DB apply/import와 API join 변경은 보류했다.

### 현재 확인 결과

- local Docker containers: `product_ops_test_postgres`, `product_ops_api_local` running.
- local DB: `product_ops_test`.
- `to_regclass('product_code.product_image')`: null.
- image 관련 export/search 결과: `exports`, `outputs`, `sql`, `scripts`에서 기존 image/product_image/thumbnail 파일 없음.
- product master data:
  - `product_code.product_master`: 6,175 rows.
  - `product_code.sku_master`: 33,289 rows.
  - `product_code.code_alias`: 65,273 rows.
  - `product_code.v_sku_canonical`: 33,291 rows.
- frontend는 이미 `row.thumbnail_url || row.image_url`을 `ProductThumbnail`에 전달한다.
- API repository는 아직 `product_image`를 join하지 않는다. 기존 응답 필드만 유지된다.

### 작성한 SQL 초안

- `sql/export_product_code_product_image_select_only.sql`: 운영 source에서 image rows를 SELECT-only CSV로 내보내기 위한 초안.
- `sql/schema_local_patch_product_image.sql`: local-only `product_code.product_image` DDL 초안. 아직 미적용.
- `sql/precheck_product_image_import.sql`: local DB readiness/read-only check.
- `sql/stage_product_image_import.sql`: CSV를 TEMP table로 올리는 stage 초안. persistent write 없음.
- `sql/dryrun_product_image_import.sql`: CSV row 분류 dryrun. `BEGIN ... ROLLBACK`, persistent write 없음.
- `sql/postcheck_product_image_import.sql`: 향후 apply 후 image coverage 확인. table 미존재 상태에서도 0건으로 안전 통과.

### 검증 결과

실행한 것:

```powershell
docker exec product_ops_test_postgres psql -U product_ops_tester -d product_ops_test -v ON_ERROR_STOP=1 -P pager=off -f /tmp/precheck_product_image_import.sql
docker exec product_ops_test_postgres psql -U product_ops_tester -d product_ops_test -v ON_ERROR_STOP=1 -P pager=off -f /tmp/postcheck_product_image_import.sql
```

결과:

- `precheck_product_image_import.sql`: 성공. `product_image_table`은 null, 기존 master/view row count 정상.
- `postcheck_product_image_import.sql`: 성공. table 미존재 notice 후 image rows 0건, `1258-1`, `11258-1`, `LOCAL_TEST_PM_1258-1` 모두 image URL null 확인.

실행하지 않은 것:

- `schema_local_patch_product_image.sql`: DDL 미적용.
- `stage_product_image_import.sql`: export CSV 없음으로 미실행.
- `dryrun_product_image_import.sql`: export CSV 없음으로 미실행.
- API repository join 변경: 보류.
- frontend 코드 변경: 보류.

### 다음 승인 필요 항목

1. 운영 Supabase `product_image` 구조 확인 및 SELECT-only export 실행 승인.
2. export CSV 확보 후 `schema_local_patch_product_image.sql` local-only 적용 승인.
3. stage/dryrun/postcheck 결과 검토 후 apply SQL 작성 여부 승인.
4. local DB에 image table/data가 준비된 뒤 API `thumbnail_url` / `image_url` join 변경 승인.

## v1 image CSV coverage and dryrun (2026-05-15)

`exports/selfpia_image_url.csv`가 확보되어 local Docker PostgreSQL 기준으로 TEMP coverage 진단과 dryrun insert simulation을 진행했다. persistent DB apply는 하지 않았다.

### CSV source

- File: `exports/selfpia_image_url.csv`
- Original file name: `셀피아코드-이미지url-자사코드.csv`
- Columns: `p_code`, `image_url`, `updated_at`, `own_code`
- Key policy: `p_code`를 `product_code.code_alias(code_system='selfpia_sku', code_value=p_code)`에 연결한다. `own_code`는 blank/duplicate가 많아 primary key로 쓰지 않는다.

### Coverage result

- CSV rows: 32,094
- distinct `p_code`: 32,094
- duplicated `p_code`: 0
- blank `image_url`: 12,762
- blank `own_code`: 5,080
- matched distinct `p_code`: 32,062
- unmatched distinct `p_code`: 32
- rows with image and matched SKU: 19,331
- rows with image but unmatched SKU: 1
- blank image but matched SKU: 12,731
- SKUs with image rows: 19,331
- SKUs with multiple image rows: 0
- image URLs reused by multiple SKUs: 0

### SQL files

- `sql/precheck_product_image_csv_coverage.sql`: TEMP table + `\copy` coverage check.
- `sql/schema_local_patch_product_image.sql`: local-only table DDL draft. Not applied.
- `sql/stage_product_image_import.sql`: TEMP stage check.
- `sql/dryrun_product_image_import.sql`: TEMP target insert simulation with `BEGIN ... ROLLBACK`.
- `sql/postcheck_product_image_import.sql`: post-apply read-only check. Safe before apply.

### Dryrun result

- CSV rows: 32,094
- rows with image URL: 19,332
- blank image URL rows: 12,762
- ready insert rows: 19,331
- image orphan rows: 1
- simulated insert rows: 19,331
- duplicate primary image SKUs: 0
- reused image URL count: 0
- requested sample:
  - `1000-1`: image URL present.
  - `1258-1`: image URL present.
  - `11258-1`: no image URL in CSV.
  - `LOCAL_TEST_PM_1258-1`: no image URL in CSV.
- no=99 `OVERALL`: `REVIEW` because `image_orphan_rows = 1`.
- unmatched image sample: `8276-2`.

### Current decision

Do not apply yet. The dryrun is structurally good, but one image row has no matching `selfpia_sku` alias. User decision is needed:

1. Skip unmatched image rows during apply, keeping `8276-2` out of `product_image`.
2. Backfill/fix the missing master alias separately, then rerun coverage/dryrun.

API image join should wait until local `product_code.product_image` is actually applied and populated.

### User decision: skip 8276-2 and proceed to local apply file

User approved treating `8276-2` as an expected skipped orphan image row. SQL was updated accordingly:

- `sql/dryrun_product_image_import.sql` now reports no=70 `EXPECTED_SKIP_POLICY` and no=99 `OVERALL = PASS` when the only image orphan is `8276-2`.
- `sql/apply_product_image_import.sql` was created as a user-executed local-only apply file. It inserts only matched rows and excludes orphan image rows.
- `sql/postcheck_product_image_import.sql` now checks expected row count, skipped orphan source row, duplicate primary images, and sample image/null behavior.

Re-run dryrun result:

- ready insert rows: 19,331
- image orphan rows: 1
- skipped orphan image rows: 1 (`8276-2`)
- duplicate primary image SKUs: 0
- no=99 `OVERALL`: `PASS`

Apply is not executed yet. To apply locally, run in this order after copying CSV/SQL into the PostgreSQL container:

```powershell
docker cp .\exports\selfpia_image_url.csv product_ops_test_postgres:/tmp/selfpia_image_url.csv
docker cp .\sql\schema_local_patch_product_image.sql product_ops_test_postgres:/tmp/schema_local_patch_product_image.sql
docker cp .\sql\apply_product_image_import.sql product_ops_test_postgres:/tmp/apply_product_image_import.sql
docker cp .\sql\postcheck_product_image_import.sql product_ops_test_postgres:/tmp/postcheck_product_image_import.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/schema_local_patch_product_image.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/apply_product_image_import.sql

docker exec product_ops_test_postgres `
  psql -U product_ops_tester -d product_ops_test `
  -v ON_ERROR_STOP=1 `
  --echo-errors `
  -f /tmp/postcheck_product_image_import.sql
```

API repository image join should be implemented only after this local apply/postcheck succeeds.

## v1 image API join (2026-05-15)

Local DB `product_code.product_image` apply/postcheck 성공 후 `/api/products/*` read-only 응답에 image URL 필드를 추가했다. DB/schema/data 변경은 이 단계에서 하지 않았다.

### Local image apply result

- `product_code.product_image`: created.
- image rows: 19,331.
- primary rows: 19,331.
- duplicate primary image SKUs: 0.
- skipped orphan image rows: 1.
- skipped p_code: `8276-2`.
- postcheck overall: PASS.

### API change

Changed file:

- `server/src/modules/product-management/repository.js`

Added fields:

- `thumbnail_url`
- `image_url`

Affected repository functions:

- `listSkus`
- `getSkuById`
- `findSkusByCode`
- `searchProducts`

Join strategy:

```sql
LEFT JOIN LATERAL (
  SELECT
    pi.thumbnail_url,
    pi.image_url
  FROM product_code.product_image pi
  WHERE pi.sku_id = v.sku_id
  ORDER BY pi.is_primary DESC, pi.sort_order ASC, pi.id ASC
  LIMIT 1
) img ON true
```

`findSkusByCode` uses the same lateral lookup with `pi.sku_id = sm.id`. This preserves one API row per SKU/result and returns null image fields when no image exists.

### Verification

API container was restarted to load repository changes:

```powershell
docker restart product_ops_api_local
```

Verified:

- `GET /api/products/skus?search=1258-1&limit=5`
  - `1258-1`: `thumbnail_url` / `image_url` present.
  - `11258-1`: image fields null.
- `GET /api/products/skus?search=1000-1&limit=5`
  - `1000-1`: `thumbnail_url` / `image_url` present.
- `GET /api/products/skus?search=11258-1&limit=5`
  - image fields null.
- `GET /api/products/skus/by-code/selfpia_sku/1258-1`
  - image fields present.
- `GET /api/products/search?q=1258-1&type=all&limit=5`
  - image fields included in search results.
- `GET /product-code/skus/1258-1`
  - migration alias still works and includes image fields.
- `npm.cmd run build`
  - frontend build succeeded. React Router dependency `"use client"` warnings remain non-blocking.

Frontend browser check:

- `/products`, search `1258-1`: 4 cards, 1 image tag, 3 placeholders.
- `/products`, search `1000-1`: 1 card, 1 image tag, 0 placeholders.
- `/products`, search `11258-1`: 1 card, 0 image tags, 1 placeholder.

Remaining note: in headless Chrome the remote Googleusercontent image did not complete pixel loading during the short check, but the API-provided URL was rendered into the `<img src>` and placeholder fallback behavior remained correct for null images.
## Admin UI refresh - clean card layout (2026-05-15)

상품관리 v1 admin UI를 read-only 원칙 안에서 "여백, 카드, 정보 위계가 정돈된 관리자 UI" 방향으로 개편했다. 토스 UI를 복제하지 않고, 밝은 회색 배경, 흰 카드, 절제된 파란 강조색, 약한 그림자, 명확한 typography hierarchy 중심으로 정리했다.

변경 범위:

- `frontend/admin/src/styles.css`: layout, sidebar, page header, section card, form, button, chip, badge, thumbnail, list card, detail hero, responsive 스타일 재정리.
- `frontend/admin/src/components/Layout.jsx`: 사이드바 문구와 read-only banner 정리.
- `frontend/admin/src/components/ProductCardRow.jsx`: SKU 목록 카드에 thumbnail, 상품명, 옵션, 상태, 주요 코드 chip, 상세 이동 affordance를 한눈에 보이도록 재배치.
- `frontend/admin/src/components/ProductThumbnail.jsx`: 기존 image/fallback 로직 유지.
- `frontend/admin/src/components/ProductMetaChips.jsx`: 코드 chip label/copy 문구 정리.
- `frontend/admin/src/components/CopyButton.jsx`: 깨진 한글 문구를 복구하고 기존 복사 로직 유지.
- `frontend/admin/src/components/EmptyImagePlaceholder.jsx`: 더 차분한 no image placeholder로 정리.
- `frontend/admin/src/pages/products/ProductListPage.jsx`: 검색 카드, 예시 chip, 안내 문구, empty/loading/error 문구 정리.
- `frontend/admin/src/pages/products/ProductDetailPage.jsx`: hero card와 하단 alias/channel mapping panel 문구 및 정보 위계 정리.
- `frontend/admin/src/pages/products/AliasSearchPage.jsx`: alias 검색 조건 카드와 결과 리스트 카드 위계 정리.
- `frontend/admin/src/pages/products/ChangeRequestsPlaceholderPage.jsx`: read-only placeholder 문구와 disabled 상태 정리.

변경하지 않은 것:

- API endpoint 변경 없음.
- `/api/products/*`, `/product-code/*` 제거 없음.
- DB schema/data 변경 없음.
- master write / change request write 기능 추가 없음.
- 운영 Supabase / NAS 변경 없음.

검증 권장:

```powershell
cd frontend\admin
npm.cmd run build
npm.cmd run dev
```

브라우저 확인:

- `http://localhost:5173/products`
- `http://localhost:5173/products/aliases`
- `http://localhost:5173/products/change-requests`

검색어:

- `1258-1`
- `1000-1`
- `11258-1`
- `피어싱`
- `LOCAL_TEST_PM`

이번 검증 결과:

- `npm.cmd run build`: 성공. React Router dependency의 `"use client"` ignore 경고 2건은 기존 non-blocking 경고.
- `http://localhost:5173/products`: 렌더 확인.
- SKU 목록 검색:
  - `1258-1`: card 4건.
  - `1000-1`: card 1건.
  - `11258-1`: card 1건.
  - `피어싱`: card 50건.
  - `LOCAL_TEST_PM`: card 2건.
- `http://localhost:5173/products/aliases`: header/search/example/render 확인.
- `http://localhost:5173/products/change-requests`: placeholder와 disabled 새 요청 버튼 확인.
- SKU 상세 직접 확인: `SKU 상세`, hero card, SKU 정보, Alias, Channel Mapping panel 렌더 확인.

## Product detail seller code summary (2026-05-15)

상품 상세 화면에서 사용자가 판매처별 코드 연결 상태를 먼저 볼 수 있도록 `판매처별 코드 요약` 섹션을 추가했다. 기존 raw alias / channel mapping 표는 삭제하지 않고 하단 보조 정보 카드로 유지했다.

구성 방식:

- Sellpia row
  - 상품코드: `selfpia_product_code`
  - 옵션코드 또는 SKU 코드: `selfpia_sku_code`
  - 자사코드: `own_sku` alias 첫 번째 값
  - 상태: `기준`
- MakeShop row
  - `sku_channel_mapping.channel_code = 'makeshop'` row 기준
  - 상품코드: `seller_product_code`
  - 옵션코드 또는 SKU 코드: `channel_sku_code`
  - 자사코드: `own_sku_code`
  - 상태: `연결됨`
- Smartstore row
  - `smartstore_option_no` alias 또는 `channel_code = 'smartstore'` mapping이 있으면 해당 코드 표시
  - 없으면 옵션코드/SKU 코드 `없음`, 상태 `미매핑`
- 기타 channel row
  - MakeShop/Smartstore 외 `channel_code`가 있으면 channel label 기준으로 추가 row 표시

유지 원칙:

- `sku_id` UUID는 `판매처별 코드 요약`에 노출하지 않는다.
- UUID는 하단 `SKU 정보`의 `내부 ID`로만 작게 표시한다.
- API endpoint / DB schema / local DB data 변경 없음.
- raw alias / raw channel mapping은 보조 정보로 유지.

검증:

- `/products/d4c0a5bf-73f1-4203-a6f8-9a27a44f58da` (`1000-3`, image): Sellpia / MakeShop / Smartstore 미매핑 / raw tables 확인.
- `/products/8d76dbe6-31cc-4682-bf34-190d27eaf37a` (`1258-1`, image): Sellpia / MakeShop / Smartstore 미매핑 / raw tables 확인.
- `/products/8f4b3764-0c40-4836-bb60-89e44679b710` (`11258-1`, no image): placeholder + Sellpia / MakeShop / Smartstore 미매핑 / raw tables 확인.
- `npm.cmd run build`: 성공. React Router dependency `"use client"` ignore 경고 2건은 기존 non-blocking 경고.
