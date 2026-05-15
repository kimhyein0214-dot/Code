import React, { useEffect, useState } from 'react';

import { productsApi } from '../../api/client.js';
import { ProductCardRow } from '../../components/ProductCardRow.jsx';

const DEFAULT_SEARCH = '1258-1';
const SEARCH_EXAMPLES = ['1258-1', '1000-1', '11258-1', '피어싱', 'LOCAL_TEST_PM'];

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
    // 초기 진입 시 대표 SKU로 목록 UI를 확인한다.
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
          <p>상품명, 옵션, 주요 코드와 이미지를 한 화면에서 확인하는 read-only 목록입니다.</p>
        </div>
        <button className="button disabled" disabled title="v1 read-only. master 변경 기능은 비활성화되어 있습니다.">
          Change Request
        </button>
      </div>

      <section className="section-card" aria-label="SKU 검색">
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
            placeholder="상품명 / Selfpia SKU / Virtual SKU / 옵션으로 검색"
            aria-label="SKU 검색"
          />
          <button className="button" type="submit" disabled={loading}>
            {loading ? '조회 중...' : '검색'}
          </button>
        </form>

        <div className="examples">
          <span className="examples-label">예시 검색</span>
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

        <p className="hint">
          최대 50건까지 조회하며, 화면의 복사와 상세 이동은 모두 조회 전용 동작입니다.
        </p>
      </section>

      {error && <div className="notice error">조회 실패: {error}</div>}
      {loading && !error && <div className="notice">상품을 조회하는 중입니다.</div>}

      <div className="product-card-list" aria-busy={loading}>
        {!loading && rows.map((row, index) => (
          <ProductCardRow
            key={`${row.sku_id}-${row.selfpia_sku_code || row.virtual_sku_code || index}`}
            product={row}
          />
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
        호출: <code>/api/products/skus?search=...&amp;limit=50</code>. 이미지 URL이 없는 상품은 정돈된 placeholder로 표시합니다.
      </p>
    </section>
  );
}
