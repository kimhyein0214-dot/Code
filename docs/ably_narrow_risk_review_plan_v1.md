# Ably Narrow Risk Review Plan v1

## Purpose

This document records the narrow risk review for Ably final planned candidates before any apply dryrun.

This step is review-only:

- No automatic matching apply.
- No `product_code.code_alias` change.
- No `product_code.sku_channel_mapping` change.
- No operating Supabase access.
- No NAS PostgreSQL access.
- No remote DB access.
- No source CSV/XLSX modification or git add.

Review SQL:

- `sql/select_ably_narrow_risk_review_v1.sql`

## Why Broad Risk Is Not Excluded

The prior sample review found broad risk keywords in most final planned rows, but many are normal option descriptors:

- `실버`
- `골드`
- `핑크골드`
- `로즈골드`
- `옐로우골드`
- standalone `크리스탈`

These are common valid colors/materials. Excluding all broad-risk rows would throw away most usable candidates, so this review isolates only narrower risk signals.

## Narrow Risk Criteria

Exclude from the first apply dryrun when any of these are present:

- `크리스탈AB`
- `크리AB`
- standalone `AB`
- `1+1`
- `세트`
- `수량`
- same Ably product group contains both `크리스탈` and `크리스탈AB`

Color equivalence policy:

- `핑크골드` can be treated as `로즈골드`.
- `옐로우골드` can be treated as `골드`.
- `크리스탈` and `크리스탈AB` are different colors.
- standalone `AB` needs review before automatic confirmation.

## Execution Result

Executed locally against `product_ops_test` with `BEGIN READ ONLY` and `ROLLBACK`.

| Metric | Count |
|---|---:|
| Final planned candidate count | 3,024 |
| Narrow risk candidate count | 751 |
| Standalone AB count | 2 |
| Crystal AB count | 43 |
| Crystal vs CrystalAB conflict count | 656 |
| Set or quantity count | 84 |
| 1+1 count | 1 |
| Safe broad color only count | 1,592 |
| Final planned after narrow risk exclusion count | 2,273 |
| Duplicate after exclusion count | 0 |
| Semantic warning after exclusion count | 0 |
| Apply dryrun ready verdict | READY_WITH_NARROW_RISK_EXCLUSION |

## Review Notes

The broad color-only bucket is large and should not be excluded by itself. It mostly represents normal option words such as silver, gold, pink gold, rose gold, yellow gold, or plain crystal.

The narrow risk bucket should stay out of the first apply dryrun:

- Standalone `AB` appears in product-level naming and needs manual confirmation before automatic mapping.
- `크리스탈AB` / `크리AB` candidates are real color variants and should not be merged with plain `크리스탈`.
- The largest narrow bucket is product-level mixing of plain crystal and crystal AB in the same Ably product group.
- `세트`, `수량`, and `1+1` are smaller but should remain review-first because option quantity/package semantics can change the matched SKU.

After excluding narrow risk candidates, the remaining 2,273 candidates have no duplicate planned exact pair and no semantic warning in this review query.

## Sample Buckets

The SQL outputs:

- narrow risk sample, up to 100
- standalone AB sample
- `크리스탈AB` / `크리AB` sample
- `크리스탈` vs `크리스탈AB` conflict sample
- `세트` / `수량` / `1+1` sample
- safe broad color only sample, 50
- final planned after exclusion sample, 100
- source conflict reference sample, 50

## Decision Framework

A) narrow risk excluded clean candidates PASS -> write apply dryrun SQL.

B) narrow risk is small and samples are safe -> consider including selected sub-buckets later.

C) repeated risky pattern appears -> move that bucket to manual review.

Current intended first pass:

- Keep source conflict excluded.
- Keep warning, duplicate SKU, inactive, and evidence-missing buckets excluded.
- Exclude narrow risk from first apply dryrun unless reviewed.

## Completion Report Template

1. 생성/수정 파일
2. local DB read-only 실행 여부
3. final_planned_candidate_count
4. narrow_risk_candidate_count
5. standalone_ab_count
6. crystal_ab_count
7. crystal_vs_crystal_ab_conflict_count
8. set_or_quantity_count
9. one_plus_one_count
10. safe_broad_color_only_count
11. final_planned_after_narrow_risk_exclusion_count
12. duplicate/semantic warning after exclusion
13. apply_dryrun_ready_verdict
14. sample에서 위험해 보이는 케이스 요약
15. Ably apply dryrun으로 넘어가도 될지 Codex 1차 판단
16. 커밋 해시
17. push 여부
18. git status -s 결과
19. 안전 확인
