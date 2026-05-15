# NAS PostgreSQL Integration Plan

> **목표**: 피킹시스템 DB(PR_system) + 상품코드 DB(Product_code) 를 통합하여 **Synology NAS PostgreSQL** 에서 운영.
> Supabase 는 개발/검증 한정. 최종 트래픽은 NAS PG 로 수렴.
> 본 문서는 **설계 / 사전조사** 단계 산출물이며, 실제 이전 작업은 별도 일정.

---

## 1. 아키텍처 원칙

- **클라이언트(HTML/태블릿/PC)** 는 PostgreSQL 에 직접 접속하지 않는다.
- 모든 클라이언트는 **Docker API 서버** 를 통해서만 DB 에 접근한다.
- **PC 상품통합관리** 와 **태블릿 피킹시스템** 은 같은 API/DB 를 공유한다.
- 상품코드 = 기준(master), 피킹시스템 = 운영(orders/picking/inspection/cs).
- canonical key 는 `selfpia_sku_code` 역할의 `PR_system.order_items.p_code`.
- Product_code 에서는 `code_alias.code_system='selfpia_sku' AND code_alias.code_value = selfpia_sku_code` 를 통해 `sku_master.id` 로 연결한다.

```
 [태블릿/HTML/PC]  ──HTTPS──▶  [Docker API 서버] ──TCP/SSL──▶  [NAS PostgreSQL]
                                       │
                                       └─ JWT / 세션
```

---

## 2. 통합 schema 구조

| schema | 책임 | 변경 주체 |
|---|---|---|
| `product_code` | SKU master, 채널 매핑, 번들 | 상품팀 (가끔 INSERT/UPDATE) |
| `picking` | 주문, 주문상품, 피킹 작업 | API 서버 (빈번 INSERT/UPDATE) |
| `inspection` | 검품 결과 | API 서버 |
| `cs` | 티켓, 이벤트 | API 서버 |
| `audit` | 변경 이력 | API 서버 (INSERT only) |
| `stg` | ETL 임시 적재 | ETL 계정 (수시 DROP/CREATE 허용) |

상세 DDL 초안은 `sql/schema_nas_postgresql_draft_v2.sql` 참조. v2는 로컬 Docker PostgreSQL (`product_ops_test`) 적용/validation 확인을 완료했지만, 아직 NAS 적용용으로 승인된 상태는 아니다.

핵심 관계도(요지):

```
product_code.sku_master (PK selfpia_sku_code)
   ▲
   │ FK
   │
picking.order_items.selfpia_sku_code
   ▲
   │
picking.picking_tasks ── inspection.inspections
   ▲
   │
picking.orders ── cs.tickets ── cs.ticket_events
```

---

## 3. 키 통일 전략 (Product_code ↔ PR_system)

- **canonical key** = `selfpia_sku_code` 역할의 `PR_system.order_items.p_code`.
- Product_code 원본에는 `selfpia_sku_code` 단일 컬럼이 없으므로 `code_alias.code_value WHERE code_system='selfpia_sku'` 를 기준 alias 로 사용한다.
- 모든 운영 테이블에서 SKU 식별은 `selfpia_sku_code` 값(text) 만 사용하고, 필요 시 `code_alias.target_id → sku_master.id` 를 보조 FK/lookup 으로 둔다.
- 다른 키(`channel_sku_code`, `seller_product_code`, `virtual_sku_code` 등)는
  `product_code.sku_channel_mapping` 으로 분리하고, **운영 테이블에서는 raw 값만 감사용으로 보관**.
- ETL 시 `picking.order_items.raw_channel_sku` 컬럼에 원본 SKU 를 그대로 저장 → 추후 매핑 보강에 활용.
- 로컬 Docker PostgreSQL 실측 결과, `order_items.p_code` 와 Product_code `selfpia_sku` alias 의 직접 매칭률은 99.92% (`6,164 / 6,169`) 이다.
- 미매칭 5건은 과거 배송완료 주문으로 보이며, 과거 주문 보존을 위해 raw `p_code` 를 반드시 유지한다.

