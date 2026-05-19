# Smartstore Auto Match Sample Review Plan v1

## Purpose

Smartstore has `6,692` dryrun candidates after own_sku reclassification:

- high confidence: `3,936`
- medium confidence: `2,756`
- remain blocked risk: `3,983`
- channel absent or inactive excluded: `9,093`

This step is a sample review step, not an apply step. It helps a reviewer decide whether the high/medium buckets are ready for dryrun without reading all `6,692` rows.

The sample SQL keeps the promoted total at `6,692`. For review caution, rows with set or quantity wording can be routed from high into the medium sample bucket, so a local sample run can show `3,928` high sample candidates and `2,764` medium sample candidates while preserving the same promoted total.

## Why Sample Review

Full manual review would erase most of the value of auto matching. The better workflow is:

```text
validate -> sample review -> dryrun -> user approval -> local apply -> postcheck
```

If sample review looks clean, proceed to dryrun SQL design. If a bucket shows problems, tighten only that bucket's condition instead of sending every candidate to manual review.

## Sample Buckets

`sql/select_smartstore_auto_match_sample_review_v1.sql` returns up to about 20 rows per bucket:

- `high_confidence_sample`
- `medium_confidence_sample`
- `own_sku_repeat_promoted_sample`
- `same_product_family_repeat_sample`
- `option_normalization_sample`
- `product_option_one_to_one_sample`
- `random_sample`
- `risk_edge_sample`

Each row includes:

- confidence tier
- selfpia SKU
- own_sku
- product name
- option name
- Smartstore productNo candidate
- Smartstore optionNo or option text candidate
- normalized option text
- match reason
- risk note
- reviewer checkpoint

## Human Checkpoints

Reviewers should look for:

- product name appears to be the same product
- option name appears to be the same option
- own_sku repeat looks like a normal same-product or option repeat
- productNo is not unexpectedly split across unrelated products
- high confidence rows really feel high confidence
- medium confidence rows are safe enough for dryrun after sample review
- normalization examples are genuine equivalents, such as 6mm바 and 6mm or 핑크골드 and 로즈골드
- crystal and CrystalAB are not being collapsed into each other
- standalone AB, white-gold/silver, or quantity meaning conflict does not appear as a clean high-confidence assumption

## Decision Rules

If the sample is clean:

- keep high confidence as dryrun-ready
- keep medium confidence as dryrun-ready with sample review evidence
- proceed to dryrun SQL design

If the sample shows risk:

- do not apply
- tighten only the affected bucket
- rerun validation and sample review
- keep remain_blocked_risk as manual review or hold

## Safety Rules

- This stage does not write to DB.
- This stage does not create apply SQL.
- This stage does not import or export files.
- Existing manual mappings must not be overwritten.
- Candidates must not be treated as confirmed.
- `export_allowed` must not be enabled.
- `reviewer_decision` must remain `pending`.

Run only against local DB in read-only mode:

- database: `product_ops_test`
- user: `product_ops_tester`
- `SET default_transaction_read_only = on`

Do not run against production Supabase, NAS PostgreSQL, or any remote DB.
