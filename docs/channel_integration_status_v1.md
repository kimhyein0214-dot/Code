# Channel Integration Status v1

## 1. 목적

이 문서는 스마트스토어, 메이크샵, 에이블리, 플레이오토, 쿠팡의 코드매칭/자료분석/export 준비 상태를 한눈에 보기 위한 현황판이다.

목표는 대표님 보고와 다음 작업 우선순위 판단에 사용할 수 있도록, 판매처별로 어디까지 정리되었고 무엇이 아직 막혀 있는지 분리해서 보는 것이다.

이번 문서는 상태 정리용이다. SQL 실행, DB 접속, DB 변경, local apply, export 파일 생성은 하지 않는다.

## 2. 판매처별 상태 요약표

| channel | current_status | matching_status | data_source_status | export_readiness | next_action | risk_note |
|---|---|---|---|---|---|---|
| Smartstore | optionNo/productNo local 정리 완료 | confirmed/candidate 분리 완료 | stage/dryrun/apply/postcheck 계열 SQL 이력 존재. 보류 SQL은 실행 금지 상태로 분류됨 | 중간. 확정 코드만 export source로 사용 가능하도록 규칙은 정리됨 | 후보/미매핑 수동검수 CSV 설계 및 reviewed CSV validate 설계 | productNo와 optionNo 혼동 금지. candidate code export 금지 |
| MakeShop | auto_confirm 및 weak_top1 strong_candidate local 반영 완료 | 자동 연결 가능분은 상당수 반영, 잔여 review_required/ambiguous/manual 존재 | MakeShop 후보/export/dryrun/apply/postcheck 계열 SQL과 수동검수 설계 문서 존재 | 중간. 확정 mapping은 활용 가능하나 잔여 검수 필요 | 수동검수 CSV 생성 구조와 reviewed CSV validate 설계 | ambiguous/weak 후보를 자동확정처럼 쓰면 위험 |
| Ably | 자료 구조 분석 완료, 업로드 템플릿 체크리스트 작성 완료 | 상품 번호/옵션 번호와 seller code 후보 파악 | `에이블리 ALL.csv` 확인 완료. 9,158 rows / 29 columns | 초기. 공식 업로드 템플릿 확보 전까지 export 필드 확정 불가 | 공식 업로드 템플릿 확보 후 컬럼 비교 | 옵션 번호는 고유하나 seller code 단독 확정 금지 |
| PlayAuto | 원본 XLSX 분석 완료 | PlayAuto SKU/판매자관리코드/쇼핑몰 상품번호 후보 파악 | `플레이오토_일반_ALL판매처...xlsx` 확인 완료. 핵심 `쇼핑몰상품` 4,219 rows / 95 columns, `SKU상품` 17,968 rows | 초기~중간. 허브 구조 이해는 시작됐지만 공식 템플릿과 multi-line 옵션 검증 필요 | 공식 업로드 템플릿 확보, multi-line 옵션 구조 확인 | PlayAuto 내부 코드와 실제 판매처 코드를 혼동하면 위험 |
| Coupang | 보류 | 미진행 | 원본/공식 템플릿 분석 미진행 | 낮음 | 공식 템플릿/원본 자료 확보 후 별도 분석 | `vendorItemId`, `itemId`, `sellerProductId` 등 ID 체계가 복잡할 가능성 높음 |

## 3. 판매처별 상세

### Smartstore

현재 상태:

- optionNo/productNo local 정리 완료.
- confirmed/candidate 분리 완료.
- productNo 관련 cleanup까지 완료된 것으로 기록되어 있다.
- 관련 보류 SQL은 `docs/pending_sql_inventory_v1.md`에서 실행 금지 또는 보존/검토 대상으로 분류했다.

매칭/export 기준:

- confirmed `smartstore_product_no`, `smartstore_option_no`만 export source 후보가 된다.
- `smartstore_product_no_candidate`, `smartstore_option_no_candidate`는 export 금지다.
- productNo는 상품 단위, optionNo는 옵션/SKU 단위로 분리해야 한다.

다음 단계:

