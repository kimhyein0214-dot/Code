# Channel Export Validation Rules v1

작성일: 2026-05-16

## 1. 목적

이 문서는 판매처별 CSV/XLSX export 파일을 생성하기 전에 반드시 검사해야 할 검증 규칙을 정의한다.

목표는 스마트스토어, 메이크샵, 에이블리, 플레이오토 등 판매처별 업로드 양식에 데이터 오류, 위험값, 후보 코드, 불명확한 매핑이 들어가는 것을 사전에 차단하는 것이다.

이 문서는 실제 export 기능 구현 전 설계 문서다. DB 변경, SQL 실행, API 구현, Frontend 구현, 실제 CSV/XLSX 생성 기능 구현을 포함하지 않는다.

## 2. 검증 등급

| 등급 | 의미 | 처리 기준 |
|---|---|---|
| `export_blocker` | 반드시 export를 차단해야 하는 오류 | preview에는 표시하되 실제 파일 생성 대상에서 제외한다. |
| `export_warning` | 확인이 필요하지만 preview에는 표시 가능한 위험 또는 미확정 항목 | 담당자 확인 후 정책에 따라 차단으로 승격할 수 있다. |
| `info` | 참고 정보 | export 가능 여부에는 직접 영향이 없다. |

기본 원칙은 "확정된 값만 export"다. 후보 코드, ambiguous 코드, 자동 추정 코드는 운영 업로드 파일에 포함하지 않는다.

## 3. 공통 검증 규칙

### 3.1 내부 SKU / VSKU 연결

모든 export row는 내부 `internal_sku_id` 또는 VSKU/SKU 기준으로 연결되어야 한다.

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| 내부 SKU 또는 VSKU가 없거나 하나의 SKU로 확정되지 않음 | `export_blocker` | `MISSING_INTERNAL_SKU` |
| 한 row가 여러 내부 SKU 후보와 연결됨 | `export_blocker` | `AMBIGUOUS_MAPPING` |
| 내부 SKU는 있으나 운영 상태가 inactive/deleted/archive 계열로 판단됨 | `export_warning` 또는 `export_blocker` | `INVALID_INTERNAL_SKU_STATUS` |

### 3.2 셀피아 SKU / 자사코드

`selfpia_sku_code`와 `own_sku_code`는 내부 검수와 판매처 코드 연결의 기준값이다.

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| `selfpia_sku_code`가 없음 | `export_blocker` | `MISSING_SELFPIA_SKU_CODE` |
| `own_sku_code`가 필요한 채널에서 자사코드가 없음 | `export_blocker` | `MISSING_OWN_SKU_CODE` |
| 자사코드가 여러 SKU에 연결되어 확정 불가 | `export_blocker` | `AMBIGUOUS_MAPPING` |

### 3.3 판매처 상품코드 / 옵션코드

판매처 상품코드와 옵션코드는 확정된 `code_alias` 또는 `sku_channel_mapping` 값만 사용할 수 있다.

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| 채널 상품코드가 필수인데 없음 | `export_blocker` | `MISSING_CHANNEL_PRODUCT_CODE` |
| 채널 옵션코드가 필수인데 없음 | `export_blocker` | `MISSING_CHANNEL_OPTION_CODE` |
| 후보 코드 사용 시도 | `export_blocker` | `CANDIDATE_CODE_NOT_ALLOWED` |
| ambiguous 코드 사용 시도 | `export_blocker` | `AMBIGUOUS_MAPPING` |
| 자동 추정 코드 사용 시도 | `export_blocker` | `AUTO_INFERRED_CODE_NOT_ALLOWED` |

예: `smartstore_option_no_candidate`는 확정 옵션번호가 아니므로 export 금지다.

### 3.4 가격

가격은 채널별 필수 가격 출처가 먼저 정의되어야 한다. 채널 가격이 있으면 채널 가격을 우선하고, 없을 때 내부 기본 판매가를 fallback으로 쓸 수 있는지는 별도 정책으로 확정한다.

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| 필수 가격 누락 | `export_blocker` | `MISSING_REQUIRED_PRICE` |
| 가격이 숫자로 파싱되지 않음 | `export_blocker` | `INVALID_PRICE` |
| 판매가 또는 최종 판매가가 0원 이하 | `export_blocker` | `INVALID_PRICE` |
| 옵션가가 채널 허용 범위를 벗어남 | `export_blocker` | `INVALID_OPTION_PRICE` |
| 비정상적으로 큰 가격 또는 기준가 대비 급격한 차이 | `export_warning` | `SUSPICIOUS_PRICE` |
| 채널별 가격 우선순위 미확정 | `export_warning` | `PRICE_PRIORITY_UNCONFIRMED` |

