# Smartstore productNo overlap cleanup result (2026-05-17)

## Summary

Smartstore productNo confirmed/candidate overlap 1 row was cleaned up in the local Docker PostgreSQL database only.

- Container: `product_ops_test_postgres`
- Database: `product_ops_test`
- DB user: `product_ops_tester`
- Scope changed: local DB only
- Supabase production changes: none
- NAS PostgreSQL changes: none
- Remote DB access/changes: none
- API/Frontend changes: none

## Backup

A pre-cleanup local DB backup was created before any apply step.

- File: `backups/product_ops_test_before_smartstore_product_no_overlap_cleanup_20260517_205309.dump`
- Format: `pg_dump -Fc`
- Size: 16,154,280 bytes

## Cleanup Target

Only one `smartstore_product_no_candidate` alias was targeted.

| Field | Value |
|---|---|
| `code_system` | `smartstore_product_no_candidate` |
| `target_id` | `f46f312c-4c9e-4405-a9a7-c23e1155bd31` |
| `code_value` | `7577001822` |
| candidate optionNo | `30809506051` |

The confirmed counterpart was preserved:

| Field | Value |
|---|---|
| `code_system` | `smartstore_product_no` |
| `target_id` | `f46f312c-4c9e-4405-a9a7-c23e1155bd31` |
| `code_value` | `7577001822` |
| confirmed optionNo | `27014145275` |

The cleanup did not touch `smartstore_product_no`, `smartstore_option_no`, or `smartstore_option_no_candidate`.

## Before And After Counts

| Metric | Before | After |
|---|---:|---:|
| `smartstore_product_no` | 897 | 897 |
| `smartstore_product_no_candidate` | 11,691 | 11,690 |
| confirmed/candidate overlap | 1 | 0 |
| candidate primary violations | 0 | 0 |
| SKU `1000-3` productNo rows | 0 | 0 |
| `smartstore_option_no` | 909 | 909 |
| `smartstore_option_no_candidate` | 11,691 | 11,691 |

## Dryrun Cleanup

The first dryrun was stopped by the guard because `remaining_overlap_in_tx=1`.

Cause: the initial dryrun SQL computed the post-delete overlap in the same data-modifying CTE statement. PostgreSQL snapshot behavior meant the sibling SELECT did not observe the DELETE result as intended. The transaction was rolled back, and the target row remained present.

The dryrun SQL was corrected to store the target/deleted ids in temp tables and compute the overlap in a separate statement.

Corrected dryrun result:

| Metric | Result |
|---|---:|
| `cleanup_candidate_target_rows` | 1 |
| `confirmed_counterpart_rows` | 1 |
| `rows_deleted_in_tx` | 1 |
| `remaining_overlap_in_tx` | 0 |
| verdict | `OVERALL PASS` |
| rollback check target rows | 1 |

Output files:

- `outputs/dryrun_cleanup_smartstore_product_no_candidate_overlap_20260517_205309.txt`
- `outputs/dryrun_cleanup_smartstore_product_no_candidate_overlap_20260517_205309_rerun.txt`

## Apply Cleanup

Apply completed successfully and committed exactly one local row deletion.

| Metric | Result |
|---|---:|
| deleted rows | 1 |
| `smartstore_product_no` | 897 |
| `smartstore_product_no_candidate` | 11,690 |
| confirmed/candidate overlap | 0 |
| candidate primary violations | 0 |
| SKU `1000-3` productNo rows | 0 |
| `smartstore_option_no` unchanged | 909 |
| `smartstore_option_no_candidate` unchanged | 11,691 |
| final verdict | `OVERALL PASS` |

Output file:

- `outputs/apply_cleanup_smartstore_product_no_candidate_overlap_20260517_205309.txt`

## Postcheck Cleanup

Cleanup-specific postcheck completed successfully.

| Metric | Result |
|---|---:|
| cleanup target candidate row after | 0 |
| confirmed counterpart after | 1 |
| `smartstore_product_no` | 897 |
| `smartstore_product_no_candidate` | 11,690 |
| confirmed/candidate overlap | 0 |
| missing adjusted confirmed/candidate | 0 / 0 |
| FK missing | 0 |
| duplicate alias pairs | 0 |
| final verdict | `OVERALL PASS` |

Output file:

- `outputs/postcheck_cleanup_smartstore_product_no_candidate_overlap_20260517_205309.txt`

## Postcheck Note

The original `sql/postcheck_smartstore_product_no_import.sql` still expects `smartstore_product_no_candidate = 11,691`, which was the pre-cleanup count. After cleanup, the official verification should be:

- `sql/postcheck_cleanup_smartstore_product_no_candidate_overlap.sql`

Do not use the original productNo postcheck as the cleanup success criterion unless it is intentionally updated to the adjusted candidate count of 11,690.

## Recurrence Prevention

Update the Smartstore productNo candidate generation/stage logic so that candidate rows are anti-joined against confirmed productNo rows:

- If a `smartstore_product_no_candidate` row has the same `target_id + code_value` as a confirmed `smartstore_product_no`, exclude it from the candidate export/stage.

The optionNo candidate should remain preserved separately as `smartstore_option_no_candidate` when it represents a distinct optionNo candidate.

