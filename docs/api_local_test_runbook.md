# API Local Test Runbook

로컬 Docker API 서버가 로컬 Docker PostgreSQL (`product_ops_test`) 에만 연결되는지 확인하는 절차다. 운영 Supabase 와 NAS 에는 적용하지 않는다.

## 1. 전제

- Docker PostgreSQL: `product_ops_test_postgres`
- Docker API: `product_ops_api_local`
- API port: `8080`
- DB: `product_ops_test`
- DB user: `product_ops_tester`
- Supabase service role / anon key 사용 금지
- 클라이언트는 PostgreSQL 직접 접속 금지

## 2. 실행

```powershell
Copy-Item .env.api.example .env.api
docker compose --env-file .env.local -f docker-compose.local-test.yml up -d
docker compose --env-file .env.api -f docker-compose.local-test.yml -f docker-compose.api-local.yml up -d api
```

## 3. Endpoint 확인

```powershell
Invoke-RestMethod http://localhost:8080/health
Invoke-RestMethod http://localhost:8080/mapping/summary
Invoke-RestMethod http://localhost:8080/mapping/unmatched
Invoke-RestMethod "http://localhost:8080/product-code/skus?limit=50"
Invoke-RestMethod "http://localhost:8080/picking/order-items?limit=50"
```

## 4. 실제 테스트 결과

| Endpoint | 결과 | 해석 |
|---|---|---|
| `GET /health` | 성공, `ok=true` | DB 연결 확인 |
| `GET /mapping/summary` | 성공, `data={}` | 운영 데이터 미적재로 빈 집계 |
| `GET /mapping/unmatched` | 성공 | `9826-*` 미매칭 데이터 반환 |
| `GET /product-code/skus` | 성공, `data={}`, `limit=50` | product_code sample 미적재 |
| `GET /picking/order-items` | 성공, `data={}`, `limit=50` | picking sample 미적재 |

## 5. 판정

- API 서버 구동 성공
- PostgreSQL 접근 구조 검증 완료
- route wiring 정상
- `stg.unmatched_order_items` 조회 정상
- 클라이언트가 DB에 직접 접속하지 않는 구조의 1차 검증 완료
- 운영 Supabase 변경 없음
- NAS 변경 없음

## 6. 다음 검증

로컬 Docker DB 전용 seed/sample data를 적재한 뒤 아래 endpoint가 실제 row를 반환하는지 재검증한다.

- `GET /product-code/skus`
- `GET /product-code/skus/:selfpiaSkuCode`
- `GET /picking/order-items`
- `GET /mapping/summary`

## 7. Seed 후 재테스트 절차

로컬 Docker PostgreSQL psql에서 실행한다.

```sql
\i /sql/local_seed_sample_data.sql
\i /sql/local_seed_sample_validation.sql
```

그 다음 API endpoint를 다시 확인한다.

```powershell
Invoke-RestMethod "http://localhost:8080/product-code/skus?search=LOCAL_TEST"
Invoke-RestMethod "http://localhost:8080/product-code/skus/LOCAL_TEST_1258-1"
Invoke-RestMethod "http://localhost:8080/picking/order-items?master_match_status=matched"
Invoke-RestMethod "http://localhost:8080/picking/unmatched"
Invoke-RestMethod "http://localhost:8080/mapping/summary"
Invoke-RestMethod "http://localhost:8080/mapping/unmatched"
Invoke-RestMethod "http://localhost:8080/mapping/own-sku/ambiguous"
```

기대:

- `/product-code/skus` 는 LOCAL_TEST SKU 2건 이상 반환
- `/picking/order-items` 는 matched sample 2건 반환
- `/mapping/summary` 는 빈 결과가 아니라 `matched`, `unmatched`, `ambiguous`, `legacy_unmatched` 집계를 반환

seed는 로컬 Docker DB 전용이며 운영 Supabase/NAS에는 적용하지 않는다.

## 8. Seed 후 실제 재검증 결과 (2026-05-12)

| Endpoint | 결과 | 해석 |
|---|---|---|
| `GET /product-code/skus?search=LOCAL_TEST` | 성공 | `LOCAL_TEST` SKU 2건 반환 |
| `GET /product-code/skus/LOCAL_TEST_1258-1` | 성공 | 단일 SKU 상세 반환 |
| `GET /picking/order-items?master_match_status=matched` | 성공 | matched order item 2건 반환 |
| `GET /picking/unmatched` | 성공 | unmatched / ambiguous / legacy_unmatched 3건 반환 |
| `GET /mapping/summary` | 성공 | matched 2 / unmatched 1 / ambiguous 1 / legacy_unmatched 1 집계 반환 |
| `GET /mapping/own-sku/ambiguous` | 성공 | `LOCAL_TEST_OWN_AMBIG` 후보 2개 반환 |

추가 관찰:

- `GET /mapping/unmatched` 에서 기존 `9826-*` legacy_unmatched 가 raw_p_code별로 2번씩 중복 반환됨.
- 현재 `/mapping/unmatched` 는 `stg.unmatched_order_items` row를 그대로 반환하는 line-level endpoint다.
- 중복 원인 확인은 `sql/local_check_unmatched_duplicates.sql` 로 진행한다.
