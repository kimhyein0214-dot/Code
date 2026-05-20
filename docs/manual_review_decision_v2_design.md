# Manual Review Decision v2 Design

## 1. v2 Goal

Manual review v2 should let reviewers save a decision for each read-only workbench candidate.

Initial persistence scope is local DB only:

- Database: `product_ops_test`.
- Intended user: local/test reviewer workflow.
- Production Supabase, NAS PostgreSQL, and any remote DB writes are prohibited until separately approved.

The v2 decision store is not an operating data apply step. It records review intent only. Applying approved decisions to aliases, channel mappings, exports, or production systems must remain a separate, guarded workflow.

## 2. Decision Taxonomy

### `approve_match`

Meaning: approve that this candidate may be matched to the suggested Selfpia SKU.

Target:

- `manual_matching_candidate`.

Notes:

- This is not an immediate operating DB apply.
- This only saves a local decision record.
- Later apply workflows must re-check guards and current data before using this decision.

### `hold`

Meaning: reviewer cannot decide yet and intentionally leaves the candidate pending.

Target:

- All candidates.

Notes:

- Does not approve matching.
- Does not classify inactive/delete review.
- Does not route the candidate into auto-match or inactive review applies.

### `exclude_candidate`

Meaning: this candidate is judged to be a wrong or irrelevant candidate for the current review queue.

Target:

- All candidates.

Notes:

- This does not mean product deletion.
- This does not remove source data.
- This only records that the candidate should be excluded from the current review workbench decision flow.

### `inactive_reviewed`

Meaning: a reviewer checked a deletion/inactive review candidate and marked the operating-status review as complete.

Target:

- `deletion_or_inactive_review_candidate`.

Notes:

- This is not actual deletion.
- This is not actual channel deactivation.
- This should not write to channel mappings or product master tables.

### `needs_source_fix`

Meaning: the reviewer found that source/channel/code evidence must be corrected before a reliable decision can be made.

Target:

- `source_conflict`.
- `evidence_missing`.
- Other candidates with insufficient or suspect source evidence.

Notes:

- This is not a match approval.
- This should route the item toward source-data correction or evidence investigation.

## 3. Prohibited Misinterpretations

- Unmatched does not mean deletion target.
- A deletion/inactive review candidate does not mean deletion is confirmed.
- `approve_match` does not immediately apply to production or operating DB.
- `exclude_candidate` does not delete a product.
- `inactive_reviewed` does not deactivate an actual channel product.
- A saved decision is not an apply script.
- A saved decision is not permission to overwrite confirmed/manual mappings.

## 4. Decision Table Draft

Expected table name:

- `manual_review_decision`

This is a column design only. Do not treat this section as DDL.

| Column | Draft meaning |
|---|---|
| `decision_id` | Stable primary key for the saved decision record. |
| `review_candidate_id` | Candidate id from the read-only workbench. |
| `review_scope` | Candidate scope at decision time: `manual_matching_candidate` or `deletion_or_inactive_review_candidate`. |
| `channel_code` | Channel at decision time. |
| `channel_product_code` | Channel product code at decision time. |
| `channel_option_code` | Channel option code at decision time. |
| `suggested_sku_id` | Suggested local SKU id from the candidate, if present. |
| `suggested_selfpia_sku` | Suggested Selfpia SKU code from the candidate, if present. |
| `decision_status` | Review decision enum value. |
| `decision_reason` | Optional structured reason or reviewer-selected reason category. |
| `reviewer_note` | Free-form reviewer note. |
| `reviewer` | Reviewer identity from local admin/session/env. |
| `decided_at` | Time the decision was made or last changed. |
| `source_risk_type` | Candidate `risk_type` captured at decision time. |
| `source_evidence_level` | Candidate `evidence_level` captured at decision time. |
| `source_suggested_action` | Candidate `suggested_action` captured at decision time. |
| `created_at` | Decision record creation time. |
| `updated_at` | Decision record update time. |

Design notes:

- Store candidate source fields as a decision snapshot so later candidate query changes do not erase the review context.
- Do not store any field that implies an operating apply has already happened.
- Consider enforcing one active decision per `review_candidate_id`, with history handled separately if audit requirements grow.

## 5. `decision_status` Enum Draft

Allowed values:

- `approve_match`
- `hold`
- `exclude_candidate`
- `inactive_reviewed`
- `needs_source_fix`

The enum should remain local-review oriented. Avoid names such as `delete`, `apply`, `activate`, `deactivate`, or `overwrite` because those imply operating changes.

## 6. API Design Draft

v1 remains GET only. Write endpoints are only for v2 and must be local-guarded.

