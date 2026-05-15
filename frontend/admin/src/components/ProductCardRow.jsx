import React from 'react';
import { useNavigate } from 'react-router-dom';

import { ProductMetaChips } from './ProductMetaChips.jsx';
import { ProductThumbnail } from './ProductThumbnail.jsx';
import { StatusBadge } from './StatusBadge.jsx';

export function ProductCardRow({ product, to }) {
  const navigate = useNavigate();
  const title = product.product_name || '상품명 없음';
  const option = product.option_value || '옵션 정보 없음';
  const href = to || `/products/${product.sku_id}`;

  function openDetail() {
    navigate(href);
  }

  function onKeyDown(event) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      openDetail();
    }
  }

  return (
    <div
      className="product-card-row"
      role="link"
      tabIndex={0}
      onClick={openDetail}
      onKeyDown={onKeyDown}
    >
      <ProductThumbnail
        src={product.thumbnail_url || product.image_url}
        alt={title}
        size="md"
      />
      <div className="product-card-main">
        <div className="product-card-heading">
          <div className="product-card-title-wrap">
            <strong className="product-card-title" title={title}>{title}</strong>
            <span className="product-card-option" title={option}>{option}</span>
          </div>
          <StatusBadge value={product.sku_status} />
        </div>
        <ProductMetaChips
          items={[
            { key: 'selfpia_sku_code', value: product.selfpia_sku_code },
            { key: 'virtual_sku_code', value: product.virtual_sku_code }
          ]}
        />
      </div>
      <div className="product-card-actions" aria-hidden="true">
        <span className="button-subtle detail-button">상세 보기</span>
      </div>
    </div>
  );
}
