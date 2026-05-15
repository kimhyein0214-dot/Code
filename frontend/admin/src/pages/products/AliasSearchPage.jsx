import React, { useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';

import { productsApi } from '../../api/client.js';
import { CodeSystemBadge } from '../../components/StatusBadge.jsx';
import { CopyButton } from '../../components/CopyButton.jsx';
import { ProductMetaChips } from '../../components/ProductMetaChips.jsx';
import { ProductThumbnail } from '../../components/ProductThumbnail.jsx';

const CODE_SYSTEMS = [
  {
    value: 'all_codes',
    label: '통합 검색',
    shortDescription: '모든 코드에서 찾기',
    description: 'SKU, alias, channel code를 한 번에 넓게 찾습니다.',
    searchMode: 'all'
  },
  {
    value: 'selfpia_sku',
    label: 'Sellpia SKU',
    shortDescription: '1000-1 같은 셀피아 옵션 코드',
    description: '셀피아 SKU 단위 코드입니다. 상품 상세의 기준 SKU와 1:1로 연결됩니다.'
  },
  {
    value: 'selfpia_product',
    label: 'Sellpia 상품코드',
    shortDescription: '옵션을 묶는 셀피아 상품 코드',
    description: '셀피아 상품 단위 코드입니다. 같은 상품 아래 여러 옵션 SKU가 함께 조회될 수 있습니다.'
  },
  {
    value: 'own_sku',
    label: '자사코드',
    shortDescription: 'PA-1-11 같은 내부 자사 코드',
    description: '내부 운영에서 쓰는 자사 옵션 코드입니다. 하나의 코드가 복수 SKU에 연결될 수 있어 검수 대상이 될 수 있습니다.'
  },
  {
    value: 'smartstore_option_no',
    label: 'Smartstore 옵션번호',
    shortDescription: '운영 확정 스마트스토어 옵션번호',
    description: '운영에서 확정된 스마트스토어 옵션번호입니다.'
  },
  {
    value: 'smartstore_option_no_candidate',
    label: 'Smartstore 후보',
    shortDescription: '운영 확정 전 자동 후보값',
    description: '자동 추정된 스마트스토어 후보입니다. 운영 확정값이 아니므로 연결됨으로 보지 않습니다.'
  },
  {
    value: 'makeshop_channel_code',
    label: 'MakeShop 코드',
    shortDescription: '메이크샵 채널 코드',
    description: 'MakeShop channel_sku_code 또는 seller_product_code를 기존 채널 코드 검색 API로 조회합니다.',
    searchMode: 'channel_code'
  }
];

const SEARCH_EXAMPLES = [
  { label: '1258-1', system: 'selfpia_sku', value: '1258-1' },
  { label: '1000-1', system: 'selfpia_sku', value: '1000-1' },
  { label: '11258-1', system: 'selfpia_sku', value: '11258-1' },
  { label: 'PA-1-11', system: 'own_sku', value: 'PA-1-11' },
  { label: 'Smartstore 후보', system: 'smartstore_option_no_candidate', value: '15643191865' },
  { label: 'MakeShop 코드', system: 'makeshop_channel_code', value: '59511-3' },
  { label: 'LOCAL_TEST_PM', system: 'all_codes', value: 'LOCAL_TEST_PM' }
];

const CODE_SYSTEM_LABELS = {
  selfpia_sku: 'Sellpia SKU',
  selfpia_product: 'Sellpia 상품코드',
  own_sku: '자사코드',
  smartstore_option_no: 'Smartstore 옵션번호',
  smartstore_option_no_candidate: 'Smartstore 후보',
  smartstore: 'Smartstore',
  makeshop: 'MakeShop',
  makeshop_sku: 'MakeShop SKU',
  makeshop_channel_code: 'MakeShop 코드',
  channel_code: '채널 코드',
  sku: 'SKU 검색',
  alias: 'Alias',
  all_codes: '통합 검색'
};

function findMeta(systemValue) {
  return CODE_SYSTEMS.find((system) => system.value === systemValue) || CODE_SYSTEMS[0];
}

function codeSystemLabel(codeSystem) {
  return CODE_SYSTEM_LABELS[codeSystem] || codeSystem || 'Matched';
}

function matchedCodeLabel(codeSystem) {
  if (codeSystem === 'smartstore_option_no_candidate') {
    return 'Smartstore 후보';
  }
  if (codeSystem === 'smartstore_option_no' || codeSystem === 'smartstore') {
    return 'Smartstore 옵션번호';
  }
  if (codeSystem === 'own_sku') {
    return '자사코드';
  }
  if (codeSystem === 'selfpia_sku') {
    return 'Sellpia SKU';
  }
  if (codeSystem === 'selfpia_product') {
    return 'Sellpia 상품코드';
  }
  if (codeSystem === 'makeshop_channel_code' || codeSystem === 'makeshop' || codeSystem === 'makeshop_sku') {
    return 'MakeShop 코드';
  }
  if (codeSystem === 'channel_code') {
    return '채널 코드';
  }
  return '검색 코드';
}

function isSmartstoreCandidate(codeSystem) {
  return codeSystem === 'smartstore_option_no_candidate';
}

function firstAliasValue(detail, codeSystem) {
  return detail?.aliases?.find((alias) => alias.code_system === codeSystem)?.code_value || '';
}

function normalizeRows(result, system, searchMode) {
  const data = result.data || [];
  if (searchMode === 'channel_code') {
    return data.map((row) => ({
      ...row,
      matched_code_system: 'makeshop_channel_code',
      matched_code_value: row.matched_value,
      matched_alias_is_primary: null
    }));
  }
  if (searchMode === 'all') {
    return data.map((row) => ({
      ...row,
      matched_code_system: row.result_type || 'all_codes',
      matched_code_value: row.matched_value,
      matched_alias_is_primary: null
    }));
  }
  return data.map((row) => ({
    ...row,
    matched_code_system: row.matched_code_system || system,
    matched_code_value: row.matched_code_value
  }));
}

export function AliasSearchPage() {
  const navigate = useNavigate();
  const [codeSystem, setCodeSystem] = useState('all_codes');
  const [codeValue, setCodeValue] = useState('1258-1');
  const [rows, setRows] = useState([]);
  const [detailsBySkuId, setDetailsBySkuId] = useState({});
  const [detailLoading, setDetailLoading] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [lastQuery, setLastQuery] = useState(null);
  const requestSeq = useRef(0);

  async function hydrateDetails(nextRows, seq) {
    const skuIds = [...new Set(nextRows.map((row) => row.sku_id).filter(Boolean))];
    if (skuIds.length === 0) {
      return;
    }

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
      setDetailLoading(false);
    }
  }

  async function runSearch(nextSystem, nextValue) {
    const q = nextValue.trim();
    const meta = findMeta(nextSystem);
    const seq = requestSeq.current + 1;
    requestSeq.current = seq;
    setError('');
    setLoading(true);
    setDetailLoading(false);
    setSubmitted(true);
    setRows([]);
    setDetailsBySkuId({});
    setLastQuery({ system: nextSystem, value: q });

    try {
      const result =
        meta.searchMode === 'channel_code'
          ? await productsApi.search({ q, type: 'channel_code', limit: 50 })
          : meta.searchMode === 'all'
            ? await productsApi.search({ q, type: 'all', limit: 50 })
            : await productsApi.findByCode(nextSystem, q);
      const nextRows = normalizeRows(result, nextSystem, meta.searchMode);

      if (requestSeq.current !== seq) {
        return;
      }

      setRows(nextRows);
      setLoading(false);
      await hydrateDetails(nextRows, seq);
    } catch (err) {
      if (requestSeq.current !== seq) {
        return;
      }
      setError(err.message);
      setRows([]);
      setDetailsBySkuId({});
    } finally {
      if (requestSeq.current === seq) {
        setLoading(false);
        setDetailLoading(false);
      }
    }
  }

  function onSubmit(event) {
    event.preventDefault();
    runSearch(codeSystem, codeValue);
  }

  function applyExample(example) {
    setCodeSystem(example.system);
    setCodeValue(example.value);
    runSearch(example.system, example.value);
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
          <p>판매처 코드와 자사코드가 어떤 SKU에 연결되는지 read-only로 확인합니다.</p>
        </div>
      </div>

      <section className="section-card alias-search-card" aria-label="Alias 검색 조건">
        <div className="alias-type-grid" role="radiogroup" aria-label="검색 타입">
          {CODE_SYSTEMS.map((system) => {
            const selected = codeSystem === system.value;
            const candidateType = system.value === 'smartstore_option_no_candidate';
            return (
              <button
                key={system.value}
                type="button"
                className={`alias-type-option ${selected ? 'is-selected' : ''} ${candidateType ? 'is-candidate' : ''}`}
                role="radio"
                aria-checked={selected}
                onClick={() => setCodeSystem(system.value)}
              >
                <span className="alias-type-title">
                  {system.label}
                  {candidateType && <span className="status-badge status-candidate">운영 미확정</span>}
                </span>
                <span className="alias-type-description">{system.shortDescription}</span>
              </button>
            );
          })}
        </div>

        <form className="toolbar product-search-toolbar alias-search-form" onSubmit={onSubmit}>
          <input
            value={codeValue}
            onChange={(event) => setCodeValue(event.target.value)}
            placeholder="예: 1258-1, PA-1-11, 59511-3"
            aria-label="Code value"
          />
          <button className="button" type="submit" disabled={loading || codeValue.trim() === ''}>
            {loading ? '조회 중...' : '검색'}
          </button>
        </form>

        <div className="alias-system-help">
          <CodeSystemBadge value={codeSystem} /> {meta.description}
        </div>

        <div className="examples alias-examples">
          <span className="examples-label">예시 검색</span>
          {SEARCH_EXAMPLES.map((example) => (
            <button
              key={`${example.system}-${example.value}`}
              type="button"
              className="chip alias-example-chip"
              onClick={() => applyExample(example)}
              title={`${codeSystemLabel(example.system)} 예시로 검색`}
            >
              <span>{example.label}</span>
              <small>{codeSystemLabel(example.system)}</small>
            </button>
          ))}
        </div>
      </section>

      {error && <div className="notice error">조회 실패: {error}</div>}
      {ambiguous && !error && (
        <div className="notice warn">
          <strong>복수 후보 {rows.length}건</strong> 같은 코드가 여러 SKU에 연결되어 있습니다.
          상세 화면에서 판매처별 코드 요약과 raw alias를 함께 확인하세요.
        </div>
      )}
      {!ambiguous && !error && submitted && !loading && rows.length === 1 && (
        <div className="notice ok">연결 대상 SKU 1건을 찾았습니다.</div>
      )}
      {loading && !error && <div className="notice">alias를 조회하는 중입니다.</div>}

      <div className="alias-result-list" aria-busy={loading || detailLoading}>
        {!loading && rows.map((row) => {
          const detail = detailsBySkuId[row.sku_id];
          const ownSkuCode =
            firstAliasValue(detail, 'own_sku') ||
            (row.matched_code_system === 'own_sku' ? row.matched_code_value : '');
          const selfpiaProductCode = row.selfpia_product_code || detail?.selfpia_product_code;
          const candidate = isSmartstoreCandidate(row.matched_code_system);
          const statusLabel = candidate ? '운영 미확정' : row.matched_alias_is_primary === false ? '보조 alias' : '연결 확인';
          const statusClass = candidate ? 'status-candidate' : row.matched_alias_is_primary === false ? 'status-unmapped' : 'status-connected';

          return (
            <div
              className={`alias-result-row ${candidate ? 'is-candidate' : ''}`}
              role="link"
              tabIndex={0}
              onClick={() => openDetail(row.sku_id)}
              onKeyDown={(event) => onResultKeyDown(event, row.sku_id)}
              key={`${row.sku_id}-${row.matched_code_system}-${row.matched_code_value}`}
            >
              <ProductThumbnail
                src={row.thumbnail_url || row.image_url}
                alt={row.product_name || row.selfpia_sku_code}
                size="sm"
              />
              <div className="alias-result-main">
                <div className="alias-result-title-row">
                  <div className="alias-result-title-wrap">
                    <strong className="alias-result-title" title={row.product_name}>{row.product_name || '상품명 없음'}</strong>
                    <span className="alias-result-option" title={row.option_value}>{row.option_value || '옵션 정보 없음'}</span>
                  </div>
                  <div className="alias-result-badges">
                    <CodeSystemBadge value={row.matched_code_system} />
                    <span className={`status-badge ${statusClass}`}>{statusLabel}</span>
                  </div>
                </div>

                <div className="alias-match-summary">
                  <span className="alias-match-label">{matchedCodeLabel(row.matched_code_system)}</span>
                  <strong className="alias-match-value mono" title={String(row.matched_code_value || '')}>
                    {row.matched_code_value || '값 없음'}
                  </strong>
                  <CopyButton value={row.matched_code_value} label="복사" />
                </div>

                {candidate && (
                  <p className="alias-candidate-note">
                    자동 후보 / 운영 미확정 값입니다. 확정 Smartstore 옵션번호처럼 사용하지 마세요.
                  </p>
                )}

                <ProductMetaChips
                  items={[
                    { key: 'selfpia_sku_code', value: row.selfpia_sku_code },
                    { key: 'selfpia_product_code', value: selfpiaProductCode },
                    { key: 'own_sku_code', value: ownSkuCode },
                    { key: 'virtual_sku_code', value: row.virtual_sku_code }
                  ]}
                />
              </div>
              <div className="alias-result-actions" aria-hidden="true">
                <span className="button-subtle detail-button">상세 보기</span>
              </div>
            </div>
          );
        })}

        {empty && (
          <div className="empty-state alias-empty-state">
            <strong>연결된 SKU를 찾지 못했습니다.</strong>
            <p>
              {lastQuery && (
                <>
                  검색 조건: <CodeSystemBadge value={lastQuery.system} /> <code>{lastQuery.value}</code>
                </>
              )}
            </p>
            <ul className="empty-hints">
              <li>Sellpia SKU, Sellpia 상품코드, 자사코드, Smartstore 옵션번호, MakeShop 코드로 검색할 수 있습니다.</li>
              <li>Smartstore 후보는 `Smartstore 후보` code system에서 별도로 확인합니다.</li>
              <li>MakeShop 코드는 channel_sku_code 또는 seller_product_code 기준의 채널 코드 검색입니다.</li>
            </ul>
          </div>
        )}
      </div>

      <p className="hint">
        호출: alias는 <code>GET /api/products/skus/by-code/{`{codeSystem}`}/{`{codeValue}`}</code>,
        MakeShop/통합 검색은 기존 <code>GET /api/products/search</code>를 사용합니다.
      </p>
    </section>
  );
}
