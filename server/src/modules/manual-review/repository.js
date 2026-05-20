import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { pool } from '../../db.js';
import { AppError } from '../../shared/errors.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WORKBENCH_SQL_PATH = path.resolve(
  __dirname,
  '../../../../sql/select_manual_review_workbench_candidates_v1.sql'
);

let workbenchCteCache = null;

const CANDIDATE_COLUMNS = [
  'wc.review_candidate_id',
  'wc.channel_code',
  'wc.source_system',
  'wc.source_file_name',
  'wc.source_row_no',
  'wc.review_scope',
  'wc.evidence_level',
  'wc.risk_type',
  'wc.risk_reason',
  'wc.suggested_action',
  'wc.channel_product_code',
  'wc.channel_option_code',
  'wc.channel_sku_code',
  'wc.seller_product_code',
  'wc.own_sku_code_candidate',
  'wc.selfpia_sku_candidate',
  'wc.matched_sku_id_candidate',
  'wc.matched_product_id_candidate',
  'wc.selfpia_product_code',
  'wc.selfpia_sku_code',
  'wc.own_sku_code',
  'wc.product_name_channel',
  'wc.option_name_channel',
  'wc.product_name_selfpia',
  'wc.option_name_selfpia',
  'wc.image_status',
  'wc.source_status',
  'wc.normalized_sale_status',
  'wc.normalized_display_status',
  'wc.normalized_option_status',
  'wc.reviewer_decision_placeholder',
  'wc.reviewer_note_placeholder'
].join(',\n    ');

const FILTER_COLUMNS = {
  channel_code: 'wc.channel_code',
  risk_type: 'wc.risk_type',
  evidence_level: 'wc.evidence_level',
  review_scope: 'wc.review_scope',
  suggested_action: 'wc.suggested_action',
  source_status: 'wc.source_status'
};

const SEARCH_COLUMNS = [
  'wc.review_candidate_id',
  'wc.source_file_name',
  'wc.risk_reason',
  'wc.channel_product_code',
  'wc.channel_option_code',
  'wc.channel_sku_code',
  'wc.seller_product_code',
  'wc.own_sku_code_candidate',
  'wc.selfpia_sku_candidate',
  'wc.selfpia_product_code',
  'wc.selfpia_sku_code',
  'wc.own_sku_code',
  'wc.product_name_channel',
  'wc.option_name_channel',
  'wc.product_name_selfpia',
  'wc.option_name_selfpia'
];

function loadWorkbenchCte() {
  if (workbenchCteCache) {
    return workbenchCteCache;
  }

  const sql = readFileSync(WORKBENCH_SQL_PATH, 'utf8');
  const start = sql.indexOf('WITH evidence AS MATERIALIZED');
  if (start < 0) {
    throw new Error('manual review workbench SQL is missing the evidence CTE');
  }

  const cteSql = sql.slice(start);
  const numberedMarker = cteSql.search(/,\r?\nnumbered AS MATERIALIZED/i);
  if (numberedMarker < 0) {
    throw new Error('manual review workbench SQL is missing the numbered CTE marker');
  }

  workbenchCteCache = cteSql.slice(0, numberedMarker);
  return workbenchCteCache;
}

async function assertLocalReadOnly(client) {
  const result = await client.query(`
    SELECT
      current_database() AS current_database,
      current_user AS current_user,
      current_setting('transaction_read_only') AS transaction_read_only
  `);
  const guard = result.rows[0];

  if (
    guard.current_database !== 'product_ops_test'
    || guard.current_user !== 'product_ops_tester'
    || guard.transaction_read_only !== 'on'
  ) {
    throw new AppError(
      403,
      'manual_review_local_db_guard_failed',
      'Manual review API is restricted to product_ops_test as product_ops_tester in a read-only transaction.'
    );
  }
}

async function readOnlyQuery(text, params = []) {
  const client = await pool.connect();

  try {
    await client.query('BEGIN READ ONLY');
    await assertLocalReadOnly(client);
    const result = await client.query(text, params);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch {
      // Ignore rollback failures so the original error remains visible.
    }
    throw err;
  } finally {
    client.release();
  }
}

