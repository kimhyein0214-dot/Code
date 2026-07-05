# Auto Approval Apply Runbook v1

작성일: 2026-07-05

## 목적

수동검수 대상 중 검증 완료된 `4,467`건을 운영 Supabase에서 자동승인 후보로 전환한다.

이 runbook은 실제 DB 변경을 포함하는 단계다. 적용 전 dry-run, 적용 후 postcheck, rollback SQL을 모두 준비한 뒤 실행한다.

## 파일

| 파일 | 역할 |
| --- | --- |
| `sql/dryrun_auto_approval_candidates_v1.sql` | 적용 대상 산출 및 preview |
| `sql/apply_auto_approval_candidates_v1.sql` | 실제 적용 |
| `sql/postcheck_auto_approval_candidates_v1.sql` | 적용 후 검증 |
| `sql/rollback_auto_approval_candidates_v1.sql` | 적용 전 snapshot 기준 원복 |

## 적용 대상

| 그룹 | 채널 | 건수 |
| --- | --- | ---: |
| P1_SAFE_UNTAGGED | ably | 1,179 |
| P1_SAFE_UNTAGGED | coupang | 662 |
| P1_SAFE_UNTAGGED | makeshop | 595 |
| P2_HOLD_PROMOTION_SAFE | makeshop | 2,031 |
| 합계 |  | 4,467 |

## 적용 전 확인

1. `sql/dryrun_auto_approval_candidates_v1.sql` 실행
2. `02_proposed_candidate_summary` 총합이 `4,467`인지 확인
3. `03_conflict_check`의 `conflicting_rows`가 모든 그룹에서 `0`인지 확인
4. `04_apply_preview` 샘플 확인

## Apply 동작

`sql/apply_auto_approval_candidates_v1.sql`은 아래 작업을 한 transaction에서 수행한다.

1. `review.auto_approval_apply_backup_v1` snapshot 테이블 생성
2. temp candidate table 생성
3. 카운트 guard 실행
4. 충돌 guard 실행
5. 기존 backup marker 존재 여부 확인
6. 변경 전 상태 snapshot 저장
7. `review.match_candidate_queue` 업데이트

변경값:

| 컬럼 | 값 |
| --- | --- |
| `match_tier` | `AUTO_APPROVE_CANDIDATE` |
| `review_required` | `false` |
| `recommended_action` | `자동 승인됨 - auto_approval_candidates_v1` |
| `evidence_json.auto_approval_events` | 적용 marker와 변경 전후 상태 append |

## Apply guard

아래 조건 중 하나라도 맞지 않으면 SQL이 exception으로 중단된다.

- 총 후보 수가 `4,467`이 아님
- P1/P2 채널별 수가 기대값과 다름
- 같은 판매처 옵션키가 둘 이상의 Sellpia SKU로 갈라짐
- 같은 marker의 backup row가 이미 존재함
- snapshot row 수가 `4,467`이 아님
- update row 수가 `4,467`이 아님

## Postcheck

Apply 직후 `sql/postcheck_auto_approval_candidates_v1.sql`을 실행한다.

PASS 조건:

- backup rows = `4,467`
- applied rows = `4,467`
- `match_tier = AUTO_APPROVE_CANDIDATE` rows = `4,467`
- `review_required = false` rows = `4,467`
- marker rows = `4,467`
- evidence marker rows = `4,467`
- conflict rows = `0`

## Rollback

문제가 있으면 `sql/rollback_auto_approval_candidates_v1.sql`을 실행한다.

Rollback은 `review.auto_approval_apply_backup_v1`의 `auto_approval_candidates_v1` marker snapshot을 기준으로 아래 값을 복구한다.

- `match_tier`
- `review_required`
- `recommended_action`
- `best_sellpia_product_code`
- `best_sellpia_sku_code`
- `best_sellpia_product_name`
- `best_sellpia_option_name`
- `evidence_json`
- `updated_at`

Rollback도 backup row가 정확히 `4,467`개일 때만 실행된다.

## GitHub Pages 연동 전제

이 apply는 프론트 공개 쓰기와 별개다.

GitHub Pages를 쓰기 모드로 연결하기 전에는 Supabase RPC 권한을 먼저 정리해야 한다.

현재 확인된 위험:

- `link_match_candidate_option`
- `unlink_match_candidate_option`
- `update_match_candidate_queue_cell`

위 RPC는 `anon` 실행 권한이 있고 `SECURITY DEFINER`다. 공개 GitHub Pages에 DB config를 넣으면 누구나 쓰기 요청을 보낼 수 있다.

따라서 Pages 쓰기 연결 전 필수 작업:

1. `anon` RPC 실행권한 제거
2. `authenticated`만 쓰기 RPC 실행 가능하게 변경
3. 함수 내부에서 허용 사용자 allowlist 확인
4. GitHub Pages에 Supabase Auth 로그인 추가
5. smoke test 후 담당자에게 URL 공유
