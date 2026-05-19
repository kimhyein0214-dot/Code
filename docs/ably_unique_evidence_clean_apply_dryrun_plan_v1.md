# Ably Clean Unique Evidence Apply Dryrun Plan v1

## Purpose

This document records the apply dryrun for Ably clean unique evidence candidates.

This is still a dryrun:

- No real automatic matching apply.
- No `COMMIT`.
- No persistent `product_code.code_alias` change.
- No persistent `product_code.sku_channel_mapping` change.
- No operating Supabase access.
- No NAS PostgreSQL access.
- No remote DB access.
- No source CSV/XLSX modification or git add.

Dryrun SQL:

- `sql/dryrun_ably_unique_evidence_clean_apply_v1.sql`

## Candidate Scope

The previous Ably dryrun produced 3,024 final planned candidates. The narrow risk review found 751 candidates that should not enter the first apply dryrun.

This dryrun therefore targets only 2,273 clean candidates:

| Bucket | Count | First-pass policy |
|---|---:|---|
| Final planned candidates | 3,024 | Source pool |
| Narrow risk candidates | 751 | Exclude |
| Clean apply dryrun candidates | 2,273 | Dryrun target |

Broad color-only words are not excluded by themselves:

- silver
- gold
- pink gold
- rose gold
- yellow gold

They remain eligible only when the existing duplicate and semantic warning checks stay clean.

## Exclusion Policy

These buckets remain excluded from the apply dryrun:

- source conflict: 4,813
- warning: 8,149
- duplicate SKU: 312
- inactive: 12,860
- evidence missing: 5,584
- narrow risk: 751
- `크리스탈AB` / `크리AB`
- standalone `AB`
- crystal vs crystal AB product-group conflict
- set, quantity, or `1+1`

## Dryrun Method

The SQL runs in one transaction:

1. Guard `current_database() = 'product_ops_test'`.
2. Guard `current_user = 'product_ops_tester'`.
3. Rebuild the Ably final planned candidate CTE.
4. Rebuild the narrow risk classification.
5. Select only the clean 2,273 candidates.
6. Insert dryrun `ably_product_no` and `ably_option_no` aliases into `product_code.code_alias`.
7. Do not insert into `product_code.sku_channel_mapping`.
8. `ROLLBACK`.
9. Verify Ably alias and mapping rows are still 0 after rollback.

The dryrun insert is intentionally real inside the transaction so table constraints and defaults are exercised, but it must leave no persistent rows.

## Result

Executed locally against `product_ops_test`.

The dryrun used `BEGIN`, temporary `product_code.code_alias` inserts, and `ROLLBACK`. No persistent Ably alias or channel mapping rows remained after rollback.

| Metric | Count / Verdict |
|---|---:|
| Source final planned count | 3,024 |
| Narrow risk excluded count | 751 |
| Final clean planned count | 2,273 |
| Skipped existing confirmed count | 0 |
| Skipped existing manual count | 0 |
| Existing alias excluded count | 0 |
| Existing mapping excluded count | 0 |
| Duplicate Ably code count | 0 |
| Duplicate Selfpia-to-Ably count | 0 |
| Semantic warning count | 0 |
| Narrow risk remaining count | 0 |
| Source conflict remaining count | 0 |
| Warning remaining count | 0 |
| Duplicate SKU remaining count | 0 |
| Inactive remaining count | 0 |
| Dryrun inserted product alias count | 2,273 |
| Dryrun inserted option alias count | 561 |
| Dryrun inserted code alias total count | 2,834 |
| Dryrun inserted sku channel mapping count | 0 |
| Rollback after code alias count | 0 |
| Rollback after sku channel mapping count | 0 |
| Rollback verdict | PASS |
| Overall verdict | PASS |

## Review Notes

The dryrun confirms that the 2,273 clean candidates can be inserted into `product_code.code_alias` without constraint failure when limited to this transaction.

The lower option alias count is expected because PlayAuto-only evidence often does not carry an Ably option code. The first local apply SQL should make this behavior explicit:

- Insert `ably_product_no` for all 2,273 clean candidates.
- Insert `ably_option_no` only for candidates with a non-null `channel_option_code`.
- Keep `sku_channel_mapping` unchanged unless a separate approved mapping strategy is written.

The first local apply should still be gated by exact counts and should stop if any Ably alias or mapping rows already exist before execution.

## Decision Rules

A) If the dryrun is PASS and rollback is PASS, the next step may be writing a user-approved local apply SQL.

B) If any risk remains in the clean candidate set, exclude that risk and rerun the dryrun.

C) If duplicate or semantic warnings appear, do not proceed to apply; return to sample review.

## Completion Report Template

1. Created/modified files
2. Local DB dryrun execution status
3. Source final planned count
4. Narrow risk excluded count
5. Final clean planned count
6. Skipped existing confirmed/manual count
7. Duplicate/semantic warning/narrow risk remaining result
8. Dryrun inserted product/option alias count
9. Rollback result
10. OVERALL verdict
11. Codex first-pass judgment on local apply SQL readiness
12. Commit hash
13. Push status
14. `git status -s`
15. Safety confirmation
