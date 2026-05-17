# Manual Mapping Review Workflow v1

작성일: 2026-05-17

## 1. 목적

이 문서는 후보군, 미매칭, 애매한 판매처 코드를 사람이 직접 검수하고, 검수 결과를 확정 매핑 반영과 자동매칭 규칙 개선에 재사용하기 위한 운영 workflow 초안이다.

핵심 목표:

- 후보/미매칭/애매한 매핑을 사람이 검수한다.
- 검수 결과를 확정 매핑으로 반영할 수 있는 표준 입력 형식으로 모은다.
- 누적된 수동검수 결과를 자동매칭 규칙, 정규화 규칙, threshold 조정에 활용한다.
- 초기 단계는 CSV 기반으로 시작하고, 안정화 후 DB review table로 확장한다.

이번 문서는 설계 문서다. DB 변경, SQL 실행, API/Frontend 구현, 실제 review table 생성은 포함하지 않는다.

## 2. 현재 상태

| 영역 | 상태 |
|---|---:|
| MakeShop auto_confirm v3 local apply | 11,179 rows 완료 |
| MakeShop weak_top1 local apply | 6,389 rows 완료 |
| MakeShop local mapping total | 17,568 rows |
| Smartstore optionNo local apply | 완료 |
| Smartstore productNo local cleanup | 완료 |
| Smartstore productNo candidate overlap cleanup | 1건 cleanup 완료 |
| Ablely/Coupang/PlayAuto | 본격 매핑 전 |
| 운영 Supabase/NAS 변경 | 없음 |

MakeShop `review_required`, `ambiguous`, `manual review` 대상은 계속 자동 apply 금지다. Smartstore candidate 값도 확정값처럼 export/apply하면 안 된다.

## 3. 검수 대상 범위

검수 대상은 한 화면과 한 CSV 구조 안에서 다루되, `review_type` 또는 `issue_type`으로 분리한다.

| 유형 | 설명 | 기본 처리 방향 |
|---|---|---|
| Smartstore 후보만 있는 SKU | confirmed optionNo/productNo 없이 candidate alias만 있는 SKU | 사람이 확인 후 확정/유지/반려 |
| Smartstore 미매핑 SKU | Smartstore 판매 이력이 있거나 원본에는 있으나 local 확정 alias가 없는 SKU | 원본 코드 확인 후 후보 생성 또는 미매핑 유지 |
| MakeShop review_required | 자동 apply 조건을 통과하지 못한 MakeShop row | 수동 검수 CSV 우선 |
| MakeShop ambiguous | own_sku, option token, product context가 복수 후보를 가리키는 row | 후보 비교 후 하나를 선택하거나 보류 |
| MakeShop manual review | 자동 후보가 없거나 사람 판단이 필요한 row | 보류/제외/추가 정보 요청 |
| 이미지 없음 | export 또는 판매처 검수에 필요한 대표/추가 이미지가 없는 SKU | 이미지 보강 요청 또는 export block |
| 자사코드 없음 | own_sku alias가 없거나 판매처 코드와 연결 불가 | alias backfill workflow로 분기 |
| 판매처 코드 중복 의심 | 같은 channel product/option code가 여러 SKU에 연결될 가능성 | conflict 검증 후 확정 금지 |
| Ablely/Coupang/PlayAuto 신규 후보 | 아직 본격 매핑 전인 채널의 초기 후보 | CSV-first 수동 검수로 시작 |

## 4. 검수 화면에 보여줄 정보

검수자는 내부 SKU, 원본 판매처 코드, 후보 생성 근거를 한 화면에서 비교해야 한다.

필수 표시 항목:

- 셀피아 SKU
- VSKU
- 자사코드
- 상품명
- 옵션명
- 이미지
- 판매처명
- 판매처 상품코드
- 판매처 옵션코드
- 후보 점수 또는 후보 사유
- 원본 판매처 상품명/옵션명
- 가격/재고
- 기존 확정 매핑 여부
- 후보/확정/미매핑 상태

