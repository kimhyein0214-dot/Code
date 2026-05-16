# Channel Export Field Mapping Matrix v1

작성일: 2026-05-16

## 1. 목적

이 문서는 실제 확인한 판매처별 업로드/수정 양식 구조를 기준으로 내부 표준 필드와 판매처별 컬럼을 연결한 필드 매핑표 초안이다.

앞선 `docs/price_inventory_export_design_v1.md`와 `docs/channel_export_field_mapping_plan_v1.md`는 가격/재고/export 기능의 구조와 방향을 정리했다. 이 문서는 그 다음 단계로, 셀피아 기준 데이터와 스마트스토어, 메이크샵, 에이블리, 플레이오토 양식의 실제 컬럼을 맞춰 본다.

이번 문서는 설계 초안이다. DB 변경, SQL 작성/실행, API/Frontend 수정, 실제 CSV/XLSX 생성 기능 구현은 하지 않는다.

## 2. 기준 원칙

- 내부 기준은 `internal_sku_id` 또는 VSKU/SKU다.
- 셀피아 `자사코드`와 셀피아 SKU 계열 코드는 내부 기준 코드 후보로 사용한다.
- 판매처 상품코드와 판매처 옵션코드는 확정된 `code_alias` 또는 `sku_channel_mapping` 값만 사용한다.
- 후보 코드, 자동 추정 코드, ambiguous 코드는 export에 직접 사용하지 않는다.
- 판매처별 가격과 판매처별 노출재고는 내부 기본 가격/실재고와 분리한다.
- 판매처 양식의 필드명, 필수 여부, 값 형식은 판매처별 template 버전과 함께 관리한다.
- 원본 xlsx/csv/xml 파일은 reference로만 읽고 수정하지 않는다.

## 3. 내부 표준 필드 정의

| 내부 표준 필드 | 의미 | 내부 출처 후보 | 비고 |
|---|---|---|---|
| `internal_sku_id` / `VSKU` | 내부 SKU 식별자 또는 virtual SKU | `sku_master.id`, `sku_master.virtual_sku_code` | export 처리의 기준 key |
| `selfpia_sku_code` | 셀피아 SKU 또는 셀피아 기준 옵션 코드 | `code_alias`, canonical SKU view | 사람이 검수하는 기준 코드 |
| `own_sku_code` | 자사코드 | `code_alias(code_system='own_sku')`, 셀피아 `자사코드` | 채널 코드 연결의 핵심 후보 |
| `product_name` | 상품명 | `product_master.product_name`, 셀피아 `상품명` | 판매처별 글자수/금지어 확인 필요 |
| `option_name` | 옵션명 | `sku_master.option_value`, 셀피아 `옵션명` | 옵션 조합/줄바꿈/구분자 변환 필요 |
| `channel_product_code` | 판매처 상품코드 | `sku_channel_mapping.seller_product_code`, channel alias | 확정 코드만 사용 |
| `channel_option_code` | 판매처 옵션코드 | `sku_channel_mapping.channel_sku_code`, channel alias | 확정 코드만 사용 |
| `cost_price` | 매입가 | `sku_price.purchase_price`, 셀피아 `매입가` | 판매처에 직접 노출하지 않는 내부 기준 |
| `base_sale_price` | 내부 기본 판매가 | `sku_price.base_sale_price`, 셀피아 `판매가` | 채널 판매가 fallback 후보 |
| `channel_sale_price` | 판매처별 판매가 | `sku_channel_price.sale_price` | 판매처 업로드 가격 우선값 |
| `option_extra_price` | 옵션 추가/차감가 | `sku_price.option_price`, `sku_channel_price.option_price` | 판매처별 해석 다름 |
| `stock_qty` | 실제 재고 | `sku_inventory.stock_qty`, 셀피아 `재고` | 내부 실재고 |
| `available_qty` | 가용 재고 | `sku_inventory.available_qty`, 셀피아 `가용재고`, `통합가용재고` | 노출재고 산출 기준 |
| `safety_stock_qty` | 안전재고 | `sku_inventory.safety_stock_qty`, 셀피아 `안전재고` | 과판매 방지 기준 |
| `soldout_status` | 품절 여부 | `sku_inventory`, `sku_channel_inventory`, 셀피아 `품절` | 판매처 상태값으로 변환 |
| `display_status` | 진열/노출/판매 상태 | `sku_channel_inventory`, channel status 후보 | 판매처별 값 체계 다름 |
| `representative_image` | 대표 이미지 | `product_image.image_url`, 셀피아 이미지 URL 후보 | 판매처별 URL/파일 방식 확인 |
| `additional_images` | 추가 이미지 | `product_image`, channel image 후보 | 여러 URL 구분자 확인 필요 |
| `delivery_type` | 배송 유형 | channel policy 후보 | 판매처별 template 또는 기본값 필요 |
| `courier_code` | 택배사 코드 | channel policy 후보 | 스마트스토어 예: `EPOST` |
| `return_shipping_fee` | 반품 배송비 | channel policy 후보 | 에이블리/스마트스토어 등 채널별 필요 |
| `remote_area_fee` | 도서산간 추가배송비 | channel policy 후보 | 채널별 필드명 다름 |

