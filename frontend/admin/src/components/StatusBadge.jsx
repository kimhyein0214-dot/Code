import React from 'react';

export function StatusBadge({ value }) {
  const text = value === undefined || value === null || value === '' ? 'unknown' : String(value);
  const normalized = text.toLowerCase().replace(/[^a-z0-9_-]+/g, '-');
  return <span className={`status-badge status-${normalized}`}>{text}</span>;
}

const CODE_SYSTEM_LABEL = {
  selfpia_sku: 'Selfpia SKU',
  selfpia_product: 'Selfpia Product',
  own_sku: 'Own SKU',
  own_product: 'Own Product',
  own_set: 'Own Set',
  smartstore_option_no: 'Smartstore Option',
  smartstore: 'Smartstore',
  makeshop: 'MakeShop',
  ably: 'Ably',
  playauto: 'Playauto'
};

export function CodeSystemBadge({ value }) {
  const raw = value === undefined || value === null || value === '' ? 'unknown' : String(value);
  const normalized = raw.toLowerCase().replace(/[^a-z0-9_-]+/g, '-');
  const label = CODE_SYSTEM_LABEL[raw] || raw;
  return <span className={`code-system-badge code-system-${normalized}`}>{label}</span>;
}