매칭 우선순위 (ETL 시 사용):

1. `order_items.p_code` → Product_code `code_alias(code_system='selfpia_sku').code_value`
2. `order_items.p_dpcode` / `prod_code` 정제값 → Product_code `code_alias(code_system='own_sku').code_value` 후보
3. `selfpia_product_code` + 옵션 매칭
4. `(channel_code, channel_sku_code)`
5. `(channel_code, seller_product_code)`
6. `virtual_sku_code`

미매칭 라인 처리: `stg.unmatched_order_items` 에 격리하거나 `picking.order_items.master_match_status` 로 관리한다. `own_sku` 는 n:m 중복 가능성이 있으므로 후보 산출용이며, 중복 해소 규칙 확정 전 자동 확정하지 않는다.

초기 FK 전략:

- 이전 초기에는 `picking.order_items.selfpia_sku_code` / `selfpia_sku_id` 를 nullable 로 두거나 master FK 를 `NOT VALID` 로 생성한다.
- 미매칭 과거 주문 5건 때문에 초기부터 strict NOT NULL + VALID FK 를 강제하면 전체 이전이 실패할 수 있다.
- master 보강이 완료되면 미매칭 상태를 해소하고 FK validation 또는 NOT NULL 전환을 별도 단계로 진행한다.

---

## 4. 이전 전략 (Migration Strategy)

### 4.1 단계

1. **사전조사** (현재 단계)
   - `precheck_product_code_inventory.sql`, `precheck_picking_inventory.sql` 실행 → inventory 채움
   - `precheck_cross_mapping.sql` 의 staging 절차로 매칭률 측정
2. **schema 확정**
   - inventory 결과 반영 → `schema_nas_postgresql_draft.sql` 수정 → 리뷰
3. **개발 DB 구축**
   - NAS PG 컨테이너 또는 별도 PG 인스턴스에 schema 적용
   - Supabase 데이터를 `pg_dump --schema-only` 후 정제 → NAS 에 적용
4. **샘플 데이터 적재**
   - Product_code → `pg_dump --data-only` → NAS `stg.*` 적재 → 매핑 규칙으로 `product_code.*` 적재
   - PR_system → 마찬가지로 `stg.*` 거쳐 `picking/inspection/cs` 적재
5. **Docker API 서버 통합 점검**
   - 새 DSN(NAS) 으로 dev 환경 구동
   - 핵심 API 회귀 테스트 (주문 조회/피킹 처리/검품 등록/CS 등록)
6. **읽기 트래픽 우선 전환**
   - HTML/태블릿 read API 만 NAS 로 우선 전환, 쓰기는 Supabase 유지
   - 쌍방 차이 모니터링
7. **쓰기 전환 / Cutover**
   - 점검창(점심/심야) 잡고 freeze
   - 최종 incremental dump → NAS 적용
   - DNS / API 환경변수 전환
   - 롤백 플랜: 환경변수 되돌리면 Supabase 로 복귀
8. **이전 후 검증**
   - `post_migration_validation.sql` 으로 row count, FK, 매칭률 확인
9. **Supabase 폐기 결정**
   - 1~2주 안정 운영 후 read-only freeze → 추가 1주 후 archive

### 4.2 데이터 이전 도구

- `pg_dump --format=custom --schema-only` / `--data-only`
- 큰 테이블은 `pg_dump --table=... -Fc` 분할
- staging 적재 시 `\COPY` (CSV) 또는 `pg_restore`
- 변환은 NAS 측 `stg.*` 에서 SQL 로 (외부 ETL 도구 없이도 가능)

### 4.3 idempotent 적재 패턴 (참고)