## 4. 판매처별 필드 매핑표

아래 표는 실제 확인한 양식 구조를 기준으로 한 1차 매핑이다. 빈 값은 해당 양식에서 직접 확인된 컬럼이 없거나 별도 정책/후속 양식 확인이 필요한 항목이다.

| 내부 표준 필드 | 셀피아 `셀피아 NEW ALL.xlsx` | 스마트스토어 `일괄수정` | 메이크샵 `Sheet1` | 에이블리 CSV | 플레이오토 `쇼핑몰상품` |
|---|---|---|---|---|---|
| `internal_sku_id` / `VSKU` | `자사코드` | `판매자 상품코드` | `sto_code` 또는 `opt_value` 내 코드 후보 | `판매자 상품코드`, `솔루션사 고유코드` | `판매자관리코드`, `SKU` |
| `selfpia_sku_code` | `자사코드` 또는 `상품코드` 검토 | 직접 컬럼 없음 | 직접 컬럼 없음 | 직접 컬럼 없음 | `SKU`가 `sellpia_...` 형태 |
| `own_sku_code` | `자사코드` | `판매자 상품코드`가 후보 | `sto_code`, `opt_value` 내 bracket 코드 후보 | `솔루션사 고유코드` 또는 옵션명 내 bracket 코드 후보 | `SKU`, `판매자관리코드` |
| `product_name` | `상품명`, `매입상품명` | `상품명` | `product_name`, `mobile_product_name` | `상품명` | `온라인 상품명` |
| `option_name` | `옵션명`, `상세옵션 정보` | `옵션값`, `옵션명` | `opt_value`, `opt_values`, `opt_name` | `옵션1`, `옵션2`, `전체 옵션명` | `옵션`, `SKU상품` 시트의 `속성` |
| `channel_product_code` | 없음 | `상품번호` | `product_uid` | `상품 번호` | `쇼핑몰 상품번호` |
| `channel_option_code` | 없음 | `옵션번호` | `sto_id` | `옵션 번호` | `SKU` 또는 판매처별 옵션 문자열 내 위치 |
| `cost_price` | `매입가` | 직접 컬럼 없음 | `original_price`, `상품 구매원가` 한글 헤더 | 직접 컬럼 없음 | `원가` |
| `base_sale_price` | `판매가` | `판매가` | `sell_price` | `에이블리 판매가` | `판매가` |
| `channel_sale_price` | 없음 | `판매가` | `sell_price` | `에이블리 최종 판매가(앱)`, `에이블리 할인 판매가` | `판매가` |
| `option_extra_price` | 직접 컬럼 없음 | `옵션가` | `opt_price`, `sto_price` | 직접 컬럼 없음. 옵션별 가격은 row별 판매가로 해석 가능 | `옵션 추가금액` |
| `stock_qty` | `재고` | `재고수량` | `stock` | `재고수량` | `판매수량` |
| `available_qty` | `가용재고`, `통합가용재고` | `옵션 재고수량` 또는 `재고수량` | `sto_stock`, `stock` | `재고수량` | `옵션 판매수량`, `판매수량` |
| `safety_stock_qty` | `안전재고` | 직접 컬럼 없음 | `sto_safe_stock`, `확인요청수량` 계열 검토 | `안전재고` | 직접 컬럼 없음 |
| `soldout_status` | `품절` | 재고 0일 때 품절 처리. 별도 판매상태 컬럼은 양식 설명 확인 필요 | `sto_state`, `판매상태` | `품절상태`, `재고 소진시 판매 방식` | `상품상태(수정불가)`, `옵션 상태` |
| `display_status` | `판매구분` | `상품상태`, 옵션 사용여부 | `non_display`, `sell_accept`, `sto_state` | `진열상태` | `상품상태(수정불가)` |
| `representative_image` | `상품코드`가 이미지 파일명처럼 보이는 경우 있음. 별도 이미지 URL 자료와 연결 필요 | `대표이미지` | `max_image`, `mini_image`, `tiny_image` 중 대표 정책 필요 | 직접 컬럼 없음 | `기본이미지` |
| `additional_images` | 별도 이미지 URL 자료 필요 | `추가이미지` | `multi_images`, `gallery_image`, `mobile_image`, `tiny_gallery_image` | 직접 컬럼 없음 | 기본이미지 이후 이미지 URL 컬럼들 |
| `delivery_type` | 직접 컬럼 없음 | `배송방법`, `배송비유형` | `delivery` | `배송 타입` | `배송방법` |
| `courier_code` | 직접 컬럼 없음 | `택배사코드` | 직접 컬럼 없음 | `택배사` | 직접 컬럼 없음 또는 계정/template 정책 |
| `return_shipping_fee` | 직접 컬럼 없음 | 반품/교환 배송비 계열 컬럼 확인 필요 | 직접 컬럼 없음 | `반품 배송비(편도)` | 직접 컬럼 없음 또는 template 정책 |
| `remote_area_fee` | 직접 컬럼 없음 | 제주/도서산간 추가배송비 계열 컬럼 확인 필요 | 직접 컬럼 없음 | `도서산간추가배송비(편도)` | 직접 컬럼 없음 또는 template 정책 |

