# Module Map

## 전체 모듈

| 모듈 | Frontend route | Server module | DB schema |
|---|---|---|---|
| 상품관리 | `/products/*` | `server/modules/product-management` | `product_code`, `audit` |
| 채널상품관리 | `/channels/*` | `server/modules/channel-management` | `product_code`, `integration`, `audit` |
| 주문/피킹 | `/picking/*` | `server/modules/picking` | `picking`, `product_code`, `audit` |
| 검품 | `/inspection/*` | `server/modules/inspection` | `inspection`, `picking`, `audit` |
| CS/미송 | `/cs/*` | `server/modules/cs` | `cs`, `picking`, `product_code`, `audit` |
| 연동/설정 | `/settings/*`, `/integrations/*` | `server/modules/integration-settings` | `integration`, `audit` |

`integration` schema는 필수 schema다. 연동 job, scraper state, external account, import/export file, bookmarklet client, sync run 로그를 이 schema에서 관리한다.

상세 설계는 `docs/12_integration_module_design.md`를 기준으로 한다.

## 공유 레이어

| 공유 요소 | 설명 |
|---|---|
| `product_code.sku_master` | 모든 업무가 참조하는 SKU 기준 |
| `product_code.code_alias` | selfpia, own_sku, channel code, seller code 연결 |
| API auth/permission | 모듈별 접근 통제 |
| audit log | 모든 쓰기 작업 이력 |
| 공통 UI 컴포넌트 | table, form, status badge, scanner input, modal |

## 연결 방식

- 모듈 간 직접 DB join을 화면에서 하지 않는다.
- 화면은 자기 모듈 API만 호출한다.
- 서버는 필요한 경우 내부 service에서 shared lookup을 호출한다.
- shared lookup은 `sku_id`, `selfpia_sku_code`, `code_alias` 기준으로 제공한다.

## 지금 만들 것

- 모듈별 URL과 server module 디렉터리 계획
- product_code lookup API
- picking read API와 mapping status API

## 나중에 만들 것

- role matrix
- module별 navigation shell
- inter-module event/audit feed
