# Auto Approval Candidate Dry-run Plan v1

작성일: 2026-07-05

## 목적

상품코드 매칭 수동검수 대상 중, 사람이 보기 전에 일괄 승인 후보로 분리할 수 있는 행을 보수적으로 산출한다.

이 문서는 운영 Supabase에 적용할 SQL이 아니라 dry-run 기준 문서다. 실제 DB 변경은 별도 apply SQL, 사전 백업, postcheck, 롤백 기준 승인 후 진행한다.

## 기준 테이블

- 기준 뷰: `public.mapping_matrix_review_full_v3`
- 실제 수동검수 범위: `match_tier in ('REVIEW', 'NO_MATCH')`
- 과대 범위로 보지 말 것: `review_required = true` 전체

## 현황

최근 운영 Supabase 읽기 검증 기준:

| 항목 | 건수 |
| --- | ---: |
| 전체 행 | 84,990 |
| 실제 수동검수 범위 | 약 23,857 |
| 기존 1차 안전 후보 | 2,436 |
| 보류 후보 중 추가 승격 가능 | 2,031 |
| 1차 dry-run 총 후보 | 4,467 |

위 수치는 live DB 상태에 따라 약간 변할 수 있다. 최종 판단은 `sql/dryrun_auto_approval_candidates_v1.sql` 실행 결과를 기준으로 한다.

## 후보 그룹

### P1_SAFE_UNTAGGED

기존 `recommended_action <> '자동 승인하지 않음'` 행 중 아래 조건을 모두 통과한 행이다.

- 수동검수 범위 안에 있음
- Sellpia 상품코드와 SKU 코드가 있음
- 중복 후보 없음
- 재고 보류 상태 아님
- 상품명 정규화 일치 또는 포함일치
- 옵션명 정규화 완전일치
- 위험어 없음
- 수동 태그 없음

최근 검증 기준 예상 건수:

| 채널 | 건수 |
| --- | ---: |
| Ably | 1,179 |
| Coupang | 662 |
| MakeShop | 595 |
| 합계 | 2,436 |

### P2_HOLD_PROMOTION_SAFE

기존 `recommended_action = '자동 승인하지 않음'` 행 중 더 엄격한 조건을 통과한 행이다.

- MakeShop만 포함
- 상품명 정규화 완전일치
- 옵션명 정규화 완전일치
- Sellpia 상품코드와 SKU 코드가 있음
- 중복 후보 없음
- 같은 판매처 옵션키가 다른 Sellpia SKU로 갈라지는 충돌 없음
- 위험어 없음
- 수동 태그 없음

최근 검증 기준 예상 건수:

| 채널 | 건수 |
| --- | ---: |
| MakeShop | 2,031 |

랜덤 샘플 40건에서는 오탐이 보이지 않았다.

## 제외 기준

아래는 자동승인 후보에서 제외한다.

- `NO_MATCH`
- 수동 태그 있음
- 14K 태그 행
- `자동 승인하지 않음` 중 상품명 포함일치만 되는 행
- 같은 판매처 옵션키가 둘 이상의 Sellpia SKU로 연결되는 행
- 위험어 포함 행
- 옵션명이 부분 포함으로만 맞는 행
- Smartstore 수동검수 행

위험어 기준:

- 세트
- 묶음
- 1+1
- 랜덤
- 혼합
- 대체
- 교환
- 단종
- 삭제
- 품절
- sold out
- crystal AB
- 크리스탈AB
- 독립 토큰 `AB`
- 독립 토큰 `set`
- `[xxx]`

## 정규화 기준

상품명:

- 공백, 괄호, 구분자 제거
- P1은 완전일치 또는 포함일치 허용
- P2는 완전일치만 허용

옵션명:

- 위치코드 `[AA-1-01]` 제거
- `=` 이후 문구 제거
- 줄바꿈 이후 문구 제거
- `모델착용` 제거
- 공백, 괄호, 구분자, 별표 제거
- 완전일치만 허용

부분 포함 옵션명은 제외한다. 예: `골드`가 `핑크골드`에 포함되는 케이스는 오탐 위험이 있어 제외한다.

## Dry-run SQL

파일:

- `sql/dryrun_auto_approval_candidates_v1.sql`

출력 섹션:

| 섹션 | 내용 |
| --- | --- |
| `01_manual_scope_summary` | 실제 수동검수 범위 카운트 |
| `02_proposed_candidate_summary` | 후보 그룹/룰/채널별 집계 |
| `03_conflict_check` | 같은 판매처 옵션키의 Sellpia SKU 분기 여부 |
| `04_apply_preview` | queue_id 기준 적용 미리보기 200건 |

## 예상 적용 방향

실제 apply SQL은 아직 만들지 않았다.

추후 적용한다면 대상은 `queue_id` 기준으로 고정하고, 적용 직전 dry-run 결과와 카운트가 정확히 일치할 때만 진행한다.

예상 변경 방향:

| 현재 | 제안 |
| --- | --- |
| `match_tier = REVIEW` | `AUTO_APPROVE_CANDIDATE` |
| `review_required = true` | `false` |
| `recommended_action` | 별도 승인 문구 또는 evidence marker 기록 |

단, 실제 컬럼 업데이트 방식은 현재 운영 저장 구조를 한 번 더 확인한 뒤 결정한다. `decision.option_match_decisions`는 비어 있었고, 현재 프론트 저장 흔적은 `review.match_candidate_queue.evidence_json` 및 queue 컬럼에 남는 구조로 보인다.

## 롤백 기준

적용 SQL을 만들 때 반드시 아래 값을 snapshot으로 남긴다.

- `queue_id`
- `source_candidate_key`
- `match_tier`
- `review_required`
- `recommended_action`
- `best_sellpia_product_code`
- `best_sellpia_sku_code`
- `best_sellpia_product_name`
- `best_sellpia_option_name`
- `evidence_json`
- `updated_at`

롤백은 `queue_id` 기준으로 위 snapshot 값을 되돌리는 방식이어야 한다.

## 다음 단계

1. `sql/dryrun_auto_approval_candidates_v1.sql`을 운영 Supabase에서 읽기 전용으로 실행한다.
2. `02_proposed_candidate_summary` 총합이 기대 범위와 맞는지 확인한다.
3. `03_conflict_check`에서 `conflicting_rows = 0`인지 확인한다.
4. `04_apply_preview` 샘플을 담당자가 확인한다.
5. 승인 후 별도 apply/postcheck/rollback SQL을 작성한다.