### 3.5 재고

재고는 실제 보유재고와 채널 노출재고를 분리해서 검증한다.

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| 필수 재고값 누락 또는 공백 | `export_blocker` | `MISSING_STOCK` |
| 재고가 숫자로 파싱되지 않음 | `export_blocker` | `INVALID_STOCK` |
| 재고가 음수 | `export_blocker` | `INVALID_STOCK` |
| 채널 노출재고 산출 기준 미확정 | `export_warning` | `STOCK_POLICY_UNCONFIRMED` |

권장 산식 초안:

```text
available_export_qty = max(0, available_qty - safety_stock_qty)
```

단, 채널별 `sku_channel_inventory` 값이 확정되어 있으면 해당 값을 우선 사용한다. 실제 보유재고를 모든 채널에 그대로 내보내는 것은 과판매 위험이 있으므로 기본값으로 삼지 않는다.

### 3.6 품절상태 / 진열상태

내부 `soldout_status`, `display_status`는 채널별 허용값으로 변환 가능해야 한다.

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| 품절상태를 채널 허용값으로 변환할 수 없음 | `export_blocker` | `INVALID_SOLDOUT_STATUS` |
| 진열상태 또는 판매상태를 채널 허용값으로 변환할 수 없음 | `export_blocker` | `INVALID_DISPLAY_STATUS` |
| 재고 0인데 판매중 상태로 export 예정 | `export_warning` 또는 `export_blocker` | `STATUS_STOCK_CONFLICT` |

### 3.7 이미지

채널별로 대표이미지와 추가이미지 필수 여부를 확인한다.

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| 대표이미지가 필수인데 없음 | `export_blocker` | `MISSING_REQUIRED_IMAGE` |
| 이미지 URL 또는 파일 참조 형식이 채널 요구사항과 맞지 않음 | `export_blocker` | `INVALID_IMAGE_REFERENCE` |
| 추가이미지가 권장이나 없음 | `export_warning` | `MISSING_OPTIONAL_IMAGE` |

### 3.8 배송 / 택배사 / 반품비 / 도서산간비

배송 관련 필드는 채널별 policy mapping으로 관리되어야 한다.

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| 배송 타입 또는 배송비 정책 누락 | `export_blocker` | `MISSING_DELIVERY_POLICY` |
| 택배사 코드 필수 채널에서 누락 | `export_blocker` | `MISSING_COURIER_CODE` |
| 반품 배송비 필수 채널에서 누락 | `export_blocker` | `MISSING_RETURN_SHIPPING_FEE` |
| 도서산간 추가배송비 필수 채널에서 누락 | `export_blocker` | `MISSING_REMOTE_AREA_FEE` |
| 채널 정책 기본값 사용 여부 미확정 | `export_warning` | `DELIVERY_POLICY_UNCONFIRMED` |

### 3.9 옵션 배열 / 다중 라인 구조

옵션번호, 옵션명, 옵션가, 옵션재고가 한 row 안의 구분 문자열 또는 여러 row 구조로 표현되는 채널은 개수 일치를 검증해야 한다.

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| 옵션번호/옵션명/옵션가/옵션재고 개수 불일치 | `export_blocker` | `OPTION_COUNT_MISMATCH` |
| 옵션 문자열 파싱 실패 | `export_blocker` | `OPTION_PARSE_FAILED` |
| 상품 단위 row와 옵션 단위 row의 연결 실패 | `export_blocker` | `PRODUCT_OPTION_ROW_MISMATCH` |

### 3.10 원본 양식 헤더 / 가이드 행 보존

