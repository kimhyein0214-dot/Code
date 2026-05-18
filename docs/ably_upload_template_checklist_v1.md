# Ably Upload Template Checklist v1

## 1. 목적

이 문서는 에이블리 공식 업로드 템플릿을 확보한 뒤 반드시 확인해야 할 항목을 정리한다.

현재 저장소에는 `에이블리 ALL.csv`가 있으며, 이 파일은 에이블리 현재 상품/옵션/가격/재고/상태 자료로 보인다. 다만 실제 업로드 가능 컬럼, 필수값, 수정 가능 여부, 빈 값 처리 방식은 공식 업로드 템플릿을 확인해야 확정할 수 있다.

목표는 다음과 같다.

- 에이블리 공식 업로드 템플릿 확보 후 확인할 항목 정리
- 현재 `에이블리 ALL.csv`와 업로드 템플릿의 컬럼 차이를 비교하기 위한 기준 마련
- 추후 가격/재고/판매상태 관리 및 에이블리 업로드 파일 생성 기능으로 연결하기 위한 준비

이번 작업은 문서화만 수행한다. SQL 실행, DB 접속, DB 변경, import, apply, export 파일 생성은 하지 않는다.

## 2. 현재 확인된 에이블리 ALL.csv 요약

| 항목 | 현재 확인 내용 |
|---|---|
| 파일명 | `에이블리 ALL.csv` |
| 위치 | repository root |
| row count | 9,158 |
| column count | 29 |
| 상품 식별 후보 | `상품 번호` |
| 옵션 식별 후보 | `옵션 번호` |
| 옵션 번호 특성 | 전체 row에서 고유 |
| 가격 컬럼 | `에이블리 판매가`, `에이블리 할인 판매가`, `에이블리 최종 판매가(앱)`, `4910 판매가`, `4910 할인 판매가`, `4910 현재 판매가` |
| 재고/상태 컬럼 | `재고수량`, `안전재고`, `재고 소진시 판매 방식`, `품절상태`, `진열상태` |
| 매칭 후보 컬럼 | `판매자 상품코드`, `솔루션사 고유코드`, `옵션1`, `옵션2`, `전체 옵션명` 안 bracket code |
| 이미지 컬럼 | 현재 CSV에는 직접 이미지 URL 컬럼 없음 |
| 배송/기타 컬럼 | `카테고리`, `상품등록일`, `배송 타입`, `택배사`, `반품 배송비(편도)`, `도서산간추가배송비(편도)`, `성별`, `병행수입 여부`, `주문제작 여부` |

현재 해석:

- `상품 번호`는 에이블리 상품 단위 식별자 후보이다.
- `옵션 번호`는 에이블리 옵션/SKU 단위 식별자 후보이다.
- 가격/재고/상태 컬럼은 추후 `sku_channel_price`, `sku_channel_inventory`, export field mapping과 연결될 수 있다.
- `판매자 상품코드`, `솔루션사 고유코드`, 옵션명 bracket code는 `selfpia_sku` 또는 `own_sku`와의 매칭 후보지만, 단독 자동확정 근거로 사용하면 안 된다.

관련 문서:

- `docs/ably_channel_analysis_v1.md`
- `docs/manual_review_csv_design_v1.md`
- `docs/price_inventory_export_design_v1.md`

## 3. 공식 업로드 템플릿 확보 후 확인할 질문

공식 템플릿을 확보하면 아래 질문에 답을 채워야 한다.

| check | question | answer_after_template_review |
|---|---|---|
| [ ] | 업로드 기준키는 상품 번호인가, 옵션 번호인가? | TBD |
| [ ] | 옵션 단위 수정 시 옵션 번호가 필수인가? | TBD |
| [ ] | 상품 번호 없이 옵션 번호만으로 가격/재고 수정이 가능한가? | TBD |
| [ ] | 판매자 상품코드 또는 솔루션사 고유코드를 기준키로 사용할 수 있는가? | TBD |
| [ ] | 가격 수정에 필요한 필수 컬럼은 무엇인가? | TBD |
| [ ] | 재고 수정에 필요한 필수 컬럼은 무엇인가? | TBD |
| [ ] | 품절상태 수정이 가능한가? | TBD |
| [ ] | 진열상태 수정이 가능한가? | TBD |
| [ ] | 판매상태와 진열상태가 별도 개념인가? | TBD |
| [ ] | 옵션 추가금액이 있는 경우 최종 판매가는 어떻게 계산되는가? | TBD |
| [ ] | 빈 값 업로드 시 기존 값 유지인지, 삭제/초기화인지? | TBD |
| [ ] | 템플릿에 없는 컬럼을 포함하면 오류가 나는가? | TBD |
| [ ] | 일부 컬럼만 업로드 가능한가? | TBD |
| [ ] | 전체 상품 일괄 업로드만 가능한가? | TBD |
| [ ] | 수정용 템플릿과 신규등록용 템플릿이 다른가? | TBD |
| [ ] | 업로드 후 실패 사유 파일을 받을 수 있는가? | TBD |

추가 확인 질문:

