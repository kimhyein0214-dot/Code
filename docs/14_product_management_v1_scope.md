# Product Management Module v1 Scope

## 목표

상품관리 모듈 v1은 첫 구현 대상이다. v1은 read-only 중심으로 시작하며, `product_code` master를 직접 수정하지 않는다.

구현 기준 환경:

- 로컬 Docker PostgreSQL: `product_ops_test`
- 로컬 Docker API server
- PC 관리자 화면

적용 금지:

- 운영 Supabase 적용 금지
- NAS PostgreSQL 적용 금지
- master 직접 수정 금지
- 운영 데이터 전체 적재 금지

## v1에서 만들 기능

### SKU 목록

- SKU 목록 조회
- selfpia sku code 표시
- 상품명/옵션명 표시
- 대표 alias 요약 표시
- master match 관련 상태 링크 제공
- pagination 또는 limit 기반 목록

### SKU 상세

- SKU 기본 정보 조회
- 연결된 product master 정보 조회
- alias 목록 panel 표시
- channel mapping 요약 표시
- audit/change request placeholder 표시

### Alias 목록

- SKU별 alias 목록 조회
- `code_system`별 필터
- `selfpia_sku`, `selfpia_product`, `own_sku`, channel code 구분
- primary 여부, 활성 여부 표시

### 상품/SKU 검색

- 상품명 검색
- SKU ID 검색
- selfpia sku code 검색
- own_sku 검색
- channel code 검색
- code system + code value 기반 정확 조회

### 미매칭/모호 매칭 링크

- unmatched order item으로 이동하는 링크
- ambiguous own_sku 후보로 이동하는 링크
- 상품관리 모듈에서는 해결 처리를 직접 수행하지 않는다.
- 해결이 필요한 경우 change request draft placeholder로 연결한다.

### Change Request Placeholder

- `change request` 버튼은 v1에서 disabled 또는 draft placeholder로 둔다.
- 실제 master 변경 API는 만들지 않는다.
- 버튼 클릭 시 “change request workflow 예정” 안내 또는 draft 화면 mock만 제공한다.

## v1에서 만들지 않을 기능

- `product_code` master 직접 수정
- SKU 생성/수정/삭제
- alias 생성/수정/삭제
- channel mapping 수정
- SKU merge
- bulk import/export
- 이미지 관리
- bundle editor
- approval workflow 전체 구현
- master writer 구현
- 운영 Supabase/NAS 반영
- 실제 외부 채널 동기화

## 사용 화면

| 화면 | Route | 목적 |
|---|---|---|
| SKU 목록 | `/products` | 상품/SKU 검색과 목록 조회 |
| SKU 상세 | `/products/:skuId` | SKU 단건 상세 조회 |
| Alias panel | `/products/:skuId` 내부 panel | 해당 SKU의 alias 조회 |
| Alias 목록 | `/products/aliases` | alias 중심 검색 |
| Change request placeholder | `/products/change-requests` | 향후 workflow 진입점 |

PC 관리자 화면만 대상으로 한다.

## API 목록

v1 최종 namespace는 `/api/products/*`를 제안한다.

| Method | Endpoint | 설명 | 쓰기 여부 |
|---|---|---|---|
| `GET` | `/api/products/skus` | SKU 목록 조회 | read-only |
| `GET` | `/api/products/skus/:skuId` | SKU 상세 조회 | read-only |
| `GET` | `/api/products/skus/by-code/:codeSystem/:codeValue` | code alias 기반 SKU 조회 | read-only |
| `GET` | `/api/products/skus/:skuId/aliases` | SKU별 alias 조회 | read-only |
| `GET` | `/api/products/search` | 통합 검색 | read-only |
| `GET` | `/api/products/change-requests` | change request placeholder 목록 | read-only 또는 mock |

### Query Parameter 초안

`GET /api/products/skus`

- `search`
- `code_system`
- `code_value`
- `limit`
- `offset`

`GET /api/products/search`

- `q`
- `type`: `sku`, `product`, `alias`, `channel_code`, `own_sku`, `selfpia_sku`
- `limit`

`GET /api/products/change-requests`

- v1에서는 placeholder로 빈 목록 또는 sample draft만 반환한다.
- 실제 승인/반영 API는 v1 범위에서 제외한다.

## 기존 API와 Namespace 정리

현재 skeleton에는 다음 endpoint가 있다.

- `GET /product-code/skus`
- `GET /product-code/skus/:selfpiaSkuCode`

최종 운영 namespace는 `/api/products/*`를 권장한다.

이유:

- 모듈형 운영 플랫폼의 API namespace 규칙과 맞다.
- 화면 route `/products/*`와 API route `/api/products/*`가 자연스럽게 대응된다.
- `product-code`는 DB schema 이름에 가깝고, 운영 모듈 이름은 상품관리다.
- 이후 change request, alias, search API를 같은 namespace 아래에 둘 수 있다.

Migration alias 제안:

- 기존 `/product-code/skus` 계열은 바로 삭제하지 않는다.
- 로컬 검증과 기존 문서 호환을 위해 v1 기간에는 alias endpoint로 유지한다.
- 내부 구현은 `/api/products/*` service를 호출하도록 연결한다.
- v2 또는 API 안정화 후 deprecated 표시한다.

권장 매핑:

| 기존 endpoint | 신규 endpoint | 정책 |
|---|---|---|
| `/product-code/skus` | `/api/products/skus` | migration alias 유지 |
| `/product-code/skus/:selfpiaSkuCode` | `/api/products/skus/by-code/selfpia_sku/:selfpiaSkuCode` | migration alias 유지 |

