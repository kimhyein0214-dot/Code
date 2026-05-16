# MakeShop Weak Top1 Local Apply Result

Date: 2026-05-16

## Summary

MakeShop `weak_top1 strong_candidate` rows were applied to the local Docker PostgreSQL `product_ops_test` database.

Both apply and postcheck finished with `OVERALL PASS`.

This was a local-only DB change. There was no access to, or change in, production Supabase, NAS PostgreSQL, or any remote DB.

## Execution Target

| Item | Value |
|---|---|
| Docker container | `product_ops_test_postgres` |
| Database | `product_ops_test` |
| DB user | `product_ops_tester` |
| Target table | `product_code.sku_channel_mapping` |
| Channel code | `makeshop` |
| Source CSV | `outputs/makeshop_weak_top1_strong_candidate.csv` |
| Apply SQL | `sql/apply_makeshop_weak_top1_strong_candidate.sql` |
| Postcheck SQL | `sql/postcheck_makeshop_weak_top1_strong_candidate.sql` |

## Backup

A local DB backup was created before apply.

| Item | Value |
|---|---|
| Backup file | `backups/product_ops_test_before_makeshop_weak_top1_20260516.dump` |
| Format | `pg_dump -Fc` |
| Size | 15,632,059 bytes |

The apply SQL commits on success. After `COMMIT`, transaction rollback is no longer available through the apply script. Recovery requires restoring this local DB backup, or a separately approved cleanup using the `raw_payload.source='weak_top1_strong_candidate'` marker.

## Apply Result

| Item | Value |
|---|---:|
| source rows | 6,389 |
| insert candidate rows | 6,389 |
| inserted rows | 6,389 |
| delta | 6,389 |
| MakeShop rows before | 11,179 |
| MakeShop rows after | 17,568 |
| auto_confirm v3 retained rows | 11,179 |
| weak_top1 rows after | 6,389 |
| duplicate rows | 0 |
| conflict rows | 0 |
| missing SKU rows | 0 |
| null key rows | 0 |
| rule violation rows | 0 |
| apply final verdict | `OVERALL PASS` |

## Postcheck Result

| Item | Value |
|---|---:|
| source rows | 6,389 |
| weak_top1 applied rows | 6,389 |
| matched source rows | 6,389 |
| auto_confirm v3 retained rows | 11,179 |
| missing mapping rows | 0 |
| conflict rows | 0 |
| duplicate channel_sku_code keys | 0 |
| source null key rows | 0 |
| FK missing SKU rows | 0 |
| applied FK missing SKU rows | 0 |
| source rule violation rows | 0 |
| non-makeshop weak_top1 rows | 0 |
| apply marker status mismatch rows | 0 |
| unexpected review_reason rows | 0 |
| postcheck final verdict | `OVERALL PASS` |

Postcheck was read-only and ended with `ROLLBACK`.

## Current MakeShop Local Mapping State

| Category | Rows |
|---|---:|
| auto_confirm v3 | 11,179 |
| weak_top1 strong_candidate | 6,389 |
| MakeShop local mapping total | 17,568 |

## Safety Notes

- The only data change was in local Docker PostgreSQL `product_ops_test`, table `product_code.sku_channel_mapping`.
- Production Supabase was not changed.
- NAS PostgreSQL was not changed.
- No remote DB was accessed.
- API/Frontend were not changed.
- Source xlsx/csv/xml files were not changed.
- `review_required`, `ambiguous`, and `manual review` targets remain blocked from automatic apply.
- The export/upload rule remains unchanged: candidate, ambiguous, or weak inferred codes must not be treated as confirmed channel export values.

## Next Steps

1. Review this result document and the summary in `docs/codex_handoff_status.md`.
2. Decide whether to commit the two weak_top1 SQL files and the documentation.
3. Keep remaining MakeShop `review_required` / `ambiguous` / `manual review` targets in the manual review workflow.