function buildCandidateWhere({ filters = {}, search = null }) {
  const params = [];
  const clauses = [];

  for (const [key, column] of Object.entries(FILTER_COLUMNS)) {
    const value = filters[key];
    if (value !== undefined && value !== null && String(value).trim() !== '') {
      params.push(String(value).trim());
      clauses.push(`${column} = $${params.length}`);
    }
  }

  if (search) {
    params.push(search);
    const placeholder = `$${params.length}`;
    clauses.push(`(
      ${SEARCH_COLUMNS.map((column) => `COALESCE(${column}::text, '') ILIKE ${placeholder}`).join('\n      OR ')}
    )`);
  }

  return {
    whereSql: clauses.length ? `WHERE ${clauses.join('\n      AND ')}` : '',
    params
  };
}

export async function listManualReviewCandidates({ filters, search, limit, offset }) {
  const { whereSql, params } = buildCandidateWhere({ filters, search });
  params.push(limit, offset);

  const result = await readOnlyQuery(
    `
    ${loadWorkbenchCte()}
    SELECT
      ${CANDIDATE_COLUMNS}
    FROM workbench_candidates AS wc
    ${whereSql}
    ORDER BY
      wc.channel_code,
      wc.risk_type,
      wc.source_row_no NULLS LAST,
      wc.review_candidate_id
    LIMIT $${params.length - 1} OFFSET $${params.length}
    `,
    params
  );

  return result.rows;
}

export async function getManualReviewCandidateById(reviewCandidateId) {
  const result = await readOnlyQuery(
    `
    ${loadWorkbenchCte()}
    SELECT
      ${CANDIDATE_COLUMNS}
    FROM workbench_candidates AS wc
    WHERE wc.review_candidate_id = $1
    LIMIT 1
    `,
    [reviewCandidateId]
  );

  return result.rows[0] || null;
}

export async function getManualReviewSummary() {
  const result = await readOnlyQuery(
    `
    ${loadWorkbenchCte()},
    summary_rows AS (
      SELECT 'total'::text AS dimension, 'total'::text AS value, COUNT(*)::integer AS row_count
      FROM workbench_candidates
      UNION ALL
      SELECT 'channel_code', channel_code, COUNT(*)::integer
      FROM workbench_candidates
      GROUP BY channel_code
      UNION ALL
      SELECT 'risk_type', risk_type, COUNT(*)::integer
      FROM workbench_candidates
      GROUP BY risk_type
      UNION ALL
      SELECT 'evidence_level', evidence_level, COUNT(*)::integer
      FROM workbench_candidates
      GROUP BY evidence_level
      UNION ALL
      SELECT 'review_scope', review_scope, COUNT(*)::integer
      FROM workbench_candidates
      GROUP BY review_scope
      UNION ALL
      SELECT 'suggested_action', suggested_action, COUNT(*)::integer
      FROM workbench_candidates
      GROUP BY suggested_action
      UNION ALL
      SELECT 'source_status', source_status, COUNT(*)::integer
      FROM workbench_candidates
      GROUP BY source_status
    )
    SELECT dimension, value, row_count
    FROM summary_rows
    ORDER BY dimension, row_count DESC, value
    `
  );

  const byDimension = new Map();
  for (const row of result.rows) {
    if (!byDimension.has(row.dimension)) {
      byDimension.set(row.dimension, []);
    }
    byDimension.get(row.dimension).push({
      value: row.value,
      count: row.row_count
    });
  }

  return {
    total_count: byDimension.get('total')?.[0]?.count || 0,
    by_channel_code: byDimension.get('channel_code') || [],
    by_risk_type: byDimension.get('risk_type') || [],
    by_evidence_level: byDimension.get('evidence_level') || [],
    by_review_scope: byDimension.get('review_scope') || [],
    by_suggested_action: byDimension.get('suggested_action') || [],
    by_source_status: byDimension.get('source_status') || []
  };
}
