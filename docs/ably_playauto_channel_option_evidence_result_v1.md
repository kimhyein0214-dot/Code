# Ably / PlayAuto Channel Option Evidence Result v1

## Scope

This step creates normalized stage evidence from already-imported Ably / PlayAuto raw stage rows.

This is not automatic matching apply:

- No operating Supabase access.
- No NAS PostgreSQL access.
- No remote DB access.
- No `product_code.code_alias` changes.
- No `product_code.sku_channel_mapping` changes.
- No confirmed/manual overwrite.
- No source CSV/XLSX modification.
- No source CSV/XLSX git add.
- No export/backup copy creation.

Target table:

- `product_code_stage.channel_option_evidence`

## Evidence Generation Logic

### Ably

Source: `product_code_stage.ably_raw`

Mapping:

- `channel_code`: `ably`
- `channel_account`: `pink_rocket@naver.com`
- `raw_product_no` -> `channel_product_code`
- `raw_option_no` -> `channel_option_code`
- `raw_seller_product_code` -> `seller_product_code`
- `raw_solution_unique_code` -> `own_sku_code_candidate`
- `raw_product_name` -> `product_name`
- `raw_full_option_name`, `raw_option1`, `raw_option2` -> option evidence
- `raw_stock_qty`, `raw_soldout_status`, `raw_display_status` -> status/stock fields

Expected: one option-level evidence row per Ably raw row.

### PlayAuto

Source: `product_code_stage.playauto_product_raw`, with `product_code_stage.playauto_sku_raw` used as a SKU dictionary check.

Channel branch:

| `raw_mall_account` | `channel_code` |
|---|---|
| `스마트스토어=w_ground` | `smartstore` |
| `에이블리=pink_rocket@naver.com` | `ably` |
| `쿠팡=wworks2010` | `coupang` |
| `카카오톡 스토어=pink_rocket@naver.com` | `kakaotalk_store` |

Rules:

- `channel_code='playauto'` is never inserted.
- `raw_mall_account` is preserved as `channel_account`.
- `raw_mall_product_no` -> `channel_product_code`.
- `raw_seller_management_code` -> `seller_product_code`.
- `raw_online_product_name` -> `product_name`.
- `raw_sku_text` is split on CRLF/LF/CR into evidence rows.
- `raw_option_text` is split on CRLF/LF/CR and aligned to SKU lines.
- If option lines are one more than SKU lines, the first option line is treated as the option header.
- `raw_option_status` is split and aligned to SKU lines.
- SKU lines are checked against the `SKU상품` sheet dictionary.

## Execution Result

Status: executed on local `product_ops_test` only.

Execution:

- Apply SQL: PASS.
- Postcheck SQL: PASS_WITH_WARNINGS.
- Guard result: `current_database=product_ops_test`, `current_user=product_ops_tester`.
- `product_code.code_alias`: unchanged for Ably/PlayAuto evidence.
- `product_code.sku_channel_mapping`: unchanged for Ably/PlayAuto evidence.

Expected:

| Source | Expected evidence rows | Actual evidence rows | Verdict |
|---|---:|---:|---|
| Ably | 9,158 | 9,158 | PASS |
| PlayAuto | 32,082 | 32,082 | PASS |
| Total | 41,240 | 41,240 | PASS |

## Postcheck Requirements

Postcheck SQL: `sql/postcheck_ably_playauto_channel_option_evidence_v1.sql`

Required checks:

- Local guard is `product_ops_test` / `product_ops_tester`.
- Ably evidence rows match Ably raw rows.
- PlayAuto evidence rows match non-empty exploded SKU lines.
- `channel_code='playauto'` count is `0`.
- `reviewer_decision='pending'` for all generated evidence.
- `export_allowed=false` for all generated evidence.
- Required keys are present.
- `product_code.code_alias` Ably/PlayAuto rows remain `0`.
- `product_code.sku_channel_mapping` Ably/PlayAuto rows remain `0`.

Duplicate key checks are reported as review metrics, not automatic failure, because this is a stage evidence table.

## Result Summary

Evidence generated: yes.

Channel distribution:

| Channel | Source system | Evidence rows | Active candidate rows |
|---|---|---:|---:|
| `ably` | `ably_csv` | 9,158 | 6,263 |
| `ably` | `playauto_xlsx` | 14,685 | 4,720 |
| `smartstore` | `playauto_xlsx` | 16,096 | 12,939 |
| `coupang` | `playauto_xlsx` | 1,283 | 565 |
| `kakaotalk_store` | `playauto_xlsx` | 18 | 0 |

Parse status:

| Source system | Parse status | Rows | Parse warning rows |
|---|---|---:|---:|
| `ably_csv` | `ok` | 9,158 | 0 |
| `playauto_xlsx` | `ok` | 22,999 | 0 |
| `playauto_xlsx` | `warning` | 9,083 | 9,083 |

Parse warning summary:

- `missing channel_product_code`: 9,083 PlayAuto evidence rows.
- Ably missing option code: 0 rows.
- PlayAuto missing SKU code: 0 rows.
- The missing product-number rows remain in stage evidence with `parse_status='warning'`; they are not automatic apply candidates.

PlayAuto multi-line alignment:

| Alignment status | SKU dictionary matched | Evidence rows | Verdict |
|---|---:|---:|---|
| `header_option_aligned` | true | 32,082 | PASS |

Duplicate key result:

| Metric | Count |
|---|---:|
| Duplicate `channel_code + channel_product_code + channel_option_code` groups | 0 |
| Duplicate `channel_code + channel_product_code + channel_option_code` rows | 0 |
| Duplicate `channel_code + channel_sku_code` groups | 156 |
| Duplicate `channel_code + channel_sku_code` rows | 312 |

Duplicate SKU rows are reported as a review metric only. They are not treated as evidence-generation failure because this is a staging table.

Safety checks:

- `channel_code='playauto'`: 0 rows.
- `reviewer_decision <> 'pending'`: 0 rows.
- `export_allowed <> false`: 0 rows.
- `product_code.code_alias` Ably/PlayAuto rows: 0.
- `product_code.sku_channel_mapping` Ably/PlayAuto rows: 0.
- Overall postcheck verdict: `PASS_WITH_WARNINGS`.

Notes:

- The warning bucket is expected and useful: PlayAuto rows with missing `쇼핑몰 상품번호` can still provide SKU/option evidence, but should not be treated as direct channel product evidence.
- `channel_option_evidence` is still not an apply table. All generated rows remain pending and non-exportable.

## Next Steps

A) Inspect code evidence against `sku_master`, `product_master`, `code_alias`, and `sku_channel_mapping`.

B) Run unique evidence dryrun.

C) Review samples before local apply.

D) Apply only approved local matching changes.

E) Run postcheck.
