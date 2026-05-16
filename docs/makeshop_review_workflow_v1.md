# MakeShop Review Workflow v1

작성일: 2026-05-15

## 목적

MakeShop `auto_confirm v3` 로컬 apply 이후 남은 `review_required` 19,408건을 사람이 검수하고, 향후 검증 SQL 및 dryrun apply 단계로 넘기기 위한 운영 기준을 정의한다.

이 문서는 수동 검수 프로세스 설계 문서다. review 대상 apply SQL, DDL, 운영 DB 반영, API/Frontend 변경은 포함하지 않는다.

## 현재 상태

| 항목 | 값 |
|---|---:|
| auto_confirm v3 local apply | 11,179 rows |
| auto_confirm postcheck | PASS |
| review_required matrix export | 19,408 rows |
| existing mapping different SKU | 0 |
| unapplied auto candidate | 0 |

## Review CSV별 목적

| CSV | rows | 목적 |
|---|---:|---|
| `makeshop_review_ambiguous_weak_top1_matrix.csv` | 12,585 | token score상 top1 후보가 단독으로 잡힌 ambiguous row. 자동확정은 금지하고, 사람 검수 우선순위 파일로 사용한다. |
| `makeshop_review_ambiguous_manual_matrix.csv` | 3,192 | 후보가 복수이거나 점수 동률/불충분한 ambiguous row. candidate 목록 전체를 보고 수동 판단한다. |
| `makeshop_review_not_in_alias_matrix.csv` | 592 | MakeShop에서 추출한 `own_sku_code`가 `code_alias(code_system='own_sku')`에 없는 row. alias 누락 후보 또는 수동 보류 대상으로 관리한다. |
| `makeshop_review_null_key_matrix.csv` | 2,289 | `product_uid` 또는 `sto_id`가 비어 `channel_sku_code`를 만들 수 없는 row. SKU mapping 제외 또는 product-level/meta row 여부를 분류한다. |
| `makeshop_review_pattern_loose_matrix.csv` | 750 | bracket regex 미매칭 또는 loose regex only row. regex 보강 후보인지, 수동 보류인지 판단한다. |

## 검수 우선순위

1. `ambiguous_weak_top1`
   - 단독 top1 후보가 있어 가장 빠르게 사람 검수 효율을 낼 수 있다.
   - 단, strong 자동해소 후보는 0이므로 일괄 자동 apply는 금지한다.

2. `not_in_alias`
   - alias 누락 여부를 사람이 확인하면 `backfill_own_sku_alias` 또는 `manual_hold`로 분기할 수 있다.
   - normalized alias 자동 backfill 후보는 0이므로 직접 증거 확인이 필요하다.

3. `pattern_loose`
   - 반복 패턴이 확인되면 향후 regex 후보로 관리한다.
   - loose-only는 자동확정 제외 원칙을 유지한다.

4. `ambiguous_manual`
   - 후보 비교가 가장 어렵고 비용이 크다.
   - candidate option value, selfpia alias, product name, barcode 등 다중 증거 기반으로 검수한다.

별도: `null_key`

- SKU option mapping 대상에서 우선 제외한다.
- product-level/meta row, 옵션 없는 상품 row, 원본 CSV 구조 row인지 분류한다.

## CSV 추가 검수 컬럼 제안

각 matrix CSV를 사람이 검수할 때 아래 컬럼을 추가한 별도 reviewed CSV를 만든다.

| 컬럼 | 필수 여부 | 설명 |
|---|---|---|
| `review_status` | 필수 | 검수 상태 enum. |
| `reviewer` | apply 후보 필수 | 검수자 식별자. |
| `reviewed_at` | apply 후보 필수 | 검수 완료 시각. ISO-8601 또는 `YYYY-MM-DD HH:MI:SS` 권장. |
| `decision_sku_id` | mapping apply 후보 필수 | 최종 선택 SKU UUID. |
| `decision_reason` | 권장 | 선택/제외/보류 근거. |
| `action_type` | 필수 | 후속 작업 유형 enum. |
| `memo` | 선택 | 추가 설명, 원본 이슈, 재검수 요청 등. |

## review_status Enum

| 값 | 의미 |
|---|---|
| `pending` | 아직 검수하지 않음. apply 대상 아님. |
| `approved` | 증거가 충분해 후속 action을 진행해도 됨. |
| `rejected` | 후보 SKU 또는 후보 action이 틀림. apply 대상 아님. |
| `needs_alias` | SKU는 식별됐지만 alias 보강이 먼저 필요함. |
| `exclude_meta_row` | SKU option mapping 대상이 아닌 product-level/meta row로 제외. |
| `needs_more_evidence` | 현재 CSV 증거만으로 판단 불가. 추가 진단 필요. |

## action_type Enum

| 값 | 사용 대상 |
|---|---|
| `create_channel_mapping` | 검수 완료 후 `sku_channel_mapping` 생성 후보. |
| `backfill_own_sku_alias` | alias 누락 보강 후보. channel mapping보다 alias 보강을 먼저 검토한다. |
| `exclude_from_sku_mapping` | null_key, meta row, 비옵션 row 등 SKU mapping 제외 대상. |
| `regex_candidate` | 새 regex 후보로 관리할 row. 즉시 mapping apply 대상 아님. |
| `manual_hold` | 보류. 추가 자료 또는 운영 판단 필요. |

## Evidence 기준

검수자는 최소한 아래 증거를 함께 확인한다.

