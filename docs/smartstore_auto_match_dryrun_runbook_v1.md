# Smartstore Auto Match Dryrun Runbook v1

## Purpose

This runbook covers the rollback-only dryrun for Smartstore auto-match candidates.

The target set is the `auto_match_high_confidence` and `auto_match_medium_confidence` candidates from the Smartstore own_sku reclassification work. The expected promoted set is about `6,692` rows before final dryrun guards.

This is not a local apply step. It is a validation step before any approved local apply.

## Scope

Input evidence comes from the current local DB tables only:

- `product_code.v_sku_canonical`
- `product_code.code_alias`
- `product_code.sku_channel_mapping`
- `product_code.product_image`

Excluded from dryrun apply planning:

- existing confirmed Smartstore evidence
- existing manual or reviewer evidence
- `channel_absent_or_inactive`
- `remain_blocked_risk`
- semantic warning rows
- productNo + optionNo duplicate rows
- selfpia SKU to productNo split rows

## Execution

Run only on local Docker DB:

- database: `product_ops_test`
- user: `product_ops_tester`
- port: `localhost:5433`

The SQL file starts with `BEGIN`, switches the transaction to read-only mode, outputs summary counts, then ends with `ROLLBACK`.

Expected command shape:

```powershell
Get-Content .\sql\dryrun_smartstore_auto_match_candidates_v1.sql |
  docker compose --env-file .env.local -f docker-compose.local-test.yml exec -T postgres `
    psql -U product_ops_tester -d product_ops_test
```

Do not run this against production Supabase, NAS PostgreSQL, or any remote DB.

## Summary Items To Check

The dryrun output must include:

- `candidate_total`
- `high_candidate_count`
- `medium_candidate_count`
- `insert_or_update_planned_count`
- `skipped_existing_confirmed_count`
- `skipped_existing_manual_count`
- `skipped_blocked_risk_count`
- `skipped_channel_absent_or_inactive_count`
- `duplicate_product_option_count`
- `duplicate_selfpia_product_count`
- `own_sku_multi_conflict_count`
- `semantic_warning_count`
- `expected_after_count`
- `rollback_after_count`
- `rollback_verdict`

## Pass Criteria

The dryrun is acceptable only if:

- `duplicate_product_option_count = 0`
- `duplicate_selfpia_product_count = 0`
- existing manual evidence is skipped, not overwritten
- existing confirmed evidence is skipped, not overwritten
- blocked risk rows are not planned
- channel absent or inactive rows are not planned
- semantic warning rows are not planned
- `rollback_after_count = 0`
- `rollback_verdict = PASS`

If `insert_or_update_planned_count` is lower than `candidate_total`, the difference must be explained by skip guards such as manual, confirmed, semantic, or quantity/set safety checks.

## Failure Handling

If any pass criterion fails:

- do not apply
- keep the SQL in dryrun mode
- tighten only the failing guard or candidate bucket
- rerun validation, sample review, and dryrun
- keep `remain_blocked_risk` and uncertain rows out of the apply path

## Postcheck

`sql/postcheck_smartstore_auto_match_candidates_v1.sql` is a read-only postcheck draft for a future approved local apply. It expects future applied rows to carry a clear project marker so accidental overwrite or duplicate conditions can be counted.

Do not run postcheck as evidence of success until a separate local apply has been explicitly approved and completed.

## Operating Rules

The required flow remains:

```text
validate -> sample review -> dryrun -> user approval -> local apply -> postcheck
```

Before user approval:

- no local apply
- no production or NAS execution
- no import or export files
- no original Excel changes
- no overwrite of existing manual mappings
- no overwrite of existing confirmed aliases
- candidates must not be treated as confirmed
- `export_allowed` must not be enabled
- `reviewer_decision` must remain `pending`
