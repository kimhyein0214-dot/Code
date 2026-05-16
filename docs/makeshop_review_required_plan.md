# MakeShop Review Required Plan

작성일: 2026-05-15

## 현재 완료 상태

MakeShop `auto_confirm v3` 후보는 로컬 `product_ops_test` DB의 `product_code.sku_channel_mapping`에 반영 완료됐다.

| 항목 | 값 |
|---|---:|
| channel_code | `makeshop` |
| inserted_rows | 11,179 |
| postcheck verdict | PASS |
| duplicate channel_sku_code | 0 |
| conflict rows | 0 |
| null key / missing SKU | 0 |
| new_regex_candidate | 91 |
| changed_from_v2 | 8 |
| repeated matched_sku 3+ | 42 rows / 14 keys |

남은 단계는 `review_required` 대상의 원인별 분류, 진단 export, 수동/반자동 처리 기준 설계다. 아직 review 대상 apply는 금지한다.

## Review Required 대략 분포

v3 dryrun 기준 잔여 review 대상:

| 분류 | 대략 row 수 | 기본 판단 |
|---|---:|---|
| `own_sku_ambiguous` | 약 15,777 | 자동해소 금지. 2차 매칭 기준 설계 필요 |
| `null_key` | 약 2,289 | SKU mapping 대상이 아닐 가능성 큼. product-level/meta row 여부 확인 |
| `pattern_unmatched` | 약 732 | regex/토큰 보강 후보. 수동 검토와 alias 후보 추출 필요 |
| `own_sku_not_in_alias` | 약 592 | alias 누락 후보. own_sku alias 보강 workflow 필요 |

숫자는 v3 기준이며, 과거 full dryrun의 v1/v2 수치와 다를 수 있다.

## 처리 원칙

- 운영 DB 반영 금지.
- review 대상 mapping apply 금지.
- ambiguous 자동해소 금지.
- 먼저 SELECT-only 진단 SQL과 CSV export로 근거를 만든다.
- 자동 처리 가능 조건은 보수적으로 정의하고, 조건 외 row는 manual review로 남긴다.

## Null Key Strategy

`null_key`는 `product_uid` 또는 `sto_id`가 비어 있어 `channel_sku_code = product_uid || '-' || sto_id`를 만들 수 없는 row다.

전략:

1. SKU mapping 대상에서 제외한다.
2. `product_uid`만 있는지, `sto_id`만 있는지, 둘 다 없는지 분리한다.
3. `opt_value`, `opt_values`, `product_name`, `barcode`, `status`, `gid`, `ps_num`을 확인해 product-level meta row인지 판단한다.
4. product-level row라면 `sku_channel_mapping`이 아니라 향후 product/channel product metadata 설계 대상으로 분리한다.

추천 export:

- `makeshop_review_null_key_full.csv`
- 컬럼: `product_uid`, `sto_id`, `channel_sku_code`, `product_name`, `opt_value`, `opt_values`, `barcode`, `status`, `gid`, `ps_num`, null pattern flags

## Pattern Unmatched Strategy

`pattern_unmatched`는 key는 있으나 `sto_code`, bracket own_sku, bracket 4-part code를 찾지 못한 row다.

전략:

1. unmatched text를 `opt_values` 우선으로 분석한다.
2. 기존 regex가 놓치는 형식을 분류한다.
3. loose regex는 계속 diagnostic only로 유지한다.
4. 코드처럼 보이는 토큰이 alias unique_1로 연결되는지 별도 진단한다.
5. 실제 코드가 아니라 색상/사이즈/옵션명만 있는 row는 manual review로 남긴다.

자동 후보 조건:

- extracted token이 `own_sku` alias에서 unique_1로 매칭된다.
- `opt_values` 안에 선택 토큰이 존재한다.
- 기존 `channel_sku_code` conflict가 없다.
- SKU inactive가 아니다.

수동검수 조건:

- token이 없거나 코드 패턴이 불명확하다.
- loose token만 존재한다.
- alias match가 0 또는 2개 이상이다.
- product/option text와 SKU option이 불일치한다.

추천 export:

- `makeshop_review_pattern_unmatched_full.csv`
- `makeshop_review_pattern_unmatched_regex_candidates.csv`

## Own SKU Not In Alias Strategy

`own_sku_not_in_alias`는 MakeShop에서 own_sku 후보는 추출됐지만 `product_code.code_alias(code_system='own_sku')`에 존재하지 않는 row다.

전략:

1. distinct `own_sku_code` 기준으로 묶는다.
2. MakeShop product/option sample을 붙인다.
3. `selfpia_sku`, `virtual_sku_code`, `sku_master.option_value`, `product_master.product_name`으로 alias 보강 후보를 찾는다.
4. alias 보강은 `code_alias` 쪽 별도 설계/승인 후 진행한다.
5. alias 보강 전에는 `sku_channel_mapping` apply 대상이 아니다.

자동 alias 보강 후보 조건:

