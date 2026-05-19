# Manual Review Workbench Candidates Plan v1

## Purpose

Define the SELECT-only candidate scope for the manual review frontend v1.

This is not a frontend implementation, not a DB write workflow, and not an export workflow. The SQL is intended to shape review candidates for a read-only workbench first.

## Scope

The workbench should show rows that remain unresolved after local round-1 auto-match.

Included candidate buckets:

- source conflict.
- warning bucket.
- duplicate SKU.
- narrow risk.
- evidence missing.
- channel_absent_or_inactive_possible.
- existing alias or mapping conflict.
- manual review required.

Excluded from the workbench candidate set:

- clean candidates already locally auto-applied.
- rows with the same existing local channel alias or mapping.
- confirmed/manual mappings that must not be overwritten.
- rows that only belong in deletion or inactive review without a manual matching decision.
- rows whose source evidence has not been staged, because their channel state cannot be judged from the current local source files.

## Manual Match vs Deletion Review

Manual matching and deletion or inactive review must stay separate.

Manual matching asks: which Selfpia SKU should this channel listing map to?

Deletion or inactive review asks: should this channel row be ignored, removed from active matching scope, or classified as not currently operated?

The workbench emits a `review_scope` field:

- `manual_matching_candidate`
- `deletion_or_inactive_review_candidate`

The frontend should filter these separately to avoid turning inactive listings into false manual-match work.

## Row Columns

The SELECT emits the following review-shaped columns:

| Column | Meaning |
|---|---|
| `review_candidate_id` | stable hash id for the review row |
| `channel_code` | normalized channel, not `playauto` |
| `source_system` | source evidence system such as Ably CSV or PlayAuto XLSX |
| `source_file_name` | source file name from stage metadata |
| `source_row_no` | source row number for traceability |
| `evidence_level` | direct, unique, duplicate, missing, source_conflict, or needs_review |
| `review_status_default` | default frontend status, currently pending |
| `risk_type` | primary review bucket |
| `risk_reason` | human-readable reason summary |
| `channel_product_code` | channel product identifier |
| `channel_option_code` | channel option identifier when available |
| `channel_sku_code` | channel SKU code when available |
| `seller_product_code` | seller-side product code |
| `own_sku_code_candidate` | source-side own SKU candidate |
| `selfpia_sku_candidate` | source-side Selfpia SKU candidate |
| `matched_sku_id_candidate` | matched local SKU id when evidence is unique |
| `matched_product_id_candidate` | matched local product id when available |
| `selfpia_product_code` | local product code from product master |
| `selfpia_sku_code` | local Selfpia SKU alias or virtual SKU |
| `own_sku_code` | local own SKU alias |
| `product_name_channel` | channel product name |
| `option_name_channel` | channel option text |
| `product_name_selfpia` | local product name |
| `option_name_selfpia` | local option text |
| `image_status` | `has_image` or `missing_or_unknown` |
| `source_status` | active_candidate, inactive_possible, or unknown |
| `normalized_sale_status` | normalized sale status from stage evidence |
| `normalized_display_status` | normalized display status from stage evidence |
| `normalized_option_status` | normalized option status from stage evidence |
| `suggested_action` | recommended reviewer action |
| `reviewer_decision_placeholder` | pending placeholder |
| `reviewer_note_placeholder` | empty note placeholder |

## Filters

Recommended frontend filters:

- `channel_code`
- `review_status_default`
- `risk_type`
- `evidence_level`
- `source_status`
- `suggested_action`
- `review_scope`
- `image_status`

## risk_type

| risk_type | Meaning |
|---|---|
| `source_conflict` | same channel evidence splits across conflicting Selfpia or channel candidates |
| `warning_bucket` | parse warning, missing channel product code, or similar source warning |
| `duplicate_sku` | duplicated `channel_sku_code` blocked auto-confirm |
| `narrow_risk` | crystal AB, standalone AB, set, quantity, `1+1`, or crystal vs crystal AB conflict |
| `evidence_missing` | no local Selfpia or own SKU candidate could be matched |
| `channel_absent_or_inactive_possible` | source status suggests inactive, hidden, waiting, sold out, or absent channel listing |
| `existing_conflict` | existing alias or mapping points elsewhere and must not be overwritten |
| `manual_review_required` | candidate is not auto-applied but appears reviewable by a person |

