import React, { useEffect, useState } from 'react';

import { productsApi } from '../../api/client.js';

export function ChangeRequestsPlaceholderPage() {
  const [meta, setMeta] = useState(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const result = await productsApi.listChangeRequests();
        if (!cancelled) setMeta(result.meta || {});
      } catch (err) {
        if (!cancelled) setError(err.message);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <section className="page">
      <div className="page-header">
        <div>
          <h1>Change Requests</h1>
          <p>master 변경 workflow placeholder</p>
        </div>
        <button
          className="button disabled"
          disabled
          aria-disabled="true"
          title="v1 read-only. 새 요청 작성 기능은 비활성 상태입니다."
        >
          새 요청
        </button>
      </div>

      <div className="readonly-banner readonly-banner-strong" role="note">
        <strong>v1 READ-ONLY</strong> — Change Request 의 작성/검토/승인 UI 는 본 버전에 포함되지 않습니다.
        master / code_alias / channel mapping 의 직접 수정 기능도 모두 비활성입니다.
      </div>

      <div className="panel">
        <h2>v1 상태</h2>
        {loading && <p className="muted">상태 조회 중…</p>}
        {error && <div className="notice error">상태 조회 실패: {error}</div>}
        {!loading && !error && (
          <p>{meta?.message || 'Product Management v1 은 read-only 입니다.'}</p>
        )}
        <ul className="bullet-list">
          <li>새 요청 작성 버튼은 의도적으로 disabled 상태로 유지됩니다.</li>
          <li>요청 목록 / 상세 / 상태 전이 UI 는 후속 버전에서 추가됩니다.</li>
          <li>master 변경이 필요한 경우 현재는 SOP/문서 기준 수동 처리합니다.</li>
        </ul>
      </div>

      <div className="panel">
        <h2>v1 범위 밖 항목</h2>
        <ul className="bullet-list">
          <li>SKU / Product master 의 추가/수정/삭제</li>
          <li>code_alias 의 추가/수정/삭제 (예: 메이크샵·에이블리 매핑 적재)</li>
          <li>sku_channel_mapping 의 추가/수정/삭제</li>
          <li>Approval workflow / change request 작성·승인</li>
        </ul>
        <p className="hint">
          관련 API: <code>GET /api/products/change-requests</code> 는 placeholder 메시지만 반환합니다.
        </p>
      </div>
    </section>
  );
}
