# Manual Review Frontend Scope v1

## Purpose

The manual review frontend v1 should help reviewers quickly inspect the candidates that remain after local round-1 auto-match.

This is a scope document only. It does not change frontend code, SQL, or DB state.

The first version should be read-only or local-only review storage. It should prioritize fast triage, clear evidence comparison, and safe reviewer decisions before any operating DB workflow is considered.

## Product Concept

Use a list-style review screen, similar to a compact vocabulary-review or spreadsheet-review workflow.

Each row should show one channel candidate and the strongest available evidence. Reviewers should be able to scan many rows, filter down to risky buckets, and make a simple decision:

- approve.
- hold.
- exclude.
- view other candidates.

The UI should not try to hide ambiguity. It should make ambiguity visible and cheap to classify.

## Primary Filters

| Filter | Purpose |
|---|---|
| `channel` | Smartstore, MakeShop, Ably, Coupang, and later channels |
| `review_status` | pending, approved, held, excluded, needs_more_evidence |
| `risk_type` | source_conflict, warning, duplicate_sku, narrow_risk, evidence_missing, inactive_possible |
| `evidence_level` | direct, unique, duplicate, missing, source_conflict |
| `source_status` | active, inactive, hidden, waiting, sold_out, unknown |

## Row Columns

Each review row should include enough context to decide whether a candidate is the same product or option.

Recommended columns:

| Column | Notes |
|---|---|
| 판매처 | normalized channel code and account/source when available |
| 셀피아 상품코드 | product-level Selfpia code |
| 셀피아 SKU | option/SKU-level Selfpia code |
| 자사코드 | own SKU or seller-side internal code evidence |
| 판매처 상품코드 | channel product code |
| 판매처 옵션코드 | channel option code when available |
| 상품명 | channel product name plus internal product name if available |
| 옵션명 | channel option text plus internal option text if available |
| 이미지 여부 | whether image evidence exists; v1 can show a boolean before image preview work |
| 자동매칭 후보 사유 | direct code, unique code, source agreement, or other candidate reason |
| 위험 사유 | source conflict, warning, duplicate, narrow keyword, inactive, evidence missing |
| 승인/보류/제외/다른 후보 보기 | reviewer actions |

## Candidate Buckets

The frontend should start with the unresolved buckets that round-1 auto-match intentionally left behind.

Examples:

- source conflict.
- warning bucket.
- duplicate SKU.
- narrow risk.
- evidence missing.
- channel_absent_or_inactive_possible.

These buckets should remain separate. A row that is likely channel_absent_or_inactive should not be mixed with a row that needs manual matching.

## Review Decisions

Recommended v1 decisions:

| Decision | Meaning |
|---|---|
| approve | reviewer believes this is the correct mapping candidate |
| hold | reviewer cannot decide yet; keep for later |
| exclude | reviewer believes this should not be mapped |
| needs_more_evidence | row needs image, source file, or channel status confirmation |
| channel_absent_or_inactive | likely not a true missing mapping because the channel listing is inactive, hidden, old, or absent |

## Delete Review vs Manual Match

Deletion or deactivation review candidates must be separated from manual matching candidates.

Manual matching asks: which internal SKU should this active channel row map to?

Deletion or inactive review asks: should this channel row be ignored, removed from active matching scope, or classified as not currently operated?

Mixing these two decisions can inflate the apparent mismatch count and can cause reviewers to approve mappings that should stay inactive.

## Suggested v1 Workflow

1. Start with read-only candidate browsing.
2. Add local-only reviewer decisions after the row fields are trusted.
3. Review high-signal buckets first: source conflict, duplicate SKU, narrow risk.
4. Review evidence missing separately, because it may require image or source-file inspection.
5. Review channel_absent_or_inactive_possible separately from true manual-match candidates.
6. Summarize reviewer outcomes by channel, risk type, and evidence level.
7. Convert repeated safe patterns into round-2 dryrun rules.

## Round-2 Feedback Loop

Manual review should not be treated only as one-off cleanup.

The reviewed outcomes should feed the next matching iteration:

- approved rows become stronger code evidence candidates.
- repeated safe patterns can become round-2 auto-match rules.
- repeated risky patterns become permanent exclusion or manual-only rules.
- channel_absent_or_inactive decisions reduce false mismatch counts.

## Out of Scope for v1

- operating DB writes.
- NAS writes.
- remote DB writes.
- automatic confirmed/manual overwrite.
- bulk apply from the frontend.
- image-heavy review UI before the candidate columns and buckets are validated.

## Completion Report Template

1. Created/modified files
2. DB execution status
3. Round-1 auto-match summary
4. Manual review frontend v1 scope summary
5. Next-step recommendation
6. Commit hash
7. Push status
8. `git status -s`
9. Safety confirmation