Expected endpoints:

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/api/manual-review/decisions` | List saved decisions, optionally filtered by status, scope, channel, reviewer, or candidate id. |
| GET | `/api/manual-review/decisions/:reviewCandidateId` | Read the saved decision for one candidate. |
| POST | `/api/manual-review/decisions` | Create a local decision for a candidate. |
| PATCH | `/api/manual-review/decisions/:decisionId` | Update a local decision or reviewer note. |

Required API constraints:

- Keep existing read-only candidate endpoints unchanged.
- Add write endpoints only under v2 implementation work.
- Do not connect v2 write endpoints to production Supabase.
- Do not connect v2 write endpoints to NAS PostgreSQL.
- Require local DB guard before any write.
- Validate that the requested `decision_status` is allowed for the candidate `review_scope`.
- Validate that the saved candidate snapshot matches the latest local candidate enough to avoid accidental stale saves.

Draft POST payload shape:

```json
{
  "review_candidate_id": "candidate-hash",
  "decision_status": "hold",
  "decision_reason": "needs_manager_review",
  "reviewer_note": "Need to compare source file row before deciding."
}
```

This JSON is illustrative only. It is not an implementation instruction for this task.

## 7. Local DB Write Guard Design

Decision writes must fail closed.

Required guards:

- Reject if current database is not `product_ops_test`.
- Reject if current user is not an approved local/test user, such as `product_ops_tester`.
- Reject if app environment is not local/test.
- Reject if connection string points to production Supabase, NAS PostgreSQL, or any remote DB host.
- Reject if the request attempts to perform apply/merge behavior.
- Keep decision storage separate from alias/channel mapping/product master apply SQL.

Recommended guard checks:

- Read `current_database()` before write.
- Read `current_user` before write.
- Check `NODE_ENV`, API env, or a dedicated `MANUAL_REVIEW_WRITE_MODE=local_only` flag.
- Log guard failures without exposing credentials.
- Add postcheck queries that count changed rows in the decision table only.

Explicitly prohibited:

- Updating `product_code.code_alias`.
- Updating `product_code.sku_channel_mapping`.
- Updating product master or SKU master tables.
- Running apply SQL from a decision save endpoint.

## 8. UI v2 Design

Controls to add only after v2 write API and local guards are reviewed:

- `approve_match` button.
- `hold` button.
- `exclude_candidate` button.
- `inactive_reviewed` button.
- `needs_source_fix` button.
- `reviewer_note` input.
- Save confirmation modal.
- Saved status badge.
- Saved candidates filter.
- Unsaved candidates filter.

UI rules:

- Keep read-only candidate data visible beside any decision form.
- Show the decision meaning in Korean before save.
- Show a confirmation modal before any write.
- Make it explicit that saved decisions are local-only.
- After save, show status badge and last saved time.
- Do not imply production apply.
- Disable buttons not allowed by the candidate scope.

Suggested confirmation copy:

- "이 결정은 local DB에만 저장됩니다."
- "운영 DB에는 반영되지 않습니다."
- "상품 삭제나 채널 비활성 처리가 아닙니다."

## 9. Candidate Type Decision Matrix

| Candidate type | `approve_match` | `hold` | `exclude_candidate` | `inactive_reviewed` | `needs_source_fix` |
|---|---:|---:|---:|---:|---:|
| `manual_matching_candidate` | Allowed | Allowed | Allowed | Not allowed or strongly discouraged | Allowed |
| `deletion_or_inactive_review_candidate` | Strongly discouraged | Allowed | Allowed | Allowed | Allowed |

Additional guidance:

- `approve_match` should require a suggested SKU id or a selected replacement SKU.
- `inactive_reviewed` should only be prominent for `deletion_or_inactive_review_candidate`.
- `needs_source_fix` should be prominent for `source_conflict`, `evidence_missing`, source warnings, and missing key fields.
- `exclude_candidate` should be framed as excluding the candidate from review, not deleting source/product data.
- `hold` should never feed auto-apply.

Risk-oriented defaults:

| `risk_type` | Preferred visible choices |
|---|---|
| `source_conflict` | `needs_source_fix`, `hold`, `exclude_candidate` |
| `warning_bucket` | `needs_source_fix`, `hold`, `exclude_candidate` |
| `narrow_risk` | `approve_match`, `hold`, `exclude_candidate` |
| `evidence_missing` | `needs_source_fix`, `hold`, `exclude_candidate` |
| `channel_absent_or_inactive_possible` | `inactive_reviewed`, `hold`, `needs_source_fix` |
| `duplicate_sku` | `needs_source_fix`, `hold`, `exclude_candidate` |

## 10. Recommended Implementation Order

1. Document review.
2. Local DB schema draft for `manual_review_decision`.
3. Dry-run SQL draft for schema and constraints.
4. Local-only API write guard implementation.
5. UI save controls activation.
6. Postcheck design and implementation.
7. Extended local review.
8. Separate decision on whether and how any reviewed output may feed operating apply workflows.

Do not skip from this design directly to production writes. Decision storage, decision apply, and production apply must remain separate phases.
