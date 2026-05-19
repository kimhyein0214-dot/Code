# Smartstore Blocked Risk Reduction Plan v1

## Purpose

The current DB-only channel presence lite summary shows Smartstore as the immediate bottleneck:

- current representative auto-match rate: `19.85%`
- current `blocked_risk` rows: `19,768`
- current `unknown_need_check` rows: `3,846`

The blocked bucket is too large to treat as one manual-review queue. The goal is to split blocked rows by cause and promote safe candidates into `auto_match_high_confidence` or `auto_match_medium_confidence` wherever practical.

High/medium confidence is still not a DB write target. It means candidate rows are ready for validate, dryrun, user approval, local apply, and postcheck.

## Why Breakdown Matters

The current lite summary marks rows as blocked when duplicate or conflict-looking evidence exists in DB-only aliases/mappings. Some of that is true risk. Some may be stale candidate alias noise, missing option evidence, or expression differences that option normalization can absorb.

If all blocked rows stay blocked, Smartstore reporting remains artificially conservative. If true-risk rows are separated and the rest are promoted, representative auto-match rate can improve without changing any DB values.

## Promotion Strategy

### Promote to `auto_match_high_confidence`

Promote when:

- selfpia SKU exists in DB.
- Smartstore productNo candidate exists.
- Smartstore optionNo or option text candidate exists.
- productNo + optionNo pair does not point to multiple SKU IDs.
- the same selfpia SKU does not split across multiple productNo values.
- own_sku, when present, does not point to multiple SKU IDs.
- no true blocked-risk condition exists.

### Promote to `auto_match_medium_confidence`

Promote when:

- selfpia SKU exists in DB.
- productNo or option evidence exists.
- own_sku is absent or needs light support.
- option evidence is incomplete but usable.
- expression differences are normalization-absorbable.
- no true blocked-risk condition exists.

Medium rows should be reviewed by summary/sample, not line by line by default.

## Normalization-Absorbable Evidence

The breakdown SQL counts rows with option text that can be absorbed by normalization:

- `핑골` = `핑크골드` = `로즈골드` = `rose gold` = `RG`
- `골드` = `옐로우골드` = `yellow gold` = `YG`
- `원타입` = `단일옵션`
- `6mm바` = `6mm`
- `8mm바` = `8mm`
- `주문제작` can be removed from the core option key.
- spacing, parentheses, and ordinary punctuation differences can be ignored.

These should not automatically block Smartstore matching.

## True Blocked Risk

Keep rows blocked when any of these are present:

- `크리스탈` and `크리스탈AB` confusion.
- standalone or unsafe `AB` token.
- `화이트골드` and `실버` confusion.
- `한쌍`, `낱개`, `세트`, `5개` or similar quantity conflict.
- same productNo + optionNo maps to multiple SKU IDs.
- same selfpia SKU maps to multiple productNo values.
- own_sku maps to multiple SKU IDs.
- product name is clearly different.
- bracket parse error.

## Improvement Formula

Current auto-match rows:

```text
matched_confirmed + auto_match_high_confidence + auto_match_medium_confidence
```

Expected auto-match rows after promotion:

```text
current_auto_match_rows
+ promotable_to_high_confidence_rows
+ promotable_to_medium_confidence_rows
```

Expected representative auto-match rate:

```text
expected_auto_match_rows_after_promotion
/ smartstore_channel_present_rows
```

Expected gain:

```text
expected_channel_presence_based_auto_match_rate_pct_after_promotion
- current_channel_presence_based_auto_match_rate_pct
```

## First Local Read-Only Result

The first read-only run matched the existing lite baseline:

- Smartstore channel-present rows: `29,464`
- current blocked-risk rows: `19,768`
- current representative auto-match rate: `19.85%`
- promotable to high confidence: `0`
- promotable to medium confidence: `0`
- expected representative auto-match rate after promotion: `19.85%`

The main blocker is not missing product/option evidence. It is `own_sku` conflict evidence:

- duplicate own_sku blocked rows: `19,758`
- duplicate selfpia SKU to product rows: `10`
- AB token true-risk rows: `6`
- option normalization absorbable rows inside blocked rows: `1,761`
- productNo and option candidate evidence inside blocked rows: `6,706`

This means the next practical reduction step should split `own_sku` conflicts into true conflicts versus stale/shared own_sku evidence before promoting rows. Under the current true-risk rule, rows with multi-SKU own_sku evidence stay blocked.

## SQL Output

`sql/select_smartstore_blocked_risk_breakdown_v1.sql` returns summary rows only. Important outputs:

- `current_blocked_risk_rows`
- `duplicate_product_option_blocked_rows`
- `duplicate_selfpia_sku_to_product_blocked_rows`
- `duplicate_own_sku_blocked_rows`
- `option_normalization_absorbable_rows`
- `crystal_crystal_ab_true_risk_rows`
- `ab_token_true_risk_rows`
- `white_gold_silver_true_risk_rows`
- `quantity_set_true_risk_rows`
- `promotable_to_high_confidence_rows`
- `promotable_to_medium_confidence_rows`
- `remain_blocked_risk_rows`
- `current_channel_presence_based_auto_match_rate_pct`
- `expected_channel_presence_based_auto_match_rate_pct_after_promotion`
- `expected_auto_match_rate_gain_pct_point`

## Execution Rules

Run only against local DB in read-only mode:

- database: `product_ops_test`
- user: `product_ops_tester`
- `SET default_transaction_read_only = on`

Do not run against production Supabase, NAS PostgreSQL, or any remote DB.

No apply, import, export, CSV/JSON/XLSX generation, or DB write is allowed for this diagnostic.