- 업로드 파일 형식은 CSV, XLSX, 또는 둘 다 가능한가?
- 인코딩 요구사항이 있는가?
- 숫자 가격에 comma가 허용되는가?
- `품절`, `품절아님`, `진열`, `미진열` 같은 한글 상태값을 그대로 업로드할 수 있는가?
- 옵션 row와 상품 row가 같은 파일에 섞이는가, 아니면 별도 템플릿인가?
- 이미지 URL 또는 이미지 파일 업로드가 필수인가?
- 배송/반품/카테고리 필드는 수정 템플릿에서 필수인가?
- 업로드 성공 후 에이블리 상품/옵션 번호가 변경될 수 있는가?

## 4. 컬럼 비교표 템플릿

공식 업로드 템플릿을 확보한 뒤 아래 표를 채운다.

| current_csv_column | upload_template_column | field_group | required_for_upload | required_for_update | update_allowed | used_as_key | maps_to_internal_field | note |
|---|---|---|---|---|---|---|---|---|
| `상품 번호` | TBD | 상품 식별 | TBD | TBD | TBD | TBD | `channel_product_code`, `ably_product_no` | 상품 단위 key 후보 |
| `옵션 번호` | TBD | 옵션 식별 | TBD | TBD | TBD | TBD | `channel_option_code`, `ably_option_no` | SKU/옵션 단위 key 후보 |
| `판매자 상품코드` | TBD | 자사/외부 코드 | TBD | TBD | TBD | TBD | `own_sku`, `selfpia_sku`, `ably_seller_code` 후보 | 상품 단위 가능성 주의 |
| `솔루션사 고유코드` | TBD | 자사/외부 코드 | TBD | TBD | TBD | TBD | `own_sku`, `selfpia_sku`, `ably_seller_code` 후보 | blank row 존재 |
| `상품명` | TBD | 상품명 | TBD | TBD | TBD | no | `product_name`, evidence | 이름 단독 자동확정 금지 |
| `옵션1` | TBD | 옵션명 | TBD | TBD | TBD | no | `option_name`, evidence | bracket code 추출 가능 |
| `옵션2` | TBD | 옵션명 | TBD | TBD | TBD | no | `option_name`, evidence | 옵션 조합 확인 필요 |
| `전체 옵션명` | TBD | 옵션명 | TBD | TBD | TBD | no | `option_name`, evidence | channel option display name 후보 |
| `에이블리 판매가` | TBD | 가격 | TBD | TBD | TBD | no | `price`, `sku_channel_price` | 정상 판매가 후보 |
| `에이블리 할인 판매가` | TBD | 가격 | TBD | TBD | TBD | no | `discount_price`, `sku_channel_price` | 할인 판매가 후보 |
| `에이블리 최종 판매가(앱)` | TBD | 가격 | TBD | TBD | TBD | no | `final_price`, `sku_channel_price` | 앱 최종 노출가 후보 |
| `4910 판매가` | TBD | 가격 | TBD | TBD | TBD | no | channel/sub-channel price 후보 | 현재 값 비어 있음 |
| `4910 할인 판매가` | TBD | 가격 | TBD | TBD | TBD | no | channel/sub-channel price 후보 | 현재 값 비어 있음 |
| `4910 현재 판매가` | TBD | 가격 | TBD | TBD | TBD | no | channel/sub-channel price 후보 | 현재 값 비어 있음 |
| `재고수량` | TBD | 재고 | TBD | TBD | TBD | no | `inventory_quantity`, `sku_channel_inventory` | 채널 노출 재고 후보 |
| `안전재고` | TBD | 재고 | TBD | TBD | TBD | no | safety stock 후보 | 현재 대부분 0으로 관찰 |
| `재고 소진시 판매 방식` | TBD | 재고/판매상태 | TBD | TBD | TBD | no | stockout policy 후보 | 값 체계 확인 필요 |
| `품절상태` | TBD | 판매상태 | TBD | TBD | TBD | no | `sale_status` | 품절/품절아님 값 변환 필요 |
| `진열상태` | TBD | 노출상태 | TBD | TBD | TBD | no | `display_status` | 진열/미진열 값 변환 필요 |
| `카테고리` | TBD | 배송/기타 | TBD | TBD | TBD | no | category mapping 후보 | 카테고리 code/name 구분 필요 |
| `상품등록일` | TBD | 배송/기타 | TBD | TBD | TBD | no | source metadata | 업로드 수정 대상인지 확인 |
| `배송 타입` | TBD | 배송/기타 | TBD | TBD | TBD | no | channel shipping policy 후보 | 일반배송/오늘출발 |
| `택배사` | TBD | 배송/기타 | TBD | TBD | TBD | no | shipping carrier 후보 | 정책성 값 |
| `반품 배송비(편도)` | TBD | 배송/기타 | TBD | TBD | TBD | no | return shipping fee 후보 | 정책성 값 |
| `도서산간추가배송비(편도)` | TBD | 배송/기타 | TBD | TBD | TBD | no | remote area fee 후보 | 정책성 값 |
| `브랜드` | TBD | 상품 속성 | TBD | TBD | TBD | no | brand 후보 | 현재 blank |
| `성별` | TBD | 상품 속성 | TBD | TBD | TBD | no | gender attribute 후보 | 현재 blank |
| `병행수입 여부` | TBD | 상품 속성 | TBD | TBD | TBD | no | import flag 후보 | 값 체계 확인 |
| `주문제작 여부` | TBD | 상품 속성 | TBD | TBD | TBD | no | made-to-order flag 후보 | 값 체계 확인 |

