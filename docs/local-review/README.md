# System v1 Local Review App

Supabase `System_v1` 프로젝트의 매칭 매트릭스 샘플 큐를 로컬 HTML로 확인하는 검수 화면입니다.

## 구성

- `대시보드`: 샘플 큐 count, 판매처별 분포, 이미지 연결 수를 확인합니다.
- `매칭 매트릭스`: Cloud Run 매칭 매트릭스와 유사한 탭/필터/상세 패널 구조로 Smartstore/MakeShop 샘플 매칭 후보를 확인합니다.

별도 `코드 검수` 탭은 만들지 않고, 매칭 검수 흐름을 `매칭 매트릭스` 안에 모읍니다.

## 최초 설정

1. `config.example.js`를 같은 폴더의 `config.js`로 복사합니다.
2. Supabase Dashboard에서 publishable key 또는 anon key를 확인합니다.
3. `config.js`의 `supabaseAnonKey`에 키를 붙여 넣습니다.

```js
window.SYSTEM_V1_CONFIG = {
  supabaseUrl: "https://bpgvqmtsjgegnrdzmpep.supabase.co",
  supabaseAnonKey: "여기에 publishable/anon key 입력",
  defaultBatchIds: ["sample_smartstore_500", "sample_makeshop_500"],
};
```

`config.js`는 로컬 전용 파일이며 git에 올리지 않습니다.

## 실행

정적 파일 서버로 실행합니다.

```powershell
python -m http.server 4174 -d local_review_app
```

브라우저에서 아래 주소를 엽니다.

```text
http://localhost:4174
```

## 현재 공개 범위

Supabase RLS는 anon key로 전체 테이블을 열지 않습니다. 현재 local HTML 기본 화면은 아래 1,000건 샘플 batch를 읽습니다.

- `sample_smartstore_500`
- `sample_makeshop_500`

이전 smoke용 200건 batch도 Supabase에는 남아 있지만, 화면 기본값은 500+500 샘플입니다.

## 현재 연결된 기능

- 판매처 구획 탭
- Smartstore 재고대조 요약 카드
- 판매처/등급/검색/이미지 필터
- 수동 태그 생성/부착/필터
- 상세 후보 패널
- Sellpia 이미지 썸네일 표시
- 현재 필터 결과 CSV 다운로드
- 현재 필터 결과 검토용 XLSX 다운로드
- Smartstore 원본양식 XLSX 브라우저 업로드/검증
- Smartstore 재고 변경 preview CSV 다운로드
- Smartstore 변경 셀 노란색 검토용 XLSX 다운로드

## 검토용 export

`재고대조 CSV 다운로드`와 `검토용 엑셀 다운로드`는 현재 화면의 필터 결과만 내려받습니다.
두 파일 모두 판매처 업로드용이 아니며, 원본 데이터나 판매처 재고를 수정하지 않습니다.

포함 컬럼:

- Sellpia 상품코드/옵션코드/상품명/옵션명
- 판매처 상품코드/옵션코드/상품명/옵션명
- 매칭 등급, 자동승인 등급, 재고대조 상태
- 중복 후보 수, 중복 위험, 검토 필요
- 이미지 파일명/URL
- 수동 태그, 태그 메모
- 권장 액션, 매칭 근거

XLSX는 `안내`와 `검토대상` 시트로 구성되며, `검토대상` 시트에는 헤더 고정, 필터, 상태별 배경색을 적용합니다.

## Smartstore 원본양식 재고 preview

`Smartstore 원본양식 업로드`에 `스마트스토어_ALL_변경양식.xlsx` 같은 변경양식 파일을 선택한 뒤 `원본양식 업로드/검증`을 누르면 브라우저 안에서만 재고 변경 preview를 만듭니다.

기준 데이터:

- `local_review_app/data/smartstore_stock_apply_map_4251_v1.json`
- 상품번호 + 옵션번호 기준
- 옵션 재고수량 셀의 줄 단위로 변경 preview 적용

버튼:

- `변경 preview CSV`: 변경 후보를 CSV로 다운로드합니다.
- `변경 셀 노란색 XLSX`: 원본 workbook 구조를 유지하면서 변경 preview가 적용된 재고 셀을 노란색으로 칠한 검토용 XLSX를 다운로드합니다.
- `위험 변경 검토 XLSX`: `0으로 변경`, `큰 감소`, `재확인 필요` 후보만 별도 시트로 분리한 검토용 XLSX를 다운로드합니다.

