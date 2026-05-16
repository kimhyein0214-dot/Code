# MakeShop Auto Confirm Apply Plan

작성일: 2026-05-15

## 목적

`outputs/makeshop_auto_confirm_candidates_v3.csv`를 기준으로 MakeShop 자동확정 후보를 `product_code.sku_channel_mapping`에 반영하기 위한 설계안이다.

이 문서는 설계안이며, 실제 apply SQL이 아니다. 실제 DB 영구 변경은 아직 금지 상태다.

## Source

| 항목 | 값 |
|---|---|
| source CSV | `outputs/makeshop_auto_confirm_candidates_v3.csv` |
| container path | `/tmp/makeshop_auto_confirm_candidates_v3.csv` |
| expected rows | 11,179 |
| existing_regex | 11,088 |
| new_regex_candidate | 91 |
| duplicate channel_sku_code | 0 |
| conflict | 0 |
| changed_from_v2 | 8 |
| repeated matched_sku 3+ | 42 rows / 14 keys |

## Target

| 항목 | 값 |
|---|---|
| target table | `product_code.sku_channel_mapping` |
| channel_code | `makeshop` |
| channel_sku_code | `product_uid || '-' || sto_id` from export CSV |
| seller_product_code | `seller_product_code_raw` / MakeShop `product_uid` |
| channel SKU raw | `sto_id_raw`, if a compatible target/raw payload column exists |
| internal SKU | `matched_sku_id` |

## Column Mapping Policy

`sku_channel_mapping` 실제 컬럼 구조는 dryrun SQL에서 `information_schema.columns`로 확인한다.

기본 insert 후보 컬럼:

| target column | source |
|---|---|
| `sku_id` | `matched_sku_id::uuid` |
| `channel_code` | `makeshop` |
| `channel_sku_code` | `channel_sku_code` |
| `seller_product_code` | `seller_product_code_raw`, if column exists |
| `own_sku_code` | `own_sku_code`, if column exists |
| `is_primary` | `false`, if column exists |
| `raw_payload` | JSON metadata, if column exists |
| `created_at` | `now()`, if column exists |
| `updated_at` | `now()`, if column exists |

CSV metadata such as `extraction_method`, `regex_pattern_used`, `auto_confirm_type`, `repeated_matched_sku_3plus_flag`, `changed_from_v2_flag`, `sto_id_raw`, and matched product/option fields are stored in `raw_payload` when that column exists. If no compatible column exists, those values remain dryrun/postcheck-only and are excluded from insert.

## Conflict Policy

Conflict key:

- `channel_code = 'makeshop'`
- `channel_sku_code = source.channel_sku_code`

Policy:

- no existing mapping: insert candidate
- existing same SKU: idempotent skip
- existing different SKU: conflict, excluded from insert
- duplicate source `channel_sku_code`: blocker for actual apply
- null required key or missing `matched_sku_id`: blocker for actual apply

## Review Flags

`repeated_matched_sku_3plus` is not an apply blocker. It remains a review flag and is stored in `raw_payload` if possible.

`new_regex_candidate` 91 rows and `changed_from_v2` 8 rows are included in the apply candidate set, but the dryrun and postcheck must surface their counts separately before actual apply is approved.

## Dryrun Apply

Prepared dryrun SQL:

- `sql/dryrun_apply_makeshop_auto_confirm_v3.sql`

The dryrun:

1. Loads `/tmp/makeshop_auto_confirm_candidates_v3.csv` into a TEMP table.
2. Checks `product_ops_test`.
3. Reads `information_schema.columns` for `product_code.sku_channel_mapping`.
4. Classifies source rows into insert candidates, idempotent skips, conflicts, duplicate source keys, null required keys, and missing SKU rows.
5. Performs an INSERT simulation inside a transaction using only existing target columns.
6. Prints postcheck counts.
7. Ends with `ROLLBACK`.

## Gates Before Real Apply SQL

Actual apply SQL may be written only after:

1. dryrun apply result is PASS:
   - source rows = 11,179
   - duplicate source channel_sku_code = 0
   - null required keys = 0
   - missing matched SKU = 0
   - conflict existing different SKU = 0
   - inserted_rows equals expected insert candidate rows
   - transaction postcheck delta matches inserted_rows
2. User explicitly approves writing real apply SQL.
3. Real apply SQL is separately reviewed before execution.

## Current Prohibitions

- No real apply SQL yet.
- No DDL.
- No persistent DB changes.
- No operation DB/API/Frontend changes.
