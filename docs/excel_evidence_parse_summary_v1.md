# Excel Evidence Parse Summary v1

## Scope

This is a read-only parsing summary for three Excel evidence files:

- `가격 수정 리스트 - 수정하였습니다.xlsx`
- `플레이오토 스스_옵션_변경양식.xlsx`
- `플레이오토 스스_일반_변경양식.xlsx`

The files were read with Python/openpyxl in read-only mode. No source workbook was modified or added to git. No CSV, JSON, XLSX, output, export, backup, stage table, import, SQL execution, or DB connection was created.

The counts below estimate matching potential only. They do not confirm candidates, do not change `export_allowed`, and do not change reviewer decisions.

## 1. Price Update List Workbook

File: `가격 수정 리스트 - 수정하였습니다.xlsx`

Sheets:

- `셀피아`
- `메이크샵`
- `스마트스토어`
- `플레이오토`
- `에이블리`
- `DB_0`
- `DB_1`
- `DB_2`
- `DB_3`
- `DB_4`

Sheet row counts, excluding interpreted header rows:

| Sheet | Non-empty rows |
| --- | ---: |
| `셀피아` | 4 |
| `메이크샵` | 4 |
| `스마트스토어` | 1 |
| `플레이오토` | 1 |
| `에이블리` | 1 |
| `DB_0` | 2,777 |
| `DB_1` | 2,780 |
| `DB_2` | 2,780 |
| `DB_3` | 2,781 |
| `DB_4` | 2,780 |

Parsing counts:

| Metric | Count |
| --- | ---: |
| Selfpia SKU-like rows | 13,902 |
| Smartstore code-like rows | 2,785 |
| MakeShop code-like rows | 5,562 |
| PlayAuto code-like rows | 5,562 |
| Ably code-like rows | 5,555 |
| Option-text bracket own_sku candidate rows | 10,754 |

Expression counts:

| Expression | Count |
| --- | ---: |
| `핑크골드` | 2,533 |
| `로즈골드` | 2,384 |
| `핑골` | 987 |
| `골드` | 10,611 |
| `옐로우골드` | 811 |
| `크리스탈` | 384 |
| `크리스탈AB` | 88 |
| `AB` token warning | 4 |
| `주문제작` | 566 |
| `원타입` | 56 |
| `세트` | 0 |
| `한쌍` | 0 |
| `낱개` | 1,003 |

Interpretation:

- `DB_0~DB_4` provide broad cross-channel code evidence.
- Bracket own_sku extraction appears highly useful.
- `핑크골드`/`로즈골드`/`핑골` and `골드`/`옐로우골드` should remain normalization evidence, not standalone confirmation.
- `크리스탈AB` and token `AB` require safety flags.

## 2. PlayAuto Smartstore Option Workbook

File: `플레이오토 스스_옵션_변경양식.xlsx`

Sheets:

- `옵션기본`
- `추천옵션-스마트스토어_w_ground`

`옵션기본` parsing counts:

| Metric | Count |
| --- | ---: |
| Option-basic rows | 762 |
| Option SKU code exists | 762 |
| Extractable `sellpia_상품코드-옵션번호` | 762 |
| Smartstore `쇼핑몰상품코드` exists | 762 |
| `옵션1 값` exists | 762 |
| Bracket own_sku extractable from `옵션1 값` | 299 |
| selfpia_sku + Smartstore productNo + option text all present in one row | 762 |
| Duplicate selfpia_sku count | 0 |
| Duplicate Smartstore productNo + option text count | 0 |

Expression counts:

| Expression | Count |
| --- | ---: |
| `핑크골드` | 8 |
| `로즈골드` | 131 |
| `핑골` | 0 |
| `골드` | 271 |
| `옐로우골드` | 10 |
| `크리스탈` | 11 |
| `크리스탈AB` | 3 |
| `AB` token warning | 0 |
| `주문제작` | 0 |
| `원타입` | 21 |
| `세트` | 33 |
| `한쌍` | 0 |
| `낱개` | 3 |

Interpretation:

- This workbook is the strongest Smartstore option-level evidence source.
- Every parsed option row has selfpia SKU, Smartstore productNo, and option text in the same row.
- No duplicate selfpia SKU or duplicate productNo + option text combination was found in this read-only pass.
- only 299 of 762 rows have bracket own_sku in `옵션1 값`; missing own_sku should remain review evidence, not auto-confirm evidence.

## 3. PlayAuto Smartstore General Workbook

File: `플레이오토 스스_일반_변경양식.xlsx`

Sheets:

