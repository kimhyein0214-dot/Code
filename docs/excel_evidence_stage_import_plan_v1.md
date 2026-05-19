# Excel Evidence Stage Import Plan v1

## 목적

이 문서는 향후 엑셀 증거 데이터를 stage로 가져와 검증한다고 가정할 때 필요한 컬럼과 절차를 설계한다. 이번 작업에서는 stage relation을 만들지 않고, 원본 엑셀도 변경하지 않는다.

대상 증거 파일:

- `가격 수정 리스트 - 수정하였습니다.xlsx`
- `플레이오토 스스_옵션_변경양식.xlsx`
- `플레이오토 스스_일반_변경양식.xlsx`

## 권장 stage 구조

권장 logical stage 이름:

- `stg.excel_evidence_match_stage`

권장 컬럼:

| 컬럼 | 용도 |
| --- | --- |
| `source_file` | 원본 파일명 |
| `source_sheet` | 원본 시트명 |
| `row_no` | 원본 행 번호 |
| `source_channel` | `smartstore`, `makeshop`, `playauto`, `ably`, `selfpia`, `cross_channel` |
| `raw_seller_management_code` | `sellpia_11422`, `S-10529-1`, `P-10529-1` 등 원본 관리코드 |
| `normalized_selfpia_product_code` | `sellpia_11422`에서 추출한 `11422` |
| `normalized_selfpia_sku_code` | `sellpia_11422-1` 또는 `10529-1`에서 추출한 셀피아 SKU |
| `raw_product_name` | 원본 상품명 |
| `normalized_product_name` | 공백/특수문자 등 최소 정규화된 상품명 |
| `raw_option_text` | 원본 옵션명/속성/옵션1 값 |
| `normalized_option_text` | 색상/속성 분리 전후 비교용 정규화 옵션명 |
| `extracted_own_sku` | 대괄호에서 추출한 own_sku 후보 |
| `smartstore_product_no_candidate` | Smartstore productNo 후보 |
| `playauto_sku_code` | `sellpia_11422-1` 같은 PlayAuto SKU 코드 원문 |
| `raw_price` | 원본 판매가/옵션가/수정가격 등 |
| `raw_stock` | 원본 재고/판매수량 |
| `raw_option_price` | 옵션 추가금액/옵션조합가격 |
| `raw_delivery_code` | 배송처코드 |
| `multiline_group_key` | multi-line 상품행을 펼친 경우 원본 상품행 묶음 키 |
| `multiline_option_index` | multi-line 옵션 순번 |
| `multiline_sku_index` | multi-line SKU 순번 |
| `multiline_option_count` | 원본 상품행의 옵션 줄 수 |
| `multiline_sku_count` | 원본 상품행의 SKU 줄 수 |
| `parse_status` | `parsed`, `warning`, `failed` |
| `parse_warning` | bracket 오류, 줄 수 불일치, 위험 토큰 등 |
| `match_status` | `not_checked`, `candidate`, `auto_confirm_ready_candidate`, `manual_review_required` |
| `safety_note` | 자동확정 금지 사유 또는 안전 근거 |
| `export_allowed` | stage 진단 단계에서는 항상 `false` |
| `reviewer_decision` | stage 진단 단계에서는 항상 `pending` |

## 파일별 매핑 설계

### 가격 수정 리스트

`DB_0`은 cross-channel 연결 stage로 우선 사용한다.

- `상품코드` -> `normalized_selfpia_sku_code`
- `메이크샵` -> MakeShop 판매처 관리코드 후보
- `스마트스토어` -> Smartstore 자체 코드 후보 또는 productNo 연결 보조
- `플레이오토` -> PlayAuto 자체 코드 후보
- `에이블리` -> Ably 자체 코드 후보
- `상품명`, `매입옵션명`, `옵션명` -> 상품명/옵션명 보강
- 가격류 -> 보조 검산

`DB_1~DB_4`는 판매처별 펼침 구조로 사용한다.

- `DB_1`: MakeShop
- `DB_2`: Smartstore
- `DB_3`: PlayAuto
- `DB_4`: Ably

### 플레이오토 스스_옵션_변경양식

`옵션기본`을 Smartstore option-level stage로 펼친다.

