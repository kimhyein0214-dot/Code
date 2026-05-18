# PlayAuto Channel Analysis v1

## 1. 목적

이 문서는 플레이오토 상품/옵션/판매처코드/가격/재고/export 자료 구조를 분석하고, 기존 상품코드 통합 구조와 연결하기 위한 기준을 정리한다.

목표는 다음과 같다.

- 플레이오토 상품/옵션/판매처코드/가격/재고/export 구조 분석
- 기존 상품코드 통합 구조와 연결하기 위한 기준 정리
- 추후 판매처별 업로드 파일 생성 기능으로 연결하기 위한 준비

이번 작업은 분석/문서화만 수행했다. SQL 실행, DB 접속, DB 변경, local apply, import, export 파일 생성은 하지 않았다.

## 2. 현재 파일 확인 결과

플레이오토 관련 파일 발견 여부: 발견함.

| file | location | format | sheets | summary |
|---|---|---|---:|---|
| `플레이오토_일반_ALL판매처 (판매중,수정대기,판매대기 ALL).xlsx` | repository root | XLSX | 7 | 플레이오토 판매처별 상품/옵션/SKU/템플릿/코드표 성격의 workbook |

시트별 요약:

| sheet | rows | columns | role |
|---|---:|---:|---|
| `쇼핑몰상품` | 4,219 data rows | 95 | 판매처별 상품 row. 상품, 판매처 계정, 쇼핑몰 상품번호, 가격, 옵션, SKU, 옵션별 수량/상태, 이미지, 배송/고시 정보 포함 |
| `쇼핑몰(ID)` | 7 data rows | 2 | 쇼핑몰 계정과 별칭 기준표 |
| `SKU상품` | 17,968 data rows | 4 | 플레이오토 SKU 코드, SKU명, 속성, 배송처코드 기준표 |
| `템플릿` | 12 data rows | 4 | 판매처별 템플릿 코드와 템플릿명 |
| `카테고리` | 23 data rows | 3 | 카테고리 코드표 |
| `인증정보 코드표` | 49 data rows | 2 | 인증 유형 코드표 |
| `원산지표` | 511 data rows | 1 | 원산지 값 목록 |

주요 프로파일:

- `쇼핑몰상품.판매자관리코드`: 4,219/4,219 nonblank, distinct 2,040
- `쇼핑몰상품.쇼핑몰(계정)`: 4개 값 관찰
  - `스마트스토어=w_ground`: 2,039 rows
  - `에이블리=pink_rocket@naver.com`: 2,016 rows
  - `쿠팡=wworks2010`: 161 rows
  - `카카오톡 스토어=pink_rocket@naver.com`: 3 rows
- `쇼핑몰상품.쇼핑몰 상품번호`: 2,945 nonblank, distinct 2,945, blank 1,274
- `쇼핑몰상품.상품상태(수정불가)`: `판매중`, `판매대기`, `수정대기`, `승인대기`, `일시품절`, `판매중지` 관찰
- `쇼핑몰상품.SKU`: 4,207 nonblank, distinct cell patterns 2,112, multi-line SKU list 형태
- `SKU상품.SKU코드`: 17,968 rows, distinct 17,968
- `쇼핑몰상품`의 옵션/SKU/옵션 추가금액/옵션 판매수량/출고수량/옵션 상태는 한 cell 안에 줄바꿈으로 옵션별 값이 들어가는 구조가 많다.

원본 파일 수정 여부: 수정하지 않음.

개인정보/민감정보 가능성을 고려해 상품명, 이미지 URL, 원본 행 전체는 문서에 직접 복붙하지 않았다.

## 3. 플레이오토 컬럼 분류표

