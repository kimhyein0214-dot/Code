# Unmatched Order Items SOP

`precheck_cross_mapping_v2.sql` STEP C 결과에서 Product_code master 와 연결되지 않는 PR_system 주문상품 라인을 처리하는 절차다.

## 1. 격리 기준

미매칭 라인은 아래 중 하나다.

- `order_items.p_code` 가 Product_code `code_alias(code_system='selfpia_sku').code_value` 에 없음
- `p_dpcode_clean` / `prod_code_clean` 의 `own_sku` fallback 후보도 없음
- fallback 후보가 2개 이상이라 자동 확정할 수 없음

## 2. 분류

| 유형 | 의미 | 처리 |
|---|---|---|
| `NNN-NN` 미매칭 | selfpia_sku 형식은 맞지만 Product_code master 누락 가능 | 상품팀 master 보강 요청 |
| `empty` | 주문상품의 SKU key 누락 | 원주문/수집 로직 확인 |
| `other` | 예상 외 key 형식 | 수집/파싱 규칙 확인 |
| `own_sku ambiguous` | 같은 own_sku 가 여러 SKU 후보로 연결 | 중복 해소 규칙 확정 전 보류 |

## 3. 보강 요청에 포함할 필드

- `item_no`
- `ord_no`
- `inv_no`
- `p_code`
- `p_dpcode_clean`
- `prod_code_clean`
- `p_name`
- `p_option`
- `qty`
- fallback 후보 `sku_id` 목록이 있으면 함께 첨부

## 4. 처리 원칙

- 운영 Supabase DB 에 직접 수정하지 않는다.
- Product_code master 보강은 별도 승인된 master 관리 절차로 수행한다.
- `own_sku` 가 n:m 인 경우 `is_primary=true` 만으로 자동 확정하지 않는다. 같은 code_value 의 후보 수, 상품명, 옵션값, selfpia product hint 를 같이 검토한다.
- 보강 후 cross mapping 을 재실행해 `db_integration_inventory.md` 의 §5 값을 갱신한다.

## 5. NAS ETL 반영

- 확정 매칭 라인: `selfpia_sku_code` 로 `picking.order_items` 적재
- 미확정 라인: `stg.unmatched_order_items` 에 격리
- ambiguous 라인: `stg.unmatched_order_items` 에 후보 목록과 함께 저장하고 운영 테이블 적재는 보류

## 6. 2026-05-12 로컬 실측 미매칭 5건

노트북 Docker PostgreSQL cross mapping 실측 결과, `selfpia_sku` 직접 미매칭은 5건이다.

| p_code | 상품명 | 현재 판단 | 권장 처리 |
|---|---|---|---|
| `9826-1` | 925 실버 피어싱 귀걸이 원터치 미니 링피어싱 귓바퀴 93종 | 배송완료 과거 주문으로 추정 | raw `p_code` 보존, master 미매칭 격리 |
| `9826-3` | 925 실버 피어싱 귀걸이 원터치 미니 링피어싱 귓바퀴 93종 | 배송완료 과거 주문으로 추정 | raw `p_code` 보존, master 미매칭 격리 |
| `9826-26` | 925 실버 피어싱 귀걸이 원터치 미니 링피어싱 귓바퀴 93종 | 배송완료 과거 주문으로 추정 | raw `p_code` 보존, master 미매칭 격리 |
| `9826-31` | 925 실버 피어싱 귀걸이 원터치 미니 링피어싱 귓바퀴 93종 | 배송완료 과거 주문으로 추정 | raw `p_code` 보존, master 미매칭 격리 |
| `9826-48` | 925 실버 피어싱 귀걸이 원터치 미니 링피어싱 귓바퀴 93종 | 배송완료 과거 주문으로 추정 | raw `p_code` 보존, master 미매칭 격리 |

처리 방안:

- 초기 이전 시 `picking.order_items.selfpia_sku_code` 또는 `selfpia_sku_id` 는 nullable 로 둔다.
- 또는 FK 를 `NOT VALID` 로 생성하고, 보강 완료 후 `VALIDATE CONSTRAINT` 를 수행한다.
- `picking.order_items.raw_p_code` 또는 기존 raw `p_code` 를 반드시 보존한다.
- 미매칭 라인은 `master_match_status = 'unmatched'` 같은 상태 컬럼으로 운영 테이블에 남기거나, `stg.unmatched_order_items` 로 격리한다.
- 배송완료 과거 주문이면 운영 조회/감사용 보존을 우선하고, 새 피킹/검품 흐름에 투입하지 않는다.
