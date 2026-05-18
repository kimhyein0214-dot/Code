# Manual Review CSV Design v1

작성일: 2026-05-17

## 1. 목적

이 문서는 자동확정할 수 없는 판매처 코드 후보를 사람이 검수하기 위한 CSV 설계 초안이다.

목표는 Smartstore, MakeShop, 이미지, 자사코드 상태를 read-only로 분리해 검수자가 같은 기준으로 판단할 수 있게 하고, 검수 결과를 나중에 `validate -> dryrun -> 승인 -> local apply -> postcheck` 흐름으로 넘기기 위한 입력 형식을 정하는 것이다.

이번 범위는 설계와 SELECT-only SQL 초안 작성까지다. DB 실행, local apply, 운영 Supabase/NAS 반영, API write 기능, 실제 export 생성 기능은 포함하지 않는다.

## 2. CSV 종류 제안

| CSV | 목적 | 주요 대상 |
|---|---|---|
| `manual_review_smartstore_candidates.csv` | Smartstore 확정값 없이 후보만 있거나, 확정과 후보가 같이 남은 SKU를 검수한다. | 후보만 있는 SKU, 후보/확정 충돌 또는 정리 대상 |
| `manual_review_makeshop_candidates.csv` | MakeShop 미연결 및 기존 review_required/ambiguous matrix 대상을 검수한다. | MakeShop mapping 없음, weak_top1/manual/not_in_alias/null_key/pattern_loose |
| `manual_review_missing_assets.csv` | 판매처 코드 검수 전에 보강이 필요한 기초 자산을 모은다. | 이미지 없음, own_sku 없음 |
| `manual_review_channel_gap_summary.csv` | SKU 단위 판매처 연결 공백을 요약한다. | Smartstore/MakeShop 둘 다 없는 SKU, 채널별 gap count |

MakeShop 기존 outputs 기준 잔여 대상은 이번 작업에서 outputs 파일을 만들거나 수정하지 않고 설계 기준으로만 기록한다.

| 그룹 | 기존 기준 rows | count_basis | CSV 관리 방향 |
|---|---:|---|---|
| review_required 합계 | 19,408 | `output_row_count` | `review_group=makeshop_review_required` |
| ambiguous weak_top1 matrix | 12,585 | `output_row_count` | `candidate_reason=ambiguous_weak_top1` |
| ambiguous manual matrix | 3,192 | `output_row_count` | `candidate_reason=ambiguous_manual` |
| not_in_alias matrix | 592 | `output_row_count` | `candidate_reason=not_in_alias` |
| null_key matrix | 2,289 | `output_row_count` | `candidate_reason=null_key` |
| pattern_loose matrix | 750 | `output_row_count` | `candidate_reason=pattern_loose` |

## 3. 공통 컬럼 설계

모든 CSV는 가능한 한 같은 컬럼을 유지한다. 채널별로 값이 없는 컬럼은 blank로 둔다.

| 컬럼 | 필수성 | 설명 |
|---|---|---|
| `review_id` | 필수 | 검수 row 고유 ID. 저장 테이블이 생기기 전에는 `review_group:sku_id:channel` 같은 deterministic 텍스트를 사용한다. |
| `review_group` | 필수 | 검수 그룹. 예: `smartstore_candidate_only`, `makeshop_missing_mapping`, `missing_image` |
| `source_query_section` | 필수 | SQL 초안의 섹션. 예: `A`, `B`, `H` |
| `source_row_ref` | 권장 | 기존 matrix CSV row 또는 조회 출처 참조. 초기 SKU 기준 SELECT에서는 NULL일 수 있다. |
| `priority` | 필수 | `P1`, `P2`, `P3` |
| `sku_id` | 필수 | local `product_code.sku_master.id` |
| `selfpia_sku` | 필수 | 셀피아 SKU alias |
| `virtual_sku_code` | 권장 | 내부 VSKU |
| `product_name` | 필수 | 상품명 |
| `option_name` | 필수 | 옵션명 |
| `own_sku` | 권장 | 자사코드 alias |
| `image_status` | 권장 | `has_image`, `missing_image`, `unknown` |
| `channel` | 필수 | `smartstore`, `makeshop`, `asset`, `summary` 등 |
| `code_system` | 필수 | `smartstore_product_or_option`, `makeshop_channel_mapping`, `own_sku` 등 |
| `confirmed_code_system` | 권장 | 확정 코드의 code_system |
| `candidate_code_system` | 권장 | 후보 코드의 code_system |
| `candidate_count` | 권장 | 같은 SKU 안의 후보 수 |
| `candidate_reason` | 필수 | 후보 생성 또는 검수 대상 사유 |
| `match_status` | 필수 | `candidate_only`, `unmapped`, `missing_mapping`, `confirmed_with_candidate`, `missing_asset` 등 |
| `conflict_note` | P1 필수 | 후보/확정 중복, productNo/optionNo 혼동 위험, 같은 코드의 다중 SKU 의심. P1 충돌/중복 검수에서는 필수에 가깝다. |
| `risk_note` | 필수 | export/apply 위험 또는 검수 주의사항 |
| `export_allowed` | 필수 | CSV 최초 생성 시 기본값은 `false` |
| `export_blocker_reason` | 필수 | export 차단 사유. 예: `candidate_unreviewed`, `no_confirmed_code` |
| `reviewer_decision` | 필수 | 최초 생성 시 `pending` |
| `reviewer_note` | 권장 | 검수자 메모 |
| `reviewed_code_value` | 권장 | 검수자가 최종 선택한 코드값 |
| `reviewed_at` | 권장 | 검수 완료 시각 |

