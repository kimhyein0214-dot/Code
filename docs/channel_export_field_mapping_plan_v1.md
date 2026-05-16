# Channel Export Field Mapping Plan v1

작성일: 2026-05-16

## 1. 목적

이 문서는 스마트스토어, 메이크샵, 에이블리, 플레이오토의 업로드 양식을 향후 내부 상품/가격/재고 데이터와 어떻게 매핑할지 정리하는 설계 문서다.

이 작업은 `docs/price_inventory_export_design_v1.md` 다음 단계다. 앞선 문서에서 가격, 재고, export 기능을 별도 확장 구조로 두는 방향을 정했으므로, 이번 문서에서는 실제 판매처별 업로드 양식을 받기 전에 어떤 필드를 공통 기준으로 보고 어떤 판매처별 차이를 확인해야 하는지 정리한다.

판매처별 필드 매핑표가 필요한 이유는 다음과 같다.

- 같은 SKU라도 판매처마다 상품코드, 옵션코드, 가격, 재고 필드명이 다르다.
- 어떤 판매처는 CSV를 쓰고, 어떤 판매처는 XLSX 지정 양식을 요구할 수 있다.
- 필수값, 선택값, 기본값, 변환 규칙이 판매처마다 다르다.
- 후보 코드를 확정 코드처럼 export하면 운영 사고로 이어질 수 있다.
- 실제 export 기능을 만들기 전에 어떤 내부 데이터가 어떤 판매처 필드로 나가야 하는지 문서로 합의해야 한다.

이번 작업은 DB 변경 없이 문서 설계만 진행하는 안전 작업이다. SQL 실행, DB 반영, API/Frontend 코드 수정, CSV/XLSX 생성 기능 구현은 하지 않는다.

## 2. 현재 기준 구조

현재 내부 기준은 VSKU/SKU다. 상품 단위 정보는 `product_master`, SKU/옵션 단위 정보는 `sku_master`를 기준으로 보고, 실제 화면/API에서는 canonical SKU 조회 결과와 alias/channel mapping을 함께 사용한다.

판매처 코드는 다음 두 구조로 연결한다.

| 구조 | 역할 |
|---|---|
| `code_alias` | 셀피아 SKU, 셀피아 상품코드, 자사코드, 스마트스토어 옵션번호, 스마트스토어 후보 코드 등 여러 코드 체계를 내부 상품/SKU와 연결한다. |
| `sku_channel_mapping` | 메이크샵, 스마트스토어 등 판매처별 확정 상품코드와 옵션/SKU 코드를 내부 SKU에 연결한다. |

유지해야 할 원칙은 다음과 같다.

- 내부 export 기준은 VSKU/SKU다.
- 셀피아 SKU는 내부 운영에서 사람이 확인하는 canonical text code로 유지한다.
- 판매처 상품코드와 판매처 옵션코드는 `code_alias` 또는 `sku_channel_mapping`에서 찾는다.
- 후보 코드와 확정 코드는 분리한다.
- export에는 확정된 판매처 코드만 사용하는 방향을 기본으로 한다.
- 후보 코드는 export 제외 또는 preview 경고 대상으로만 다룬다.
- 가격/재고는 내부 기준 값과 판매처별 값이 다를 수 있으므로 분리해서 조회한다.

## 3. 판매처별 Export 대상

아래 내용은 실제 양식 파일 확보 전의 초안이다. 각 판매처의 최신 업로드 양식과 필수 필드 설명서를 받은 뒤 확정해야 한다.

### 스마트스토어

