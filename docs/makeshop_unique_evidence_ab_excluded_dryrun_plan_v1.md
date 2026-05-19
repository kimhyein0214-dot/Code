# MakeShop Unique Evidence AB-Excluded Dryrun Plan v1

## Purpose

This plan narrows the MakeShop unique-evidence clean subset from `255` rows to a conservative `241` row dryrun target by excluding `14` broad `AB` keyword rows.

This is not an apply step. It does not write confirmed aliases, does not create local apply SQL, and does not change any existing confirmed or manual mapping.

## Current Baseline

The prior MakeShop review found:

| Metric | Count | Meaning |
|---|---:|---|
| `source_candidate_total` | 1,247 | original MakeShop medium candidate baseline |
| `unique_evidence_candidate_count` | 291 | own_sku resolves to one existing MakeShop code pair |
| `duplicate_evidence_excluded_count` | 18 | own_sku maps to multiple MakeShop code pairs |
| `evidence_missing_excluded_count` | 956 | no direct or unique own_sku-based MakeShop evidence |
| `duplicate_code_pair_excluded_count` | 36 | planned code pair is not 1:1 |
| `risk_keyword_excluded_count` | 8 | strict semantic/risk exclusion |
| `clean_subset_before_ab_exclusion_count` | 255 | clean subset before broad AB exclusion |
| `ab_keyword_excluded_count` | 14 | broad AB rows excluded for conservative handling |
| `final_planned_count` | 241 | second dryrun target |

The full `1,247`, `291`, and `255` row sets must not be applied as-is:

- `1,247` rows include `956` rows without MakeShop code evidence.
- `291` rows include duplicate code-pair and risk exclusions.
- `255` rows still include `14` broad `AB` keyword rows.

The `241` row subset is the only candidate set for this dryrun, and it still requires explicit user approval before any later local apply SQL is written.

## Evidence Source

MakeShop code evidence comes from existing local DB mappings:

- relation: `product_code.sku_channel_mapping`
- required filter: `channel_code = 'makeshop'`
- key columns:
  - `seller_product_code`
  - `channel_sku_code`
  - `own_sku_code`
  - `sku_id`

The dryrun requires that each candidate own_sku resolves to exactly one MakeShop `seller_product_code + channel_sku_code` pair, then removes rows with duplicate planned code pairs, semantic warnings, existing confirmed/manual status, and broad `AB` text.

## Execution

Run only against the local DB:

```powershell
Get-Content -Raw -Path sql\dryrun_makeshop_unique_evidence_ab_excluded_v1.sql |
  docker compose --env-file .env.local -f docker-compose.local-test.yml exec -T postgres psql -U product_ops_tester -d product_ops_test -P pager=off
```

Expected guard:

- `current_database() = product_ops_test`
- `current_user = product_ops_tester`
- `transaction_read_only = on`
- final statement is `ROLLBACK`

Production Supabase, NAS PostgreSQL, and remote DBs must not be used.

## Pass Criteria

The dryrun passes only when:

| Check | Expected |
|---|---:|
| `source_candidate_total` | 1,247 |
| `unique_evidence_candidate_count` | 291 |
| `clean_subset_before_ab_exclusion_count` | 255 |
| `ab_keyword_excluded_count` | 14 |
| `final_planned_count` | 241 |
| `skipped_existing_confirmed_count` | 0 |
| `skipped_existing_manual_count` | 0 |
| `duplicate_makeshop_code_count` | 0 |
| `duplicate_selfpia_to_makeshop_count` | 0 |
| `semantic_warning_count` | 0 |
| `strict_risk_keyword_remaining_count` | 0 |
| `rollback_after_count` | 0 |
| `rollback_verdict` | PASS |
| `overall_verdict` | PASS |

The broad `AB` rows stay out of the final planned subset and are printed as a separate `ab_keyword_excluded_sample` bucket for manual review.

## Sample Review

The SQL prints limited sample buckets, including:

- `final_planned_sample`: up to 80 rows from the final `241`
- `ab_keyword_excluded_sample`: all `14` broad AB rows
- `duplicate_code_pair_excluded_sample`
- `evidence_missing_excluded_sample`
- `seller_product_code_group_sample`
- `channel_sku_code_sample`
- `selfpia_sku_sample`

Each sample row shows product name, option name, own_sku, selfpia SKU, and MakeShop code pair in one line.

## Decision Branches

### A. Dryrun PASS And No Risk Found

If this dryrun passes and sample review finds no additional risk in the final `241` rows, a later user-approved task may write a local-only apply SQL for those `241` rows.

### B. Some Risk Found

If final planned samples show risky product/option semantics, exclude the risky rows and run another dryrun with the narrower subset.

### C. Structural Problem Found

If MakeShop code pairs, selfpia SKU, own_sku, product names, or option names do not line up, do not apply the `241` rows. Move the affected rows to manual review or require MakeShop source evidence.

## Safety Notes

- This step is dryrun only.
- No apply SQL is written.
- No confirmed aliases are changed.
- No existing confirmed/manual values are overwritten.
- No DDL is used.
- No import/export files are created.
- The transaction is read-only and ends with `ROLLBACK`.
- Existing pending SQL and unrelated untracked files are not touched.

## Completion Report Template

Report:

- generated files
- local DB dryrun status
- `source_candidate_total`
- `unique_evidence_candidate_count`
- `clean_subset_before_ab_exclusion_count`
- `ab_keyword_excluded_count`
- `final_planned_count`
- skipped existing confirmed/manual counts
- duplicate/risk/semantic warning counts
- rollback result
- overall verdict
- sample risk observations
- whether local apply SQL design can proceed
- commit and push result
