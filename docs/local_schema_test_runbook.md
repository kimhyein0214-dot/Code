# Local Schema Test Runbook

NAS PostgreSQL schema 초안 v2를 노트북 Docker PostgreSQL (`product_ops_test`) 에서만 적용 테스트하는 절차다.

## 1. 전제

- 운영 Supabase DB 변경 금지
- NAS PostgreSQL 적용 금지
- 로컬 Docker PostgreSQL 에서만 DDL 실행
- cross mapping 결과는 `docs/db_integration_inventory.md` §5에 기록되어 있어야 함

## 2. 로컬 DB 실행

```powershell
Copy-Item .env.local.example .env.local
docker compose --env-file .env.local -f docker-compose.local-test.yml up -d
docker compose --env-file .env.local -f docker-compose.local-test.yml ps
```

psql 접속:

```powershell
docker compose --env-file .env.local -f docker-compose.local-test.yml exec postgres psql -U product_ops_tester -d product_ops_test
```

## 3. Schema v2 적용

컨테이너 psql 안에서 실행한다.

```sql
\i /sql/local_schema_apply_test.sql
```

`local_schema_apply_test.sql` 은 `current_database() = 'product_ops_test'` 가 아니면 중단한다.

## 4. Validation 실행

schema 적용 후 같은 psql 세션에서 실행한다.

```sql
\i /sql/post_migration_validation_v2.sql
```

확인 항목:

- schema 6개 존재: `product_code`, `picking`, `inspection`, `cs`, `audit`, `stg`
- `stg.unmatched_order_items` 에 `9826-*` 5건 seed row 존재
- `fk_order_items_sku_id` 가 존재하고 `convalidated = false` 인지 확인
- `picking.order_items.raw_p_code` 보존 컬럼 존재
- `master_match_status` check 제약 존재

## 4.1 실제 실행 결과 (2026-05-12)

로컬 Docker PostgreSQL에서 schema v2 적용 및 validation 확인 완료.

실행 환경:

- DB: `product_ops_test`
- user: `product_ops_tester`
- Docker PostgreSQL
- 운영 Supabase 변경 없음
- NAS 변경 없음

확인 결과:

| 항목 | 결과 |
|---|---:|
| 주요 인덱스 | 53개 |
| 주요 view | 4개 |
| audit base tables | 2 |
| cs base tables | 3 |
| inspection base tables | 1 |
| picking base tables | 5 |
| product_code base tables | 5 |
| stg base tables | 2 |

주요 view:

- `picking.v_order_items_master_match_summary`
- `picking.v_order_items_unmatched`
- `product_code.v_sku_canonical`
- `stg.v_ambiguous_own_sku_candidates`

`/d` 오타로 인한 syntax error 1건이 있었지만 schema 적용/validation과 무관하다.

## 5. Local reset

초기화가 필요하면 `sql/local_schema_apply_test.sql` 하단의 Local reset section 을 직접 확인한 뒤 로컬 DB에서만 실행한다.

주의:

- reset section 은 destructive SQL 이다.
- 운영 Supabase 또는 NAS 에서 실행 금지.
- 실행 전 현재 DB가 `product_ops_test` 인지 확인한다.

## 6. 다음 단계

1. schema 적용/validation 결과를 `docs/codex_handoff_status.md` 에 기록
2. 필요하면 `schema_nas_postgresql_draft_v2.sql` 수정
3. ETL load script 설계
4. API 서버가 사용할 read/write boundary 설계
5. 로컬 통합 검증 완료 후에만 NAS 이전 절차 검토

## 7. Local API Endpoint Test (2026-05-12)

schema v2 validation 이후, 같은 로컬 Docker PostgreSQL을 대상으로 API server skeleton endpoint 응답을 확인했다.

실행 환경:

```text
Docker PostgreSQL: product_ops_test_postgres
Docker API: product_ops_api_local
API port: 8080
DB: product_ops_test
DB user: product_ops_tester
```

기본 실행 명령:

```powershell
docker compose --env-file .env.local -f docker-compose.local-test.yml up -d
docker compose --env-file .env.api -f docker-compose.local-test.yml -f docker-compose.api-local.yml up -d api
```

확인 endpoint:

```powershell
Invoke-RestMethod http://localhost:8080/health
Invoke-RestMethod http://localhost:8080/mapping/summary
Invoke-RestMethod http://localhost:8080/mapping/unmatched
Invoke-RestMethod http://localhost:8080/product-code/skus?limit=50
Invoke-RestMethod http://localhost:8080/picking/order-items?limit=50
```

결과:

| Endpoint | 결과 |
|---|---|
| `/health` | 성공, `ok=true`, DB 연결 확인 |
| `/mapping/summary` | 성공, `data={}` |
| `/mapping/unmatched` | 성공, `9826-*` 미매칭 데이터 반환 |
| `/product-code/skus?limit=50` | 성공, `data={}` |
| `/picking/order-items?limit=50` | 성공, `data={}` |

해석:

- 빈 결과는 현재 local schema test DB에 `product_code.sku_master` / `picking.order_items` sample row가 충분히 적재되지 않은 상태로 판단한다.
- API 서버와 PostgreSQL 연결, route wiring, 미매칭 staging 조회는 정상이다.
- 운영 Supabase 변경 없음.
- NAS 변경 없음.

다음 단계:

- local Docker DB 전용 seed/sample data를 설계한다.
- seed 대상은 `product_code.sku_master`, `product_code.code_alias`, `picking.order_items` 최소 row로 제한한다.
- seed는 로컬 Docker DB 전용이며 운영 Supabase/NAS에는 적용하지 않는다.
