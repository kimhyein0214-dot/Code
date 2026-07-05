# Read Path Bottleneck Report v1

작성일: 2026-07-02

목적: 현재 상품코드/매칭 데이터가 화면에 나오기까지의 읽기 경로를 실측하고, 안정화 작업의 첫 타깃을 정한다.

## 결론

현재 가장 큰 병목은 DB 자체보다 **브라우저가 84,990건 전체 row를 순차 다운로드하고, 그 데이터를 프론트에서 필터/검색/렌더링하는 구조**다.

실사용 Vercel static 앱 기준:

- DOM 로딩: 약 0.55초
- `mapping_matrix_review_full_v3 전체 84,990건 조회 완료`: 약 109.35초
- 화면 표시 단위: 100건
- 실제로는 100건만 보이지만, 내부에서는 84,990건 전체를 먼저 가져온다.

따라서 읽기 구조 안정화의 1순위는 **전체 다운로드 제거**다.

## Current Read Flow

기준 파일: `docs/local-review/app.js`

1. `initSupabase()`
2. 로컬 JSON apply map 로드
3. `loadTags()`
4. `loadQueueRows()`
5. `fetchQueueRows()`
6. `mapping_matrix_review_full_v3`를 1,000건씩 `range(from, to)` 반복 조회
7. 진행 중에도 일부 렌더
8. 전체 row 로딩 후 `loadImageAssets(queueRows)`
9. 전체 row 기준 `loadSellpiaSharedTagsForRows(queueRows)`
10. 최종 dashboard/table/manual review 렌더

주요 코드 근거:

- `LOAD_ALL_ROWS`: `docs/local-review/app.js:104`
- `SUPABASE_PAGE_SIZE=1000`: `docs/local-review/app.js:105`
- queue load 시작: `docs/local-review/app.js:422`
- queue select columns: `docs/local-review/app.js:463`
- 1,000건 range 반복: `docs/local-review/app.js:498`
- 이미지 보조조회: `docs/local-review/app.js:1312`
- 공유 태그 보조조회: `docs/local-review/app.js:589`
- 프론트 필터: `docs/local-review/app.js:1616`
- 테이블 렌더: `docs/local-review/app.js:1991`, `docs/local-review/app.js:2149`

## Live Measurements

측정 기준:

- 대상: `https://vercelstatic-l2qp4wzr6-codesystemgood.vercel.app/`
- DB view: `mapping_matrix_review_full_v3`
- 측정 시각: 2026-07-02 22:38 KST 전후
- 방식: Supabase REST fetch + Chrome headless browser
- DB 쓰기 없음

### Browser End-to-End

| metric | value |
| --- | ---: |
| DOM ready | 0.55 sec |
| final queue loaded | 109.35 sec |
| final status | `mapping_matrix_review_full_v3 전체 84,990건 조회 완료` |
| visible table rows | 100 |
| console error | favicon 404 only |

### Full Queue View

| metric | value |
| --- | ---: |
| total rows | 84,990 |
| page size | 1,000 |
| REST page requests | 85 |
| detail view rows | 82,187 |

### Lightweight Scan

Lightweight columns:

`queue_id, source_channel, match_tier, review_required, stock_compare_status, auto_approval_tier, recommended_action, has_sellpia_image, best_sellpia_product_code, best_sellpia_sku_code, manual_tag_count, has_manual_tag`

| metric | value |
| --- | ---: |
| total scan time | 32.34 sec |
| rows fetched | 84,990 |
| total transfer | 31.45 MB |
| avg page time | 379 ms |
| p50 page time | 387 ms |
| p90 page time | 546 ms |
| max page time | 755 ms |
| avg page size | 370 KB |

### Current Full Column Samples

Current app select columns include names, reasons, evidence JSON, image URL fields, manual tags, and display fields.

| range | rows | time | transfer |
| --- | ---: | ---: | ---: |
| 0-999 | 1,000 | 0.91 sec | 1.13 MB |
| 1000-1999 | 1,000 | 1.03 sec | 1.40 MB |
| 10000-10999 | 1,000 | 1.47 sec | 1.25 MB |
| 50000-50999 | 1,000 | 1.69 sec | 1.09 MB |
| 84000-84989 | 990 | 2.05 sec | 1.22 MB |

Estimated full transfer for current columns:

- 85 pages x roughly 1.2 MB = about 100 MB plus overhead
- observed browser completion = 109.35 sec

## Distribution Snapshot

### Channel

| channel | rows | share |
| --- | ---: | ---: |
| makeshop | 37,683 | 44.3% |
| smartstore | 21,179 | 24.9% |
| ably | 13,898 | 16.4% |
| coupang | 8,011 | 9.4% |
| playauto | 4,219 | 5.0% |

### Match Tier

