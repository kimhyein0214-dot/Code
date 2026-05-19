# Ably / PlayAuto Stage Import Design v1

## Purpose

Current local DB evidence is not enough to generate Ably or PlayAuto auto-match candidates. The previous inspection found no Ably/PlayAuto `sku_channel_mapping.channel_code` rows and no Ably/PlayAuto `code_alias.code_system` rows.

The two source files are therefore needed as source evidence:

- Ably CSV supplies direct Ably product/option code fields.
- PlayAuto XLSX supplies a multi-marketplace management view that includes Ably, Smartstore, Coupang, and KakaoTalk Store account rows.

This design is analysis only. It does not define executable DDL and does not import data.

## Design Principle

Do not treat PlayAuto as `channel_code='playauto'` for final channel mapping. PlayAuto is a management source system. Its `쇼핑몰(계정)` value must be parsed first, then mapped to the actual channel/account:

| source value | proposed channel_code | channel_account |
|---|---|---|
| `에이블리=pink_rocket@naver.com` | `ably` | `pink_rocket@naver.com` |
| `스마트스토어=w_ground` | `smartstore` | `w_ground` |
| `쿠팡=wworks2010` | `coupang` | `wworks2010` |
| `카카오톡 스토어=pink_rocket@naver.com` | `kakaotalk_store` | `pink_rocket@naver.com` |

PlayAuto-specific IDs may still be retained as source metadata or candidate aliases, but final channel presence should belong to the actual marketplace.

## Recommended Stage Shape

Use a raw-preserving stage structure with an option-level normalized layer.

### Option A: Source-Specific Tables

Conceptual tables:

- `stg.stage_ably_source_raw`
- `stg.stage_ably_options`
- `stg.stage_playauto_source_raw`
- `stg.stage_playauto_options`
- `stg.stage_playauto_sku_dictionary`

This is easiest to reason about because Ably is already option-level while PlayAuto needs line explosion.

### Option B: Unified Channel Source Raw

Conceptual tables:

- `stg.channel_source_raw`
- `stg.channel_source_option_evidence`

This is better long term if more channel files will be imported. It should preserve source-specific raw columns in `raw_payload` while exposing canonical fields.

Recommended path: start with source-specific dryrun views or temp analysis scripts, then converge into a unified `channel_source_option_evidence` shape once parse rules are stable.

## Canonical Field Mapping

| canonical field | Ably CSV | PlayAuto XLSX | note |
|---|---|---|---|
| `source_system` | `ably_csv` | `playauto_xlsx` | source provenance |
| `source_file` | original filename | original filename | store basename only in DB if imported later |
| `source_sheet` | null / `csv` | sheet name | `쇼핑몰상품`, `SKU상품`, etc. |
| `source_row_no` | CSV row number | workbook row number | preserve for audit |
| `channel_code` | `ably` | derived from `쇼핑몰(계정)` | never default PlayAuto rows to `playauto` |
| `channel_account` | optional fixed account | right side of `쇼핑몰(계정)` | e.g. email or store ID |
| `channel_product_code` | `상품 번호` | `쇼핑몰 상품번호` | product-level channel code |
| `channel_option_code` | `옵션 번호` | not explicit in main sheet | PlayAuto may require marketplace-specific option code from another source |
| `seller_product_code` | `판매자 상품코드` | `판매자관리코드` | product/seller code candidate |
| `channel_sku_code` | `옵션 번호` or blank | exploded `SKU` line | PlayAuto SKU may be internal SKU, not marketplace option code |
| `own_sku_code` | `솔루션사 고유코드` or bracket code candidate | exploded `SKU`, `SKU상품.SKU코드`, bracket-like codes | candidate until verified |
| `selfpia_sku_code` | bracket code or verified code candidate | exploded `SKU` if pattern matches selfpia | candidate until verified |
| `product_name` | `상품명` | `온라인 상품명` | support evidence |
| `option_name` | `전체 옵션명` | exploded `옵션` line after header handling | support evidence |
| `option_value` | `옵션1` + `옵션2` | exploded option value / `SKU상품.속성` | support evidence |
| `sale_status` | derived from `품절상태` | `상품상태(수정불가)` | active/inactive classifier |
| `display_status` | `진열상태` | not explicit | PlayAuto has product status, not display status |
| `stock_status` | `품절상태` | `옵션 상태` line and product status | normalize to active/inactive |
| `stock_qty` | `재고수량` | exploded `옵션 판매수량` or `출고수량` | numeric parse required |
| `price` | Ably price columns | `판매가`, `옵션 추가금액` | not matching identity |
| `parse_status` | dryrun parse result | dryrun parse result | `ok`, `warning`, `error` |
| `parse_warning` | warning text | warning text | line mismatch, blank code, inactive |
| `raw_payload` | complete row JSON | complete row JSON | retain source trace |
| `collected_at` | file analysis timestamp | file analysis timestamp | import batch metadata |

## Import Pre-Checks

Before any local stage import:

- Confirm the target database is `product_ops_test`.
- Run import inside an explicit read/write-approved local-only step; this document does not authorize it.
- Confirm the source file hashes and row counts:
  - Ably: `9,158` rows, `29` columns.
  - PlayAuto `쇼핑몰상품`: `4,219` rows, `95` columns.
  - PlayAuto `SKU상품`: `17,968` rows, `4` columns.
- Confirm no source file is copied into `outputs/`, `exports/`, or `backups/`.
- Confirm PlayAuto account values map to explicit channel codes.
- Validate PlayAuto line explosion:
  - `옵션` may have one more line than `SKU` / `옵션 상태`.
  - `SKU`, `옵션 추가금액`, `옵션 판매수량`, `출고수량`, and `옵션 상태` should align after header handling.
  - rows with non-aligning line counts must be parse warnings, not auto-confirm candidates.
