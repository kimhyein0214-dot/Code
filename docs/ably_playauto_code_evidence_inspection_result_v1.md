# Ably / PlayAuto Code Evidence Inspection Result v1

## Purpose

This document summarizes a read-only inspection of normalized Ably / PlayAuto stage evidence in `product_code_stage.channel_option_evidence`.

This step is diagnostic only:

- No automatic matching apply.
- No `product_code.code_alias` change.
- No `product_code.sku_channel_mapping` change.
- No operating Supabase access.
- No NAS PostgreSQL access.
- No remote DB access.
- No source CSV/XLSX modification or git add.

Inspection SQL:

- `sql/inspect_ably_playauto_code_evidence_v1.sql`

Execution:

- Ran on local `product_ops_test`.
- Guard PASS: `current_database=product_ops_test`, `current_user=product_ops_tester`.
- Explicit read-only transaction: `transaction_read_only=on`.
- No DDL/DML/COPY executed.
- No automatic matching apply.
- No `code_alias` or `sku_channel_mapping` mutation.

## Current Stage Evidence

| Metric | Count |
|---|---:|
| Total evidence rows | 41,240 |
| Warning bucket rows | 9,083 |
| Duplicate `channel_sku_code` risk rows | 312 |
| Direct evidence candidates | 35,392 |
| Unique clean evidence candidates | 21,372 |
| Duplicate evidence rows | 312 |
| Evidence missing rows | 5,845 |
| Existing channel mapping present rows | 0 |
| Existing channel alias present rows | 13,161 |
| Existing confirmed/manual conflict rows | 0 |

Key availability:

| Key | Non-null rows |
|---|---:|
| `seller_product_code` | 40,481 |
| `own_sku_code_candidate` | 41,240 |
| `selfpia_sku_candidate` | 35,914 |
| `channel_sku_code` | 32,082 |
| Missing `channel_product_code` | 9,083 |
| `channel_code='playauto'` | 0 |

## Classification Rules

Direct evidence:

- Evidence row has `selfpia_sku_candidate` and it joins directly to one known SKU via `sku_master.virtual_sku_code` or `code_alias.code_value`.

Unique evidence:

- Candidate keys from `selfpia_sku_candidate`, `own_sku_code_candidate`, `seller_product_code`, or `channel_sku_code` join to exactly one SKU.
- Row is not in the warning bucket.
- Row is not duplicate `channel_sku_code` risk.
- Row is active candidate.

Duplicate evidence:

- Candidate keys join to more than one SKU, or the same `channel_code + channel_sku_code` occurs on multiple evidence rows.

Evidence missing:

- No usable candidate key exists, or candidate keys do not join to any known SKU.

Warning excluded:

- `parse_warning` exists.
- `channel_product_code` is missing.
- These rows remain useful for review but are not automatic confirmation candidates.

Source not active:

- `is_active_candidate=false`, including sold-out, hidden, waiting, suspended, or option-disabled states.

## Known Risk Buckets

Warning bucket:

- Count: 9,083 PlayAuto warning rows.
- Main reason: missing `channel_product_code`.
- Policy: exclude from automatic apply; keep as review/supporting evidence only.

Duplicate `channel_sku_code` risk:

- Count: 156 duplicate groups / 312 rows.
- Policy: exclude from automatic apply unless later evidence proves uniqueness.

Smartstore from PlayAuto:

- Smartstore already had a prior local auto-confirm cycle.
- PlayAuto Smartstore evidence should be treated as overlap/supporting evidence first, not as a fresh apply surface.

Coupang / KakaoTalk Store:

- Row volume is small.
- Keep as separate evidence buckets for later channel-specific review.

## Channel-Level Results

| Channel | Source | Evidence rows | Unique candidate rows | Warning excluded | Duplicate risk | Evidence missing |
|---|---|---:|---:|---:|---:|---:|
| `ably` | Ably CSV | 9,158 | 3,518 | 0 | 0 | 5,323 |
| `ably` | PlayAuto XLSX | 14,685 | 4,404 | 8,149 | 312 | 261 |
| `smartstore` | PlayAuto XLSX | 16,096 | 12,885 | 794 | 0 | 261 |
| `coupang` | PlayAuto XLSX | 1,283 | 565 | 140 | 0 | 0 |
| `kakaotalk_store` | PlayAuto XLSX | 18 | 0 | 0 | 0 | 0 |

Direct evidence candidates:

| Channel | Source | Direct candidate rows |
|---|---|---:|
| `ably` | Ably CSV | 3,832 |
| `ably` | PlayAuto XLSX | 14,424 |
| `smartstore` | PlayAuto XLSX | 15,835 |
| `coupang` | PlayAuto XLSX | 1,283 |
| `kakaotalk_store` | PlayAuto XLSX | 18 |

Inactive / absent possible:

| Channel | Source | Rows |
|---|---|---:|
| `ably` | Ably CSV | 2,895 |
| `ably` | PlayAuto XLSX | 9,965 |
| `smartstore` | PlayAuto XLSX | 3,157 |
| `coupang` | PlayAuto XLSX | 718 |
| `kakaotalk_store` | PlayAuto XLSX | 18 |

## Candidate Join Findings

- `sellpia_` prefix normalization is required. Stage evidence often has values like `sellpia_11422-1`, while existing `selfpia_sku` aliases commonly store `11422-1`.
- `selfpia_sku_candidate`, `own_sku_code_candidate`, and `channel_sku_code` are productive keys.
- `seller_product_code` did not directly join to SKU-level aliases in this inspection.
- PlayAuto Smartstore has 13,161 rows with existing Smartstore channel alias overlap, so it should remain a support/validation surface before any new apply.
- Existing channel mapping count is 0 and conflict count is 0, so this inspection did not find confirmed/manual overwrite pressure.

## Auto-Match Potential

Ably:

- Ably CSV provides 3,518 clean unique candidates.
- PlayAuto Ably provides 4,404 clean unique candidates after warning, duplicate SKU, and inactive exclusions.
- Ably is a strong next dryrun target, but the two Ably sources should be reconciled so duplicate channel evidence does not create conflicting apply candidates.

Smartstore:

- PlayAuto Smartstore has 12,885 clean unique candidates, but Smartstore already had a prior local auto-confirm pass.
- Treat this as overlap/supporting evidence first.

Coupang:

- 565 clean unique candidates.
- Small enough for channel-specific dryrun and sample review.

KakaoTalk Store:

- 18 direct candidates, but 0 clean unique active candidates because all are inactive/absent bucket.
- Keep for later review, not immediate apply.

## Decision Framework

A) Proceed to unique evidence dryrun for clean Ably candidates first.

B) Exclude warning rows, duplicate `channel_sku_code` rows, and inactive rows from the first dryrun.

C) Use PlayAuto Smartstore as support/overlap validation, not as a fresh Smartstore apply surface.

D) Keep Coupang as a small separate dryrun bucket.

E) Send evidence-missing and warning rows to manual review or source validation.

## Completion Report Template

1. 생성/수정 파일
2. local DB read-only 실행 여부
3. channel_option_evidence total count
4. channel_code별 count
5. warning bucket count
6. duplicate channel_sku_code risk count
7. direct evidence candidate count
8. unique evidence candidate count
9. duplicate evidence count
10. evidence missing count
11. existing confirmed/manual conflict count
12. 채널별 자동매칭 후보 가능성
13. 다음 단계 제안
14. 커밋 해시
15. push 여부
16. git status -s 결과
17. 안전 확인