- 후보/미매핑 수동검수 CSV 실제 생성 구조 설계.
- reviewed CSV validate SQL 설계.
- 수동검수 결과를 confirmed code로 반영하는 dryrun/apply/postcheck는 별도 승인 후 진행.

주의:

- productNo와 optionNo를 하나의 code value처럼 섞으면 안 된다.
- candidate code를 export에 사용하면 운영 업로드 오류로 이어질 수 있다.

### MakeShop

현재 상태:

- auto_confirm v3 local 반영 완료 기록이 있다.
- weak_top1 strong_candidate local 반영 완료 기록이 있다.
- 자동 연결 가능분은 상당수 반영된 상태로 본다.
- 아직 review_required, ambiguous, manual 대상이 남아 있다.

매칭/export 기준:

- 확정된 MakeShop mapping만 export source 후보가 된다.
- ambiguous, weak, review_required 후보는 수동검수 전 export 금지다.
- own_sku 기반 자동 후보는 유용하지만, own_sku가 여러 SKU에 걸칠 수 있어 검수 흐름이 필요하다.

다음 단계:

- MakeShop 잔여 후보를 수동검수 CSV 구조에 실어 검토 가능하게 만든다.
- reviewed CSV validate 설계를 만든다.
- confirm/reject/hold 결과를 이후 자동매칭률 개선용 기준 데이터로 재사용한다.

주의:

- weak_top1이나 ambiguous 후보를 확정 mapping처럼 쓰면 안 된다.
- 이미 local 반영된 apply SQL은 재실행하지 않는다.

### Ably

현재 상태:

- `에이블리 ALL.csv` 분석 완료.
- 9,158 rows / 29 columns.
- `상품 번호`는 상품 단위 식별 후보.
- `옵션 번호`는 옵션/SKU 단위 식별 후보이며 전체 row에서 고유했다.
- 가격 컬럼, 재고수량, 안전재고, 품절상태, 진열상태 컬럼을 확인했다.
- `판매자 상품코드`, `솔루션사 고유코드`, 옵션명 bracket code는 `selfpia_sku` 또는 `own_sku` 매칭 후보로 정리했다.
- 공식 업로드 템플릿 비교용 체크리스트를 작성했다.

매칭/export 기준:

- 확정된 `ably_product_no`, `ably_option_no`만 export source 후보가 된다.
- `ably_product_no_candidate`, `ably_option_no_candidate`, `ably_seller_code_candidate`는 export 금지다.
- 상품명/옵션명은 자동매칭 보조 evidence로만 사용한다.

다음 단계:

- 에이블리 공식 업로드 템플릿 확보.
- 현재 `에이블리 ALL.csv`와 공식 템플릿 컬럼 비교.
- 가격/재고/품절/진열상태의 필수/선택/수정 가능 여부 확인.
- Ably 후보/미매칭을 수동검수 CSV 구조에 반영.

주의:

- 상품 번호와 옵션 번호를 혼동하면 안 된다.
- seller code 또는 이름 유사도 단독 자동확정은 위험하다.
- 공식 템플릿 확인 전에는 export readiness를 확정할 수 없다.

### PlayAuto

현재 상태:

- 플레이오토 원본 XLSX 분석 완료.
- 핵심 시트 `쇼핑몰상품`: 4,219 rows / 95 columns.
- `SKU상품` 시트: 17,968 SKU 코드 기준표.
- `쇼핑몰상품`에는 `판매자관리코드`, `쇼핑몰(계정)`, `쇼핑몰 상품번호`, `온라인 상품명`, 가격, 옵션, SKU, 옵션별 수량/상태, 이미지/배송/고시 정보가 포함된다.
- 플레이오토는 단일 판매처라기보다 여러 판매처를 묶는 허브로 봐야 한다.

매칭/export 기준:

- `판매자관리코드`는 PlayAuto/seller code 후보.
- `쇼핑몰 상품번호`는 판매처별 channel product code 후보.
- `SKU` 및 `SKU상품.SKU코드`는 `own_sku` 또는 `selfpia_sku` 연결 후보.
- `쇼핑몰(계정)`은 실제 판매처 및 계정 분기 기준이다.

