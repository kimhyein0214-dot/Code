import React from 'react';

import { CopyButton } from './CopyButton.jsx';

const LABELS = {
  selfpia_sku_code: 'Sellpia SKU',
  selfpia_product_code: 'Sellpia 상품코드',
  virtual_sku_code: 'Virtual SKU',
  virtual_product_code: 'Virtual Product',
  own_sku_code: '자사코드',
  smartstore_option_no: 'Smartstore 옵션번호',
  smartstore_code: 'Smartstore',
  matched_code_value: 'Matched',
  sku_id: '내부 ID'
};

export function ProductMetaChips({ items = [] }) {
  const visibleItems = items.filter((item) => item?.value !== undefined && item?.value !== null && item?.value !== '');

  if (visibleItems.length === 0) {
    return null;
  }

  return (
    <div className="product-meta-chips">
      {visibleItems.map((item) => {
        const key = item.key || item.label || item.value;
        const label = item.label || LABELS[item.key] || item.key;
        return (
          <span className="product-meta-chip" key={`${key}-${item.value}`}>
            <span className="product-meta-label">{label}</span>
            <span className="product-meta-value mono" title={String(item.value)}>
              {item.value}
            </span>
            {item.copy !== false && <CopyButton value={item.value} label="복사" />}
          </span>
        );
      })}
    </div>
  );
}
