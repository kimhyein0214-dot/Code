# PlayAuto Evidence Reduction Plan v1

## Purpose

This document describes how PlayAuto data can be used as supporting evidence to reduce manual review volume for Smartstore, MakeShop, and Ably.

PlayAuto evidence is not treated as a confirmed export source. It is used only to classify review rows into safer evidence groups before any later dry-run or apply design.

## Why PlayAuto Can Help

The current manual review population is large:

| area | row_count |
| --- | ---: |
| total_review_rows | 119,560 |
| Smartstore | 32,536 |
| MakeShop | 20,442 |
| Ably | 33,291 |
| PlayAuto | 33,291 |
| image_missing | 54,048 |
| own_sku_missing | 1,252 |
| Smartstore candidate_or_unreviewed | 11,054 |
| Smartstore missing | 7,657 |
| MakeShop missing | 6,617 |

PlayAuto can reduce manual matching when it connects the same internal SKU to marketplace-facing product or option codes. If PlayAuto evidence agrees with Smartstore candidates or provides a marketplace code for missing MakeShop/Ably rows, the row may move from broad manual review into a smaller review-relaxed group.

## PlayAuto Is A Hub

PlayAuto must be treated as a sales-channel hub, not as a single marketplace.

The important source structures are:

- Shopping-mall product data: shopping mall account, shopping mall product number, seller management code, option, SKU, price, quantity, and status.
- SKU product data: SKU-code reference data.

This means PlayAuto internal codes and actual marketplace codes must remain separate. A PlayAuto code can be useful evidence, but it does not automatically prove a Smartstore, MakeShop, or Ably confirmed code.

## Smartstore Candidate Support

Smartstore candidates can be strengthened when PlayAuto evidence points to the same SKU and agrees with both candidate values:

- `candidate_product_no` equals PlayAuto seller product code.
- `candidate_option_no` equals PlayAuto channel SKU or option-like code.
- The row is still blocked with `export_allowed = false`.
- The reviewer decision remains `pending`.

Rows that meet this evidence condition are classified as `playauto_supported_auto_confirm_candidate`. This means they are candidates for a later auto-confirm readiness rule, not immediate confirmed codes.

If PlayAuto evidence exists but does not exactly match the Smartstore candidate pair, the row remains review-required. Conflicting evidence is classified separately.

## MakeShop Missing Support

For MakeShop missing rows, PlayAuto evidence may reduce review effort when the same `sku_id` or `own_sku` has PlayAuto product or option evidence.

This does not confirm MakeShop mapping. It only indicates that the reviewer may have a stronger clue for the missing channel product or option code.

MakeShop rows with PlayAuto evidence are classified as `playauto_supported_review_relaxed` unless a direct conflict is detected.

## Ably And PlayAuto Held Rows

Ably missing rows can also be reclassified when PlayAuto evidence exists for the same SKU or own SKU.

However, Ably still needs product-number and option-number semantics confirmed, including option number uniqueness and official upload template review. PlayAuto evidence can help prioritize Ably rows, but it does not make Ably export-ready.

PlayAuto missing rows remain a separate structure problem until hub code, marketplace code, and multi-line option alignment are verified.

## Evidence Statuses

The diagnostic SQL reports these statuses:

| evidence_status | meaning |
| --- | --- |
| `playauto_supported_auto_confirm_candidate` | Smartstore candidate pair is directly supported by PlayAuto evidence. |
| `playauto_supported_review_relaxed` | PlayAuto evidence exists and can reduce manual lookup effort, but it is not enough for automatic confirmation. |
| `playauto_conflict_review_required` | PlayAuto evidence exists but conflicts with candidate product or option values. |
| `no_playauto_evidence` | No usable PlayAuto evidence was found by SKU or own SKU. |
| `playauto_structure_needs_mapping` | PlayAuto evidence exists but the hub or marketplace code structure is not specific enough. |

## Risks

PlayAuto internal code and actual marketplace code can be confused. This is the main risk.

Other risks:

- Multi-line option, SKU, price, quantity, and status alignment may be wrong or unverified.
- own_sku alone must not trigger automatic confirmation.
- Product-name similarity alone must not trigger automatic confirmation.
- Candidate code values must not become export sources without a later dry-run and approval sequence.
- Ably and PlayAuto final export design still depends on official template confirmation.

## Diagnostic SQL

File:

- `sql/select_playauto_evidence_reduction_v1.sql`

The SQL is SELECT-only and uses currently available structures:

- `product_code.v_sku_canonical`
- `product_code.code_alias`
- `product_code.sku_channel_mapping`

It does not use missing `channel_*` tables.

The SQL compares:

- Smartstore candidate/missing rows against PlayAuto SKU evidence.
- MakeShop missing rows against PlayAuto SKU or own SKU evidence.
- Ably missing rows against PlayAuto SKU or own SKU evidence.

## Next Steps

1. Static review the diagnostic SQL and this plan.
2. Run the SQL only in an approved local read-only session.
3. Review counts by `evidence_status`.
4. Review counts by `source_channel + evidence_status`.
5. If `playauto_supported_auto_confirm_candidate` is meaningful, design a stricter auto-confirm-ready rule.
6. Any dry-run apply SQL must be written separately and approved separately.
7. User approval, local apply, and postcheck are required before any confirmed or export promotion.
