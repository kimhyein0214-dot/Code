# Integration Module Design

## 결정

`integration` schema는 후보가 아니라 필수 schema다. 운영 시스템은 외부 채널, 셀피아, 파일 import/export, bookmarklet client, scraper run, sync job 상태를 독립적으로 추적해야 한다.

연동/설정 모듈은 PC 관리자용이며, 외부 시스템 연결과 실행 이력을 관리한다. 상품관리, 채널상품관리, 주문/피킹 모듈은 연동 결과를 읽을 수 있지만 연동 상태를 직접 수정하지 않는다.

## 책임

- 셀피아 스크래퍼 실행 설정과 결과 기록
- 셀피아 메모 업데이터 실행 설정과 결과 기록
- 스마트스토어, 에이블리, 메이크샵, 플레이오토 import/export 관리
- external account와 credential reference 관리
- sync job 정의와 실행 이력 관리
- scraper run, import file, export file 관리
- bookmarklet client 등록과 버전 관리
- 실패, 재시도, 로그, alert 관리

## 소유 화면

- `/integrations/accounts`
- `/integrations/jobs`
- `/integrations/jobs/:jobId/runs`
- `/integrations/scrapers`
- `/integrations/imports`
- `/integrations/exports`
- `/integrations/bookmarklets`
- `/settings/integration`

## API

| Method | Endpoint | 설명 |
|---|---|---|
| `GET` | `/api/integrations/accounts` | 외부 계정 목록 |
| `POST` | `/api/integrations/accounts` | 외부 계정 등록 |
| `PATCH` | `/api/integrations/accounts/:id` | 계정 설정 수정 |
| `GET` | `/api/integrations/jobs` | sync job 목록 |
| `POST` | `/api/integrations/jobs` | sync job 생성 |
| `POST` | `/api/integrations/jobs/:id/run` | 수동 실행 |
| `GET` | `/api/integrations/jobs/:id/runs` | 실행 이력 |
| `GET` | `/api/integrations/scraper-runs` | scraper 실행 이력 |
| `POST` | `/api/integrations/import-files` | import 파일 등록 |
| `POST` | `/api/integrations/export-files` | export 파일 생성 요청 |
| `GET` | `/api/integrations/bookmarklets` | bookmarklet client 목록 |
| `GET` | `/api/integrations/logs` | 실패/재시도 로그 조회 |

## 읽는 데이터

- `integration.external_accounts`
- `integration.sync_jobs`
- `integration.sync_job_runs`
- `integration.scraper_runs`
- `integration.import_files`
- `integration.export_files`
- `integration.bookmarklet_clients`
- `integration.integration_logs`
- `product_code.sku_master`
- `product_code.code_alias`
- `product_code.channel_product`
- `product_code.channel_sku`
- `audit.domain_events`

## 쓰는 데이터

- `integration.external_accounts`
- `integration.sync_jobs`
- `integration.sync_job_runs`
- `integration.scraper_runs`
- `integration.import_files`
- `integration.export_files`
- `integration.bookmarklet_clients`
- `integration.integration_logs`
- 필요한 경우 change request 생성

`product_code` master를 직접 수정하지 않는다. 외부 데이터가 master 변경을 요구하면 change request를 생성한다.

## Conceptual Tables

### external_accounts

- `id`
- `provider`
- `account_name`
- `credential_ref`
- `status`
- `created_at`
- `updated_at`

### sync_jobs

- `id`
- `job_type`
- `provider`
- `schedule`
- `enabled`
- `config`
- `created_by`
- `created_at`

### sync_job_runs

- `id`
- `sync_job_id`
- `status`
- `started_at`
- `finished_at`
- `input_summary`
- `output_summary`
- `error_message`
- `retry_count`

### scraper_runs

- `id`
- `scraper_type`
- `provider`
- `status`
- `started_at`
- `finished_at`
- `rows_seen`
- `rows_changed`
- `error_message`
- `raw_log_ref`

### import_files

- `id`
- `provider`
- `file_type`
- `file_name`
- `storage_ref`
- `status`
- `row_count`
- `parsed_at`
- `created_by`

### export_files

- `id`
- `provider`
- `file_type`
- `file_name`
- `storage_ref`
- `status`
- `row_count`
- `created_by`

### bookmarklet_clients

- `id`
- `client_name`
- `provider`
- `version`
- `enabled`
- `last_seen_at`

### integration_logs

- `id`
- `source_type`
- `source_id`
- `level`
- `message`
- `context`
- `created_at`

## 실패/재시도/로그

- 모든 job/run은 `pending`, `running`, `success`, `failed`, `cancelled`, `retrying` 상태를 가진다.
- 실패는 원본 error message와 context를 보존한다.
- 재시도는 새 run으로 기록하고 이전 run을 덮어쓰지 않는다.
- 외부 시스템에 쓰기 작업을 수행할 때는 idempotency key를 둔다.
- 실패가 master 변경과 관련되면 직접 보정하지 않고 change request나 unmatched SOP로 연결한다.

## 다른 모듈과 연결되는 지점

- 상품관리: 외부에서 발견한 신규 alias, SKU 변경 후보를 change request로 전달
- 채널상품관리: 채널 상품/옵션 import/export 결과를 조회
- 주문/피킹: 주문 수집 job 결과를 주문 생성 workflow로 전달
- CS: 외부 주문/배송 상태 조회 결과를 ticket 처리에 참고
- audit: 모든 run, 실패, 외부 쓰기 작업을 domain event로 기록

## 지금 만들 것

- `integration` schema 필수화
- sync job/run 기본 모델
- external account 설정 화면
- import/export 파일 목록 화면
- scraper run 로그 화면
- API module skeleton

## 나중에 만들 것

- provider별 adapter 상세 구현
- credential vault 연동
- retry backoff 정책
- scheduler/worker 분리
- 운영 alert와 notification
- bookmarklet 배포/버전 업데이트 체계
