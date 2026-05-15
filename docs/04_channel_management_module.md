# Channel Management Module

## 책임

채널상품관리 모듈은 스마트스토어, Ably, Makeshop, PlayAuto 등 외부 채널 상품 코드와 내부 SKU를 연결한다. `own_sku`와 채널별 상품/옵션 코드는 자동 확정하지 않고 후보/검수 흐름을 거친다.

## 소유 화면

- `/channels`
- `/channels/:channelCode/products`
- `/channels/:channelCode/mappings`
- `/channels/review`
- `/channels/imports`

PC 관리자용 화면이다.

## 호출 API

- `GET /api/channels`
- `GET /api/channels/:channelCode/products`
- `GET /api/channels/:channelCode/mappings`
- `POST /api/channels/:channelCode/mapping-candidates`
- `POST /api/channels/mapping-reviews/:id/approve`
- `POST /api/channels/imports`

## 읽는 데이터

- `product_code.sku_master`
- `product_code.code_alias`
- `product_code.sku_channel_mapping`
- `stg.own_sku_match_candidates`
- `stg.v_ambiguous_own_sku_candidates`
- `audit.row_changes`

## 쓰는 데이터

- mapping candidate
- mapping review decision
- 승인 후 `product_code.sku_channel_mapping`
- 필요 시 `code_alias` change request
- `audit.row_changes`

## 다른 모듈과 연결

- 주문/피킹은 채널 코드로 들어온 주문 라인을 SKU에 연결할 때 mapping을 참조한다.
- CS는 채널 주문/상품 문의를 내부 SKU로 찾는다.
- 연동/설정 모듈은 채널 import job을 실행한다.

## 지금 만들 것

- ambiguous own_sku 후보 조회
- mapping review queue
- channel mapping read API

## 나중에 만들 것

- 채널별 adapter
- 대량 mapping import/export
- 자동 추천 점수
- 채널 API sync