## 5. 채널별 특이사항

### 셀피아

- 내부 기준 데이터로 가장 적합하다.
- `자사코드`가 `1000-1` 형태로 들어 있어 내부 SKU/VSKU 기준 매핑의 핵심 후보가 된다.
- `판매가`, `매입가`, `재고`, `가용재고`, `통합가용재고`, `안전재고`, `품절`이 있어 가격/재고 기준값을 만들기 좋다.
- `상품코드`가 이미지 파일명처럼 보이는 샘플이 있어, 이미지 URL 자료와의 연결 정책을 별도로 확인해야 한다.

### 스마트스토어

- 1행은 섹션, 2행은 실제 필드명, 3행은 필수/비필수, 4~5행은 작성 가이드, 6행부터 데이터다.
- 업로드 파일 생성 시 3~5행 작성 가이드를 유지할지 삭제할지 정책이 필요하다.
- 핵심 키는 `상품번호`, `판매자 상품코드`, `옵션번호`다.
- 옵션 관련 값은 줄바꿈 또는 공백 구분으로 여러 옵션이 한 셀에 들어갈 수 있다.
- `smartstore_option_no_candidate` 같은 후보 옵션번호는 절대 확정 옵션번호처럼 사용하지 않는다.

### 메이크샵

- 1행은 한글 설명 헤더, 2행은 실제 영문 필드명이다.
- 핵심 키는 `product_uid`, `sto_id`, `sto_code`, `opt_value`다.
- 옵션 여러 줄 구조라 상품 단위 값이 비어 있는 row가 있을 수 있으며, 분석/매핑 시 product-level field forward-fill이 필요하다.
- 가격/재고 후보는 `sell_price`, `opt_price`, `sto_price`, `stock`, `sto_stock`이다.
- `sto_code`가 비어 있으면 `opt_value` 안의 bracket code를 후보로 볼 수 있으나, export에는 확정 mapping만 사용한다.

### 에이블리

- UTF-8-SIG CSV이며 1행이 헤더다.
- 핵심 키는 `상품 번호`, `판매자 상품코드`, `옵션 번호`, `솔루션사 고유코드`다.
- 가격은 `에이블리 판매가`, `에이블리 할인 판매가`, `에이블리 최종 판매가(앱)`이 분리되어 있다.
- 재고/상태는 `재고수량`, `안전재고`, `재고 소진시 판매 방식`, `품절상태`, `진열상태`를 함께 봐야 한다.
- 배송 관련 필드는 `배송 타입`, `택배사`, `반품 배송비(편도)`, `도서산간추가배송비(편도)`가 확인된다.

### 플레이오토

- 핵심 시트는 `쇼핑몰상품`이고, 보조 시트로 `쇼핑몰(ID)`, `SKU상품` 등이 있다.
- `쇼핑몰상품`은 약 4,220행, 95열이며 여러 판매처를 한 양식에서 다룬다.
- 핵심 키는 `판매자관리코드`, `쇼핑몰(계정)`, `쇼핑몰 상품번호`, `SKU`다.
- 한 행에 옵션/SKU가 공백 구분 문자열로 들어가는 구조다. export/import 시 옵션 배열 파싱과 재조립이 필요하다.
- `쇼핑몰(계정)` 값으로 스마트스토어, 에이블리 등 하위 판매처를 구분해야 한다.

## 6. Export 생성 시 검증 규칙

export 생성 전 최소 검증 규칙은 다음과 같다.

