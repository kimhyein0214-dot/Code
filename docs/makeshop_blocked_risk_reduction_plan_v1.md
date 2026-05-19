# MakeShop Blocked Risk Reduction Plan v1

## Purpose

MakeShop currently looks much healthier than Smartstore, but still has a large blocked bucket:

- selfpia total rows: `33,291`
- channel-present rows: `31,678`
- current representative auto-match rate: `54.55%`
- matched confirmed rows: `17,279`
- blocked risk rows: `13,878`
- unknown need check rows: `521`
- channel absent or inactive rows: `1,613`

This diagnostic checks whether the remaining MakeShop blocked rows are true risk, or whether some are conservative blocks caused by repeated `own_sku`, same-product option repeats, set/quantity structures, or historical/inactive channel evidence.

## Domain Assumption

`own_sku` is useful evidence, but it is not always a strict one-to-one SKU key. The same own code can repeat:

- inside one product with different options
- inside one selfpia product family
- in set or quantity variants
- in older selfpia rows that no longer exist on MakeShop
- in rows that have no MakeShop evidence and should not be counted as manual review by default

Therefore duplicate `own_sku` is treated as a reclassification target first, not a true blocked risk by default.

## Reclassification Buckets

### Same Product Family Repeat

Rows where duplicated `own_sku` stays inside one `product_id` or one selfpia product family. These are potential high/medium candidates when MakeShop code evidence is present and selfpia SKU is one-to-one.

### MakeShop Code Evidence

Rows with MakeShop product/option code evidence are stronger than rows with only `own_sku`. If the MakeShop code + option evidence points to one SKU and no semantic risk exists, the row can move toward high confidence.

### Set Or Quantity Repeat

Set, quantity, pair, or single wording should not automatically block matching. These rows can become medium confidence or set warning when MakeShop code/product evidence is strong. If quantity meaning conflicts, they remain blocked.

### Channel Absent Or Inactive

Rows with no MakeShop code/mapping/image evidence are likely historical, inactive, hidden, or not listed on MakeShop. These should be separated from manual review and apply targets.

### True Conflict

Keep rows blocked when:

- the same `own_sku` crosses unrelated product families
- the same MakeShop code maps to multiple selfpia SKU rows
- the same selfpia SKU splits across multiple MakeShop codes
- crystal/CrystalAB, standalone AB, white-gold/silver, or quantity meaning conflicts exist
- `own_sku` exists but MakeShop/selfpia/option evidence is too weak

## Promotion Criteria

### `auto_match_high_confidence`

Promote when:

- selfpia SKU is one-to-one in DB.
- MakeShop code evidence exists.
- MakeShop product/option evidence exists.
- the same selfpia SKU does not split across multiple MakeShop codes.
- duplicated `own_sku` stays inside the same product or selfpia product family.
- no true semantic or quantity risk exists.

### `auto_match_medium_confidence`

Promote when:

- selfpia SKU is one-to-one.
- MakeShop code or option evidence exists.
- duplicated `own_sku` is likely same-product family repetition.
- option text differences are normalization-absorbable.
- set or quantity wording is present but not conflicting.
- no true conflict condition remains.

High/medium rows are not direct apply targets. They require validate, dryrun, user approval, local apply, and postcheck.

## Improvement Formula

Current auto-match rows:

```text
matched_confirmed + auto_match_high_confidence + auto_match_medium_confidence
```

Expected auto-match rows after reclassification:

```text
current_auto_match_rows
+ promotable_to_high_confidence_rows
+ promotable_to_medium_confidence_rows
```

Expected representative auto-match rate:

```text
expected_auto_match_rows_after_reclassification
/ makeshop_channel_present_rows
```

Expected gain:

```text
expected_channel_presence_based_auto_match_rate_pct_after_reclassification
- current_channel_presence_based_auto_match_rate_pct
```

## First Local Read-Only Result

The first local read-only run matched the MakeShop lite baseline and found a smaller promotion opportunity than Smartstore:

- current blocked risk rows: `13,878`
- unknown need check rows: `521`
- duplicate own_sku blocked rows: `13,878`
- same product family repeats: `5,681`
- cross product repeats: `8,197`
- unique MakeShop code evidence inside blocked rows: `0`
- blocked rows without MakeShop code evidence: `13,878`
- channel absent or inactive style own_sku repeats: `7,726`
- option normalization absorbable rows: `1,304`
- AB token true-risk rows: `3`
- promotable to high confidence: `0`
- promotable to medium confidence: `1,247`
- remain blocked risk: `12,631`

Representative rate impact:

- current MakeShop auto-match rate: `54.55%`
- expected rate after reclassification: `58.48%`
- expected gain: `3.94%p`
- expected remaining blocked-risk rate: `39.87%`

This suggests MakeShop blocked rows are mostly missing MakeShop code evidence, not rich product/option evidence like Smartstore. The immediate safe gain is medium-confidence normalization/same-family review, while high confidence likely needs additional MakeShop code evidence.

## SQL Output

`sql/select_makeshop_blocked_risk_breakdown_v1.sql` returns summary rows only. Important outputs:

- `current_blocked_risk_rows`
- `unknown_need_check_rows`
- `duplicate_own_sku_blocked_rows`
- `duplicate_own_sku_same_product_family_rows`
- `duplicate_own_sku_cross_product_rows`
- `duplicate_own_sku_with_unique_makeshop_code_rows`
- `duplicate_own_sku_true_conflict_rows`
- `makeshop_code_candidate_exists_rows`
- `option_normalization_absorbable_rows`
- `promotable_to_high_confidence_rows`
- `promotable_to_medium_confidence_rows`
- `expected_channel_presence_based_auto_match_rate_pct_after_reclassification`
- `expected_auto_match_rate_gain_pct_point`

## Execution Rules

Run only against local DB in read-only mode:

- database: `product_ops_test`
- user: `product_ops_tester`
- `SET default_transaction_read_only = on`

Do not run against production Supabase, NAS PostgreSQL, or any remote DB.

No apply SQL, import, export, CSV/JSON/XLSX generation, or DB write is allowed for this diagnostic.