| 항목 | 내용 |
|---|---|
| 예상 업로드 파일 형식 | CSV 또는 XLSX. 실제 스마트스토어 상품 일괄 수정/업로드 양식 확인 필요. |
| 주요 필드 후보 | 스마트스토어 상품번호, 옵션번호, 판매자 관리코드, 상품명, 옵션명, 판매가, 옵션가, 재고수량, 판매상태, 이미지 URL, 카테고리, 배송비/배송정보, 고시정보, 상세설명 |
| 내부 데이터 출처 후보 | `sku_master`, `product_master`, `code_alias`, `sku_channel_mapping`, `sku_price`, `sku_channel_price`, `sku_inventory`, `sku_channel_inventory`, `product_image` |
| 필수/선택 여부 판단 필요 항목 | 상품번호/옵션번호 필수 여부, 옵션가 필수 여부, 재고수량 필수 여부, 판매상태 값 체계, 이미지와 상세설명의 수정 가능 여부 |
| 주의점 | `smartstore_option_no_candidate` 같은 후보 코드는 확정 옵션번호처럼 export하지 않는다. 확정 스마트스토어 상품/옵션 번호가 없는 SKU는 export 대상 제외 또는 검수 필요 상태로 처리한다. |

### 메이크샵

| 항목 | 내용 |
|---|---|
| 예상 업로드 파일 형식 | CSV 또는 XLSX. 기존 MakeShop 상품/옵션 업로드 및 수정 양식 확인 필요. |
| 주요 필드 후보 | 메이크샵 상품 UID, 옵션 ID 또는 `sto_id`, 옵션 코드 또는 `sto_code`, 상품명, 옵션명, 판매가, 옵션가, 재고수량, 판매상태, 진열상태, 이미지 URL, 자체 상품코드 |
| 내부 데이터 출처 후보 | `sku_master`, `product_master`, `code_alias`, `sku_channel_mapping`, `sku_price`, `sku_channel_price`, `sku_inventory`, `sku_channel_inventory`, `product_image` |
| 필수/선택 여부 판단 필요 항목 | 상품 UID 필수 여부, 옵션 ID 필수 여부, 옵션 코드 수정 가능 여부, 재고/가격 수정 양식의 키 필드, 상품 단위 row와 옵션 단위 row 구분 방식 |
| 주의점 | MakeShop은 상품 UID와 옵션 구조 확인이 중요하다. 기존 review workflow에서 나온 후보/ambiguous 코드는 자동 확정하지 않고, 확정된 `sku_channel_mapping` 중심으로 export 대상을 잡는다. |

### 에이블리

| 항목 | 내용 |
|---|---|
| 예상 업로드 파일 형식 | CSV 또는 XLSX. 에이블리 셀러 상품 등록/수정 양식 확보 필요. |
| 주요 필드 후보 | 에이블리 상품코드, 옵션코드, 상품명, 옵션명, 판매가, 옵션가, 재고수량, 판매상태, 카테고리, 대표 이미지, 추가 이미지, 배송/반품 정보, 고시정보 |
| 내부 데이터 출처 후보 | `sku_master`, `product_master`, `code_alias`, `sku_channel_mapping`, `sku_price`, `sku_channel_price`, `sku_inventory`, `sku_channel_inventory`, `product_image` |
| 필수/선택 여부 판단 필요 항목 | 에이블리 상품/옵션 코드 체계, 옵션가 처리 방식, 이미지 필수 조건, 카테고리 필수 여부, 배송/반품 필드 구조 |
| 주의점 | 아직 내부에 확정된 에이블리 코드 매핑 정책이 없을 수 있으므로, 실제 양식과 현재 운영 샘플을 먼저 확보해야 한다. 확정 코드가 없으면 필드 매핑표에서 `검수 필요`로 분류한다. |

### 플레이오토

| 항목 | 내용 |
|---|---|
| 예상 업로드 파일 형식 | CSV 또는 XLSX. 플레이오토 통합 업로드 양식 및 판매처별 템플릿 확인 필요. |
| 주요 필드 후보 | 플레이오토 관리 상품코드, 원 판매처 상품코드, 원 판매처 옵션코드, 상품명, 옵션명, 판매가, 재고수량, 판매처 구분, 카테고리, 배송정보, 이미지 URL |
| 내부 데이터 출처 후보 | `sku_master`, `product_master`, `code_alias`, `sku_channel_mapping`, `sku_price`, `sku_channel_price`, `sku_inventory`, `sku_channel_inventory`, `product_image` |
| 필수/선택 여부 판단 필요 항목 | 플레이오토 자체 관리코드와 원 판매처 코드의 관계, 판매처별 template 선택 방식, 가격/재고를 플레이오토 기준으로 넣는지 원 판매처 기준으로 넣는지 |
| 주의점 | 플레이오토는 여러 판매처 통합 업로드 허브로 볼 가능성이 있다. 단일 판매처 template처럼 보지 말고, 플레이오토 자체 필드와 하위 판매처 필드를 분리해서 확인해야 한다. |

