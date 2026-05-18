# Manual Review Export Precheck Plan v1

작성일: 2026-05-18

## 1. 목적

이 문서는 실제 수동검수 CSV를 뽑기 전에 필요한 테이블과 컬럼이 존재하는지 확인하는 precheck 단계의 기준을 정리한다.

이번 단계는 DB 변경이 아니라 구조 확인용이다. precheck 결과를 보고 수동검수 CSV를 만들 수 있는 최소 기반이 있는지 판단하고, 실제 SELECT export 초안과 reviewed CSV validate SQL 설계로 넘어간다.

## 2. 대상 채널

- Smartstore
- MakeShop
- Ably
- PlayAuto

## 3. 공통 원칙

- 후보 또는 미검수 row는 `export_allowed=false`가 기본이다.
- `reviewer_decision` 기본값은 `pending`이다.
- candidate는 절대 export source가 될 수 없다.
- reviewer가 `confirm`을 선택해도 `validate -> dryrun -> 사용자 승인 -> local apply -> postcheck` 전에는 확정 반영하지 않는다.
- `productNo`와 `optionNo`를 혼동하지 않는다.
- `own_sku` 단독 자동확정은 금지한다.

## 4. Smartstore 확인 포인트

- `confirmed_product_no`
- `confirmed_option_no`
- `candidate_product_no`
- `candidate_option_no`
- `productNo`와 `optionNo` 분리 유지
- `smartstore_product_no_candidate`와 `smartstore_option_no_candidate`는 확정값이 아님

Smartstore는 상품 단위 `productNo`와 옵션/SKU 단위 `optionNo`가 서로 다른 의미를 가진다. 수동검수 CSV에서도 확정값과 후보값을 분리하고, product/option 단위도 분리해야 한다.

## 5. MakeShop 확인 포인트

- `source_row_ref = source_file:row_no` 형태의 추적성 필요
- `candidate_rank`
- `candidate_score`
- `match_rule_before`
- `own_sku`
- option token
- 원본 상품명/옵션명 보존 필요
- `review_required`, `ambiguous`, `manual` 대상 자동 apply 금지

MakeShop은 이미 자동 매칭 가능한 일부만 별도 절차로 처리된 상태다. 잔여 검수 대상은 원본 row 추적성과 후보 점수, 후보 순위, 기존 매칭 규칙을 보존해야 하며, 검수 없이 확정 mapping처럼 취급하지 않는다.

## 6. Ably 확인 포인트

- 상품 번호와 옵션 번호 분리
- `option_no` 고유성 재확인 필요
- 판매자 상품코드, 솔루션사 고유코드, 옵션명 bracket code는 후보로만 취급
- 공식 업로드 템플릿 확보 전 export 확정 금지

Ably는 현재 분석 파일 기준으로 상품 번호와 옵션 번호가 분리되어 있다. 특히 옵션 번호가 SKU 단위 key 후보가 될 수 있지만, 공식 업로드 템플릿과 고유성 재확인 전에는 확정 export source로 쓰지 않는다.

## 7. PlayAuto 확인 포인트

- PlayAuto는 단일 판매처가 아니라 판매처 허브로 취급
- 플레이오토 내부 코드와 실제 판매처 코드를 분리
- 쇼핑몰(계정), 쇼핑몰 상품번호, SKU, 옵션, 가격, 수량, 상태 컬럼 구조 확인
- multi-line 옵션/SKU/가격/수량/상태 line alignment 검증 필요

PlayAuto는 여러 판매처를 묶는 허브 성격이 강하다. 따라서 PlayAuto 내부 관리 코드와 Smartstore, Ably, Coupang 등 실제 판매처별 상품/옵션 코드를 같은 값처럼 취급하지 않는다. multi-line 셀을 SKU 단위로 펼칠 때 옵션명, SKU, 가격, 수량, 상태의 줄 수와 순서가 맞는지도 별도 검증이 필요하다.

## 8. precheck SQL이 확인해야 할 것

- 필요한 테이블 존재 여부
- 필요한 컬럼 존재 여부
- `code_alias`의 `code_system` 분포 확인 가능성
- candidate/confirmed `code_system` 분리 가능성
- `product_image` 존재 여부 확인 가능성
- sku/channel/export 관련 컬럼 존재 여부 확인 가능성
- 수동검수 CSV 컬럼을 만들 수 있는 최소 기반 존재 여부

이번 precheck는 구조 확인용이므로 row export나 CSV 생성은 하지 않는다. 테이블이나 컬럼이 없으면 실제 export 초안을 쓰기 전에 어떤 전제가 부족한지 먼저 표시한다.

## 9. 다음 단계

1. 사용자가 승인한 실행 세션에서 `sql/precheck_manual_review_export_v1.sql`을 local read-only로 실행한다.
2. 결과를 보고 실제 SELECT export 초안을 작성한다.
3. 그 다음 reviewed CSV validate SQL을 설계한다.

이번 문서와 precheck SQL은 실제 수동검수 CSV 생성 전 단계까지만 다룬다.