- `*판매자관리코드` -> `normalized_selfpia_product_code`
- `옵션 SKU 코드` -> `normalized_selfpia_sku_code`, `playauto_sku_code`
- `쇼핑몰상품코드` -> `smartstore_product_no_candidate`
- `옵션1 값` -> `raw_option_text`, `extracted_own_sku`
- `온라인 상품명` -> `raw_product_name`
- `추가 금액`, `판매가능재고`, `*판매수량`, `배송처코드` -> 보조 컬럼

### 플레이오토 스스_일반_변경양식

`쇼핑몰상품`은 multi-line 옵션/SKU를 같은 순서로 펼친다.

- `판매자관리코드` -> `normalized_selfpia_product_code`
- `쇼핑몰 상품번호` -> `smartstore_product_no_candidate`
- `옵션` -> 줄 단위 `raw_option_text`
- `SKU` -> 줄 단위 `normalized_selfpia_sku_code`
- `배송처코드`, `옵션 추가금액`, `옵션 판매수량` -> 줄 단위 보조 컬럼
- 옵션 줄 수와 SKU 줄 수가 다르면 해당 상품행 전체를 수동검수로 둔다.

`SKU상품`은 셀피아 SKU/속성 보강 stage로 사용한다.

- `SKU코드` -> `normalized_selfpia_sku_code`
- `SKU명` -> `raw_product_name`
- `속성` -> `raw_option_text`, `extracted_own_sku`
- `배송처코드` -> `raw_delivery_code`

## import 전 precheck

stage 반영 전 다음을 확인한다.

- 원본 파일명과 시트명이 기대 목록과 일치하는지.
- 헤더명이 기대 컬럼과 일치하는지.
- 원본 행 번호가 보존되는지.
- `sellpia_숫자`, `sellpia_숫자-숫자` 파싱 성공률.
- `숫자-숫자` 셀피아 SKU 후보 파싱 성공률.
- 대괄호 own_sku 추출 성공률과 bracket 오류 행.
- Smartstore productNo 후보가 숫자형으로 1개인지.
- multi-line 옵션 줄 수와 SKU 줄 수가 일치하는지.
- `크리스탈`/`크리스탈AB`, `AB`, `화이트골드`/`실버`, `세트`/`한쌍`/`낱개` 위험 토큰이 플래그되는지.
- 같은 `normalized_selfpia_sku_code`가 여러 `smartstore_product_no_candidate`로 갈라지는지.
- 같은 `smartstore_product_no_candidate + normalized_option_text`가 여러 셀피아 SKU와 충돌하는지.

## read-only validation 항목

stage 적재 후에는 읽기 전용으로만 다음을 확인한다.

- 총 stage 행 수.
- 셀피아 SKU 파싱 성공 행 수.
- own_sku 파싱 성공 행 수.
- Smartstore productNo 파싱 성공 행 수.
- `product_code.code_alias`의 `selfpia_sku` join 성공 행 수.
- `product_code.code_alias`의 `own_sku` join 성공 행 수.
- 상품명 보강 evidence가 있는 행 수.
- 옵션 정규화 후 1:1 후보 행 수.
- auto-confirm-ready 후보 행 수.
- manual-review-required 행 수.
- 충돌/중복 행 수.
- 위험 토큰별 경고 행 수.

## 금지 원칙

- 엑셀을 바로 `product_code.code_alias`에 반영하지 않는다.
- 후보를 confirmed처럼 취급하지 않는다.
- `export_allowed`는 진단 단계에서 `false`를 유지한다.
- `reviewer_decision`은 진단 단계에서 `pending`을 유지한다.
- 원본 `.xlsx`는 변경하지 않는다.
- 원본 `.xlsx`는 git에 추가하지 않는다.

## 권장 진행 순서

1. stage 컬럼 설계 확정.
2. 로컬에서 엑셀 파서로 summary만 생성해 파싱 규칙 검증.
3. stage로 분리 보관.
4. read-only validation.
5. dry-run 결과 문서화.
6. 사용자 승인.
7. local 환경에서만 apply 후보를 별도 검토.
8. postcheck.

운영 DB 또는 원격 DB로 바로 가지 않는다.
