# Manual Review Export Priority Plan v1

## 목적

이 문서는 `select_manual_review_export_summary_v1.sql`의 local read-only 실행 결과를 바탕으로 수동검수 CSV 대상을 우선순위별로 나누기 위한 계획이다.

이번 문서는 실제 CSV 생성 문서가 아니며, DB 변경이나 확정 apply를 전제로 하지 않는다. 기존 상세 SELECT 결과를 그대로 CSV화하지 않고, 검수 가능한 범위로 나눈 filtered SELECT를 별도로 설계하기 위한 기준을 정리한다.

## summary 실행 결과 요약

전체 수동검수 후보 row 수는 119,560건이다.

채널별 분포:

| source_channel | row_count |
| --- | ---: |
| ably | 33,291 |
| makeshop | 20,442 |
| playauto | 33,291 |
| smartstore | 32,536 |

review_reason별 분포:

| review_reason | row_count |
| --- | ---: |
| ably_missing | 19,466 |
| image_missing | 54,048 |
| makeshop_missing | 6,617 |
| own_sku_missing | 1,252 |
| playauto_missing | 19,466 |
| smartstore_candidate_or_unreviewed | 11,054 |
| smartstore_missing | 7,657 |

안전 상태:

| check | result |
| --- | ---: |
| export_allowed = false | 119,560 |
| reviewer_decision = pending | 119,560 |

## 전체 119,560건을 한 번에 검수하면 안 되는 이유

119,560건을 한 번에 CSV로 뽑으면 사람이 검수 가능한 단위를 넘어선다. 채널별 원인과 조치 방식도 다르기 때문에 한 파일에 섞이면 우선순위 판단, 검수 기준, 반려/보류 사유 관리가 어려워진다.

특히 `image_missing`은 54,048건으로 가장 크지만, 상품코드 확정 검수와는 성격이 다르다. 이미지 보강 또는 이미지 없음 검수 기준을 먼저 정해야 하므로 1차 상품코드 수동검수와 분리하는 것이 안전하다.

Ably와 PlayAuto는 각각 19,466건의 missing 대상이 있으나, 공식 업로드 템플릿과 채널별 코드 의미를 확정하기 전에는 export 대상으로 삼으면 안 된다. PlayAuto는 판매처 허브 성격이 있으므로 내부 코드와 실제 판매처 코드 분리를 추가 확인해야 한다.

## 1차 수동검수 추천 범위

1차 검수는 Smartstore와 MakeShop의 상품코드 연결성에 직접 영향을 주는 범위부터 시작한다.

| priority | target | row_count | reason |
| --- | --- | ---: | --- |
| P1 | Smartstore candidate_or_unreviewed | 11,054 | 후보 또는 미검수 상태이므로 productNo/optionNo 분리 검수가 필요하다. |
| P1 | Smartstore missing | 7,657 | Smartstore productNo/optionNo 연결이 비어 있어 우선 확인 대상이다. |
| P1 | MakeShop missing | 6,617 | source_row_ref, raw_payload 기반 추적성을 확인하며 누락 mapping을 검수해야 한다. |

1차 범위 합계는 25,328건이다. 이 범위도 한 번에 확정 apply하지 않고, 채널별 filtered SELECT를 별도 SQL로 설계한 뒤 사용자가 검수 가능한 단위로 나누는 것이 좋다.

Smartstore 검수에서는 `confirmed_product_no`, `confirmed_option_no`, `candidate_product_no`, `candidate_option_no`를 분리해서 유지한다. `smartstore_product_no_candidate`와 `smartstore_option_no_candidate`는 확정값이 아니며, 후보 코드는 export source가 될 수 없다.

MakeShop 검수에서는 `source_row_ref`, `candidate_rank`, `candidate_score`, `match_rule_before`의 확보 수준을 확인한다. 현재 직접 컬럼이 없는 값은 `raw_payload` 또는 `NULL` placeholder로 보수 처리되어야 하며, `review_required`, `ambiguous`, `manual` 성격의 대상은 자동 apply하지 않는다.

## 2차 보조 검수 범위

2차 범위는 코드 매핑 자체보다 보조 데이터 품질과 검수 가능성에 영향을 주는 항목이다.

| priority | target | row_count | reason |
| --- | --- | ---: | --- |
| P2 | own_sku_missing | 1,252 | own_sku 단독 자동확정은 금지지만, 누락 여부는 채널 검수 전제에 영향을 준다. |
| P2 | image_missing | 54,048 | 상품 이미지 없음 검수 또는 이미지 보강 정책이 필요하다. |

`own_sku_missing`은 규모가 작고 여러 채널 검수의 기반 품질에 영향을 주므로 별도 확인 가치가 있다. 다만 own_sku만으로 상품코드를 자동확정해서는 안 된다.

`image_missing`은 규모가 매우 크므로 상품코드 수동검수 CSV와 분리한다. 이미지 없음 대상을 검수할지, product_image 보강 후 재집계할지, 채널별 업로드 필요 여부를 먼저 정해야 한다.

## 보류 또는 별도 분석 범위

아래 범위는 공식 템플릿과 채널 구조 확인 전까지 확정 export 대상으로 삼지 않는다.

| status | target | row_count | reason |
| --- | --- | ---: | --- |
| Hold | Ably missing | 19,466 | 상품 번호와 옵션 번호 분리, option_no 고유성 재확인이 필요하다. |
| Hold | PlayAuto missing | 19,466 | PlayAuto는 판매처 허브이므로 쇼핑몰별 multi-line 옵션 구조 확인이 필요하다. |

Ably는 판매자 상품코드, 솔루션사 고유코드, 옵션명 bracket code를 후보로만 취급한다. 공식 업로드 템플릿을 확보하기 전까지 확정 export를 금지한다.

PlayAuto는 단일 판매처가 아니라 판매처 허브로 취급한다. 쇼핑몰 계정, 쇼핑몰 상품번호, SKU, 옵션, 가격, 수량, 상태의 line alignment를 검증하기 전에는 export 확정 단계로 넘어가지 않는다.

## 안전 원칙 유지

summary 결과상 전체 119,560건이 `export_allowed = false`이고 `reviewer_decision = pending`이다.

이 상태는 유지되어야 한다.

- 후보 또는 미검수 row는 `export_allowed = false`를 유지한다.
- 기본 `reviewer_decision`은 `pending`을 유지한다.
- 후보 코드는 확정 export source가 될 수 없다.
- confirm처럼 보이는 값도 validate, dry-run, 사용자 승인, local apply, postcheck 전에는 확정 반영하지 않는다.
- 실제 CSV 생성과 DB apply는 별도 승인 단계에서만 다룬다.

## 다음 단계 제안

`select_manual_review_export_v1.sql`을 바로 CSV화하지 않는다. 전체 상세 row 출력은 검수와 운영 판단에 너무 크고, 채널별 기준이 섞일 위험이 있다.

다음 단계는 priority별 filtered SELECT를 별도로 설계하는 것이다.

추천 SQL 초안:

- `sql/smartstore_manual_review_export_v1.sql`
- `sql/makeshop_manual_review_export_v1.sql`
- `sql/own_sku_missing_review_v1.sql`
- `sql/image_missing_review_v1.sql`

1차로는 Smartstore와 MakeShop만 분리한다.

- Smartstore: `smartstore_candidate_or_unreviewed`, `smartstore_missing`
- MakeShop: `makeshop_missing`

Ably와 PlayAuto는 공식 업로드 템플릿과 채널 구조 확인 전까지 보류한다.