판매처 원본 양식은 헤더, 가이드 행, 시트 구조, 인코딩, 템플릿 버전이 중요하다.

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| 지원하지 않는 템플릿 버전 | `export_blocker` | `UNSUPPORTED_TEMPLATE_VERSION` |
| 필수 헤더 누락 또는 순서 변경 | `export_blocker` | `TEMPLATE_HEADER_MISMATCH` |
| 가이드 행 보존/삭제 정책 미확정 | `export_warning` 또는 `export_blocker` | `TEMPLATE_GUIDE_ROW_POLICY_UNCONFIRMED` |
| XLSX 시트명 또는 시트 구조 불일치 | `export_blocker` | `TEMPLATE_SHEET_MISMATCH` |

## 4. 채널별 검증 규칙

### 4.1 셀피아 기준 데이터

셀피아 데이터는 내부 SKU/VSKU, 가격, 재고, 자사코드 연결의 기준 데이터로 사용한다. 판매처 업로드 대상 파일이라기보다 export preview의 기준 원천으로 본다.

주요 blocker:

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| `selfpia_sku_code` 또는 VSKU가 내부 SKU에 연결되지 않음 | `export_blocker` | `MISSING_INTERNAL_SKU` |
| `selfpia_sku_code` 중복 또는 여러 SKU 연결 | `export_blocker` | `AMBIGUOUS_MAPPING` |
| `own_sku_code`가 없거나 여러 SKU에 연결됨 | `export_blocker` | `MISSING_OWN_SKU_CODE` / `AMBIGUOUS_MAPPING` |
| 판매가, 매입가, 재고, 가용재고가 숫자 검증 실패 | `export_blocker` | `INVALID_PRICE` / `INVALID_STOCK` |
| 품절상태 값이 내부 표준 상태로 변환 불가 | `export_blocker` | `INVALID_SOLDOUT_STATUS` |

추가 확인:

- `상품코드`가 이미지 파일명처럼 쓰이는 케이스와 실제 상품코드 케이스를 구분해야 한다.
- 가용재고와 통합가용재고 중 export 산출 기준으로 어떤 값을 우선할지 확정해야 한다.

### 4.2 스마트스토어

스마트스토어는 상품번호와 옵션번호 확정 여부가 핵심이다.

주요 blocker:

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| 상품번호 누락 | `export_blocker` | `MISSING_CHANNEL_PRODUCT_CODE` |
| 옵션번호 누락 | `export_blocker` | `MISSING_CHANNEL_OPTION_CODE` |
| `smartstore_option_no_candidate` 사용 시도 | `export_blocker` | `CANDIDATE_CODE_NOT_ALLOWED` |
| 판매자 상품코드 누락 | `export_blocker` | `MISSING_OWN_SKU_CODE` |
| 판매가, 옵션가, 재고수량 누락 | `export_blocker` | `MISSING_REQUIRED_PRICE` / `MISSING_STOCK` |
| 판매가 또는 옵션가가 0원 이하이거나 숫자 아님 | `export_blocker` | `INVALID_PRICE` |
| 재고수량이 공백, 음수, 숫자 아님 | `export_blocker` | `INVALID_STOCK` |
| 원본 양식 헤더 또는 필수 행 구조 불일치 | `export_blocker` | `TEMPLATE_HEADER_MISMATCH` |

warning / 확인 필요:

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| 3~5행 가이드 행을 보존할지 삭제할지 정책 미확정 | `export_warning` | `TEMPLATE_GUIDE_ROW_POLICY_UNCONFIRMED` |
| 대표이미지 필수 여부 미확정 또는 URL 누락 | `export_warning` 또는 `export_blocker` | `MISSING_REQUIRED_IMAGE` |
| 배송비 템플릿 코드 필요 여부 미확정 | `export_warning` | `DELIVERY_POLICY_UNCONFIRMED` |
| 상품상태, 판매상태, 품절상태 변환 규칙 미확정 | `export_warning` | `STATUS_POLICY_UNCONFIRMED` |

### 4.3 메이크샵

메이크샵은 `product_uid`, `sto_id`, `sto_code`, `opt_value` 관계와 상품 단위/옵션 단위 row 구조가 핵심이다.

