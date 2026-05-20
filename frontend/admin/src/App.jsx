import React from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';

import { Layout } from './components/Layout.jsx';
import { AliasSearchPage } from './pages/products/AliasSearchPage.jsx';
import { ChangeRequestsPlaceholderPage } from './pages/products/ChangeRequestsPlaceholderPage.jsx';
import { ManualReviewWorkbenchPage } from './pages/products/ManualReviewWorkbenchPage.jsx';
import { ProductDetailPage } from './pages/products/ProductDetailPage.jsx';
import { ProductListPage } from './pages/products/ProductListPage.jsx';

export function App() {
  return (
    <Layout>
      <Routes>
        <Route path="/" element={<Navigate to="/products" replace />} />
        <Route path="/products" element={<ProductListPage />} />
        <Route path="/products/aliases" element={<AliasSearchPage />} />
        <Route path="/products/manual-review" element={<ManualReviewWorkbenchPage />} />
        <Route path="/products/change-requests" element={<ChangeRequestsPlaceholderPage />} />
        <Route path="/products/:skuId" element={<ProductDetailPage />} />
      </Routes>
    </Layout>
  );
}