## 4. 공통 필드 매핑 초안

아래 표는 실제 양식 파일 확보 전의 공통 매핑 초안이다. 판매처별 정확한 컬럼명, 필수 여부, 값 형식은 이후 별도 matrix 문서에서 확정한다.

| 공통 항목 | 내부 기준 필드 | 참조 테이블 후보 | 판매처별 변환 필요 여부 | 비고 |
|---|---|---|---|---|
| 내부 SKU / VSKU | `sku_id`, `virtual_sku_code` | `sku_master`, canonical SKU view | 필요 | 내부 기준 key. 판매처 업로드에는 직접 노출하지 않거나 관리코드로 변환할 수 있다. |
| 셀피아 SKU | `selfpia_sku_code` | `code_alias`, canonical SKU view | 필요 가능 | 내부 검수용 기준 코드. 판매처별 관리코드로 쓰는지 확인 필요. |
| 판매처 상품코드 | `seller_product_code`, channel product code | `sku_channel_mapping`, `code_alias` | 필요 | 스마트스토어 상품번호, MakeShop 상품 UID 등 판매처별 이름과 형식이 다르다. |
| 판매처 옵션코드 | `channel_sku_code`, option code | `sku_channel_mapping`, `code_alias` | 필요 | 스마트스토어 옵션번호, MakeShop `sto_id` 등. 후보 코드는 export 제외 원칙. |
| 상품명 | `product_name` | `product_master`, canonical SKU view | 필요 가능 | 판매처별 글자수, 금지어, 접두/접미 규칙 확인 필요. |
| 옵션명 | `option_value` | `sku_master`, canonical SKU view | 필요 | 옵션 조합 형식, 옵션명 구분자, 빈 옵션 처리 규칙 확인 필요. |
| 매입가 | purchase price 후보 | `sku_price` | 보통 미노출 | 내부 마진/검수용. 판매처 업로드 필드로 직접 나가는지 확인 필요. |
| 기본 판매가 | base sale price 후보 | `sku_price` | 필요 가능 | 판매처별 판매가 fallback으로 사용할 수 있다. |
| 판매처별 판매가 | channel sale price 후보 | `sku_channel_price` | 필요 | 판매처 업로드 가격의 우선 출처. 판매처 수수료/정책에 따라 다를 수 있다. |
| 옵션가 | option price 후보 | `sku_price`, `sku_channel_price` | 필요 | 기본 판매가 대비 추가/차감인지, 최종 옵션 판매가인지 판매처별 확인 필요. |
| 실제 재고 | actual stock 후보 | `sku_inventory` | 필요 가능 | 내부 재고 기준. 판매처에 그대로 내보내지 않고 노출재고 산출 기준으로 사용한다. |
| 판매처 노출재고 | channel visible stock 후보 | `sku_channel_inventory` | 필요 | 판매처 업로드 재고의 우선 출처. 안전재고 반영 여부가 중요하다. |
| 품절 여부 | sold-out flag 후보 | `sku_inventory`, `sku_channel_inventory` | 필요 | 판매처별 판매상태/품절상태 코드로 변환해야 할 수 있다. |
| 이미지 URL 또는 이미지 참조 | `image_url`, `thumbnail_url` | `product_image` | 필요 | 대표 이미지/추가 이미지 구분, URL 허용 여부, 파일 업로드 방식 확인 필요. |
| 카테고리 | category code/name 후보 | future category mapping | 필요 | 현재 별도 category mapping 후보가 필요하다. 판매처별 카테고리 코드가 다를 수 있다. |
| 배송 관련 필드 | shipping policy 후보 | future channel policy mapping | 필요 | 배송비, 배송방법, 반품지, 제주/도서산간 정책 등 판매처별 차이가 크다. |
| 고시정보 / 상세설명 등 추후 확장 필드 | notice/detail fields 후보 | future product content mapping | 필요 | 상품군별 고시정보, 상세설명 HTML, 인증정보 등은 별도 확장 대상으로 본다. |

