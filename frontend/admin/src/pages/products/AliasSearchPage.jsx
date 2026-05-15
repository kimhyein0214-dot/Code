import React, { useState } from 'react';
import { Link } from 'react-router-dom';

import { productsApi } from '../../api/client.js';
import { CodeSystemBadge } from '../../components/StatusBadge.jsx';
import { CopyButton } from '../../components/CopyButton.jsx';

const CODE_SYSTEMS = [
  {
    value: 'selfpia_sku',
    label: 'selfpia_sku (Selfpia SKU code, NNN-NN)',
    description: 'canonical SKU 키. 1:1 매칭이 원칙입니다. 예: LOCAL_TEST_PM_1258-1',
    example: 'LOCAL_TEST_PM_1258-1'
  },
  {
    value: 'selfpia_product',
    label: 'selfpia_product (상품 단위)',
    description: '상품 단위 코드입니다. 같은 selfpia_product 의 옵션들이 여러 SKU 로 묶입니다.',
    example: 'LOCAL_TEST_PM_1258'
  },
  {
    value: 'own_sku',
    label: 'own_sku (자체 옵션 코드)',
    description: 'n:m 가능. 동일 own_sku 가 여러 SKU 에 묶인 경우 "복수 후보" 로 반환됩니다. 예: LOCAL_TEST_PM_OWN_AMBIG',
    example: 'LOCAL_TEST_PM_OWN_AMBIG'
  },
  {
    value: 'smartstore_option_no',
    label: 'smartstore_option_no (스마트스토어 옵션 번호)',
    description: '스마트스토어 채널 옵션 번호. local seed 에 1건만 있습니다.',
    example: 'LOCAL_TEST_PM_SS_001'
  }
];

function findMeta(systemValue) {
  return CODE_SYSTEMS.find((s) => s.value === systemValue) || CODE_SYSTEMS[0];
}

export function AliasSearchPage() {
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
    const meta = findMeta(system);
    setCodeSystem(system);
    setCodeValue(meta.example);
    runSearch(system, meta.example);
  }

  const meta = findMeta(codeSystem);
  const ambiguous = rows.length > 1;
  const empty = submitted && !loading && !error && rows.length === 0;

  return (
    <section className="page">
      <div className="page-header">
        <div>
          <h1>Alias 검색</h1>
          <p>code system / code value 기준 read-only SKU 조회</p>
        </div>
      </div>

      <form className="toolbar" onSubmit={onSubmit}>
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
          {loading ? '조회 중…' : '검색'}
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
          <strong>복수 후보 {rows.length}건</strong> — 동일 code value 가 여러 SKU 에 묶여 있습니다.
          own_sku 같은 n:m alias 에서 자주 나타납니다. 자동 확정 금지 대상입니다.
        </div>
      )}
      {!ambiguous && !error && submitted && !loading && rows.length === 1 && (
        <div className="notice ok">단일 매칭 SKU 1건</div>
      )}

      <div className="table-wrap">
        <table className="sticky zebra">
          <thead>
            <tr>
              <th style={{ minWidth: 200 }}>Selfpia SKU</th>
              <th>Matched code</th>
              <th>상품명</th>
              <th>옵션</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={`${row.sku_id}-${row.matched_code_value}`}>
                <td>
                  <div className="cell-code">
                    <Link to={`/products/${row.sku_id}`} className="mono ellipsis" title={row.selfpia_sku_code}>
                      {row.selfpia_sku_code}
                    </Link>
                    <CopyButton value={row.selfpia_sku_code} />
                  </div>
                </td>
                <td>
                  <div className="cell-code">
                    <CodeSystemBadge value={row.matched_code_system} />
                    <span className="mono ellipsis" title={row.matched_code_value}>{row.matched_code_value}</span>
                    <CopyButton value={row.matched_code_value} />
                  </div>
                </td>
                <td className="ellipsis-2" title={row.product_name}>{row.product_name}</td>
                <td className="ellipsis-2" title={row.option_value}>{row.option_value}</td>
              </tr>
            ))}
            {empty && (
              <tr>
                <td colSpan="4" className="empty">
                  <div>
                    조회 결과가 없습니다.
                    {lastQuery && (
                      <> 검색 조건: <CodeSystemBadge value={lastQuery.system} /> <code>{lastQuery.value}</code>.</>
                    )}
                  </div>
                  <ul className="empty-hints">
                    <li>해당 code value 가 master code_alias 에 적재되지 않았을 수 있습니다.</li>
                    <li>code system 을 잘못 선택했을 수 있습니다 (selfpia_sku ↔ own_sku 등).</li>
                    <li>로컬 seed 가 아닌 운영 코드를 조회하려면 로컬 DB 에 master export 적재가 필요합니다.</li>
                  </ul>
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <p className="hint">
        호출: <code>GET /api/products/skus/by-code/{`{codeSystem}`}/{`{codeValue}`}</code>. ambiguous 결과는 by-code endpoint 가
        SKU 별 1행씩 반환합니다 (같은 alias row 가 여러 개여도 SKU 단위로 dedupe).
      </p>
    </section>
  );
}