| group | columns | interpretation | use for matching/export |
|---|---|---|---|
| 상품 식별 | `판매자관리코드`, `쇼핑몰 상품번호`, `온라인 상품명`, `템플릿코드`, `카테고리코드(마스터에서 수정)` | 플레이오토 상품 row와 판매처 상품 row를 구분하는 핵심 컬럼. `판매자관리코드`는 내부/판매자 관리 코드 후보, `쇼핑몰 상품번호`는 판매처 상품번호 후보 | `channel_product_code`, `playauto_product_code`, 판매처별 product code 후보 |
| 옵션/SKU 식별 | `옵션조합`, `옵션`, `SKU`, `옵션 추가금액`, `옵션 판매수량`, `출고수량`, `옵션 무게(kg)`, `옵션 상태` | 한 상품 row 안에 여러 옵션/SKU가 줄바꿈 목록으로 들어간다. SKU 단위로 펼치는 전처리가 필요하다 | SKU 단위 `channel_option_code` 또는 내부 `own_sku`/`selfpia_sku` 후보 |
| 판매처/채널 식별 | `쇼핑몰(계정)`, `템플릿코드`, `쇼핑몰(ID).쇼핑몰(ID)`, `쇼핑몰(ID).별칭`, `템플릿.쇼핑몰(ID)` | 플레이오토가 여러 판매처 계정을 허브처럼 묶는다. `스마트스토어`, `에이블리`, `쿠팡`, `카카오톡 스토어`가 관찰됨 | `channel`, `marketplace_name`, `channel_account`, export template 선택 기준 |
| 자사/외부 코드 | `판매자관리코드`, `SKU`, `SKU상품.SKU코드`, `SKU상품.속성`, 옵션명 안 bracket code | `sellpia_...` 형태 SKU와 `[PI-...]` 같은 내부 코드형 값이 관찰된다 | `own_sku`, `selfpia_sku`, `playauto_seller_code` 후보 |
| 상품명/옵션명 | `온라인 상품명`, `옵션`, `SKU상품.SKU명`, `SKU상품.속성` | 자동매칭 보조 evidence. 이름 유사도만으로 확정 금지 | 후보 점수 보조, 수동검수 표시 |
| 가격 | `판매가`, `공급가`, `원가`, `시중가`, `옵션 추가금액`, `추가구매 옵션 추가금액` | 상품 단위 판매가와 옵션 단위 추가금액이 분리되어 있다. 판매처별 가격 차이가 존재할 수 있음 | `sku_channel_price`, export field mapping 후보 |
| 재고 | `판매수량`, `옵션 판매수량`, `출고수량`, `추가구매 옵션 판매수량`, `추가구매 옵션 출고수량` | 상품/옵션/추가구매 옵션 단위 수량이 섞여 있다 | `sku_channel_inventory` 후보. 옵션 단위 펼침 필요 |
| 판매상태 | `상품상태(수정불가)`, `옵션 상태`, `추가구매 옵션 상태` | 상품상태는 수정불가 표시가 붙어 있고, 옵션 상태는 Y/N형 목록으로 보인다 | sale status 후보. 수정 가능 여부는 공식 템플릿 확인 필요 |
| 노출상태 | 명시적 진열상태 컬럼은 현재 핵심 시트에서 확인되지 않음 | 판매상태/상품상태/템플릿/판매처 정책과 분리 확인 필요 | display status 후보는 공식 템플릿 확인 전 미확정 |
| 이미지 | `기본이미지`, `추가이미지1`~`추가이미지9`, `상세설명` | 이미지 URL과 상세설명이 포함된다 | `product_image`, export image field 후보 |
| 배송/기타 | `배송처코드`, `원산지`, `복수원산지 여부`, `과세여부`, `배송방법`, `배송비`, `모델명`, `브랜드`, `제조사`, `바코드`, `키워드`, `인증유형`, `인증정보`, `HS코드`, `해외배송 여부`, `무게`, `상품정보제공고시 1`~`24`, `예약 전송일시`, `예약 항목` | 판매처 업로드에 필요한 정책/속성/고시/예약 정보 | export template field 후보 |
| export/upload 필수 필드 | 미확정 | 현재 파일은 플레이오토 관리/업로드형 workbook으로 보이나 필수/선택/수정 가능 여부는 공식 템플릿 확인 필요 | 공식 템플릿 확보 후 확정 |
| 매칭에 사용 가능 | `판매자관리코드`, `쇼핑몰(계정)`, `쇼핑몰 상품번호`, `SKU`, `SKU상품.SKU코드`, `SKU상품.속성`, 옵션 bracket code | 코드형 값은 우선 매칭 후보. 판매처 계정은 channel 분기 기준 | 확정/후보 분리 필요 |
| 매칭에 사용하면 위험 | `온라인 상품명`, `옵션`, `SKU상품.SKU명`, `SKU상품.속성`, `판매자관리코드` 단독 사용 | 이름 유사도와 관리코드만으로 내부 SKU 1:1 보장이 없다. `판매자관리코드`는 여러 판매처 row에 반복된다 | 자동확정 금지, 수동검수 필요 |

