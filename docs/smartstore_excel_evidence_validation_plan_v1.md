# Smartstore Excel Evidence Validation Plan v1

## Purpose

This plan changes the Smartstore Excel evidence validation layer from a maximum-safety gate into an operational confidence-tier model. The goal is not to make mismatch risk mathematically zero. The goal is to maximize useful automatic matching candidates while separating genuinely risky rows into `blocked_risk` or `manual_review_required`.

The Excel parsing summary showed:

- `excel_parse_good_candidate`: 976
- `strong_candidate`: 286
- `manual_review_required`: 0
- `parse_warning`: 11,040

These are still parsing-only estimates. They are not DB-ready changes and must not be applied directly. The new validation layer uses DB joins and option normalization to split candidates into practical confidence tiers.

## Operating Principle

`auto_match_high_confidence` and `auto_match_medium_confidence` are not direct DB write targets. They are candidate groups for reducing manual review. The actual workflow remains:

1. validate
2. dryrun
3. user approval
4. local apply
5. postcheck

The operational change is how people review the output. Instead of reviewing every candidate row, reviewers can focus on medium-confidence samples, summaries, and the risk buckets.

## Confidence Tiers

### `excel_parse_good_candidate`

This means the Excel row is well-formed before DB validation.

Typical evidence:

- `normalized_selfpia_sku_code` is present.
- Smartstore productNo is present.
- option text is present.
- the option SKU pattern was read as `sellpia_상품코드-옵션번호`.
- no duplicate selfpia SKU was found in the parsing pass.
- no duplicate Smartstore productNo + option text was found in the parsing pass.

This is not directly applicable to DB. It is the validation input pool.

### `auto_match_high_confidence`

This is the main practical automation bucket.

Use this when:

- selfpia SKU joins to exactly one DB SKU.
- Smartstore productNo candidate exists.
- option text exists.
- no duplicate selfpia SKU split is detected.
- no duplicate Smartstore productNo + option text collision is detected.
- own_sku, when present, joins to the same SKU.
- option text matches after normalization.
- no `blocked_risk` condition exists.

PlayAuto Smartstore option evidence should be treated aggressively here. The parse summary showed `옵션기본` 762 rows where selfpia SKU, Smartstore productNo, and option text all existed, with zero duplicate selfpia SKU and zero duplicate productNo + option text. Those rows should not be sent to manual review merely because of absorbable text differences.

### `auto_match_medium_confidence`

This is still useful for reducing manual review.

Use this when:

- selfpia SKU joins to exactly one DB SKU.
- Smartstore productNo candidate exists.
- option text exists.
- no hard duplicate or blocked risk is present.
- evidence is strong but needs light review, for example:
  - own_sku is missing.
  - product-name support is weak but not conflicting.
  - option text differs only by absorbable normalization.
  - `주문제작`, spacing, parentheses, or minor punctuation changes were absorbed.

Medium rows should be reviewed by summary/sample rather than line-by-line unless the sample reveals a pattern problem.

### `manual_review_required`

Use this for ambiguous but not obviously dangerous rows:

- required key evidence is missing.
- selfpia SKU does not join to DB.
- product-name support is weak and option normalization is not enough.
- own_sku needs confirmation.
- option normalization is not decisive.
- the row is not blocked, but cannot be confidently grouped.

### `blocked_risk`

Use this for rows that should not be automatically matched:

- `크리스탈` vs `크리스탈AB` confusion is possible.
- `AB` appears as a standalone or unsafe token.
- `AB` is caught as a substring rather than a true token.
- `화이트골드` vs `실버` confusion is possible.
- `한쌍` vs `낱개` vs `세트` conflict exists.
- quantity options such as `5개 세트` could change SKU identity.
- option name splits into multiple incompatible candidates.
- the same selfpia SKU links to multiple Smartstore productNo values.
- the same Smartstore productNo + option text links to multiple selfpia SKUs.
- own_sku links to multiple SKU IDs.
- selfpia SKU links to multiple SKU IDs.
- product name is clearly different.
- multi-line option/SKU count mismatch is present.
- bracket or own_sku parsing is malformed.

### `parse_warning`

Use this for parser warnings that are not yet confirmed as blocked risk:

- parser warning text exists.
- option text is malformed but not yet proven conflicting.
- source row is structurally suspicious.

If a row has both a warning and a hard collision, `blocked_risk` should win.

## Normalization That Should Increase Match Rate

The following differences should be absorbed and should not block automatic matching candidates by themselves:

- `핑골` = `핑크골드` = `로즈골드` = `rose gold` = `RG`
- `골드` = `옐로우골드` = `yellow gold` = `YG`
- `원타입` = `단일옵션` = `one type`
- `6mm바` = `6mm`
- `8mm바` = `8mm`
- `주문제작` text can be removed from the core option key.
- whitespace differences can be ignored.
- parentheses differences can be ignored.
- ordinary punctuation differences can be ignored.

