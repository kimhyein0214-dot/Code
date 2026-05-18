# Ably Channel Analysis v1

## 1. Purpose

이 문서는 에이블리 상품/옵션/가격/재고/export 자료 구조를 분석하고, 기존 상품코드 통합 구조와 연결하기 위한 기준을 정리한다.

목표는 추후 판매처별 업로드 파일 생성 기능으로 확장하기 전에 에이블리 원본 컬럼이 어떤 의미를 갖는지, 어떤 컬럼을 매칭 근거로 사용할 수 있는지, 어떤 값은 후보 또는 검수 대상으로만 취급해야 하는지 분리하는 것이다.

이번 작업은 분석/문서화만 수행했다. SQL 실행, DB 접속, DB 변경, import/apply/export 파일 생성은 하지 않았다.

## 2. Current File Check Result

에이블리 관련 파일 발견 여부: 발견함.

| file | location | format | encoding | rows | columns | summary |
|---|---|---|---|---:|---:|---|
| `에이블리 ALL.csv` | repository root | CSV | UTF-8 BOM | 9,158 | 29 | 에이블리 상품/옵션 단위 row로 보인다. `상품 번호`는 956개, `옵션 번호`는 9,158개로 옵션 번호가 row 단위 고유 식별자 역할을 한다. |

발견한 컬럼:

`상품 번호`, `판매자 상품코드`, `상품명`, `브랜드`, `에이블리 판매가`, `에이블리 할인 판매가`, `에이블리 최종 판매가(앱)`, `4910 판매가`, `4910 할인 판매가`, `4910 현재 판매가`, `옵션 번호`, `솔루션사 고유코드`, `옵션1`, `옵션2`, `전체 옵션명`, `재고수량`, `안전재고`, `재고 소진시 판매 방식`, `품절상태`, `진열상태`, `카테고리`, `상품등록일`, `배송 타입`, `택배사`, `반품 배송비(편도)`, `도서산간추가배송비(편도)`, `성별`, `병행수입 여부`, `주문제작 여부`

간단 프로파일:

- `상품 번호`: 9,158/9,158 nonblank, distinct 956
- `옵션 번호`: 9,158/9,158 nonblank, distinct 9,158
- `판매자 상품코드`: 8,399 nonblank, distinct 939, blank or dash 759
- `솔루션사 고유코드`: 4,725 nonblank, distinct 4,691, blank or dash 4,433
- `품절상태`: `품절아님` 6,263, `품절` 2,895
- `진열상태`: `진열` 6,732, `미진열` 2,426
- `배송 타입`: `일반배송` 8,476, `오늘출발` 682
- bracket code pattern: `옵션1`, `옵션2`, `전체 옵션명` 안에 `[EE-8-04_4]` 같은 내부 코드형 문자열이 다수 포함되어 있으며, distinct bracket code는 5,983개로 관찰됨

개인정보/민감정보 가능성을 고려해 상품명과 원본 행 전체는 문서에 복붙하지 않았다. 원본 파일 수정 여부: 수정하지 않음.

## 3. Ably Column Classification