summary row 권장 컬럼:

| 컬럼 | 설명 |
|---|---|
| `metric_name` | summary row 지표명 |
| `target_count` | summary row count |
| `count_basis` | count가 `distinct_sku_count`, `output_row_count`, `mapping_row_count` 중 무엇인지 표시 |
| `export_allowed_default` | summary 대상의 기본 export 허용 여부 |
| `note` | 지표 해석 메모 |

## 4. Smartstore 전용 컬럼

Smartstore CSV에서는 productNo와 optionNo를 반드시 분리한다.

| 컬럼 | 설명 |
|---|---|
| `confirmed_product_no` | 확정된 Smartstore 상품 단위 코드 |
| `confirmed_option_no` | 확정된 Smartstore 옵션/SKU 단위 코드 |
| `candidate_product_no` | 검수 대상 Smartstore 상품 단위 후보 코드 |
| `candidate_option_no` | 검수 대상 Smartstore 옵션/SKU 단위 후보 코드 |
| `confirmed_code_system` | `smartstore_product_no`, `smartstore_option_no` 중 존재하는 확정 system |
| `candidate_code_system` | `smartstore_product_no_candidate`, `smartstore_option_no_candidate` 중 존재하는 후보 system |

규칙:

1. `productNo`는 상품 단위 코드다.
2. `optionNo`는 옵션/SKU 단위 코드다.
3. 두 값을 하나의 `code_value`로 섞어서 검수하거나 export하면 안 된다.
4. 후보 productNo 또는 후보 optionNo는 운영 미확정 상태이며 export source가 될 수 없다.
5. Smartstore CSV 검수 시 `confirmed_code_value` / `candidate_code_value` 같은 통합 컬럼은 사용하지 않는다.
6. productNo와 optionNo는 반드시 분리된 컬럼으로 확인한다.
7. productNo와 optionNo를 합친 값은 export 기준값으로 사용하지 않는다.

## 5. Export 차단 규칙

`export_allowed`와 `export_blocker_reason`은 기계적으로 export 사용을 차단하기 위한 컬럼이다.

규칙:

1. candidate row 기본값은 `export_allowed=false`.
2. unreviewed row 기본값은 `export_allowed=false`.
3. `reviewer_decision=confirm`이어도 validate, dryrun, 사용자 승인, local apply, postcheck 전에는 `export_allowed=true`로 취급하지 않는다.
4. candidate rows must never be export source.
5. export는 confirmed code만 허용한다.
6. `pending`, `hold`, `needs_more_info`, `reject` row는 DB 반영, 업로드, export 금지다.

권장 blocker reason:

| 값 | 의미 |
|---|---|
| `candidate_unreviewed` | 후보 코드이며 미검수 상태 |
| `no_confirmed_code` | 확정 코드 없음 |
| `channel_mapping_missing` | 판매처 mapping 없음 |
| `conflict_confirmed_and_candidate` | 확정과 후보가 같이 있어 정리 필요 |
| `image_missing` | 이미지 근거 부족 |
| `own_sku_missing` | 자사코드 근거 부족 |

