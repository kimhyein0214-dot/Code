# Product Management Module

## 책임

상품관리 모듈은 SKU master와 상품 기준 정보를 관리한다. Product_code 원본의 `sku_master`, `product_master`, `code_alias`를 기준으로 운영 플랫폼의 단일 상품 기준을 제공한다.

master 직접 수정은 금지하고 change request 기반으로 처리한다.

## 소유 화면

- `/products`
- `/products/:skuId`
- `/products/aliases`
- `/products/change-requests`
- `/products/bundles`

PC 관리자용 화면이다.

## 호출 API

- `GET /api/products`
- `GET /api/products/:skuId`
- `GET /api/products/:skuId/aliases`
- `POST /api/products/change-requests`
- `GET /api/products/change-requests`
- `POST /api/products/change-requests/:id/approve`

## 읽는 데이터

- `product_code.product_master`
- `product_code.sku_master`
- `product_code.code_alias`
- `product_code.v_sku_canonical`
- `product_code.sku_bundle_component`
- `audit.row_changes`

## 쓰는 데이터

- 직접 master 쓰기 금지
- `product_code.change_requests` 후보
- 승인 시 별도 master writer가 `product_code.*` 반영
- `audit.row_changes`

`product_code.change_requests`는 v2 schema에 아직 없음. 추가 설계 필요.

## 다른 모듈과 연결

- 주문/피킹은 `sku_id`와 `selfpia_sku_code`를 읽는다.
- 채널상품관리는 alias와 mapping을 확장한다.
- CS는 상품명/옵션/alias를 조회한다.

## 지금 만들 것

- SKU 목록/상세 read UI
- alias 조회
- change request 초안 구조
- master write 금지 정책

## 나중에 만들 것

- 승인 workflow
- 대량 import 검수
- 상품 이미지/카테고리 관리
- bundle editor

