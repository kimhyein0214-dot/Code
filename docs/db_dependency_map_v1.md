# DB Dependency Map v1

작성일: 2026-07-02

목적: 현재 Product Ops / Picking System의 프론트와 API가 어떤 Supabase view/table/RPC를 읽거나 호출하는지 동결해서, 이후 읽기 구조 안정화 작업의 기준선으로 삼는다.

## 확인 범위

- GitHub Pages 정적 앱: `docs/local-review`
- 기존 Vercel static 앱: `https://vercelstatic-l2qp4wzr6-codesystemgood.vercel.app/`
- React admin API client: `frontend/admin/src/api/client.js`
- local API manual review module: `server/src/modules/manual-review`
- SQL draft/runbook 문서: `sql/`, `docs/`

DB에는 쓰기 작업을 하지 않았다. Supabase REST 조회와 코드 분석만 수행했다.

## 배포/사용 링크 역할

| 링크 | 역할 | DB 연결 상태 |
| --- | --- | --- |
| `https://vercelstatic-l2qp4wzr6-codesystemgood.vercel.app/` | 담당자 실사용 중인 안정화 전 static 앱 | `config.js` 포함, Supabase live read/write RPC 호출 가능 |
| `https://kimhyein0214-dot.github.io/Code/local-review/` | GitHub Pages 정적 안정판 | `config.js` 미포함, 현재 DB 미연결 경고 상태 |
| `http://127.0.0.1:5173/products/manual-review` | React admin local 화면 | local API `:8080` 및 local/test DB 필요 |

## Static App Read Dependencies

기준 파일: `docs/local-review/app.js`

| 대상 | 사용 위치 | 용도 | 현재 위험 |
| --- | --- | --- | --- |
| `mapping_matrix_review_full_v3` | `QUEUE_VIEW` live config | 전체 매칭 매트릭스/수동검수 큐 목록 | 84,990건 전체를 브라우저로 순차 다운로드 |
| `match_candidate_details_full` | `DETAILS_VIEW` live config | 선택 행 후보 상세 50건 조회 | 행 클릭 시 lazy load라 상대적으로 안전 |
| `product_tags` | `loadTags`, 태그 생성 | 태그 목록 조회/생성 | write 기능이 static 앱에 남아 있음 |
| `product_tag_assignments` | 상품 태그 저장/조회 | 행 단위 태그 저장 | write 기능이 static 앱에 남아 있음 |
| `sellpia_tag_assignments` | Sellpia 공유 태그 조회/저장 | 상품/옵션 코드 기준 공유 태그 | 현재 row count 0, 구조만 존재 |
| `sellpia_product_images_public` | `loadImageAssets` | 최초 500개 Sellpia SKU 이미지 보조 조회 | 전체가 아니라 500개 제한 |
| `sellpia_stock_snapshots` | 최신 재고 snapshot 조회/업로드 | Sellpia 재고 최신본 | 현재 REST 기준 0건 |
| `sellpia_stock_snapshot_rows` | snapshot rows 조회/업로드 | Sellpia 재고 row | 현재 REST 기준 0건 |

## Static App RPC Dependencies

| RPC | 사용 위치 | 의미 | 현재 위험 |
| --- | --- | --- | --- |
| `link_match_candidate_option` | 상품 매칭관리 수동 연동 | 후보 option을 매칭으로 연결 | live static에서 직접 호출 가능 |
| `unlink_match_candidate_option` | 상품 매칭관리 연동 끊기 | 기존 연결 해제 | live static에서 직접 호출 가능 |
| `update_match_candidate_queue_cell` | 큐 cell 수정 | stage 검수값 수정 | live static에서 직접 호출 가능 |

## React/Admin API Dependencies

기준 파일: `frontend/admin/src/api/client.js`

| API | 용도 | 구조 |
| --- | --- | --- |
| `GET /api/manual-review/summary` | 수동검수 요약 | local API가 SQL CTE 실행 |
| `GET /api/manual-review/candidates` | 수동검수 후보 목록 | `limit`, `offset`, filter 지원 |
| `GET /api/manual-review/candidates/:id` | 후보 상세 | 단건 조회 |
| `GET /api/manual-review/decisions/:id` | 저장된 결정 조회 | local/test 결정 테이블 조회 |
| `POST /api/manual-review/decisions` | 4개 결정 버튼 저장 | local/test DB 쓰기 guard 있음 |

