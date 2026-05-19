# Option Normalization Dictionary Plan v1

## 1. 목적

옵션명 정규화/동의어 사전은 Smartstore, MakeShop, Ably 수동검수 후보 중에서 단순 표현 차이 때문에 매칭되지 않는 건을 줄이기 위한 진단용 설계다.

악세사리/피어싱 상품은 같은 SKU라도 판매처마다 옵션명을 다르게 표기하는 경우가 많다. 예를 들어 `핑크골드`, `로즈골드`, `rose gold`, `RG`는 같은 색상 계열일 수 있지만 문자열 exact match만으로는 다른 옵션처럼 보인다. 이런 표현 차이를 비교 전처리에서 정규화하면 자동매칭 후보의 evidence를 강화할 수 있다.

이번 단계는 확정 반영이 아니다. 원본 `option_value`는 보존하고, 진단 SQL에서만 `normalized_option_value`를 별도로 만들어 정규화 전후 영향도를 측정한다. 결과는 auto-confirm이 아니라 auto-confirm-ready 후보 선별과 수동검수 우선순위 조정에만 사용한다.

## 2. 정규화 대상

- 색상: 판매처별 한글/영문/약어 표기 차이
- 소재: 색상처럼 보이지만 실제로는 재질 또는 함량인 값
- 사이즈: 영문 약어, 한글 표기, mm 표기 차이
- 수량/세트: 낱개, 한쌍, 세트, 단일옵션 표기 차이
- 형태/타입: 하트, 플라워, 스타 등 형태명 표기 차이

## 3. 1차 동의어 사전 초안

### 색상

| normalization_rule | terms |
| --- | --- |
| rose_gold | 핑크골드, 로즈골드, rose gold, RG |
| yellow_gold | 옐로우골드, 골드, yellow gold, YG |
| silver | 실버, 은색, silver, SV |
| black | 블랙, 검정, black, BK |
| white | 화이트, 흰색, white, WH |
| clear | 투명, 클리어, clear |
| crystal | 크리스탈, crystal |
| crystal_ab | 크리스탈AB, crystal AB, AB, 오로라, aurora |
| purple | 바이올렛, 퍼플, 보라, purple |
| red | 레드, 빨강, red |
| blue | 블루, 파랑, blue |
| green | 그린, 초록, green |
| ivory | 아이보리, ivory |
| brown | 브라운, brown |

`크리스탈`과 `크리스탈AB`는 서로 다른 컬러다. `크리스탈AB`, `crystal AB`, `AB`, `오로라`, `aurora`는 `crystal_ab`로 분리하고, `크리스탈` 또는 `crystal`만 있는 값은 `crystal`로 둔다. `크리스탈AB`를 `크리스탈`로 자동 정규화하지 않는다.

`AB`는 짧은 문자열이라 임의 포함 매칭을 쓰면 오탐 위험이 높다. `AB`는 공백, 슬래시, 괄호, 하이픈 등으로 분리된 독립 토큰일 때만 `crystal_ab` 후보로 본다.

### 소재

| normalization_rule | terms |
| --- | --- |
| surgical | 써지컬, 써지컬스틸, surgical, steel |
| 925_silver | 925실버, 실버925, sterling silver |
| 14k | 14K, 14k골드, gold 14k |
| acrylic | 아크릴, acrylic |
| mother_of_pearl | 자개, mother of pearl, mop |

`14K`, `써지컬`, `925실버`는 색상이 아니라 소재 또는 함량으로 분리한다. 특히 `925실버`는 색상 `silver`와 의미가 다를 수 있으므로 자동확정 근거로 섞지 않는다.

### 사이즈

| normalization_rule | terms |
| --- | --- |
| xs | XS, 엑스스몰, extra small |
| small | S, 스몰, small |
| medium | M, 미디움, medium |
| large | L, 라지, large |
| xl | XL, 엑스라지, extra large |
| 6mm | 6mm바, 6mm |
| 8mm | 8mm바, 8mm |

`S`, `M`, `L` 같은 한 글자 약어도 오탐 가능성이 있으므로 독립 토큰 또는 전체 옵션값이 해당 값일 때만 적용한다.

### 수량/세트

| normalization_rule | terms |
| --- | --- |
| one_type | 원타입, 단일옵션, one size |
| single | 낱개, 1개, single |
| pair | 한쌍, 2개, pair |
| set | 세트, set |

### 형태/타입

| normalization_rule | terms |
| --- | --- |
| heart | 하트, heart |
| flower | 플라워, 꽃, flower |
| star | 스타, 별, star |
| butterfly | 나비, butterfly |
| cross | 크로스, 십자가, cross |

## 4. 주의 규칙

- 화이트골드와 실버는 무조건 동일 처리하지 않는다.
- `14K`, `써지컬`, `925실버`는 색상이 아니라 소재로 분리한다.
- 상품명 유사도만으로 자동확정하지 않는다.
- 색상만 같다고 같은 SKU로 확정하지 않는다.
- 사이즈, 수량, 소재가 다르면 자동확정하지 않는다.
- 판매처 내부 코드와 실제 판매처 상품/옵션 코드를 혼동하지 않는다.
- 정규화 결과는 원본 옵션명을 대체하지 않는다.

## 5. 진단 방식

1. Smartstore, MakeShop, Ably 수동검수 후보를 읽기 전용으로 모은다.
2. 원본 `option_value`와 판매처 옵션명 후보를 각각 보존한다.
3. 정규화 전 exact match 여부를 계산한다.
4. 정규화 후 normalized option match 여부를 계산한다.
5. 정규화로 새로 매칭 가능해진 행을 `normalized_option_match_candidate`로 집계한다.
6. 같은 정규화 값에 여러 SKU 또는 여러 판매처 옵션 코드가 묶이면 `normalized_option_conflict_or_ambiguous`로 분리한다.
7. 정규화 후에도 증거가 부족한 건은 `manual_review_still_required`로 남긴다.

## 6. auto-confirm-ready 후보 기준

정규화 사전은 auto-confirm 자체가 아니라 auto-confirm-ready 후보 선별용이다. 최소 기준은 아래와 같다.

- 정규화 후 옵션명이 같음
- SKU 기준 후보가 1개뿐임
- 판매처 상품코드 + 옵션코드 조합이 중복되지 않음
- 기존 확정 코드와 충돌하지 않음
- `own_sku` 또는 `selfpia_sku` 근거가 있음
- 색상 외에 사이즈, 수량, 소재 구조가 충돌하지 않음

## 7. 다음 단계

1. SELECT-only 진단 SQL 정적 검토
2. 이후 별도 승인 시 local DB read-only 실행
3. source_channel별 영향도 확인
4. normalization_category별 영향도 확인
5. normalization_rule별 영향도 확인
6. crystal/crystal_ab safety count 확인
7. AB 오탐 가능 row count 확인
8. 영향도가 충분할 때만 별도 dictionary table 또는 전처리 CTE 반영 검토
