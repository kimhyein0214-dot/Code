# Coupang Clean Unique Evidence Apply Dryrun Plan v1

## Purpose

This document records the apply dryrun for Coupang clean unique evidence candidates.

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

- `sql/dryrun_coupang_unique_evidence_clean_apply_v1.sql`

## Candidate Scope

The previous Coupang dryrun produced 565 final planned candidates. The narrow risk review found 26 candidates that should not enter the first apply dryrun.

This dryrun therefore targets only 539 clean candidates:

| Bucket | Count | First-pass policy |
|---|---:|---|
| Final planned candidates | 565 | Source pool |
| Narrow risk candidates | 26 | Exclude |
| Clean apply dryrun candidates | 539 | Dryrun target |

Broad color-only words are not excluded by themselves:

- silver
- gold
- pink gold
- rose gold
- yellow gold

They remain eligible only when duplicate and semantic warning checks stay clean.

## Exclusion Policy

These buckets remain excluded from the apply dryrun:

- warning: 140
- inactive: 718
- narrow risk: 26
- `크리스탈AB` / `크리AB`
- crystal vs crystal AB product-group conflict
- set, quantity, or `1+1`

## Coupang Alias Shape

Coupang evidence currently has no `channel_option_code`.

This means:

- dryrun `coupang_product_no` insert count should be 539
- dryrun `coupang_option_no` insert count should be 0
- `product_code.sku_channel_mapping` insert count should be 0

The first real local apply, if approved later, should be product-alias only unless a confirmed Coupang option identifier is added from another source.

## Dryrun Method

The SQL runs in one transaction:

1. Guard `current_database() = 'product_ops_test'`.
2. Guard `current_user = 'product_ops_tester'`.
3. Rebuild the Coupang final planned candidate CTE.
4. Rebuild the narrow risk classification.
5. Select only the clean 539 candidates.
6. Insert dryrun `coupang_product_no` aliases into `product_code.code_alias`.
7. Do not insert `coupang_option_no`.
8. Do not insert into `product_code.sku_channel_mapping`.
9. `ROLLBACK`.
10. Verify Coupang alias and mapping rows are still 0 after rollback.

## Result

Executed locally against `product_ops_test`.

The dryrun used `BEGIN`, temporary `product_code.code_alias` inserts, and `ROLLBACK`. No persistent Coupang alias or channel mapping rows remained after rollback.

| Metric | Count / Verdict |
|---|---:|
| Source final planned count | 565 |
| Narrow risk excluded count | 26 |
| Final clean planned count | 539 |
| Skipped existing confirmed count | 0 |
| Skipped existing manual count | 0 |
| Existing alias excluded count | 0 |
| Existing mapping excluded count | 0 |
| Duplicate Coupang code count | 0 |
| Duplicate Selfpia-to-Coupang count | 0 |
| Semantic warning count | 0 |
| Narrow risk remaining count | 0 |
| Warning remaining count | 0 |
| Inactive remaining count | 0 |
| Dryrun inserted product alias count | 539 |
| Dryrun inserted option alias count | 0 |
| Dryrun inserted sku_channel_mapping count | 0 |
| Rollback after code alias count | 0 |
| Rollback after sku channel mapping count | 0 |
| Rollback verdict | PASS |
| Overall verdict | PASS |

## Review Notes

The dryrun confirms that the 539 clean Coupang candidates can be inserted into `product_code.code_alias` as `coupang_product_no` rows without constraint failure when limited to this transaction.

No `coupang_option_no` rows were inserted because this evidence set has no `channel_option_code`. No `product_code.sku_channel_mapping` rows were inserted.

The first local apply SQL can proceed if approved, but it should remain product-alias only:

- Insert `coupang_product_no` for 539 clean candidates.
- Insert `coupang_option_no` for 0 candidates.
- Keep `sku_channel_mapping` unchanged.
- Stop if any Coupang alias or mapping row already exists before execution.

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
