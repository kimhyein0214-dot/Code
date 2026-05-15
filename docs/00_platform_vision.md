# Platform Vision

## 원칙

통합 시스템은 모든 화면을 한 페이지에 합친다는 뜻이 아니다. 데이터 기준과 API, 인증, 권한, 감사 로그를 통합하되 화면과 코드는 업무별 모듈로 분리한다.

운영 플랫폼은 다음 6개 모듈로 구성한다.

1. 상품관리
2. 채널상품관리
3. 주문/피킹
4. 검품
5. CS/미송
6. 연동/설정

각 모듈은 독립된 화면, 독립된 frontend route, 독립된 server module을 가진다. 공유하는 것은 `product_code` master, `sku_id`, `code_alias`, API 인증/권한, audit log, 공통 UI 컴포넌트뿐이다.

## 금지

- 하나의 거대한 관리자 페이지로 만들지 않는다.
- 상품관리, 피킹, 검품, CS를 한 화면에 섞지 않는다.
- 하나의 `app.js`에 모든 기능을 넣지 않는다.
- DB 테이블을 업무 영역 없이 `public`에 몰아넣지 않는다.
- 클라이언트가 PostgreSQL에 직접 접속하지 않는다.
- master 데이터는 화면에서 즉시 수정하지 않고 change request 기반으로 변경한다.

## 사용자 표면

| 모듈 | 주 사용자 | 기기 |
|---|---|---|
| 상품관리 | 상품/운영 관리자 | PC |
| 채널상품관리 | 상품/채널 관리자 | PC |
| 주문/피킹 | 현장 피커 | 태블릿 |
| 검품 | 검품 담당자/관리자 | 태블릿/PC |
| CS/미송 | CS/운영 관리자 | PC |
| 연동/설정 | 관리자/운영자 | PC |

## 통합되는 것

- 모든 SKU 기준은 `product_code` master와 `sku_id`로 통일한다.
- 외부 코드와 내부 코드는 `code_alias`로 통일한다.
- 모든 화면은 API 서버만 호출한다.
- 모든 쓰기 작업은 actor, source, before/after, request id가 audit에 남는다.
- 권한은 모듈/행동 단위로 분리한다.

## 지금 만들 것

- 모듈별 route와 server module 경계
- read 중심 API skeleton
- master 직접 수정 금지 정책
- 주문/피킹, 검품, CS의 업무 경계
- 로컬 Docker DB 기반 검증 흐름

## 나중에 만들 것

- 실제 인증/JWT/session
- master change request 승인 workflow
- 채널별 연동 adapter
- 태블릿 offline queue
- NAS 운영 배포/백업/모니터링

