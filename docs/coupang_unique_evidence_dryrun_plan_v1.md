# Coupang Unique Evidence Dryrun Plan v1

## Purpose

This document records the dryrun for Coupang unique evidence candidates found from PlayAuto source evidence.

This step is dryrun-only:

- No real automatic matching apply.
- No `COMMIT`.
- No persistent `product_code.code_alias` change.
- No persistent `product_code.sku_channel_mapping` change.
- No operating Supabase access.
- No NAS PostgreSQL access.
- No remote DB access.
- No source CSV/XLSX modification or git add.

Dryrun SQL:

- `sql/dryrun_coupang_unique_evidence_candidates_v1.sql`

## Source

Coupang evidence comes from PlayAuto XLSX rows where `쇼핑몰(계정)` maps to:

- `쿠팡=wworks2010` -> `channel_code='coupang'`

The source system is PlayAuto, but the channel must remain `coupang`; `playauto` is not a channel code for apply or alias purposes.

## Candidate Policy

The dryrun targets Coupang unique evidence only:

- joins `selfpia_sku_candidate` / `own_sku_code_candidate` to known `selfpia_sku` / `own_sku` aliases
- excludes warning rows
- excludes duplicate channel SKU risk
- excludes inactive rows
- excludes evidence missing rows
- excludes existing Coupang aliases/mappings
- does not use existing Smartstore, MakeShop, or Ably channel aliases as SKU evidence

Risk keywords are counted and sampled, not automatically applied:

- `크리스탈`
- `크리스탈AB`
- `크리AB`
- standalone `AB`
- `화이트골드`
- `실버`
- `골드`
- `로즈골드`
- `핑크골드`
- `세트`
- `1+1`
- `수량`

## Result

Executed locally against `product_ops_test`.

The dryrun used `BEGIN`, temporary `product_code.code_alias` inserts, and `ROLLBACK`. No persistent Coupang alias or channel mapping rows remained after rollback.

| Metric | Count / Verdict |
|---|---:|
| Coupang evidence total | 1,283 |
| Coupang unique candidate count | 565 |
| Warning excluded count | 140 |
| Duplicate SKU excluded count | 0 |
| Inactive excluded count | 718 |
| Evidence missing excluded count | 0 |
| Skipped existing confirmed count | 0 |
| Skipped existing manual count | 0 |
| Existing alias excluded count | 0 |
| Existing mapping excluded count | 0 |
| Duplicate Coupang code count | 0 |
| Duplicate Selfpia-to-Coupang count | 0 |
| Semantic warning count | 0 |
| Risk keyword count | 442 |
| Final planned candidate count | 565 |
| Dryrun inserted product alias count | 565 |
| Dryrun inserted option alias count | 0 |
| Dryrun inserted sku_channel_mapping count | 0 |
| Rollback after code_alias count | 0 |
| Rollback after sku_channel_mapping count | 0 |
| Rollback verdict | PASS |
| OVERALL verdict | PASS_WITH_RISK_REVIEW |

## Review Notes

The dryrun confirms that 565 Coupang product-code aliases can be inserted inside a transaction without constraint failure, then rolled back cleanly.

However, risk keyword coverage is high:

- 442 of 565 final planned candidates include at least one configured risk keyword.
- Many samples appear to be normal color/material options such as `실버`, `골드`, `핑크골드`, or plain `크리스탈`.
- Some samples include `크리스탈AB`, which should not be auto-applied before review.

The first dryrun produced no `coupang_option_no` rows because the Coupang evidence does not currently carry `channel_option_code`. A future apply would only insert `coupang_product_no` unless a confirmed Coupang option identifier is added from another source.

Codex first-pass judgment:

- Do not move directly to local apply SQL yet.
- Run a Coupang sample review that separates broad color-only rows from narrow risk rows such as `크리스탈AB`, standalone `AB`, set, quantity, and `1+1`.
- After narrow-risk exclusion or approval, rerun this dryrun with the reduced candidate set.

## Sample Buckets

The SQL outputs:

- final planned sample, up to 100
- risk keyword sample, up to 100
- duplicate excluded sample, up to 50
- evidence missing sample, up to 50
- inactive sample, up to 50

## Decision Rules

A) If the dryrun is PASS and risk samples look low-risk, proceed to sample review or write a user-approved local apply SQL.

B) If some risk patterns are unsafe, exclude those risk buckets and rerun the dryrun.

C) If duplicate or semantic warnings appear, do not proceed to apply; move to sample review.

## Completion Report Template

1. Created/modified files
2. Local DB dryrun execution status
3. Coupang evidence total
4. Coupang unique candidate count
5. Warning/duplicate/inactive/evidence missing excluded count
6. Final planned candidate count
7. Skipped existing confirmed/manual count
8. Duplicate/semantic warning/risk result
9. Dryrun inserted product/option alias count
10. Rollback result
11. OVERALL verdict
12. Codex first-pass judgment on local apply SQL readiness
13. Commit hash
14. Push status
15. `git status -s`
16. Safety confirmation
