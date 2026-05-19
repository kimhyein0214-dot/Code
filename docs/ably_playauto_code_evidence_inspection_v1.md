# Ably / PlayAuto Code Evidence Inspection v1

## Purpose

This document records a read-only local DB inspection for Ably and PlayAuto code evidence after the first Smartstore and MakeShop local auto-match applies.

This is a diagnosis step only. It does not write apply SQL, does not change confirmed mappings, and does not import or export files.

## Current Project State

Smartstore:

- local apply completed
- additional applied rows: `6,684`
- channel-presence based auto-match rate: `19.85% -> 42.54%`
- postcheck: PASS

MakeShop:

- local apply completed
- additional applied rows: `241`
- channel-presence based auto-match rate: `54.55% -> 55.31%`
- postcheck: PASS
- broad `AB` `14` rows, duplicate/evidence-missing/risk rows were not applied

## Execution

Run only against local DB:

```powershell
$sql = "BEGIN READ ONLY;`n" + (Get-Content -Raw -Path sql\inspect_ably_playauto_code_evidence_sources_v1.sql) + "`nROLLBACK;`n"
$sql | docker compose --env-file .env.local -f docker-compose.local-test.yml exec -T postgres psql -v ON_ERROR_STOP=1 -U product_ops_tester -d product_ops_test -P pager=off
```

Observed guard:

- `current_database() = product_ops_test`
- `current_user = product_ops_tester`
- `transaction_read_only = on`
- database guard: PASS
- transaction ended with `ROLLBACK`

Production Supabase, NAS PostgreSQL, and remote DBs were not used.

## Catalog Findings

The inspection used `information_schema.columns` and found only the existing generic product-code relations:

- `product_code.code_alias`
- `product_code.sku_channel_mapping`
- `product_code.v_sku_canonical`
- `product_code.sku_master`
- `product_code.product_master`
- `product_code.product_image`
- Smartstore stage tables already present in the local schema

No Ably-specific or PlayAuto-specific source/stage table was found in the local DB.

## Channel Code Distribution

`product_code.sku_channel_mapping` currently has these channel codes:

| channel_code | rows | distinct sku_id | seller_product non-null | seller_product distinct | channel_sku non-null | channel_sku distinct | own_sku non-null | own_sku distinct |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `local_test_smartstore` | 2 | 2 | 2 | 1 | 2 | 2 | 2 | 2 |
| `makeshop` | 17,568 | 17,279 | 17,568 | 3,891 | 17,568 | 17,568 | 17,568 | 15,062 |

No `ably`, `a-bly`, `playauto`, `play_auto`, `play-auto`, or similar channel code rows were found.

## Code Alias Findings

`product_code.code_alias` has no Ably/PlayAuto code_system rows:

| channel group | matching code_system rows |
|---|---:|
| Ably | 0 |
| PlayAuto | 0 |

This means there is no direct code_alias evidence for either channel in the current local DB.

## Ably Summary

| Metric | Count | Meaning |
|---|---:|---|
| `selfpia_total_rows` | 33,289 | canonical selfpia SKU rows considered |
| `direct_sku_channel_mapping_rows` | 0 | no direct `sku_channel_mapping` evidence |
| `direct_code_alias_rows` | 0 | no direct `code_alias` evidence |
| `direct_mapping_rows` | 0 | no direct channel mapping or alias evidence |
| `own_sku_join_to_existing_mapping_rows` | 0 | no own_sku join to existing Ably mapping |
| `unique_own_sku_evidence_candidate_rows` | 0 | no DB-only auto-match candidate |
| `duplicate_own_sku_evidence_rows` | 0 | no duplicate evidence because no evidence exists |
| `duplicate_code_pair_risk_rows` | 0 | no code-pair risk because no code pairs exist |
| `semantic_warning_rows` | 78 | keyword risk count in the full selfpia universe, not Ably evidence |
| `manual_marker_rows` | 6,846 | generic manual/reviewer markers in the SKU universe |
| `evidence_missing_rows` | 33,289 | no Ably evidence in local DB |

## PlayAuto Summary

| Metric | Count | Meaning |
|---|---:|---|
| `selfpia_total_rows` | 33,289 | canonical selfpia SKU rows considered |
| `direct_sku_channel_mapping_rows` | 0 | no direct `sku_channel_mapping` evidence |
| `direct_code_alias_rows` | 0 | no direct `code_alias` evidence |
| `direct_mapping_rows` | 0 | no direct channel mapping or alias evidence |
| `own_sku_join_to_existing_mapping_rows` | 0 | no own_sku join to existing PlayAuto mapping |
| `unique_own_sku_evidence_candidate_rows` | 0 | no DB-only auto-match candidate |
| `duplicate_own_sku_evidence_rows` | 0 | no duplicate evidence because no evidence exists |
| `duplicate_code_pair_risk_rows` | 0 | no code-pair risk because no code pairs exist |
| `semantic_warning_rows` | 78 | keyword risk count in the full selfpia universe, not PlayAuto evidence |
| `manual_marker_rows` | 6,846 | generic manual/reviewer markers in the SKU universe |
| `evidence_missing_rows` | 33,289 | no PlayAuto evidence in local DB |

## Interpretation

Current local DB evidence is not enough to create Ably or PlayAuto auto-match candidates.

There are no channel mapping rows, no channel code aliases, and no own_sku-based join path for either channel. The sample output therefore only shows `evidence_missing_sample` rows: selfpia SKU, own_sku, product name, and option name exist, but product/option code candidates are blank.

Do not treat the full `33,289` evidence-missing rows as manual review targets. Without Ably/PlayAuto source evidence, these rows are better classified as unknown/channel evidence missing, not failed matches.

## Decision Branches

### A. Evidence Sufficient

Not applicable for the current local DB. Ably and PlayAuto both have zero usable DB-only code evidence.

### B. Evidence Partial

Not applicable yet. There are no unique own_sku evidence candidates to split into a smaller dryrun subset.

### C. Evidence Missing

Recommended next step:

- design a read-only source/stage import plan for Ably and PlayAuto evidence
- expected source fields should include channel product code, channel option/SKU code, own_sku, selfpia SKU if available, product name, option name, price/stock if useful, and source row metadata
- after stage evidence exists, rerun candidate validation and only then consider channel-specific dryrun SQL

## Safety Notes

- Read-only inspection only
- No apply SQL written
- No DB changes
- No DDL
- No import/export files
- No source xlsx/csv/xml edits
- Existing confirmed/manual mappings not overwritten
- Existing pending SQL and unrelated untracked files not touched

## Completion Report Template

Report:

- generated files
- local DB read-only execution status
- Ably table/channel/code findings
- PlayAuto table/channel/code findings
- row/non-null/distinct counts
- existing code_alias status
- auto-match candidate feasibility
- duplicate/risk/channel_absent summary
- next decision branch
- commit and push result
