import { query } from '../../db.js';

const SKU_SELECT = `
  SELECT
    sku_id,
    selfpia_sku_code,
    selfpia_product_code,
    selfpia_option_no,
    virtual_sku_code,
    product_id,
    virtual_product_code,
    product_name,
    option_value,
    sku_type,
    sku_status
  FROM product_code.v_sku_canonical
`;

export async function listSkus({ search, codeSystem, codeValue, limit, offset }) {
  const result = await query(
    `
    WITH matched_alias AS (
      SELECT DISTINCT target_id AS sku_id
      FROM product_code.code_alias
      WHERE target_type = 'SKU'
        AND ($2::text IS NULL OR code_system = $2)
        AND ($3::text IS NULL OR code_value ILIKE $3)
    )
    ${SKU_SELECT}
    WHERE (
        $1::text IS NULL
        OR selfpia_sku_code ILIKE $1
        OR product_name ILIKE $1
        OR option_value ILIKE $1
        OR virtual_sku_code ILIKE $1
      )
      AND (
        ($2::text IS NULL AND $3::text IS NULL)
        OR sku_id IN (SELECT sku_id FROM matched_alias)
      )
    ORDER BY selfpia_sku_code NULLS LAST, sku_id
    LIMIT $4 OFFSET $5
    `,
    [search, codeSystem, codeValue, limit, offset]
  );

  return result.rows;
}

export async function getSkuById(skuId) {
  const result = await query(
    `
    ${SKU_SELECT}
    WHERE sku_id = $1
    LIMIT 1
    `,
    [skuId]
  );

  return result.rows[0] || null;
}

export async function findSkusByCode(codeSystem, codeValue, limit) {
  const result = await query(
    `
    WITH sku_alias_matches AS (
      SELECT
        ca.target_id AS sku_id,
        ca.code_system AS matched_code_system,
        ca.code_value AS matched_code_value,
        ca.is_primary AS matched_alias_is_primary
      FROM product_code.code_alias ca
      WHERE ca.target_type = 'SKU'
        AND ca.code_system = $1
        AND ca.code_value = $2
    ),
    product_alias_matches AS (
      SELECT
        sm.id AS sku_id,
        ca.code_system AS matched_code_system,
        ca.code_value AS matched_code_value,
        ca.is_primary AS matched_alias_is_primary
      FROM product_code.code_alias ca
      JOIN product_code.sku_master sm
        ON sm.product_id = ca.target_id
      WHERE ca.target_type = 'PRODUCT'
        AND ca.code_system = $1
        AND ca.code_value = $2
    ),
    matched_skus AS (
      SELECT * FROM sku_alias_matches
      UNION ALL
      SELECT * FROM product_alias_matches
    )
    SELECT DISTINCT ON (ms.sku_id, ms.matched_code_system, ms.matched_code_value)
      sm.id AS sku_id,
      selfpia.code_value AS selfpia_sku_code,
      selfpia.selfpia_product_code,
      selfpia.selfpia_option_no,
      sm.virtual_sku_code,
      sm.product_id,
      pm.virtual_product_code,
      pm.product_name,
      sm.option_value,
      sm.sku_type,
      sm.status AS sku_status,
      ms.matched_code_system,
      ms.matched_code_value,
      ms.matched_alias_is_primary
    FROM matched_skus ms
    JOIN product_code.sku_master sm
      ON sm.id = ms.sku_id
    LEFT JOIN product_code.product_master pm
      ON pm.id = sm.product_id
    LEFT JOIN LATERAL (
      SELECT
        code_value,
        selfpia_product_code,
        selfpia_option_no
      FROM product_code.code_alias
      WHERE target_type = 'SKU'
        AND target_id = sm.id
        AND code_system = 'selfpia_sku'
      ORDER BY
        (code_value = ms.matched_code_value) DESC,
        is_primary DESC,
        code_value
      LIMIT 1
    ) selfpia ON true
    ORDER BY
      ms.sku_id,
      ms.matched_code_system,
      ms.matched_code_value,
      ms.matched_alias_is_primary DESC,
      selfpia.code_value NULLS LAST
    LIMIT $3
    `,
    [codeSystem, codeValue, limit]
  );

  return result.rows;
}

