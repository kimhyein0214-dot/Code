# Coupang Clean Unique Evidence Local Apply Result v1

## Purpose

Apply Coupang clean unique evidence to the local DB only.

This apply is limited to `product_ops_test` and only the clean 539 candidates from the previous dryrun.

This is not an operating Supabase apply, not a NAS PostgreSQL apply, and not a remote DB apply.

## Scope

The full Coupang final planned pool was 565 candidates, but only 539 were eligible for this local apply.

565 full apply was forbidden because 26 candidates remained in narrow risk buckets:

- `crystal AB` / `crystal-AB` style values
- crystal vs crystal AB product-group conflict
- set, quantity, or `1+1`

These excluded buckets also remained outside this apply:

- warning: 140
- inactive: 718
- narrow risk: 26

Coupang currently had no `channel_option_code` in this evidence set, so this apply was product-alias only:

- inserted `coupang_product_no`
- did not insert `coupang_option_no`
- did not insert `product_code.sku_channel_mapping`

## Files

- `sql/apply_coupang_unique_evidence_clean_v1.sql`
- `sql/postcheck_coupang_unique_evidence_clean_v1.sql`

## Result

Local apply and postcheck were executed against `product_ops_test` as `product_ops_tester`.

The apply precheck passed, inserted only `coupang_product_no`, and committed after the commit guard passed.
The postcheck verdict was PASS.

| Metric | Count / Verdict |
|---|---:|
| Precheck source final planned count | 565 |
| Precheck narrow risk excluded count | 26 |
| Precheck final clean planned count | 539 |
| Inserted product alias count | 539 |
| Inserted option alias count | 0 |
| Total inserted code alias count | 539 |
| Inserted sku_channel_mapping count | 0 |
| Applied outside final clean count | 0 |
| Existing confirmed/manual overwrite count | 0 |
| Duplicate Coupang code count | 0 |
| Duplicate Selfpia-to-Coupang count | 0 |
| Semantic warning count | 0 |
| Narrow risk applied count | 0 |
| Warning applied count | 0 |
| Inactive applied count | 0 |
| Applied candidate rate of Coupang evidence | 42.01% |
| Applied candidate rate of final planned | 95.40% |
| OVERALL verdict | PASS |

## Notes

- The 26 narrow-risk candidates remain excluded.
- The 140 warning rows and 718 inactive rows remain excluded.
- No `coupang_option_no` rows were inserted because this evidence set had no option alias candidates.
- No `product_code.sku_channel_mapping` rows were inserted.
- This was local DB work only; it is not an operating DB, NAS, or remote DB change.

## Result Criteria

PASS required:

- local DB guard PASS
- product alias insert count = 539
- option alias insert count = 0
- total code_alias insert count = 539
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
12. Coupang auto match rate change
13. OVERALL verdict
14. Commit hash
15. Push status
16. `git status -s`
17. Safety confirmation
