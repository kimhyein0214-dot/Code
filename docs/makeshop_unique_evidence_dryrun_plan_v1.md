# MakeShop Unique Evidence Dryrun Plan v1

## Purpose

This dryrun narrows the MakeShop medium candidates before any local apply design.

Previous inspection showed:

- full MakeShop medium candidates: `1,247`
- direct MakeShop code evidence: `0`
- unique own_sku-based MakeShop mapping evidence: `291`
- duplicate own_sku-based MakeShop evidence: `18`
- evidence missing: `956`

The full `1,247` rows must not be applied. The only practical next dryrun target is the subset where `own_sku` joins to existing `product_code.sku_channel_mapping` rows for `channel_code='makeshop'` and resolves to exactly one `seller_product_code + channel_sku_code` pair.

## Source Evidence

Current MakeShop code evidence source:

- `product_code.sku_channel_mapping`

Relevant columns:

- `channel_code`
- `seller_product_code`
- `channel_sku_code`
- `own_sku_code`
- `sku_id`

The dryrun does not import new MakeShop source files and does not write to `code_alias`.

## Dryrun Scope

Included for split:

- `candidate_total = 1,247`
- rows with medium confidence from the prior MakeShop dryrun workflow

Promoted to unique-evidence review:

- `unique_evidence_candidate_count = 291`
- condition: candidate `own_sku` joins to exactly one existing MakeShop `seller_product_code + channel_sku_code` pair

Excluded before any clean apply plan:

- `duplicate_evidence_excluded_count = 18`
- condition: candidate `own_sku` joins to multiple existing MakeShop code pairs
- `evidence_missing_excluded_count = 956`
- condition: no direct MakeShop code and no unique own_sku-based MakeShop code evidence

Additional clean-plan exclusions found inside the 291 unique-evidence rows:

- `duplicate_code_pair_excluded_count = 36`
- condition: the planned MakeShop code pair appears on multiple candidate SKUs
- `risk_keyword_excluded_count = 8`
- condition: risk keyword or semantic warning should not enter the clean plan

Clean planned rows:

- `insert_or_update_planned_count = 255`
- this is a planned count only; the SQL does not insert or update anything

## Execution

Run only against the local DB:

```powershell
Get-Content -Raw -Path sql\dryrun_makeshop_unique_evidence_candidates_v1.sql |
  docker compose --env-file .env.local -f docker-compose.local-test.yml exec -T postgres psql -U product_ops_tester -d product_ops_test -P pager=off
```

The SQL itself uses:

- `BEGIN READ ONLY`
- guard check for `current_database() = product_ops_test`
- `current_user` output
- summary and limited samples
- final `ROLLBACK`

Production Supabase, NAS PostgreSQL, and remote DBs must not be used.

## Pass Criteria

The clean planned subset passes when:

- `candidate_total = 1,247`
- `unique_evidence_candidate_count = 291`
- `duplicate_evidence_excluded_count = 18`
- `evidence_missing_excluded_count = 956`
- `skipped_existing_confirmed_count = 0`
- `skipped_existing_manual_count = 0`
- `duplicate_makeshop_code_count = 0`
- `duplicate_selfpia_to_makeshop_count = 0`
- `semantic_warning_count = 0`
- `rollback_after_count = 0`
- `rollback_verdict = 1`
- `overall_verdict = 1`

In the current run, the clean planned subset is `255` rows after excluding duplicate planned code pairs and semantic/risk rows from the 291 unique-evidence rows.

## Sample Buckets

The SQL outputs limited samples for:

- `own_sku_unique_code_evidence_sample`
- `duplicate_evidence_excluded_sample`
- `duplicate_code_pair_excluded_sample`
- `evidence_missing_excluded_sample`
- `risk_keyword_sample`
- `same_product_family_sample`
- `own_sku_repeat_sample`
- `random_sample`
- `risk_edge_sample`

Risk keyword samples include terms such as:

- `크리스탈`
- `크리스탈AB`
- `AB`
- `화이트골드`
- `실버`
- `세트`
- `1+1`
- `수량`
- `골드`
- `로즈골드`
- `핑크골드`

The risk sample is intentionally broader than the clean exclusion rule so reviewers can see edge cases before any local apply design.

## Decision Branches

### A. Dryrun PASS + Risk Controlled

If the clean planned subset remains duplicate-free and warning-free, a later task may write a local apply SQL for the clean subset only.

That later step still requires explicit user approval.

### B. Risk Found

If samples show risky semantics, strengthen the exclusion rules and rerun the dryrun.

Risk rows should not be applied until reviewed.

### C. Evidence or Duplicate Problem Found

If the unique evidence join produces duplicate MakeShop code pairs, selfpia split, semantic warnings, or unclear product/option evidence, keep those rows out of apply and move them to manual review or a stricter source-evidence workflow.

## Current First-Pass Decision

The full `291` unique-evidence rows should not be applied as-is.

The clean subset of `255` rows is a possible future local apply target, but only after:

- sample review of the unique evidence rows
- explicit user approval
- a separate local apply SQL task
- postcheck verification

## Safety Notes

- This step is dryrun only.
- It does not apply confirmed aliases.
- It does not create DDL.
- It does not import/export files.
- It does not overwrite existing confirmed/manual mappings.
- It ends with `ROLLBACK`.
- Existing pending SQL files and unrelated untracked files are not touched.

## Completion Report Template

Report:

- generated files
- local dryrun environment
- `candidate_total`
- `unique_evidence_candidate_count`
- `duplicate_evidence_excluded_count`
- `evidence_missing_excluded_count`
- `insert_or_update_planned_count`
- duplicate/risk/semantic warning counts
- rollback result
- overall verdict
- sample risk notes
- whether local apply is recommended now