위험 분류:

- 증가
- 소폭 감소
- 큰 감소
- 0으로 변경
- 재확인 필요

Smartstore preview 생성 후 `업로드-ready gate`가 표시되지만, 업로드용 파일 생성은 별도 승인 전까지 잠금 상태입니다.

주의:

- 이 파일은 검토용입니다.
- 판매처 업로드는 하지 않습니다.
- DB write는 하지 않습니다.
- 실제 업로드용 파일 생성/반영은 별도 승인 후 분리된 버튼으로 진행해야 합니다.

## 아직 샘플 모드인 기능

- 옵션 확정/보류/반려/연동 끊기 저장
- 판매처 업로드
- 재고 자동반영

## 다음 단계

- 태그 필터/저장 흐름을 실제 검수자 기준으로 확인
- 이미지 표시 61건 확인
- CSV/XLSX export를 원본양식 기반 local generator와 연결
- 전체 데이터 이관 전 RLS와 성능 재확인
## Review workbook download panel

- `product_ops_full_workflow_execution_plan_20260619_progress_v1.xlsx`: current checklist workbook. It marks completed, in-progress, blocked, and approval-needed tasks after the latest read-only batch.
- `git_candidate_manifest_20260619_v1.xlsx`: selective commit helper. It separates candidate, review-only, and never-add files so `git add .` is not needed.
- `smartstore_code_matching_review_package_20260619_v1.xlsx`: Smartstore current matching package with 91.18% option match rate, 4,251 review candidates, 622 remaining risky rows, and 527 option decision dry-run rows.
- `smartstore_upload_gate_checklist_20260619_v1.xlsx`: Smartstore upload gate checklist. It separates automatic validation PASS checks from human approval checks.
- `supabase_schema_rls_audit_v1.xlsx`: proposed Supabase full review schema and RLS/grant audit. It was not applied to Supabase.
- `local_html_ui_validation_pack_v1.xlsx`: read-only UI validation pack for batch selector, pagination, detail panel, mode badge, and bulk tag preview.
- `performance_roundtrip_readiness_pack_v1.xlsx`: performance and roundtrip readiness pack. Smartstore is review-ready; MakeShop/Ably need filled review input; Coupang/PlayAuto are source-blocked.
- `remaining_blocker_approval_queue_v1.xlsx`: remaining queue after automatic read-only tasks reached zero. It separates approval, source, review-input, and performance blockers.
- `non_developer_status_report_20260619_v2.html`: latest plain-language report with progress, blockers, next human actions, and key file links.
- `policy_decision_request_pack_v1.xlsx`: five remaining policy decisions that need human input before more progress can safely move.

The mapping matrix view includes a `Review workbooks` panel. These files are copied into `local_review_app/downloads/` so they can be downloaded from the local HTML server.

Included review files:

- `overnight_review_execution_dashboard_v1.xlsx`
- `non_developer_morning_report_v1.html`
- `all_channel_workflow_readiness_matrix_v1.xlsx`
- `review_workload_batch_plan_v1.xlsx`
- `review_input_validation_suite_v1.xlsx`
- `review_input_master_pack_v1.xlsx`
- `playauto_hub_evidence_package_v1.xlsx`
- `makeshop_original_form_stock_review_v1.xlsx`
- `makeshop_multistage_breakdown_review_v1.xlsx`
- `makeshop_multistage_diff_original_form_review_v1.xlsx`
- `makeshop_stock_review_input_template_v1.xlsx`
- `p0_duplicate_manual_choice_review_v1.xlsx`
- `ably_real_option_subset_review_v1.xlsx`
- `ably_option_decision_candidate_lift_review_v1.xlsx`
- `ably_decision_review_input_template_v1.xlsx`
- `coupang_matching_rate_recheck_review_v1.xlsx`
- `coupang_source_request_checklist_v1.xlsx`
- `coupang_decision_review_input_template_v1.xlsx`
- `makeshop_decision_key_stock_rebuild_review_v1.xlsx`

All files are review-only. They are not seller upload files, and opening/downloading them does not write to DB or reflect stock.
