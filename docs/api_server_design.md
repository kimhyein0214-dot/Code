# API Server Design

작성일: 2026-05-12

## 목적

PC 관리자 화면과 태블릿 피킹 화면이 PostgreSQL에 직접 접속하지 않고 Docker API 서버만 호출하도록 전환하기 위한 로컬 skeleton 설계다.

현재 API 서버는 로컬 Docker PostgreSQL (`product_ops_test`) 전용이다. 운영 Supabase service role, anon key, Supabase client key 는 사용하지 않는다.

## 원칙

- 클라이언트는 DB 직접 접속 금지
- API 서버만 PostgreSQL 접속
- 현재 연결 대상은 로컬 Docker PostgreSQL
- Product_code master 영역은 API 기준 SELECT-only
- picking / inspection / cs 운영 영역은 이후 API를 통해 read/write
- DB 비밀번호는 `.env.api` 에만 둔다
- 운영 Supabase 수정 금지
- NAS 적용 금지

## 로컬 구성

| 파일 | 역할 |
|---|---|
| `.env.api.example` | API 서버 환경변수 예시 |
| `docker-compose.api-local.yml` | 로컬 API 컨테이너 |
| `server/package.json` | Node/Express dependency |
| `server/src/server.js` | Express app entry |
| `server/src/db.js` | PostgreSQL pool |
| `server/src/routes/*` | API route modules |

로컬 DB와 함께 실행:

```powershell
Copy-Item .env.api.example .env.api
docker compose --env-file .env.local -f docker-compose.local-test.yml up -d
docker compose --env-file .env.api -f docker-compose.local-test.yml -f docker-compose.api-local.yml up -d api
```

API base URL:

```text
http://localhost:8080
```

## DB 연결

`.env.api.example` 기본값:

```text
DATABASE_URL=postgres://product_ops_tester:change_me_local_only@postgres:5432/product_ops_test
```

compose 파일을 함께 실행할 때 API 컨테이너는 Docker network 안에서 `postgres:5432` 로 로컬 테스트 DB에 접속한다.

## 권한 경계

초기 skeleton은 read 중심이다.

| 영역 | 현재 API | 향후 |
|---|---|---|
| product_code | SELECT only | 계속 SELECT only |
| picking | SELECT only skeleton | 피킹 처리 API 추가 |
| mapping | SELECT only skeleton | 미매칭 검수/보정 workflow 추가 |
| inspection | 미구현 | 검품 등록 API 추가 |
| cs | 미구현 | ticket/event API 추가 |

쓰기 API는 schema/ETL 검증 후 별도 설계한다. 특히 Product_code master 수정 API는 이 skeleton 범위 밖이다.

## 보안 메모

- 이 skeleton은 로컬 개발용이다.
- 인증/JWT/세션은 아직 없음.
- NAS 또는 운영 배포 전에 인증, 권한, audit actor 기록, request logging, rate limit을 추가해야 한다.
- Supabase key는 사용하지 않는다.

## Health Check

```powershell
Invoke-WebRequest http://localhost:8080/health
```

정상 응답은 현재 DB명과 DB user를 JSON으로 반환한다.


## Local Endpoint Test Result (2026-05-12)

로컬 Docker API endpoint 1차 테스트 완료.

실행 환경:

| 항목 | 값 |
|---|---|
| Docker PostgreSQL | `product_ops_test_postgres` |
| Docker API | `product_ops_api_local` |
| API port | `8080` |
| DB | `product_ops_test` |
| DB user | `product_ops_tester` |

확인 결과:

| Endpoint | 결과 | 메모 |
|---|---|---|
| `GET /health` | 성공 | `ok=true`, DB 연결 확인 |
| `GET /mapping/summary` | 성공 | `data={}`. 로컬 DB에 운영 데이터가 충분히 적재되지 않아 빈 집계로 판단 |
| `GET /mapping/unmatched` | 성공 | `9826-*` 미매칭 데이터 반환. `stg.unmatched_order_items` 또는 관련 view/API 연결 확인 |
| `GET /product-code/skus` | 성공 | `data={}`, `limit=50`. `product_code.sku_master` sample 미적재 상태로 판단 |
| `GET /picking/order-items` | 성공 | `data={}`, `limit=50`. `picking.order_items` sample 미적재 상태로 판단 |

판단:

- API 서버 구동 성공
- API 서버의 PostgreSQL 접근 구조 검증 완료
- route 응답 성공
- 클라이언트가 DB에 직접 접속하지 않고 API 서버를 경유하는 구조 1차 검증 완료
- 운영 Supabase 변경 없음
- NAS 변경 없음

다음 검증은 로컬 Docker DB 전용 seed/sample data를 적재한 뒤 `/product-code/skus`, `/picking/order-items`가 실제 row를 반환하는지 확인한다.
