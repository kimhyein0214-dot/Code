# Channel Presence Matching Rate Plan v1

## Purpose

Product-code matching progress must not treat every selfpia SKU without a channel code as a true missing match. Selfpia can retain old products and options that are no longer sold, exposed, or operated in Smartstore, MakeShop, Ably, or PlayAuto. If those historical selfpia SKUs are counted as channel missing, matching rates look artificially low and manual-review queues become noisy.

This plan separates true matching work from channel presence uncertainty. It keeps the confidence-tier direction from the Smartstore Excel evidence work: maximize useful automatic matching candidates, push matchable rows into high/medium confidence, and reserve `blocked_risk` or `manual_review_required` for genuinely risky or ambiguous cases.

Representative reporting should use this wording:

> 셀피아 전체 기준으로 보면 미매칭처럼 보이는 건이 많지만, 셀피아에는 과거 상품이나 판매처에서 이미 내려간 상품도 남아 있습니다. 따라서 판매처 자료에 전혀 등장하지 않는 상품은 해당 판매처 기준 미운영/과거 상품으로 분리하고, 실제 자동매칭률과 수동검수율은 판매처에 실제 존재하는 상품 기준으로 계산하는 것이 더 정확합니다.

## Why Simple Missing Is Risky

Simple missing means:

- selfpia SKU exists
- channel mapping/alias does not exist
- therefore count as unmatched

That is too blunt because:

- Selfpia may still contain historical products.
- Channel shops may have deleted or hidden old listings.
- Some products may never have been operated in a specific channel.
- Image missing or own_sku missing can make a SKU look like a review target even when the channel item is absent.
- Reporting against the full selfpia universe can understate real channel matching progress.

So absence from a channel should be classified, not automatically treated as a failed match.

Wrong interpretation:

```text
selfpia_sku exists
Smartstore productNo is missing
=> smartstore_missing
=> manual review required
```

Correct interpretation:

```text
selfpia_sku exists
no evidence exists for the target channel
=> channel_absent_or_inactive
=> possible historical/non-operated channel item
=> exclude from manual-review denominator
```

If any target-channel evidence exists, classify it as channel-present and then decide among `matched_confirmed`, `auto_match_high_confidence`, `auto_match_medium_confidence`, `manual_review_required`, `blocked_risk`, or `unknown_need_check`.

## Two Matching Rate Denominators

### `selfpia_total_based_matching_rate`

This is a broad reference metric.

Formula:

```text
(matched_confirmed + auto_match_high_confidence + auto_match_medium_confidence)
/ selfpia_total_rows
```

Use it for inventory-wide visibility only. It may be low because it includes historical, deleted, hidden, or non-operated channel items.

### `channel_presence_based_matching_rate`

This is the recommended representative reporting metric.

Formula:

```text
(matched_confirmed + auto_match_high_confidence + auto_match_medium_confidence)
/ channel_present_rows
```

Use it for executive progress and practical workflow planning. `channel_present_rows` means channel-present evidence plus unresolved `unknown_need_check` rows, and it excludes rows classified as `channel_absent_or_inactive`.

## Core Classes

### `matched_confirmed`

The SKU already has confirmed channel identity evidence:

- confirmed channel code alias
- confirmed Smartstore productNo/optionNo alias
- existing `product_code.sku_channel_mapping`

### `auto_match_high_confidence`

Strong candidate for automatic matching review:

- selfpia SKU is known
- channel productNo or option text exists
- own_sku or option-normalization evidence is strong
- no high-risk collision is present

This is still not a direct apply target. It must go through validate, dryrun, user approval, local apply, and postcheck.

### `auto_match_medium_confidence`

Likely match with some expression differences or missing supporting evidence:

- core channel presence exists
- matching evidence is sufficient for summary/sample review
- minor option differences can be absorbed by normalization
- no blocked-risk condition is present

### `manual_review_required`

The channel item appears to exist, but matching evidence is weak or ambiguous:

- channel presence evidence exists
- no confirmed mapping
- no strong automatic matching evidence
- not risky enough to block outright

### `channel_absent_or_inactive`

Selfpia has the SKU, but the target channel appears not to operate it.

This is not a matching failure. It means the item is likely historical, deleted, hidden, non-exposed, or non-operated in that channel. It should be excluded from the priority manual-review denominator or placed in a separate hold bucket.

