# Coupang Narrow Risk Review Plan v1

## Purpose

This document records the narrow risk review for Coupang final planned candidates before any apply dryrun.

This step is review-only:

- No automatic matching apply.
- No `product_code.code_alias` change.
- No `product_code.sku_channel_mapping` change.
- No operating Supabase access.
- No NAS PostgreSQL access.
- No remote DB access.
- No source CSV/XLSX modification or git add.

Review SQL:

- `sql/select_coupang_narrow_risk_review_v1.sql`

## Source And Scope

Coupang evidence comes from PlayAuto source rows mapped from `쿠팡=wworks2010` to `channel_code='coupang'`.

The dryrun found 565 final planned Coupang candidates. This review targets only those 565 candidates. Warning rows and inactive rows remain excluded.

Coupang currently has no `channel_option_code` in this evidence set, so option alias count is 0. Review and future dryrun/apply planning are product-alias oriented.

## Why Broad Risk Is Not Excluded

The previous dryrun found broad risk keywords in 442 of 565 candidates. Many of these are normal option descriptors, such as:

- silver
- gold
- pink gold
- rose gold
- yellow gold
- plain crystal

Excluding all broad-risk rows would throw away most usable candidates, so this review isolates narrower risk signals only.

## Narrow Risk Criteria

Exclude from the first apply dryrun when any of these are present:

- `크리스탈AB`
- `크리AB`
- standalone `AB`
- `1+1`
- `세트`
- `수량`
- same Coupang product group contains both `크리스탈` and `크리스탈AB`

Color equivalence policy:

- `핑크골드` can be treated as `로즈골드`.
- `옐로우골드` can be treated as `골드`.
- `크리스탈` and `크리스탈AB` are different colors.
- standalone `AB` needs review before automatic confirmation.

## Execution Result

Executed locally against `product_ops_test` with `BEGIN READ ONLY` and `ROLLBACK`.

| Metric | Count |
|---|---:|
| Final planned candidate count | 565 |
| Broad risk keyword count | 442 |
| Narrow risk candidate count | 26 |
| Standalone AB count | 0 |
| Crystal AB count | 4 |
| Crystal vs CrystalAB conflict count | 17 |
| Set or quantity count | 7 |
| 1+1 count | 0 |
| Safe broad color only count | 424 |
| Final planned after narrow risk exclusion count | 539 |
| Duplicate after exclusion count | 0 |
| Semantic warning after exclusion count | 0 |
| Apply dryrun ready verdict | READY_WITH_NARROW_RISK_EXCLUSION |

## Review Notes

Most broad risk hits are normal color/material terms. The broad bucket should not be excluded as a whole.

The narrow bucket should stay out of the first Coupang apply dryrun:

- `크리스탈AB` appears in 4 candidates and should not be merged with plain `크리스탈`.
- Product-level crystal vs crystal AB mixing affects 17 candidates.
- Set or quantity wording appears in 7 candidates.
- No standalone `AB` and no `1+1` candidates were detected in the final planned set.

After excluding narrow risk candidates, the remaining 539 candidates have no duplicate pair and no semantic warning in this review query. Coupang still remains product-alias only because this evidence set has no `channel_option_code`.

## Sample Buckets

The SQL outputs:

- narrow risk sample, up to 100
- standalone AB sample
- `크리스탈AB` / `크리AB` sample
- `크리스탈` vs `크리스탈AB` conflict sample
- `세트` / `수량` / `1+1` sample
- safe broad color only sample, 50
- final planned after exclusion sample, 100
- warning excluded sample, 50
- inactive excluded sample, 50

## Decision Framework

A) narrow risk excluded clean candidates PASS -> write apply dryrun SQL.

B) narrow risk is small and samples are safe -> consider including selected sub-buckets later.

C) repeated risky pattern appears -> move that bucket to manual review.

Current intended first pass:

- Keep warning and inactive buckets excluded.
- Keep option alias insert at 0 until a confirmed Coupang option identifier exists.
- Exclude narrow risk from first apply dryrun unless reviewed.

## Completion Report Template

1. Created/modified files
2. Local DB read-only execution status
3. Final planned candidate count
4. Broad risk keyword count
5. Narrow risk candidate count
6. Standalone AB count
7. Crystal AB count
8. Crystal vs CrystalAB conflict count
9. Set or quantity count
10. 1+1 count
11. Safe broad color only count
12. Final planned after narrow risk exclusion count
13. Duplicate/semantic warning after exclusion
14. Apply dryrun ready verdict
15. Sample risk summary
16. Codex first-pass judgment on Coupang apply dryrun readiness
17. Commit hash
18. Push status
19. `git status -s`
20. Safety confirmation