| 검증 항목 | 규칙 |
|---|---|
| 내부 SKU 존재 | 모든 export row는 내부 SKU 또는 VSKU에 연결되어야 한다. |
| 확정 코드 사용 | 판매처 상품코드/옵션코드는 확정 alias 또는 확정 channel mapping만 사용한다. |
| 후보 코드 차단 | 후보 코드, ambiguous 코드, 자동 추정 코드는 export 대상에서 제외하거나 경고로 표시한다. |
| 가격 필수값 | 판매처별 필수 가격 필드가 비어 있으면 export 불가로 표시한다. |
| 재고 필수값 | 판매처별 재고 필드가 필요한 경우 노출재고 값을 확정해야 한다. |
| 판매 상태 | 품절/진열/판매상태를 판매처 허용값으로 변환할 수 있어야 한다. |
| 옵션 개수 일치 | 옵션번호, 옵션값, 옵션가, 옵션재고의 개수가 판매처 양식 기준으로 맞아야 한다. |
| 이미지 URL | 대표이미지 필수 판매처는 URL 존재 여부를 확인한다. |
| 배송 필드 | 배송방법, 택배사, 반품/도서산간 배송비 필수 여부를 채널별로 확인한다. |
| 원본 양식 보존 | 판매처가 요구하는 헤더/가이드 행/시트 구조를 훼손하지 않는다. |

## 7. 미확정/추가 확인 필요 항목

- 스마트스토어 업로드 시 3~5행 작성 가이드를 실제 업로드 파일에 포함해야 하는지 삭제해야 하는지 확인 필요.
- 스마트스토어 `상품상태`와 실제 판매상태/품절상태의 변환 규칙 확인 필요.
- 메이크샵에서 상품 단위 row와 옵션 단위 row를 export 때 어떻게 구성해야 하는지 확인 필요.
- 메이크샵 `sto_code`와 `opt_value` 내 bracket code 중 어떤 값을 확정 옵션 연결로 쓸지 정책 확정 필요.
- 에이블리 `솔루션사 고유코드`의 실제 의미와 내부 자사코드 매핑 여부 확인 필요.
- 에이블리 가격 3종 중 실제 업로드 대상 가격 우선순위 확인 필요.
- 플레이오토 `SKU` 문자열의 옵션 순서, 옵션가격, 옵션재고 개수 일치 규칙 확인 필요.
- 플레이오토 `쇼핑몰(계정)`별 필드 해석 차이 확인 필요.
- 이미지 URL은 셀피아 이미지 URL 자료, `product_image`, 판매처별 이미지 URL 중 우선순위 확정 필요.
- 배송/반품/도서산간 정책은 내부 channel policy 후보 구조를 별도로 설계해야 한다.

## 8. 구현 단계 제안

1. 본 matrix 문서 검토 및 확정
2. 판매처별 template 버전/헤더 행/데이터 시작 행 문서화
3. 내부 표준 필드와 판매처 컬럼의 1:1/1:N/N:1 관계 정리
4. 후보 코드 차단 규칙 문서화
5. 로컬 전용 dry-run export preview 설계
6. API read-only export preview 조회 설계
7. 프론트 read-only export preview 화면 설계
8. 승인 후 CSV/XLSX 생성 기능 설계
9. 운영 반영 전 별도 승인 및 검증

## 9. 지금 하지 말아야 할 것

- SQL 실행 금지
- DB 변경 금지
- DDL 작성/실행 금지
- apply SQL 실행 금지
- API/Frontend 코드 수정 금지
- 원본 xlsx/csv/xml 파일 수정 금지
- 원본 xlsx/csv/xml 파일 git add 금지
- 실제 CSV/XLSX export 구현 금지
- 판매처 운영 업로드 실행 금지
- `git add .` 금지
- 사용자 승인 전 git add / commit / push 금지
- `sql/`, `outputs/`, `exports/`, `backups` 임의 add 금지

## 10. 대표님 보고용 요약

1. 실제 판매처 양식을 확인해서 어떤 내부 정보가 어느 판매처 컬럼으로 들어가야 하는지 표로 정리했습니다.
2. 셀피아는 내부 기준 자료로 보고, 스마트스토어/메이크샵/에이블리/플레이오토는 판매처별 업로드 대상 양식으로 분리했습니다.
3. 모든 판매처 export는 내부 SKU 기준으로 만들고, 판매처 상품코드와 옵션코드는 확정된 값만 쓰는 방향입니다.
4. 아직 DB, 사이트, 원본 양식 파일에는 아무것도 반영하지 않았습니다.
5. 다음 단계는 이 매핑표를 검토한 뒤, 후보 코드 차단과 필수값 누락 검증 규칙을 더 구체화하는 것입니다.