권장 보조 정보:

- 같은 판매처 코드가 연결된 다른 SKU 목록
- 같은 자사코드가 연결된 SKU 목록
- 같은 상품명 안의 다른 옵션 목록
- 후보 생성 규칙명
- 이전 수동검수 이력
- export blocker/warning reason

## 5. 사람이 선택할 결정값

검수 결과는 사람이 이해하기 쉬운 `decision_status`로 저장한다.

| 결정값 | 의미 | apply 후보 여부 |
|---|---|---|
| `manual_confirmed` | 사람이 해당 판매처 코드와 SKU 매핑을 확정 | 가능 |
| `manual_rejected` | 후보가 틀렸다고 판단 | 불가 |
| `needs_more_info` | 이미지, 원본 상세, 판매처 화면 등 추가 근거 필요 | 불가 |
| `excluded` | SKU 매핑 대상이 아닌 meta/product-level row 또는 운영상 제외 대상 | 불가 |
| `duplicate` | 중복 후보 또는 이미 확정값으로 커버되는 후보 | 불가 |
| `keep_candidate` | 아직 확정하지 않고 후보 상태로 유지 | 불가 |
| `change_to_other_code` | 제시된 후보 대신 다른 product/option code를 선택 | 가능, selected code 필수 |

`manual_confirmed`와 `change_to_other_code`만 확정 매핑 apply 후보가 될 수 있다. 두 상태 모두 reviewer, reviewed_at, selected code, decision_reason이 필요하다.

## 6. CSV 우선 저장 구조

초기에는 검수 결과를 CSV로 저장한다. 이유는 검수자가 엑셀/스프레드시트로 빠르게 작업할 수 있고, DB write 기능 없이도 validate/dryrun 흐름을 만들 수 있기 때문이다.

추천 파일 흐름:

```text
outputs/manual_review_candidates_<channel>_<yyyymmdd>.csv
outputs/manual_review_reviewed_<channel>_<yyyymmdd>.csv
outputs/manual_review_validate_<channel>_<yyyymmdd>.txt
outputs/manual_review_dryrun_<channel>_<yyyymmdd>.txt
```

추천 CSV/향후 table 필드:

| 필드 | 설명 |
|---|---|
| `review_id` | 검수 row 고유 ID. source_file + row number 기반도 가능 |
| `sku_id` | 내부 SKU UUID |
| `virtual_sku_code` | VSKU |
| `selfpia_sku_code` | 셀피아 SKU |
| `own_sku_code` | 자사코드 |
| `channel_code` | `smartstore`, `makeshop`, `ablely`, `coupang`, `playauto` 등 |
| `candidate_product_code` | 후보 판매처 상품코드 |
| `candidate_option_code` | 후보 판매처 옵션코드 |
| `selected_product_code` | 사람이 선택한 최종 판매처 상품코드 |
| `selected_option_code` | 사람이 선택한 최종 판매처 옵션코드 |
| `decision_status` | `manual_confirmed`, `manual_rejected` 등 |
| `decision_reason` | 선택/반려/보류 사유 |
| `reviewer` | 검수자 |
| `reviewed_at` | 검수 완료 시각 |
| `review_note` | 자유 메모 |
| `source_file` | 원본 후보 CSV 또는 진단 파일 |
| `confidence_before` | 자동 후보 점수 |
| `rule_before` | 자동 후보 생성 규칙 |
| `image_checked` | 이미지 확인 여부 |
| `price_checked` | 가격 확인 여부 |
| `option_name_checked` | 옵션명 확인 여부 |

확장 후보 필드:

- `product_name`
- `option_name`
- `channel_product_name`
- `channel_option_name`
- `candidate_rank`
- `candidate_count`
- `existing_mapping_id`
- `existing_mapped_sku_id`
- `conflict_reason`
- `export_blocker_reason`

