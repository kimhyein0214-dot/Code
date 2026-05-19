# MakeShop Auto Match Dryrun Runbook v1

## Purpose

This runbook prepares a rollback-only dryrun for MakeShop auto-match candidates.

Current MakeShop diagnostic status:

- current channel presence based auto-match rate: `54.55%`
- expected rate after reclassification: `58.48%`
- expected gain: `+3.94 percentage points`
- high confidence candidates: `0`
- medium confidence candidates: `1,247`

The high confidence count is `0` because the current DB-only MakeShop evidence does not provide enough unique MakeShop product/option code evidence to promote rows into a stronger tier. The 1,247 rows are medium confidence because they rely on own_sku reclassification, same-family repetition, normalization, or limited MakeShop evidence.

Because MakeShop code evidence is incomplete, these 1,247 medium rows are not yet a direct confirmed-code apply set. They are a dryrun-ready review set for deciding whether an apply design can safely infer or attach MakeShop codes later.

## Scope

The workflow uses current local DB tables only:

- `product_code.v_sku_canonical`
- `product_code.code_alias`
- `product_code.sku_channel_mapping`
- `product_code.product_image`

It does not use stage tables, Excel imports, CSV files, exports, or production data.

Excluded from dryrun planning:

- existing confirmed MakeShop evidence
- existing manual or reviewer evidence
- `blocked_risk` residual rows
- `channel_absent_or_inactive`
- semantic warning rows
- duplicate MakeShop code rows
- selfpia SKU to MakeShop code split rows

## SQL Files

- `sql/select_makeshop_auto_match_candidates_v1.sql`
  - SELECT-only candidate summary and limited samples.
- `sql/validate_makeshop_auto_match_candidates_v1.sql`
  - SELECT-only validation counts before dryrun.
- `sql/dryrun_makeshop_auto_match_candidates_v1.sql`
  - `BEGIN` + read-only transaction + summary + `ROLLBACK`.
- `sql/postcheck_makeshop_auto_match_candidates_v1.sql`
  - SELECT-only postcheck draft for a future approved local apply.

## Execution

Run only on local Docker DB:

- database: `product_ops_test`
- user: `product_ops_tester`
- port: `localhost:5433`

Expected command shape:

```powershell
Get-Content .\sql\dryrun_makeshop_auto_match_candidates_v1.sql |
  docker compose --env-file .env.local -f docker-compose.local-test.yml exec -T postgres `
    psql -U product_ops_tester -d product_ops_test
```

Do not run this against production Supabase, NAS PostgreSQL, or any remote DB.

## Pass Criteria

Dryrun can pass only if:

- `duplicate_makeshop_code_count = 0`
- `duplicate_selfpia_to_makeshop_count = 0`
- existing manual evidence is not overwritten
- existing confirmed evidence is not overwritten
- blocked risk rows are not planned
- channel absent or inactive rows are not planned
- semantic warning rows are not planned
- `rollback_after_count = 0`
- `rollback_verdict = PASS`

The current local dryrun result is:

- `candidate_total = 1,247`
- `high_candidate_count = 0`
- `medium_candidate_count = 1,247`
- `insert_or_update_planned_count = 1,247`
- `duplicate_makeshop_code_count = 0`
- `duplicate_selfpia_to_makeshop_count = 0`
- `own_sku_multi_conflict_count = 1,247`
- `semantic_warning_count = 0`
- `rollback_after_count = 0`
- `rollback_verdict = PASS`

## Failure Handling

If any pass criterion fails:

- do not apply
- keep the SQL in dryrun mode
- tighten the failing candidate bucket
- rerun validate and dryrun
- keep residual blocked risk out of the apply path

## Operating Rules

Required flow:

```text
validate -> dryrun -> user approval -> local apply -> postcheck
```

Before user approval:

- no local apply
- no `COMMIT`
- no production or NAS execution
- no import or export files
- no original Excel changes
- no overwrite of existing manual mappings
- no overwrite of existing confirmed aliases
- candidates must not be treated as confirmed
- `export_allowed` must not be enabled
- `reviewer_decision` must remain `pending`
