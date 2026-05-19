# MakeShop Auto Match Sample Review Plan v1

## Purpose

MakeShop dryrun passed, but all current candidates are medium confidence:

- candidate total: `1,247`
- high confidence: `0`
- medium confidence: `1,247`
- duplicate MakeShop code count: `0`
- duplicate selfpia to MakeShop count: `0`
- semantic warning count: `0`
- rollback verdict: `PASS`

The high confidence count is zero because current DB-only evidence does not provide enough unique MakeShop product/option code evidence. Before any local apply design, reviewers need to see whether the medium candidates actually have MakeShop code evidence or are only own_sku/normalization based.

This step is review only. It does not apply, import, export, or change DB state.

## Local Read-Only Result

The local read-only sample review result shows:

- candidate total: `1,247`
- medium candidate count: `1,247`
- MakeShop code present count: `0`
- MakeShop code missing count: `1,247`
- selfpia SKU joined count: `1,247`
- own_sku joined count: `1,247`
- same product family count: `511`
- cross product count: `736`
- channel absent or inactive excluded count: `0`
- duplicate MakeShop code count: `0`
- duplicate selfpia to MakeShop count: `0`
- semantic warning count: `0`

This means the dryrun candidates are useful for narrowing review, but they are not ready for confirmed-code local apply. Every candidate is missing direct MakeShop code evidence.

## SQL

`sql/select_makeshop_auto_match_sample_review_v1.sql` is SELECT-only. It returns:

- summary counts for the 1,247 medium candidates
- bucketed samples, limited to about 20 rows per bucket
- explicit `makeshop_code_present` and `makeshop_code_missing` review groups

## Summary Checks

The review should confirm:

- how many medium candidates have MakeShop code evidence
- how many medium candidates are missing MakeShop code evidence
- whether selfpia SKU and own_sku evidence are present
- whether own_sku repeats stay inside one product family
- whether cross-product repeats remain in the candidate set
- whether duplicate MakeShop code, selfpia split, or semantic warnings are zero

## Sample Buckets

The SQL returns these buckets:

- `medium_candidate_sample`
- `makeshop_code_present_sample`
- `makeshop_code_missing_sample`
- `same_product_family_sample`
- `own_sku_repeat_sample`
- `random_sample`
- `risk_edge_sample`

Each sample row includes:

- confidence tier
- sku_id
- selfpia SKU
- own_sku
- product name
- option name
- MakeShop code candidate
- MakeShop product candidate
- MakeShop option candidate
- match reason
- evidence source
- risk note
- reviewer checkpoint

## Human Checkpoints

Reviewers should check:

- whether a MakeShop code candidate actually exists
- whether the candidate is linked one-to-one to the selfpia SKU
- whether own_sku repeats look like same-product repeats
- whether code-missing candidates should be excluded from apply
- whether any candidate relies only on own_sku without product/option evidence
- how many rows are truly applyable after code evidence review

## Decision Rules

If MakeShop code evidence is missing for most candidates:

- do not local apply
- keep the 1,247 rows as medium review candidates
- gather or import MakeShop code evidence through a separately approved stage workflow

The current result falls into this branch because MakeShop code evidence is missing for all `1,247` candidates.

If a subset has solid MakeShop product/option code evidence:

- design a narrower dryrun/apply plan for that subset only
- keep code-missing rows out of confirmed code apply
- rerun validate and dryrun before requesting user approval

## Safety

- DB write is forbidden in this step.
- Local apply is forbidden in this step.
- No apply SQL is created or executed.
- Existing confirmed/manual values must not be overwritten.
- No import or export files are generated.
- Production Supabase, NAS PostgreSQL, and remote DBs must not be used.
- `export_allowed` must not be enabled.
- `reviewer_decision` must remain `pending`.
