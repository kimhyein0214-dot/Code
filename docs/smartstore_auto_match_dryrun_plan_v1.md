# Smartstore Auto Match Dryrun Plan v1

## Purpose

This is a dryrun preparation step for Smartstore auto-match candidates. It does not apply mappings, confirm candidates, export rows, or change reviewer decisions.

Current own_sku reclassification result:

- current Smartstore auto-match rate: `19.85%`
- expected rate after own_sku reclassification: `61.57%`
- expected gain: `41.72%p`
- high confidence repeat candidates: `3,936`
- medium confidence repeat candidates: `2,756`
- channel absent or inactive separable rows: `9,093`
- remaining blocked risk: `3,973`

## Operating Sequence

Use this sequence only:

```text
validate -> dryrun -> user approval -> local apply -> postcheck
```

High and medium confidence rows are not direct apply targets before approval. They are candidate buckets for validation and dryrun.

## Candidate Buckets

### `auto_match_high_confidence`

Use for rows where:

- selfpia SKU is one-to-one in DB.
- Smartstore productNo exists.
- Smartstore optionNo or option evidence exists.
- productNo + optionNo is one-to-one.
- selfpia SKU does not split across multiple productNo values.
- no true blocked risk remains.

### `auto_match_medium_confidence`

Use for rows where:

- selfpia SKU exists.
- Smartstore productNo or option evidence exists.
- duplicate own_sku is likely a same-product repeat, set/quantity repeat, or normalization-only difference.
- true blocked risk remains absent.

Medium candidates should be sample-checked before any dryrun apply plan.

### `channel_absent_or_inactive`

These rows are not apply targets. They represent likely historical, inactive, hidden, or channel-absent items. They should be excluded from Smartstore matching-rate denominator when reporting channel-present progress.

### `remain_blocked_risk`

These rows stay out of dryrun apply:

- cross-product own_sku conflict
- productNo/optionNo collision
- selfpia SKU split across multiple productNo values
- crystal/CrystalAB conflict
- standalone AB warning
- white-gold/silver warning
- quantity or set meaning conflict
- clearly different product meaning

## SQL Files

### Candidate extraction

`sql/select_smartstore_auto_match_candidates_v1.sql`

Returns:

- summary rows by `confidence_tier` and source
- limited sample rows, at most five per tier/source
- `export_allowed=false`
- `reviewer_decision='pending'`

It does not create CSV, JSON, XLSX, export files, or stage tables.

### Validation

`sql/validate_smartstore_auto_match_candidates_v1.sql`

Checks counts before dryrun:

- candidate total
- high count
- medium count
- duplicate productNo + optionNo count
- duplicate selfpia SKU to productNo count
- own_sku multi-SKU conflict count
- residual blocked-risk count
- channel_absent_or_inactive excluded count
- crystal/CrystalAB warning count
- AB warning count
- white-gold/silver warning count
- quantity/set warning count

The duplicate own_sku count can remain non-zero because this plan intentionally reclassifies own_sku repeats. ProductNo/option and semantic warning counts should remain zero for high/medium candidates unless explicitly approved after sample review.

## First Local Read-Only Result

The first local read-only validation produced:

- candidate total: `6,692`
- high confidence: `3,936`
- medium confidence: `2,756`
- duplicate productNo + optionNo inside candidates: `0`
- duplicate selfpia SKU to productNo inside candidates: `0`
- own_sku multi-SKU conflict inside candidates: `6,692`
- residual blocked risk: `3,983`
- channel_absent_or_inactive excluded: `9,093`
- crystal/CrystalAB warning inside candidates: `0`
- AB warning inside candidates: `0`
- white-gold/silver warning inside candidates: `0`
- quantity/set warning inside candidates: `0`
- `export_allowed` stayed false.
- `reviewer_decision` stayed pending.

The non-zero own_sku multi-SKU count is expected. This step is reclassifying duplicate own_sku evidence for dryrun, not confirming it.

## Safety Rules

- Do not overwrite existing manual mappings.
- Do not treat candidates as confirmed.
- Do not enable `export_allowed`.
- Do not set `reviewer_decision` to anything other than `pending`.
- Do not run apply SQL in this step.
- Do not import or export files.
- Run only against local DB in read-only mode:
  - database: `product_ops_test`
  - user: `product_ops_tester`
  - `SET default_transaction_read_only = on`

Do not run against production Supabase, NAS PostgreSQL, or any remote DB.