다음 단계:

- 플레이오토 공식 업로드 템플릿 확보.
- PlayAuto 내부 코드와 실제 판매처 코드 관계 확인.
- multi-line 옵션/SKU/가격/수량/상태 column의 line alignment 검증.
- 수동검수 CSV에 `channel=playauto`, `marketplace_name` 축 반영.

주의:

- PlayAuto 내부 코드와 스마트스토어/에이블리/쿠팡 등 실제 판매처 코드를 혼동하면 안 된다.
- multi-line 옵션 구조를 잘못 펼치면 잘못된 SKU에 가격/재고가 붙을 수 있다.
- PlayAuto를 통해 판매처별 export를 만들 경우, hub code와 marketplace code를 모두 추적해야 한다.

### Coupang

현재 상태:

- 급하지 않아 보류.
- 자료 구조 분석은 아직 미진행.
- 공식 템플릿 또는 원본 자료가 아직 분석되지 않았다.

예상 이슈:

- `vendorItemId`, `itemId`, `sellerProductId` 등 ID 체계가 복잡할 가능성이 높다.
- 상품 단위, 옵션 단위, vendor item 단위가 섞일 수 있다.
- 가격/재고 수정 기준키가 다른 판매처보다 엄격할 수 있다.

다음 단계:

- 쿠팡 공식 업로드 템플릿 또는 현재 상품 다운로드 자료 확보.
- 상품/옵션/vendor item ID 체계 분리.
- 쿠팡 전용 channel code 후보와 export blocker rule 정리.

주의:

- 쿠팡은 ID 체계 확인 전까지 자동매칭이나 export 설계를 시작하지 않는 편이 안전하다.

## 4. 최종 목표 정리

최종 목표는 상품 페이지에서 가격, 재고, 판매상태를 관리하고, 판매처별 업로드 파일을 안정적으로 생성하는 것이다.

기본 원칙:

- 내부 기준은 `sku_id`다.
- 판매처별 상품/옵션 코드는 확정 코드와 후보 코드를 분리한다.
- 확정된 코드만 export에 사용한다.
- 후보/미검수 코드는 export에서 차단한다.
- 가격/재고/판매상태 검수는 코드매칭 검수와 분리하되 `sku_id` 기준으로 연결한다.
- 사람이 검수한 결과는 이후 자동매칭률 개선용 기준 데이터로 재사용한다.

## 5. 현재 남은 큰 단계

1. 후보/미매칭 수동검수 CSV 실제 생성 구조 설계.
2. reviewed CSV validate SQL 설계.
3. 판매처별 공식 업로드 템플릿 확보.
4. 가격/재고/판매상태 관리 화면 설계.
5. 판매처별 export 생성 기능 설계 및 구현.
6. 쿠팡 자료 구조 분석.
7. 각 단계별 dryrun/apply/postcheck 절차 분리.

## 6. 대표님 보고용 짧은 요약

현재 스마트스토어와 메이크샵은 코드 매칭 작업이 가장 많이 진행되어 있고, 확정 코드와 후보 코드를 분리하는 기준도 잡혀 있습니다. 에이블리는 현재 보유한 전체 CSV를 분석해 상품번호와 옵션번호 구조, 가격/재고/상태 컬럼을 확인했습니다. 플레이오토는 여러 판매처를 묶는 허브 성격이 강해서, 플레이오토 내부 코드와 실제 판매처 코드를 분리해서 봐야 합니다. 쿠팡은 아직 급하지 않아 보류 중이며, 자료와 공식 템플릿을 확보한 뒤 별도 분석이 필요합니다. 최종 목표는 상품 페이지에서 가격/재고/판매상태를 관리하고, 검수된 확정 코드만 사용해 판매처별 업로드 파일을 만드는 것입니다. 후보나 미검수 코드는 업로드에 사용하지 않도록 차단할 예정입니다. 다음 우선순위는 수동검수 CSV 구조와 판매처별 공식 업로드 템플릿 확보입니다.