## 4. 기존 통합 구조와의 연결 설계

| PlayAuto source | proposed integration target | note |
|---|---|---|
| 플레이오토 `판매자관리코드` | `playauto_product_code` 또는 `playauto_seller_code` 후보 | 상품 row의 관리 코드. 여러 판매처 계정에 반복되므로 SKU 단위 확정에는 옵션/SKU 근거가 필요 |
| 플레이오토 상품코드/상품번호 후보 | `channel_product_code` 후보 | 현재 파일에서는 `쇼핑몰 상품번호`가 판매처 상품번호 역할을 한다. 플레이오토 내부 상품번호가 별도 존재하는지는 공식 템플릿 확인 필요 |
| 플레이오토 `SKU` / `SKU상품.SKU코드` | `own_sku`, `selfpia_sku`, `playauto_option_code` 후보 | `sellpia_...` 형태이며 SKU 단위 연결 가능성이 높다 |
| 플레이오토 옵션코드/옵션번호 후보 | SKU 단위 `channel_option_code` 후보 | 현재 파일에는 명시적 판매처 옵션번호 컬럼이 보이지 않고, `SKU`와 옵션 목록이 줄바꿈 구조로 존재한다 |
| `쇼핑몰(계정)` | `channel`, `marketplace_name`, `channel_account` 후보 | 판매처명/계정이 함께 들어 있다. 스마트스토어/에이블리/쿠팡 등 개별 판매처 export와 연결 가능 |
| `쇼핑몰 상품번호` | 판매처별 `channel_product_code` 후보 | 판매처별 외부 상품번호로 보인다. blank row가 있어 상태별/신규등록 row 구분 필요 |
| 판매처 상품번호/옵션번호 | 각 판매처별 channel code 후보 | 상품번호는 확인됨. 옵션번호는 현재 파일만으로 명확하지 않음 |
| `온라인 상품명`, `옵션`, `SKU상품.SKU명`, `SKU상품.속성` | 자동매칭 보조 evidence | 코드 일치 후보의 검증 근거. 단독 자동확정 금지 |
| 가격/재고/판매상태 컬럼 | `sku_channel_price`, `sku_channel_inventory`, sale status/export mapping 후보 | 코드매칭 검수와 분리하되 `sku_id` 기준으로 연결 |

권장 연결 원칙:

- 내부 기준 축은 `sku_id`다.
- 플레이오토가 허브 역할을 하므로 `playauto_*` 내부 코드와 `smartstore`, `ably`, `coupang`, `kakaotalk_store` 같은 실제 판매처 코드를 분리한다.
- 확정된 판매처별 상품/옵션 코드는 `sku_channel_mapping`에서 `channel`과 함께 관리하는 방향이 export에 적합하다.
- 후보/검수 전 코드는 `code_alias` candidate system 또는 수동검수 CSV로 분리하고 export source가 되지 않게 한다.
- 가격/재고/export는 `sku_id + marketplace_name/channel + confirmed channel_product_code/channel_option_code` 기준으로 연결한다.

## 5. code_system 후보