## 6. `reviewer_decision` 허용값

| 값 | 의미 |
|---|---|
| `pending` | CSV 최초 생성 상태. 아직 검수하지 않음 |
| `confirm` | 검수자가 후보 또는 입력값을 맞다고 판단 |
| `reject` | 후보가 틀렸다고 판단 |
| `hold` | 보류 |
| `needs_more_info` | 이미지, 원본 상세, 판매처 화면 등 추가 근거 필요 |

규칙:

1. CSV 최초 생성 시 `reviewer_decision` 기본값은 `pending`.
2. `pending` 상태는 DB 반영, 업로드, export 금지.
3. `confirm`도 바로 DB 반영이 아니다.
4. `confirm` row는 validate, dryrun, 사용자 승인, local apply, postcheck 이후에만 확정 반영 후보가 된다.

## 7. 자동매칭 학습데이터 활용 컬럼

검수 결과는 단순 저장용이 아니라 이후 자동매칭 기준 데이터로 재활용한다. `confirm`, `reject`, `hold` 결과가 쌓이면 비슷한 상품명, 옵션명, 판매처코드 패턴을 학습해 자동매칭률을 높이는 데 사용할 수 있다.

| 컬럼 | 설명 |
|---|---|
| `decision_sku_id` | 검수자가 최종 선택한 SKU |
| `decision_code_system` | 검수자가 최종 선택한 코드 system |
| `decision_confidence` | 검수자 신뢰도. 예: `high`, `medium`, `low` |
| `evidence_product_name` | 판단에 사용한 원본/판매처 상품명 |
| `evidence_option_name` | 판단에 사용한 원본/판매처 옵션명 |
| `normalized_product_name` | 정규화된 상품명 |
| `normalized_option_name` | 정규화된 옵션명 |
| `candidate_rank` | 자동 후보 순위 |
| `candidate_score` | 자동 후보 점수 |
| `match_rule_before` | 기존 후보 생성 규칙 |
| `reject_reason` | reject 사유. 잘못된 option, 상품군 불일치, 중복 등 |

MakeShop은 특히 `own_sku`, option token, 원본 상품명/옵션명, weak_top1 score를 가능한 한 보존해야 한다. 이 값이 있어야 사람이 확정하거나 반려한 패턴을 다음 자동매칭 규칙 개선에 연결할 수 있다.

MakeShop matrix 또는 reviewed CSV 단계에서는 `source_row_ref`를 `source_file:row_no` 형태로 채우는 것을 권장한다. 추후 MakeShop matrix 연결 SELECT에서는 `candidate_rank`, `candidate_score`, `match_rule_before`를 실제 matrix 기준으로 채워야 한다.

## 8. 가격/재고/판매상태/export 연결 컬럼

코드매칭 검수와 가격/재고/판매상태 검수는 분리한다. 다만 최종 목표가 가격/재고/판매상태 관리 화면과 판매처별 업로드 파일 생성 기능이므로 같은 `sku_id` 기준으로 이어붙일 수 있게 연결 컬럼을 남긴다.

| 컬럼 | 설명 |
|---|---|
| `channel` | 판매처 |
| `channel_product_code` | 판매처 상품 코드 |
| `channel_option_code` | 판매처 옵션/SKU 코드 |
| `channel_product_name` | 판매처 상품명 |
| `channel_option_name` | 판매처 옵션명 |
| `sale_status_review_needed` | 판매상태 검수 필요 여부 |
| `price_review_needed` | 가격 검수 필요 여부 |
| `inventory_review_needed` | 재고 검수 필요 여부 |
| `upload_template_scope` | 향후 업로드 템플릿 범위 |
| `export_field_blocker_reason` | 업로드 필드 생성 차단 사유 |

이 컬럼들은 코드매칭 검수 CSV에서 값을 모두 채우기 위한 것이 아니다. 나중에 가격, 재고, 판매상태 검수 테이블 또는 CSV와 join할 수 있도록 기준 축을 맞추기 위한 연결점이다.

## 9. 우선순위 기준

| 우선순위 | 대상 |
|---|---|
| P1 | Smartstore/MakeShop 둘 다 없는 SKU |
| P1 | 후보/확정 충돌 또는 중복 의심 |
| P2 | Smartstore 후보만 있음 |
| P2 | MakeShop 미연결 |
| P3 | 이미지 없음 |
| P3 | own_sku 없음 |