Examples that should remain match candidates:

- `핑크골드/6mm바`
- `로즈골드(주문제작)/6mm바`
- `핑골/6mm`

The normalized option key should treat these as the same practical option unless another blocked-risk rule fires.

## DB Join Strategy

Assumed future stage relation:

- `stage_excel_smartstore_evidence`

Assumed columns:

- `source_file`
- `source_sheet`
- `row_no`
- `normalized_selfpia_product_code`
- `normalized_selfpia_sku_code`
- `raw_product_name`
- `normalized_product_name`
- `raw_option_text`
- `normalized_option_text`
- `extracted_own_sku`
- `smartstore_product_no_candidate`
- `parse_status`
- `parse_warning`
- `evidence_level`

Join order:

1. Read stage evidence.
2. Join selfpia SKU through `product_code.code_alias` with `code_system='selfpia_sku'`.
3. Join canonical SKU/product data through `product_code.v_sku_canonical`, `product_code.sku_master`, and `product_code.product_master`.
4. Join own_sku through `product_code.code_alias` with `code_system='own_sku'`.
5. Join Smartstore aliases from `product_code.code_alias`.
6. Join current Smartstore mapping from `product_code.sku_channel_mapping`.
7. Build normalized option keys.
8. Detect duplicate and blocked-risk conditions.
9. Classify into confidence tiers.

## High-Confidence Criteria

A row can be `auto_match_high_confidence` when all of these pass:

- selfpia SKU joins to exactly one DB SKU.
- Smartstore productNo candidate exists.
- option text exists.
- same selfpia SKU has one productNo candidate in stage evidence.
- same productNo + normalized option text has one selfpia SKU in stage evidence.
- own_sku is absent or joins to the same SKU.
- normalized option key matches DB option key or is absorbed by the normalization rules.
- no blocked-risk condition fires.

Product-name support is useful but should not over-block PlayAuto option rows when SKU/productNo/option evidence is strong and there is no product-name conflict.

## Medium-Confidence Criteria

A row can be `auto_match_medium_confidence` when:

- selfpia SKU joins to exactly one DB SKU.
- Smartstore productNo candidate exists.
- option text exists.
- no blocked-risk condition fires.
- no hard duplicate is present.
- option evidence is present but needs light review, or own_sku/product-name support is incomplete.

Medium-confidence rows are good candidates for sampled review.

## Manual Review Criteria

Use `manual_review_required` when the row cannot be safely grouped but does not hit blocked risk:

- selfpia SKU missing.
- Smartstore productNo missing.
- selfpia SKU does not join to DB.
- product name is weak and option match is weak.
- own_sku needs human confirmation.
- parser evidence is incomplete but not blocked.

## Blocked-Risk Criteria

Use `blocked_risk` when any hard blocker exists:

- crystal/Crystal AB confusion.
- unsafe AB token.
- white-gold/silver confusion.
- set/pair/single/quantity conflict.
- duplicate selfpia SKU to multiple productNo values.
- duplicate productNo + option text to multiple selfpia SKUs.
- own_sku maps to multiple SKU IDs.
- selfpia SKU maps to multiple SKU IDs.
- own_sku maps to a different SKU than the selfpia SKU.
- clear product-name conflict.
- malformed bracket or own_sku parse error.
- multi-line alignment mismatch.

## Summary Output

The validation SQL should report:

- `total_stage_rows`
- `excel_parse_good_candidate_count`
- `auto_match_high_confidence_count`
- `auto_match_medium_confidence_count`
- `manual_review_required_count`
- `blocked_risk_count`
- `parse_warning_count`
- `selfpia_sku_joined_count`
- `own_sku_joined_count`
- `smartstore_product_no_candidate_count`
- `normalized_option_match_count`
- `normalization_absorbed_count`
- `rose_gold_family_count`
- `yellow_gold_family_count`
- `order_made_text_absorbed_count`
- `one_type_absorbed_count`
- `mm_bar_absorbed_count`
- `crystal_crystal_ab_blocked_count`
- `ab_token_warning_count`
- `white_gold_silver_blocked_count`
- `quantity_set_blocked_count`
- `duplicate_selfpia_sku_blocked_count`
- `duplicate_product_option_blocked_count`

## Review Workflow

Review should be operationally tiered:

- High confidence: review summary and small sample, then dryrun.
- Medium confidence: review summary, samples by pattern, and normalization buckets.
- Manual review: inspect rows that lack enough evidence.
- Blocked risk: inspect separately; do not mix with auto-match candidates.

No production DB, remote DB, NAS DB, SQL execution, Excel import, or file export is part of this design step.
