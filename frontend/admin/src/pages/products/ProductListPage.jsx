import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

import { productsApi } from '../../api/client.js';
import { StatusBadge } from '../../components/StatusBadge.jsx';
import { CopyButton } from '../../components/CopyButton.jsx';

const DEFAULT_SEARCH = 'LOCAL_TEST_PM';
const SEARCH_EXAMPLES = ['LOCAL_TEST_PM', 'LOCAL_TEST_PM_1258-1', 'LOCAL_TEST_PM_OWN_AMBIG'];

export function ProductListPage() {
  const [search, setSearch] = useState(DEFAULT_SEARCH);
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [lastQuery, setLastQuery] = useState('');

  async function load(term) {
    const q = term ?? search;
    setLoading(true);
    setError('');
    try {
      const result = await productsApi.listSkus({ search: q, limit: 50 });
      setRows(result.data || []);
      setLastQuery(q);
    } catch (err) {
      setError(err.message);
      setRows([]);
      setLastQuery(q);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load(DEFAULT_SEARCH);
    // 최초 1회만. 후속 검색은 form submit / 예시 chip 으로 트리거.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function applyExample(example) {
    setSearch(example);
    load(example);
  }

  return (
    <section className="page">
      <div className="page-header">
        <div>
          <h1>SKU 목록</h1>
          <p>Product_code master 기준 read-only 조회 · 최대 50건</p>
        </div>
        <button className="button disabled" disabled title="v1 read-only. master 변경 기능 비활성">
          Change Request
        </button>
      </div>

      <form
        className="toolbar"
        onSubmit={(event) => {
          event.preventDefault();
          load();
        }}
      >
        <input
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="상품명 / Selfpia SKU / Own SKU / Virtual SKU 부분 일치"
          aria-label="SKU 검색"
        />
        <button className="button" type="submit" disabled={loading}>
          {loading ? '조회 중…' : '검색'}
        </button>
      </form>

      <div className="examples">
        <span className="examples-label">검색 예시</span>
        {SEARCH_EXAMPLES.map((example) => (
          <button
            key={example}
            type="button"
            className="chip"
            onClick={() => applyExample(example)}
          >
            {example}
          </button>
        ))}
      </div>

      {error && <div className="notice error">조회 실패: {error}</div>}
      {loading && !error && <div className="notice">조회 중…</div>}

      <div className="table-wrap">
        <table className="sticky">
          <thead>
            <tr>
              <th style={{ minWidth: 200 }}>Selfpia SKU</th>
              <th>상품명</th>
              <th>옵션</th>
              <th style={{ minWidth: 200 }}>Virtual SKU</th>
              <th style={{ width: 110 }}>상태</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.sku_id}>
                <td>
                  <div className="cell-code">
                    <Link to={`/products/${row.sku_id}`} className="mono ellipsis" title={row.selfpia_sku_code}>
                      {row.selfpia_sku_code}
                    </Link>
                    <CopyButton value={row.selfpia_sku_code} />
                  </div>
                </td>
                <td className="ellipsis-2" title={row.product_name}>{row.product_name}</td>
                <td className="ellipsis-2" title={row.option_value}>{row.option_value}</td>
                <td>
                  <div className="cell-code">
                    <span className="mono ellipsis" title={row.virtual_sku_code}>{row.virtual_sku_code}</span>
                    <CopyButton value={row.virtual_sku_code} />
                  </div>
                </td>
                <td><StatusBadge value={row.sku_status} /></td>
              </tr>
            ))}
            {!loading && rows.length === 0 && (
              <tr>
                <td colSpan="5" className="empty">
                  검색어 <code>{lastQuery || search}</code> 로 조회된 SKU 가 없습니다.
                  검색 예시 버튼을 눌러보거나 검색어를 줄여보세요.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <p className="hint">
        결과는 <code>/api/products/skus?search=…&amp;limit=50</code> 응답입니다. 상태 컬럼은 sku_master.status 원본을 그대로 보여줍니다.
      </p>
    </section>
  );
}
