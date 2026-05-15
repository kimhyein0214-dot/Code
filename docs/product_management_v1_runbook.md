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
