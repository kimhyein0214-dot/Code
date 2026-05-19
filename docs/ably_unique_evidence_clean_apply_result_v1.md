# Ably Clean Unique Evidence Local Apply Result v1

## Purpose

Apply Ably clean unique evidence to the local DB only.

This apply is limited to `product_ops_test` and only the clean 2,273 candidates from the previous dryrun.

This is not an operating Supabase apply, not a NAS PostgreSQL apply, and not a remote DB apply.

## Scope

The full final planned pool was 3,024 candidates, but only 2,273 are eligible for this local apply.

3,024 full apply is forbidden because 751 candidates remain in narrow risk buckets:

- `크리스탈AB` / `크리AB`
- standalone `AB`
- crystal vs crystal AB product-group conflict
- set, quantity, or `1+1`

These excluded buckets also remain outside this apply:

- source conflict: 4,813
- warning: 8,149
- duplicate SKU: 312
- inactive: 12,860
- evidence missing: 5,584
- narrow risk: 751

Broad color-only words are not excluded by themselves:

- silver
- gold
- pink gold
- rose gold
- yellow gold

## Files

- `sql/apply_ably_unique_evidence_clean_v1.sql`
- `sql/postcheck_ably_unique_evidence_clean_v1.sql`

## Result

Executed against local `product_ops_test` only.

Apply transaction:

- guard: PASS
- precheck: PASS
- commit guard: PASS
- COMMIT: completed

Postcheck verdict: PASS

| Metric | Count / Verdict |
|---|---:|
| Precheck source final planned count | 3,024 |
| Precheck narrow risk excluded count | 751 |
| Precheck final clean planned count | 2,273 |
| Inserted product alias count | 2,273 |
| Inserted option alias count | 561 |
| Total inserted code alias count | 2,834 |
| Inserted sku_channel_mapping count | 0 |
| Applied outside final clean count | 0 |
| Existing confirmed/manual overwrite count | 0 |
| Duplicate Ably code count | 0 |
| Duplicate Selfpia-to-Ably count | 0 |
| Semantic warning count | 0 |
| Narrow risk applied count | 0 |
| Source conflict applied count | 0 |
| Warning applied count | 0 |
| Duplicate SKU applied count | 0 |
| Inactive applied count | 0 |
| Evidence missing applied count | 0 |
| Applied candidate rate of Ably evidence | 9.53% |
| Applied candidate rate of final planned | 75.17% |
| OVERALL verdict | PASS |

## Notes

The apply inserted only `product_code.code_alias` rows:

- `ably_product_no`: 2,273 rows
- `ably_option_no`: 561 rows

`product_code.sku_channel_mapping` remained unchanged for Ably: 0 rows.

The option alias count is lower than the product alias count because PlayAuto-only evidence often has no Ably option code. This was expected from the dryrun and was enforced in the apply SQL.

The local Ably clean evidence apply moved the confirmed local Ably alias count from 0 to 2,834 code alias rows. At the candidate level, 2,273 clean candidates are now represented, which is 75.17% of the 3,024 final planned pool after source-conflict exclusions and 9.53% of all Ably channel evidence rows.

## Result Criteria

PASS requires:

- local DB guard PASS
- product alias insert count = 2,273
- option alias insert count = 561
- total code_alias insert count = 2,834
- sku_channel_mapping insert count = 0
- existing confirmed/manual overwrite count = 0
- excluded bucket applied counts = 0
- duplicate and semantic warning counts = 0

## Completion Report Template

1. Created/modified files
2. Local DB apply execution status
3. Precheck target count
4. Inserted product alias count
5. Inserted option alias count
6. Total inserted code_alias count
7. sku_channel_mapping insert count
8. Postcheck result
9. Excluded bucket non-application confirmation
10. Existing confirmed/manual overwrite 0 confirmation
11. Duplicate/risk/semantic warning 0 confirmation
12. Ably auto match rate change
13. OVERALL verdict
14. Commit hash
15. Push status
16. `git status -s`
17. Safety confirmation
