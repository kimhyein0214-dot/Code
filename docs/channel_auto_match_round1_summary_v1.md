# Channel Auto Match Round 1 Summary v1

## Purpose

This document summarizes the local round-1 auto-match results for Smartstore, MakeShop, Ably, and Coupang.

This is a local DB summary only. These results were applied to `product_ops_test`; they have not been applied to the operating Supabase DB, NAS PostgreSQL, or any remote DB.

The correct status is: round-1 locally applicable auto-match portion has been applied. This does not mean every remaining channel mismatch is resolved.

## Summary

| Channel | Local round-1 result | Added mapping evidence | Match rate change | Postcheck | Remaining excluded scope |
|---|---:|---:|---:|---|---|
| Smartstore | applied | 6,684 | 19.85% -> 42.54% | PASS | unresolved rows remain for manual review or additional evidence |
| MakeShop | applied | 241 | 54.55% -> 55.31% | PASS | 1,006 of 1,247 candidates excluded by code evidence, duplicate, risk, or AB rules |
| Ably | applied | 2,273 clean candidates | local first-pass only | PASS | source conflict, warning, duplicate, inactive, evidence missing, and 751 narrow-risk rows excluded |
| Coupang | applied | 539 clean candidates | local first-pass only | PASS | warning, inactive, and 26 narrow-risk rows excluded |

## Channel Details

### Smartstore

- Local DB round-1 auto-match apply completed.
- Additional applied count: 6,684.
- Auto-match rate changed from 19.85% to 42.54%.
- Postcheck verdict: PASS.
- Remaining unmatched or excluded rows should not be treated as all true missing mappings. Some may be past-sale, inactive, hidden, non-operated, or otherwise absent from the current active channel scope.

### MakeShop

- Local DB round-1 auto-match apply completed.
- Additional applied count: 241.
- Auto-match rate changed from 54.55% to 55.31%.
- Postcheck verdict: PASS.
- The wider candidate pool had 1,247 rows, but only 241 were safely applied.
- Excluded buckets remain:
  - AB-related candidates: 14.
  - duplicate evidence.
  - evidence missing.
  - risk candidates.
  - candidates without enough direct or unique code evidence.

### Ably

- Local DB round-1 auto-match apply completed.
- Clean applied candidates: 2,273.
- Inserted `ably_product_no`: 2,273.
- Inserted `ably_option_no`: 561.
- Total inserted `code_alias`: 2,834.
- Postcheck verdict: PASS.
- Excluded buckets remain:
  - narrow risk: 751.
  - source conflict.
  - warning bucket.
  - duplicate SKU.
  - inactive.
  - evidence missing.
- These excluded rows remain for manual review or additional source verification. They were not applied in round 1.

### Coupang

- Local DB round-1 auto-match apply completed.
- Clean applied candidates: 539.
- Inserted `coupang_product_no`: 539.
- Inserted `coupang_option_no`: 0.
- Postcheck verdict: PASS.
- Excluded buckets remain:
  - narrow risk: 26.
  - warning: 140.
  - inactive: 718.
- Coupang round 1 was product-alias only because the inspected evidence did not provide safe option alias candidates.

## Exclusion Principles

The excluded rows are intentionally not applied. They should be routed to manual review or additional evidence inspection when useful.

Common exclusion reasons:

- source conflict across files or systems.
- warning bucket rows, especially missing channel product code or parse warnings.
- duplicate SKU or duplicate channel-code risk.
- inactive, hidden, waiting, stopped, sold-out, or otherwise non-active source status.
- evidence missing, where no clear Selfpia SKU, own SKU, seller product code, or unique channel evidence exists.
- narrow risk keyword buckets, including crystal AB, standalone AB, set, quantity, `1+1`, or crystal vs crystal AB conflict.
- existing confirmed/manual values that must not be overwritten.

## Remaining Unmatched Interpretation

Remaining unmatched rows are not automatically errors.

They may include:

- products with old sales history.
- inactive or discontinued channel listings.
- hidden or not-displayed products.
- channel-absent products that should not be mapped.
- duplicate or ambiguous option rows.
- rows that need image/name/option inspection before a safe decision.

Manual review should therefore distinguish true missing mappings from channel_absent_or_inactive cases.

## Current Recommendation

The next step is not another broad auto-apply.

The next step should be a manual review frontend scope that lets reviewers quickly inspect excluded and unresolved buckets by channel, risk type, evidence level, and source status. Approved review outcomes can later be analyzed and converted into safer round-2 matching rules.
