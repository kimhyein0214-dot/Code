# Channel Presence Matching Rate Lite Run Plan v1

## Purpose

`sql/select_channel_presence_matching_rate_lite_v1.sql` is a read-only local summary query for channel presence based matching rates. It is the executable-lite companion to the broader channel presence plan, but it does not use Excel stage tables or import outputs.

The goal is to estimate current Smartstore and MakeShop matching progress with only existing local DB tables.

## Tables Used

The lite SQL uses only:

- `product_code.v_sku_canonical`
- `product_code.code_alias`
- `product_code.sku_channel_mapping`
- `product_code.product_image`

It intentionally does not use conceptual stage relations such as:

- `stage_excel_smartstore_evidence`
- `stage_excel_cross_channel_evidence`
- `stage_playauto_smartstore_evidence`

It also does not use non-available channel tables such as `product_code.channel_product`, `product_code.channel_sku`, or `product_code.channel_sku_review_draft`.

## Scope

Initial channel scope:

- `smartstore`
- `makeshop`

Ably and PlayAuto are left out of the lite SQL for now because current DB-only evidence may be too thin for a useful presence denominator.

## Reporting Rule

Prefer:

- `channel_presence_based_auto_match_rate_pct`

over:

- `selfpia_total_based_auto_match_rate_pct`

Reason: selfpia may contain historical products or products no longer operated in a channel. Those rows should be separated as `channel_absent_or_inactive`, not counted as channel mismatches.

`channel_absent_or_inactive` is not a mismatch rate. It is a channel inactive / historical-item separation rate.

## Classification Summary

The SQL classifies each SKU/channel pair into summary buckets:

- `matched_confirmed`: confirmed alias or `sku_channel_mapping` identity exists.
- `auto_match_high_confidence`: candidate alias/mapping evidence appears one-to-one.
- `auto_match_medium_confidence`: channel evidence exists but needs summary/sample review.
- `manual_review_required`: channel evidence exists but matching evidence is insufficient.
- `blocked_risk`: duplicate or conflict risk.
- `unknown_need_check`: DB-only evidence is inconclusive.
- `channel_absent_or_inactive`: no alias or channel mapping evidence exists for that channel.

Because this lite version does not use Excel evidence, it is conservative about channel presence. It should be treated as a DB-only baseline, not the final Excel-enhanced matching rate.

## Output Columns

The query returns summary rows with:

- `summary_type`
- `channel`
- `row_count`
- `rate_pct`
- `denominator_type`
- `note`

Important summary types:

- `selfpia_total_rows`
- `channel_present_rows`
- `channel_absent_or_inactive_rows`
- `matched_confirmed_rows`
- `auto_match_high_confidence_rows`
- `auto_match_medium_confidence_rows`
- `manual_review_required_rows`
- `blocked_risk_rows`
- `unknown_need_check_rows`
- `selfpia_total_based_auto_match_rate_pct`
- `channel_presence_based_auto_match_rate_pct`
- `channel_presence_based_manual_review_rate_pct`
- `channel_absent_or_inactive_rate_pct`

## Rate Formulas

Selfpia-total auto-match rate:

```text
(matched_confirmed + auto_match_high_confidence + auto_match_medium_confidence)
/ selfpia_total_rows
```

Channel-presence auto-match rate:

```text
(matched_confirmed + auto_match_high_confidence + auto_match_medium_confidence)
/ channel_present_rows
```

Channel-presence manual-review rate:

```text
(manual_review_required + unknown_need_check)
/ channel_present_rows
```

Channel inactive / historical separation rate:

```text
channel_absent_or_inactive
/ selfpia_total_rows
```

## Execution Rules

Run only against a local read-only DB.

Do not run against:

- production Supabase
- NAS PostgreSQL
- any remote DB

Before execution, statically confirm:

- SQL is SELECT-only.
- no DML or DDL exists.
- no `\copy` or file output exists.
- no temp table exists.
- no stage table is referenced.
- no non-available channel table is referenced.

## After Running Locally

Check:

- Smartstore `channel_presence_based_auto_match_rate_pct`
- MakeShop `channel_presence_based_auto_match_rate_pct`
- `channel_absent_or_inactive_rate_pct` by channel
- `manual_review_required_rows`
- `blocked_risk_rows`
- whether DB-only evidence is too sparse and needs Excel evidence stage integration later

Use this output as a baseline before building an Excel-enhanced channel presence report.
