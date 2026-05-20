# Manual Review Decision v2 Schema Runbook

## Purpose

This runbook explains the draft SQL files for preparing a local-only manual review decision table.

This stage prepares decision storage only. It does not implement API writes, frontend save buttons, production apply, channel mapping updates, or product data changes.

## Files

- `sql/schema_manual_review_decision_v2_draft.sql`
  - Draft DDL for `product_code_review.manual_review_decision`.
  - Do not run until dry-run passes and the user explicitly approves local apply.
- `sql/dryrun_manual_review_decision_v2_schema.sql`
  - Transactional dry-run.
  - Creates the schema/table inside `BEGIN`, verifies constraints, and ends with `ROLLBACK`.
- `sql/postcheck_manual_review_decision_v2_schema.sql`
  - Read-only style postcheck after a separately approved local apply.
  - Verifies table, required columns, constraints, and row count visibility.

## Scope And Prohibitions

Local-only:

- Intended DB: `product_ops_test`.
- Intended local user: `product_ops_tester`.
- Intended environment: local/test.

Prohibited:

- Do not run on production Supabase.
- Do not run on NAS PostgreSQL.
- Do not run on any remote DB.
- Do not treat this table as an operating apply table.
- Do not use this step to update `product_code.code_alias`.
- Do not use this step to update `product_code.sku_channel_mapping`.
- Do not update source CSV/XLSX/XML files.

## Execution Order For A Future Approved Local Apply

Do not execute these steps until the user explicitly asks for schema validation/apply.

1. Run dry-run locally:

   ```text
   sql/dryrun_manual_review_decision_v2_schema.sql
   ```

2. Confirm the final `OVERALL` row.

   Expected dry-run verdict:

   ```text
   OVERALL | PASS | ALL PASS - draft can be considered for local apply after user approval
   ```

3. Ask for explicit user approval before any actual local schema apply.

4. After approval, apply the schema draft locally only:

   ```text
   sql/schema_manual_review_decision_v2_draft.sql
   ```

5. Run postcheck locally:

   ```text
   sql/postcheck_manual_review_decision_v2_schema.sql
   ```

6. Confirm the final `OVERALL` row.

   Expected postcheck verdict:

   ```text
   OVERALL | PASS | ALL PASS - local decision schema is present
   ```

## Meaning Of Decision Storage

The table stores reviewer intent only.

- `approve_match` means a reviewer approved the suggested match for local decision tracking.
- `approve_match` does not apply to production.
- `approve_match` does not immediately create aliases or channel mappings.
- `exclude_candidate` does not delete products.
- `inactive_reviewed` does not deactivate a channel product.
- Deletion/inactive review candidates are not deletion-confirmed rows.

## Required Guard Before v2 API Writes

The later API implementation must reject writes unless all local guards pass:

- DB name is `product_ops_test`.
- Environment is local/test.
- Connection is not production Supabase.
- Connection is not NAS PostgreSQL.
- Connection is not any remote DB.
- The requested decision is allowed for the candidate scope.

Decision write endpoints must remain separate from any later apply/export workflow.

## Current Non-Goals

- No API implementation.
- No frontend save implementation.
- No POST/PUT/PATCH/DELETE route implementation.
- No schema execution in this task.
- No migration execution.
- No operating DB apply.
