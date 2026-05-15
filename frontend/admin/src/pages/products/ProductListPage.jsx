import React, { useEffect, useState } from 'react';

import { productsApi } from '../../api/client.js';
import { ProductCardRow } from '../../components/ProductCardRow.jsx';

const DEFAULT_SEARCH = '1258-1';
const SEARCH_EXAMPLES = ['1258-1', '실버 기본 바', '피어싱', 'LOCAL_TEST_PM'];

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
    // 최초 1회만 기본 검색을 실행한다.
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
          <p>상품코드 master 기준 read-only 조회 · 최대 50건</p>
        </div>
        <button className="button disabled" disabled title="v1 read-only. master 변경 기능은 비활성화 상태입니다.">
          Change Request
        </button>
      </div>

      <form
        className="toolbar product-search-toolbar"
        onSubmit={(event) => {
          event.preventDefault();
          load();
        }}
      >
        <input
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="상품명 / Selfpia SKU / Virtual SKU 부분 일치"
          aria-label="SKU 검색"
        />
        <button className="button" type="submit" disabled={loading}>
          {loading ? '조회 중...' : '검색'}
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
      {loading && !error && <div className="notice">상품을 조회하는 중입니다.</div>}

      <div className="product-card-list" aria-busy={loading}>
        {!loading && rows.map((row) => (
          <ProductCardRow key={row.sku_id} product={row} />
        ))}
        {!loading && rows.length === 0 && (
          <div className="empty-state">
            <strong>검색 결과가 없습니다.</strong>
            <p>
              <code>{lastQuery || search}</code> 조건으로 조회된 SKU가 없습니다.
              예시 검색어를 누르거나 검색어를 줄여보세요.
            </p>
          </div>
        )}
      </div>

      <p className="hint">
        목록은 <code>/api/products/skus?search=...&amp;limit=50</code> 응답을 그대로 사용합니다.
        현재 단계에서는 이미지 URL을 요청하지 않으므로 모든 상품에 이미지 슬롯 placeholder가 표시됩니다.
      </p>
    </section>
  );
}
