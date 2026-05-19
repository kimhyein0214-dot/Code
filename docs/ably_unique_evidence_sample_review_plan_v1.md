# Ably Unique Evidence Sample Review Plan v1

## Purpose

This document records the sample review plan for Ably final planned candidates before any apply dryrun.

This step is review-only:

- No automatic matching apply.
- No `product_code.code_alias` change.
- No `product_code.sku_channel_mapping` change.
- No operating Supabase access.
- No NAS PostgreSQL access.
- No remote DB access.
- No source CSV/XLSX modification or git add.

Sample SQL:

- `sql/select_ably_unique_evidence_sample_review_v1.sql`

## Scope

The prior Ably dryrun produced:

| Bucket | Count |
|---|---:|
| Ably evidence total | 23,843 |
| Ably CSV clean unique | 3,518 |
| PlayAuto Ably clean unique | 4,404 |
| Both sources agree | 51 |
| Source conflict | 4,813 |
| Warning excluded | 8,149 |
| Duplicate SKU excluded | 312 |
| Inactive excluded | 12,860 |
| Evidence missing excluded | 5,584 |
| Final planned candidates | 3,024 |

The source conflict bucket remains excluded from apply planning.

## Sample Buckets

The SQL outputs these review buckets:

| Bucket | Limit |
|---|---:|
| final planned sample | 100 |
| both sources agree sample | up to 100 |
| Ably CSV only sample | 100 |
| PlayAuto Ably only sample | 100 |
| source conflict sample | 100 |
| warning excluded sample | 50 |
| duplicate SKU excluded sample | 50 |
| inactive excluded sample | 50 |
| evidence missing sample | 50 |

Review fields are arranged so product name, option text, Selfpia/Sellpia code, and Ably codes can be compared on one row.

## Risk Keyword Rules

Risk keyword scan:

- `크리스탈`
- `크리스탈AB`
- `크리AB`
- `AB`
- `화이트골드`
- `실버`
- `골드`
- `로즈골드`
- `핑크골드`
- `세트`
- `1+1`
- `수량`

Interpretation:

- `핑크골드` can usually be treated as `로즈골드`.
- `옐로우골드` can usually be treated as `골드`.
- `크리스탈` and `크리스탈AB` are different colors.
- Standalone `AB` requires separate checking before automatic confirmation.

## Execution Result

Execution: completed on local `product_ops_test`.

Guard:

- `current_database=product_ops_test`
- `current_user=product_ops_tester`
- `transaction_read_only=on`
- SQL ended with `ROLLBACK`.

| Metric | Count |
|---|---:|
| Final planned sample count | 100 |
| Both sources agree sample count | up to 100 |
| Ably CSV only sample count | 100 |
| PlayAuto Ably only sample count | 100 |
| Source conflict sample count | 100 |
| Warning excluded sample count | 50 |
| Duplicate SKU excluded sample count | 50 |
| Inactive excluded sample count | 50 |
| Evidence missing sample count | 50 |
| Final planned sample risk keyword count | 100 |
| Final planned all risk keyword evidence count | 3,004 |

Summary from the sample SQL:

| Bucket | Count |
|---|---:|
| Final planned candidates | 3,024 |
| Source conflict | 4,813 |
| Both sources agree | 51 |
| Ably CSV only | 1,031 |
| PlayAuto Ably only | 1,942 |
| Warning excluded | 8,149 |
| Duplicate SKU excluded | 312 |
| Inactive excluded | 12,860 |
| Evidence missing | 5,584 |

## Sample Observations

The broad risk keyword scan is intentionally sensitive. It catches common option words such as `실버`, `골드`, and `핑크골드`, so the presence of risk keywords does not by itself mean the final planned 3,024 candidates should be excluded.

Observed review signals:

- Final planned samples are readable in one row with Ably product code, Ably option code or PlayAuto SKU, Sellpia/Selfpia code, product name, and option value.
- The final planned sample includes many ordinary color/material options (`실버`, `골드`, `핑크골드`) that need normal option comparison, not blanket exclusion.
- The warning excluded sample confirms the expected reason: PlayAuto Ably rows with missing `channel_product_code`.
- The source conflict bucket is large enough that it must remain excluded from the first apply dryrun.
- PlayAuto-only rows remain less strong than Ably CSV rows because they lack Ably option code.

Initial risk handling recommendation:

- Do not exclude all broad risk keyword rows.
- Keep source conflicts excluded.
- Before apply dryrun, add a narrower high-risk review pass for `크리스탈AB`, `크리AB`, standalone `AB`, `1+1`, `수량`, and `세트`.
- Treat `핑크골드=로즈골드` and `옐로우골드=골드` as potentially equivalent, but still sample-check.

## Review Criteria

Final planned:

- Product/option text should clearly match the Selfpia/Sellpia SKU.
- Ably product code should not be paired with conflicting SKU evidence.
- Risk keywords must not imply color/material/count mismatch.

Both sources agree:

- Highest-confidence sample bucket.
- If this bucket looks clean, it can anchor the apply dryrun checks.

Ably CSV only:

- Usually stronger than PlayAuto-only because it contains Ably option code.
- Check option value and color carefully.

PlayAuto Ably only:

- More cautious bucket because it has SKU evidence but no Ably option code.
- Should not be treated the same as Ably CSV option-level evidence.

Source conflict:

- Must remain excluded.
- Review to identify repeated conflict patterns.

Warning / duplicate / inactive / evidence missing:

- Keep excluded from automatic apply.
- Route to manual review or source validation if needed.

## Decision Framework

A) final planned sample PASS -> write apply dryrun SQL.

B) risk found -> add risk exclusion and rerun dryrun.

C) source conflict patterns are repeatedly safe -> consider separate second-pass candidate design.

D) conflict or PlayAuto-only risk is high -> move those buckets to manual review.

Current Codex first-pass judgment:

- Do not apply yet.
- It is reasonable to proceed to apply dryrun design for the 3,024 final planned candidates only if the next sample review explicitly accepts the common color/material cases.
- The source conflict bucket should stay excluded.
- A narrow high-risk keyword count/review should be run before apply dryrun.

## Completion Report Template

1. 생성/수정 파일
2. local DB read-only 실행 여부
3. final planned sample count
4. source conflict sample count
5. risk keyword가 final planned에 남아 있는지
6. sample에서 위험해 보이는 케이스 요약
7. 3,024건 전체 apply dryrun으로 넘어가도 될지 Codex 1차 판단
8. 제외가 필요하다면 제외 기준/예상 제외 수
9. 커밋 해시
10. push 여부
11. git status -s 결과
12. 안전 확인
