# Local Seed Sample Runbook

로컬 Docker PostgreSQL (`product_ops_test`) 에만 LOCAL_TEST sample data를 넣고 API row 반환을 재검증하는 절차다.

## 1. 전제

- 운영 Supabase 수정 금지
- NAS 적용 금지
- 실제 운영 데이터 전체 적재 금지
- seed는 API route 검증용 최소 데이터만 사용
- 모든 sample 값은 `LOCAL_TEST_` 또는 `TEST_` prefix 로 식별

## 2. Seed 구성

| 유형 | 개수 | 목적 |
|---|---:|---|
| matched | 2 | `/product-code/skus`, `/picking/order-items`, `/mapping/summary` row 반환 확인 |
| unmatched | 1 | master 미매칭 상태 조회 확인 |
| ambiguous | 1 | own_sku 후보 중복 view/API 확인 |
| legacy_unmatched | 1 | 과거 배송완료 미매칭 보존 흐름 확인 |

추가로 schema v2가 이미 seed한 `9826-*` legacy unmatched rows는 유지한다.

## 3. 실행 방법

Docker DB와 API를 실행한다.

```powershell
docker compose --env-file .env.local -f docker-compose.local-test.yml up -d
docker compose --env-file .env.api -f docker-compose.local-test.yml -f docker-compose.api-local.yml up -d api
```

psql 접속:

```powershell
docker compose --env-file .env.local -f docker-compose.local-test.yml exec postgres psql -U product_ops_tester -d product_ops_test
```

psql 안에서 seed 실행:

```sql
\i /sql/local_seed_sample_data.sql
\i /sql/local_seed_sample_validation.sql
```

두 SQL 모두 `current_database() = 'product_ops_test'` 가 아니면 중단한다.

## 4. Reset 방법

`sql/local_seed_sample_data.sql` 하단의 Local reset section 을 확인하고, 필요한 DELETE 문만 직접 실행한다.

주의:

- reset SQL은 destructive 하다.
- 주석 처리되어 있으며 자동 실행되지 않는다.
- 로컬 `product_ops_test` 전용이다.
- 운영 Supabase / NAS 실행 금지.

## 5. API 재검증

```powershell
Invoke-RestMethod "http://localhost:8080/product-code/skus?search=LOCAL_TEST"
Invoke-RestMethod "http://localhost:8080/product-code/skus/LOCAL_TEST_1258-1"
Invoke-RestMethod "http://localhost:8080/picking/order-items?master_match_status=matched"
Invoke-RestMethod "http://localhost:8080/picking/unmatched"
Invoke-RestMethod "http://localhost:8080/mapping/summary"
Invoke-RestMethod "http://localhost:8080/mapping/unmatched"
Invoke-RestMethod "http://localhost:8080/mapping/own-sku/ambiguous"
```

## 6. 기대 결과

- `/product-code/skus?search=LOCAL_TEST`: LOCAL_TEST SKU 2건 반환
- `/product-code/skus/LOCAL_TEST_1258-1`: 단건 반환
- `/picking/order-items?master_match_status=matched`: matched sample 2건 반환
- `/picking/unmatched`: unmatched / ambiguous / legacy_unmatched sample 반환
- `/mapping/summary`: `matched`, `unmatched`, `ambiguous`, `legacy_unmatched` 집계 반환
- `/mapping/unmatched`: `LOCAL_TEST_NO_MASTER_001` 및 기존 `9826-*` rows 반환
- `/mapping/own-sku/ambiguous`: `LOCAL_TEST_OWN_AMBIG` 후보 2건 집계 반환

## 7. 결과 기록 위치

- `docs/api_local_test_runbook.md`
- `docs/codex_handoff_status.md`

## 8. 실제 실행 결과 (2026-05-12)

로컬 Docker DB 전용 sample seed 적재 후 API row 반환 재검증 완료.

| Endpoint | 결과 |
|---|---|
| `/product-code/skus?search=LOCAL_TEST` | 성공, LOCAL_TEST SKU 2건 반환 |
| `/product-code/skus/LOCAL_TEST_1258-1` | 성공, 단일 SKU 상세 반환 |
| `/picking/order-items?master_match_status=matched` | 성공, matched order item 2건 반환 |
| `/picking/unmatched` | 성공, unmatched / ambiguous / legacy_unmatched 3건 반환 |
| `/mapping/summary` | 성공, matched 2 / unmatched 1 / ambiguous 1 / legacy_unmatched 1 |
| `/mapping/own-sku/ambiguous` | 성공, LOCAL_TEST_OWN_AMBIG 후보 2개 반환 |

추가 확인:

- `/mapping/unmatched` 에서 기존 `9826-*` legacy_unmatched 가 raw_p_code별로 2번씩 중복 반환됨.
- 원인 확인용 SQL: `sql/local_check_unmatched_duplicates.sql`
- 운영 Supabase 변경 없음.
- NAS 변경 없음.
