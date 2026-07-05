# GitHub Pages Review Mode Connection Plan v1

작성일: 2026-07-05

## 현재 상태

GitHub Pages 프론트는 열려 있다.

- URL: `https://kimhyein0214-dot.github.io/Code/local-review/`
- live `config.js`: 없음
- live HTML: `config.js`를 로드하지 않음
- 기본 `appMode`: `demo`

따라서 현재 Pages 화면은 DB 저장을 하지 않는다.

프론트 코드에는 저장 로직이 있다.

- `link_match_candidate_option`
- `unlink_match_candidate_option`
- `update_match_candidate_queue_cell`

운영 Supabase에도 위 RPC 3개가 존재한다.

## 현재 위험

RPC 3개는 현재 아래 상태다.

- schema: `public`
- `SECURITY DEFINER`
- `anon` 실행 가능
- `authenticated` 실행 가능
- 함수 내부 인증은 `reviewer` 문자열 입력 확인뿐임

이 상태에서 GitHub Pages에 Supabase key와 `appMode: "review"`를 공개로 넣으면 누구나 브라우저에서 DB 쓰기 요청을 보낼 수 있다.

## 연동 원칙

GitHub Pages 쓰기 연동은 자동승인 DB 적용 이후 진행한다.

순서:

1. 자동승인 후보 DB 적용 완료
2. postcheck PASS
3. RPC 권한 정리
4. Supabase Auth 로그인 추가
5. allowlist 기반 쓰기 허용
6. Pages config 연결
7. 버튼 smoke test

## 권한 정리 방향

최소 변경:

```sql
revoke execute on function public.link_match_candidate_option(bigint, text, text, text, text, text, text) from anon;
revoke execute on function public.unlink_match_candidate_option(bigint, text, text) from anon;
revoke execute on function public.update_match_candidate_queue_cell(bigint, text, text, text, text) from anon;

grant execute on function public.link_match_candidate_option(bigint, text, text, text, text, text, text) to authenticated;
grant execute on function public.unlink_match_candidate_option(bigint, text, text) to authenticated;
grant execute on function public.update_match_candidate_queue_cell(bigint, text, text, text, text) to authenticated;
```

하지만 이것만으로는 부족하다. 로그인한 모든 사용자가 쓸 수 있기 때문이다.

권장 변경:

- `review.review_user_allowlist` 테이블 생성
- 허용 이메일 또는 user id만 쓰기 가능
- RPC 내부 시작부에서 allowlist 확인
- 실패 시 exception

## 프론트 변경 방향

GitHub Pages에서는 비밀키를 숨길 수 없다. 따라서 service role key는 절대 사용하지 않는다.

공개 가능한 설정만 포함한다.

```js
window.SYSTEM_V1_CONFIG = {
  supabaseUrl: "https://bpgvqmtsjgegnrdzmpep.supabase.co",
  supabaseAnonKey: "publishable_or_anon_key",
  queueView: "mapping_matrix_review_full_v3",
  detailsView: "match_candidate_details_full",
  appMode: "review",
  loadAllRows: false,
  supabasePageSize: 200
};
```

추가 프론트 작업:

- 로그인 UI 추가
- 현재 로그인 사용자 표시
- 로그아웃 버튼 추가
- 로그인 전 쓰기 버튼 disabled
- 로그인 후 RPC smoke test
- `config.js`를 repo에 직접 커밋할지, GitHub Pages용 공개 config 파일명을 따로 둘지 결정

## 버튼별 저장 확인

연동 후 smoke test:

| 버튼 | 기대 동작 |
| --- | --- |
| 자동승인 | `link_match_candidate_option` 호출, `MANUAL_LINKED` 또는 승인 상태 저장 |
| 수동연동 | `link_match_candidate_option` 호출 |
| 연동끊기 | `unlink_match_candidate_option` 호출 |
| 단종시키기 | 현재 구현상 `unlink_match_candidate_option` 호출, 단종 전용 상태가 필요하면 별도 RPC 필요 |

## 보류 결정

현재 `단종시키기`는 단종 전용 DB 상태가 아니라 unlink 계열로 저장된다. 담당자가 실제로 단종 상태를 별도 관리해야 한다면 아래 중 하나를 결정해야 한다.

- `recommended_action = '단종 처리됨'`으로 queue에 남김
- 별도 RPC `discontinue_match_candidate_option` 생성
- decision table을 활성화해서 결정 이력을 분리 저장

## 다음 실행 단위

자동승인 DB 적용이 끝난 뒤 아래 파일을 만든다.

- `sql/draft_secure_review_rpc_permissions_v1.sql`
- `docs/github_pages_auth_smoke_test_runbook_v1.md`

그 다음 Pages 프론트에 로그인 UI와 review mode config를 붙인다.