| group | columns | interpretation | use for matching/export |
|---|---|---|---|
| 상품 식별 | `상품 번호` | 에이블리 상품 단위 식별자. 한 상품에 여러 옵션이 연결된다. | `channel_product_code` 또는 `ably_product_no` 후보 |
| 옵션 식별 | `옵션 번호` | 에이블리 옵션/SKU 단위 식별자. 현재 파일에서는 row마다 고유하다. | `channel_option_code` 또는 `ably_option_no` 후보 |
| 자사/외부 코드 | `판매자 상품코드`, `솔루션사 고유코드`, 옵션명 안 bracket code | 내부 SKU, selfpia, own_sku와 연결될 수 있는 후보. 단 컬럼 의미는 확정 전이다. | 매칭 후보로 사용 가능. 단독 자동확정은 금지 |
| 상품명/옵션명 | `상품명`, `옵션1`, `옵션2`, `전체 옵션명` | 자동매칭 보조 evidence. 옵션명에는 코드형 문자열이 함께 들어갈 수 있다. | 코드 일치 검증 보조. 이름 유사도 단독 확정 금지 |
| 가격 | `에이블리 판매가`, `에이블리 할인 판매가`, `에이블리 최종 판매가(앱)`, `4910 판매가`, `4910 할인 판매가`, `4910 현재 판매가` | 에이블리/4910 채널 가격. 현재 4910 가격 3개 컬럼은 모두 blank/dash로 관찰됨. | 추후 `sku_channel_price` 또는 export field source 후보 |
| 재고 | `재고수량`, `안전재고`, `재고 소진시 판매 방식` | 채널 노출 재고와 안전재고/소진 정책. `안전재고=0`, `재고 소진시 판매 방식=품절`로 관찰됨. | 추후 `sku_channel_inventory` 및 export source 후보 |
| 판매상태 | `품절상태` | 판매 가능/품절 상태. | 가격/재고 상태 검수 및 export 변환 후보 |
| 노출상태 | `진열상태` | 에이블리 화면 진열 여부. | channel sale/display status 후보 |
| 이미지 | 현재 파일에 직접 이미지 URL 컬럼 없음 | 이미지가 필요한 export라면 `product_image` 또는 별도 에이블리 양식 확인 필요. | 현재 파일만으로는 이미지 export source 불충분 |
| 배송/기타 | `배송 타입`, `택배사`, `반품 배송비(편도)`, `도서산간추가배송비(편도)`, `카테고리`, `상품등록일`, `성별`, `병행수입 여부`, `주문제작 여부`, `브랜드` | 카테고리/배송/정책/상품 속성. `브랜드`, `성별`은 blank로 관찰됨. | export template field 또는 policy mapping 후보 |
| export/upload 필수 필드 | 미확정 | 실제 에이블리 업로드 템플릿을 별도 확보해야 필수/선택/수정 가능 여부를 확정할 수 있다. | 현재는 후보로만 문서화 |
| 매칭에 사용 가능 | `옵션 번호`, `상품 번호`, `판매자 상품코드`, `솔루션사 고유코드`, bracket code, `상품명`, `전체 옵션명` | 코드형 값은 우선 매칭 후보, 이름은 보조 evidence. | 확정/후보 code_system 분리 필요 |
| 매칭에 사용하면 위험 | `상품명`, `옵션1`, `옵션2`, `전체 옵션명`, `판매자 상품코드`, `솔루션사 고유코드` 단독 사용 | 이름 유사도와 관리코드만으로 1:1 SKU 보장이 없다. | 자동확정 금지, 수동검수 필요 |

## 4. Existing Integration Design

| Ably source | proposed integration target | note |
|---|---|---|
| 에이블리 `상품 번호` | `code_alias.code_system='ably_product_no'` 또는 `sku_channel_mapping.channel_product_code` 후보 | 상품 단위 코드다. SKU 단위 export에는 옵션 번호와 함께 사용해야 한다. |
| 에이블리 `옵션 번호` | `code_alias.code_system='ably_option_no'` 또는 `sku_channel_mapping.channel_option_code` 후보 | 현재 파일에서 row 고유값이므로 SKU 단위 channel option code 후보로 가장 중요하다. |
| `판매자 상품코드` | `own_sku`, `selfpia_sku`, 또는 channel seller code 후보 | 상품 단위로 일관되어 보이나 blank/dash가 있어 단독 확정 근거로 부족하다. |
| `솔루션사 고유코드` | `own_sku`, `selfpia_sku`, 또는 `ably_seller_code` 후보 | nonblank가 약 절반 수준이다. 실제 의미 확인 전 후보로만 둔다. |
| 옵션명 안 bracket code | `selfpia_sku` 또는 `own_sku` 후보 | `[EE-...]` 패턴이 다수 관찰된다. 기존 내부 코드 체계와 교차 확인 필요. |
| `상품명`, `옵션1`, `옵션2`, `전체 옵션명` | 자동매칭 보조 evidence | 코드 일치 후보의 신뢰도 보강 용도. 단독 자동확정 금지. |
| 가격 컬럼 | `sku_channel_price`, export field mapping 후보 | 에이블리 판매가/할인가/최종 판매가를 구분해서 보존해야 한다. |
| 재고/품절/진열 컬럼 | `sku_channel_inventory`, channel status/export field mapping 후보 | 코드매칭 검수와 분리하되 `sku_id` 기준으로 연결한다. |

권장 연결 원칙:

