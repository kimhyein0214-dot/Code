# Frontend Route Structure

## 원칙

프론트엔드는 업무별 route와 화면을 분리한다. 한 페이지짜리 거대 관리자 화면으로 만들지 않는다.

## Route 구조

```text
/
  products/
    index
    :skuId
    aliases
    change-requests
  channels/
    index
    :channelCode/products
    :channelCode/mappings
    review
  picking/
    index
    tasks
    tasks/:taskId
    shortage
  inspection/
    index
    queue
    items/:orderItemId
    history
  cs/
    index
    tickets
    tickets/:ticketId
    shortage
    templates
  integrations/
    index
    scraper
    memo-updater
    jobs
  settings/
    users
    permissions
    channels
```

## 화면별 기기

| Route | 기기 |
|---|---|
| `/products/*` | PC |
| `/channels/*` | PC |
| `/picking/*` | 태블릿 |
| `/inspection/queue`, `/inspection/items/*` | 태블릿 |
| `/inspection/history` | PC |
| `/cs/*` | PC |
| `/integrations/*`, `/settings/*` | PC |

## 공통 UI 컴포넌트

- App shell
- Module navigation
- Data table
- Filter/search bar
- Status badge
- Confirm modal
- Audit drawer
- SKU lookup picker
- Scanner input

공통 컴포넌트는 공유하되 업무 화면은 섞지 않는다.

## API 호출 원칙

- 화면은 PostgreSQL에 직접 접속하지 않는다.
- 화면은 자기 모듈 API를 우선 호출한다.
- shared product lookup은 공통 hook/service로 감싼다.

## 지금 만들 것

- route shell
- module별 navigation
- product lookup component
- picking tablet layout

## 나중에 만들 것

- 권한별 route guard
- offline queue indicator
- responsive audit drawer
- module별 dashboard

