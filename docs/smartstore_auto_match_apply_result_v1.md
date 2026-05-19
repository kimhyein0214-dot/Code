# Smartstore Auto Match Local Apply Result v1

## Purpose

This document records the user-approved local DB apply for Smartstore auto-match candidates.

The apply was limited to local Docker PostgreSQL:

- database: `product_ops_test`
- user: `product_ops_tester`
- project marker: `smartstore_auto_match_dryrun_v1`

No production Supabase, NAS PostgreSQL, or remote DB was used.

## Apply Target

The source candidate set came from the Smartstore dryrun workflow:

- candidate total: `6,692`
- high confidence: `3,928`
- medium confidence: `2,764`
- final planned local apply rows: `6,684`

The following rows were excluded from apply:

- existing confirmed Smartstore evidence
- existing manual or reviewer evidence
- `remain_blocked_risk`
- `channel_absent_or_inactive`
- semantic or quantity warning rows
- duplicate productNo + optionNo rows
- selfpia SKU to productNo split rows

The semantic or quantity warning guard excluded `8` rows from the candidate set.

## Dryrun Basis

The prior dryrun passed with:

- `candidate_total = 6,692`
- `insert_or_update_planned_count = 6,684`
- `duplicate_product_option_count = 0`
- `duplicate_selfpia_product_count = 0`
- `skipped_existing_confirmed_count = 0`
- `skipped_existing_manual_count = 0`
- `semantic_warning_count = 8`
- `rollback_after_count = 0`
- `rollback_verdict = PASS`

## Local Apply Result

The local apply inserted confirmed Smartstore aliases into `product_code.code_alias`.

Applied counts:

- applied SKU count: `6,684`
- inserted `smartstore_product_no` alias rows: `6,684`
- inserted `smartstore_option_no` alias rows: `6,684`

Skip and guard counts:

- skipped existing confirmed: `0`
- skipped existing manual: `0`
- skipped blocked risk: `3,983`
- skipped channel absent or inactive: `9,093`
- semantic or quantity warning rows not applied: `8`
- duplicate productNo + optionNo: `0`
- duplicate selfpia SKU to productNo: `0`

## Postcheck Result

Postcheck result:

- smartstore auto matched count: `6,684`
- duplicate productNo + optionNo residual: `0`
- duplicate selfpia SKU to productNo residual: `0`
- manual overwrite count: `0`
- confirmed overwrite count: `0`
- blocked risk accidentally applied count: `0`
- channel absent or inactive accidentally applied count: `0`
- semantic warning accidentally applied count: `0`
- final verdict: `PASS`

The postcheck query was adjusted to avoid counting the new apply marker payload itself as an existing manual marker. It now checks manual markers only on pre-existing rows.

## Safety Notes

- This was a local-only apply.
- Existing confirmed aliases were not overwritten.
- Existing manual or reviewer evidence was not overwritten.
- Blocked risk rows were not applied.
- Channel absent or inactive rows were not applied.
- Semantic or quantity warning rows were not applied.
- No import or export files were generated.
- Original Excel files were not changed.

## Next Steps

- Refresh Smartstore local matching-rate summary to confirm the new local rate.
- Check the product/SKU UI summary against the newly confirmed Smartstore aliases.
- Prepare MakeShop dryrun only after separate review.
- Any production or NAS apply requires a separate explicit approval and a separate runbook.
