# Manual Review Precheck Run Guide v1

작성일: 2026-05-18

대상 SQL: `sql/precheck_manual_review_export_v1.sql`

## 1. 목적

이 문서는 수동검수 CSV를 실제로 생성하기 전에 `sql/precheck_manual_review_export_v1.sql`을 local DB에서 안전하게 read-only로 실행하고, 결과를 PM 세션에 보고하기 위한 안내문이다.

이 precheck SQL은 다음을 확인한다.

- 수동검수 CSV 작성에 필요한 테이블 존재 여부
- 수동검수 CSV 작성에 필요한 컬럼 존재 여부
- `code_alias.code_system` 분포를 확인할 수 있는 구조인지 여부
- candidate/confirmed code system을 분리할 수 있는 구조인지 여부
- `product_image` 기반 이미지 검수 가능 여부
- `sku_channel_mapping` 등 판매처별 export 기반 컬럼 존재 여부
- 실제 export SELECT 초안을 작성할 수 있는 최소 구조가 준비되어 있는지 여부

이번 단계는 실제 export 생성 전 구조 점검이다. DB 변경이 없는 read-only 확인 단계이며, CSV/XLSX 파일을 만들지 않는다.

## 2. 실행 전 조건

반드시 아래 조건을 모두 확인한 뒤 실행한다.

- local DB에서만 실행한다.
- 운영 Supabase에서 실행하지 않는다.
- NAS PostgreSQL에서 실행하지 않는다.
- 원격 DB에서 실행하지 않는다.
- SQL 파일을 열어 `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `TRUNCATE`, `CREATE`, `ALTER`, `DROP`이 없는지 재확인한다.
- `\copy`, 파일 출력, temp table 생성이 없는지 재확인한다.
- psql 또는 SQL 클라이언트에서 결과만 확인한다.
- 결과를 보고 다음 SELECT export 설계 가능 여부를 판단한다.

실행 대상 DB가 local인지 먼저 확인한다. 예를 들어 local Docker PostgreSQL을 쓴다면 DB 이름이 `product_ops_test`인지 확인한다.

```sql
SELECT current_database() AS db_name, current_user AS db_user, now() AS checked_at;
```

위 확인 쿼리도 운영 Supabase/NAS가 아닌 local DB 접속 상태에서만 실행한다.

## 3. 실행 방법

local DB의 승인된 read-only 실행 세션에서만 실행한다.

psql 예시:

```powershell
psql -h localhost -p 5433 -U product_ops_tester -d product_ops_test -f sql/precheck_manual_review_export_v1.sql
```

SQL 클라이언트를 사용할 경우:

1. `sql/precheck_manual_review_export_v1.sql` 파일을 연다.
2. 대상 연결이 local DB인지 확인한다.
3. 전체 SQL을 실행한다.
4. 각 SELECT 결과를 복사한다.

이 SQL은 여러 SELECT 결과를 순서대로 출력한다. 결과 테이블의 `check_area` 값을 기준으로 `table_check`, `column_check`, `code_system_readiness_check`, `final_overall`을 구분한다.

## 4. 실행 후 사용자 보고 형식

실행 후 아래 항목을 PM 세션에 그대로 붙여넣는다.

```text
- 실행 DB local 확인:
  - db_name:
  - db_user:
  - checked_at:

- 에러 발생 여부:
  - 없음 / 있음
  - 에러가 있으면 메시지:

- table_check 결과:
  - 전체 결과 또는 MISSING_REVIEW_REQUIRED row 목록:

- column_check 결과:
  - 전체 결과 또는 MISSING_REVIEW_REQUIRED row 목록:

- final_overall 결과:
  - result:
  - note:

- missing table 목록:
  - 없음 / 목록:

- missing column 목록:
  - 없음 / 목록:
```

가능하면 `table_check`, `column_check`, `final_overall` 결과는 표 형태 그대로 복사한다. 결과가 길면 `status = MISSING_REVIEW_REQUIRED`인 row를 우선 보고하고, 전체 결과는 별도 파일 생성 없이 클립보드 텍스트로 전달한다.

## 5. 결과 해석 기준

### missing 없음

필수 구조가 준비된 상태로 볼 수 있다. 다음 단계에서 실제 수동검수 CSV용 SELECT 초안, 예를 들어 `select_manual_review_export_v1.sql` 설계를 시작할 수 있다.

### 일부 missing

실제 local DB의 테이블명 또는 컬럼명이 precheck 예상 목록과 다를 수 있다. 결과를 기준으로 실제 테이블명/컬럼명에 맞춰 SELECT export SQL 초안을 보정해야 한다.

### `code_alias` 관련 missing

`code_alias` 테이블 또는 `code_system`, `code_value` 컬럼이 없으면 code system 분포 확인 쿼리는 보류한다. confirmed/candidate 분리 기준도 먼저 재확인해야 한다.

### `product_image` 관련 missing

이미지 없음 검수 대상 추출 방식 보정이 필요하다. `product_image`가 없으면 이미지 missing 결과를 실제 상품 이미지 부재로 확정하지 말고, image import 또는 image source 구조 상태를 먼저 확인한다.

### channel mapping 관련 missing

`sku_channel_mapping`, `channel_code`, `channel_sku_code`, `seller_product_code`, `own_sku_code` 등이 없으면 판매처별 export용 컬럼 설계를 재확인해야 한다. Smartstore productNo/optionNo, MakeShop mapping, Ably/PlayAuto 후보 구조를 실제 local schema에 맞춰 다시 매핑한다.

## 6. 다음 단계

1. precheck 결과를 PM 세션에 보고한다.
2. 결과 기준으로 `select_manual_review_export_v1.sql` 초안을 작성한다.
3. 그 다음 reviewed CSV validate SQL을 설계한다.

이 안내문은 precheck 실행 전후 절차까지만 다룬다. 실제 수동검수 CSV 생성, reviewed CSV 저장, local apply, postcheck는 별도 승인 후 별도 SQL로 진행한다.