Equivalent operational wording:

- `channel_absent_or_inactive`
- `channel_not_listed_as_inactive`

The SQL keeps the stable name `channel_absent_or_inactive`.

### `unknown_need_check`

Channel presence itself is unclear:

- no clear present evidence
- no enough absent evidence
- needs more channel evidence before being called missing or inactive

### `blocked_risk`

Automatic matching should not proceed:

- `크리스탈`/`크리스탈AB` confusion
- unsafe `AB` token
- `화이트골드`/`실버` confusion
- `세트`/`한쌍`/`낱개`/quantity conflict
- selfpia SKU split across multiple channel productNo values
- channel productNo + option text maps to multiple selfpia SKUs
- own_sku maps to multiple SKU IDs

## Channel Presence Evidence

Treat a SKU as having channel presence evidence if at least one of the following exists for that channel:

- channel productNo or optionNo exists
- channel-specific `code_alias` exists
- `product_code.sku_channel_mapping` exists
- PlayAuto Smartstore evidence includes the SKU/productNo/option text
- price-update list has a channel-specific code in the same row
- MakeShop, Ably, Smartstore, or PlayAuto source form includes the item
- product name and option name appear with a channel code in the same evidence row
- channel product number exists even if only option matching is incomplete

Future stage evidence can come from:

- `stage_excel_smartstore_evidence`
- `stage_excel_cross_channel_evidence`
- `stage_playauto_smartstore_evidence`

These are design assumptions only. This plan does not create or import any stage data.

## `channel_absent_or_inactive` Candidate Conditions

Classify a row as `channel_absent_or_inactive` candidate when all are true:

- selfpia SKU exists in DB
- no channel productNo or optionNo exists
- no channel-specific alias exists
- no `sku_channel_mapping` exists
- no PlayAuto, price-update, or source-form evidence exists
- the row was pulled into review only by secondary gaps such as image missing or own_sku missing

Do not express this as "unmatched" or "failed". Use "separated as possible channel inactive/deleted/non-operated".

## Reporting Formulas

Definitions:

- `total_review_rows`: all SKU/channel rows considered by the diagnostic.
- `channel_present_rows`: rows with channel presence evidence plus rows still needing presence confirmation (`unknown_need_check`).
- `channel_absent_or_inactive_rows`: rows separated as likely not operated in that channel.

Representative automatic matching rate:

```text
(auto_match_high_confidence + auto_match_medium_confidence + matched_confirmed)
/ channel_present_rows
```

Representative manual review rate:

```text
(manual_review_required + unknown_need_check)
/ channel_present_rows
```

Separate hold rate:

```text
channel_absent_or_inactive
/ total_review_rows
```

Do not call `channel_absent_or_inactive` a matching failure. It is a separate channel-presence bucket.

Do not include `channel_absent_or_inactive` in the missing rate. Express it as "판매처 미운영/과거 상품 분리율" or "channel inactive/historical separation rate".

## Channel-Specific Reporting

Report the metrics separately for:

- `smartstore`
- `makeshop`
- `ably`
- `playauto`

Each channel can have a different denominator because each channel can operate a different subset of selfpia SKUs.

## Link to Confidence Tiers

Use the existing confidence-tier posture:

- Push matchable rows into `auto_match_high_confidence` or `auto_match_medium_confidence`.
- Keep risky rows in `blocked_risk`.
- Keep ambiguous present rows in `manual_review_required`.
- Keep parser/evidence warnings visible as `parse_warning`.
- Keep channel-absence rows separate as `channel_absent_or_inactive`.
- Keep unresolved presence rows as `unknown_need_check`.

The important change is that `channel_absent_or_inactive` is not manual review by default.

## Operating Principles

- Maximize automatic matching candidates when evidence is strong.
- Use summary/sample review for medium-confidence candidates.
- Put only real risk into `blocked_risk`.
- Do not send likely channel-inactive rows into normal manual review.
- Do not apply high/medium candidates directly.
- Preserve workflow: validate → dryrun → user approval → local apply → postcheck.

No DB connection, SQL execution, stage creation, Excel import, CSV/JSON/XLSX generation, or remote DB work is part of this design step.
