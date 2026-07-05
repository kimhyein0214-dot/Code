# Stabilization Worklog 2026-07-03

작성일: 2026-07-03

## 작업 범위

사용자가 약 1시간 동안 추가 명령을 주기 어려운 상황에서, DB 쓰기/커밋/푸시 없이 읽기 구조 안정화 준비 작업을 진행했다.

## 생성한 문서

| 파일 | 목적 |
| --- | --- |
| `docs/db_dependency_map_v1.md` | 현재 static app, React/API, Supabase table/view/RPC 의존성 동결 |
| `docs/read_path_bottleneck_report_v1.md` | 현재 전체 조회 병목 실측 보고 |
| `docs/read_query_contract_v1.md` | 목록/상세/요약/검색 API 계약 초안 |
| `docs/read_model_v1_design.md` | read model 분리 설계 초안 |

## 생성한 SQL 초안

| 파일 | 목적 | 적용 여부 |
| --- | --- | --- |
| `sql/draft_read_model_v1.sql` | light list, manual queue, summary, search view 초안 | 미적용 |
| `sql/postcheck_read_model_v1.sql` | 적용 후 count parity 확인 초안 | 미실행 |
| `sql/rollback_read_model_v1.sql` | 적용 후 제거용 rollback 초안 | 미실행 |

SQL 파일은 모두 초안이다. 현재 상태에서는 `ROLLBACK`으로 끝나도록 작성해 실수 적용을 막았다. 실제 적용 단계에서는 별도 검토 후 `COMMIT`/migration 형태로 바꿔야 한다.

## 주요 측정값

| 항목 | 값 |
| --- | ---: |
| live queue view | `mapping_matrix_review_full_v3` |
| total rows | 84,990 |
| current full load time | 약 109.35초 |
| current REST page requests | 85회 |
| visible first page rows | 100 |
| lightweight full scan time | 약 32.34초 |
| lightweight transfer | 약 31.45MB |
| current full payload estimate | 약 100MB |

## 판단

1. 병목은 DB 단일 쿼리보다 전체 row 다운로드 구조에 있다.
2. 첫 화면은 summary + page 1만 받아야 한다.
3. `mapping_matrix_review_full_v3`는 당장 제거하지 말고 parity 기준으로 유지한다.
4. 새 read model은 기존 view를 감싸는 wrapper view로 먼저 시작하는 것이 가장 안전하다.
5. React/API는 이미 `limit`/`offset` 방향이 있으므로, static app보다 전환 기반으로 적합하다.

## 사용자가 돌아오면 결정할 것

1. SQL 초안을 실제 local/test DB에 dry-run할지 결정한다.
2. `manual_review_queue_light_v1`의 포함 조건을 승인 또는 수정한다.
3. `MANUAL_LINKED`를 기본 큐에 포함할지 완료 필터로 분리할지 결정한다.
4. 검색 우선순위를 코드 exact 우선으로 할지, 상품명 포함 통합 검색으로 할지 결정한다.
5. 다음 구현을 GitHub Pages static에 먼저 붙일지, React/API에 먼저 붙일지 결정한다.

## 추천 다음 작업

1. `sql/draft_read_model_v1.sql`을 local/test DB에서 `BEGIN ... ROLLBACK` 상태로 실행해 컬럼 존재 여부를 확인한다.
2. `sql/postcheck_read_model_v1.sql`을 실제 적용 가능한 형태로 정리한다.
3. `GET /api/mapping-matrix`, `GET /api/mapping-matrix/summary` skeleton을 추가한다.
4. React 화면에서 전체 로딩 대신 page 1만 로딩하도록 바꾼다.
5. Vercel static 담당자 사용 링크는 검증 완료 전까지 유지한다.

## 미수행

- DB schema 적용 안 함
- DB row 쓰기 안 함
- 커밋 안 함
- 푸시 안 함
- 담당자 실사용 링크 변경 안 함
