# Read Model v1 Design

작성일: 2026-07-03

목적: 현재 `mapping_matrix_review_full_v3` 전체 다운로드를 제거하기 위한 read model 초안을 정의한다. 이 문서는 설계 초안이며 DB에 적용하지 않았다.

## Current Problem

현재 live static app은 다음 구조다.

1. `mapping_matrix_review_full_v3` 84,990건 전체 조회
2. 1,000건씩 85회 REST 요청
3. 약 100MB payload 추정
4. 브라우저에서 필터/검색/렌더링
5. 첫 완료까지 약 109초

이는 기능상 동작하지만 운영 도구로는 비효율적이다.

## Target Split

| model | purpose | payload |
| --- | --- | --- |
| `mapping_matrix_list_v1` | 일반 매트릭스 목록 | light |
| `manual_review_queue_light_v1` | 수동검수 queue 목록 | light |
| `mapping_matrix_summary_v1` | KPI/count | aggregate |
| `mapping_matrix_detail_v1` | 행 상세 | heavy |
| `product_code_search_v1` | 코드/상품명 검색 | search-light |

## View 1: `mapping_matrix_list_v1`

목록 전용 view다.

포함:

- row identity
- channel/source 정보
- channel product/option code
- Sellpia product/SKU code
- 표시용 상품명/옵션명
- tier/status/filter field
- boolean flags

제외:

- `evidence_json`
- 긴 상세 reason
- image URL
- tag array
- export 전용 field

## View 2: `manual_review_queue_light_v1`

수동검수 전용 queue다.

포함 조건 초안:

- `review_required = true`
- 또는 `match_tier in ('REVIEW', 'FAST_REVIEW', 'NO_MATCH')`
- 또는 `stock_compare_status`가 hold/review 계열
- `MANUAL_LINKED`는 별도 필터에서 볼 수 있게 유지

정렬 초안:

1. 위험도 bucket
2. source_channel
3. source_row_no
4. queue_id

## View 3: `mapping_matrix_summary_v1`

첫 화면 KPI용 aggregate view다.

dimension 후보:

- total
- source_channel
- match_tier
- review_required
- stock_compare_status
- auto_approval_tier
- has_sellpia_image
- has_manual_tag

## View 4: `mapping_matrix_detail_v1`

행 클릭 시만 조회한다.

포함:

- `mapping_matrix_review_full_v3`의 heavy field
- `match_candidate_details_full` 후보 상세
- image metadata
- tag assignments

v1에서는 view 하나로 무리하게 합치지 않고 API composition을 우선한다.

## View 5: `product_code_search_v1`

통합 검색 전용이다.

초안 검색 대상:

- `channel_product_code`
- `channel_option_code`
- `best_sellpia_product_code`
- `best_sellpia_sku_code`
- `channel_product_name`
- `channel_option_name`
- `best_sellpia_product_name`
- `best_sellpia_option_name`

v1은 `ILIKE` 기반으로 시작한다. 필요하면 v2에서 normalized column 또는 trigram index를 검토한다.

## API Attachment

React/API 쪽 endpoint 후보:

- `GET /api/mapping-matrix`
- `GET /api/mapping-matrix/:queueId`
- `GET /api/mapping-matrix/summary`
- `GET /api/product-code-search`
- 기존 `GET /api/manual-review/candidates`는 `manual_review_queue_light_v1` 기반으로 교체 가능

## Migration Strategy

1. 새 view를 추가한다.
2. 기존 view는 유지한다.
3. postcheck SQL로 count parity를 검증한다.
4. UI를 새 endpoint로 전환한다.
5. 실사용 링크 전환은 별도 승인 후 진행한다.

## Non-goals

- 기존 `mapping_matrix_review_full_v3` 즉시 삭제
- 운영 DB write 구조 변경
- 상품 매핑 자동 반영
- CSV/XLSX export 완전 이전
- 담당자 실사용 링크 즉시 교체

## Open Questions

1. `MANUAL_LINKED` row를 기본 큐에 포함할지, 완료 필터로 분리할지 결정 필요.
2. 검색은 코드 exact 우선인지, 상품명 fuzzy 우선인지 결정 필요.
3. summary count는 view로 충분한지, materialized view 또는 cached table이 필요한지 측정 필요.
4. GitHub Pages 정적 앱에 live config를 둘지, React/API만 live DB에 붙일지 결정 필요.