- 내부 기준 축은 `sku_id`다.
- 확정된 에이블리 상품/옵션 코드는 `sku_channel_mapping`에서 `channel='ably'`로 관리하는 방향이 export에 적합하다.
- 후보/검수 전 코드는 `code_alias`의 candidate system 또는 수동검수 CSV로 분리해 export source가 되지 않게 한다.
- `code_alias`는 `selfpia_sku`, `own_sku`, `ably_*` 후보를 모두 한곳에서 비교할 때 유용하다.
- 가격/재고/export는 `sku_id + channel + confirmed channel_product_code/channel_option_code`를 기준으로 연결한다.

## 5. code_system Candidates

실제 에이블리 공식 업로드/다운로드 템플릿과 컬럼 의미를 확인하기 전까지 아래 값은 확정이 아니라 후보다.

| code_system candidate | target level | meaning |
|---|---|---|
| `ably_product_no` | product/channel product | 확정된 에이블리 상품 번호 |
| `ably_option_no` | SKU/channel option | 확정된 에이블리 옵션 번호 |
| `ably_product_no_candidate` | product/channel product candidate | 검수 전 에이블리 상품 번호 후보 |
| `ably_option_no_candidate` | SKU/channel option candidate | 검수 전 에이블리 옵션 번호 후보 |
| `ably_seller_code` | product or SKU candidate, pending confirmation | 에이블리 파일의 판매자/솔루션사 관리코드 중 내부 코드와 연결되는 확정 코드 |
| `ably_seller_code_candidate` | product or SKU candidate | 판매자/솔루션사 관리코드 후보 |

## 6. Matching Priority Proposal

| priority | condition | action |
|---|---|---|
| P1 | 에이블리 옵션 관리코드, `솔루션사 고유코드`, 또는 옵션명 bracket code가 `selfpia_sku` 또는 `own_sku`와 명확히 1:1 일치하고, 상품명/옵션명도 충돌이 없음 | 자동확정 후보로 분류 가능. 그래도 첫 적용 전 샘플 검수 필요 |
| P2 | `판매자 상품코드`가 `own_sku` 또는 내부 상품 코드와 일치하지만 옵션명이 애매하거나 옵션 단위 코드가 부족함 | 수동검수 우선 후보 |
| P3 | 상품명/옵션명 유사도만 높거나 bracket code가 여러 SKU에 걸침 | 자동확정 금지. 수동검수 대상 |
| P4 | 코드 없음, 이름만 있음, 옵션 구조 불일치, blank/dash 관리코드 | 보류 또는 수동검수 대상 |

추가 규칙:

- `상품 번호`와 `옵션 번호`는 서로 다른 레벨이므로 혼합하지 않는다.
- `판매자 상품코드`는 상품 단위일 가능성이 높으므로 SKU 단위 확정에는 옵션 근거가 추가로 필요하다.
- `솔루션사 고유코드`는 값이 있는 row와 없는 row가 섞여 있으므로 null/blank 처리를 분리해야 한다.

## 7. Manual Review CSV Connection

기존 수동검수 설계 문서:

- `docs/manual_review_csv_design_v1.md`

에이블리 후보/미매칭도 같은 수동검수 CSV 구조에 포함한다.

- `reviewer_decision=pending`을 기본값으로 둔다.
- candidate row는 `export_allowed=false`가 기본값이다.
- 후보 코드는 export source로 사용하지 않는다.
- 검수 결과는 이후 자동매칭 rule/score 개선을 위한 학습 데이터로 재사용한다.

에이블리 수동검수 CSV 컬럼 후보:

| column | note |
|---|---|
| `review_group` | 예: `ably_candidate`, `ably_unmatched`, `ably_conflict` |
| `priority` | `P1`~`P4` |
| `sku_id` | 내부 SKU ID. 미매칭이면 blank 가능 |
| `selfpia_sku` | 내부/셀피아 SKU evidence |
| `own_sku` | 자사코드 evidence |
| `product_name` | 내부 상품명 |
| `option_name` | 내부 옵션명 |
| `channel` | `ably` |
| `channel_product_code` | 에이블리 `상품 번호` |
| `channel_option_code` | 에이블리 `옵션 번호` |
| `channel_product_name` | 에이블리 `상품명` |
| `channel_option_name` | 에이블리 `전체 옵션명` 또는 옵션 조합 |
| `candidate_code_system` | `ably_option_no_candidate`, `ably_seller_code_candidate` 등 |
| `candidate_product_no` | 에이블리 상품 번호 후보 |
| `candidate_option_no` | 에이블리 옵션 번호 후보 |
| `candidate_seller_code` | 판매자 상품코드/솔루션사 고유코드/bracket code 후보 |
| `candidate_reason` | 후보 생성 사유 |
| `candidate_score` | 자동매칭 점수 |
| `candidate_rank` | 후보 순위 |
| `reviewer_decision` | 기본값 `pending` |
| `reviewer_note` | 검수자 메모 |
| `export_allowed` | 기본값 `false` |
| `export_blocker_reason` | 예: `candidate_unreviewed`, `no_confirmed_code`, `ambiguous_seller_code` |

