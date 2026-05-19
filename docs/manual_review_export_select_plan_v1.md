# Manual Review Export Select Plan v1

## Precheck Summary

`sql/precheck_manual_review_export_v1.sql` was run against the local DB in read-only mode. The final status was `STRUCTURE_PRECHECK_READY_TO_RUN`.

Present and usable tables:

- `product_code.product_master`
- `product_code.sku_master`
- `product_code.code_alias`
- `product_code.product_image`
- `product_code.sku_channel_mapping`
- `product_code.v_sku_canonical`

Missing tables that must not be referenced:

- `product_code.channel_option_mapping`
- `product_code.channel_product`
- `product_code.channel_product_mapping`
- `product_code.channel_sku`
- `product_code.channel_sku_review_draft`

## SELECT Design Principles

The draft SQL in `sql/select_manual_review_export_v1.sql` is SELECT-only. It uses CTEs and `UNION ALL` to produce one review-shaped result set for Smartstore, MakeShop, Ably, and PlayAuto.

It deliberately does not create temp tables, write data, run schema changes, export files, or generate CSV output. It is a review target query only.

All candidate and unreviewed rows use:

- `export_allowed = false::boolean`
- `reviewer_decision = 'pending'::text`

Candidate codes are not treated as confirmed upload values.

## Actual Column Basis

`product_code.v_sku_canonical` is used only through the confirmed columns:

- `sku_id`
- `product_id`
- `selfpia_sku_code`
- `selfpia_product_code`
- `selfpia_option_no`
- `product_name`
- `option_value`

`option_value` is emitted as `option_name` when a review-friendly option label is needed. The draft does not reference unconfirmed columns such as `sku_code`, `product_code`, `option_name`, or `is_active`.

`product_code.code_alias` is used through:

- `target_id`
- `target_type`
- `code_system`
- `code_value`
- `selfpia_product_code`
- `selfpia_option_no`
- `usage_type`
- `is_primary`
- `memo`
- `raw_payload`

Own SKU aliases use `target_type = 'SKU'`, `code_system = 'own_sku'`, `target_id = sku_id`, and `code_value` as the own SKU code.

Smartstore aliases use conditional aggregation over:

- `smartstore_product_no`
- `smartstore_product_no_candidate`
- `smartstore_option_no`
- `smartstore_option_no_candidate`

Product-level Smartstore productNo aliases and SKU-level Smartstore aliases are kept separate before being combined into review columns.

`product_code.sku_channel_mapping` is used only through:

- `sku_id`
- `channel_code`
- `seller_product_code`
- `channel_sku_code`
- `own_sku_code`
- `is_primary`
- `raw_payload`

The channel hierarchy tables are not present in the current local schema, so `channel_product`, `channel_sku`, `channel_product_mapping`, `channel_option_mapping`, and `channel_sku_review_draft` are not used.

`product_code.product_image` is used through:

- `sku_id`
- `product_id`
- `selfpia_sku_code`
- `selfpia_product_code`
- `image_url`
- `thumbnail_url`
- `is_primary`
- `sort_order`

Image presence is based on `image_url` or `thumbnail_url`. The representative image URL is derived from those fields only.

## Channel Shape

Every channel-specific SELECT emits the same column shape, including:

- `source_channel`
- `review_reason`
- canonical SKU/product fields
- `own_sku_code`
- Smartstore split columns: `confirmed_product_no`, `confirmed_option_no`, `candidate_product_no`, `candidate_option_no`
- MakeShop traceability placeholders: `source_row_ref`, `candidate_rank`, `candidate_score`, `match_rule_before`
- `image_missing`
- `own_sku_missing`
- `representative_image_url`
- `export_allowed`
- `reviewer_decision`
- `raw_payload`

## Smartstore

Smartstore keeps product and option identifiers split:

- `confirmed_product_no`
- `confirmed_option_no`
- `candidate_product_no`
- `candidate_option_no`

Confirmed and candidate values are built from `code_alias.code_system` conditional aggregation. Candidate productNo and optionNo values remain separated and blocked from export.

## MakeShop

MakeShop review rows use `sku_channel_mapping.channel_code`, `seller_product_code`, `channel_sku_code`, `own_sku_code`, and `raw_payload`.

Direct traceability columns such as `source_row_ref`, `candidate_rank`, `candidate_score`, and `match_rule_before` are not assumed to exist on `sku_channel_mapping`.

Conservative handling:

- `source_row_ref` may be read from `raw_payload ->> 'source_row_ref'`.
- `match_rule_before` may be read from `raw_payload ->> 'match_rule_before'`.
- `candidate_rank` stays `NULL::integer` until a reviewed numeric payload key is confirmed.
- `candidate_score` stays `NULL::numeric` until a reviewed numeric payload key is confirmed.

These fields are review metadata only and must not be used as export approval.

## Ably And PlayAuto

Ably and PlayAuto are kept candidate-centered until official upload templates and validation rules are confirmed.

Ably requires option number uniqueness recheck before any reviewed export design.

PlayAuto requires multi-line alignment validation before any reviewed export design.

## Image And Own SKU Checks

`product_code.product_image` is summarized by SKU and product to identify `image_missing`.

Own SKU presence is checked through:

- `product_code.sku_channel_mapping.own_sku_code`
- `product_code.code_alias` rows where `target_type = 'SKU'` and `code_system = 'own_sku'`

Rows with missing own SKU are included with `review_reason = 'own_sku_missing'` and remain blocked from export.

## Next Steps

1. Static SQL review.
2. Local DB read-only execution.
3. Result row count confirmation by channel and review reason.
4. Reviewed CSV validation SQL design.