```sql
INSERT INTO product_code.sku_master AS m (selfpia_sku_code, selfpia_product_code, ...)
SELECT ...
FROM stg.sku_master_load s
ON CONFLICT (selfpia_sku_code) DO UPDATE
SET selfpia_product_code = EXCLUDED.selfpia_product_code,
    updated_at = now()
WHERE m IS DISTINCT FROM EXCLUDED;
```

---

## 5. Docker API 서버 권한 / 계정 설계

| role | 용도 | 권한 |
|---|---|---|
| `app_admin` | DBA / 스키마 변경 | OWNER on all app schemas |
| `app_api` | Docker API 서버 (운영) | product_code: SELECT only / picking, inspection, cs: SELECT,INSERT,UPDATE,DELETE / audit: INSERT |
| `app_ro` | 분석/리포트 | 전 schema SELECT |
| `app_etl` | 이전/배치 ETL | stg: ALL / 운영 schema: SELECT,INSERT (필요 시) |

원칙:

- API 서버는 **master 를 직접 수정하지 못한다** (실수 방지). master 수정은 별도 `app_master_writer` 또는 관리자 콘솔만.
- Product_code master 영역은 Docker API 서버 기준 SELECT-only 로 운영한다.
- 운영 테이블에 대해서도 `DELETE` 권한은 최소화 검토 (논리 삭제 컬럼 도입 고려).
- 비밀번호는 환경변수 (`POSTGRES_PASSWORD_APP_API`) 로 주입, Docker secrets 권장.
- 접속은 NAS 내부망 또는 Tailscale/VPN 으로 한정. 외부 공개 금지.
- TLS: NAS PG `ssl = on`, API 서버는 `sslmode=verify-full` 로 접속.

연결 풀:

- `pgbouncer` (transaction pool) 권장. 태블릿/PC 동접 수에 비례하지 않고 API 서버 수에 비례하므로 풀 크기는 작게 시작 (예: `default_pool_size=20`).

DSN 예시 (실제 값은 secret):

```
postgres://app_api:****@nas.local:6432/selfpia?sslmode=verify-full&application_name=docker_api
```

### 5.1 로컬 API skeleton

로컬 검증 단계의 API 서버 skeleton 을 `server/` 아래에 준비했다.

- 연결 대상: 로컬 Docker PostgreSQL `product_ops_test`
- 실행 compose: `docker-compose.api-local.yml`
- 환경변수 예시: `.env.api.example`
- 설계 문서: `docs/api_server_design.md`
- endpoint 계획: `docs/api_endpoint_plan.md`
- Supabase key/service role 은 사용하지 않는다.
- 현재 skeleton 은 read 중심이며, write API/인증/audit actor 는 다음 단계에서 설계한다.

---

## 6. 백업 / 복구

- NAS PG 자체: 일 1회 `pg_basebackup` + WAL archive 로 PITR 구성.
- 추가로 Synology Hyper Backup 으로 외부 저장소 1차 복제.
- 주 1회 `pg_dump -Fc` 논리 백업 → 외부 클라우드 보조 보관.
- 복구 리허설: 분기 1회, 임시 PG 인스턴스로 dump 복원 → `post_migration_validation.sql` 일부 실행으로 sanity check.

---

## 7. 모니터링 / 운영

- 컨테이너 로그 + `pg_stat_statements` 활성화.
- 핵심 알람: 연결 수, replication lag(추후), 디스크 잔량 20% 이하, deadlock 발생, slow query > 2s.
- 운영 대시보드는 `app_ro` 로 접속, 별도 read-replica 가능 시 분리.

---

## 8. 위험 요소 / 보류 사항

### 8.1 위험