## 5. 판매처별 차이점

판매처별 차이는 실제 양식 파일을 확보해야 확정할 수 있다. 현재 단계의 판단은 초안이다.

- 스마트스토어는 스마트스토어 상품번호와 옵션번호 기준이 필요할 가능성이 높다. 후보 옵션번호와 확정 옵션번호를 반드시 구분해야 한다.
- 메이크샵은 상품 UID와 옵션 ID 또는 옵션 코드 구조 확인이 필요하다. 상품 단위 row와 옵션 단위 row가 섞이는 양식이면 export 전처리 규칙이 필요하다.
- 에이블리는 별도 상품/옵션/가격 양식 확인이 필요하다. 현재 내부 코드 연결이 충분하지 않으면 매핑 후보 수집 단계가 먼저 필요하다.
- 플레이오토는 여러 판매처 통합 업로드 허브로 볼 가능성이 있다. 플레이오토 자체 관리코드와 원 판매처 코드를 분리해서 봐야 한다.
- 실제 양식 파일 확보 전에는 판매처별 필드명, 필수값, 허용값, 파일 형식, 인코딩, 업로드 키를 확정하지 않는다.

## 6. 추천 문서/데이터 구조

이번 문서 `docs/channel_export_field_mapping_plan_v1.md`는 설계 문서다. 실제 판매처 양식 파일을 확보한 뒤에는 더 구체적인 매핑표 문서를 별도로 만드는 것이 좋다.

추천 후속 문서 후보는 다음과 같다.

| 문서 후보 | 목적 |
|---|---|
| `docs/channel_export_field_mapping_matrix_v1.md` | 판매처별 실제 컬럼명, 내부 출처, 필수 여부, 변환 규칙을 표로 확정한다. |
| `docs/channel_export_template_collection_log.md` | 어떤 판매처 양식을 언제, 어디서, 어떤 버전으로 확보했는지 기록한다. |
| `docs/channel_export_validation_rules_v1.md` | export 전 필수값 누락, 후보 코드 포함, 가격/재고 이상값 검증 규칙을 정리한다. |

추후 샘플 양식은 `exports/templates` 또는 `docs/templates` 같은 위치에 둘 수 있다. 다만 이번 작업에서는 어떤 template 파일도 생성하지 않는다. 실제 파일 보관 위치는 양식 파일을 받은 뒤, git 추적 여부와 민감정보 포함 여부를 먼저 판단해야 한다.

## 7. Export 처리 흐름 보강

판매처별 필드 매핑 관점에서 export 흐름은 다음과 같이 본다.

1. VSKU/SKU 선택
2. 판매처 코드 조회
3. 가격/재고 조회
4. 판매처별 필드 매핑 적용
5. 판매처별 값 변환
6. CSV/XLSX 생성
7. export 이력 저장

| 단계 | 필드 매핑 관점의 확인 사항 |
|---|---|
| VSKU/SKU 선택 | 내부 기준 SKU가 명확해야 한다. `sku_id`, 셀피아 SKU, VSKU, 상품명, 옵션명으로 대상을 확인한다. |
| 판매처 코드 조회 | 판매처 상품코드와 옵션코드가 확정값인지 확인한다. 후보 alias만 있는 경우 export 대상에서 제외하거나 preview 경고로 표시한다. |
| 가격/재고 조회 | 내부 기본 가격/재고와 판매처별 판매가/노출재고를 구분한다. 판매처별 값이 없을 때 fallback을 허용할지 정책이 필요하다. |
| 판매처별 필드 매핑 적용 | 판매처 template의 컬럼 순서, 필수값, 내부 출처, 기본값, 변환 규칙을 적용한다. |
| 판매처별 값 변환 | 품절 여부, 판매상태, 옵션가, 재고수량, 이미지 URL, 카테고리 코드를 판매처 허용값으로 바꾼다. |
| CSV/XLSX 생성 | 이 단계는 향후 구현 범위다. 이번 문서에서는 파일 생성 기능을 만들지 않는다. |
| export 이력 저장 | 어떤 template 버전과 SKU 조건으로 생성했는지 남긴다. 이번 문서에서는 DB 구조나 저장 기능을 만들지 않는다. |

