# Local Seed Sample Plan

API endpoint가 빈 결과가 아니라 실제 row를 반환하는지 확인하기 위한 로컬 Docker DB 전용 seed 계획이다.

## 1. 원칙

- 적용 대상은 로컬 Docker PostgreSQL `product_ops_test` 만.
- 운영 Supabase 적용 금지.
- NAS 적용 금지.
- 실제 운영 데이터 전체 적재 금지.
- seed는 API route 검증용 최소 row만 사용한다.

## 2. Seed 대상

| schema.table | 목적 |
|---|---|
| `product_code.product_master` | canonical SKU view 조인용 상품 |
| `product_code.sku_master` | `/product-code/skus` 반환 대상 |
| `product_code.code_alias` | `selfpia_sku` canonical alias |
| `picking.orders` | order item FK/조회용 주문 |
| `picking.order_items` | `/picking/order-items` 반환 대상 |
| `stg.unmatched_order_items` | 이미 9826-* seed 존재, 유지 |

## 3. Sample 시나리오

### matched row

- `raw_p_code`: `1258-1`
- `selfpia_sku_code`: `1258-1`
- `master_match_status`: `matched`
- `sku_id`: `product_code.sku_master.id` 와 연결

목적:

- `/product-code/skus` 가 row 반환
- `/product-code/skus/1258-1` 단건 반환
- `/picking/order-items?master_match_status=matched` 가 row 반환
- `/mapping/summary` 에 `matched` count 반영

### legacy_unmatched row

- `raw_p_code`: `9826-1`
- `master_match_status`: `legacy_unmatched`
- `sku_id`: null
- `selfpia_sku_code`: null

목적:

- `/picking/unmatched` 가 운영 미매칭 row 반환
- raw `p_code` 보존 확인

## 4. 작성 예정 SQL

작성 완료 산출물:

- `sql/local_seed_sample_data.sql`
- `sql/local_seed_sample_validation.sql`

`local_seed_sample_data.sql` 은 반드시 DB guard를 포함한다.

```sql
DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION 'Local seed is allowed only on product_ops_test.';
  END IF;
END
$$;
```

## 5. 검증 endpoint

```powershell
Invoke-RestMethod "http://localhost:8080/product-code/skus?search=1258-1"
Invoke-RestMethod "http://localhost:8080/product-code/skus/1258-1"
Invoke-RestMethod "http://localhost:8080/picking/order-items?master_match_status=matched"
Invoke-RestMethod "http://localhost:8080/picking/unmatched"
Invoke-RestMethod "http://localhost:8080/mapping/summary"
```

## 6. 완료 기준

- `/product-code/skus` 가 최소 1개 SKU row 반환
- `/picking/order-items` 가 최소 1개 matched row 반환
- `/picking/unmatched` 가 legacy unmatched row 반환
- `/mapping/summary` 에 `matched` 및 `legacy_unmatched` 상태 집계 표시
- 운영 Supabase / NAS 변경 없음

## 7. Runbook

실행 절차는 `docs/local_seed_sample_runbook.md` 를 따른다.