## evidence_level

| evidence_level | Meaning |
|---|---|
| `direct` | direct Selfpia SKU evidence resolved to one local SKU |
| `unique` | own SKU, seller code, or channel SKU evidence resolved to one local SKU |
| `duplicate` | evidence splits to duplicate local candidates or duplicate channel SKU |
| `missing` | no local SKU could be resolved |
| `source_conflict` | source evidence conflicts across product/SKU candidates |
| `needs_review` | fallback bucket for rows that should not be automatically decided |

## suggested_action

| suggested_action | Meaning |
|---|---|
| `classify_channel_absent_or_inactive` | decide whether row should be outside active mapping scope |
| `compare_conflicting_candidates` | compare competing Selfpia/channel candidates |
| `inspect_source_warning` | inspect parse warning or missing source key |
| `compare_duplicate_candidates` | inspect duplicated channel SKU or duplicate evidence |
| `manual_option_risk_review` | inspect narrow option/name risk manually |
| `find_or_mark_missing_evidence` | find correct SKU or mark evidence missing |
| `do_not_overwrite_existing_mapping` | existing local mapping blocks auto-change |
| `manual_match_review` | human can likely approve, hold, exclude, or choose another candidate |

## v1 Screen Proposal

Use a compact list or vocabulary-review style screen:

- default table view by channel and risk bucket.
- row expansion for source evidence, product/option comparison, and status details.
- actions: approve, hold, exclude, view other candidates.
- separate tab or filter for `deletion_or_inactive_review_candidate`.
- no operating DB writes in v1.

## Current SQL

`sql/select_manual_review_workbench_candidates_v1.sql`:

- starts `BEGIN READ ONLY`.
- checks `product_ops_test` and `product_ops_tester`.
- reads `product_code_stage.channel_option_evidence`.
- joins local SKU evidence through `selfpia_sku` / `own_sku` alias candidates.
- keeps the v1 executable query stage-centered so it can run as a read-only workbench source.
- emits `image_status = not_checked_in_v1_select`; image joins should be added after the first read-only endpoint shape is confirmed.
- outputs summary rows and bounded samples.
- ends with `ROLLBACK`.

## Read-Only Execution Result

The SELECT was executed locally against `product_ops_test` as `product_ops_tester` in a read-only transaction and ended with `ROLLBACK`.

Guard result: PASS.

Frontend verdict: `READY_FOR_READ_ONLY_WORKBENCH`.

Summary counts:

| Metric | Count |
|---|---:|
| total manual review candidate count | 40,958 |
| manual matching candidates | 24,205 |
| deletion or inactive review candidates | 16,753 |

Channel counts:

| channel_code | Count |
|---|---:|
| ably | 23,740 |
| smartstore | 15,921 |
| coupang | 1,279 |
| kakaotalk_store | 18 |

Risk type counts:

| risk_type | Count |
|---|---:|
| source_conflict | 29,305 |
| warning_bucket | 9,083 |
| narrow_risk | 1,436 |
| evidence_missing | 1,115 |
| channel_absent_or_inactive_possible | 11 |
| duplicate_sku | 8 |

Evidence level counts:

| evidence_level | Count |
|---|---:|
| source_conflict | 29,305 |
| direct | 8,696 |
| missing | 2,949 |
| duplicate | 8 |

Suggested action counts:

| suggested_action | Count |
|---|---:|
| compare_conflicting_candidates | 23,755 |
| classify_channel_absent_or_inactive | 16,753 |
| find_or_mark_missing_evidence | 223 |
| manual_option_risk_review | 219 |
| compare_duplicate_candidates | 8 |

## Result Fields To Check

After read-only execution, confirm:

- total manual review candidate count.
- `channel_code` counts.
- `risk_type` counts.
- `evidence_level` counts.
- `source_status` counts.
- `suggested_action` counts.
- `review_scope` counts, especially manual match vs inactive/delete review separation.
- frontend verdict row.

## Next Steps

A) SELECT result count confirmation.

B) API read-only endpoint design.

C) Frontend workbench v1 read-only implementation.

D) Local-only review decision storage design.

E) Feed manual review outcomes into round-2 auto-match rules.