## DB/View 의존성

읽는 데이터:

- `product_code.product_master`
- `product_code.sku_master`
- `product_code.code_alias`
- `product_code.channel_product`
- `product_code.channel_sku`
- `product_code.v_sku_canonical`
- `audit.domain_events` 후보
- `stg.unmatched_order_items` 링크용
- `stg.v_ambiguous_own_sku_candidates` 링크용

쓰는 데이터:

- v1에서는 없음
- change request placeholder가 실제화될 때만 `product_code.change_requests` 후보 또는 workflow table에 draft 생성

View 의존성:

- `product_code.v_sku_canonical`: SKU 목록/검색의 기본 view
- `stg.v_ambiguous_own_sku_candidates`: own_sku 모호 매칭 링크
- `picking.v_order_items_unmatched`: 미매칭 주문상품 링크

## Seed/Sample Data 필요 여부

필요하다.

현재 local seed는 API row 반환 검증용으로 최소 SKU 2건을 포함한다. 상품관리 v1 화면 검증에는 다음 sample이 더 있으면 좋다.

- selfpia_sku alias가 있는 matched SKU
- own_sku alias가 여러 개 연결된 SKU
- channel code alias가 있는 SKU
- product master와 연결된 SKU
- ambiguous own_sku 후보와 연결 가능한 sample
- unmatched order item으로부터 이동 가능한 sample

원칙:

- 모든 sample 값은 `LOCAL_TEST_` 또는 `TEST_` prefix 사용
- 로컬 Docker DB 전용
- 운영 Supabase/NAS 적용 금지

## Frontend 구조 초안

권장 위치:

```text
frontend/
  admin/
    products/
      pages/
        SkuListPage
        SkuDetailPage
        AliasListPage
        ChangeRequestPlaceholderPage
      components/
        ProductSearchBar
        SkuTable
        SkuSummaryHeader
        AliasPanel
        AliasTable
        ProductStatusBadge
        MasterMatchLink
        ChangeRequestButton
      api/
        productsClient
      hooks/
        useSkuList
        useSkuDetail
        useSkuAliases
```

화면 구성:

- SKU list page
- SKU detail page
- alias panel
- search/filter bar
- status badge
- 미매칭/모호 매칭 링크 영역
- disabled change request button

## Server 구조 초안

권장 위치:

```text
server/
  src/
    modules/
      product-management/
        routes.js
        service.js
        repository.js
        dto.js
```

v1 원칙:

- route는 request/response만 담당
- service는 검색 타입, alias 조회, placeholder 정책 담당
- repository는 SQL SELECT만 담당
- INSERT/UPDATE/DELETE 없음
- master write 없음

## 구현 전 결정 필요사항

### Frontend 선택

결정 필요:

- React/Vite로 시작할지
- 단순 HTML prototype으로 먼저 갈지

권장:

- 운영 플랫폼으로 갈 계획이면 React/Vite가 적합하다.
- 단, 첫 검증 속도를 우선하면 HTML prototype으로 API shape만 먼저 확인할 수 있다.

### Server Skeleton 리팩토링

결정 필요:

- 현재 `server/src/routes/*` skeleton을 유지할지
- 바로 `server/src/modules/product-management/*` 구조로 리팩토링할지

권장:

- 상품관리 v1부터 modules 구조로 시작한다.
- 기존 `/product-code/*`는 migration alias route로 얇게 남긴다.

### Local Seed 확장

결정 필요:

- 현재 seed만으로 화면 구현을 시작할지
- alias/channel/ambiguous sample을 더 넣고 시작할지

권장:

- 화면 검증을 위해 local seed를 소폭 확장한다.
- 단, 실제 운영 데이터 전체 적재는 하지 않는다.

### Change Request 범위

결정 필요:

- 버튼 disabled만 둘지
- draft placeholder 화면까지 만들지

권장:

- v1에서는 disabled button + placeholder route까지만 둔다.
- 실제 request 생성 API는 v1.1 이후로 넘긴다.

## 다음 단계로 넘길 기능

- change request draft 생성
- approval workflow
- master writer
- alias 추가/수정
- SKU 속성 수정
- channel mapping 수정
- bulk import/export
- SKU merge
- product image 관리
- bundle component 관리
- audit event 상세 drawer

## v1 완료 기준

- `/api/products/skus`가 local DB에서 SKU 목록을 반환한다.
- `/api/products/skus/:skuId`가 SKU 상세를 반환한다.
- `/api/products/skus/:skuId/aliases`가 alias 목록을 반환한다.
- `/api/products/skus/by-code/:codeSystem/:codeValue`가 selfpia_sku/own_sku/channel code 조회를 지원한다.
- `/api/products/search`가 통합 검색을 지원한다.
- PC 관리자 화면에서 SKU 목록, 상세, alias panel을 탐색할 수 있다.
- change request는 disabled 또는 placeholder로 표시된다.
- 운영 Supabase/NAS 변경이 없다.

## 구현 준비 반영 상태

- React + Vite frontend skeleton을 `frontend/admin/`에 둔다.
- Backend는 `server/src/modules/product-management/` 구조를 사용한다.
- 최종 API namespace는 `/api/products/*`다.
- 기존 `/product-code/*`는 v1 기간 migration alias로 유지한다.
- local seed 확장 SQL은 `sql/local_seed_product_management_v1.sql`이다.
- local validation SQL은 `sql/local_seed_product_management_v1_validation.sql`이다.
- 실행 절차는 `docs/product_management_v1_runbook.md`를 따른다.
