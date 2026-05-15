import { badRequest, notFound } from '../../shared/errors.js';
import {
  findSkusByCode,
  getSkuById,
  listAliasesBySkuId,
  listChannelMappingsBySkuId,
  listSkus,
  searchProducts
} from './repository.js';

function clampLimit(value, fallback = 50, max = 200) {
  const numeric = Number(value || fallback);
  if (!Number.isFinite(numeric) || numeric <= 0) {
    return fallback;
  }
  return Math.min(numeric, max);
}

function normalizeOffset(value) {
  const numeric = Number(value || 0);
  if (!Number.isFinite(numeric) || numeric < 0) {
    return 0;
  }
  return numeric;
}

function likeSearch(value) {
  const trimmed = value ? String(value).trim() : '';
  return trimmed ? `%${trimmed}%` : null;
}

function uniqueAliasValues(aliases, codeSystem) {
  return [
    ...new Set(
      aliases
        .filter((alias) => alias.code_system === codeSystem)
        .map((alias) => alias.code_value)
        .filter((value) => value !== undefined && value !== null && value !== '')
    )
  ];
}

export async function getSkuList(query) {
  const limit = clampLimit(query.limit);
  const offset = normalizeOffset(query.offset);
  const search = likeSearch(query.search);
  const codeSystem = query.code_system ? String(query.code_system).trim() : null;
  const codeValue = query.code_value ? likeSearch(query.code_value) : null;

  const data = await listSkus({ search, codeSystem, codeValue, limit, offset });
  return { data, limit, offset };
}

export async function getSkuDetail(skuId) {
  const sku = await getSkuById(skuId);
  if (!sku) {
    throw notFound('sku_not_found', `SKU not found: ${skuId}`);
  }

  const [aliases, channelMappings] = await Promise.all([
    listAliasesBySkuId(skuId),
    listChannelMappingsBySkuId(skuId)
  ]);

  return {
    data: {
      ...sku,
      aliases,
      smartstore_codes: {
        product_nos: uniqueAliasValues(aliases, 'smartstore_product_no'),
        product_no_candidates: uniqueAliasValues(aliases, 'smartstore_product_no_candidate'),
        option_nos: uniqueAliasValues(aliases, 'smartstore_option_no'),
        option_no_candidates: uniqueAliasValues(aliases, 'smartstore_option_no_candidate')
      },
      channel_mappings: channelMappings,
      change_request: {
        enabled: false,
        status: 'placeholder'
      }
    }
  };
}

export async function getSkuAliases(skuId) {
  const sku = await getSkuById(skuId);
  if (!sku) {
    throw notFound('sku_not_found', `SKU not found: ${skuId}`);
  }

  const aliases = await listAliasesBySkuId(skuId);
  return { data: aliases, sku };
}

export async function getSkusByCode(codeSystem, codeValue, query) {
  if (!codeSystem || !codeValue) {
    throw badRequest('code_lookup_required', 'codeSystem and codeValue are required');
  }

  const limit = clampLimit(query.limit, 50, 200);
  const data = await findSkusByCode(codeSystem, codeValue, limit);
  return { data, count: data.length, limit };
}

export async function getProductSearch(query) {
  const q = query.q || query.search;
  if (!q || !String(q).trim()) {
    throw badRequest('search_query_required', 'q or search is required');
  }

  const limit = clampLimit(query.limit, 50, 200);
  const type = query.type ? String(query.type).trim() : 'all';
  const data = await searchProducts({ q: `%${String(q).trim()}%`, type, limit });
  return { data, limit, type };
}

export async function getChangeRequestPlaceholder() {
  return {
    data: [],
    meta: {
      enabled: false,
      status: 'placeholder',
      message: 'Product master change requests are planned for a later version. v1 is read-only.'
    }
  };
}
