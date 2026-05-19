# MakeShop Unique Evidence Sample Review Plan v1

## Purpose

This is a read-only sample/detail review for the MakeShop unique-evidence clean subset before any local apply SQL is written.

The previous dryrun split the MakeShop medium candidates as follows:

- source medium candidates: `1,247`
- unique own_sku-based MakeShop evidence: `291`
- duplicate own_sku-based evidence excluded: `18`
- evidence missing excluded: `956`
- duplicate planned code pair excluded: `36`
- strict risk keyword excluded: `8`
- clean planned subset: `255`

This step does not apply anything. It only rebuilds the same `255` row clean subset and prints summary/sample rows so a reviewer can check product, option, own_sku, selfpia SKU, and MakeShop code pair in one row.

## Why The Full Sets Are Not Apply Targets

The full `1,247` candidates are not apply-ready because direct MakeShop code evidence was `0`.

The full `291` unique-evidence rows are also not apply-ready because:

- `36` rows share a planned MakeShop code pair with more than one candidate SKU
- `8` rows hit strict risk keywords or semantic warning rules

The `255` clean subset is the first practical apply-candidate subset, but it still needs human sample review and explicit user approval before a separate local apply SQL task.

## Evidence Source

MakeShop code evidence comes from:

- `product_code.sku_channel_mapping`

Required relation:

- `channel_code = 'makeshop'`
- `own_sku_code` joins from the candidate row
- exactly one `seller_product_code + channel_sku_code` pair is available

The review SQL does not update `code_alias` and does not create an apply plan.

## Execution

Run only against the local DB:

```powershell
$sql = "BEGIN READ ONLY;`n" + (Get-Content -Raw -Path sql\select_makeshop_unique_evidence_sample_review_v1.sql) + "`nROLLBACK;`n"
$sql | docker compose --env-file .env.local -f docker-compose.local-test.yml exec -T postgres psql -U product_ops_tester -d product_ops_test -P pager=off
```

The SQL itself is SELECT-only. The read-only transaction wrapper is used at execution time.

Expected guard:

- `current_database() = product_ops_test`
- `current_user = product_ops_tester`
- `transaction_read_only = on`

Production Supabase, NAS PostgreSQL, and remote DBs must not be used.

## Result Summary

Read-only execution result:

| Metric | Count | Meaning |
|---|---:|---|
| `source_candidate_total` | 1,247 | original MakeShop medium candidate baseline |
| `unique_evidence_candidate_count` | 291 | own_sku resolves to one existing MakeShop code pair |
| `duplicate_evidence_excluded_count` | 18 | own_sku maps to multiple MakeShop code pairs |
| `evidence_missing_excluded_count` | 956 | no direct or unique own_sku-based MakeShop evidence |
| `duplicate_code_pair_excluded_count` | 36 | planned code pair is not 1:1 |
| `risk_keyword_excluded_count` | 8 | strict semantic/risk exclusion |
| `clean_planned_subset_count` | 255 | sample review target |
| `skipped_existing_confirmed_count` | 0 | no confirmed overwrite |
| `skipped_existing_manual_count` | 0 | no manual overwrite |
| `duplicate_makeshop_code_count` | 0 | clean subset has no duplicate MakeShop code pair |
| `duplicate_selfpia_to_makeshop_count` | 0 | clean subset has no selfpia split |
| `semantic_warning_count` | 0 | clean subset has no strict semantic warning |
| `review_verdict` | 1 | structural review query PASS |

## Risk Keyword Recheck

Clean subset risk keyword recheck:

| Keyword check | Count | Interpretation |
|---|---:|---|
| `clean_crystal_keyword_count` | 0 | no crystal text in clean subset |
| `clean_crystal_ab_keyword_count` | 0 | no crystalAB/크리AB text in clean subset |
| `clean_ab_keyword_count` | 14 | broad AB text remains and should be sampled or excluded before apply |
| `clean_white_gold_keyword_count` | 0 | no white gold text |
| `clean_silver_keyword_count` | 0 | no silver text in clean subset options |
| `clean_gold_keyword_count` | 0 | no broad gold text in clean subset options |
| `clean_rose_gold_keyword_count` | 0 | no rose gold text |
| `clean_pink_gold_keyword_count` | 0 | no pink gold text in clean subset options |
| `clean_set_keyword_count` | 0 | no set text |
| `clean_one_plus_one_keyword_count` | 0 | no 1+1 text |
| `clean_quantity_keyword_count` | 0 | no quantity text |

Important interpretation:

- `골드` and `실버` are broad words and are not automatic exclusion by themselves.
- `핑크골드` and `로즈골드` can be normalized together.
- `골드` and `옐로우골드` can be normalized together.
- `크리스탈` and `크리스탈AB` must remain distinct.
- The broad `AB` count of `14` should be reviewed before any local apply SQL.

## Sample Buckets

The SQL outputs limited sample/detail rows:

| Sample bucket | Bucket count | Purpose |
|---|---:|---|
| `clean_subset_sample` | 255 | 80-row clean subset sample |
| `same_product_family_clean_sample` | 151 | same product family repeat check |
| `cross_product_possible_clean_sample` | 104 | cross-product-looking own_sku repeat check |
| `seller_product_code_group_sample` | 255 | compare rows sharing MakeShop product code |
| `channel_sku_code_sample` | 255 | compare MakeShop option/SKU code |
| `selfpia_sku_sample` | 255 | selfpia SKU ordered review |
| `duplicate_code_pair_excluded_sample` | 36 | excluded duplicate planned code pair rows |
| `evidence_missing_excluded_sample` | 956 | excluded missing-evidence rows |
| `risk_keyword_sample` | 22 | broad risk keyword examples from unique evidence rows |

The clean subset examples show product/option/selfpia/own_sku/MakeShop code pair side by side, such as:

- selfpia `5444-3`, own_sku `GPA-5-03_3`, MakeShop product `972165`, option `972165-1`
- selfpia `5444-4`, own_sku `GPA-5-03_4`, MakeShop product `972165`, option `972165-2`

## Decision Branches

### A. Sample Review PASS

If reviewers accept the sample output and the broad `AB` rows are either approved or excluded, a later user-approved task may write a local apply SQL for the approved subset only.

### B. Some Risk Found

If the broad `AB` rows or cross-product-looking rows are risky, exclude those rows and run a second dryrun/sample review.

Current first-pass recommended exclusion before apply design:

- review or exclude the `14` broad `AB` rows

### C. Structural Problem Found

If product names, option names, own_sku, or MakeShop code pairs do not line up in samples, do not apply the 255 rows. Move the affected bucket to manual review or require MakeShop source evidence.

## Current First-Pass Recommendation

Do not proceed to local apply for all `255` rows as-is.

Recommended next step:

- review the `14` broad `AB` rows
- if they are safe, a local apply SQL can be drafted for the 255 rows after explicit user approval
- if they are not safe, exclude them and draft only the remaining `241` rows after a second dryrun

## Safety Notes

- This step is read-only.
- No apply SQL is written.
- No confirmed aliases are changed.
- No existing confirmed/manual values are overwritten.
- No DDL is used.
- No import/export files are created.
- Unrelated pending SQL and untracked files are not touched.

## Completion Report Template

Report:

- generated files
- local read-only execution environment
- `clean_planned_subset_count`
- sample bucket counts
- remaining risk keyword counts
- sample risk observations
- whether local apply can proceed
- commit and push result