- 후보 own_sku가 특정 SKU 1개와 강하게 연결된다.
- product name 또는 option token이 SKU master와 일치한다.
- 같은 own_sku가 여러 MakeShop row에서 일관되게 같은 SKU 후보를 가리킨다.

수동검수 조건:

- SKU 후보가 없거나 여러 개다.
- product/option text가 불충분하다.
- 동일 own_sku가 서로 다른 제품군에서 재사용된다.

추천 export:

- `makeshop_review_own_sku_not_in_alias_full.csv`
- `makeshop_review_own_sku_alias_backfill_candidates.csv`

## Own SKU Ambiguous Strategy

`own_sku_ambiguous`는 같은 `own_sku` alias가 여러 SKU에 연결되는 구조다. 현재 약 15k row로 가장 큰 잔여 집합이다.

### 구조적 원인

- 같은 own_sku가 여러 SKU option에 연결되어 있다.
- 같은 `product_uid` 안에서 여러 `sto_id`가 반복되며 동일 own_sku를 공유한다.
- MakeShop `opt_value`는 전체 옵션 목록일 수 있고, `opt_values`가 실제 선택 옵션일 가능성이 높다.
- `own_sku`만으로는 SKU unique key가 아니며, option token과 product context가 필요하다.

### 2차 매칭 후보 기준

1. `opt_values` token vs `sku_master.option_value`
   - normalized option text exact match
   - slash-separated token containment
   - size/color/material keyword match
2. `selfpia_sku` alias cross-check
   - candidate SKU의 `selfpia_sku` / `selfpia_product_code`를 함께 표시
   - MakeShop product group과 selfpia product group consistency 확인
3. product context
   - same `product_uid` 내 candidate SKU의 `product_id` 분포 확인
   - 하나의 product_uid가 하나의 product_id로 수렴하면 강한 신호
4. barcode 확인
   - barcode가 SKU-level인지 product-level인지 먼저 진단
   - 같은 barcode가 여러 option row에 반복되면 product-level로 보고 자동해소에 사용하지 않음
   - barcode가 SKU별 unique로 보이면 보조 key 후보

### 자동해소 가능 조건

아래 조건을 모두 만족하는 경우에만 별도 dryrun 후보로 올린다.

- `own_sku` alias 후보 중 정확히 1개 SKU가 선택된다.
- 선택 근거는 `opt_values` token과 `sku_master.option_value`의 강한 일치다.
- same `product_uid` context가 candidate product와 모순되지 않는다.
- 기존 `sku_channel_mapping` conflict가 없다.
- SKU inactive가 아니다.
- barcode를 사용한 경우 barcode가 SKU-level임이 별도 진단으로 확인됐다.

### 수동검수 유지 조건

- candidate SKU가 2개 이상 동률이다.
- option token이 너무 짧거나 일반어다.
- same own_sku가 여러 product group에서 재사용된다.
- barcode가 product-level 반복값이다.
- product_uid context가 여러 product_id로 갈라진다.

추천 export:

- `makeshop_review_ambiguous_full.csv`
- `makeshop_review_ambiguous_candidate_matrix.csv`
- `makeshop_review_ambiguous_token_score_candidates.csv`
- `makeshop_review_ambiguous_barcode_diagnostic.csv`
- `makeshop_review_ambiguous_product_uid_context.csv`

## 다음 SQL 제안

아직 실행/적용 금지. 다음 SQL은 모두 SELECT-only / TEMP TABLE / CSV export 형태로 설계한다.

1. `sql/diagnose_makeshop_review_required_v3_summary.sql`
   - review reason별 count
   - source row sanity
   - auto_confirm already applied coverage check

2. `sql/export_makeshop_review_required_v3_samples.sql`
   - null_key, pattern_unmatched, not_in_alias, ambiguous sample/full export

3. `sql/diagnose_makeshop_own_sku_not_in_alias_backfill.sql`
   - distinct own_sku alias 누락 후보
   - candidate SKU search by selfpia/option/product context

4. `sql/diagnose_makeshop_ambiguous_token_scoring.sql`
   - `opt_values` normalized token과 candidate `sku_master.option_value` 비교
   - unique winner 후보만 별도 표시

5. `sql/diagnose_makeshop_ambiguous_barcode_scope.sql`
   - barcode가 SKU-level인지 product-level인지 분포 확인

6. `sql/export_makeshop_ambiguous_manual_review_matrix.sql`
   - 수동검수용 matrix export

## 단계별 진행안

1. review_required v3 summary SQL 작성 및 실행
2. null_key / pattern_unmatched / not_in_alias / ambiguous CSV export
3. not_in_alias alias 보강 후보 검수
4. ambiguous token scoring 진단
5. 자동해소 가능한 narrow candidate만 별도 dryrun
6. 사용자 승인 전까지 review 대상 apply 금지

## 금지 사항

- 운영 DB 반영 금지.
- review 대상 apply 금지.
- DDL 금지.
- API/Frontend 변경 금지.