주요 blocker:

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| `product_uid` 누락 | `export_blocker` | `MISSING_CHANNEL_PRODUCT_CODE` |
| `sto_id` 또는 확정 옵션키 누락 | `export_blocker` | `MISSING_CHANNEL_OPTION_CODE` |
| `sto_code` 또는 `opt_value` bracket code가 확정 mapping이 아님 | `export_blocker` | `AMBIGUOUS_MAPPING` |
| 후보/weak top1/자동추정 mapping 사용 시도 | `export_blocker` | `CANDIDATE_CODE_NOT_ALLOWED` |
| `sell_price`, `opt_price`, `sto_price` 숫자 검증 실패 | `export_blocker` | `INVALID_PRICE` |
| `stock`, `sto_stock` 누락, 음수, 숫자 아님 | `export_blocker` | `MISSING_STOCK` / `INVALID_STOCK` |
| 옵션 여러 줄 구조에서 row 개수 또는 key 연결 불일치 | `export_blocker` | `PRODUCT_OPTION_ROW_MISMATCH` |

warning / 확인 필요:

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| 상품 단위 값 forward-fill 필요 여부 미확정 | `export_warning` | `FORWARD_FILL_POLICY_UNCONFIRMED` |
| `sto_code`와 `opt_value` bracket code 중 우선순위 미확정 | `export_warning` | `OPTION_CODE_PRIORITY_UNCONFIRMED` |
| 상품 단위 row와 옵션 단위 row를 export에서 어떻게 구성할지 미확정 | `export_warning` | `TEMPLATE_ROW_STRUCTURE_UNCONFIRMED` |

### 4.4 에이블리

에이블리는 상품 번호, 옵션 번호, 솔루션사 고유코드와 가격 우선순위, 배송/상태 필드 검증이 중요하다.

주요 blocker:

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| 상품 번호 누락 | `export_blocker` | `MISSING_CHANNEL_PRODUCT_CODE` |
| 옵션 번호 누락 | `export_blocker` | `MISSING_CHANNEL_OPTION_CODE` |
| 솔루션사 고유코드 또는 판매자 상품코드가 내부 SKU와 연결되지 않음 | `export_blocker` | `MISSING_INTERNAL_SKU` |
| 재고수량 누락, 음수, 숫자 아님 | `export_blocker` | `MISSING_STOCK` / `INVALID_STOCK` |
| 안전재고가 숫자 아님 또는 재고보다 큰 경우 정책 미확정 | `export_warning` 또는 `export_blocker` | `INVALID_STOCK` |
| 품절상태 또는 진열상태 변환 불가 | `export_blocker` | `INVALID_SOLDOUT_STATUS` / `INVALID_DISPLAY_STATUS` |
| 배송 타입, 택배사, 반품 배송비, 도서산간 추가배송비 필수값 누락 | `export_blocker` | `MISSING_DELIVERY_POLICY` |

warning / 확인 필요:

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| 에이블리 판매가/할인가/최종 판매가 우선순위 미확정 | `export_warning` | `PRICE_PRIORITY_UNCONFIRMED` |
| 대표이미지 또는 추가이미지 필수 여부 미확정 | `export_warning` | `IMAGE_POLICY_UNCONFIRMED` |
| 재고 소진 시 판매 방식 변환 규칙 미확정 | `export_warning` | `STATUS_POLICY_UNCONFIRMED` |

### 4.5 플레이오토

플레이오토는 여러 하위 판매처를 중계할 수 있으므로 쇼핑몰 계정, 하위 판매처, 옵션 문자열 파싱 정책이 핵심이다.

주요 blocker:

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| 쇼핑몰 또는 계정 값 누락 | `export_blocker` | `MISSING_PLAYAUTO_ACCOUNT` |
| 쇼핑몰 상품번호 누락 | `export_blocker` | `MISSING_CHANNEL_PRODUCT_CODE` |
| 판매자관리코드 또는 SKU가 내부 SKU와 연결되지 않음 | `export_blocker` | `MISSING_INTERNAL_SKU` |
| 옵션/SKU 공백 구분 문자열 파싱 실패 | `export_blocker` | `OPTION_PARSE_FAILED` |
| 옵션명, 옵션 추가금액, 옵션 판매수량 개수 불일치 | `export_blocker` | `OPTION_COUNT_MISMATCH` |
| 하위 판매처별 필수값을 구분할 수 없음 | `export_blocker` | `SUB_CHANNEL_POLICY_MISSING` |

