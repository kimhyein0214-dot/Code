# Manual Review Frontend Read-Only Runbook v1

## Scope

This runbook covers the admin frontend read-only manual review workbench.

Route:

- `/products/manual-review`

The screen is list and detail inspection only. It does not save reviewer decisions, reviewer notes, approvals, holds, exclusions, or mapping changes.

## API Calls

The screen uses GET requests only:

- `GET /api/manual-review/summary`
- `GET /api/manual-review/candidates`
- `GET /api/manual-review/candidates/:reviewCandidateId`

No POST, PUT, PATCH, or DELETE requests are implemented.

## UI Behavior

- Shows total manual review candidates.
- Separates `manual_matching_candidate` from `deletion_or_inactive_review_candidate`.
- Labels deletion/inactive rows as `삭제/비활성 검토 후보`.
- Does not use wording that implies deletion is confirmed.
- Provides filters for channel, risk type, evidence level, review scope, suggested action, and search.
- Uses `limit=50` by default.
- Keeps filters in URL query parameters and sends them to the candidates API.
- Shows loading, error, and empty states.
- Detail expansion reads candidate detail by `review_candidate_id`.
- Approval, hold, and exclusion controls are disabled and marked as 준비중.

## Local Verification

Run the local API against `product_ops_test`, then start the admin app:

```bash
cd frontend/admin
npm run dev
```

Open:

```text
http://localhost:5173/products/manual-review
```

Expected summary counts:

- Total: `40,958`
- 수동매칭 후보: `24,205`
- 삭제/비활성 검토 후보: `16,753`

## Non-Goals

- No review decision storage.
- No database writes.
- No API write requests.
- No production Supabase access.
- No NAS PostgreSQL access.
- No source CSV/XLSX changes.
