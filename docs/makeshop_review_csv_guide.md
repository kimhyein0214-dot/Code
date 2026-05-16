# MakeShop Review CSV Guide

작성일: 2026-05-15

## 목적

MakeShop `review_required` 19,408건을 사람이 검수하기 쉽도록 matrix CSV를 검수 템플릿 CSV로 재가공한다.

이 문서는 검수 CSV 사용법만 다룬다. DB 변경, SQL apply 작성, 운영 DB 반영, DDL, API/Frontend 변경은 범위에 포함하지 않는다.

## 생성 파일

| CSV | 목적 |
|---|---|
| `outputs/makeshop_review_ambiguous_weak_top1_priority.csv` | `ambiguous_weak_top1`을 검수 우선순위대로 정렬한 참고 파일. |
| `outputs/makeshop_review_ambiguous_weak_top1_review_template.csv` | 단독 top1 후보가 있는 ambiguous row 검수 템플릿. |
| `outputs/makeshop_review_ambiguous_manual_review_template.csv` | 복수 후보/동률/불충분 후보를 wide 형태로 유지한 검수 템플릿. |
| `outputs/makeshop_review_ambiguous_manual_candidate_long.csv` | `ambiguous_manual` 후보 SKU를 후보 1개당 1행으로 펼친 비교용 파일. |
| `outputs/makeshop_review_not_in_alias_review_template.csv` | MakeShop에서 추출된 `own_sku_code`가 alias에 없는 row의 alias 보강 검토 템플릿. |
| `outputs/makeshop_review_null_key_review_template.csv` | `channel_sku_code`를 만들 수 없는 row의 제외/원본 구조 분류 템플릿. |
| `outputs/makeshop_review_pattern_loose_review_template.csv` | regex 미매칭/loose-only row의 regex 후보 검토 템플릿. |
| `outputs/makeshop_review_enum_guide.csv` | `review_status`, `action_type` 입력값 설명 파일. |

## 검수 순서

1. `ambiguous_weak_top1_review_template`
   - `token_score=70` 및 `candidate_sku_count` 2 또는 3 구간이 가장 먼저 오도록 정렬되어 있다.
   - `opt_values`, `top1_option_value`, `top1_product_name`, `top1_selfpia_sku_aliases`를 함께 확인한다.

2. `not_in_alias_review_template`
   - `representative_row_flag=t`부터 확인한다.
   - 실제 기존 SKU가 확인되면 alias 보강 후보로 분류한다.

3. `pattern_loose_review_template`
   - 반복되는 옵션 패턴과 `loose_4part_candidate` 존재 여부를 먼저 본다.
   - regex 후보일 뿐 즉시 mapping apply 대상이 아니다.

4. `null_key_review_template`
   - SKU option mapping 대상이 아닌 product-level/meta row인지 분류한다.
   - `channel_sku_code`가 없으므로 바로 apply할 수 없다.

5. `ambiguous_manual_review_template`
   - 후보 비교 비용이 가장 크므로 `candidate_long` 파일과 함께 본다.
   - 후보가 많으면 상품 단위 또는 후보 수 기준으로 batch를 나눠 검수한다.

## 공통 검수 컬럼

| 컬럼 | 설명 |
|---|---|
| `review_status` | 검수 상태. 기본값은 `pending`. |
| `action_type` | 후속 작업 유형. 기본값은 blank이며 apply 후보처럼 보이지 않게 둔다. |
| `reviewer` | 검수자 식별자. apply 후보에는 필수다. |
| `reviewed_at` | 검수 완료 시각. apply 후보에는 필수다. |
| `decision_sku_id` | 최종 선택 SKU UUID. 기본 blank. |
| `decision_reason` | 승인/제외/보류 근거. |
| `memo` | 추가 설명, 원본 확인 메모, 재검수 요청. |
| `review_batch` | 사람이 나눠 작업할 batch 이름. |
| `priority_score` | 검수 우선순위 보조 점수. `weak_top1`은 계산값이 들어간다. |
| `validation_note` | 검수 CSV validation 단계에서 남길 메모. |
| `needs_second_review` | 2차 검수 필요 여부. |
| `source_row_ref` | 원본 matrix CSV 파일명과 CSV row number. |

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
| `create_channel_mapping` | 검수 완료 후 channel mapping 생성 후보. |
| `backfill_own_sku_alias` | alias 누락 보강 후보. channel mapping보다 alias 보강을 먼저 검토한다. |
| `exclude_from_sku_mapping` | null_key, meta row, 비옵션 row 등 SKU mapping 제외 대상. |
| `regex_candidate` | 새 regex 후보로 관리할 row. 즉시 mapping apply 대상 아님. |
| `manual_hold` | 보류. 추가 자료 또는 운영 판단 필요. |

## approved 처리 조건

`approved`는 검수자가 충분한 증거를 확인했을 때만 입력한다.

- MakeShop 옵션 텍스트와 후보 SKU 옵션명이 의미상 일치한다.
- 상품명/상품군 맥락이 충돌하지 않는다.
- alias 또는 후보 SKU 증거가 선택한 `decision_sku_id`를 뒷받침한다.
- 동률 또는 복수 후보가 있으면 다른 후보를 배제한 근거를 `decision_reason`에 남긴다.

## create_channel_mapping 처리 조건

`create_channel_mapping`은 실제 channel mapping 후보를 뜻한다. 아래 조건이 모두 채워지지 않으면 apply 후보로 취급하지 않는다.

- `review_status=approved`
- `action_type=create_channel_mapping`
- `decision_sku_id` nonblank
- `reviewer` nonblank
- `reviewed_at` nonblank
- `channel_sku_code` nonblank

## Apply 후보 필수 조건

향후 validate SQL 단계에서 apply 후보가 되려면 최소한 아래 조건을 모두 만족해야 한다.

1. `review_status=approved`
2. `action_type=create_channel_mapping`
3. `decision_sku_id` nonblank
4. `reviewer` nonblank
5. `reviewed_at` nonblank

이 조건은 apply 실행 조건이 아니라 validate 대상으로 넘기기 위한 최소 조건이다.

## Google Sheets / Excel 규칙

권장 필터:

- `review_status`
- `action_type`
- `review_batch`
- `needs_second_review`
- `sort_bucket`
- `candidate_sku_count`
- `token_score`
- `representative_row_flag`
- `null_key_type`
- `regex_confidence`

권장 색상:

- `review_status=pending`: 흰색 또는 무색
- `review_status=approved`: 연한 초록
- `review_status=needs_more_evidence` 또는 `action_type=manual_hold`: 연한 노랑
- `review_status=rejected`: 연한 빨강
- `review_status=exclude_meta_row` 또는 `action_type=exclude_from_sku_mapping`: 회색
- `action_type=regex_candidate`: 연한 파랑
- `approved`인데 `decision_sku_id`, `reviewer`, `reviewed_at` 중 하나라도 blank: 빨강
- `candidate_sku_count>=8`: 주황
- `token_score<=30`: 주황

## 절대 금지

- `pending` 상태 apply 금지
- `needs_alias`를 바로 channel mapping apply 금지
- `null_key`를 바로 apply 금지
- `regex_candidate`를 바로 apply 금지
- `decision_sku_id` blank row apply 금지
- `reviewer` 또는 `reviewed_at` blank row apply 금지

## 실행 명령

```powershell
python scripts\build_makeshop_review_templates.py
```

Python 실행 파일을 명시해야 하는 환경에서는 로컬 Python 경로로 아래처럼 실행한다.

```powershell
& 'C:\Users\hihi0\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' scripts\build_makeshop_review_templates.py
```
