import React, { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';

import { productsApi } from '../../api/client.js';
import { CodeSystemBadge, StatusBadge } from '../../components/StatusBadge.jsx';
import { CopyButton } from '../../components/CopyButton.jsx';

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
        <div className="notice">조회 중…</div>
      </section>
    );
  }

  const aliases = sku.aliases || [];
  const mappings = sku.channel_mappings || [];

  return (
    <section className="page">
      <div className="page-header">
        <div>
          <Link className="back-link" to="/products">← SKU 목록</Link>
          <div className="cell-code">
            <h1 className="mono">{sku.selfpia_sku_code}</h1>
            <CopyButton value={sku.selfpia_sku_code} />
          </div>
          <p className="ellipsis-2" title={sku.product_name}>{sku.product_name}</p>
        </div>
        <button className="button disabled" disabled title="v1 read-only. master 변경 기능 비활성">
          Change Request
        </button>
      </div>

      <div className="readonly-banner" role="note">
        본 상세 화면은 read-only 입니다. master/alias/channel mapping 의 추가/수정/삭제 UI 는 v1 범위 밖입니다.
      </div>

      <div className="detail-grid">
        <section className="panel">
          <h2>SKU 정보</h2>
          <dl className="definition-list">
            <dt>SKU ID</dt>
            <dd>
              <div className="cell-code">
                <span className="mono ellipsis" title={sku.sku_id}>{sku.sku_id}</span>
                <CopyButton value={sku.sku_id} />
              </div>
            </dd>
            <dt>Selfpia Product</dt>
            <dd>
              <div className="cell-code">
                <span className="mono">{sku.selfpia_product_code || '—'}</span>
                {sku.selfpia_product_code && <CopyButton value={sku.selfpia_product_code} />}
              </div>
            </dd>
            <dt>Virtual SKU</dt>
            <dd>
              <div className="cell-code">
                <span className="mono ellipsis" title={sku.virtual_sku_code}>{sku.virtual_sku_code}</span>
                <CopyButton value={sku.virtual_sku_code} />
              </div>
            </dd>
            <dt>옵션</dt>
            <dd>{sku.option_value || '—'}</dd>
            <dt>상태</dt>
            <dd><StatusBadge value={sku.sku_status} /></dd>
          </dl>
        </section>

        <section className="panel">
          <h2>운영 연결</h2>
          <p className="hint">아래 링크는 read-only 운영 API 입니다. 새 탭에서 JSON 응답을 그대로 확인할 수 있습니다.</p>
          <div className="link-list">
            <a href="http://localhost:8080/mapping/own-sku/ambiguous" target="_blank" rel="noreferrer">
              모호 매칭 API ↗
            </a>
            <a href="http://localhost:8080/picking/unmatched" target="_blank" rel="noreferrer">
              미매칭 주문상품 API ↗
            </a>
          </div>
        </section>
      </div>

      <section className="panel">
        <div className="panel-header">
          <h2>Alias</h2>
          <span className="muted">{aliases.length}건</span>
        </div>
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
                      <CopyButton value={alias.code_value} />
                    </div>
                  </td>
                  <td className="mono">{alias.selfpia_product_code || '—'}</td>
                  <td className="mono">{alias.selfpia_option_no || '—'}</td>
                  <td>{alias.is_primary ? <span className="pill pill-on">Y</span> : <span className="pill pill-off">N</span>}</td>
                </tr>
              ))}
              {aliases.length === 0 && (
                <tr>
                  <td colSpan="5" className="empty">alias 가 없습니다.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section className="panel">
        <div className="panel-header">
          <h2>Channel Mapping</h2>
          <span className="muted">{mappings.length}건</span>
        </div>
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
                      <span className="mono ellipsis" title={mapping.channel_sku_code}>{mapping.channel_sku_code || '—'}</span>
                      {mapping.channel_sku_code && <CopyButton value={mapping.channel_sku_code} />}
                    </div>
                  </td>
                  <td className="mono ellipsis" title={mapping.seller_product_code}>{mapping.seller_product_code || '—'}</td>
                  <td className="mono ellipsis" title={mapping.own_sku_code}>{mapping.own_sku_code || '—'}</td>
                  <td>{mapping.is_primary ? <span className="pill pill-on">Y</span> : <span className="pill pill-off">N</span>}</td>
                </tr>
              ))}
              {mappings.length === 0 && (
                <tr>
                  <td colSpan="5" className="empty">channel mapping 이 없습니다.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </section>
  );
}
