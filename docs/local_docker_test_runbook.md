# Local Docker PostgreSQL Test Runbook

이 문서는 NAS 이전 전에 노트북 Docker PostgreSQL을 로컬 검증 DB로 사용해 cross mapping 과 schema 초안을 검증하는 절차다. 운영 Supabase 에서는 SELECT-only CSV export 만 수행한다.

## 1. 구성 파일

| 파일/폴더 | 용도 |
|---|---|
| `docker-compose.local-test.yml` | 로컬 PostgreSQL 17 컨테이너 실행 |
| `.env.local.example` | 로컬 DB 접속 정보 예시 |
| `exports/` | Supabase SELECT 결과 CSV 저장 위치 |
| `sql/` | export SQL, 로컬 staging/측정 SQL, schema 초안 |
| `docker-data/` | 로컬 PostgreSQL 데이터 볼륨 |
| `docs/` | runbook / inventory / handoff 문서 |

## 2. Docker 실행

처음 한 번만 `.env.local.example` 을 `.env.local` 로 복사하고 로컬 전용 비밀번호를 정한다.

```powershell
Copy-Item .env.local.example .env.local
docker compose --env-file .env.local -f docker-compose.local-test.yml up -d
docker compose --env-file .env.local -f docker-compose.local-test.yml ps
```

PostgreSQL은 노트북 `localhost:5433` 으로 노출된다. 컨테이너 내부 DB명은 `product_ops_test` 이다.

컨테이너 psql 접속:

```powershell
docker compose --env-file .env.local -f docker-compose.local-test.yml exec postgres psql -U product_ops_tester -d product_ops_test
```

## 3. Supabase SELECT-only CSV export

운영 Supabase 에서는 아래 파일만 사용한다. 모두 SELECT-only 파일이다.

| 실행 DB | SQL 파일 | 저장 파일 |
|---|---|---|
| Product_code `mrqoqmidnrawflwezxlm` | `sql/export_product_code_selfpia_sku_alias_select_only.sql` | `exports/selfpia_sku_alias.csv` |
| Product_code `mrqoqmidnrawflwezxlm` | `sql/export_product_code_own_sku_alias_select_only.sql` | `exports/own_sku_alias.csv` |
| PR_system `vgxocngpykhlkosiaeew` | `sql/export_pr_system_order_items_xmap_select_only.sql` | `exports/order_items_xmap.csv` |

실행 순서:

1. 올바른 Supabase project 를 연다.
2. SQL 파일의 첫 번째 context SELECT 를 실행해 project/db/schema 를 확인한다.
3. 두 번째 export SELECT 만 실행한다.
4. 결과를 CSV 로 내려받아 `exports/` 폴더에 지정 파일명으로 둔다.

운영 Supabase 금지 사항:

- `CREATE`, `DROP`, `ALTER`
- `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`
- server-side `COPY`
- `stg_xmap` 또는 기타 staging table 생성
- `schema_nas_postgresql_draft.sql` 실행
- `post_migration_validation.sql` 실행

## 4. 로컬 CSV 적재

CSV 3개를 `exports/`에 둔 뒤 컨테이너 psql에 접속한다.

```powershell
docker compose --env-file .env.local -f docker-compose.local-test.yml exec postgres psql -U product_ops_tester -d product_ops_test
```

psql 안에서 `sql/local_cross_mapping_stage_and_measure.sql` 의 STEP B-0, B-1 을 실행해 `stg_xmap` schema 와 staging table 을 만든다.

그 다음 psql 안에서 아래 `\copy`를 실행한다.

```sql
\copy stg_xmap.selfpia_sku_alias FROM '/exports/selfpia_sku_alias.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy stg_xmap.own_sku_alias      FROM '/exports/own_sku_alias.csv'      WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy stg_xmap.order_items        FROM '/exports/order_items_xmap.csv'   WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
```

적재 후 STEP B-3 row count sanity check 를 실행한다.

기대 행 수:

| table | expected rows |
|---|---:|
| `stg_xmap.selfpia_sku_alias` | 33,287 |
| `stg_xmap.own_sku_alias` | 31,975 |
| `stg_xmap.order_items` | 6,169 |

## 5. Cross Mapping 측정

`sql/local_cross_mapping_stage_and_measure.sql` 에서 STEP C-1~C-5 를 순서대로 실행한다.

| STEP | 측정 항목 |
|---|---|
| C-1 | selfpia_sku 직접 매칭률 |
| C-2 | own_sku fallback unique / ambiguous / unmatched |
| C-3 | 최종 미매칭 sample |
| C-4 | ambiguous own_sku sample |
| C-5 | 미매칭 p_code pattern |

결과는 `docs/db_integration_inventory.md` 의 `§5.3 STEP C 결과 기록 템플릿` 에 채운다. 실행 상태와 남은 작업은 `docs/codex_handoff_status.md` 에도 갱신한다.

## 6. Schema 초안 로컬 검증

cross mapping 결과를 반영한 뒤에만 `sql/schema_nas_postgresql_draft.sql` 을 로컬 Docker PostgreSQL에서 검토한다. 이 파일은 NAS나 운영 Supabase 에서 실행하지 않는다.

권장 순서:

1. cross mapping 결과가 inventory 에 기록됐는지 확인
2. schema 초안의 key/FK/dtype 가 실측 결과와 맞는지 검토
3. 필요한 수정은 파일로만 반영
4. 로컬 Docker DB 에서만 schema 적용 테스트
5. `sql/post_migration_validation.sql` 은 실제 migration 이후 검증용이므로 현 단계에서는 실행하지 않는다

## 7. 종료

```powershell
docker compose --env-file .env.local -f docker-compose.local-test.yml down
```

데이터까지 지우려면 `docker-data/postgres` 폴더를 삭제한다. 운영 DB와는 무관한 로컬 데이터만 대상인지 확인하고 삭제한다.