React/API 쪽은 기본적으로 페이지네이션 구조를 가지고 있다. 다만 local API가 아직 실제 사용 링크로 연결된 상태는 아니며, local DB/Docker가 필요하다.

## Local Manual Review SQL Dependencies

기준 파일:

- `server/src/modules/manual-review/repository.js`
- `sql/select_manual_review_workbench_candidates_v1.sql`

핵심 원천:

| 원천 | 용도 |
| --- | --- |
| `product_code_stage.channel_option_evidence` | 판매처별 evidence 원천 |
| `product_code_stage.ably_playauto_source_file` | source file name 보강 |
| `product_code.code_alias` | Selfpia/own SKU 후보 매칭 |
| `product_code_review.manual_review_decision` | 수동검수 결정 저장 초안 |

local API는 `product_ops_test` + `product_ops_tester` + read-only transaction guard를 요구한다. 결정 저장은 `NODE_ENV=development`와 read-write transaction guard를 요구한다.

## Live Supabase Row Counts

측정 기준: 2026-07-02 22:37 KST 전후, Supabase REST anon key, 쓰기 없음.

| 대상 | count | 비고 |
| --- | ---: | --- |
| `mapping_matrix_review_full_v3` | 84,990 | count exact가 한 번은 성공, 한 번은 500으로 흔들림 |
| `match_candidate_details_full` | 82,187 | 후보 상세 |
| `product_tags` | 18 | 태그 마스터 |
| `product_tag_assignments` | 1 | 행 태그 |
| `sellpia_tag_assignments` | 0 | 공유 태그 |
| `sellpia_product_images_public` | 19,332 | 이미지 public view |
| `sellpia_stock_snapshots` | 0 | live REST 기준 |
| `sellpia_stock_snapshot_rows` | 0 | live REST 기준 |

## Queue Distribution Snapshot

`mapping_matrix_review_full_v3` 84,990건을 lightweight 컬럼으로 전체 스캔해서 집계했다.

### Channel

| channel | rows |
| --- | ---: |
| makeshop | 37,683 |
| smartstore | 21,179 |
| ably | 13,898 |
| coupang | 8,011 |
| playauto | 4,219 |

### Match Tier

| match_tier | rows |
| --- | ---: |
| FAST_REVIEW | 32,778 |
| AUTO_APPROVE_CANDIDATE | 29,910 |
| REVIEW | 22,210 |
| NO_MATCH | 56 |
| MANUAL_LINKED | 36 |

### Review Required

| review_required | rows |
| --- | ---: |
| true | 55,044 |
| false | 29,946 |

### Other Signals

| signal | rows |
| --- | ---: |
| unique Sellpia product codes | 3,412 |
| unique Sellpia SKU codes | 22,278 |
| has Sellpia image | 66,485 |
| no Sellpia image | 18,505 |
| has manual tag | 11,038 |
| no manual tag | 73,952 |

## Current Dependency Risk

1. Live static 앱이 읽기와 쓰기 기능을 같이 들고 있다.
2. 가장 큰 view 하나가 목록, 필터, 검색, 수동검수, 매트릭스 기능을 모두 떠안고 있다.
3. React/API 쪽은 구조가 더 안정적이지만, 현재 실사용 경로는 static 앱 쪽이다.
4. `mapping_matrix_review_full_v3`의 exact count가 간헐적으로 500을 반환해, count도 안정화 대상이다.
5. GitHub Pages 안정판은 안전하게 분리됐지만 `config.js`가 없으므로 아직 live 데이터 확인용은 아니다.

## 다음 산출물로 이어질 항목

- `read_path_bottleneck_report_v1.md`: 현재 읽기 병목 실측
- `read_query_contract_v1.md`: page/filter/search/count 계약
- `manual_review_queue_light_v1` 설계안
- `mapping_matrix_list_v1` 설계안
- `manual_review_summary_v1` 설계안
