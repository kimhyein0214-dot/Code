# Smartstore Own SKU Conflict Reduction Plan v1

## Purpose

The latest Smartstore blocked-risk diagnostic shows that `own_sku` conflict is the main bottleneck:

- Smartstore `blocked_risk`: `19,768`
- duplicate `own_sku` blocked rows: `19,758`
- duplicate selfpia SKU to product rows: `10`
- current promotable high confidence rows: `0`
- current promotable medium confidence rows: `0`

The current rule is too strict if every repeated `own_sku` is treated as a hard block. `own_sku` is important evidence, but it is not always a strict one-to-one SKU key. The same code can repeat inside a product family, a set product, a grouped option structure, an older inactive listing, or a channel-specific option bundle.

The default interpretation changes here: duplicate `own_sku` is not automatically a true conflict. It is a reclassification target unless stronger evidence proves a real cross-product or semantic conflict.

## Practical Reclassification Strategy

Split duplicate `own_sku` rows into evidence groups:

- `same_product_option_repeat`: repeated `own_sku` inside the same product, selfpia product, or Smartstore productNo while options differ.
- `set_or_quantity_repeat`: repeated `own_sku` caused by set, pair, single, or quantity wording.
- `stale_or_channel_absent_repeat`: repeated `own_sku` caused by selfpia history or no Smartstore evidence.
- `true_cross_product_conflict`: repeated `own_sku` crossing product groups with productNo/option or semantic conflict.

This avoids sending all duplicate `own_sku` rows to manual review by default.

## Four Reclassification Buckets

### `same_product_option_repeat`

This is usually not a true risk. If productNo + optionNo is unique and selfpia SKU is one-to-one, this bucket can become high confidence. If some expression support is still needed, it can become medium confidence.

### `set_or_quantity_repeat`

Set, pair, single, or quantity wording should not automatically block matching. Treat it as medium confidence or a set warning unless the quantity meaning conflicts across candidates.

### `stale_or_channel_absent_repeat`

If the row has no Smartstore alias, mapping, or image evidence, the duplicate can be a selfpia historical item or channel-inactive item. This should be separated as `channel_absent_or_inactive`, not manual review.

### `true_cross_product_conflict`

Keep this blocked only when the repeated `own_sku` crosses product families and the channel evidence also conflicts, or when option meaning is genuinely different.

## High Confidence Promotion

Move a duplicate `own_sku` row toward `auto_match_high_confidence` when all are true:

- selfpia SKU maps to one DB SKU.
- Smartstore productNo exists.
- Smartstore optionNo or option evidence exists.
- Smartstore productNo + optionNo pair is unique.
- the same selfpia SKU does not split across multiple productNo values.
- duplicated `own_sku` remains inside the same product family or same selfpia product.
- no AB, crystal/CrystalAB, white-gold/silver, productNo split, product-option collision, or other true conflict is present.

This is still only a promotion candidate. It is not a DB apply instruction.

## Medium Confidence Promotion

Move a duplicate `own_sku` row toward `auto_match_medium_confidence` when:

- selfpia SKU exists.
- productNo or option evidence exists.
- Smartstore productNo + optionNo is unique, or the duplicate stays inside one Smartstore productNo.
- option text differences look normalization-absorbable.
- set, pair, single, or quantity wording exists but does not conflict.
- true-risk wording and productNo splitting are absent.

Medium confidence should reduce line-by-line review. It should go through summary/sample review, dryrun, user approval, local apply, and postcheck before any real change.

## Keep Blocked

Keep duplicate `own_sku` rows in `blocked_risk` when:

- the same `own_sku` crosses different product IDs and selfpia product families.
- the same `own_sku` points to multiple Smartstore productNo values without a unique product-option key.
- the same productNo + optionNo points to multiple selfpia SKU rows.
- the same selfpia SKU splits into multiple productNo values.
- quantity or set meaning actually conflicts.
- crystal/CrystalAB, standalone AB, or white-gold/silver meaning differs.
- product names are clearly different.
- `own_sku` exists but selfpia/productNo/option evidence is too weak.

## Improvement Formula

Current auto-match rows:

```text
matched_confirmed + auto_match_high_confidence + auto_match_medium_confidence
```

Expected auto-match rows after own_sku reclassification:

```text
current_auto_match_rows
+ own_sku_promotable_to_high_confidence_rows
+ own_sku_promotable_to_medium_confidence_rows
```

Expected representative auto-match rate:

```text
expected_auto_match_rows_after_own_sku_reclassification
/ smartstore_channel_present_rows
```

Expected gain:

```text
expected_channel_presence_based_auto_match_rate_pct_after_own_sku_reclassification
- current_channel_presence_based_auto_match_rate_pct
```

## First Local Read-Only Result

The first read-only run shows that duplicate `own_sku` is mostly a reclassification opportunity, not a hard block:

- duplicate `own_sku` blocked rows: `19,758`
- `same_product_option_repeat`: `3,940`
- `set_or_quantity_repeat`: `0`
- `stale_or_channel_absent_repeat`: `9,093`
- `true_cross_product_conflict`: `8,124`
- promotable to high confidence: `3,936`
- promotable to medium confidence: `2,756`
- separable as channel absent or inactive: `9,093`
- remaining blocked after reclassification: `3,973`

Representative rate impact:

- current Smartstore auto-match rate: `19.85%`
- expected rate after own_sku reclassification: `61.57%`
- expected gain: `41.72%p`
- expected remaining blocked-risk rate: `19.55%`

This confirms the domain assumption: duplicate `own_sku` should be treated as a reclassification bucket first. Only the cross-product/semantic conflict remainder should stay blocked by default.

## SQL Output

`sql/select_smartstore_own_sku_conflict_breakdown_v1.sql` returns summary rows only. Important outputs:

- `duplicate_own_sku_blocked_rows`
- `same_product_option_repeat_rows`
- `set_or_quantity_repeat_rows`
- `stale_or_channel_absent_repeat_rows`
- `true_cross_product_conflict_rows`
- `duplicate_own_sku_same_product_family_rows`
- `duplicate_own_sku_cross_product_rows`
- `duplicate_own_sku_same_selfpia_product_rows`
- `duplicate_own_sku_same_smartstore_product_rows`
- `duplicate_own_sku_with_unique_product_option_rows`
- `duplicate_own_sku_with_candidate_product_option_rows`
- `duplicate_own_sku_true_conflict_rows`
- `own_sku_repeat_promotable_to_high_confidence_rows`
- `own_sku_repeat_promotable_to_medium_confidence_rows`
- `own_sku_repeat_channel_absent_or_inactive_rows`
- `own_sku_repeat_remain_blocked_risk_rows`
- `expected_channel_presence_based_auto_match_rate_pct_after_own_sku_reclassification`
- `expected_auto_match_rate_gain_pct_point`

## Execution Rules

Run only against local DB in read-only mode:

- database: `product_ops_test`
- user: `product_ops_tester`
- `SET default_transaction_read_only = on`

Do not run against production Supabase, NAS PostgreSQL, or any remote DB.

No apply, import, export, CSV/JSON/XLSX generation, or DB write is allowed for this diagnostic.