## 7. 향후 DB table 확장 초안

DB table은 CSV workflow가 안정된 뒤 별도 승인으로 설계한다. 지금은 생성하지 않는다.

개념상 table은 다음 책임을 가진다.

- review batch 관리
- candidate row 저장
- reviewer decision 저장
- apply eligibility 계산
- audit trail 보존

초기 table 후보:

```text
product_code.manual_mapping_review_batch
product_code.manual_mapping_review_item
product_code.manual_mapping_review_decision
```

주의: DDL 작성/실행은 이번 범위가 아니다. CSV 필드를 먼저 안정화한 뒤 설계한다.

## 8. 확정 매핑 반영 흐름

확정 매핑 반영은 CSV 검수 결과를 기반으로 단계별 승인 후 진행한다.

1. review CSV 생성
   - SELECT-only 진단 또는 기존 outputs 기반으로 후보 CSV를 만든다.
   - 후보, 미매칭, ambiguous, missing evidence를 분리한다.

2. 사람이 검수
   - 검수자는 `decision_status`, selected code, reason, reviewer, reviewed_at을 채운다.
   - 후보를 확정값처럼 임의 저장하지 않는다.

3. reviewed CSV 저장
   - 원본 후보 CSV와 reviewed CSV를 분리한다.
   - reviewed CSV는 source_file, review_id로 원본 row를 추적 가능해야 한다.

4. reviewed CSV validate
   - 필수 컬럼, enum 값, selected code, reviewer, reviewed_at을 검증한다.
   - duplicate channel key, missing SKU, existing conflict, candidate-only apply 시도를 차단한다.

5. dryrun apply
   - `manual_confirmed` 또는 `change_to_other_code` 중 apply eligible row만 대상으로 한다.
   - local transaction 안에서 insert/update simulation 후 `ROLLBACK`한다.

6. 사용자 승인
   - dryrun PASS와 예상 insert/update count를 보고받은 뒤 승인한다.

7. local apply
   - local Docker `product_ops_test`에서만 실행한다.
   - backup 후 COMMIT 전 guard와 postcheck를 둔다.

8. postcheck
   - count delta, conflict, duplicate, FK, candidate misuse 여부를 확인한다.

9. 운영 반영
   - 운영 Supabase/NAS 반영은 별도 설계/승인/rollback plan 이후에만 검토한다.

## 9. Validate 규칙 초안

reviewed CSV validate 단계에서 최소한 다음을 확인한다.

| 검증 항목 | 실패 시 처리 |
|---|---|
| 필수 컬럼 존재 | FAIL |
| `decision_status` enum 값 유효 | FAIL |
| apply eligible 상태에 selected code 존재 | FAIL |
| reviewer/reviewed_at 존재 | FAIL |
| selected SKU가 local `sku_master`에 존재 | FAIL |
| 같은 channel product/option key 중복 | FAIL |
| 기존 확정 매핑과 다른 SKU conflict | FAIL |
| candidate code를 confirmed처럼 직접 사용 | FAIL |
| excluded/duplicate/rejected row가 apply 대상에 포함 | FAIL |
| `image_checked`, `price_checked`, `option_name_checked` 필수 여부 | channel별 정책에 따라 FAIL 또는 WARNING |

## 10. 자동매칭 규칙 개선 흐름

수동확정 결과는 다음 자동매칭 개선에 사용한다.

| 개선 영역 | 활용 방식 |
|---|---|
| 옵션명 정규화 규칙 | 사람이 확정한 option text pair를 normalize rule 후보로 축적 |
| 색상명 동의어 규칙 | 예: 딥퍼플/퍼플, 실버/SV 등 채널별 동의어 관리 |
| 사이즈 매칭 규칙 | M/L, free, one size, 호수 표기 등 표준화 |
| 자사코드 우선 규칙 | own_sku가 강한 채널과 보조 근거인 채널을 분리 |
| 판매처별 코드 우선순위 | product code, option code, own_sku, barcode의 신뢰도 순서 조정 |
| 이미지 검수 활용 | 이미지 일치 확인이 필요한 유형과 생략 가능한 유형 분리 |
| 후보 점수 threshold | manual_confirmed/rejected 분포로 threshold 상향/하향 |
| rejected 후보 패턴 차단 | 반복적으로 반려된 token/rule 조합을 blocker 후보로 관리 |