## 8. Price / Inventory / Export Connection

최종 목표:

- 상품 페이지에서 가격, 재고, 판매상태, 진열상태를 SKU 기준으로 관리한다.
- 에이블리 업로드 파일 생성은 별도 export 모듈에서 수행한다.
- 확정된 `channel_product_code`와 `channel_option_code`만 export source로 사용한다.
- 후보/미검수 코드는 export에서 차단한다.
- 가격/재고/판매상태 검수는 코드매칭 검수와 분리하되 `sku_id` 기준으로 연결한다.

에이블리 가격 연결:

- `에이블리 판매가`: 채널 기준 정상 판매가 후보
- `에이블리 할인 판매가`: 채널 할인 판매가 후보
- `에이블리 최종 판매가(앱)`: 실제 앱 노출/최종 가격 후보
- `4910 판매가`, `4910 할인 판매가`, `4910 현재 판매가`: 현재 파일에서는 blank/dash로 관찰됨. 4910 채널을 별도 sub-channel로 볼지 확인 필요

에이블리 재고/상태 연결:

- `재고수량`: 에이블리 노출 재고 또는 채널 재고 후보
- `안전재고`: 채널 안전재고 후보
- `재고 소진시 판매 방식`: 재고 0 이하 처리 정책 후보
- `품절상태`: 판매 가능/품절 상태 후보
- `진열상태`: 노출/미노출 상태 후보

export 연결:

- `channel='ably'`인 확정 mapping만 export 대상이 된다.
- `ably_product_no_candidate`, `ably_option_no_candidate`, `ably_seller_code_candidate`는 export 차단 대상이다.
- 에이블리 공식 업로드 템플릿을 확보한 뒤 필수/선택/업데이트 가능 컬럼을 확정한다.
- 이미지 URL이 필요하면 현재 CSV만으로는 부족하므로 `product_image` 또는 별도 이미지 파일/템플릿을 연결해야 한다.

## 9. Risks and Cautions

- 에이블리 상품번호와 옵션번호를 혼동하면 안 된다.
- 에이블리 자체 관리코드가 내부 SKU와 1:1이라는 보장은 없다.
- `own_sku`는 여러 SKU에 걸칠 수 있어 단독 자동확정에 위험이 있다.
- 상품명/옵션명 유사도만으로 자동확정하면 안 된다.
- 후보 코드는 export 금지다.
- 원본 파일은 수정하지 않는다.
- 운영 DB 반영은 별도 승인 전 금지다.
- `판매자 상품코드`는 상품 단위로 보이며 blank/dash가 존재하므로 SKU 단위 매칭에는 옵션 근거가 필요하다.
- `솔루션사 고유코드`는 nonblank row와 blank row가 섞여 있어 전체 SKU 커버리지 근거로 부족하다.
- 4910 가격 컬럼은 현재 파일에서 값이 비어 있으므로 에이블리와 4910을 같은 채널 가격으로 합치면 안 된다.
- 에이블리 업로드 필수 필드는 현재 CSV만으로 확정할 수 없다. 공식 업로드 템플릿 확인이 필요하다.

## 10. Suggested Next Steps

1. 에이블리 공식 업로드 템플릿 또는 최신 다운로드 양식 위치를 확인한다.
2. 에이블리 컬럼명과 필수/선택/수정 가능 여부를 확정한다.
3. `판매자 상품코드`, `솔루션사 고유코드`, 옵션명 bracket code가 각각 `selfpia_sku`/`own_sku` 중 무엇과 연결되는지 검증한다.
4. 에이블리 매칭 후보 SELECT/export 설계를 작성한다. 이 단계도 read-only 초안으로 시작한다.
5. 에이블리 후보/미매칭을 `docs/manual_review_csv_design_v1.md` 구조에 맞게 수동검수 CSV 설계에 반영한다.
6. reviewed CSV validation SQL 설계를 작성한다.
7. dryrun/apply/postcheck는 별도 승인 후에만 진행한다.
