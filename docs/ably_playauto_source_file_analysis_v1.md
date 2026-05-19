# Ably / PlayAuto Source File Analysis v1

## Purpose

This document records a read-only analysis of the two source files prepared for the Ably / PlayAuto matching workflow.

No source file was modified. No database import, export, DDL, apply SQL, Supabase connection, NAS connection, or remote DB connection was used.

## Source Files

| source | format | encoding / sheet | rows | columns | role |
|---|---|---|---:|---:|---|
| `에이블리 ALL.csv` | CSV | UTF-8 BOM | 9,158 | 29 | Ably product-option rows |
| `플레이오토_일반_ALL판매처 (판매중,수정대기,판매대기 ALL).xlsx` | XLSX | 7 sheets | see below | see below | PlayAuto multi-marketplace management workbook |

## Ably CSV Structure

Columns:

`상품 번호`, `판매자 상품코드`, `상품명`, `브랜드`, `에이블리 판매가`, `에이블리 할인 판매가`, `에이블리 최종 판매가(앱)`, `4910 판매가`, `4910 할인 판매가`, `4910 현재 판매가`, `옵션 번호`, `솔루션사 고유코드`, `옵션1`, `옵션2`, `전체 옵션명`, `재고수량`, `안전재고`, `재고 소진시 판매 방식`, `품절상태`, `진열상태`, `카테고리`, `상품등록일`, `배송 타입`, `택배사`, `반품 배송비(편도)`, `도서산간추가배송비(편도)`, `성별`, `병행수입 여부`, `주문제작 여부`

Key column profile:

| column | nonblank | distinct nonblank | blank/dash | matching use |
|---|---:|---:|---:|---|
| `상품 번호` | 9,158 | 956 | 0 | channel product code candidate |
| `옵션 번호` | 9,158 | 9,158 | 0 | strongest channel option code candidate |
| `판매자 상품코드` | 8,399 | 939 | 759 | seller/product-level code candidate, not SKU-safe alone |
| `솔루션사 고유코드` | 4,725 | 4,691 | 4,433 | own_sku/selfpia_sku candidate if verified |
| `상품명` | 9,158 | 956 | 0 | support evidence only |
| `옵션1` | 9,158 | 6,842 | 0 | option evidence and bracket-code source |
| `옵션2` | 9,158 | 250 | 0 | option evidence |
| `전체 옵션명` | 9,158 | 9,096 | 0 | option evidence and bracket-code source |
| `재고수량` | 9,158 | 95 | 0 | status/inventory evidence |
| `품절상태` | 9,158 | 2 | 0 | inactive / active classification |
| `진열상태` | 9,158 | 2 | 0 | channel presence classification |

Product-option relation:

| metric | value |
|---|---:|
| products by `상품 번호` | 956 |
| products with 1 option | 102 |
| products with 2+ options | 854 |
| max options per product | 584 |

Status distribution:

| column | value | rows |
|---|---|---:|
| `품절상태` | `품절아님` | 6,263 |
| `품절상태` | `품절` | 2,895 |
| `진열상태` | `진열` | 6,732 |
| `진열상태` | `미진열` | 2,426 |
| `배송 타입` | `일반배송` | 8,476 |
| `배송 타입` | `오늘출발` | 682 |
| `병행수입 여부` | `N` | 9,158 |
| `주문제작 여부` | `N` | 9,158 |

Bracket-code evidence:

- option text contains `18,838` bracket-code mentions
- distinct bracket codes: `5,967`
- frequent examples include `PT-25-01` through `PT-25-08` and `EE-*` patterns
- these are useful own_sku/selfpia_sku candidates, but repeated product-family patterns mean they must be uniqueness-checked before auto confirmation

## PlayAuto XLSX Structure

Sheets:

| sheet | rows | columns | role |
|---|---:|---:|---|
| `쇼핑몰상품` | 4,219 | 95 | main marketplace product rows |
| `쇼핑몰(ID)` | 7 | 2 | marketplace ID / alias reference |
| `SKU상품` | 17,968 | 4 | PlayAuto SKU master-like list |
| `템플릿` | 12 | 4 | upload template codes |
| `카테고리` | 23 | 3 | category code reference |
| `인증정보 코드표` | 49 | 2 | certification code reference |
| `원산지표` | 511 | 1 | origin reference |

Main `쇼핑몰상품` columns include:

`판매자관리코드`, `카테고리코드(마스터에서 수정)`, `쇼핑몰(계정)`, `템플릿코드`, `온라인 상품명`, `쇼핑몰 상품번호`, `상품상태(수정불가)`, `판매수량`, `판매가`, `공급가`, `원가`, `시중가`, `옵션조합`, `옵션`, `SKU`, `배송처코드`, `옵션 추가금액`, `옵션 판매수량`, `출고수량`, `옵션 무게(kg)`, `옵션 상태`, image fields, detail fields, model/brand/manufacturer fields, keyword/certification fields, and 24 `상품정보제공고시` fields.

Main key column profile:

| column | nonblank | distinct nonblank | blank/dash | matching use |
|---|---:|---:|---:|---|
| `판매자관리코드` | 4,219 | 2,040 | 0 | PlayAuto internal seller management code |
| `쇼핑몰(계정)` | 4,219 | 4 | 0 | actual marketplace/account classifier |
| `온라인 상품명` | 4,219 | 2,959 | 0 | support evidence only |
| `쇼핑몰 상품번호` | 2,945 | 2,945 | 1,274 | marketplace product code candidate |
| `상품상태(수정불가)` | 4,219 | 6 | 0 | active/inactive status |
| `옵션조합` | 4,219 | 1 | 0 | option mode, not a key |
| `옵션` | 4,219 | 3,052 | 0 | multi-line option names |
| `SKU` | 4,207 | 2,112 | 12 | multi-line PlayAuto SKU codes |
| `옵션 상태` | 4,219 | 143 | 0 | multi-line option active flags |

`SKU상품` sheet profile:

| column | nonblank | distinct nonblank | blank/dash |
|---|---:|---:|---:|
| `SKU코드` | 17,968 | 17,968 | 0 |
| `SKU명` | 17,968 | 2,123 | 0 |
| `속성` | 17,964 | 17,201 | 4 |
| `배송처코드` | 17,968 | 1 | 0 |

## PlayAuto Marketplace Distribution

`쇼핑몰(계정)` shows that PlayAuto is not a single sales channel. It is a management workbook containing several marketplace/account rows.

| 쇼핑몰(계정) | product rows |
|---|---:|
| `스마트스토어=w_ground` | 2,039 |
| `에이블리=pink_rocket@naver.com` | 2,016 |
| `쿠팡=wworks2010` | 161 |
| `카카오톡 스토어=pink_rocket@naver.com` | 3 |

By account and product status:

| 쇼핑몰(계정) | 상품상태 | rows |
|---|---|---:|
| `스마트스토어=w_ground` | `판매중` | 1,822 |
| `스마트스토어=w_ground` | `수정대기` | 109 |
| `스마트스토어=w_ground` | `판매대기` | 108 |
| `에이블리=pink_rocket@naver.com` | `판매대기` | 1,139 |
| `에이블리=pink_rocket@naver.com` | `판매중` | 795 |
| `에이블리=pink_rocket@naver.com` | `수정대기` | 82 |
| `쿠팡=wworks2010` | `판매중` | 84 |
| `쿠팡=wworks2010` | `수정대기` | 36 |
| `쿠팡=wworks2010` | `판매대기` | 27 |
| `쿠팡=wworks2010` | `승인대기` | 7 |
| `쿠팡=wworks2010` | `일시품절` | 5 |
| `쿠팡=wworks2010` | `판매중지` | 2 |
| `카카오톡 스토어=pink_rocket@naver.com` | `수정대기` | 3 |

Overall `상품상태(수정불가)` distribution:

| value | rows |
|---|---:|
| `판매중` | 2,701 |
| `판매대기` | 1,274 |
| `수정대기` | 230 |
| `승인대기` | 7 |
| `일시품절` | 5 |
| `판매중지` | 2 |

## PlayAuto Multi-Line Option Structure

Many `쇼핑몰상품` rows contain option/SKU arrays inside a single cell. These must be exploded into option-level stage rows before matching.

| column | rows with line breaks | max lines in one cell |
|---|---:|---:|
| `옵션` | 4,219 | 466 |
| `SKU` | 3,761 | 465 |
| `옵션 추가금액` | 3,770 | 465 |
| `옵션 판매수량` | 3,770 | 465 |
| `출고수량` | 3,761 | 465 |
| `옵션 상태` | 3,770 | 465 |
| `추가구매 옵션 추가금액` | 7 | 4 |
| `추가구매 옵션 판매수량` | 7 | 4 |
| `추가구매 옵션 상태` | 7 | 4 |

The `옵션` line count is consistently one greater than `SKU` / option quantity / option status counts in inspected rows. This suggests `옵션` may include an option header or grouping line. Import dryrun must validate row-level line alignment before creating option-level evidence.

Account-level line count summary:

| 쇼핑몰(계정) | product rows | SKU lines | option lines | option status lines |
|---|---:|---:|---:|---:|
| `스마트스토어=w_ground` | 2,039 | 16,096 | 18,135 | 16,096 |
| `에이블리=pink_rocket@naver.com` | 2,016 | 14,686 | 16,732 | 14,716 |
| `쿠팡=wworks2010` | 161 | 1,283 | 1,444 | 1,283 |
| `카카오톡 스토어=pink_rocket@naver.com` | 3 | 18 | 21 | 18 |

## Ably Source vs PlayAuto Ably Rows

PlayAuto includes `에이블리=pink_rocket@naver.com` rows, but it is not a complete substitute for the Ably CSV.

| account | PlayAuto distinct `쇼핑몰 상품번호` | overlap with Ably `상품 번호` | note |
|---|---:|---:|---|
| `에이블리=pink_rocket@naver.com` | 877 | 875 | strong product-code relationship |
| `스마트스토어=w_ground` | 1,931 | 0 | separate marketplace |
| `쿠팡=wworks2010` | 134 | 0 | separate marketplace |
| `카카오톡 스토어=pink_rocket@naver.com` | 3 | 0 | separate marketplace |

The Ably CSV has `956` distinct `상품 번호`; PlayAuto Ably rows expose `877` distinct nonblank marketplace product numbers, with `875` overlapping. That means the two files are related, but the Ably CSV remains the stronger source for Ably option-level channel codes because `옵션 번호` is present and unique for all 9,158 rows.

## Automatic Matching Key Candidates

Ably:

| priority | source key | target interpretation | caution |
|---|---|---|---|
| P1 | `옵션 번호` | `channel_option_code` for `channel_code='ably'` | unique in file, but needs SKU link evidence |
| P1 | `상품 번호` + `옵션 번호` | channel product-option identity | do not collapse product and option code |
| P2 | `솔루션사 고유코드` | own_sku or selfpia_sku candidate | only 4,725 rows nonblank |
| P2 | bracket codes in `옵션1` / `전체 옵션명` | own_sku or selfpia_sku candidate | repeated product-family patterns require uniqueness checks |
| P3 | `판매자 상품코드` | seller product code / product-level own code candidate | product-level, not SKU-safe alone |
| support | `상품명`, `옵션1`, `옵션2`, `전체 옵션명` | product/option text support | never auto-confirm from names alone |

PlayAuto:

| priority | source key | target interpretation | caution |
|---|---|---|---|
| P0 | `쇼핑몰(계정)` | marketplace account classifier | must map to real channel before matching |
| P1 | `SKU` exploded lines | own_sku / selfpia_sku / PlayAuto SKU candidate | multi-line parse and `SKU상품` validation required |
| P1 | `판매자관리코드` | PlayAuto internal product/seller management code | unique per account row, not automatically a SKU |
| P2 | `쇼핑몰 상품번호` | marketplace product code | blank for 1,274 rows, especially pending rows |
| P2 | `SKU상품.SKU코드` | SKU code dictionary | likely validates `쇼핑몰상품.SKU` line values |
| support | `온라인 상품명`, `옵션`, `SKU상품.SKU명`, `SKU상품.속성` | text support | do not auto-confirm from names alone |

## Risky Or Ambiguous Columns

- Ably `판매자 상품코드`: 939 distinct values over 9,158 rows, likely product-level.
- Ably `솔루션사 고유코드`: sparse and not yet proven as selfpia_sku or own_sku.
- Ably bracket codes: numerous and useful, but duplicate families such as `PT-25-*` repeat heavily.
- PlayAuto `쇼핑몰(계정)`: must drive channel classification; `playauto` should not be used as a final marketplace channel code.
- PlayAuto `옵션`: line count does not align directly with `SKU`; likely includes a header/group label.
- PlayAuto `옵션 상태`: stored as multi-line `Y`/`N` arrays, not one row-level status.
- PlayAuto `판매대기`, `수정대기`, `승인대기`, `일시품절`, `판매중지`: these should classify channel presence/inactive evidence, not true unmatched SKUs.

## Feasibility Summary

Automatic candidate generation becomes feasible after a stage import dryrun, because both files contain code evidence that is absent from the current local DB:

- Ably can provide channel product/option codes directly.
- PlayAuto can classify marketplace account rows and validate Ably/Smartstore/Coupang/Kakao product evidence.
- Direct auto-confirm should be limited to rows where source code evidence joins uniquely to `selfpia_sku` or `own_sku`, with product/option text support and no inactive/status blockers.
- Rows without active marketplace presence should be separated as `channel_absent_or_inactive`, not counted as true matching failures.