warning / 확인 필요:

| 규칙 | 등급 | 사유 코드 |
|---|---|---|
| 쇼핑몰 계정별 템플릿 차이 미확정 | `export_warning` | `SUB_CHANNEL_POLICY_UNCONFIRMED` |
| 플레이오토 자체 코드와 하위 판매처 코드 우선순위 미확정 | `export_warning` | `CHANNEL_CODE_PRIORITY_UNCONFIRMED` |
| 배송/이미지/상태 값이 하위 판매처별로 달라지는지 미확정 | `export_warning` | `SUB_CHANNEL_POLICY_UNCONFIRMED` |

## 5. Export 불가 사유 코드 초안

| 코드 | 의미 | 기본 등급 |
|---|---|---|
| `MISSING_INTERNAL_SKU` | 내부 SKU/VSKU 연결 없음 | `export_blocker` |
| `MISSING_SELFPIA_SKU_CODE` | 셀피아 SKU 코드 없음 | `export_blocker` |
| `MISSING_OWN_SKU_CODE` | 자사코드 또는 판매자관리코드 없음 | `export_blocker` |
| `MISSING_CHANNEL_PRODUCT_CODE` | 판매처 상품코드 없음 | `export_blocker` |
| `MISSING_CHANNEL_OPTION_CODE` | 판매처 옵션코드 없음 | `export_blocker` |
| `CANDIDATE_CODE_NOT_ALLOWED` | 후보 코드를 export에 사용하려 함 | `export_blocker` |
| `AUTO_INFERRED_CODE_NOT_ALLOWED` | 자동 추정 코드를 export에 사용하려 함 | `export_blocker` |
| `AMBIGUOUS_MAPPING` | 복수 후보 또는 불명확한 연결 | `export_blocker` |
| `MISSING_REQUIRED_PRICE` | 필수 가격 누락 | `export_blocker` |
| `INVALID_PRICE` | 가격이 0원 이하, 음수, 숫자 아님, 범위 초과 | `export_blocker` |
| `PRICE_PRIORITY_UNCONFIRMED` | 가격 우선순위 미확정 | `export_warning` |
| `MISSING_STOCK` | 필수 재고 누락 | `export_blocker` |
| `INVALID_STOCK` | 재고가 음수, 숫자 아님, 범위 초과 | `export_blocker` |
| `STOCK_POLICY_UNCONFIRMED` | 가용재고/안전재고 산출 정책 미확정 | `export_warning` |
| `OPTION_COUNT_MISMATCH` | 옵션번호/옵션명/옵션가/옵션재고 개수 불일치 | `export_blocker` |
| `OPTION_PARSE_FAILED` | 옵션 문자열 파싱 실패 | `export_blocker` |
| `PRODUCT_OPTION_ROW_MISMATCH` | 상품 row와 옵션 row 연결 실패 | `export_blocker` |
| `MISSING_REQUIRED_IMAGE` | 필수 이미지 누락 | `export_blocker` |
| `INVALID_IMAGE_REFERENCE` | 이미지 URL/파일 참조 형식 오류 | `export_blocker` |
| `MISSING_DELIVERY_POLICY` | 배송 정책 필수값 누락 | `export_blocker` |
| `MISSING_COURIER_CODE` | 택배사 코드 누락 | `export_blocker` |
| `MISSING_RETURN_SHIPPING_FEE` | 반품 배송비 누락 | `export_blocker` |
| `MISSING_REMOTE_AREA_FEE` | 도서산간 추가배송비 누락 | `export_blocker` |
| `INVALID_SOLDOUT_STATUS` | 품절상태 변환 실패 | `export_blocker` |
| `INVALID_DISPLAY_STATUS` | 진열/판매상태 변환 실패 | `export_blocker` |
| `UNSUPPORTED_TEMPLATE_VERSION` | 지원하지 않는 양식 버전 | `export_blocker` |
| `TEMPLATE_HEADER_MISMATCH` | 헤더/컬럼 구조 불일치 | `export_blocker` |
| `TEMPLATE_GUIDE_ROW_POLICY_UNCONFIRMED` | 가이드 행 처리 정책 미확정 | `export_warning` |
| `SUB_CHANNEL_POLICY_MISSING` | 플레이오토 하위 판매처 정책 없음 | `export_blocker` |

