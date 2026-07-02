import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';

import { manualReviewApi } from '../../api/client.js';

const DEFAULT_LIMIT = 50;

const FILTERS = [
  { key: 'channel_code', label: '채널' },
  { key: 'risk_type', label: '위험유형' },
  { key: 'evidence_level', label: '근거수준' },
  { key: 'suggested_action', label: '추천 검토 방향' }
];

const SUMMARY_DIMENSION_BY_FILTER = {
  channel_code: 'by_channel_code',
  risk_type: 'by_risk_type',
  evidence_level: 'by_evidence_level',
  suggested_action: 'by_suggested_action'
};

const REVIEW_SCOPE_META = {
  manual_matching_candidate: {
    label: '수동매칭 후보',
    shortLabel: '수동매칭',
    description: '운영 중인 채널 상품을 어떤 Selfpia SKU와 연결할지 사람이 확인해야 하는 후보입니다.'
  },
  deletion_or_inactive_review_candidate: {
    label: '삭제/비활성 검토 후보',
    shortLabel: '삭제/비활성 검토',
    description: '삭제 처리로 단정하지 않고, 채널에서 비활성/미운영 상태인지 따로 분류해야 하는 후보입니다.'
  }
};

const RISK_TYPE_META = {
  source_conflict: {
    label: '소스 충돌',
    description: '같은 채널 근거가 서로 다른 SKU 또는 상품 후보를 가리킵니다.'
  },
  warning_bucket: {
    label: '소스 경고',
    description: '파싱 경고, 채널 상품 코드 누락 등 원천 데이터 확인이 필요합니다.'
  },
  duplicate_sku: {
    label: '중복 SKU',
    description: '채널 SKU 코드가 중복되어 자동확정에서 제외되었습니다.'
  },
  narrow_risk: {
    label: '옵션 주의',
    description: 'AB, 세트, 수량, 유사 옵션 등 사람이 옵션 차이를 확인해야 합니다.'
  },
  evidence_missing: {
    label: '근거 부족',
    description: 'Selfpia 또는 자사 SKU 후보가 로컬 SKU와 유일하게 연결되지 않았습니다.'
  },
  channel_absent_or_inactive_possible: {
    label: '비활성 가능',
    description: '판매중지, 숨김, 품절, 미노출 등 현재 운영 후보가 아닐 수 있습니다.'
  },
  existing_conflict: {
    label: '기존 매핑 충돌',
    description: '기존 alias 또는 채널 매핑과 충돌할 수 있어 덮어쓰면 안 됩니다.'
  },
  manual_review_required: {
    label: '수동 확인',
    description: '자동확정 조건을 통과하지 못해 사람이 확인해야 합니다.'
  }
};

const EVIDENCE_LEVEL_META = {
  direct: { label: '직접', description: 'Selfpia SKU 근거가 직접 연결된 후보입니다.' },
  unique: { label: '단일', description: '근거가 하나의 SKU 후보로 좁혀졌습니다.' },
  duplicate: { label: '중복', description: '근거가 중복되어 자동확정할 수 없습니다.' },
  missing: { label: '없음', description: '로컬 SKU 근거가 부족합니다.' },
  source_conflict: { label: '충돌', description: '원천 데이터가 서로 충돌합니다.' },
  needs_review: { label: '확인 필요', description: '자동 판단 대신 사람이 봐야 합니다.' }
};

const ACTION_META = {
  classify_channel_absent_or_inactive: {
    label: '삭제/비활성 여부 검토',
    description: '현재 운영 대상인지, 비활성 후보로 분리할지 확인합니다.'
  },
  compare_conflicting_candidates: {
    label: '충돌 후보 비교',
    description: '서로 다른 SKU/상품 후보 중 어떤 근거가 맞는지 비교합니다.'
  },
  inspect_source_warning: {
    label: '소스 경고 확인',
    description: '원천 파일의 경고나 누락된 키를 먼저 확인합니다.'
  },
  compare_duplicate_candidates: {
    label: '중복 후보 비교',
    description: '중복된 채널 SKU 또는 중복 근거를 나란히 비교합니다.'
  },
  manual_option_risk_review: {
    label: '옵션 리스크 검토',
    description: '옵션명, 수량, 세트 여부가 실제 같은 상품인지 확인합니다.'
  },
  find_or_mark_missing_evidence: {
    label: '근거 찾기',
    description: '맞는 SKU를 찾거나 근거 부족 후보로 유지합니다.'
  },
  do_not_overwrite_existing_mapping: {
    label: '기존 매핑 보존',
    description: '이미 있는 매핑을 덮어쓰지 않도록 충돌 여부를 확인합니다.'
  },
  manual_match_review: {
    label: '수동 매칭 검토',
    description: '사람이 Selfpia SKU 후보를 최종 비교합니다.'
  }
};

