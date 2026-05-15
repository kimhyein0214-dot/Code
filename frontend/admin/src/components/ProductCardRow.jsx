import React from 'react';
import { useNavigate } from 'react-router-dom';

import { ProductMetaChips } from './ProductMetaChips.jsx';
import { ProductThumbnail } from './ProductThumbnail.jsx';
import { StatusBadge } from './StatusBadge.jsx';

function firstAliasValue(aliases, codeSystem) {
  return aliases.find((alias) => alias.code_system === codeSystem)?.code_value || '';
}

function hasChannel(mappings, channelCode) {
  return mappings.some((mapping) => mapping.channel_code === channelCode);
}

function makeStatusItems(product, detail, detailLoading) {
  const aliases = detail?.aliases || [];
  const mappings = detail?.channel_mappings || [];
  const ownSkuCode = firstAliasValue(aliases, 'own_sku') || mappings.find((mapping) => mapping.own_sku_code)?.own_sku_code || '';
  const hasImage = Boolean(product.thumbnail_url || product.image_url);
  const makeshopConnected = hasChannel(mappings, 'makeshop');
  const smartstoreConnected =
    Boolean(firstAliasValue(aliases, 'smartstore_option_no')) || hasChannel(mappings, 'smartstore');
  const smartstoreCandidate = Boolean(firstAliasValue(aliases, 'smartstore_option_no_candidate'));

  const items = [
    {
      label: makeshopConnected ? 'MakeShop 연결됨' : 'MakeShop 미매핑',
      className: makeshopConnected ? 'status-connected' : 'status-unmapped'
    },
    {
      label: smartstoreConnected ? 'Smartstore 연결됨' : smartstoreCandidate ? 'Smartstore 후보' : 'Smartstore 미매핑',
      className: smartstoreConnected ? 'status-connected' : smartstoreCandidate ? 'status-candidate' : 'status-unmapped'
    },
    {
      label: hasImage ? '이미지 있음' : '이미지 없음',
      className: hasImage ? 'status-connected' : 'status-unmapped'
    },
    {
      label: ownSkuCode ? '자사코드 있음' : '자사코드 없음',
      className: ownSkuCode ? 'status-connected' : 'status-unmapped'
    }
  ];

  if (detailLoading) {
    return [
      {
        label: '연결 확인 중',
        className: 'status-candidate'
      },
      ...items.slice(2)
    ];
  }

  return items;
}

export function ProductCardRow({ product, detail, detailLoading = false, to }) {
  const navigate = useNavigate();
  const title = product.product_name || '상품명 없음';
  const option = product.option_value || '옵션 정보 없음';
  const href = to || `/products/${product.sku_id}`;
  const aliases = detail?.aliases || [];
  const mappings = detail?.channel_mappings || [];
  const ownSkuCode = firstAliasValue(aliases, 'own_sku') || mappings.find((mapping) => mapping.own_sku_code)?.own_sku_code || '';
  const statusItems = makeStatusItems(product, detail, detailLoading);

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
            { key: 'own_sku_code', value: ownSkuCode },
            { key: 'selfpia_product_code', value: product.selfpia_product_code },
            { key: 'virtual_sku_code', value: product.virtual_sku_code }
          ]}
        />
        <div className="product-card-status-strip" aria-label="판매처 연결 상태">
          {statusItems.map((item) => (
            <span className={`status-badge ${item.className}`} key={item.label}>
              {item.label}
            </span>
          ))}
        </div>
      </div>
      <div className="product-card-actions" aria-hidden="true">
        <span className="button-subtle detail-button">상세 보기</span>
      </div>
    </div>
  );
}
