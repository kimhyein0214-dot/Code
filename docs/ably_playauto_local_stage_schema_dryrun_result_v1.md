# Ably / PlayAuto Local Stage Schema Dryrun Result v1

## Purpose

This document records the local stage schema apply dryrun for the Ably / PlayAuto source evidence workflow.

This was a dryrun only. The schema was created inside a transaction and rolled back. No source CSV/XLSX import was performed. No operating Supabase, NAS PostgreSQL, or remote database was used.

## Files

Created in this step:

- `sql/dryrun_schema_local_stage_ably_playauto_v1.sql`
- `docs/ably_playauto_local_stage_schema_dryrun_result_v1.md`

Reviewed draft input:

- `sql/schema_local_stage_ably_playauto_draft_v1.sql`

## Execution

Target:

- database: `product_ops_test`
- user: `product_ops_tester`
- transaction read-only: `off`

The transaction intentionally allowed DDL inside the dryrun, then ended with `ROLLBACK`.

Command pattern used:

```powershell
Get-Content -Raw -LiteralPath sql\dryrun_schema_local_stage_ably_playauto_v1.sql |
  docker compose --env-file .env.local -f docker-compose.local-test.yml exec -T postgres `
    psql -v ON_ERROR_STOP=1 -U product_ops_tester -d product_ops_test -P pager=off
```

## Guard Result

| check | result |
|---|---|
| `current_database()` | `product_ops_test` |
| `current_user` | `product_ops_tester` |
| `transaction_read_only` | `off` |
| guard | `PASS` |

## Dryrun Objects

The dryrun created these local-only objects inside the transaction:

| object | result |
|---|---|
| schema `product_code_stage` | created inside transaction |
| `product_code_stage.ably_playauto_source_file` | PASS |
| `product_code_stage.ably_raw` | PASS |
| `product_code_stage.playauto_product_raw` | PASS |
| `product_code_stage.playauto_sku_raw` | PASS |
| `product_code_stage.channel_option_evidence` | PASS |

Pre-dryrun existing `product_code_stage` objects:

- existing relation count: `0`
- existing schema count: `0`
- verdict: `PASS`

## Traceability And Payload Columns

All required traceability and payload columns were present with expected types.

| requirement | result |
|---|---|
| `source_file_id uuid` on source/raw/evidence tables | PASS |
| `source_row_no integer` on raw/evidence tables | PASS |
| `source_option_line_no integer` on normalized evidence | PASS |
| `raw_payload jsonb` on raw/evidence tables | PASS |
| `channel_code text` on normalized evidence | PASS |
| `reviewer_decision text` on normalized evidence | PASS |
| `export_allowed boolean` on normalized evidence | PASS |

## Defaults

| table | column | default | result |
|---|---|---|---|
| `ably_raw` | `parse_status` | `'pending'::text` | PASS |
| `playauto_product_raw` | `parse_status` | `'pending'::text` | PASS |
| `playauto_sku_raw` | `parse_status` | `'pending'::text` | PASS |
| `channel_option_evidence` | `parse_status` | `'pending'::text` | PASS |
| `channel_option_evidence` | `reviewer_decision` | `'pending'::text` | PASS |
| `channel_option_evidence` | `export_allowed` | `false` | PASS |

## Constraints

| constraint | result |
|---|---|
| `ck_ably_playauto_source_file_name_not_path` | PASS |
| `ck_channel_option_evidence_reviewer_pending` | PASS |
| `ck_channel_option_evidence_export_blocked` | PASS |
| `ck_channel_option_evidence_not_playauto_channel` | PASS |

The `channel_code <> 'playauto'` constraint exists in the dryrun schema, so PlayAuto rows cannot be stored as a final marketplace channel in the normalized evidence table.

## Indexes

All ten draft indexes were created inside the transaction:

- `ix_ably_raw_product_no`
- `ix_ably_raw_option_no`
- `ix_playauto_product_raw_account`
- `ix_playauto_product_raw_product_no`
- `ix_playauto_sku_raw_code`
- `ix_channel_option_evidence_source`
- `ix_channel_option_evidence_channel_product`
- `ix_channel_option_evidence_channel_option`
- `ix_channel_option_evidence_own_sku_candidate`
- `ix_channel_option_evidence_selfpia_candidate`

Index verdict: `PASS`

## Rollback Result

The dryrun ended with `ROLLBACK`.

Post-rollback residual check:

| check | value | result |
|---|---:|---|
| remaining relation count under `product_code_stage` | 0 | PASS |
| remaining schema count for `product_code_stage` | 0 | PASS |

Final dryrun verdict: `PASS`

## Interpretation

The stage schema draft is structurally viable for a future local-only apply step:

- local schema name is available
- all draft tables can be created
- defaults keep evidence pending and non-exportable
- raw payloads are `jsonb`
- source row traceability is available
- normalized option-level evidence structure is available
- PlayAuto-as-channel is blocked
- rollback leaves no residual local DB objects

## Codex First-Pass Judgment

It is reasonable to move to the next step, local schema apply planning, after user approval.

Do not proceed directly to local schema apply without approval. The next step should decide whether to apply exactly this draft, add uniqueness constraints, or keep uniqueness checks in validation SQL until sample source rows are reviewed.

## Safety Notes

- Operating Supabase was not accessed.
- NAS PostgreSQL was not accessed.
- No remote DB was accessed.
- No source CSV/XLSX was modified.
- No source CSV/XLSX was added to git.
- No source import/export was generated.
- No mappings were applied.
- The transaction ended with `ROLLBACK`.
- No `product_code_stage` schema/table remained after rollback.
