import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';

import { productsApi } from '../../api/client.js';
import { CodeSystemBadge } from '../../components/StatusBadge.jsx';
import { CopyButton } from '../../components/CopyButton.jsx';
import { ProductMetaChips } from '../../components/ProductMetaChips.jsx';
import { ProductThumbnail } from '../../components/ProductThumbnail.jsx';

const CODE_SYSTEMS = [
  {
    value: 'selfpia_sku',
    label: 'selfpia_sku (Selfpia SKU code, NNN-NN)',
    description: 'canonical SKU와 1:1 매칭되는 기본 코드입니다. 예: LOCAL_TEST_PM_1258-1',
    example: 'LOCAL_TEST_PM_1258-1'
  },
  {
    value: 'selfpia_product',
    label: 'selfpia_product (상품 단위)',
    description: '상품 단위 코드입니다. 같은 selfpia_product 아래 여러 옵션 SKU가 묶일 수 있습니다.',
    example: 'LOCAL_TEST_PM_1258'
  },
  {
    value: 'own_sku',
    label: 'own_sku (자체 옵션 코드)',
    description: 'n:m 가능성이 있어 같은 own_sku가 여러 SKU에 묶이면 복수 후보로 반환합니다.',
    example: 'LOCAL_TEST_PM_OWN_AMBIG'
  },
  {
    value: 'smartstore_option_no',
    label: 'smartstore_option_no (스마트스토어 옵션 번호)',
    description: '스마트스토어 채널 옵션 번호입니다. local seed에는 1건이 있습니다.',
    example: 'LOCAL_TEST_PM_SS_001'
  }
];

function findMeta(systemValue) {
  return CODE_SYSTEMS.find((s) => s.value === systemValue) || CODE_SYSTEMS[0];
}

export function AliasSearchPage() {
  const navigate = useNavigate();
  const [codeSystem, setCodeSystem] = useState('selfpia_sku');
  const [codeValue, setCodeValue] = useState('LOCAL_TEST_PM_1258-1');
  const [rows, setRows] = useState([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [lastQuery, setLastQuery] = useState(null);

  async function runSearch(nextSystem, nextValue) {
    setError('');
    setLoading(true);
    setSubmitted(true);
    try {
      const result = await productsApi.findByCode(nextSystem, nextValue);
      setRows(result.data || []);
      setLastQuery({ system: nextSystem, value: nextValue });
    } catch (err) {
      setError(err.message);
      setRows([]);
      setLastQuery({ system: nextSystem, value: nextValue });
    } finally {
      setLoading(false);
    }
  }

  function onSubmit(event) {
    event.preventDefault();
    runSearch(codeSystem, codeValue);
  }

  function applyExample(system) {
    const nextMeta = findMeta(system);
    setCodeSystem(system);
    setCodeValue(nextMeta.example);
    runSearch(system, nextMeta.example);
  }

  const meta = findMeta(codeSystem);
  const ambiguous = rows.length > 1;
  const empty = submitted && !loading && !error && rows.length === 0;

  function openDetail(skuId) {
    navigate(`/products/${skuId}`);
  }

  function onResultKeyDown(event, skuId) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      openDetail(skuId);
    }
  }

  return (
    <section className="page">
      <div className="page-header">
        <div>
          <h1>Alias 검색</h1>
          <p>code system / code value 기준 read-only SKU 조회</p>
        </div>
      </div>

      <form className="toolbar product-search-toolbar" onSubmit={onSubmit}>
        <select
          value={codeSystem}
          onChange={(event) => {
            const next = event.target.value;
            setCodeSystem(next);
            setCodeValue(findMeta(next).example);
          }}
          aria-label="Code system"
        >
          {CODE_SYSTEMS.map((opt) => (
            <option key={opt.value} value={opt.value}>{opt.label}</option>
          ))}
        </select>
        <input
          value={codeValue}
          onChange={(event) => setCodeValue(event.target.value)}
          placeholder={`예: ${meta.example}`}
          aria-label="Code value"
        />
        <button className="button" type="submit" disabled={loading || codeValue.trim() === ''}>
          {loading ? '조회 중...' : '검색'}
        </button>
      </form>

      <div className="hint">
        <CodeSystemBadge value={codeSystem} /> {meta.description}
      </div>

      <div className="examples">
        <span className="examples-label">예시</span>
        {CODE_SYSTEMS.map((opt) => (
          <button
            key={opt.value}
            type="button"
            className="chip"
            onClick={() => applyExample(opt.value)}
            title={`${opt.value} 예시로 검색`}
          >
            {opt.value} · {opt.example}
          </button>
        ))}
      </div>

      {error && <div className="notice error">조회 실패: {error}</div>}
      {ambiguous && !error && (
        <div className="notice warn">
          <strong>복수 후보 {rows.length}건</strong> 같은 code value가 여러 SKU에 묶여 있습니다.
          own_sku 같은 n:m alias에서 자주 발생합니다. 자동 확정은 금지 대상입니다.
        </div>
      )}
      {!ambiguous && !error && submitted && !loading && rows.length === 1 && (
        <div className="notice ok">단일 매칭 SKU 1건</div>
      )}
      {loading && !error && <div className="notice">alias를 조회하는 중입니다.</div>}

      <div className="alias-result-list" aria-busy={loading}>
        {!loading && rows.map((row) => (
          <div
            className="alias-result-row"
            role="link"
            tabIndex={0}
            onClick={() => openDetail(row.sku_id)}
            onKeyDown={(event) => onResultKeyDown(event, row.sku_id)}
            key={`${row.sku_id}-${row.matched_code_value}`}
          >
            <ProductThumbnail
              src={row.thumbnail_url || row.image_url}
              alt={row.product_name || row.selfpia_sku_code}
              size="sm"
            />
            <div className="alias-result-main">
              <div className="alias-result-title-row">
                <strong className="alias-result-title" title={row.product_name}>{row.product_name || '상품명 없음'}</strong>
                <CodeSystemBadge value={row.matched_code_system} />
              </div>
              <span className="alias-result-option" title={row.option_value}>{row.option_value || '옵션 정보 없음'}</span>
              <ProductMetaChips
                items={[
                  { key: 'selfpia_sku_code', value: row.selfpia_sku_code },
                  { key: 'matched_code_value', label: 'Matched', value: row.matched_code_value }
                ]}
              />
            </div>
            <CopyButton value={row.matched_code_value} label="복사" />
          </div>
        ))}

        {empty && (
          <div className="empty-state">
            <strong>조회 결과가 없습니다.</strong>
            <p>
              {lastQuery && (
                <>
                  검색 조건: <CodeSystemBadge value={lastQuery.system} /> <code>{lastQuery.value}</code>
                </>
              )}
            </p>
            <ul className="empty-hints">
              <li>해당 code value가 master code_alias에 적재되지 않았을 수 있습니다.</li>
              <li>code system을 다르게 선택했을 수 있습니다.</li>
              <li>운영 코드를 조회하려면 로컬 DB에 master export 적재가 필요합니다.</li>
            </ul>
          </div>
        )}
      </div>

      <p className="hint">
        호출: <code>GET /api/products/skus/by-code/{`{codeSystem}`}/{`{codeValue}`}</code>.
        ambiguous 결과는 SKU 단위로 dedupe된 후보 목록입니다.
      </p>
    </section>
  );
}