## 8. 프론트 화면 확장 관점

향후 프론트는 현재 read-only 검수 원칙을 유지하면서 다음 화면으로 확장할 수 있다.

| 화면 후보 | 목적 | 초기 범위 |
|---|---|---|
| 판매처별 필드 매핑 관리 | 판매처별 업로드 컬럼과 내부 데이터 출처를 확인한다. | read-only 또는 draft preview |
| 판매처별 export 미리보기 | 실제 파일 생성 전에 SKU별 export row를 화면에서 검수한다. | read-only preview |
| export 대상 SKU 선택 | 판매처, 상품군, SKU 상태, 가격/재고 준비 여부로 export 대상을 고른다. | 조회/필터 중심 |
| 판매처별 가격/재고 검수 | 판매처별 판매가와 노출재고 누락/이상값을 확인한다. | read-only 검수 |
| export 이력 조회 | 생성 파일, 건수, 오류, template 버전을 확인한다. | read-only 이력 |

이번 작업에서는 프론트 코드를 수정하지 않는다. 화면 확장안은 후속 구현 범위의 참고 설계다.

## 9. 지금 필요한 실제 자료 목록

정확한 매핑표를 만들기 위해 앞으로 받아야 할 자료는 다음과 같다.

- 스마트스토어 상품 업로드/수정 양식
- 메이크샵 상품 업로드/수정 양식
- 에이블리 상품 업로드/수정 양식
- 플레이오토 업로드 양식
- 각 판매처의 필수 필드 설명서
- 각 판매처의 가격/재고 수정 전용 양식이 따로 있다면 해당 파일
- 각 판매처의 상품코드/옵션코드 설명 자료
- 현재 운영에서 실제로 사용 중인 샘플 업로드 파일 사본
- 성공적으로 업로드된 파일과 실패한 파일이 있다면 원인 메모
- 판매처별 카테고리/배송/고시정보 양식 또는 정책 문서

샘플 파일을 받을 때는 실제 고객정보, 주문정보, 비밀번호, API key 같은 민감정보가 포함되어 있지 않은지 먼저 확인해야 한다.

## 10. 지금 하지 말아야 할 것

이번 문서 설계 단계에서 하지 말아야 할 것은 다음과 같다.

- SQL 실행 금지
- DB 변경 금지
- DDL 작성/실행 금지
- apply SQL 실행 금지
- local DB apply 금지
- 운영 Supabase 변경 금지
- NAS PostgreSQL 변경 금지
- SQL 파일 생성 금지
- API 코드 수정 금지
- Frontend 코드 수정 금지
- 실제 CSV/XLSX export 구현 금지
- 판매처 운영 업로드 실행 금지
- MakeShop / Smartstore 실제 반영 작업과 섞지 말 것
- git add 금지
- git commit 금지
- git push 금지
- `sql/`, `outputs/`, `exports/`, `backups` 임의 add 금지

## 11. 대표님 보고용 요약

1. 이번에는 판매처별 업로드 양식에 어떤 항목이 필요한지 문서로 정리했습니다.
2. 스마트스토어/메이크샵/에이블리/플레이오토마다 필요한 항목이 다르기 때문에 공통 기준표가 필요합니다.
3. 내부 SKU 기준으로 가격/재고를 관리하고, 판매처별 양식에 맞춰 변환하는 방향입니다.
4. 아직 DB나 사이트에는 아무것도 반영하지 않았습니다.
5. 다음 단계는 실제 판매처별 업로드 양식 파일을 모아서 정확한 필드 매핑표를 만드는 것입니다.