const SOURCE_STATUS_META = {
  active_candidate: { label: '활성 후보' },
  inactive_possible: { label: '비활성 가능' },
  unknown: { label: '상태 미상' }
};

const RISK_REASON_SUMMARY = {
  source_conflict: '여러 후보와 근거가 겹쳐 자동 확정하기 어렵습니다.',
  warning_bucket: '원천 데이터 경고 또는 주의 조건이 있어 확인이 필요합니다.',
  narrow_risk: '색상, 옵션, 수량 조건이 좁게 갈려 오매칭 위험이 있습니다.',
  evidence_missing: '자동 판단에 필요한 SKU 근거가 부족합니다.',
  channel_absent_or_inactive_possible: '판매처에 없거나 비활성 상태일 수 있어 운영 여부 확인이 필요합니다.',
  duplicate_sku: '동일하거나 유사한 SKU 후보가 중복되어 확인이 필요합니다.',
  existing_conflict: '기존 매핑과 충돌할 수 있어 덮어쓰기 전 확인이 필요합니다.',
  manual_review_required: '자동확정 조건을 통과하지 못해 사람이 확인해야 합니다.'
};

const PRIORITY_META = {
  urgent: { label: '우선 확인', description: '자동확정에서 가장 먼저 분리해 봐야 하는 후보입니다.' },
  caution: { label: '주의 확인', description: '옵션, 원천 경고, 주의 조건을 사람이 확인해야 합니다.' },
  operation: { label: '운영 여부 확인', description: '삭제 처리로 단정하지 말고 현재 운영 상태를 확인해야 합니다.' },
  duplicate: { label: '중복 확인', description: '중복 근거 또는 중복 SKU를 비교해야 합니다.' },
  normal: { label: '일반 확인', description: '사람이 검토해야 하는 후보입니다.' }
};

const CHANNEL_LABELS = {
  ably: 'Ably',
  smartstore: 'Smartstore',
  coupang: 'Coupang',
  kakaotalk_store: 'Kakaotalk Store'
};

function metaLabel(value, metaMap = {}) {
  if (value === undefined || value === null || value === '') {
    return '-';
  }
  return metaMap[value]?.label || CHANNEL_LABELS[value] || String(value);
}

function metaDescription(value, metaMap = {}) {
  return metaMap[value]?.description || '';
}

function compactText(value) {
  return value === undefined || value === null || value === '' ? '-' : String(value);
}

function isInactiveReviewScope(value) {
  return value === 'deletion_or_inactive_review_candidate';
}

function priorityFor(row) {
  if (row.risk_type === 'source_conflict' || row.risk_type === 'evidence_missing') {
    return 'urgent';
  }
  if (row.risk_type === 'narrow_risk' || row.risk_type === 'warning_bucket') {
    return 'caution';
  }
  if (row.risk_type === 'channel_absent_or_inactive_possible' || isInactiveReviewScope(row.review_scope)) {
    return 'operation';
  }
  if (row.risk_type === 'duplicate_sku') {
    return 'duplicate';
  }
  return 'normal';
}

