# Manual Review Read-Only API Runbook v1

## Scope

This runbook covers the local read-only API for manual review workbench candidates.

The API is for local `product_ops_test` only. It does not create review decisions, does not persist reviewer notes, and does not modify product code data.

## Safety Guards

- API methods: GET only.
- Database transaction mode: `BEGIN READ ONLY` per repository call.
- Database guard: `current_database() = product_ops_test`.
- User guard: `current_user = product_ops_tester`.
- Source SQL: `sql/select_manual_review_workbench_candidates_v1.sql`.
- The endpoint reuses the SQL CTE through `workbench_candidates` and appends API-specific SELECT statements.

Do not point this API at production Supabase, NAS PostgreSQL, or any remote database.

## Endpoints

### GET `/api/manual-review/summary`

Returns candidate counts for the read-only workbench.

Response shape:

```json
{
  "data": {
    "total_count": 40958,
    "by_channel_code": [{ "value": "ably", "count": 23740 }],
    "by_risk_type": [{ "value": "source_conflict", "count": 29305 }],
    "by_evidence_level": [{ "value": "source_conflict", "count": 29305 }],
    "by_review_scope": [{ "value": "manual_matching_candidate", "count": 24205 }],
    "by_suggested_action": [{ "value": "compare_conflicting_candidates", "count": 23755 }],
    "by_source_status": [{ "value": "active_candidate", "count": 24205 }]
  }
}
```

### GET `/api/manual-review/candidates`

Returns paginated manual review candidates.

Pagination:

- `limit`: default `50`, max `200`.
- `offset`: default `0`.

Filters:

- `channel_code`
- `risk_type`
- `evidence_level`
- `review_scope`
- `suggested_action`
- `source_status`
- `search`

Examples:

```bash
curl "http://localhost:8080/api/manual-review/candidates?limit=10"
curl "http://localhost:8080/api/manual-review/candidates?channel_code=ably&limit=10"
curl "http://localhost:8080/api/manual-review/candidates?review_scope=manual_matching_candidate&limit=10"
```

### GET `/api/manual-review/candidates/:reviewCandidateId`

Returns one candidate by `review_candidate_id`.

Example:

```bash
curl "http://localhost:8080/api/manual-review/candidates/00000000000000000000000000000000"
```

## Returned Candidate Columns

- `review_candidate_id`
- `channel_code`
- `source_system`
- `source_file_name`
- `source_row_no`
- `review_scope`
- `evidence_level`
- `risk_type`
- `risk_reason`
- `suggested_action`
- `channel_product_code`
- `channel_option_code`
- `channel_sku_code`
- `seller_product_code`
- `own_sku_code_candidate`
- `selfpia_sku_candidate`
- `matched_sku_id_candidate`
- `matched_product_id_candidate`
- `selfpia_product_code`
- `selfpia_sku_code`
- `own_sku_code`
- `product_name_channel`
- `option_name_channel`
- `product_name_selfpia`
- `option_name_selfpia`
- `image_status`
- `source_status`
- `normalized_sale_status`
- `normalized_display_status`
- `normalized_option_status`
- `reviewer_decision_placeholder`
- `reviewer_note_placeholder`

## Local Verification

Start the API against local `.env.api` settings only:

```bash
cd server
npm start
```

Check endpoints:

```bash
curl "http://localhost:8080/api/manual-review/summary"
curl "http://localhost:8080/api/manual-review/candidates?limit=10"
curl "http://localhost:8080/api/manual-review/candidates?channel_code=ably&limit=10"
curl "http://localhost:8080/api/manual-review/candidates?review_scope=manual_matching_candidate&limit=10"
```

Expected v1 candidate counts from the local SELECT:

- Total manual review candidates: `40,958`.
- `manual_matching_candidate`: `24,205`.
- `deletion_or_inactive_review_candidate`: `16,753`.

## Non-Goals

- No frontend implementation.
- No review decision persistence.
- No reviewer note persistence.
- No POST, PUT, PATCH, or DELETE endpoints.
- No production Supabase access.
- No NAS PostgreSQL access.
- No source spreadsheet or CSV modification.
