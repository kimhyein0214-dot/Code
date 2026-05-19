# MakeShop Unique Evidence AB-Excluded Apply Plan v1

## Purpose

This runbook applies only the MakeShop `241` row final planned subset to the local `product_ops_test` DB.

This apply is local-only. It is not a Supabase, NAS PostgreSQL, remote DB, import, or export workflow.

## Scope

Allowed target:

- `final_planned_count = 241`
- source: `product_code.sku_channel_mapping`
- evidence filter: `channel_code = 'makeshop'`
- code pair: `seller_product_code + channel_sku_code`

Explicitly excluded:

- full `1,247` medium candidates
- full `291` unique-evidence candidates
- full `255` clean subset before broad AB exclusion
- broad `AB` `14` rows
- duplicate evidence `18` rows
- duplicate code pair `36` rows
- evidence missing `956` rows
- strict risk keyword rows
- existing confirmed/manual/reviewer rows

## Apply Behavior

The local apply inserts `product_code.code_alias` rows only:

- `makeshop_product_code`
- `makeshop_option_code`

Each row is tagged with:

- `usage_type = confirmed`
- `source_project_ref = makeshop_unique_evidence_ab_excluded_v1`
- `source_table = apply_makeshop_unique_evidence_ab_excluded_v1`
- raw payload with selfpia SKU, own_sku, confidence tier, and guard note

Existing MakeShop aliases are not overwritten. Existing manual/reviewer evidence is not overwritten.

## Execution Order

### 1. Dryrun With Rollback

Run the apply file in rollback mode by replacing the final `COMMIT` with `ROLLBACK` in-memory:

```powershell
$sql = Get-Content -Raw -Path sql\apply_makeshop_unique_evidence_ab_excluded_v1.sql
$sql = $sql -replace '(?m)^COMMIT;\s*$', 'ROLLBACK;'
$sql | docker compose --env-file .env.local -f docker-compose.local-test.yml exec -T postgres psql -v ON_ERROR_STOP=1 -U product_ops_tester -d product_ops_test -P pager=off
```

Dryrun must show:

- `insert_or_update_planned_count = 241`
- `applied_count = 241`
- `inserted_product_alias_count = 241`
- `inserted_option_alias_count = 241`
- `skipped_existing_confirmed_count = 0`
- `skipped_existing_manual_count = 0`
- `duplicate_makeshop_code_count = 0`
- `duplicate_selfpia_to_makeshop_count = 0`
- `semantic_warning_count = 0`
- `ab_keyword_remaining_count = 0`
- `strict_risk_keyword_remaining_count = 0`

After dryrun, local DB must still have no committed rows from this apply marker.

### 2. Local Apply

Run the same file as-is only after dryrun PASS:

```powershell
Get-Content -Raw -Path sql\apply_makeshop_unique_evidence_ab_excluded_v1.sql |
  docker compose --env-file .env.local -f docker-compose.local-test.yml exec -T postgres psql -v ON_ERROR_STOP=1 -U product_ops_tester -d product_ops_test -P pager=off
```

The SQL contains a `product_ops_test` and `product_ops_tester` guard. It fails before apply if any count or risk guard is different from the approved `241` row plan.

### 3. Postcheck

Run:

```powershell
Get-Content -Raw -Path sql\postcheck_makeshop_unique_evidence_ab_excluded_v1.sql |
  docker compose --env-file .env.local -f docker-compose.local-test.yml exec -T postgres psql -v ON_ERROR_STOP=1 -U product_ops_tester -d product_ops_test -P pager=off
```

Postcheck PASS requires:

- `applied_count = 241`
- `inserted_product_alias_count = 241`
- `inserted_option_alias_count = 241`
- `applied_to_final_target_count = 241`
- `ab_excluded_applied_count = 0`
- `duplicate_evidence_applied_count = 0`
- `duplicate_code_pair_applied_count = 0`
- `evidence_missing_applied_count = 0`
- `risk_keyword_applied_count = 0`
- `duplicate_makeshop_code_count = 0`
- `duplicate_selfpia_to_makeshop_count = 0`
- `manual_overwrite_count = 0`
- `confirmed_overwrite_count = 0`
- `semantic_warning_applied_count = 0`
- `strict_risk_keyword_applied_count = 0`
- `overall_verdict = PASS`

## Decision Criteria

Proceed only if:

1. rollback dryrun passes
2. local apply inserts exactly `241` product aliases and `241` option aliases
3. postcheck verdict is PASS

Stop if:

- target count differs from `241`
- broad AB rows appear in final planned rows
- duplicate/selfpia split/semantic warning appears
- existing confirmed/manual evidence would be overwritten
- postcheck finds any excluded bucket applied

## Local Execution Result

Local execution against `product_ops_test` completed with:

| Item | Result |
|---|---:|
| dryrun `insert_or_update_planned_count` | 241 |
| dryrun `applied_count` before rollback | 241 |
| dryrun rollback marker count | 0 |
| local apply `applied_count` | 241 |
| `inserted_product_alias_count` | 241 |
| `inserted_option_alias_count` | 241 |
| `skipped_existing_confirmed_count` | 0 |
| `skipped_existing_manual_count` | 0 |
| `ab_keyword_remaining_count` | 0 |
| `strict_risk_keyword_remaining_count` | 0 |
| postcheck `overall_verdict` | PASS |

MakeShop channel-presence based auto-match rate moved from `54.55%` to `55.31%`, a `+0.76%p` increase. The broad `AB` `14` rows and all excluded evidence buckets remain unapplied.

## Safety Notes

- Local DB only: `product_ops_test`
- Expected user: `product_ops_tester`
- No DDL
- No import/export
- No source files modified
- No existing manual/confirmed overwrite
- Production Supabase, NAS PostgreSQL, and remote DBs are not used

## Completion Report Template

Report:

- generated files
- dryrun target count
- rollback result
- local apply result
- postcheck result
- final MakeShop matching rate movement
- AB excluded rows not applied
- excluded buckets not applied
- overwrite and duplicate counts
- commit and push result
