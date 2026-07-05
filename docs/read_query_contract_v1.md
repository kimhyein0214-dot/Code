# Read Query Contract v1

작성일: 2026-07-03

목적: `mapping_matrix_review_full_v3` 전체 다운로드 구조를 제거하기 위해, 목록/요약/상세/검색 API가 어떤 파라미터와 응답 형태를 가져야 하는지 고정한다.

## 원칙

1. 첫 화면은 전체 row를 받지 않는다.
2. 목록 API는 기본 50건, 최대 200건까지만 반환한다.
3. 필터와 검색은 DB/API에서 처리한다.
4. 목록과 상세 payload를 분리한다.
5. count/summary는 목록 row 다운로드와 분리한다.
6. 기존 `mapping_matrix_review_full_v3`는 parity check 완료 전까지 유지한다.

## Endpoints

### `GET /api/mapping-matrix`

목록용 endpoint다. 첫 화면과 페이지 이동에 사용한다.

Query parameters:

| name | type | default | note |
| --- | --- | --- | --- |
| `limit` | integer | 50 | max 200 |
| `offset` | integer | 0 | v1은 offset 기반 |
| `source_channel` | string | empty | `smartstore`, `makeshop`, `ably`, `coupang`, `playauto` |
| `match_tier` | string | empty | `AUTO_APPROVE_CANDIDATE`, `FAST_REVIEW`, `REVIEW`, `MANUAL_LINKED`, `NO_MATCH` |
| `review_required` | boolean | empty | 수동 검수 필요 여부 |
| `stock_compare_status` | string | empty | 재고 비교 상태 |
| `has_sellpia_image` | boolean | empty | 이미지 보유 여부 |
| `has_manual_tag` | boolean | empty | 수동 태그 여부 |
| `search` | string | empty | 코드/상품명/옵션명 통합 검색 |
| `sort` | string | `source_channel,queue_id` | 허용된 정렬 key만 사용 |
| `direction` | string | `asc` | `asc`, `desc` |

Response:

```json
{
  "data": [],
  "page": {
    "limit": 50,
    "offset": 0,
    "returned": 50,
    "has_next": true
  },
  "filters": {},
  "sort": {
    "key": "source_channel,queue_id",
    "direction": "asc"
  }
}
```

`data` row shape:

| field | note |
| --- | --- |
| `queue_id` | stable row id |
| `source_channel` | 판매처 |
| `source_batch_id` | 원천 batch |
| `source_row_no` | 원천 row |
| `channel_product_code` | 판매처 상품코드 |
| `channel_option_code` | 판매처 옵션코드 |
| `channel_product_name` | 판매처 상품명 |
| `channel_option_name` | 판매처 옵션명 |
| `best_sellpia_product_code` | Sellpia 상품코드 |
| `best_sellpia_sku_code` | Sellpia SKU |
| `best_sellpia_product_name` | Sellpia 상품명 |
| `best_sellpia_option_name` | Sellpia 옵션명 |
| `match_tier` | 매칭 tier |
| `review_required` | 검수 필요 여부 |
| `recommended_action` | 표시용 권장 액션 |
| `stock_compare_status` | 재고 비교 상태 |
| `auto_approval_tier` | 자동 승인 tier |
| `has_sellpia_image` | 이미지 여부 |
| `has_manual_tag` | 태그 여부 |
| `manual_tag_count` | 태그 수 |

목록에서 제외할 field:

- `evidence_json`
- 긴 `match_reason`
- 이미지 URL
- tag array
- export 전용 field

### `GET /api/mapping-matrix/:queueId`

상세 endpoint다. 행 클릭 시에만 호출한다.

Response:

```json
{
  "data": {
    "row": {},
    "details": [],
    "images": [],
    "tags": []
  }
}
```

상세에 포함할 수 있는 field:

- `evidence_json`
- `match_reason`
- 후보 상세 rows from `match_candidate_details_full`
- Sellpia image metadata
- product/sellpia tag assignments

### `GET /api/mapping-matrix/summary`

KPI와 필터 count용 endpoint다.

Response:

```json
{
  "data": {
    "total": 84990,
    "by_source_channel": [],
    "by_match_tier": [],
    "by_review_required": [],
    "by_stock_compare_status": [],
    "by_auto_approval_tier": []
  }
}
```

### `GET /api/product-code-search`

코드/상품명 검색 전용 endpoint다.

Query parameters:

| name | type | default |
| --- | --- | --- |
| `q` | string | required |
| `source_channel` | string | empty |
| `limit` | integer | 20 |

검색 대상:

- `channel_product_code`
- `channel_option_code`
- `best_sellpia_product_code`
- `best_sellpia_sku_code`
- `channel_product_name`
- `channel_option_name`
- `best_sellpia_product_name`
- `best_sellpia_option_name`

## Pagination Contract

v1은 offset 기반으로 시작한다.

이유:

- 현재 UI 전환 비용이 낮다.
- 기존 API가 `limit`/`offset`을 이미 사용한다.
- 84,990건 규모에서는 page 이동이 제한적이면 충분하다.

v2 후보:

- keyset cursor: `(source_channel, queue_id)`
- 검색 결과 cursor: `(rank, queue_id)`

## Error Shape

```json
{
  "error": "invalid_filter",
  "message": "source_channel is not supported",
  "details": {}
}
```

공통 에러:

| error | condition |
| --- | --- |
| `invalid_limit` | limit <= 0 or limit > 200 |
| `invalid_offset` | offset < 0 |
| `invalid_filter` | 허용되지 않은 filter |
| `invalid_sort` | 허용되지 않은 sort key |
| `query_failed` | DB query 실패 |

## Performance Targets

| operation | target |
| --- | ---: |
| first list load | under 3 sec |
| summary load | under 2 sec |
| filter change | under 2 sec |
| search | under 2 sec |
| detail open | under 2 sec |
| first payload | under 1 MB |

## Compatibility Notes

- 기존 static app의 CSV/XLSX export는 당장 동일 기능을 요구하지 않는다.
- 안정화 v1에서는 화면 조회/검수 우선이다.
- export는 별도 server-side export 또는 filtered export endpoint로 분리한다.
- GitHub Pages 버전은 `config.js` 없는 read-only shell로 유지할 수 있다.

## Next Step

이 계약을 기준으로 다음 SQL 초안을 검토한다.

- `sql/draft_read_model_v1.sql`
- `sql/postcheck_read_model_v1.sql`
- `sql/rollback_read_model_v1.sql`
