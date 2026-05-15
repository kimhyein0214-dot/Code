import React from 'react';

export function StatusBadge({ value }) {
  const text = value === undefined || value === null || value === '' ? 'unknown' : String(value);
  const normalized = text.toLowerCase().replace(/[^a-z0-9_-]+/g, '-');
  return <span className={`status-badge status-${normalized}`}>{text}</span>;
}

const CODE_SYSTEM_LABEL = {
  selfpia_sku: 'Sellpia SKU',
  selfpia_product: 'Sellpia 상품코드',
  own_sku: '자사코드',
  own_product: '자사 상품코드',
  own_set: '자사 세트코드',
  smartstore_option_no: 'Smartstore 옵션번호',
  smartstore_option_no_candidate: 'Smartstore 후보',
  smartstore_product_no: 'Smartstore 상품번호',
  smartstore_product_no_candidate: 'Smartstore 상품 후보',
  smartstore: 'Smartstore',
  makeshop: 'MakeShop',
  makeshop_sku: 'MakeShop SKU',
  makeshop_channel_code: 'MakeShop 코드',
  channel_code: '채널 코드',
  sku: 'SKU 검색',
  alias: 'Alias',
  all_codes: '통합 검색',
  ably: 'Ably',
  playauto: 'Playauto'
};

export function CodeSystemBadge({ value }) {
  const raw = value === undefined || value === null || value === '' ? 'unknown' : String(value);
  const normalized = raw.toLowerCase().replace(/[^a-z0-9_-]+/g, '-');
  const label = CODE_SYSTEM_LABEL[raw] || raw;
  return <span className={`code-system-badge code-system-${normalized}`}>{label}</span>;
}