## 6. Export Preview 단계 제안

실제 파일 생성 전 read-only preview 단계에서 먼저 검증한다.

Preview row 상태:

| 상태 | 의미 |
|---|---|
| `ready` | blocker 없음. 실제 export 후보가 될 수 있음. |
| `warning` | blocker는 없지만 확인 필요한 warning 존재. |
| `blocked` | 하나 이상의 `export_blocker` 존재. 실제 파일 생성 대상에서 제외. |

Preview에서 보여줘야 할 항목:

- row별 상태: `ready` / `warning` / `blocked`
- blocked reason code와 설명
- warning code와 설명
- 채널별 필수값 누락 목록
- 내부 SKU, 셀피아 SKU, 자사코드, 판매처 상품코드, 판매처 옵션코드
- 가격/재고 산출 출처
- 후보 코드 포함 여부
- template version과 header validation 결과

후보 코드 포함 row는 항상 `blocked`로 처리한다. 예를 들어 `smartstore_option_no_candidate`, weak top1 후보, ambiguous 후보, 자동 추정 결과는 preview에는 보여줄 수 있지만 실제 export 대상에서는 제외한다.

## 7. 구현 단계 제안

1. validation rules 문서 검토 및 확정
2. 채널별 template version, 헤더, 가이드 행, 시트 구조 문서화
3. dry-run export preview 설계
4. API read-only preview 설계
5. 프론트 read-only preview 화면 설계
6. 담당자 승인 flow와 blocked/warning 처리 정책 확정
7. 승인 후 실제 CSV/XLSX 생성 기능 설계
8. 실제 운영 업로드 전 별도 샘플 파일 검증

초기 구현은 파일 생성보다 preview 정확도를 우선한다. preview가 안정화되기 전에는 실제 CSV/XLSX 생성 기능을 만들지 않는다.

## 8. 지금 하지 말아야 할 것

- DB 변경 금지
- SQL 실행 금지
- DDL 작성/실행 금지
- apply SQL 실행 금지
- schema/local patch SQL 실행 금지
- API 코드 수정 금지
- Frontend 코드 수정 금지
- 실제 CSV/XLSX export 기능 구현 금지
- 원본 xlsx/csv/xml 파일 수정 금지
- 원본 xlsx/csv/xml 파일 커밋 금지
- 운영 Supabase 반영 금지
- NAS PostgreSQL 반영 금지
- 운영 판매처 업로드 금지
- 사용자 승인 전 git add / commit / push 금지
- `git add .` 금지
- `sql/`, `outputs/`, `exports/`, `backups/` 임의 add 금지

## 9. 추가 확인 필요 항목

- 스마트스토어 3~5행 가이드 행을 실제 업로드 파일에 포함해야 하는지 여부
- 스마트스토어 대표이미지와 배송비 템플릿 코드 필수 여부
- 메이크샵 상품 단위 row와 옵션 단위 row export 구성 방식
- 메이크샵 `sto_code`와 `opt_value` bracket code 우선순위
- 에이블리 판매가/할인가/최종 판매가 우선순위
- 에이블리 이미지 필수 여부와 배송 필드 기본값 정책
- 플레이오토 계정별/하위 판매처별 필수 필드 차이
- 가용재고 산출 시 `available_qty`, `통합가용재고`, 채널 노출재고 중 우선순위
- 배송/택배사/반품비/도서산간비 channel policy mapping 구조
- 채널별 template version과 헤더 변경 감지 방식

## 10. 대표님 보고용 요약

판매처 업로드 파일을 만들기 전에 오류 데이터를 막는 검증 규칙을 문서화했습니다.  
후보 코드, 중복 매핑, 가격/재고 오류, 필수 이미지/배송정보 누락은 export 전에 차단합니다.  
스마트스토어, 메이크샵, 에이블리, 플레이오토별로 꼭 막아야 할 항목을 분리했습니다.  
실제 파일 생성 전 preview 화면에서 ready/warning/blocked 상태를 먼저 보여주는 방향입니다.  
이번 작업은 문서 작성만 했고 DB, SQL, API, 화면, 원본 양식 파일은 변경하지 않았습니다.