field_group 후보:

- 상품 식별
- 옵션 식별
- 자사/외부 코드
- 상품명/옵션명
- 가격
- 재고
- 판매상태
- 노출상태
- 이미지
- 배송/기타
- export/upload 필수 필드

## 5. 내부 구조 연결 후보

| internal field | Ably source candidate | note |
|---|---|---|
| `sku_id` | 확정 매칭 결과 | 모든 가격/재고/export 연결의 내부 기준 |
| `selfpia_sku` | `솔루션사 고유코드`, 옵션명 bracket code, 기존 `code_alias` | 실제 코드 체계 확인 필요 |
| `own_sku` | `판매자 상품코드`, `솔루션사 고유코드`, 옵션명 bracket code | 여러 SKU에 걸칠 수 있어 단독 확정 금지 |
| `channel_product_code` | `상품 번호` | `ably_product_no` 확정값 후보 |
| `channel_option_code` | `옵션 번호` | `ably_option_no` 확정값 후보 |
| `price` | `에이블리 판매가`, `에이블리 할인 판매가`, `에이블리 최종 판매가(앱)` | 정상가/할인가/최종가를 분리해서 매핑 |
| `inventory_quantity` | `재고수량` | 채널 노출 재고 후보 |
| `sale_status` | `품절상태`, `재고 소진시 판매 방식` | 판매 가능/품절 처리 규칙 확인 필요 |
| `display_status` | `진열상태` | 노출/미노출 처리 규칙 확인 필요 |
| `export_blocker_reason` | 후보 코드, 미검수, 필수 컬럼 누락, 값 변환 실패 | export 차단 사유 표준화 필요 |

code system 후보:

- `ably_product_no`
- `ably_option_no`
- `ably_product_no_candidate`
- `ably_option_no_candidate`
- `ably_seller_code`
- `ably_seller_code_candidate`

## 6. Export 전 필수 검증

export 전에는 최소한 아래 항목을 검증해야 한다.

| check | required rule |
|---|---|
| [ ] | 확정된 `ably_product_no` / `ably_option_no`만 사용한다. |
| [ ] | 후보 코드는 `export_allowed=false`로 유지한다. |
| [ ] | 가격 변경값이 비어 있을 때 기존 값 유지인지 삭제/초기화인지 확인한다. |
| [ ] | 재고 변경값이 비어 있을 때 기존 값 유지인지 삭제/초기화인지 확인한다. |
| [ ] | 판매상태/진열상태 변경값이 비어 있을 때 기존 값 유지인지 삭제/초기화인지 확인한다. |
| [ ] | 옵션 번호 중복 여부를 export 직전에 재확인한다. |
| [ ] | 상품 번호와 옵션 번호를 혼동하지 않는다. |
| [ ] | 템플릿 필수 컬럼을 누락하지 않는다. |
| [ ] | 템플릿에 없는 컬럼 포함 가능 여부를 확인한다. |
| [ ] | 가격 숫자 포맷, comma, currency 표시 허용 여부를 확인한다. |
| [ ] | 상태값 변환표를 확정한다. 예: `품절아님`, `품절`, `진열`, `미진열`. |
| [ ] | `판매자 상품코드` 또는 `솔루션사 고유코드`를 key로 사용할 경우 1:1 여부를 재검증한다. |
| [ ] | 이미지 필수 여부를 확인한다. 현재 CSV에는 이미지 URL 컬럼이 없다. |
| [ ] | 업로드 전 샘플 5~10건으로 dry-run 또는 수동 검증을 수행한다. |

export blocker 후보:

- `candidate_unreviewed`
- `no_confirmed_ably_product_no`
- `no_confirmed_ably_option_no`
- `ambiguous_seller_code`
- `missing_required_template_column`
- `blank_update_value_policy_unknown`
- `duplicate_channel_option_code`
- `product_option_level_confusion`
- `invalid_price_format`
- `invalid_inventory_format`
- `invalid_status_value`
- `image_required_but_missing`

## 7. 다음 단계

1. 에이블리 공식 업로드 템플릿을 확보한다.
2. 템플릿 컬럼명, 필수/선택 여부, 수정 가능 여부, key 컬럼을 분석한다.
3. `에이블리 ALL.csv`와 공식 템플릿 컬럼을 비교한다.
4. 에이블리 read-only 매칭 후보 SELECT 설계를 작성한다.
5. 수동검수 CSV에 `channel=ably` 항목을 반영한다.
6. 가격/재고/export 설계에 에이블리 연결을 반영한다.
7. dryrun/apply/export 생성은 별도 승인 전까지 진행하지 않는다.
