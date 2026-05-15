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
          <p>master 변경 workflow는 아직 placeholder 상태입니다.</p>
        </div>
        <button
          className="button disabled"
          disabled
          aria-disabled="true"
          title="v1 read-only. 새 요청 작성 기능은 비활성화되어 있습니다."
        >
          새 요청
        </button>
      </div>

      <div className="readonly-banner readonly-banner-strong" role="note">
        <strong>v1 READ-ONLY</strong> · Change Request 작성, 검토, 승인 UI는 이번 버전에 포함하지 않습니다.
        master / code_alias / channel mapping 직접 수정 기능도 모두 비활성화되어 있습니다.
      </div>

      <div className="panel">
        <h2>v1 상태</h2>
        {loading && <p className="muted">상태 조회 중...</p>}
        {error && <div className="notice error">상태 조회 실패: {error}</div>}
        {!loading && !error && (
          <p>{meta?.message || 'Product Management v1은 read-only입니다.'}</p>
        )}
        <ul className="bullet-list">
          <li>새 요청 버튼은 의도적으로 disabled 상태로 유지합니다.</li>
          <li>요청 목록, 상세, 상태 전이 UI는 다음 버전에서 검토합니다.</li>
          <li>master 변경이 필요한 경우 현재는 SOP와 문서 기준으로 수동 처리합니다.</li>
        </ul>
      </div>

      <div className="panel">
        <h2>v1 범위 밖 항목</h2>
        <ul className="bullet-list">
          <li>SKU / Product master 추가, 수정, 삭제</li>
          <li>code_alias 추가, 수정, 삭제</li>
          <li>sku_channel_mapping 추가, 수정, 삭제</li>
          <li>Approval workflow / change request 작성과 승인</li>
        </ul>
        <p className="hint">
          관련 API: <code>GET /api/products/change-requests</code> 는 placeholder 메시지만 반환합니다.
        </p>
      </div>
    </section>
  );
}
