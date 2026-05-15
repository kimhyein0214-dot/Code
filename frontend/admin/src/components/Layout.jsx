import React from 'react';
import { NavLink } from 'react-router-dom';

export function Layout({ children }) {
  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <strong>Product Ops</strong>
          <span>Admin v1 · read-only</span>
        </div>
        <nav className="nav">
          <NavLink to="/products" end>SKU 목록</NavLink>
          <NavLink to="/products/aliases">Alias 검색</NavLink>
          <NavLink to="/products/change-requests">Change Requests</NavLink>
        </nav>
        <div className="sidebar-foot">
          <p>Product_code master는 조회 전용으로만 노출합니다.</p>
          <p>master, alias, channel 변경은 v1 범위 밖입니다.</p>
        </div>
      </aside>
      <main className="main">
        <div className="env-banner" role="status">
          <span className="env-banner-pill">READ-ONLY</span>
          <span>Product Management v1은 실제 상품 데이터를 조회하지만, 데이터 변경 기능은 비활성화되어 있습니다.</span>
        </div>
        {children}
      </main>
    </div>
  );
}
