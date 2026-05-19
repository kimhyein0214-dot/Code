# MakeShop Code Evidence Source Inspection v1

## Purpose

This note records the read-only inspection for MakeShop code evidence before any local apply design.

The current MakeShop auto-match dryrun passed structurally, but the sample review showed:

- `candidate_total`: 1,247
- `medium_candidate_count`: 1,247
- `makeshop_code_present_count`: 0
- `makeshop_code_missing_count`: 1,247

Because high confidence is `0` and direct MakeShop code evidence is missing for all 1,247 candidates, these rows must not be applied as confirmed mappings yet.

## Execution Scope

Use:

```powershell
$sql = "BEGIN READ ONLY;`n" + (Get-Content -Raw -Path sql\inspect_makeshop_code_evidence_sources_v1.sql) + "`nROLLBACK;`n"
$sql | docker compose --env-file .env.local -f docker-compose.local-test.yml exec -T postgres psql -U product_ops_tester -d product_ops_test -P pager=off
```

Guard result from the local read-only run:

- `current_database()`: `product_ops_test`
- `current_user`: `product_ops_tester`
- `transaction_read_only`: `on`
- database guard: `PASS`

Production Supabase, NAS PostgreSQL, and remote DBs must not be used for this inspection.

## Local DB Source Findings

The local DB does not currently have a MakeShop-specific source/stage table. The catalog inspection found general product-code tables and Smartstore stage tables, but no MakeShop original import table equivalent to a MakeShop 상품/옵션 source table.

The useful current DB relation is:

- `product_code.sku_channel_mapping`

Relevant columns:

- `channel_code`
- `seller_product_code`
- `channel_sku_code`
- `own_sku_code`
- `sku_id`

`product_code.code_alias` currently has no MakeShop alias rows:

| Source | Column / filter | Rows | Non-null | Distinct |
|---|---:|---:|---:|---:|
| `product_code.code_alias` | `code_system like makeshop/shop/mall` | 0 | 0 | 0 |
| `product_code.sku_channel_mapping` | `channel_code = makeshop` | 17,568 | 17,568 | 17,279 sku_id |
| `product_code.sku_channel_mapping` | `seller_product_code` | 17,568 | 17,568 | 3,891 |
| `product_code.sku_channel_mapping` | `channel_sku_code` | 17,568 | 17,568 | 17,568 |
| `product_code.sku_channel_mapping` | `own_sku_code` | 17,568 | 17,568 | 15,062 |

Interpretation:

- Direct MakeShop alias evidence is absent from `code_alias`.
- Existing MakeShop code evidence is present in `sku_channel_mapping`.
- The current 1,247 medium candidates do not have direct code evidence by their own `sku_id`.
- Some candidates can be connected indirectly through `own_sku_code` to existing MakeShop mapping rows.

## Candidate Join Result

The inspection reuses the MakeShop medium candidate CTE from `select_makeshop_auto_match_sample_review_v1.sql`.

Candidate evidence summary:

| Metric | Count | Meaning |
|---|---:|---|
| `candidate_total` | 1,247 | High + medium MakeShop candidate baseline |
| `medium_candidate_count` | 1,247 | All candidates are medium |
| `makeshop_code_present_count` | 0 | Direct MakeShop code on the candidate SKU |
| `makeshop_code_missing_count` | 1,247 | Direct MakeShop code missing |
| `selfpia_sku_joined_count` | 1,247 | All candidates have selfpia SKU |
| `own_sku_joined_count` | 1,247 | All candidates have own_sku evidence |
| `same_product_family_count` | 511 | own_sku repeats inside same product family |
| `cross_product_count` | 736 | own_sku repeats across product families |
| `duplicate_makeshop_code_count` | 0 | Direct duplicate code conflict inside candidate set |
| `duplicate_selfpia_to_makeshop_count` | 0 | Direct selfpia to MakeShop split inside candidate set |
| `semantic_warning_count` | 0 | No semantic warning in the candidate set |

Indirect own_sku-based evidence:

| Metric | Count | Meaning |
|---|---:|---|
| `own_sku_join_to_existing_makeshop_mapping_count` | 309 | Candidate own_sku joins to at least one existing MakeShop mapping |
| `own_sku_join_to_existing_makeshop_code_count` | 309 | Candidate own_sku joins to existing MakeShop code evidence |
| `own_sku_join_unique_makeshop_code_count` | 291 | Candidate own_sku joins to exactly one MakeShop code pair |
| `own_sku_join_duplicate_makeshop_code_count` | 18 | Candidate own_sku joins to multiple MakeShop code pairs |
| `evidence_present_count` | 291 | Direct or unique own_sku-based MakeShop code evidence |
| `evidence_missing_count` | 956 | No direct or unique own_sku-based MakeShop code evidence |

## Sample Evidence

The new inspection SQL includes an `own_sku_unique_code_evidence_sample` bucket. Example pattern:

- selfpia SKU `5444-3`, own_sku `GPA-5-03_3`
- product: `14K 클로버 피어싱 미니 큐빅 골드 피어싱 4종 이너컨츠 아웃컨츠`
- option: `핑크골드/6mm바`
- indirect MakeShop product code: `972165`
- indirect MakeShop option/SKU code: `972165-1`

This is useful evidence, but it is still indirect. It should be validated against product and option semantics before any apply design.

## Decision Branches

### A. Code Evidence Available

The 291 rows with `own_sku_join_unique_makeshop_code_count` can be split into a stricter candidate set.

Recommended next step:

- write a revised MakeShop candidate SELECT that promotes only rows with unique own_sku-based MakeShop code evidence
- validate duplicate MakeShop code and duplicate selfpia to MakeShop code again
- run dryrun again
- require user approval before local apply

### B. Partial Evidence Available

The 18 rows with duplicate own_sku-based MakeShop code joins should not be applied automatically.

Recommended handling:

- keep them as medium review or risk-edge rows
- sample product/option text
- only promote if a more specific product/option key disambiguates the MakeShop code

### C. Code Evidence Missing

The remaining 956 rows still lack MakeShop code evidence.

Recommended next step:

- do not apply
- collect or import MakeShop original product/option evidence through a separately approved stage workflow
- expected useful fields: MakeShop product code, option code/SKU code, product name, option text, selfpia SKU or own_sku, row/source metadata

## Safety Notes

- This inspection does not write to DB.
- It does not create stage tables.
- It does not import/export files.
- It does not update `code_alias`.
- It does not change candidate rows to confirmed.
- `export_allowed` remains false.
- `reviewer_decision` remains pending.
- Existing confirmed/manual mappings must not be overwritten.

## Completion Report Template

When reporting this inspection:

- list the source tables/columns found
- report `code_alias` MakeShop rows and `sku_channel_mapping` MakeShop code counts
- report the 1,247 candidate join result
- separate direct evidence from indirect own_sku-based evidence
- state whether local apply is allowed
- state whether a revised candidate SQL/dryrun is possible