자동매칭 규칙 개선은 반드시 검증 가능한 누적 근거를 기반으로 한다. 검수 결과 없이 규칙을 과확장하지 않는다.

## 11. 프론트 개선 방향

초기 프론트는 read-only 검수 보조 화면으로 시작한다. 실제 저장 기능은 별도 승인 전 금지다.

당장 구현 후보:

- 후보/미매칭 필터
- 판매처별 필터
- 확정/후보/미매핑 badge
- 복사 버튼
- 후보 비교 카드
- 상품명/옵션명/이미지 비교 영역
- 기존 확정 매핑 표시
- 가격/재고 요약 표시
- 확정/반려/보류 버튼 placeholder

금지:

- 프론트에서 바로 DB write
- 검수 결과 저장 API 구현
- candidate를 confirmed처럼 저장
- review_required 자동 apply

## 12. 단계별 구현 순서

추천 순서:

1. 현재 매칭 커버리지 집계
2. 수동검수 대상 CSV 생성
3. 프론트 read-only 검수 화면 개선
4. 검수 결과 CSV template 작성
5. reviewed CSV validate SQL 작성
6. dryrun apply reviewed mapping
7. local apply/postcheck
8. 자동매칭 규칙 개선

각 단계는 별도 산출물과 PASS/FAIL 기준을 둔다. local apply 전에는 항상 backup, dryrun PASS, 사용자 승인, postcheck 계획이 필요하다.

## 13. 지금 하지 말아야 할 것

- 바로 DB write 기능 만들기 금지
- 운영 DB 반영 금지
- NAS PostgreSQL 반영 금지
- 후보를 확정값처럼 저장 금지
- `review_required` 자동 apply 금지
- 프론트에서 바로 저장 기능 추가 금지
- 검수 결과 없이 자동매칭 규칙 과확장 금지
- DDL 작성/실행 금지
- apply SQL 실행 금지
- outputs/exports/backups 임의 수정 또는 add 금지
- 원본 xlsx/csv/xml 수정 금지

## 14. 채널별 우선순위 제안

1. MakeShop remaining review_required
   - 이미 auto_confirm/weak_top1 apply가 끝났고, 남은 row가 수동검수 workflow의 첫 적용 대상으로 적합하다.
   - ambiguous, not_in_alias, pattern_unmatched, null_key를 분리한다.

2. Smartstore candidate-only / unmapped
   - optionNo/productNo 확정값과 candidate를 명확히 분리한다.
   - productNo candidate는 confirmed productNo와 같은 `target_id + code_value`를 제외한다.

3. Ablely/Coupang/PlayAuto 신규 후보
   - 본격 매핑 전이므로 CSV-first로 후보/미매핑/필수 필드 구조를 먼저 잡는다.
   - export validation blocker와 연결한다.

## 15. 대표님 보고용 요약

판매처 코드 중 애매하거나 아직 매칭되지 않은 항목은 사람이 검수하는 별도 workflow로 분리합니다.  
검수 결과는 먼저 CSV로 모으고, 검증 후 local DB에서만 dryrun/apply/postcheck를 거칩니다.  
확정된 검수 데이터는 이후 자동매칭 규칙을 더 똑똑하게 만드는 학습 재료로 사용합니다.  
후보 코드는 확정값처럼 바로 쓰지 않고, 운영 DB 반영은 별도 승인 뒤에만 진행합니다.  
처음 구현은 read-only 화면과 CSV template부터 시작하는 것이 안전합니다.

