# Product_code + PR_system 통합 — 인수인계 (2026-05-15)

다음 Claude 세션에 그대로 시스템 프롬프트로 붙여넣을 수 있도록 정리한 문서.

---

## 역할
너는 Product_code + PR_system 통합 프로젝트의 데이터통합/DB + 프론트 보조 작업자다.
이전 세션에서 smartstore optionNo import 완료 + productNo apply 대기 상태. 본 문서를 기준으로 작업 이어서 진행.

## 작업 위치
- Workspace: `C:\Users\hihi0\OneDrive\문서\2026\Picking System\Integ`

## 환경
- Supabase Product_code: `project_id=mrqoqmidnrawflwezxlm`, 스키마 = `public` (제품 스키마 `product_code` 아님)
- Supabase PR_system: `project_id=vgxocngpykhlkosiaeew` (이번 통합 흐름에서는 미접근)
- Local Docker
  - DB 컨테이너: `product_ops_test_postgres`
  - DB: `product_ops_test`
  - DB user: `product_ops_tester` (postgres 계정 사용 금지)
  - 스키마: `product_code` (local은 실제 product_code 스키마 사용)
- API 컨테이너: `product_ops_api_local` (localhost:8080)
- 프론트: `frontend/admin` (localhost:5173)
- 운영 환경: PowerShell

## 절대 원칙 (어떤 세션에서도 깨면 안 됨)
- 운영 Supabase는 SELECT-only. INSERT/UPDATE/DELETE/DDL 금지.
- 운영 Supabase의 `is_confirmed` / `decision_status` 값 변경 금지.
- NAS PostgreSQL 변경 금지.
- local DB도 dryrun PASS 전 apply 금지. apply는 사용자 승인 후 실행.
- git add / commit / push 금지.
- `scripts/`, `sql/` 디렉토리 전체 add 금지.
- 메이크샵 / 에이블리 / 플레이오토 작업과 섞지 말 것. 본 라인은 smartstore 전용.
- 운영 export는 SELECT 컬럼 리터럴로 confirmed/candidate 라벨링. 운영 schema 변경 금지.
- ON CONFLICT 사용 금지. NOT EXISTS + DISTINCT ON 패턴 유지.

## 데이터 흐름 요약
운영 Supabase `public.sku_channel_mapping scm` → `public.channel_sku cs` → `public.channel_product cp` → `public.sku_master sm` 경로로 SELECT-only export → CSV → local Docker `/tmp` 로 docker cp → server-side COPY 로 staging → BEGIN/ROLLBACK dryrun → 사용자 승인 → BEGIN/COMMIT apply → postcheck → 프론트 표시.

## 진행 상황

### 완료 ✅
1. **Smartstore optionNo import** (run target: local code_alias)
   - code_system: `smartstore_option_no` (909 rows) / `smartstore_option_no_candidate` (11,691 rows)
   - apply OVERALL = PASS / postcheck OVERALL = PASS
   - 검증 SKU: 10310-238 (smartstore 매핑 있음), 1000-3 (매핑 없음, 모든 단계 0 유지 필수)

2. **프론트 "연결 채널" 카드 smartstore 인식 패치**
   - `frontend/admin/src/pages/products/ProductDetailPage.jsx` — `buildConnectionSummary`가 code_alias의 `smartstore_option_no`를 채널 카운트에 포함. candidate는 별도 "연결 후보" 카드.
   - `frontend/admin/src/styles.css` — connection-summary-panel grid 6열 + 1200px/720px 반응형.
   - 10310-238 에서 "Smartstore 1개" 표시 확인. 1000-3은 표시 안 됨.

3. **Smartstore productNo 진단**
   - Source 확정: `public.channel_product.channel_product_code` (11자리 숫자)
   - confirmed 908 mappings / 297 distinct productNo
   - candidate 11,691 mappings / 1,406 distinct productNo
   - 진단 SQL 2종 작성 완료 (Supabase용 + local용)

### 대기 중 ⏳
4. **Smartstore productNo apply 실행**
   - 모든 SQL 작성 완료 (export / precheck / stage / dryrun / **apply** / postcheck)
   - dryrun OVERALL = PASS 확인됨:
     - stage raw confirmed=908, distinct=897 (stage 단계 중복 11 → DISTINCT ON 으로 dedupe)
     - stage raw candidate=11,691, distinct=11,691
     - INSERTED_CONFIRMED=897, INSERTED_CANDIDATE=11,691
     - CHK_1000_3_IN_TX=0, CHK_CANDIDATE_NOT_PRIMARY=0
     - ROLLBACK_CHECK = BASELINE
   - 중요 발견: local code_alias 에 실제로 UNIQUE `(code_system, code_value, target_type, target_id)` 제약 존재. productNo는 한 SKU가 여러 channel_sku option을 통해 같은 productNo를 공유 → stage 자체에 (target_id, code_value) 중복 정상 발생. INSERT source에서 `DISTINCT ON (target_id, code_value)` 사전 dedupe + NOT EXISTS 가드 적용.

