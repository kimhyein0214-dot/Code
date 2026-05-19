# 셀피아 미연결 상품 삭제 검토 후보 CSV export 계획 v1

## 목적

`exports/unmatched_selfpia_product_review_candidates_v1.csv`는 대표님 요청에 따라 희진님이 엑셀에서 검토할 수 있도록 만든 **삭제 검토 후보 리스트**다.

이 CSV는 **삭제 확정 리스트가 아니며**, 어떤 행도 바로 삭제 또는 수정 대상으로 확정하지 않는다. 미연결 후보에는 과거 판매 이력이 있는 상품, 현재 미운영/비노출 상태인 상품, 판매처 원본자료가 아직 로컬 DB에 반영되지 않은 상품이 함께 섞일 수 있다.

## 실행 범위와 안전 기준

- 실행 DB: local Docker PostgreSQL `product_ops_test`
- 실행 파일: `sql/export_unmatched_selfpia_product_review_candidates_v1.sql`
- 출력 파일: `exports/unmatched_selfpia_product_review_candidates_v1.csv`
- 방식: `product_ops_test` guard 후 SELECT 기반 CSV export
- DB 변경: 없음
- 기존 confirmed/manual 매핑값 변경: 없음
- 운영 Supabase, NAS, 원격 DB 접속: 없음

## 후보 산정 기준

기본 후보는 셀피아 SKU 중 아래 조건을 모두 만족하는 행이다.

- Smartstore 확정 연결이 없음
- MakeShop `sku_channel_mapping` 연결이 없음
- 셀피아 SKU 코드가 존재함

Smartstore candidate alias만 있는 경우는 확정 연결로 보지 않고 `candidate_only_not_confirmed`로 표시한다. Smartstore 또는 MakeShop 중 하나라도 확정 연결이 있는 SKU는 삭제 검토 후보에서 제외한다.

## 우선순위 기준

| 검토우선순위 | 기준 |
| --- | --- |
| `P1_높음` | Smartstore/MakeShop 연결이 모두 없고, 자사코드가 없거나 둘 이상으로 불명확함 |
| `P2_중간` | Smartstore/MakeShop 연결이 모두 없고, 이미지는 없음 |
| `P3_낮음` | Smartstore/MakeShop 연결은 모두 없지만 자사코드와 이미지가 확인됨 |

`channel_absent_or_inactive_possible`은 삭제 확정 사유가 아니라, 판매처 연결 부재 또는 미운영 가능성을 별도로 확인해야 한다는 검토 사유다.

## Ably/PlayAuto 처리

Ably/PlayAuto는 이번 CSV에서 최종 미매칭 판단 근거로 사용하지 않는다. 해당 원본 stage import가 최종 판단에 반영된 상태가 아니므로 모든 후보 행의 `에이블리_플레이오토상태`는 `source_not_loaded`로 표시한다.

## CSV 컬럼

| 컬럼 | 의미 |
| --- | --- |
| 검토우선순위 | 삭제 검토 우선순위 |
| 셀피아상품코드 | 셀피아 상품 코드 |
| 셀피아SKU코드 | 셀피아 SKU 코드 |
| 상품ID | local DB 상품 UUID |
| SKUID | local DB SKU UUID |
| 상품명 | 상품명 |
| 옵션명 | 엑셀 검토용 옵션명 |
| 옵션값 | SKU 옵션값 |
| 자사코드 | `own_sku` alias |
| 스마트스토어연결상태 | Smartstore 확정 또는 후보 상태 |
| 메이크샵연결상태 | MakeShop mapping 상태 |
| 에이블리_플레이오토상태 | `source_not_loaded` |
| 이미지연결상태 | 이미지 있음/없음 |
| 미연결사유 | 후보 분류 사유 |
| 주의메모 | 삭제 확정 금지 및 해석 주의 문구 |
| 삭제검토결과 | 희진님 검토 입력 칸 |
| 검토자메모 | 희진님 메모 입력 칸 |

## 희진님 검토 방식

`삭제검토결과`에는 아래 값 중 하나를 입력하는 방식으로 검토한다.

- `삭제검토`
- `유지`
- `보류`
- `판매처확인필요`
- `코드확인필요`

권장 흐름:

1. `P1_높음`부터 검토한다.
2. `자사코드`가 비어 있거나 여러 개인 행은 코드 기준을 먼저 확인한다.
3. `이미지연결상태=missing_image` 행은 이미지 자료 미반영 가능성을 먼저 확인한다.
4. `스마트스토어연결상태=candidate_only_not_confirmed` 행은 기존 후보 alias가 실제 판매처 연결인지 확인한다.
5. 최종 판단이 어려운 행은 `보류`, `판매처확인필요`, `코드확인필요` 중 하나로 남긴다.

## 산출물 관리

- SQL과 문서는 git commit/push 대상이다.
- CSV는 대표님/희진님 전달용 산출물이므로 생성만 하고 git add하지 않는다.
- `exports/` 디렉터리는 git add하지 않는다.

## 엑셀 자동 변환 방지

엑셀에서 `2234-07-01` 같은 셀피아 SKU 코드가 날짜로 자동 변환되는 것을 막기 위해 아래 컬럼은 엑셀-safe 텍스트 형태로 export한다.

- `셀피아상품코드`
- `셀피아SKU코드`
- `자사코드`

엑셀 화면에서는 원래 코드값처럼 보이지만, CSV 원문에는 `="코드값"` 형태로 저장된다. 검토자는 해당 컬럼을 날짜/숫자로 다시 변환하지 말고 텍스트 코드로 취급한다.