- `쇼핑몰상품`
- `쇼핑몰(ID)`
- `SKU상품`
- `템플릿`
- `카테고리`
- `인증정보 코드표`
- `원산지표`

Parsing counts:

| Metric | Count |
| --- | ---: |
| `쇼핑몰상품` rows | 500 |
| `SKU상품` rows | 17,968 |
| `쇼핑몰상품.판매자관리코드` exists | 500 |
| `쇼핑몰상품.쇼핑몰 상품번호` exists | 500 |
| Multi-line option product rows | 438 |
| Multi-line SKU product rows | 438 |
| Option/SKU line count matched product rows | 500 |
| Option/SKU line count mismatched product rows | 0 |
| `SKU상품.SKU코드` extractable | 17,968 |
| `SKU상품.속성` bracket own_sku extractable | 17,104 |

Expression counts:

| Expression | Count |
| --- | ---: |
| `핑크골드` | 2,587 |
| `로즈골드` | 673 |
| `핑골` | 268 |
| `골드` | 6,887 |
| `옐로우골드` | 123 |
| `크리스탈` | 906 |
| `크리스탈AB` | 177 |
| `AB` token warning | 106 |
| `주문제작` | 50 |
| `원타입` | 242 |
| `세트` | 442 |
| `한쌍` | 36 |
| `낱개` | 310 |

Interpretation:

- `쇼핑몰상품` has complete seller code and Smartstore productNo coverage in this pass.
- Option/SKU line counts matched for all 500 product rows, so the multi-line structure is usable as evidence.
- `SKU상품` is a strong SKU/attribute dictionary: all 17,968 rows had extractable sellpia SKU codes, and 17,104 rows had bracket own_sku candidates.
- Safety flags are substantial because `크리스탈AB`, `AB`, `세트`, `한쌍`, and `낱개` appear often.

## 4. Overall Possibility Estimate

This classification is a parsing-only possibility estimate. It is not confirmation.

Heuristic used:

- `auto_confirm_ready_like`: rows/groups with complete key evidence and no duplicate key hit in this pass, excluding selected high-risk tokens.
- `strong_candidate`: complete key evidence exists, but extra validation or safety review is still needed.
- `manual_review_required`: missing required key evidence or line-count mismatch in this parsing pass.
- `parse_warning`: rows or occurrences that should trigger parsing/safety warnings, including bracket-heavy evidence and high-risk option tokens.

| Class | Estimated count |
| --- | ---: |
| `auto_confirm_ready_like` | 976 |
| `strong_candidate` | 286 |
| `manual_review_required` | 0 |
| `parse_warning` | 11,040 |

Important caution:

- `manual_review_required=0` here does not mean no manual review remains. It only means the narrow parsing pass did not find missing required keys or multi-line line-count mismatches in the two PlayAuto Smartstore workbooks.
- The high `parse_warning` count means the next step must keep safety gates for own_sku ambiguity, product name conflict, option normalization conflict, `크리스탈`/`크리스탈AB`, `AB`, `화이트골드`/`실버`, quantity/unit terms, and set/single-unit terms.

## 5. Normalization Notes

Observed color/material/quantity expressions:

- `핑골`: present in price workbook and general workbook.
- `로즈골드`: present in all three workbooks.
- `옐로우골드`: present in all three workbooks.
- `크리스탈`: present in all three workbooks.
- `크리스탈AB`: present in all three workbooks.
- `AB` token warning: present in price and general workbooks.
- `주문제작`: present in price and general workbooks.
- `원타입`: present in all three workbooks.
- `세트`/`한쌍`/`낱개`: present mainly in option/general workbooks, with `낱개` also present in the price workbook.

Recommended treatment:

- `핑크골드`, `로즈골드`, `핑골`, `RG` can be one rose-gold color family for candidate comparison.
- `골드`, `옐로우골드`, `YG` can be one yellow-gold color family for candidate comparison.
- `크리스탈` and `크리스탈AB` must not be auto-normalized together.
- `AB` should be token-matched only.
- `14K`, `써지컬`, and `925실버` should be material attributes, not color matches.
- `주문제작`, bar length, `원타입`, `세트`, `한쌍`, `낱개`, and quantity expressions should be separate safety attributes.

## 6. Safe Next Step

The evidence suggests that PlayAuto Smartstore workbooks can reduce Smartstore manual matching materially, especially where `sellpia_sku + Smartstore productNo + option text` are present together. Before connecting this to any auto-confirm-ready SQL, add a read-only validation layer that checks DB selfpia/own_sku joins, product name support, normalized option 1:1 uniqueness, and safety-token blockers.