실제 플레이오토 공식 템플릿과 컬럼 의미를 확인하기 전까지 아래 값은 확정이 아니라 후보다.

| code_system candidate | target level | meaning |
|---|---|---|
| `playauto_product_code` | product | 플레이오토 내부 상품 코드 후보 |
| `playauto_option_code` | SKU/option | 플레이오토 내부 옵션/SKU 코드 후보 |
| `playauto_product_no` | product | 플레이오토 내부 상품번호 후보 |
| `playauto_option_no` | SKU/option | 플레이오토 내부 옵션번호 후보 |
| `playauto_seller_code` | product or SKU | 판매자관리코드/자체상품코드 확정 후보 |
| `playauto_channel_product_code` | marketplace product | 판매처별 상품번호/쇼핑몰 상품번호 확정 후보 |
| `playauto_channel_option_code` | marketplace option | 판매처별 옵션번호/쇼핑몰 옵션코드 확정 후보 |
| `playauto_product_code_candidate` | product candidate | 검수 전 플레이오토 상품 코드 후보 |
| `playauto_option_code_candidate` | SKU/option candidate | 검수 전 플레이오토 옵션/SKU 코드 후보 |
| `playauto_seller_code_candidate` | product or SKU candidate | 검수 전 판매자관리코드 후보 |
| `playauto_channel_product_code_candidate` | marketplace product candidate | 검수 전 판매처별 상품번호 후보 |
| `playauto_channel_option_code_candidate` | marketplace option candidate | 검수 전 판매처별 옵션번호 후보 |

## 6. 매칭 우선순위 제안

| priority | condition | action |
|---|---|---|
| P1 | 플레이오토 자체상품코드/옵션코드 또는 `SKU상품.SKU코드`가 `selfpia_sku` 또는 `own_sku`와 명확히 1:1 일치하고, 상품명/옵션명도 충돌이 없음 | 자동확정 후보로 분류 가능. 첫 적용 전 샘플 검수 필요 |
| P2 | 플레이오토 옵션코드/SKU가 SKU 단위로 고유하고, `쇼핑몰(계정)` 및 `쇼핑몰 상품번호`도 함께 확인 가능 | 수동검수 우선 후보 또는 높은 신뢰 후보 |
| P3 | 판매처별 상품번호/옵션번호는 있으나 내부 코드 연결이 애매함 | 수동검수 대상 |
| P4 | 상품명/옵션명 유사도만 높은 후보 | 자동확정 금지, 수동검수 대상 |
| P5 | 코드 없음, 이름만 있음, 옵션 구조 불일치, multi-line 옵션 펼침 실패 | 보류 또는 수동검수 대상 |

추가 규칙:

- `판매자관리코드`는 여러 판매처 row에 반복되므로 판매처별 상품번호와 같은 레벨로 다루면 안 된다.
- `쇼핑몰 상품번호`는 판매처별 외부 상품번호로 보이며, 플레이오토 내부 상품코드와 혼동하면 안 된다.
- `SKU` cell은 multi-line 구조이므로 옵션별로 펼친 뒤 option name, extra price, option quantity, option status와 line alignment를 검증해야 한다.

## 7. 수동검수 CSV 연결

기존 수동검수 설계 문서:

- `docs/manual_review_csv_design_v1.md`

플레이오토 후보/미매칭도 같은 수동검수 CSV 구조에 포함한다.

- `reviewer_decision=pending`을 기본값으로 둔다.
- candidate row는 `export_allowed=false`가 기본값이다.
- 후보 코드는 export source로 사용하지 않는다.
- 검수 결과는 이후 자동매칭 rule/score 개선을 위한 학습 데이터로 재사용한다.

플레이오토 수동검수 CSV 컬럼 후보:

| column | note |
|---|---|
| `review_group` | 예: `playauto_candidate`, `playauto_unmatched`, `playauto_conflict`, `playauto_channel_code_gap` |
| `priority` | `P1`~`P5` |
| `sku_id` | 내부 SKU ID. 미매칭이면 blank 가능 |
| `selfpia_sku` | 셀피아 SKU evidence |
| `own_sku` | 자사코드 evidence |
| `product_name` | 내부 상품명 |
| `option_name` | 내부 옵션명 |
| `channel` | `playauto` |
| `marketplace_name` | 예: `smartstore`, `ably`, `coupang`, `kakaotalk_store` |
| `channel_product_code` | 판매처별 상품번호 후보 |
| `channel_option_code` | 판매처별 옵션번호/옵션코드 후보 |
| `channel_product_name` | 플레이오토 `온라인 상품명` |
| `channel_option_name` | 플레이오토 옵션명/속성 |
| `candidate_code_system` | `playauto_option_code_candidate`, `playauto_channel_product_code_candidate` 등 |
| `candidate_product_code` | 플레이오토 상품 코드 후보 |
| `candidate_option_code` | 플레이오토 옵션/SKU 코드 후보 |
| `candidate_seller_code` | 판매자관리코드 후보 |
| `candidate_channel_product_code` | 판매처 상품번호 후보 |
| `candidate_channel_option_code` | 판매처 옵션번호/옵션코드 후보 |
| `candidate_reason` | 후보 생성 사유 |
| `candidate_score` | 자동매칭 점수 |
| `candidate_rank` | 후보 순위 |
| `reviewer_decision` | 기본값 `pending` |
| `reviewer_note` | 검수자 메모 |
| `export_allowed` | 기본값 `false` |
| `export_blocker_reason` | 예: `candidate_unreviewed`, `no_confirmed_channel_code`, `multi_line_option_parse_needed` |

## 8. 가격/재고/export 연결

최종 목표:

- 상품 페이지에서 가격, 재고, 판매상태를 SKU 기준으로 관리한다.
- 플레이오토 업로드 파일 또는 플레이오토를 통한 판매처별 업로드 파일 생성을 지원한다.
- 확정된 `channel_product_code`와 `channel_option_code`만 export source로 사용한다.
- 후보/미검수 코드는 export에서 차단한다.
- 가격/재고/판매상태 검수는 코드매칭 검수와 분리하되 `sku_id` 기준으로 연결한다.
- 플레이오토가 허브 역할을 한다면, 스마트스토어/메이크샵/에이블리/쿠팡의 개별 code와 어떤 관계인지 확인해야 한다.

가격 연결:

- `판매가`: 상품/판매처 row 기준 판매가 후보
- `공급가`: 공급가 후보. 현재 핵심 row에서는 0으로 관찰됨
- `원가`: 원가 후보. 대부분 0으로 관찰됨
- `시중가`: 표시/비교가 후보. 대부분 0으로 관찰됨
- `옵션 추가금액`: 옵션별 추가금액 후보. multi-line alignment 필요
- `추가구매 옵션 추가금액`: 추가구매 옵션 가격 후보

재고/상태 연결:

- `판매수량`: 상품 row 단위 판매수량 또는 노출수량 후보
- `옵션 판매수량`: 옵션별 판매 가능 수량 후보
- `출고수량`: 옵션별 출고수량 후보
- `옵션 상태`: 옵션별 판매 가능 상태 후보
- `상품상태(수정불가)`: 상품 상태. 수정 가능 여부는 공식 템플릿 확인 필요

export 연결:

- `쇼핑몰(계정)`을 기준으로 실제 판매처를 분기한다.
- `템플릿코드`는 판매처별 upload template 선택 후보가 된다.
- `기본이미지`, `추가이미지1`~`추가이미지9`, `상세설명`은 이미지/상세설명 export 후보이다.
- `상품정보제공고시 1`~`24`, 원산지, 인증정보, 배송 정보는 판매처별 필수 필드 후보이다.
- 후보 코드와 미검수 row는 `export_allowed=false`로 유지한다.

## 9. 위험/주의사항