| match_tier | rows |
| --- | ---: |
| FAST_REVIEW | 32,778 |
| AUTO_APPROVE_CANDIDATE | 29,910 |
| REVIEW | 22,210 |
| NO_MATCH | 56 |
| MANUAL_LINKED | 36 |

### Recommended Action Top 10

| recommended_action | rows |
| --- | ---: |
| 코드 근거를 추가로 찾아야 함 | 30,616 |
| 후보 검산 후 승인 가능 | 27,004 |
| 상품명과 옵션명을 사람이 확인 | 15,684 |
| 자동 승인하지 않음 | 6,181 |
| 판매처별 원본 보조근거로 사용 | 4,214 |
| 세트/조합 규칙 확인 필요 | 854 |
| 보조옵션이면 재고 반영 제외 | 340 |
| 검토 필요 | 56 |
| 수동 연동됨 | 36 |
| 현재 범위에서 제외 | 5 |

## Bottleneck Diagnosis

### 1. Payload is too large for first screen

첫 화면은 100건만 보여주는데, 현재는 84,990건 전체와 대량 텍스트/evidence 필드를 먼저 가져온다. 이 구조 때문에 화면 단위 page size와 DB fetch size가 분리되어 있지 않다.

### 2. Filtering happens after full download

채널, 등급, 검색, 이미지 필터가 DB 쿼리 조건이 아니라 프론트 배열 필터에 가깝다. 사용자가 특정 채널 하나만 보려 해도 전체 84,990건을 먼저 받는다.

### 3. Count path is unstable

`mapping_matrix_review_full_v3`의 exact count는 한 번 `0-0/84990`으로 성공했고, 이후 같은 성격의 count probe가 한 번 500으로 흔들렸다. 전체 view가 무겁거나 count 계획이 불안정할 가능성이 있다.

### 4. One view carries too many UI jobs

`mapping_matrix_review_full_v3`가 다음 역할을 동시에 수행한다.

- 매트릭스 목록
- 수동검수 후보 목록
- dashboard summary
- filter/search source
- CSV/XLSX export source
- 이미지/태그 보조조회 기준

역할이 많아서 필요한 컬럼을 줄이기 어렵고, UI별 최적화가 막힌다.

### 5. React/API path is structurally better but not active path

React/admin manual review API는 `limit`, `offset`, filters를 지원하고 max limit도 200으로 제한한다. 방향은 맞지만 현재 담당자 실사용 경로는 Vercel static 앱이라 read bottleneck은 여전히 static 경로에 있다.

## Recommended Stabilization Order

### Step 1. Create list-light view

새 view 후보:

- `mapping_matrix_list_v1`
- `manual_review_queue_light_v1`

목표:

- 첫 화면에 필요한 최소 컬럼만 포함
- `evidence_json`, 긴 reason, 이미지 URL, tag arrays는 제외
- DB 필터 가능한 정렬 key 포함

### Step 2. Move filters to DB/API

우선 DB/API query parameter:

- `source_channel`
- `match_tier`
- `review_required`
- `stock_compare_status`
- `has_sellpia_image`
- `has_manual_tag`
- `search`
- `limit`
- `offset` or keyset cursor

### Step 3. Split summary count

새 summary view/RPC 후보:

- `mapping_matrix_summary_v1`
- `manual_review_summary_v1`

목표:

- 전체 row 다운로드 없이 KPI 표시
- channel/tier/review_required count만 빠르게 조회

### Step 4. Split detail

새 detail view/API:

- `manual_review_candidate_detail_v1`
- `mapping_matrix_row_detail_v1`

목표:

- 행 클릭 시에만 상세/evidence/image/tag 로딩
- 1페이지 목록 로딩과 상세 로딩 분리

### Step 5. Keep old view read-only until parity check

`mapping_matrix_review_full_v3`는 즉시 제거하지 않는다.

비교 기준:

- total count 일치
- channel count 일치
- match_tier count 일치
- 샘플 100건 row identity 일치
- 검색/필터 결과 일치

## Success Criteria for Next Iteration

| metric | current | target |
| --- | ---: | ---: |
| first usable list | ~109 sec | under 3 sec |
| first payload | ~100 MB estimated | under 1 MB |
| initial row fetch | 84,990 rows | 50-100 rows |
| filter response | requires full local data | under 2 sec |
| count response | exact count sometimes unstable | stable summary endpoint |

## Immediate Next Work

1. Draft `read_query_contract_v1.md`.
2. Draft SQL for `mapping_matrix_list_v1` and `manual_review_summary_v1`.
3. Build dry-run/postcheck SQL that compares new outputs with `mapping_matrix_review_full_v3`.
4. Only after SQL parity, change Pages/React read path to paginated loading.

## Notes and Limits

- Supabase REST anon access does not expose view definitions, so this report uses app code and observable REST behavior.
- Local API/DB runtime was not measured in this pass because local Docker/API environment was not running in the prior check.
- No schema, table, view, RPC, or row was modified.