- **PR_system 과 Product_code 의 동명 테이블 충돌**: 사전에 [3.1] 항목 확정, schema 분리로 해소되지만 ETL 매핑이 누락되면 데이터 혼입 위험. → schema 분리 + 이름 충돌 시 통합 시점에 `_legacy` 접미 부여.
- **selfpia_sku_code 단일화에 따른 master 보강 부담**: 매칭률이 100% 미만이면 미매칭 라인이 발생. → `stg.unmatched_order_items` 격리 + 상품팀 보강 SOP 필요.
  - 로컬 실측 결과 미매칭은 5건(99.92% 직접 매칭)이며, 모두 `9826-*` 계열 과거 배송완료 주문으로 보임.
- **Supabase 전용 기능 의존**: RLS, Realtime, Auth, Edge Functions, Storage. NAS 이전 시 각각 대체 필요.
  - RLS: API 서버 레이어에서 동등 정책 구현
  - Realtime: WebSocket/SSE 를 API 서버에서 구현 (`LISTEN/NOTIFY` 또는 polling)
  - Auth: 별도 IdP (Authentik/Authelia) 또는 API 서버 내장
  - Storage: NAS 파일시스템 + 정적 서버
- **시퀀스/식별자 충돌**: 두 DB 의 `bigserial` 시퀀스가 같은 범위라면 충돌. → ETL 시 신규 ID 재발급 또는 기존 ID 보존 시 시퀀스 `setval` 로 충돌 회피.
- **타임존**: Supabase 기본 UTC. NAS PG 도 UTC 로 통일 권장. 애플리케이션 측에서 KST 표시.
- **NAS 하드웨어 단일 장애점**: NAS 본체 장애 = 전사 정지. → 최소 hot standby (다른 NAS or VPS) 또는 RPO 1시간 이내의 외부 백업 필수.
- **네트워크**: 매장/물류현장 ↔ NAS 네트워크 끊김 시 태블릿 사용 불가. → API 서버에 read-cache 또는 offline queue 검토.

### 8.2 보류 사항 (사전조사 후 결정)

- master 단일 키가 진짜로 `selfpia_sku_code` 인지 (vs `selfpia_product_code`)
- 채널 매핑이 1:1 인지 1:N 인지 (UNIQUE 제약 가능 여부)
- 검품 사진의 저장 방식 (현재 어디에 있는지, 이전 시 어떻게 옮길지)
- CS 테이블의 외부 시스템 연동 키 (택배사, 환불 게이트웨이 등)
- 주문 수령일/송장번호 등 운영 데이터의 보존 기간 정책

---

## 9. 실행 순서 (체크리스트)

- [ ] `sql/precheck_product_code_inventory.sql` 실행 → inventory.md 작성
- [ ] `sql/precheck_picking_inventory.sql` 실행 → inventory.md 작성
- [ ] `sql/precheck_cross_mapping.sql` 절차로 매칭률 측정 → inventory.md `§5` 작성
- [ ] inventory 결과 검토 미팅
- [ ] `schema_nas_postgresql_draft.sql` 을 실데이터에 맞춰 수정 (dtype/길이/제약)
- [ ] NAS dev PG 구축, schema 적용
- [ ] ETL 스크립트 작성 → dev 환경에 1회 적재 → `post_migration_validation.sql` 실행
- [ ] Docker API 서버 dev DSN 으로 전환 → 회귀 테스트
- [ ] 운영 cutover 계획 수립 (점검창, 롤백, 통지)
- [ ] 운영 cutover 실행 → validation → 안정화
- [ ] Supabase read-only freeze → archive

---

## 10. 절대 주의사항 (재확인)

- 실제 운영 DB 에 **CREATE / ALTER / INSERT / UPDATE / DELETE / DROP / TRUNCATE 금지** (현 단계).
- 모든 조사 SQL 은 **SELECT-only**.
- **PR_system 과 Product_code 를 헷갈리지 말 것** — 매 SQL 첫 블록의 `current_database()` 확인 필수.
- 기존 운영 테이블 / 인덱스 / 권한을 건드리지 말 것.
- 변경이 필요한 경우 별도 PR / 별도 일정으로 진행.