| Evidence | 확인 목적 |
|---|---|
| `own_sku_code` | MakeShop 옵션에서 추출된 자사코드 후보가 실제 코드 체계와 맞는지 확인. |
| `opt_values` | 실제 선택 옵션에 가까운 MakeShop 옵션 텍스트. v3 기준 우선 증거. |
| candidate `option_value` | 후보 SKU의 옵션명이 MakeShop `opt_values`와 의미상 일치하는지 확인. |
| `selfpia_sku_aliases` | Sellpia 기준 SKU 코드와 연결 증거 확인. |
| `product_uid` | MakeShop 상품 단위 context. 같은 상품 안의 sto_id 반복 구조 확인. |
| `barcode` | SKU-level인지 product-level인지 주의해서 보조 증거로만 사용. |
| `product_name` | 상품군/모델/재질/색상 등 후보 SKU와의 맥락 일치 여부 확인. |

## CSV별 검수 기준

### ambiguous_weak_top1

- `token_score`가 top1이고 동률이 아닌 후보를 우선 검토한다.
- `opt_values`와 top1 candidate `option_value`가 명확히 같은 옵션을 가리킬 때만 `approved`.
- 제품명만 비슷하고 옵션 증거가 약하면 `needs_more_evidence` 또는 `manual_hold`.
- 승인 시:
  - `review_status = approved`
  - `action_type = create_channel_mapping`
  - `decision_sku_id = top1_candidate_sku_id`

### ambiguous_manual

- candidate SKU 목록 전체를 비교한다.
- 동률 또는 점수 0 후보가 많으면 상품명, option value, selfpia alias, barcode를 함께 확인한다.
- 결정 후보가 하나로 좁혀지지 않으면 `needs_more_evidence`.
- 승인 시 `decision_sku_id`를 수동 입력한다.

### not_in_alias

- `own_sku_code`가 실제 운영 자사코드인지 확인한다.
- 기존 SKU가 식별되면 `needs_alias` 또는 `approved`로 분기한다.
- alias 보강이 선행되어야 하면:
  - `review_status = needs_alias`
  - `action_type = backfill_own_sku_alias`
  - `decision_sku_id` 입력 권장
- SKU 식별이 불가능하면 `manual_hold`.

### null_key

- `product_uid` 또는 `sto_id` blank로 `channel_sku_code = product_uid || '-' || sto_id`를 만들 수 없다.
- 기본적으로 SKU mapping apply 대상에서 제외한다.
- product-level/meta row라고 판단되면:
  - `review_status = exclude_meta_row`
  - `action_type = exclude_from_sku_mapping`
- 원본 CSV 추출 문제 가능성이 있으면 별도 원본 재확인 대상으로 보낸다.

### pattern_loose

- 반복되는 코드 패턴이 있고 alias 매칭 가능성이 보이면 `regex_candidate`.
- loose regex only는 자동확정하지 않는다.
- regex 후보로 승인하더라도 즉시 apply가 아니라 SELECT-only dryrun/export를 다시 수행한다.

## Apply 전 조건

reviewed CSV에서 실제 apply 후보로 이동하려면 아래 조건을 모두 만족해야 한다.

1. `review_status = approved`만 apply 후보가 될 수 있다.
2. `action_type = create_channel_mapping`인 row만 channel mapping apply 후보가 된다.
3. `decision_sku_id`가 필수다.
4. `reviewer`가 필수다.
5. `reviewed_at`이 필수다.
6. `channel_sku_code`가 null/blank가 아니어야 한다.
7. source reviewed CSV 내 duplicate `channel_sku_code`가 0이어야 한다.
8. 기존 `sku_channel_mapping(channel_code='makeshop')`과 conflict가 0이어야 한다.
9. `decision_sku_id`가 `product_code.sku_master.id`에 존재해야 한다.
10. `exclude_meta_row`, `needs_alias`, `regex_candidate`, `manual_hold`, `rejected`, `needs_more_evidence`, `pending`은 channel mapping apply 대상에서 제외한다.

## 향후 SQL 단계 제안

아래 SQL은 다음 단계에서 별도 요청/승인 후 작성한다.

1. reviewed CSV validate SQL
   - reviewed CSV를 TEMP TABLE로 적재한다.
   - enum 값, 필수 컬럼, duplicate key, missing SKU, conflict, reviewed timestamp를 검증한다.
   - DB 영구 변경 없이 `BEGIN` / `ROLLBACK`으로 실행한다.

2. dryrun apply reviewed mappings SQL
   - `review_status='approved'` 및 `action_type='create_channel_mapping'`만 대상으로 한다.
   - transaction 내부 simulation 후 `ROLLBACK`한다.
   - expected insert rows, idempotent skip, conflict rows를 검증한다.

3. apply reviewed mappings SQL
   - dryrun PASS 후 사용자 명시 승인 시에만 작성한다.
   - 로컬 `product_ops_test` 기준으로 먼저 실행한다.
   - 운영 DB 반영은 로컬 검증 완료 후 별도 설계/승인 단계로 분리한다.

## 운영 반영 원칙

- 운영 DB 반영은 local 검증 완료 후 별도 설계한다.
- 운영 DB apply는 source CSV, 검증 SQL, rollback/recovery plan, postcheck 기준이 확정된 뒤 별도 승인으로만 진행한다.
- review 대상 apply SQL은 이 문서 단계에서 작성하지 않는다.
- DDL, API, Frontend 변경은 현재 단계 범위가 아니다.

