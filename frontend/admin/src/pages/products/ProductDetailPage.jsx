import React, { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';

import { productsApi } from '../../api/client.js';
import { CodeSystemBadge, StatusBadge } from '../../components/StatusBadge.jsx';
import { CopyButton } from '../../components/CopyButton.jsx';
import { ProductMetaChips } from '../../components/ProductMetaChips.jsx';
import { ProductThumbnail } from '../../components/ProductThumbnail.jsx';

function uniqueValues(values) {
  return [...new Set(values.filter((value) => value !== undefined && value !== null && value !== ''))];
}

function aliasValues(aliases, codeSystem) {
  return uniqueValues(
    aliases
      .filter((alias) => alias.code_system === codeSystem)
      .map((alias) => alias.code_value)
  );
}

function smartstoreChannelCodes(mappings) {
  return uniqueValues(
    mappings
      .filter((mapping) => mapping.channel_code === 'smartstore')
      .flatMap((mapping) => [mapping.channel_sku_code, mapping.seller_product_code])
  );
}

function channelLabel(channelCode) {
  const labels = {
    makeshop: 'MakeShop',
    smartstore: 'Smartstore',
    ably: 'Ably',
    playauto: 'Playauto'
  };
  return labels[channelCode] || channelCode;
}

function CodeValue({ value, muted = false }) {
  if (!value) {
    return <span className="muted">없음</span>;
  }

  return (
    <div className="cell-code">
      <span className={`mono ellipsis${muted ? ' muted' : ''}`} title={String(value)}>{value}</span>
      <CopyButton value={value} label="복사" />
    </div>
  );
}

function MappingStatus({ status }) {
  const className = {
    기준: 'status-reference',
    연결됨: 'status-connected',
    후보: 'status-candidate',
    미매핑: 'status-unmapped',
    확인필요: 'status-needs-review'
  }[status] || '';
  return <span className={`status-badge ${className}`}>{status}</span>;
}

function buildCodeSummaryRows({
  sku,
  mappings,
  ownSkuCodes,
  smartstoreProductCodes,
  smartstoreProductCandidateCodes,
  smartstoreAliasCodes,
  smartstoreCandidateCodes
}) {
  const rows = [
    {
      key: 'selfpia',
      group: '기준',
      seller: 'Sellpia',
      productCode: sku.selfpia_product_code,
      optionCode: sku.selfpia_sku_code,
      ownSkuCode: ownSkuCodes[0],
      status: '기준',
      note: 'Product_code 기준 SKU'
    }
  ];

  mappings
    .filter((mapping) => mapping.channel_code !== 'smartstore')
    .forEach((mapping) => {
      rows.push({
        key: `channel-${mapping.id}`,
        group: '채널',
        seller: channelLabel(mapping.channel_code),
        productCode: mapping.seller_product_code,
        optionCode: mapping.channel_sku_code,
        ownSkuCode: mapping.own_sku_code,
        status: '연결됨',
        note: mapping.is_primary ? 'primary mapping' : 'channel mapping'
      });
    });

  const smartstoreMappings = mappings.filter((mapping) => mapping.channel_code === 'smartstore');
  if (smartstoreMappings.length > 0) {
    smartstoreMappings.forEach((mapping, index) => {
      rows.push({
        key: `smartstore-${mapping.id || index}`,
        group: '채널',
        seller: 'Smartstore',
        productCode: mapping.seller_product_code || smartstoreProductCodes[index] || smartstoreProductCodes[0],
        optionCode: mapping.channel_sku_code || smartstoreAliasCodes[index] || smartstoreAliasCodes[0],
        ownSkuCode: mapping.own_sku_code || ownSkuCodes[0],
        status: '연결됨',
        note: 'smartstore channel mapping'
      });
    });
  } else if (smartstoreAliasCodes.length > 0) {
    rows.push({
      key: 'smartstore-alias',
      group: '채널',
      seller: 'Smartstore',
      productCode: smartstoreProductCodes.join(', '),
      optionCode: smartstoreAliasCodes.join(', '),
      ownSkuCode: ownSkuCodes[0],
      status: '연결됨',
      note: 'confirmed smartstore_product_no / smartstore_option_no alias'
    });
  } else if (smartstoreCandidateCodes.length > 0 || smartstoreProductCandidateCodes.length > 0) {
    rows.push({
      key: 'smartstore-candidate',
      group: '후보',
      seller: 'Smartstore',
      productCode: smartstoreProductCandidateCodes.join(', '),
      optionCode: smartstoreCandidateCodes.join(', '),
      ownSkuCode: ownSkuCodes[0],
      status: '후보',
      note: '자동 후보 / 운영 미확정'
    });
  } else {
    rows.push({
      key: 'smartstore-unmapped',
      group: '채널',
      seller: 'Smartstore',
      productCode: '',
      optionCode: '',
      ownSkuCode: ownSkuCodes[0],
      status: '미매핑',
      note: 'smartstore_product_no / smartstore_option_no alias 또는 channel mapping 없음'
    });
  }

  if (
    (smartstoreMappings.length > 0 || smartstoreAliasCodes.length > 0 || smartstoreProductCodes.length > 0) &&
    (smartstoreCandidateCodes.length > 0 || smartstoreProductCandidateCodes.length > 0)
  ) {
    rows.push({
      key: 'smartstore-candidate-reference',
      group: '후보',
      seller: 'Smartstore',
      productCode: smartstoreProductCandidateCodes.join(', '),
      optionCode: smartstoreCandidateCodes.join(', '),
      ownSkuCode: ownSkuCodes[0],
      status: '후보',
      note: 'confirmed 값 우선, 후보는 참고용'
    });
  }

  return rows;
}

function buildConnectionSummary({
  sku,
  mappings,
  ownSkuCodes,
  codeSummaryRows,
  smartstoreAliasCodes,
  smartstoreProductCandidateCodes,
  smartstoreCandidateCodes
}) {
  const connectedChannels = mappings
    .filter((mapping) => mapping.channel_code)
    .reduce((acc, mapping) => {
      const label = channelLabel(mapping.channel_code);
      acc.set(label, (acc.get(label) || 0) + 1);
      return acc;
    }, new Map());

  // sku_channel_mapping 에 smartstore 가 없어도 code_alias 의
  // smartstore_option_no (confirmed) 가 있으면 연결 채널로 인정.
  // 중복 카운트 방지: mappings 에 이미 smartstore 가 있으면 alias 는 무시.
  const hasSmartstoreMapping = mappings.some((mapping) => mapping.channel_code === 'smartstore');
  if (!hasSmartstoreMapping && smartstoreAliasCodes.length > 0) {
    connectedChannels.set('Smartstore', smartstoreAliasCodes.length);
  }

  const connectedText = [...connectedChannels.entries()]
    .map(([label, count]) => `${label} ${count}개`)
    .join(', ');

  // candidate 는 확정 연결로 표기하지 않고 별도 "연결 후보" 라인에 분리.
  const candidateCount = uniqueValues([...smartstoreProductCandidateCodes, ...smartstoreCandidateCodes]).length;
  const candidateText = candidateCount > 0
    ? `Smartstore 후보 ${candidateCount}개`
    : '';

  const unmappedSellers = codeSummaryRows
    .filter((row) => row.status === '미매핑')
    .map((row) => row.seller);

  const summary = [
    { label: '기준 SKU', value: sku.selfpia_sku_code || '없음', tone: 'primary' },
    { label: '자사코드', value: ownSkuCodes[0] || '없음', tone: ownSkuCodes[0] ? 'primary' : 'muted' },
    { label: '연결 채널', value: connectedText || '없음', tone: connectedText ? 'success' : 'muted' },
    { label: '연결 후보', value: candidateText || '없음', tone: candidateText ? 'warning' : 'muted' },
    { label: '미매핑 채널', value: unmappedSellers.length > 0 ? unmappedSellers.join(', ') : '없음', tone: unmappedSellers.length > 0 ? 'warning' : 'muted' },
    { label: '이미지', value: sku.thumbnail_url || sku.image_url ? '있음' : '없음', tone: sku.thumbnail_url || sku.image_url ? 'success' : 'muted' }
  ];

  return summary;
}

function SmartstoreCodeReviewPanel({
  smartstoreProductCodes,
  smartstoreAliasCodes,
  smartstoreProductCandidateCodes,
  smartstoreCandidateCodes
}) {
  const rows = [
    {
      key: 'product-confirmed',
      label: 'productNo 확정값',
      values: smartstoreProductCodes,
      status: smartstoreProductCodes.length > 0 ? '확정' : '없음',
      note: '운영 확정 Smartstore 상품번호'
    },
    {
      key: 'option-confirmed',
      label: 'optionNo 확정값',
      values: smartstoreAliasCodes,
      status: smartstoreAliasCodes.length > 0 ? '확정' : '없음',
      note: '운영 확정 Smartstore 옵션번호'
    },
    {
      key: 'product-candidate',
      label: 'productNo 후보값',
      values: smartstoreProductCandidateCodes,
      status: smartstoreProductCandidateCodes.length > 0 ? '후보' : '없음',
      note: '후보 / 운영 미확정 / export 사용 금지'
    },
    {
      key: 'option-candidate',
      label: 'optionNo 후보값',
      values: smartstoreCandidateCodes,
      status: smartstoreCandidateCodes.length > 0 ? '후보' : '없음',
      note: '후보 / 운영 미확정 / export 사용 금지'
    }
  ];

  return (
    <section className="panel smartstore-review-panel" aria-label="Smartstore 확정값과 후보값">
      <div className="panel-header">
        <div>
          <h2>Smartstore 확정값 / 후보값</h2>
          <p className="hint">확정값과 후보값을 분리해서 표시합니다. 후보는 운영 미확정이며 export에 사용할 수 없습니다.</p>
        </div>
      </div>
      <div className="smartstore-review-grid">
        {rows.map((row) => (
          <div className={`smartstore-review-item is-${row.status === '후보' ? 'candidate' : row.status === '확정' ? 'confirmed' : 'empty'}`} key={row.key}>
            <div className="smartstore-review-title">
              <span>{row.label}</span>
              <MappingStatus status={row.status === '확정' ? '연결됨' : row.status === '후보' ? '후보' : '미매핑'} />
            </div>
            <div className="smartstore-review-values">
              {row.values.length > 0
                ? row.values.map((value) => <CodeValue value={value} key={value} />)
                : <span className="muted">없음</span>}
            </div>
            <p className="hint">{row.note}</p>
          </div>
        ))}
      </div>
      <div className="review-placeholder-actions" aria-label="수동검수 placeholder">
        <button className="button-subtle" type="button" disabled title="이번 버전은 read-only입니다. 저장 기능은 구현하지 않습니다.">
          수동확정 placeholder
        </button>
        <button className="button-subtle" type="button" disabled title="이번 버전은 read-only입니다. 저장 기능은 구현하지 않습니다.">
          반려 placeholder
        </button>
        <button className="button-subtle" type="button" disabled title="이번 버전은 read-only입니다. 저장 기능은 구현하지 않습니다.">
          보류 placeholder
        </button>
      </div>
    </section>
  );
}

export function ProductDetailPage() {
  const { skuId } = useParams();
  const [sku, setSku] = useState(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      setError('');
      setLoading(true);
      try {
        const result = await productsApi.getSku(skuId);
        if (!cancelled) setSku(result.data);
      } catch (err) {
        if (!cancelled) {
          setError(err.message);
          setSku(null);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [skuId]);

  if (error) {
    return (
      <section className="page">
        <Link className="back-link" to="/products">← SKU 목록</Link>
        <div className="notice error">조회 실패: {error}</div>
      </section>
    );
  }

  if (loading || !sku) {
    return (
      <section className="page">
        <Link className="back-link" to="/products">← SKU 목록</Link>
        <div className="notice">상품 상세를 조회하는 중입니다.</div>
      </section>
    );
  }

  const aliases = sku.aliases || [];
  const mappings = sku.channel_mappings || [];
  const smartstoreCodesByApi = sku.smartstore_codes || {};
  const ownSkuCodes = aliasValues(aliases, 'own_sku');
  const smartstoreProductCodes = uniqueValues([
    ...(smartstoreCodesByApi.product_nos || []),
    ...aliasValues(aliases, 'smartstore_product_no')
  ]);
  const smartstoreProductCandidateCodes = uniqueValues([
    ...(smartstoreCodesByApi.product_no_candidates || []),
    ...aliasValues(aliases, 'smartstore_product_no_candidate')
  ]);
  const smartstoreAliasCodes = uniqueValues([
    ...(smartstoreCodesByApi.option_nos || []),
    ...aliasValues(aliases, 'smartstore_option_no')
  ]);
  const smartstoreCandidateCodes = uniqueValues([
    ...(smartstoreCodesByApi.option_no_candidates || []),
    ...aliasValues(aliases, 'smartstore_option_no_candidate')
  ]);
  const smartstoreCodes = uniqueValues([...smartstoreAliasCodes, ...smartstoreChannelCodes(mappings)]);
  const codeSummaryRows = buildCodeSummaryRows({
    sku,
    mappings,
    ownSkuCodes,
    smartstoreProductCodes,
    smartstoreProductCandidateCodes,
    smartstoreAliasCodes,
    smartstoreCandidateCodes
  });
  const connectionSummary = buildConnectionSummary({
    sku,
    mappings,
    ownSkuCodes,
    codeSummaryRows,
    smartstoreAliasCodes,
    smartstoreProductCandidateCodes,
    smartstoreCandidateCodes
  });

  return (
    <section className="page">
      <div className="page-header">
        <div>
          <Link className="back-link" to="/products">← SKU 목록</Link>
          <h1>SKU 상세</h1>
          <p>대표 이미지, 주요 코드, alias와 channel mapping을 read-only로 확인합니다.</p>
        </div>
        <button className="button disabled" disabled title="v1 read-only. master 변경 기능은 비활성화되어 있습니다.">
          Change Request
        </button>
      </div>

      <div className="readonly-banner" role="note">
        상세 화면은 조회 전용입니다. master, alias, channel mapping 추가·수정·삭제 UI는 v1 범위 밖입니다.
      </div>

      <section className="product-detail-hero panel">
        <ProductThumbnail
          src={sku.thumbnail_url || sku.image_url}
          alt={sku.product_name || sku.selfpia_sku_code}
          size="lg"
        />
        <div className="product-detail-summary">
          <div className="product-detail-title-row">
            <div>
              <h2 title={sku.product_name}>{sku.product_name || '상품명 없음'}</h2>
              <p title={sku.option_value}>{sku.option_value || '옵션 정보 없음'}</p>
            </div>
            <StatusBadge value={sku.sku_status} />
          </div>
          <ProductMetaChips
            items={[
              { key: 'selfpia_sku_code', value: sku.selfpia_sku_code },
              { key: 'selfpia_product_code', value: sku.selfpia_product_code },
              { key: 'virtual_sku_code', value: sku.virtual_sku_code },
              { key: 'virtual_product_code', value: sku.virtual_product_code },
              { key: 'own_sku_code', value: ownSkuCodes[0] },
              { key: 'smartstore_code', value: smartstoreCodes[0] }
            ]}
          />
        </div>
      </section>

      <section className="connection-summary-panel" aria-label="연결 상태 요약">
        {connectionSummary.map((item) => (
          <div className={`connection-summary-item is-${item.tone}`} key={item.label}>
            <span>{item.label}</span>
            <strong title={item.value}>{item.value}</strong>
          </div>
        ))}
      </section>

      <SmartstoreCodeReviewPanel
        smartstoreProductCodes={smartstoreProductCodes}
        smartstoreAliasCodes={smartstoreAliasCodes}
        smartstoreProductCandidateCodes={smartstoreProductCandidateCodes}
        smartstoreCandidateCodes={smartstoreCandidateCodes}
      />

      <section className="panel code-summary-panel">
        <div className="panel-header">
          <div>
            <h2>판매처별 코드 요약</h2>
            <p className="hint">이 SKU가 기준 코드와 판매처별 코드로 어떻게 연결되어 있는지 먼저 확인합니다.</p>
          </div>
          <span className="muted">{codeSummaryRows.length}개 구분</span>
        </div>
        <div className="table-wrap code-summary-wrap">
          <table className="code-summary-table">
            <thead>
              <tr>
                <th style={{ width: 88 }}>구분</th>
                <th style={{ width: 130 }}>판매처</th>
                <th>상품코드</th>
                <th>옵션코드 또는 SKU 코드</th>
                <th>자사코드</th>
                <th style={{ width: 100 }}>상태</th>
                <th>비고</th>
              </tr>
            </thead>
            <tbody>
              {codeSummaryRows.map((row) => (
                <tr key={row.key}>
                  <td><span className="pill pill-off">{row.group}</span></td>
                  <td><strong>{row.seller}</strong></td>
                  <td><CodeValue value={row.productCode} /></td>
                  <td><CodeValue value={row.optionCode} /></td>
                  <td><CodeValue value={row.ownSkuCode} /></td>
                  <td><MappingStatus status={row.status} /></td>
                  <td className="muted">{row.note}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <div className="detail-grid">
        <section className="panel">
          <h2>SKU 정보</h2>
          <dl className="definition-list">
            <dt>Selfpia SKU</dt>
            <dd>
              <div className="cell-code">
                <span className="mono ellipsis" title={sku.selfpia_sku_code}>{sku.selfpia_sku_code || '-'}</span>
                {sku.selfpia_sku_code && <CopyButton value={sku.selfpia_sku_code} label="복사" />}
              </div>
            </dd>
            <dt>내부 ID</dt>
            <dd>
              <div className="cell-code">
                <span className="mono ellipsis muted" title={sku.sku_id}>{sku.sku_id}</span>
                <CopyButton value={sku.sku_id} label="복사" />
              </div>
            </dd>
            <dt>Selfpia Product</dt>
            <dd>
              <div className="cell-code">
                <span className="mono">{sku.selfpia_product_code || '-'}</span>
                {sku.selfpia_product_code && <CopyButton value={sku.selfpia_product_code} label="복사" />}
              </div>
            </dd>
            <dt>Virtual SKU</dt>
            <dd>
              <div className="cell-code">
                <span className="mono ellipsis" title={sku.virtual_sku_code}>{sku.virtual_sku_code || '-'}</span>
                {sku.virtual_sku_code && <CopyButton value={sku.virtual_sku_code} label="복사" />}
              </div>
            </dd>
            <dt>옵션</dt>
            <dd>{sku.option_value || '-'}</dd>
            <dt>상태</dt>
            <dd><StatusBadge value={sku.sku_status} /></dd>
          </dl>
        </section>

        <section className="panel">
          <h2>운영 연결</h2>
          <p className="hint">아래 링크는 read-only 운영 API입니다. 이 화면에서는 master 변경 요청을 생성하지 않습니다.</p>
          <div className="link-list">
            <a href="http://localhost:8080/mapping/own-sku/ambiguous" target="_blank" rel="noreferrer">
              모호 매핑 API 열기
            </a>
            <a href="http://localhost:8080/picking/unmatched" target="_blank" rel="noreferrer">
              미매칭 주문상품 API 열기
            </a>
          </div>
        </section>
      </div>

      <details className="panel raw-data-panel">
        <summary className="raw-data-summary">
          <div>
            <h2>Raw Alias</h2>
            <p className="hint">요약표 산출에 사용한 원본 alias입니다.</p>
          </div>
          <span className="muted">{aliases.length}건</span>
        </summary>
        <div className="table-wrap">
          <table className="sticky zebra">
            <thead>
              <tr>
                <th style={{ width: 180 }}>Code system</th>
                <th>Code value</th>
                <th style={{ width: 160 }}>Selfpia product</th>
                <th style={{ width: 120 }}>Option no</th>
                <th style={{ width: 90 }}>Primary</th>
              </tr>
            </thead>
            <tbody>
              {aliases.map((alias) => (
                <tr key={alias.id}>
                  <td><CodeSystemBadge value={alias.code_system} /></td>
                  <td>
                    <div className="cell-code">
                      <span className="mono ellipsis" title={alias.code_value}>{alias.code_value}</span>
                      <CopyButton value={alias.code_value} label="복사" />
                    </div>
                  </td>
                  <td className="mono">{alias.selfpia_product_code || '-'}</td>
                  <td className="mono">{alias.selfpia_option_no || '-'}</td>
                  <td>{alias.is_primary ? <span className="pill pill-on">Y</span> : <span className="pill pill-off">N</span>}</td>
                </tr>
              ))}
              {aliases.length === 0 && (
                <tr>
                  <td colSpan="5" className="empty">alias가 없습니다.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </details>

      <details className="panel raw-data-panel">
        <summary className="raw-data-summary">
          <div>
            <h2>Raw Channel Mapping</h2>
            <p className="hint">요약표 산출에 사용한 판매처 mapping 원본입니다.</p>
          </div>
          <span className="muted">{mappings.length}건</span>
        </summary>
        <div className="table-wrap">
          <table className="sticky zebra">
            <thead>
              <tr>
                <th style={{ width: 180 }}>Channel</th>
                <th>Channel SKU</th>
                <th>Seller product</th>
                <th>Own SKU</th>
                <th style={{ width: 90 }}>Primary</th>
              </tr>
            </thead>
            <tbody>
              {mappings.map((mapping) => (
                <tr key={mapping.id}>
                  <td><CodeSystemBadge value={mapping.channel_code} /></td>
                  <td>
                    <div className="cell-code">
                      <span className="mono ellipsis" title={mapping.channel_sku_code}>{mapping.channel_sku_code || '-'}</span>
                      {mapping.channel_sku_code && <CopyButton value={mapping.channel_sku_code} label="복사" />}
                    </div>
                  </td>
                  <td className="mono ellipsis" title={mapping.seller_product_code}>{mapping.seller_product_code || '-'}</td>
                  <td className="mono ellipsis" title={mapping.own_sku_code}>{mapping.own_sku_code || '-'}</td>
                  <td>{mapping.is_primary ? <span className="pill pill-on">Y</span> : <span className="pill pill-off">N</span>}</td>
                </tr>
              ))}
              {mappings.length === 0 && (
                <tr>
                  <td colSpan="5" className="empty">channel mapping이 없습니다.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </details>
    </section>
  );
}