- Validate Ably `상품 번호` + `옵션 번호` uniqueness.
- Validate candidate code patterns against current `product_code.code_alias` values.
- Keep all generated candidate rows as `reviewer_decision='pending'` and `export_allowed=false`.

## Candidate Generation Flow

1. Parse and normalize source rows into an option-level evidence shape.
2. Derive `channel_code` and `channel_account`.
3. Extract candidate codes:
   - Ably: `상품 번호`, `옵션 번호`, `판매자 상품코드`, `솔루션사 고유코드`, bracket codes.
   - PlayAuto: `판매자관리코드`, `쇼핑몰 상품번호`, exploded `SKU`, `SKU상품.SKU코드`, `SKU상품.속성`.
4. Join to local DB read models:
   - `product_code.code_alias` where `code_system='selfpia_sku'`.
   - `product_code.code_alias` where `code_system='own_sku'`.
   - `product_code.v_sku_canonical` for product/option text support.
   - existing `product_code.sku_channel_mapping` to avoid duplicate confirmed mapping.
5. Classify candidates.
6. Reduce blocked rows before manual review.
7. Only after sample review and dryrun validation should a local apply plan be written.

## Classification Rules

### Direct Evidence

Use when the source row contains a code that directly and uniquely joins to one local `sku_id`.

Examples:

- Ably `솔루션사 고유코드` or bracket code equals exactly one `selfpia_sku`.
- Ably bracket code or PlayAuto exploded `SKU` equals exactly one `own_sku`, and that own_sku maps to one `sku_id`.
- Existing confirmed `sku_channel_mapping` already has the same `channel_code`, `channel_product_code`, and `channel_option_code` for the same `sku_id`.

### Unique Evidence

Use when direct code evidence is not enough alone but all uniqueness checks pass:

- one source option row
- one candidate local `sku_id`
- one channel product/option identity
- product/option text support is compatible
- no active conflicting mapping
- no warning status such as inactive, deleted, hidden, or paused

Unique evidence may become auto-confirm-ready only after sample review.

### Duplicate Evidence

Use when any candidate key maps to multiple targets or multiple channel identities:

- one `own_sku` maps to multiple `sku_id` values
- one `selfpia_sku` has multiple candidate channel product/option pairs
- one source channel option appears under multiple products
- PlayAuto exploded lines cannot be aligned deterministically
- product/option text contradicts the candidate SKU family

Duplicate evidence must not auto-confirm.

### Evidence Missing

Use when source row lacks a usable code candidate:

- Ably `솔루션사 고유코드` blank and no bracket code extracted
- PlayAuto `SKU` blank
- PlayAuto `쇼핑몰 상품번호` blank where product-level channel identity is required
- only product name / option name exists

Evidence missing is not the same as unmatched; it means the source does not yet provide a safe join key.

### Channel Absent Or Inactive

Separate inactive channel evidence before counting true unmatched rows.

Ably:

- `진열상태='미진열'`
- `품절상태='품절'`
- zero stock may become inactive depending on channel policy

PlayAuto:

- `상품상태(수정불가)` in `판매대기`, `수정대기`, `승인대기`, `일시품절`, `판매중지`
- option-level `옵션 상태` line is `N`
- blank `쇼핑몰 상품번호` with `판매대기` is likely not live-channel absence, not a failed match

Only active rows with usable code evidence should enter the primary auto-match denominator.

## Manual Review Reduction Strategy

Before sending rows to the manual review UI:

- discard or separately bucket inactive/absent rows
- collapse exact duplicate source evidence by `channel_code`, `channel_account`, `channel_product_code`, `channel_option_code`, and candidate `sku_id`
- require code evidence before name similarity is considered
- use product-name and option-name matching only as support, not as identity
- split PlayAuto by real marketplace account first
- validate PlayAuto `SKU` lines against `SKU상품.SKU코드`
- bucket missing `쇼핑몰 상품번호` rows by product status
- block rows with `own_sku` multi-target conflicts
- block rows with line-alignment warnings
- keep `export_allowed=false` for all candidates until confirmed

## Suggested Stage Output Metrics

Every dryrun should report:

- source row count
- option-level row count after explosion
- active option row count
- inactive/absent row count
- source rows with usable selfpia_sku candidate
- source rows with usable own_sku candidate
- source rows with channel product code
- source rows with channel option code
- unique direct candidates
- duplicate/conflict candidates
- evidence-missing rows
- parse-warning rows
- sample rows for every blocker class

## Next Steps

A. Stage import dryrun design

- write a dryrun parser specification and expected row-count checks
- do not import yet

B. Local stage import

- only after approval, create local-only stage data
- target local `product_ops_test` only

C. Code evidence inspection

- inspect staged source evidence against `product_code.code_alias`, `sku_master`, `product_master`, and `sku_channel_mapping`

D. Unique evidence dryrun

- generate SELECT-only candidate classification
- no apply

E. Sample review

- review high-confidence samples and duplicate blockers

F. Local apply

- only after sample review and explicit approval
- do not overwrite confirmed/manual mappings

G. Postcheck

- verify row counts, conflict counts, channel-presence matching rates, and inactive buckets

## Safety Notes

- No operating Supabase access.
- No NAS PostgreSQL access.
- No remote DB access.
- No DB changes.
- No DDL.
- No INSERT/UPDATE/DELETE/MERGE.
- No import/export files generated.
- Original XLSX/CSV files remain unmodified and unstaged.
- Existing pending SQL files are not modified.
