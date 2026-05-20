import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';

import { manualReviewApi } from '../../api/client.js';

const DEFAULT_LIMIT = 50;

const FILTERS = [
  { key: 'channel_code', label: '채널' },
  { key: 'risk_type', label: '리스크 유형' },
  { key: 'evidence_level', label: '근거 수준' },
  { key: 'review_scope', label: '검토 범위' },
  { key: 'suggested_action', label: '권장 확인' }
];

const SUMMARY_DIMENSION_BY_FILTER = {
  channel_code: 'by_channel_code',
  risk_type: 'by_risk_type',
  evidence_level: 'by_evidence_level',
  review_scope: 'by_review_scope',
  suggested_action: 'by_suggested_action'
};

const REVIEW_SCOPE_LABELS = {
  manual_matching_candidate: '수동매칭 후보',
  deletion_or_inactive_review_candidate: '삭제/비활성 검토 후보'
};

const RISK_TYPE_LABELS = {
  source_conflict: '소스 충돌',
  warning_bucket: '소스 경고',
  duplicate_sku: '중복 SKU',
  narrow_risk: '옵션 주의',
  evidence_missing: '근거 부족',
  channel_absent_or_inactive_possible: '비활성 가능',
  existing_conflict: '기존 매핑 충돌',
  manual_review_required: '수동 확인'
};

const EVIDENCE_LEVEL_LABELS = {
  direct: '직접',
  unique: '단일',
  duplicate: '중복',
  missing: '없음',
  source_conflict: '충돌',
  needs_review: '확인 필요'
};

const ACTION_LABELS = {
  classify_channel_absent_or_inactive: '삭제/비활성 여부 검토',
  compare_conflicting_candidates: '충돌 후보 비교',
  inspect_source_warning: '소스 경고 확인',
  compare_duplicate_candidates: '중복 후보 비교',
  manual_option_risk_review: '옵션 리스크 검토',
  find_or_mark_missing_evidence: '근거 찾기',
  do_not_overwrite_existing_mapping: '기존 매핑 보존',
  manual_match_review: '수동 매칭 검토'
};

const SOURCE_STATUS_LABELS = {
  active_candidate: '활성 후보',
  inactive_possible: '비활성 가능',
  unknown: '상태 미상'
};

function labelFor(value, labels = {}) {
  if (value === undefined || value === null || value === '') {
    return '-';
  }
  return labels[value] || String(value);
}

function compactText(value) {
  return value === undefined || value === null || value === '' ? '-' : String(value);
}

function numericParam(value, fallback) {
  const numeric = Number(value || fallback);
  if (!Number.isFinite(numeric) || numeric < 0) {
    return fallback;
  }
  return Math.trunc(numeric);
}

function queryFromSearchParams(searchParams) {
  return {
    channel_code: searchParams.get('channel_code') || '',
    risk_type: searchParams.get('risk_type') || '',
    evidence_level: searchParams.get('evidence_level') || '',
    review_scope: searchParams.get('review_scope') || '',
    suggested_action: searchParams.get('suggested_action') || '',
    search: searchParams.get('search') || '',
    limit: numericParam(searchParams.get('limit'), DEFAULT_LIMIT),
    offset: numericParam(searchParams.get('offset'), 0)
  };
}

function toApiQuery(query) {
  return Object.fromEntries(
    Object.entries(query).filter(([, value]) => value !== undefined && value !== null && value !== '')
  );
}

function countFor(summary, dimension, value) {
  return summary?.[dimension]?.find((row) => row.value === value)?.count || 0;
}

function SummaryMetric({ label, value, tone = '' }) {
  return (
    <div className={`manual-summary-metric ${tone}`}>
      <span>{label}</span>
      <strong>{Number(value || 0).toLocaleString()}</strong>
    </div>
  );
}

function DistributionList({ title, rows, labels }) {
  return (
    <div className="manual-distribution">
      <h3>{title}</h3>
      <div className="manual-distribution-list">
        {(rows || []).map((row) => (
          <div className="manual-distribution-row" key={`${title}-${row.value}`}>
            <span title={row.value}>{labelFor(row.value, labels)}</span>
            <strong>{Number(row.count || 0).toLocaleString()}</strong>
          </div>
        ))}
      </div>
    </div>
  );
}

