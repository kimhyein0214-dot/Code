const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';

async function request(path) {
  const response = await fetch(`${API_BASE_URL}${path}`);
  const body = await response.json().catch(() => ({}));

  if (!response.ok) {
    const message = body.message || body.error || `Request failed: ${response.status}`;
    throw new Error(message);
  }

  return body;
}

function params(query) {
  const searchParams = new URLSearchParams();
  Object.entries(query).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      searchParams.set(key, value);
    }
  });
  const value = searchParams.toString();
  return value ? `?${value}` : '';
}

export const productsApi = {
  listSkus(query = {}) {
    return request(`/api/products/skus${params(query)}`);
  },
  getSku(skuId) {
    return request(`/api/products/skus/${encodeURIComponent(skuId)}`);
  },
  getAliases(skuId) {
    return request(`/api/products/skus/${encodeURIComponent(skuId)}/aliases`);
  },
  findByCode(codeSystem, codeValue) {
    return request(
      `/api/products/skus/by-code/${encodeURIComponent(codeSystem)}/${encodeURIComponent(codeValue)}`
    );
  },
  search(query = {}) {
    return request(`/api/products/search${params(query)}`);
  },
  listChangeRequests() {
    return request('/api/products/change-requests');
  }
};

export const manualReviewApi = {
  getSummary() {
    return request('/api/manual-review/summary');
  },
  listCandidates(query = {}) {
    return request(`/api/manual-review/candidates${params(query)}`);
  },
  getCandidate(reviewCandidateId) {
    return request(`/api/manual-review/candidates/${encodeURIComponent(reviewCandidateId)}`);
  }
};
