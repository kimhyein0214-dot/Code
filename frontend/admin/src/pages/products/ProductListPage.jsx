import React, { useEffect, useRef, useState } from 'react';

import { productsApi } from '../../api/client.js';
import { getProductConnectionStatus, ProductCardRow } from '../../components/ProductCardRow.jsx';

const DEFAULT_SEARCH = '10007';
const SEARCH_EXAMPLES = ['10007-1', '10000-1', '10005-1', '10004-1', '1012-1', '1181-31'];

const SMARTSTORE_FILTERS = [
  { value: 'all', label: '전체' },
  { value: 'confirmed', label: '확정 있음' },
  { value: 'candidate_only', label: '후보만 있음' },
  { value: 'unmapped', label: '미매핑' },
  { value: 'confirmed_and_candidate', label: '확정+후보 같이 있음' }
];

const MAKESHOP_FILTERS = [
  { value: 'all', label: '전체' },
  { value: 'connected', label: '연결 있음' },
  { value: 'unconnected', label: '미연결' }
];

const IMAGE_FILTERS = [
  { value: 'all', label: '전체' },
  { value: 'present', label: '이미지 있음' },
  { value: 'missing', label: '이미지 없음' }
];

const OWN_SKU_FILTERS = [
  { value: 'all', label: '전체' },
  { value: 'present', label: '있음' },
  { value: 'missing', label: '없음' }
];

function matchesFilters(product, detail, filters) {
  const status = getProductConnectionStatus(product, detail);
  const imageStatus = status.hasImage ? 'present' : 'missing';

  return (
    (filters.smartstore === 'all' || status.smartstoreStatus === filters.smartstore) &&
    (filters.makeshop === 'all' || status.makeshopStatus === filters.makeshop) &&
    (filters.image === 'all' || imageStatus === filters.image) &&
    (filters.ownSku === 'all' || status.ownSkuStatus === filters.ownSku)
  );
}

export function ProductListPage() {
  const [search, setSearch] = useState(DEFAULT_SEARCH);
  const [rows, setRows] = useState([]);
  const [detailsBySkuId, setDetailsBySkuId] = useState({});
  const [detailLoading, setDetailLoading] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [lastQuery, setLastQuery] = useState('');
  const [filters, setFilters] = useState({
    smartstore: 'all',
    makeshop: 'all',
    image: 'all',
    ownSku: 'all'
  });
  const requestSeq = useRef(0);

  async function load(term) {
    const q = term ?? search;
    const seq = requestSeq.current + 1;
    requestSeq.current = seq;
    setLoading(true);
    setDetailLoading(false);
    setError('');
    try {
      const result = await productsApi.listSkus({ search: q, limit: 50 });
      const nextRows = result.data || [];
      setRows(nextRows);
      setDetailsBySkuId({});
      setLastQuery(q);
      setLoading(false);

      const skuIds = [...new Set(nextRows.map((row) => row.sku_id).filter(Boolean))];
      if (skuIds.length > 0) {
        setDetailLoading(true);
        const detailEntries = await Promise.all(
          skuIds.map(async (skuId) => {
            try {
              const detail = await productsApi.getSku(skuId);
              return [skuId, detail.data || null];
            } catch {
              return [skuId, null];
            }
          })
        );
        if (requestSeq.current === seq) {
          setDetailsBySkuId(Object.fromEntries(detailEntries));
        }
      }
    } catch (err) {
      if (requestSeq.current !== seq) {
        return;
      }
      setError(err.message);
      setRows([]);
      setDetailsBySkuId({});
      setLastQuery(q);
    } finally {
      if (requestSeq.current === seq) {
        setLoading(false);
        setDetailLoading(false);
      }
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

  function updateFilter(key, value) {
    setFilters((current) => ({ ...current, [key]: value }));
  }

  function resetFilters() {
    setFilters({
      smartstore: 'all',
      makeshop: 'all',
      image: 'all',
      ownSku: 'all'
    });
  }

  const detailsReady = rows.every((row) => detailsBySkuId[row.sku_id] !== undefined);
  const filteredRows = rows.filter((row) => matchesFilters(row, detailsBySkuId[row.sku_id], filters));
  const activeFilterCount = Object.values(filters).filter((value) => value !== 'all').length;

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

      <section className="section-card product-filter-card" aria-label="매칭 상태 필터">
        <div className="panel-header">
          <div>
            <h2>매칭 상태 필터</h2>
            <p className="hint">현재 조회된 SKU 안에서 Smartstore, MakeShop, 이미지, 자사코드 상태를 read-only로 걸러봅니다.</p>
          </div>
          <button className="button-subtle" type="button" onClick={resetFilters} disabled={activeFilterCount === 0}>
            필터 초기화
          </button>
        </div>

        <div className="filter-grid">
          <label>
            <span>Smartstore</span>
            <select value={filters.smartstore} onChange={(event) => updateFilter('smartstore', event.target.value)}>
              {SMARTSTORE_FILTERS.map((filter) => (
                <option key={filter.value} value={filter.value}>{filter.label}</option>
              ))}
            </select>
          </label>
          <label>
            <span>MakeShop</span>
            <select value={filters.makeshop} onChange={(event) => updateFilter('makeshop', event.target.value)}>
              {MAKESHOP_FILTERS.map((filter) => (
                <option key={filter.value} value={filter.value}>{filter.label}</option>
              ))}
            </select>
          </label>
          <label>
            <span>이미지</span>
            <select value={filters.image} onChange={(event) => updateFilter('image', event.target.value)}>
              {IMAGE_FILTERS.map((filter) => (
                <option key={filter.value} value={filter.value}>{filter.label}</option>
              ))}
            </select>
          </label>
          <label>
            <span>자사코드</span>
            <select value={filters.ownSku} onChange={(event) => updateFilter('ownSku', event.target.value)}>
              {OWN_SKU_FILTERS.map((filter) => (
                <option key={filter.value} value={filter.value}>{filter.label}</option>
              ))}
            </select>
          </label>
        </div>

        <div className="filter-summary">
          <span>조회 {rows.length}건</span>
          <span>필터 결과 {filteredRows.length}건</span>
          {detailLoading && <span>상세 상태 계산 중</span>}
          {!detailLoading && rows.length > 0 && !detailsReady && <span>일부 상태 미확인</span>}
        </div>
      </section>

      {error && <div className="notice error">조회 실패: {error}</div>}
      {loading && !error && <div className="notice">상품을 조회하는 중입니다.</div>}

      <div className="product-card-list" aria-busy={loading}>
        {!loading && filteredRows.map((row, index) => (
          <ProductCardRow
            key={`${row.sku_id}-${row.selfpia_sku_code || row.virtual_sku_code || index}`}
            product={row}
            detail={detailsBySkuId[row.sku_id]}
            detailLoading={detailLoading && detailsBySkuId[row.sku_id] === undefined}
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
        {!loading && rows.length > 0 && filteredRows.length === 0 && (
          <div className="empty-state">
            <strong>필터 결과가 없습니다.</strong>
            <p>현재 조회 결과 안에서는 선택한 매칭 상태 조합에 해당하는 SKU가 없습니다.</p>
          </div>
        )}
      </div>

      <p className="hint">
        호출: <code>/api/products/skus?search=...&amp;limit=50</code>. 이미지 URL이 없는 상품은 정돈된 placeholder로 표시합니다.
      </p>
    </section>
  );
}