export async function listAliasesBySkuId(skuId) {
  const result = await query(
    `
    SELECT
      id,
      target_type,
      target_id AS sku_id,
      code_system,
      code_value,
      selfpia_product_code,
      selfpia_option_no,
      usage_type,
      is_primary,
      memo,
      source_project_ref,
      source_table,
      created_at,
      updated_at
    FROM product_code.code_alias
    WHERE target_type = 'SKU'
      AND target_id = $1
    ORDER BY is_primary DESC, code_system, code_value
    `,
    [skuId]
  );

  return result.rows;
}

export async function listChannelMappingsBySkuId(skuId) {
  const result = await query(
    `
    SELECT
      id,
      sku_id,
      channel_code,
      channel_sku_code,
      seller_product_code,
      own_sku_code,
      is_primary,
      valid_from,
      valid_to,
      created_at,
      updated_at
    FROM (
      SELECT *
      FROM product_code.sku_channel_mapping
      WHERE sku_id = $1
    ) mappings
    ORDER BY is_primary DESC, channel_code, channel_sku_code
    `,
    [skuId]
  );

  return result.rows;
}

export async function searchProducts({ q, type, limit }) {
  const normalizedType = type || 'all';

  const result = await query(
    `
    WITH sku_matches AS (
      SELECT
        'sku'::text AS result_type,
        sku_id,
        selfpia_sku_code,
        product_name,
        option_value,
        virtual_sku_code,
        selfpia_sku_code AS matched_value
      FROM product_code.v_sku_canonical
      WHERE $2 IN ('all', 'sku', 'product', 'selfpia_sku')
        AND (
          selfpia_sku_code ILIKE $1
          OR product_name ILIKE $1
          OR option_value ILIKE $1
          OR virtual_sku_code ILIKE $1
        )
    ),
    alias_matches AS (
      SELECT
        CASE
          WHEN ca.code_system = 'own_sku' THEN 'own_sku'
          WHEN ca.code_system = 'selfpia_sku' THEN 'selfpia_sku'
          ELSE 'alias'
        END AS result_type,
        v.sku_id,
        v.selfpia_sku_code,
        v.product_name,
        v.option_value,
        v.virtual_sku_code,
        ca.code_value AS matched_value
      FROM product_code.code_alias ca
      JOIN product_code.v_sku_canonical v
        ON v.sku_id = ca.target_id
      WHERE ca.target_type = 'SKU'
        AND $2 IN ('all', 'alias', 'own_sku', 'selfpia_sku', 'channel_code')
        AND ca.code_value ILIKE $1
    ),
    channel_matches AS (
      SELECT
        'channel_code'::text AS result_type,
        v.sku_id,
        v.selfpia_sku_code,
        v.product_name,
        v.option_value,
        v.virtual_sku_code,
        COALESCE(scm.channel_sku_code, scm.seller_product_code, scm.own_sku_code) AS matched_value
      FROM product_code.sku_channel_mapping scm
      JOIN product_code.v_sku_canonical v
        ON v.sku_id = scm.sku_id
      WHERE $2 IN ('all', 'channel_code')
        AND (
          scm.channel_sku_code ILIKE $1
          OR scm.seller_product_code ILIKE $1
          OR scm.own_sku_code ILIKE $1
        )
    )
    SELECT DISTINCT ON (result_type, sku_id, matched_value)
      result_type,
      sku_id,
      selfpia_sku_code,
      product_name,
      option_value,
      virtual_sku_code,
      matched_value
    FROM (
      SELECT * FROM sku_matches
      UNION ALL
      SELECT * FROM alias_matches
      UNION ALL
      SELECT * FROM channel_matches
    ) results
    ORDER BY result_type, sku_id, matched_value
    LIMIT $3
    `,
    [q, normalizedType, limit]
  );

  return result.rows;
}
