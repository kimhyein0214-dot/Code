# Smartstore Auto Match Rate After Local Apply v1

## Purpose

This document records the read-only matching-rate recalculation after the user-approved Smartstore local DB apply.

The apply was already completed on local Docker PostgreSQL only:

- database: `product_ops_test`
- user: `product_ops_tester`
- latest apply marker: `smartstore_auto_match_dryrun_v1`

No production Supabase, NAS PostgreSQL, or remote DB was used.

## Apply Recap

The local apply inserted confirmed Smartstore aliases for the dryrun-approved candidates:

- applied SKU count: `6,684`
- inserted `smartstore_product_no` alias rows: `6,684`
- inserted `smartstore_option_no` alias rows: `6,684`
- skipped existing confirmed rows: `0`
- skipped existing manual rows: `0`
- skipped blocked risk rows: `3,983`
- skipped channel absent or inactive rows: `9,093`
- semantic or quantity warning rows excluded: `8`

Postcheck verdict after apply: `PASS`.

## Before And After Rate

Before local apply, the DB-only lite summary showed Smartstore:

- channel presence based auto-match rate: `19.85%`
- channel presence based manual-review rate: `13.05%`
- channel absent or inactive separation rate: `11.50%`

After local apply, the same lite summary shows Smartstore:

| metric | value |
| --- | ---: |
| selfpia total rows | `33,291` |
| channel present rows | `29,464` |
| channel absent or inactive rows | `3,827` |
| matched confirmed rows | `7,581` |
| auto match high confidence rows | `4,953` |
| auto match medium confidence rows | `0` |
| manual review required rows | `0` |
| blocked risk rows | `13,084` |
| unknown need check rows | `3,846` |
| selfpia total based auto-match rate | `37.65%` |
| channel presence based auto-match rate | `42.54%` |
| channel presence based manual-review rate | `13.05%` |
| channel absent or inactive rate | `11.50%` |

Representative rate change:

```text
19.85% -> 42.54% = +22.69 percentage points
```

The earlier `61.57%` figure was an own_sku reclassification diagnostic estimate. The post-apply DB-only lite query is the actual recalculated local result and should be used for the current local status report.

## Safety Postcheck

Read-only postcheck after apply:

| check | count |
| --- | ---: |
| smartstore auto matched count | `6,684` |
| duplicate productNo + optionNo residual | `0` |
| duplicate selfpia SKU to productNo residual | `0` |
| manual overwrite count | `0` |
| confirmed overwrite count | `0` |
| blocked risk accidentally applied count | `0` |
| channel absent or inactive accidentally applied count | `0` |
| semantic warning accidentally applied count | `0` |
| final verdict | `PASS` |

## Remaining Work

Remaining Smartstore buckets after local apply:

- blocked risk: `13,084`
- unknown need check: `3,846`
- channel absent or inactive: `3,827`

Suggested next steps:

- Re-run Smartstore UI or product summary checks against the newly confirmed local aliases.
- Review the remaining Smartstore blocked risk `13,084` rows by cause.
- Prepare MakeShop dryrun/apply candidates separately.
- Treat any production or NAS apply as a separate approval path with its own dryrun and postcheck.

## Operating Notes

- This recalculation was read-only.
- No DB write was performed in this step.
- No local apply was rerun.
- No import or export file was generated.
- Original Excel files were not modified.
- Existing manual mappings were not overwritten.