- 플레이오토 내부 코드와 실제 판매처 코드가 다를 수 있다.
- 플레이오토가 허브라면 `플레이오토 코드`와 `각 판매처 코드`를 혼동하면 안 된다.
- 자체상품코드가 내부 SKU와 1:1이라는 보장은 없다.
- `own_sku`는 여러 SKU에 걸칠 수 있어 단독 자동확정에 위험이 있다.
- 상품명/옵션명 유사도만으로 자동확정하면 안 된다.
- 후보 코드는 export 금지다.
- 원본 파일은 수정하지 않는다.
- 운영 DB 반영은 별도 승인 전 금지다.
- `쇼핑몰 상품번호`가 blank인 row가 있으므로 신규등록/판매대기/수정대기 상태별 의미를 확인해야 한다.
- multi-line 옵션/SKU/가격/수량/상태 column은 line count가 어긋나면 잘못된 SKU에 가격이나 재고가 붙을 수 있다.
- `상품상태(수정불가)`처럼 수정불가 표시가 있는 컬럼은 export 수정 대상에서 제외될 가능성이 높다.

## 10. 플레이오토 공식 업로드 템플릿 확보 후 확인할 질문

| check | question | answer_after_template_review |
|---|---|---|
| [ ] | 플레이오토 내부 상품코드와 판매처 상품코드는 별도인가? | TBD |
| [ ] | 플레이오토 옵션코드와 판매처 옵션코드는 별도인가? | TBD |
| [ ] | 가격 수정 기준키는 무엇인가? | TBD |
| [ ] | 재고 수정 기준키는 무엇인가? | TBD |
| [ ] | 판매처별로 업로드 템플릿이 다른가? | TBD |
| [ ] | 플레이오토 하나의 양식으로 여러 판매처에 반영 가능한가? | TBD |
| [ ] | 판매처별 상품번호/옵션번호를 파일에서 확인할 수 있는가? | TBD |
| [ ] | 자체상품코드 또는 판매자 관리코드를 기준키로 사용할 수 있는가? | TBD |
| [ ] | 품절상태/판매상태/진열상태를 업로드로 수정할 수 있는가? | TBD |
| [ ] | 빈 값 업로드 시 기존 값 유지인지 삭제/초기화인지? | TBD |
| [ ] | 일부 컬럼만 업로드 가능한가? | TBD |
| [ ] | 신규등록용 템플릿과 수정용 템플릿이 다른가? | TBD |
| [ ] | 업로드 실패 사유 파일을 받을 수 있는가? | TBD |

추가 확인 질문:

- `쇼핑몰(계정)` 값의 앞부분을 표준 `channel`로 변환하는 공식 매핑이 있는가?
- `SKU` multi-line 값과 `옵션`, `옵션 추가금액`, `옵션 판매수량`, `출고수량`, `옵션 상태`의 줄 순서가 항상 1:1인가?
- `쇼핑몰 상품번호`가 blank인 row는 신규등록 대기인지, 판매처 미연동인지, 판매대기 상태인지?
- `템플릿코드`는 export/upload 시 필수인가?
- 이미지 URL과 상세설명은 수정용 export에서 필수인가?

## 11. 다음 단계 제안

1. 플레이오토 원본 파일 위치와 버전을 기록한다.
2. 플레이오토 공식 업로드 템플릿을 확보한다.
3. 컬럼명, 필수/선택 여부, 수정 가능 여부, 기준키를 확정한다.
4. 플레이오토 내부 코드와 판매처별 코드 관계를 확인한다.
5. multi-line 옵션/SKU/가격/재고/상태 column을 SKU row로 펼치는 read-only 설계를 작성한다.
6. 플레이오토 매칭 후보 SELECT/export 설계를 작성한다.
7. 플레이오토 수동검수 CSV 설계에 `channel=playauto`와 `marketplace_name`을 반영한다.
8. reviewed CSV validate SQL 설계를 작성한다.
9. dryrun/apply/postcheck는 별도 승인 후에만 진행한다.