function ScopeBadge({ value }) {
  const isInactiveReview = value === 'deletion_or_inactive_review_candidate';
  return (
    <span className={`manual-scope-badge ${isInactiveReview ? 'is-inactive-review' : 'is-manual-match'}`}>
      {labelFor(value, REVIEW_SCOPE_LABELS)}
    </span>
  );
}

function TinyBadge({ value, labels, tone = '' }) {
  return <span className={`manual-tiny-badge ${tone}`}>{labelFor(value, labels)}</span>;
}

function CandidateDetailPanel({ candidate, detail, loading, error }) {
  const row = detail || candidate;

  return (
    <div className="manual-detail-panel">
      {loading && <div className="notice">상세 정보를 불러오는 중입니다.</div>}
      {error && <div className="notice error">상세 조회 실패: {error}</div>}
      {!loading && !error && (
        <>
          <dl className="manual-detail-grid">
            <div>
              <dt>source_file_name</dt>
              <dd>{compactText(row.source_file_name)}</dd>
            </div>
            <div>
              <dt>source_row_no</dt>
              <dd>{compactText(row.source_row_no)}</dd>
            </div>
            <div>
              <dt>normalized_sale_status</dt>
              <dd>{compactText(row.normalized_sale_status)}</dd>
            </div>
            <div>
              <dt>normalized_display_status</dt>
              <dd>{compactText(row.normalized_display_status)}</dd>
            </div>
            <div>
              <dt>normalized_option_status</dt>
              <dd>{compactText(row.normalized_option_status)}</dd>
            </div>
            <div>
              <dt>image_status</dt>
              <dd>{compactText(row.image_status)}</dd>
            </div>
            <div>
              <dt>reviewer_decision_placeholder</dt>
              <dd>{compactText(row.reviewer_decision_placeholder)}</dd>
            </div>
            <div>
              <dt>reviewer_note_placeholder</dt>
              <dd>{compactText(row.reviewer_note_placeholder)}</dd>
            </div>
          </dl>

          <div className="manual-risk-reason">
            <span>risk_reason</span>
            <p>{compactText(row.risk_reason)}</p>
          </div>

          <div className="manual-disabled-actions" aria-label="저장 기능 없음">
            <button type="button" disabled>승인 준비중</button>
            <button type="button" disabled>보류 준비중</button>
            <button type="button" disabled>제외 준비중</button>
            <span>read-only v1에서는 검수 결과를 저장하지 않습니다.</span>
          </div>
        </>
      )}
    </div>
  );
}

export function ManualReviewWorkbenchPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const searchParamKey = searchParams.toString();
  const query = useMemo(() => queryFromSearchParams(searchParams), [searchParamKey]);
  const [searchInput, setSearchInput] = useState(query.search);
  const [summary, setSummary] = useState(null);
  const [summaryError, setSummaryError] = useState('');
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [expandedId, setExpandedId] = useState('');
  const [detailsById, setDetailsById] = useState({});
  const [detailLoadingId, setDetailLoadingId] = useState('');
  const [detailErrors, setDetailErrors] = useState({});
  const requestSeq = useRef(0);

  useEffect(() => {
    setSearchInput(query.search);
  }, [query.search]);

  useEffect(() => {
    let cancelled = false;

    async function loadSummary() {
      try {
        const result = await manualReviewApi.getSummary();
        if (!cancelled) {
          setSummary(result.data || null);
        }
      } catch (err) {
        if (!cancelled) {
          setSummaryError(err.message);
        }
      }
    }

    loadSummary();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    const seq = requestSeq.current + 1;
    requestSeq.current = seq;
    setLoading(true);
    setError('');

    manualReviewApi.listCandidates(toApiQuery(query))
      .then((result) => {
        if (requestSeq.current !== seq) return;
        setRows(result.data || []);
        setExpandedId('');
      })
      .catch((err) => {
        if (requestSeq.current !== seq) return;
        setError(err.message);
        setRows([]);
      })
      .finally(() => {
        if (requestSeq.current === seq) {
          setLoading(false);
        }
      });
  }, [query]);

  function updateQuery(updates) {
    const next = new URLSearchParams(searchParams);
    Object.entries(updates).forEach(([key, value]) => {
      if (value === undefined || value === null || value === '') {
        next.delete(key);
      } else {
        next.set(key, String(value));
      }
    });
    next.set('limit', String(query.limit || DEFAULT_LIMIT));
    setSearchParams(next);
  }

  function updateFilter(key, value) {
    updateQuery({ [key]: value, offset: 0 });
  }

  function applySearch(event) {
    event.preventDefault();
    updateQuery({ search: searchInput.trim(), offset: 0 });
  }

  function resetFilters() {
    setSearchParams({ limit: String(DEFAULT_LIMIT), offset: '0' });
  }

  async function toggleDetail(candidate) {
    if (expandedId === candidate.review_candidate_id) {
      setExpandedId('');
      return;
    }

    const id = candidate.review_candidate_id;
    setExpandedId(id);
    if (detailsById[id] || detailLoadingId === id) {
      return;
    }

    setDetailLoadingId(id);
    setDetailErrors((current) => ({ ...current, [id]: '' }));
    try {
      const result = await manualReviewApi.getCandidate(id);
      setDetailsById((current) => ({ ...current, [id]: result.data || candidate }));
    } catch (err) {
      setDetailErrors((current) => ({ ...current, [id]: err.message }));
    } finally {
      setDetailLoadingId('');
    }
  }

  const manualMatchCount = countFor(summary, 'by_review_scope', 'manual_matching_candidate');
  const inactiveReviewCount = countFor(summary, 'by_review_scope', 'deletion_or_inactive_review_candidate');
  const hasPrevious = query.offset > 0;
  const hasNext = rows.length === query.limit;
  const activeFilterCount = FILTERS.filter((filter) => query[filter.key]).length + (query.search ? 1 : 0);

  return (
    <section className="page manual-review-page">
      <div className="page-header">
        <div>
          <h1>수동검수 워크벤치</h1>
          <p>자동매칭 후 남은 후보를 읽기 전용으로 확인하는 v1 화면입니다.</p>
        </div>
        <button className="button disabled" type="button" disabled title="read-only v1: 저장 기능 없음">
          저장 기능 없음
        </button>
      </div>

      <div className="readonly-banner readonly-banner-strong" role="note">
        <strong>READ-ONLY</strong> 저장, 승인, 보류, 제외 처리 기능은 없습니다. 이 화면은
        <code> GET </code> API만 호출하며 검수 결과를 저장하지 않습니다.
      </div>

      {summaryError && <div className="notice error">Summary 조회 실패: {summaryError}</div>}

      <section className="manual-summary-grid" aria-label="수동검수 요약">
        <SummaryMetric label="전체 후보" value={summary?.total_count} tone="is-total" />
        <SummaryMetric label="수동매칭 후보" value={manualMatchCount} tone="is-manual-match" />
        <SummaryMetric label="삭제/비활성 검토 후보" value={inactiveReviewCount} tone="is-inactive-review" />
        <DistributionList title="채널별" rows={summary?.by_channel_code} />
        <DistributionList title="리스크 유형별" rows={summary?.by_risk_type} labels={RISK_TYPE_LABELS} />
      </section>

      <section className="section-card manual-filter-card" aria-label="수동검수 필터">
        <div className="panel-header">
          <div>
            <h2>필터</h2>
            <p className="hint">필터 변경 시 GET query param으로 후보 목록을 다시 조회합니다.</p>
          </div>
          <button className="button-subtle" type="button" onClick={resetFilters} disabled={activeFilterCount === 0}>
            필터 초기화
          </button>
        </div>

        <div className="manual-filter-grid">
          {FILTERS.map((filter) => (
            <label key={filter.key}>
              <span>{filter.label}</span>
              <select value={query[filter.key]} onChange={(event) => updateFilter(filter.key, event.target.value)}>
                <option value="">전체</option>
                {(summary?.[SUMMARY_DIMENSION_BY_FILTER[filter.key]] || []).map((row) => (
                  <option key={row.value} value={row.value}>
                    {labelFor(
                      row.value,
                      filter.key === 'review_scope'
                        ? REVIEW_SCOPE_LABELS
                        : filter.key === 'risk_type'
                          ? RISK_TYPE_LABELS
                          : filter.key === 'evidence_level'
                            ? EVIDENCE_LEVEL_LABELS
                            : filter.key === 'suggested_action'
                              ? ACTION_LABELS
                              : {}
                    )} ({Number(row.count || 0).toLocaleString()})
                  </option>
                ))}
              </select>
            </label>
          ))}

          <form className="manual-search-form" onSubmit={applySearch}>
            <label>
              <span>검색어</span>
              <input
                value={searchInput}
                onChange={(event) => setSearchInput(event.target.value)}
                placeholder="상품명, 옵션명, SKU, 채널 코드"
              />
            </label>
            <button className="button" type="submit" disabled={loading}>
              검색
            </button>
          </form>
        </div>

        <div className="filter-summary">
          <span>limit {query.limit}</span>
          <span>offset {query.offset}</span>
          <span>현재 페이지 {rows.length}건</span>
          {activeFilterCount > 0 && <span>활성 필터 {activeFilterCount}개</span>}
        </div>
      </section>

      {error && <div className="notice error">후보 조회 실패: {error}</div>}
      {loading && !error && <div className="notice">수동검수 후보를 불러오는 중입니다.</div>}

      <section className="manual-list" aria-busy={loading}>
        {!loading && rows.map((candidate) => {
          const expanded = expandedId === candidate.review_candidate_id;
          return (
            <article
              className={`manual-candidate-row ${expanded ? 'is-expanded' : ''}`}
              key={candidate.review_candidate_id}
            >
              <button
                className="manual-candidate-main"
                type="button"
                onClick={() => toggleDetail(candidate)}
                aria-expanded={expanded}
              >
                <div className="manual-candidate-topline">
                  <ScopeBadge value={candidate.review_scope} />
                  <TinyBadge value={candidate.channel_code} tone="is-channel" />
                  <TinyBadge value={candidate.risk_type} labels={RISK_TYPE_LABELS} tone="is-risk" />
                  <TinyBadge value={candidate.evidence_level} labels={EVIDENCE_LEVEL_LABELS} />
                  <TinyBadge value={candidate.source_status} labels={SOURCE_STATUS_LABELS} />
                </div>

                <div className="manual-candidate-products">
                  <div>
                    <span>채널 상품</span>
                    <strong title={compactText(candidate.product_name_channel)}>
                      {compactText(candidate.product_name_channel)}
                    </strong>
                    <em title={compactText(candidate.option_name_channel)}>
                      {compactText(candidate.option_name_channel)}
                    </em>
                  </div>
                  <div>
                    <span>Selfpia 후보</span>
                    <strong title={compactText(candidate.product_name_selfpia)}>
                      {compactText(candidate.product_name_selfpia)}
                    </strong>
                    <em title={compactText(candidate.option_name_selfpia)}>
                      {compactText(candidate.option_name_selfpia)}
                    </em>
                  </div>
                </div>

                <div className="manual-code-grid">
                  <span><b>channel_product</b>{compactText(candidate.channel_product_code)}</span>
                  <span><b>channel_option</b>{compactText(candidate.channel_option_code)}</span>
                  <span><b>seller_product</b>{compactText(candidate.seller_product_code)}</span>
                  <span><b>own_sku_candidate</b>{compactText(candidate.own_sku_code_candidate)}</span>
                  <span><b>selfpia_sku_candidate</b>{compactText(candidate.selfpia_sku_candidate)}</span>
                  <span><b>action</b>{labelFor(candidate.suggested_action, ACTION_LABELS)}</span>
                </div>
              </button>

              {expanded && (
                <CandidateDetailPanel
                  candidate={candidate}
                  detail={detailsById[candidate.review_candidate_id]}
                  loading={detailLoadingId === candidate.review_candidate_id}
                  error={detailErrors[candidate.review_candidate_id]}
                />
              )}
            </article>
          );
        })}

        {!loading && rows.length === 0 && !error && (
          <div className="empty-state">
            <strong>조회된 후보가 없습니다.</strong>
            <p>필터를 줄이거나 검색어를 비워 다시 조회해 주세요.</p>
          </div>
        )}
      </section>

      <div className="manual-pagination" aria-label="페이지 이동">
        <button
          className="button-subtle"
          type="button"
          disabled={!hasPrevious || loading}
          onClick={() => updateQuery({ offset: Math.max(0, query.offset - query.limit) })}
        >
          이전
        </button>
        <span>{query.offset + 1} - {query.offset + rows.length}</span>
        <button
          className="button-subtle"
          type="button"
          disabled={!hasNext || loading}
          onClick={() => updateQuery({ offset: query.offset + query.limit })}
        >
          다음
        </button>
      </div>
    </section>
  );
}