### 미시작
5. **프론트 Smartstore 행 "상품코드" 칸 productNo 표시**
   - 현재 화면: Smartstore 행 productCode = "없음" (정상, 미적재 상태)
   - apply 완료 후 패치 필요:
     - `buildCodeSummaryRows`가 confirmed 행에 `smartstore_product_no` alias의 code_value를 productCode로 채우도록 수정
     - candidate는 확정처럼 표시 금지. "Smartstore 후보" 라인에 productNo도 함께 노출하되 별도 톤 유지
   - 1000-3은 productNo 없으므로 여전히 안 보여야 정상

6. **(다음 단계 후보)** 메이크샵 / 에이블리 / 플레이오토 / PR_system 통합 — 본 라인 무관, 별도 세션.

## 파일 인덱스

### sql/ (모두 untracked)
**Optionsino 라인 (적재 완료):**
- `export_smartstore_option_no_alias.sql`
- `precheck_smartstore_alias_import.sql`
- `stage_smartstore_alias_import.sql`
- `dryrun_smartstore_alias_import.sql`
- `postcheck_smartstore_alias_import.sql`
- `apply_smartstore_alias_import.sql` (실행 완료)

**productNo 라인 (apply 대기):**
- `export_smartstore_product_no_alias.sql`
- `precheck_smartstore_product_no_import.sql`
- `stage_smartstore_product_no_import.sql` (server-side COPY, STAGE_DUPLICATE_INFO + STAGE_DISTINCT_PAIRS_BY_CODE_SYSTEM 진단 포함)
- `dryrun_smartstore_product_no_import.sql` (DISTINCT ON dedupe, OVERALL distinct pair 기준)
- `apply_smartstore_product_no_import.sql` ⏳ **실행 대기**
- `postcheck_smartstore_product_no_import.sql` (MISSING_PAIRS / STAGE_VS_APPLIED / OVERALL 모두 distinct pair 기준)

**진단:**
- `diagnose_smartstore_product_code_source.sql` (Supabase SELECT-only)
- `diagnose_local_smartstore_alias_display.sql` (local SELECT-only)

### exports/ (Supabase SQL Editor 다운로드)
- `smartstore_option_no_alias.csv` (909 raw)
- `smartstore_option_no_alias_candidates.csv` (11,691 raw)
- `smartstore_product_no_alias.csv` (908 raw)
- `smartstore_product_no_alias_candidates.csv` (11,691 raw)

### frontend/admin/src/ (이번 라인에서 수정)
- `pages/products/ProductDetailPage.jsx` — buildConnectionSummary 패치 (smartstore_option_no 인식)
- `styles.css` — 6열 grid + 반응형

### docs/
- `handoff_2026-05-15_smartstore_integration.md` (이 문서)

## 다음 세션이 받자마자 할 일

