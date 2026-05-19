# Ably Unique Evidence Dryrun Plan v1

## Purpose

This document records the dryrun plan for Ably clean unique evidence candidates.

This is not an automatic matching apply:

- No operating Supabase access.
- No NAS PostgreSQL access.
- No remote DB access.
- No `product_code.code_alias` change.
- No `product_code.sku_channel_mapping` change.
- No COMMIT.
- No source CSV/XLSX modification or git add.

Dryrun SQL:

- `sql/dryrun_ably_unique_evidence_candidates_v1.sql`

Execution note:

- The executable SQL focuses on summary, quality checks, and rollback validation.
- Full sample extraction is intentionally separated into the next sample review step because conflict/sample joins are heavier than the dryrun summary and should be reviewed with narrower filters.

## Candidate Sources

Ably evidence sources:

- Ably CSV normalized evidence: option-level data with `channel_product_code` and `channel_option_code`.
- PlayAuto Ably normalized evidence: SKU-level supporting data with `channel_product_code` and `channel_sku_code`.

Source priority:

- Ably CSV is stronger for option-level apply because it contains Ably option numbers.
- PlayAuto Ably is strong supporting evidence because it contains exploded SKU lines and joins to Selfpia SKU aliases after `sellpia_` prefix normalization.

## Exclusion Rules

Rows are excluded from the first dryrun candidate set when any of these apply:

- `parse_warning IS NOT NULL`.
- `channel_product_code IS NULL`.
- Duplicate `channel_sku_code` risk.
- `is_active_candidate=false`.
- Candidate SKU does not join to exactly one SKU.
- Existing Ably alias already exists.
- Existing Ably channel mapping already exists.
- Ably CSV and PlayAuto Ably source comparison conflicts.

## Source Comparison Rules

Clean unique candidates are compared by:

- `sku_id`
- `channel_product_code`

Buckets:

- `both_sources_agree`: same SKU and same Ably product number appears in both sources.
- `source_conflict`: same SKU points to different Ably product numbers across sources, or same Ably product number points to different SKUs across sources.
- `ably_csv_only`: clean non-conflicting candidate only in Ably CSV.
- `playauto_ably_only`: clean non-conflicting candidate only in PlayAuto Ably.

Conflict policy:

- Exclude conflicts from the first final planned candidate set.
- Review conflict samples before any apply design.

## Dryrun Result

Execution: completed on local `product_ops_test`.

Guard:

- `current_database=product_ops_test`
- `current_user=product_ops_tester`
- `transaction_read_only=on`

Summary:

| Metric | Count |
|---|---:|
| Ably evidence total | 23,843 |
| Ably CSV clean unique | 3,518 |
| PlayAuto Ably clean unique | 4,404 |
| Both sources agree | 51 |
| Source conflict pair rows | 4,813 |
| Ably CSV only | 1,031 |
| PlayAuto Ably only | 1,942 |
| Warning excluded | 8,149 |
| Duplicate SKU excluded | 312 |
| Inactive excluded | 12,860 |
| Evidence missing excluded | 5,584 |
| Existing alias excluded | 0 |
| Existing mapping excluded | 0 |
| Final planned candidate pairs | 3,024 |

Quality checks:

| Check | Count |
|---|---:|
| skipped existing confirmed | 0 |
| skipped existing manual | 0 |
| duplicate Ably code in final plan | 0 |
| duplicate Selfpia-to-Ably in final plan | 0 |
| semantic warnings in final plan | 0 |

Rollback:

- `ROLLBACK` executed.
- Ably `code_alias` after count: 0.
- Ably `sku_channel_mapping` after count: 0.
- Rollback verdict: PASS.

Overall verdict:

- `PASS_WITH_CONFLICT_EXCLUSIONS`

Sample-risk note:

- The dryrun did not execute wide sample extraction in the committed SQL.
- The main visible risk is not random sample noise but the large source conflict bucket: 4,813 pair rows.
- Next sample review should focus first on `source_conflict`, then on final planned candidates.

## Interpretation

The dryrun found a useful first apply surface: 3,024 final planned candidate pairs after excluding warning, duplicate SKU risk, inactive rows, existing mappings/aliases, and source conflicts.

The source conflict bucket is large enough that it should not be ignored. The first apply design should either:

- use only conflict-excluded candidates, or
- run a separate conflict review before widening the candidate set.

PlayAuto-only candidates are product/SKU-level evidence and do not carry Ably option numbers. They should be treated differently from Ably CSV candidates in the apply design.

## Decision Framework

A) Dryrun PASS + conflict-excluded final candidates look clean -> sample review.

B) Source conflict exists -> keep conflict rows excluded and review conflict samples separately.

C) Warning/duplicate/inactive buckets remain excluded -> send to manual review or further source validation.

## Completion Report Template

1. 생성/수정 파일
2. local DB dryrun 실행 여부
3. ably_evidence_total
4. ably_csv_unique_count
5. playauto_ably_unique_count
6. both_sources_agree_count
7. source_conflict_count
8. warning/duplicate/inactive excluded count
9. existing_alias_excluded_count
10. final_planned_candidate_count
11. duplicate/semantic warning 결과
12. rollback 결과
13. OVERALL verdict
14. sample에서 위험해 보이는 케이스 여부
15. 다음 단계 제안
16. 커밋 해시
17. push 여부
18. git status -s 결과
19. 안전 확인