function riskReasonSummary(row) {
  return RISK_REASON_SUMMARY[row.risk_type] || metaDescription(row.risk_type, RISK_TYPE_META) || compactText(row.risk_reason);
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

function SummaryMetric({ label, value, description, tone = '' }) {
  return (
    <div className={`manual-summary-metric ${tone}`}>
      <span>{label}</span>
      <strong>{Number(value || 0).toLocaleString()}</strong>
      {description && <p>{description}</p>}
    </div>
  );
}

function DistributionList({ title, rows, metaMap }) {
  return (
    <div className="manual-distribution">
      <h3>{title}</h3>
      <div className="manual-distribution-list">
        {(rows || []).map((row) => (
          <div className="manual-distribution-row" key={`${title}-${row.value}`}>
            <span title={row.value}>{metaLabel(row.value, metaMap)}</span>
            <strong>{Number(row.count || 0).toLocaleString()}</strong>
          </div>
        ))}
      </div>
    </div>
  );
}

function ScopeBadge({ value }) {
  const isInactiveReview = isInactiveReviewScope(value);
  return (
    <span className={`manual-scope-badge ${isInactiveReview ? 'is-inactive-review' : 'is-manual-match'}`}>
      {metaLabel(value, REVIEW_SCOPE_META)}
    </span>
  );
}

function TinyBadge({ value, metaMap, tone = '' }) {
  return <span className={`manual-tiny-badge ${tone}`}>{metaLabel(value, metaMap)}</span>;
}

function PriorityBadge({ row }) {
  const priority = priorityFor(row);
  const meta = PRIORITY_META[priority];
  return (
    <span className={`manual-priority-badge is-${priority}`} title={meta.description}>
      {meta.label}
    </span>
  );
}

function FieldPill({ label, value, featured = false }) {
  return (
    <span className={`manual-field-pill ${featured ? 'is-featured' : ''}`}>
      <b>{label}</b>
      <em title={compactText(value)}>{compactText(value)}</em>
    </span>
  );
}

function DetailGroup({ title, children }) {
  return (
    <section className="manual-detail-group">
      <h3>{title}</h3>
      {children}
    </section>
  );
}

function DetailItem({ label, value }) {
  return (
    <div className="manual-detail-item">
      <dt>{label}</dt>
      <dd>{compactText(value)}</dd>
    </div>
  );
}

function CompareCard({ title, eyebrow, productName, optionName, fields = [], tone = '' }) {
  return (
    <article className={`manual-compare-card ${tone}`}>
      <div className="manual-compare-card-head">
        <span>{eyebrow}</span>
        <strong>{title}</strong>
      </div>
      <div className="manual-compare-product">
        <strong title={compactText(productName)}>{compactText(productName)}</strong>
        <em title={compactText(optionName)}>{compactText(optionName)}</em>
      </div>
      <div className="manual-code-grid is-compact">
        {fields.map((field) => (
          <FieldPill key={field.label} label={field.label} value={field.value} featured={field.featured} />
        ))}
      </div>
    </article>
  );
}

function ManualQueueItem({ candidate, selected, onSelect }) {
  const sourceConflict = candidate.risk_type === 'source_conflict';
  const inactiveReview = isInactiveReviewScope(candidate.review_scope);
  return (
    <button
      type="button"
      className={`manual-queue-item ${selected ? 'is-selected' : ''} ${sourceConflict ? 'is-source-conflict' : ''} ${inactiveReview ? 'is-inactive-review' : ''}`}
      onClick={onSelect}
    >
      <span className="manual-queue-item-topline">
        <PriorityBadge row={candidate} />
        <TinyBadge value={candidate.channel_code} tone="is-channel" />
        <TinyBadge value={candidate.risk_type} metaMap={RISK_TYPE_META} tone="is-risk" />
      </span>
      <strong title={compactText(candidate.product_name_channel)}>
        {compactText(candidate.product_name_channel)}
      </strong>
      <em title={compactText(candidate.option_name_channel)}>
        {compactText(candidate.option_name_channel)}
      </em>
      <span className="manual-queue-item-meta">
        <span>{metaLabel(candidate.review_scope, REVIEW_SCOPE_META)}</span>
        <span>{metaLabel(candidate.suggested_action, ACTION_META)}</span>
      </span>
    </button>
  );
}

function ManualSelectedOverview({ row }) {
  if (!row) {
    return (
      <div className="empty-state">
        <strong>선택된 후보가 없습니다.</strong>
        <p>왼쪽 검수 큐에서 후보를 선택해 주세요.</p>
      </div>
    );
  }

  const riskDescription = metaDescription(row.risk_type, RISK_TYPE_META);
  const evidenceDescription = metaDescription(row.evidence_level, EVIDENCE_LEVEL_META);
  const actionDescription = metaDescription(row.suggested_action, ACTION_META);

  return (
    <>
      {isInactiveReviewScope(row.review_scope) && <InactiveReviewNotice />}
      <div className="manual-compare-card-grid">
        <CompareCard
          eyebrow="판매처 정보"
          title={metaLabel(row.channel_code)}
          productName={row.product_name_channel}
          optionName={row.option_name_channel}
          fields={[
            { label: '상품코드', value: row.channel_product_code, featured: true },
            { label: '옵션코드', value: row.channel_option_code, featured: true },
            { label: '채널 SKU', value: row.channel_sku_code },
            { label: '판매자 상품', value: row.seller_product_code }
          ]}
        />
        <CompareCard
          eyebrow="Selfpia 후보"
          title={compactText(row.selfpia_sku_candidate || row.selfpia_sku_code)}
          productName={row.product_name_selfpia}
          optionName={row.option_name_selfpia}
          tone="is-sellpia"
          fields={[
            { label: 'Selfpia 상품', value: row.selfpia_product_code },
            { label: 'Selfpia SKU', value: row.selfpia_sku_candidate || row.selfpia_sku_code, featured: true },
            { label: '자사 SKU 후보', value: row.own_sku_code_candidate },
            { label: '로컬 자사 SKU', value: row.own_sku_code }
          ]}
        />
      </div>

      <section className="manual-evidence-panel">
        <div className="manual-panel-title">
          <span>검수 근거</span>
          <h2>왜 사람이 봐야 하는가</h2>
        </div>
        <div className="manual-evidence-cards">
          <div className="manual-explain-card is-risk">
            <span>위험유형</span>
            <strong>{metaLabel(row.risk_type, RISK_TYPE_META)}</strong>
            <p>{riskDescription || riskReasonSummary(row)}</p>
          </div>
          <div className="manual-explain-card">
            <span>근거수준</span>
            <strong>{metaLabel(row.evidence_level, EVIDENCE_LEVEL_META)}</strong>
            <p>{evidenceDescription || compactText(row.evidence_level)}</p>
          </div>
          <div className="manual-explain-card">
            <span>추천 검토 방향</span>
            <strong>{metaLabel(row.suggested_action, ACTION_META)}</strong>
            <p>{actionDescription || compactText(row.suggested_action)}</p>
          </div>
        </div>
        <div className="manual-risk-reason">
          <span>한글 요약</span>
          <strong>{riskReasonSummary(row)}</strong>
          <span>risk_reason 원문</span>
          <p>{compactText(row.risk_reason)}</p>
        </div>
      </section>
    </>
  );
}

const DECISION_ACTION_LABELS = {
  auto_approve: '자동승인 후보 확정',
  manual_link: '수동 연동',
  unlink: '연동 끊기',
  discontinue: '단종시키기'
};

const DECISION_STATUS_LABELS = {
  approve_match: '매칭 승인',
  hold: '보류',
  exclude_candidate: '후보 제외',
  inactive_reviewed: '비활성/단종 검토 완료',
  needs_source_fix: '소스 보정 필요'
};

function formatDateTime(value) {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return date.toLocaleString('ko-KR', { hour12: false });
}

function ManualDecisionPanel({
  row,
  loading,
  reviewer,
  onReviewerChange,
  onSaveDecision,
  savingAction,
  saveMessage,
  savedDecision
}) {
  const priority = row ? PRIORITY_META[priorityFor(row)] : null;
  const disabled = !row || !reviewer.trim() || Boolean(savingAction);
  return (
    <aside className="manual-decision-panel">
      <div className="manual-panel-title">
        <span>결정 패널</span>
        <h2>선택 행 처리</h2>
      </div>
      <div className="manual-reviewer-card">
        <label>
          <span>검수자</span>
          <input
            value={reviewer}
            onChange={(event) => onReviewerChange(event.target.value)}
            placeholder="검수자 이름"
          />
        </label>
        <p>결정은 local/test DB의 수동검수 결정 테이블에만 저장됩니다. 운영 매핑/삭제는 바로 적용하지 않습니다.</p>
      </div>
      <div className="manual-decision-actions">
        {Object.entries(DECISION_ACTION_LABELS).map(([action, label]) => (
          <button
            key={action}
            type="button"
            disabled={disabled}
            onClick={() => onSaveDecision(action)}
          >
            {savingAction === action ? '저장 중...' : label}
          </button>
        ))}
      </div>
      <div className="manual-impact-card">
        <span>처리 영향</span>
        {row ? (
          <>
            <strong>{priority?.label || '검토 필요'}</strong>
            <p>{priority?.description || '선택한 후보의 검토 방향을 확인하세요.'}</p>
            <dl>
              <DetailItem label="검토 범위" value={metaLabel(row.review_scope, REVIEW_SCOPE_META)} />
              <DetailItem label="추천 액션" value={metaLabel(row.suggested_action, ACTION_META)} />
              <DetailItem label="소스 상태" value={metaLabel(row.source_status, SOURCE_STATUS_META)} />
            </dl>
          </>
        ) : (
          <p>후보를 선택하면 처리 영향이 표시됩니다.</p>
        )}
      </div>
      {savedDecision && (
        <div className="manual-saved-card">
          <span>최근 저장</span>
          <strong>{DECISION_ACTION_LABELS[savedDecision.decision_reason] || DECISION_STATUS_LABELS[savedDecision.decision_status] || savedDecision.decision_status}</strong>
          <p>{formatDateTime(savedDecision.decided_at)} · {savedDecision.reviewer}</p>
        </div>
      )}
      <div className="manual-write-status">
        {savingAction
          ? 'DB에 결정 기록을 저장하는 중입니다.'
          : saveMessage || (loading ? '상세 정보 조회 중...' : '아직 저장된 작업이 없습니다.')}
      </div>
    </aside>
  );
}

function InactiveReviewNotice() {
  return (
    <div className="manual-inactive-notice" role="note">
      <strong>삭제/비활성 검토 후보 안내</strong>
      <p>삭제 확정이 아니라 운영 여부를 확인하는 후보입니다. 미매칭 = 삭제 대상이 아닙니다.</p>
      <p>과거 판매 이력, 미노출 상품, 원본자료 누락 가능성이 섞여 있을 수 있습니다.</p>
    </div>
  );
}

function ConflictEvidenceBox({ row }) {
  if (row.risk_type !== 'source_conflict') {
    return null;
  }

  return (
    <DetailGroup title="충돌/비교 근거">
      <div className="manual-conflict-box">
        <div className="manual-conflict-message">
          <strong>같은 채널 코드 또는 유사 근거가 여러 Selfpia 후보와 연결될 가능성이 있어 자동확정에서 제외되었습니다.</strong>
          <p>아래 채널 코드와 SKU 후보를 함께 비교해 실제 연결 대상이 하나로 좁혀지는지 확인하세요.</p>
        </div>
        <div className="manual-code-grid is-detail">
          <FieldPill label="채널 상품코드" value={row.channel_product_code} featured />
          <FieldPill label="채널 옵션코드" value={row.channel_option_code} featured />
          <FieldPill label="채널 SKU 코드" value={row.channel_sku_code} />
          <FieldPill label="판매자 상품코드" value={row.seller_product_code} />
          <FieldPill label="자사 SKU 후보" value={row.own_sku_code_candidate} />
          <FieldPill label="Selfpia SKU 후보" value={row.selfpia_sku_candidate} featured />
          <FieldPill label="매칭 SKU ID 후보" value={row.matched_sku_id_candidate} />
          <FieldPill label="매칭 상품 ID 후보" value={row.matched_product_id_candidate} />
        </div>
      </div>
    </DetailGroup>
  );
}

function CandidateDetailPanel({ candidate, detail, loading, error }) {
  const row = detail || candidate;
  const riskDescription = metaDescription(row.risk_type, RISK_TYPE_META);
  const evidenceDescription = metaDescription(row.evidence_level, EVIDENCE_LEVEL_META);
  const actionDescription = metaDescription(row.suggested_action, ACTION_META);
  const reasonSummary = riskReasonSummary(row);

  return (
    <div className="manual-detail-panel">
      {loading && <div className="notice">상세 정보를 불러오는 중입니다.</div>}
      {error && <div className="notice error">상세 조회 실패: {error}</div>}
      {!loading && !error && (
        <>
          {isInactiveReviewScope(row.review_scope) && <InactiveReviewNotice />}

          <DetailGroup title="왜 검토가 필요한가">
            <div className="manual-explain-grid">
              <div className="manual-explain-card is-risk">
                <span>위험유형</span>
                <strong>{metaLabel(row.risk_type, RISK_TYPE_META)}</strong>
                <p>{riskDescription || compactText(row.risk_type)}</p>
              </div>
              <div className="manual-explain-card">
                <span>근거수준</span>
                <strong>{metaLabel(row.evidence_level, EVIDENCE_LEVEL_META)}</strong>
                <p>{evidenceDescription || compactText(row.evidence_level)}</p>
              </div>
              <div className="manual-explain-card">
                <span>추천 검토 방향</span>
                <strong>{metaLabel(row.suggested_action, ACTION_META)}</strong>
                <p>{actionDescription || compactText(row.suggested_action)}</p>
              </div>
            </div>
            <div className="manual-risk-reason">
              <span>한글 요약</span>
              <strong>{reasonSummary}</strong>
              <span>risk_reason 원문</span>
              <p>{compactText(row.risk_reason)}</p>
            </div>
          </DetailGroup>

          <ConflictEvidenceBox row={row} />

          <DetailGroup title="소스 근거">
            <dl className="manual-detail-grid">
              <DetailItem label="source_file_name" value={row.source_file_name} />
              <DetailItem label="source_row_no" value={row.source_row_no} />
              <DetailItem label="source_system" value={row.source_system} />
              <DetailItem label="source_status" value={metaLabel(row.source_status, SOURCE_STATUS_META)} />
              <DetailItem label="normalized_sale_status" value={row.normalized_sale_status} />
              <DetailItem label="normalized_display_status" value={row.normalized_display_status} />
              <DetailItem label="normalized_option_status" value={row.normalized_option_status} />
              <DetailItem label="image_status" value={row.image_status} />
            </dl>
          </DetailGroup>

          <DetailGroup title="비교 코드">
            <div className="manual-code-grid is-detail">
              <FieldPill label="channel_product" value={row.channel_product_code} featured />
              <FieldPill label="channel_option" value={row.channel_option_code} featured />
              <FieldPill label="channel_sku" value={row.channel_sku_code} />
              <FieldPill label="seller_product" value={row.seller_product_code} />
              <FieldPill label="own_sku_candidate" value={row.own_sku_code_candidate} />
              <FieldPill label="selfpia_sku_candidate" value={row.selfpia_sku_candidate} />
              <FieldPill label="local_own_sku" value={row.own_sku_code} />
              <FieldPill label="local_selfpia_sku" value={row.selfpia_sku_code} />
            </div>
          </DetailGroup>

          <div className="manual-disabled-actions" aria-label="상세 비교 안내">
            <span>상세 비교 영역입니다. 결정 저장은 오른쪽 결정 패널의 4개 버튼으로 진행합니다.</span>
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
  const [decisionsById, setDecisionsById] = useState({});
  const [decisionLoadingId, setDecisionLoadingId] = useState('');
  const [savingAction, setSavingAction] = useState('');
  const [saveMessage, setSaveMessage] = useState('');
  const [reviewer, setReviewer] = useState(() => window.localStorage.getItem('manualReviewReviewer') || '혜인');
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
        const nextRows = result.data || [];
        setRows(nextRows);
        setExpandedId((current) => (
          nextRows.some((row) => row.review_candidate_id === current)
            ? current
            : nextRows[0]?.review_candidate_id || ''
        ));
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

  function setScopeTab(scope) {
    updateQuery({ review_scope: scope, offset: 0 });
  }

  function applySearch(event) {
    event.preventDefault();
    updateQuery({ search: searchInput.trim(), offset: 0 });
  }

  function resetFilters() {
    setSearchParams({ limit: String(DEFAULT_LIMIT), offset: '0' });
  }

  async function loadCandidateDetail(candidate) {
    const id = candidate.review_candidate_id;
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

  async function loadCandidateDecision(candidate) {
    const id = candidate.review_candidate_id;
    if (decisionsById[id] !== undefined || decisionLoadingId === id) {
      return;
    }

    setDecisionLoadingId(id);
    try {
      const result = await manualReviewApi.getDecision(id);
      setDecisionsById((current) => ({ ...current, [id]: result.data || null }));
    } catch {
      setDecisionsById((current) => ({ ...current, [id]: null }));
    } finally {
      setDecisionLoadingId('');
    }
  }

  function selectCandidate(candidate) {
    const id = candidate.review_candidate_id;
    setExpandedId(id);
    loadCandidateDetail(candidate);
    loadCandidateDecision(candidate);
    setSaveMessage('');
  }

  useEffect(() => {
    if (!expandedId) return;
    const candidate = rows.find((row) => row.review_candidate_id === expandedId);
    if (candidate) {
      loadCandidateDetail(candidate);
      loadCandidateDecision(candidate);
    }
  }, [expandedId, rows]);

  function updateReviewer(value) {
    setReviewer(value);
    window.localStorage.setItem('manualReviewReviewer', value);
  }

  async function saveDecision(action) {
    if (!selectedRow || !selectedId) {
      setSaveMessage('먼저 검수 큐에서 후보를 선택하세요.');
      return;
    }
    const reviewerName = reviewer.trim();
    if (!reviewerName) {
      setSaveMessage('검수자 이름을 입력한 뒤 저장하세요.');
      return;
    }

    setSavingAction(action);
    setSaveMessage('');
    try {
      const result = await manualReviewApi.saveDecision({
        review_candidate_id: selectedId,
        action,
        reviewer: reviewerName,
        reviewer_note: `${DECISION_ACTION_LABELS[action]} 버튼으로 저장`
      });
      setDecisionsById((current) => ({ ...current, [selectedId]: result.data }));
      setSaveMessage(`${DECISION_ACTION_LABELS[action]} 결정이 DB에 저장되었습니다.`);
    } catch (err) {
      setSaveMessage(`저장 실패: ${err.message}`);
    } finally {
      setSavingAction('');
    }
  }

  const manualMatchCount = countFor(summary, 'by_review_scope', 'manual_matching_candidate');
  const inactiveReviewCount = countFor(summary, 'by_review_scope', 'deletion_or_inactive_review_candidate');
  const hasPrevious = query.offset > 0;
  const hasNext = rows.length === query.limit;
  const activeFilterCount = FILTERS.filter((filter) => query[filter.key]).length
    + (query.review_scope ? 1 : 0)
    + (query.search ? 1 : 0);
  const currentScopeMeta = query.review_scope
    ? REVIEW_SCOPE_META[query.review_scope]
    : { label: '전체 후보', description: '수동매칭 후보와 삭제/비활성 검토 후보를 함께 보는 화면입니다.' };
  const selectedCandidate = rows.find((row) => row.review_candidate_id === expandedId) || rows[0] || null;
  const selectedId = selectedCandidate?.review_candidate_id || '';
  const selectedDetail = selectedId ? detailsById[selectedId] : null;
  const selectedRow = selectedDetail || selectedCandidate;
  const selectedLoading = Boolean(selectedId && detailLoadingId === selectedId);
  const selectedError = selectedId ? detailErrors[selectedId] : '';
  const selectedDecision = selectedId ? decisionsById[selectedId] : null;

  return (
    <section className="page manual-review-page">
      <div className="page-header">
        <div>
          <h1>수동검수 워크벤치</h1>
          <p>자동매칭 후 남은 후보를 읽기 전용으로 확인하는 v1 화면입니다.</p>
        </div>
        <button className="button disabled" type="button" disabled title="결정 저장은 local/test DB에만 기록됩니다.">
          결정 저장 local-only
        </button>
      </div>

      <div className="readonly-banner readonly-banner-strong manual-readonly-banner" role="note">
        <strong>결정 저장은 local/test DB에만 기록됩니다.</strong>
        <span>운영 DB 반영, 상품 삭제, 채널 비활성, 매핑 덮어쓰기는 하지 않습니다.</span>
        <span>오른쪽 결정 패널의 4개 버튼은 수동검수 결정 기록만 저장합니다.</span>
      </div>

      {summaryError && <div className="notice error">Summary 조회 실패: {summaryError}</div>}

      <section className="manual-summary-grid" aria-label="수동검수 요약">
        <SummaryMetric label="전체 후보" value={summary?.total_count} description="자동확정되지 않아 사람이 볼 수 있는 전체 후보입니다." tone="is-total" />
        <SummaryMetric label="수동매칭 후보" value={manualMatchCount} description="어떤 Selfpia SKU에 연결할지 비교합니다." tone="is-manual-match" />
        <SummaryMetric label="삭제/비활성 검토 후보" value={inactiveReviewCount} description="삭제 처리로 단정하지 않고 운영 여부를 따로 검토합니다." tone="is-inactive-review" />
        <DistributionList title="채널별 후보" rows={summary?.by_channel_code} />
        <DistributionList title="위험유형별 후보" rows={summary?.by_risk_type} metaMap={RISK_TYPE_META} />
      </section>

      <section className="manual-scope-tabs" aria-label="검토 범위 선택">
        <button
          type="button"
          className={query.review_scope === '' ? 'is-active' : ''}
          onClick={() => setScopeTab('')}
        >
          <span>전체</span>
          <strong>{Number(summary?.total_count || 0).toLocaleString()}</strong>
        </button>
        {Object.entries(REVIEW_SCOPE_META).map(([scope, meta]) => (
          <button
            type="button"
            key={scope}
            className={query.review_scope === scope ? 'is-active' : ''}
            onClick={() => setScopeTab(scope)}
          >
            <span>{meta.label}</span>
            <strong>{Number(countFor(summary, 'by_review_scope', scope)).toLocaleString()}</strong>
            <em>{meta.description}</em>
          </button>
        ))}
      </section>

      <div className="manual-scope-help" role="note">
        <strong>현재 보기: {currentScopeMeta.label}</strong>
        <span>{currentScopeMeta.description}</span>
        {isInactiveReviewScope(query.review_scope) && (
          <span>삭제 확정 화면이 아닙니다. 미매칭 후보라도 운영 여부와 원본자료 누락 가능성을 먼저 확인합니다.</span>
        )}
      </div>

      <section className="section-card manual-filter-card" aria-label="수동검수 필터">
        <div className="panel-header">
          <div>
            <h2>필터</h2>
            <p className="hint">탭과 필터는 URL query param으로 유지되고, 후보 목록은 GET API로만 다시 조회합니다.</p>
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
                {(summary?.[SUMMARY_DIMENSION_BY_FILTER[filter.key]] || []).map((row) => {
                  const metaMap = filter.key === 'risk_type'
                    ? RISK_TYPE_META
                    : filter.key === 'evidence_level'
                      ? EVIDENCE_LEVEL_META
                      : filter.key === 'suggested_action'
                        ? ACTION_META
                        : {};
                  return (
                    <option key={row.value} value={row.value}>
                      {metaLabel(row.value, metaMap)} ({Number(row.count || 0).toLocaleString()})
                    </option>
                  );
                })}
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
          {activeFilterCount > 0 && <span>활성 조건 {activeFilterCount}개</span>}
        </div>
      </section>

      {error && <div className="notice error">후보 조회 실패: {error}</div>}
      {loading && !error && <div className="notice">수동검수 후보를 불러오는 중입니다.</div>}

      <section className="manual-review-workspace" aria-busy={loading}>
        <aside className="manual-queue-panel">
          <div className="manual-panel-title">
            <span>검수 큐</span>
            <h2>우선 처리 목록</h2>
          </div>
          <div className="manual-queue-list">
            {!loading && rows.map((candidate) => (
              <ManualQueueItem
                key={candidate.review_candidate_id}
                candidate={candidate}
                selected={candidate.review_candidate_id === selectedId}
                onSelect={() => selectCandidate(candidate)}
              />
            ))}
          </div>
          {!loading && rows.length === 0 && !error && (
            <div className="empty-state">
              <strong>조회된 후보가 없습니다.</strong>
              <p>필터를 줄이거나 검색어를 비워 다시 조회해 주세요.</p>
            </div>
          )}
        </aside>

        <section className="manual-compare-panel">
          <div className="manual-panel-title">
            <span>선택 상품 비교</span>
            <h2>판매처 정보와 Selfpia 후보</h2>
          </div>
          {selectedError && <div className="notice error">상세 조회 실패: {selectedError}</div>}
          <ManualSelectedOverview row={selectedRow} />
          {selectedRow && (
            <CandidateDetailPanel
              candidate={selectedCandidate}
              detail={selectedDetail}
              loading={selectedLoading}
              error={selectedError}
            />
          )}
        </section>

        <ManualDecisionPanel
          row={selectedRow}
          loading={selectedLoading || Boolean(decisionLoadingId)}
          reviewer={reviewer}
          onReviewerChange={updateReviewer}
          onSaveDecision={saveDecision}
          savingAction={savingAction}
          saveMessage={saveMessage}
          savedDecision={selectedDecision}
        />
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