P1은 판매처 연결 자체가 막히거나 잘못된 코드가 export로 나갈 수 있는 대상이다. P2는 검수하면 매핑률을 직접 올릴 수 있는 대상이다. P3는 상품 검수 품질과 이후 자동화 근거를 보강하는 대상이다.

## 10. 대상 범위

| 범위 | 판정 기준 | 기본 CSV |
|---|---|---|
| Smartstore 후보만 있는 SKU | `smartstore_option_no_candidate` 또는 `smartstore_product_no_candidate`가 있고 확정 `smartstore_option_no`/`smartstore_product_no`가 없음 | `manual_review_smartstore_candidates.csv` |
| Smartstore 미매핑 SKU | Smartstore 확정도 후보도 없음 | `manual_review_channel_gap_summary.csv` |
| MakeShop 미연결 SKU | `sku_channel_mapping.channel_code='makeshop'`가 없음 | `manual_review_makeshop_candidates.csv` |
| Smartstore/MakeShop 둘 다 없는 SKU | Smartstore 확정/후보가 없고 MakeShop mapping도 없음 | `manual_review_channel_gap_summary.csv` |
| 이미지 없음 SKU | `product_code.product_image`에서 SKU 이미지가 없음 | `manual_review_missing_assets.csv` |
| own_sku 없음 SKU | `code_alias.code_system='own_sku'` alias가 없음 | `manual_review_missing_assets.csv` |
| 후보/확정 같이 있는 SKU | Smartstore 확정값이 있고 candidate도 남아 있음 | `manual_review_smartstore_candidates.csv` |
| MakeShop review_required/ambiguous/manual | 기존 matrix outputs 기준 검수 잔여 대상 | `manual_review_makeshop_candidates.csv` |

## 11. product_image 전제조건

이미지 없음 SKU 조회는 `product_code.product_image` 테이블이 존재하고 local 적용이 완료되어 있다는 전제가 필요하다.

`product_image` apply 여부가 불확실하면 이미지 없음 결과는 참고용으로만 본다. 이 경우 `image_status=missing_image`는 실제 이미지 부재가 아니라 local 이미지 적재 미완료를 의미할 수 있다.

## 12. Read-only SQL 초안 설명

SQL 초안 파일은 `sql/select_manual_review_targets_v1.sql`이다.

기준:

- local `product_ops_test` 기준으로 읽기 전용 조회만 작성한다.
- `product_code.v_sku_canonical`은 selfpia alias 상태에 따라 row 수와 `distinct sku_id`가 다를 수 있으므로 각 조회에서 `DISTINCT ON (sku_id)`로 SKU 기준 분모를 만든다.
- Smartstore confirmed와 candidate를 code_system별로 분리한다.
- Smartstore productNo와 optionNo를 별도 컬럼으로 분리한다.
- Smartstore CSV는 `confirmed_code_value` / `candidate_code_value` 같은 통합 컬럼을 사용하지 않는다.
- MakeShop은 `product_code.sku_channel_mapping`의 `channel_code='makeshop'` 존재 여부로 미연결을 판단한다.
- 이미지와 own_sku는 판매처 코드와 별도 자산/근거 보강 대상으로 분리한다.
- SQL은 실제 CSV 생성 명령을 포함하지 않고, 검수 CSV로 복사 가능한 SELECT 결과 모양만 제공한다.

섹션:

- A. Smartstore 후보만 있는 SKU
- B. Smartstore 미매핑 SKU
- C. MakeShop 미연결 SKU
- D. Smartstore/MakeShop 둘 다 없는 SKU
- E. 이미지 없음 SKU
- F. own_sku 없음 SKU
- G. 후보/확정 같이 있는 SKU
- H. 검수 대상 summary count

## 13. 다음 단계 흐름

1. SELECT-only SQL을 local에서 사람이 검토한다.
2. 출력 컬럼과 우선순위가 충분한지 확인한다.
3. 별도 승인 후 CSV export 스크립트를 설계한다.
4. reviewed CSV validation SQL을 설계한다.
5. dryrun 기준과 승인 체크리스트를 만든다.
6. 승인된 reviewed CSV만 local apply 후보로 넘긴다.
7. postcheck 결과를 보고 운영 반영 여부는 별도 설계한다.