### A. 사용자 승인 받고 productNo apply 실행
```powershell
# 1) 백업
New-Item -ItemType Directory -Force -Path .\backups | Out-Null
docker exec -i product_ops_test_postgres pg_dump -U product_ops_tester -d product_ops_test -t product_code.code_alias --data-only `
  > (".\backups\code_alias_before_smartstore_product_no_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".sql")

# 2) apply SQL 컨테이너로
docker cp .\sql\apply_smartstore_product_no_import.sql product_ops_test_postgres:/tmp/apply_smartstore_product_no_import.sql

# 3) apply 실행
docker exec -i product_ops_test_postgres psql -U product_ops_tester -d product_ops_test -v ON_ERROR_STOP=1 -f /tmp/apply_smartstore_product_no_import.sql

# 4) postcheck
docker cp .\sql\postcheck_smartstore_product_no_import.sql product_ops_test_postgres:/tmp/postcheck_smartstore_product_no_import.sql
docker exec -i product_ops_test_postgres psql -U product_ops_tester -d product_ops_test -v ON_ERROR_STOP=1 -f /tmp/postcheck_smartstore_product_no_import.sql
```

apply OVERALL = PASS / postcheck OVERALL = PASS 확인.

### B. apply 후 기대 상태
- code_alias 추가: smartstore_product_no = +897, smartstore_product_no_candidate = +11,691
- 다른 code_system 카운트 변화 없음:
  - selfpia_sku / own_sku / selfpia_product
  - makeshop_* 계열
  - smartstore_option_no / smartstore_option_no_candidate
- 1000-3 (d4c0a5bf-73f1-4203-a6f8-9a27a44f58da) 의 smartstore_product_no_* = 0

### C. 프론트 패치 (apply 이후)
`frontend/admin/src/pages/products/ProductDetailPage.jsx`:
1. `aliasValues(aliases, 'smartstore_product_no')` 추출 추가
2. `buildCodeSummaryRows` 의 smartstore 행에 productCode = smartstoreProductNo[0] 채우기
3. candidate-only 케이스에는 productNo도 candidate 라인에 분리 표기
4. 1000-3 같은 매핑 없는 SKU 는 현재 동작 유지 (Smartstore 행 미매핑/숨김)

테스트 SKU:
- 10310-238 — confirmed productNo 표시 기대
- 1000-3 — Smartstore 행 변화 없음 기대

### D. 검증 명령
```powershell
docker exec -i product_ops_test_postgres psql -U product_ops_tester -d product_ops_test -t -c `
  "select target_id from product_code.code_alias where code_system='selfpia_sku' and code_value='10310-238' and target_type='SKU' limit 1;"

# 위 sku_id 를 $SKU_ID 변수에 넣고
curl.exe -s "http://localhost:8080/skus/$SKU_ID" | ConvertFrom-Json | Select-Object -ExpandProperty data | Select-Object -ExpandProperty aliases | Where-Object { $_.code_system -like 'smartstore*' }
```

## 핵심 패턴 (재사용용)

### 1) Supabase export SELECT (confirmed/candidate 분리)
```sql
select ..., 'CODE_SYSTEM_NAME'::text as code_system, ...
from public.sku_channel_mapping scm
join public.channel_sku     cs on cs.id = scm.channel_sku_id
join public.channel_product cp on cp.id = cs.channel_product_id
join public.sku_master      sm on sm.id = scm.sku_id
where cs.channel='smartstore' and scm.is_confirmed = true   -- candidate 면 false
  and <code_value 컬럼> is not null
order by scm.sku_id, <code_value 컬럼>;
```

### 2) Stage server-side COPY
```sql
copy product_code.<stage_table>
  from '/tmp/<csv_filename>.csv'
  with (format csv, header true);
```

### 3) Apply INSERT (DISTINCT ON + NOT EXISTS, ON CONFLICT 금지)
```sql
with dedupe as (
  select distinct on (s.target_id, s.code_value)
    s.target_id, s.code_value, ...
  from product_code.<stage_table> s
  where s.code_system = '<CODE_SYSTEM>'
  order by s.target_id, s.code_value, <tie-breaker columns>
),
ins as (
  insert into product_code.code_alias (...)
  select 'SKU', d.target_id, '<CODE_SYSTEM>', d.code_value, ...
  from dedupe d
  join product_code.sku_master sm on sm.id = d.target_id
  where not exists (
    select 1 from product_code.code_alias ca
    where ca.target_type='SKU' and ca.target_id=d.target_id
      and ca.code_system='<CODE_SYSTEM>' and ca.code_value=d.code_value
  )
  returning 1
)
select '<INSERTED_LABEL>' as stage, count(*) as rows from ins;
```

### 4) Dryrun = apply 와 동일 + `BEGIN ... ROLLBACK`
### 5) Apply = dryrun 과 동일 + `BEGIN ... COMMIT`
### 6) OVERALL verdict 는 항상 distinct pair / baseline 보존 / 1000-3 = 0 기준

## 알려진 주의사항
- local code_alias 에 UNIQUE `(code_system, code_value, target_type, target_id)` 제약 실재. 컬럼 순서 다른 ON CONFLICT 는 에러 — NOT EXISTS 패턴 유지.
- raw_payload (smartstore channel_product) 키는 한국어 헤더 dict. productNo 영문 키 없음. → productNo는 `channel_product_code` 컬럼에서 직접 추출.
- stage 단계 (target_id, code_value) 중복은 productNo에서 정상 (한 SKU에 여러 option이 같은 productNo로 묶임). dedupe로 처리.
- `.git/index` 손상 상태 (OneDrive 동기화 영향 추정). `GIT_INDEX_FILE=/tmp/...` 임시 인덱스로 status 조회 가능. 사용자 .git/index 건드리지 말 것.

## 화면 검증 SKU
- 10310-238 (smartstore_option_no 있음, smartstore_product_no apply 후 있음)
- 1000-3 (sku_id=d4c0a5bf-73f1-4203-a6f8-9a27a44f58da) — smartstore 매핑 0건. 모든 단계에서 smartstore_* = 0 유지 필수
- 11008-15, 11188-1, 5275-1, 1678-2 — diagnose_local_smartstore_alias_display.sql 에서 확인용

---

**이 문서를 새 세션 첫 메시지로 붙여넣으면 컨텍스트 복원 끝.** 그다음 사용자에게 "C 단계(apply 실행)부터 진행할까요?" 물어보고 승인 받기.
