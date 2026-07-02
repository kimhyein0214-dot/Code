import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
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

async function assertLocalWriteAllowed(client) {
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
    || guard.transaction_read_only !== 'off'
    || process.env.NODE_ENV !== 'development'
  ) {
    throw new AppError(
      403,
      'manual_review_local_write_guard_failed',
      'Manual review decision writes are restricted to local product_ops_test as product_ops_tester in development mode.'
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

async function writeLocalDecision(callback) {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');
    await assertLocalWriteAllowed(client);
    const result = await callback(client);
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

async function ensureDecisionSchema(client) {
  await client.query(`
    CREATE SCHEMA IF NOT EXISTS product_code_review;

    CREATE TABLE IF NOT EXISTS product_code_review.manual_review_decision (
      decision_id uuid PRIMARY KEY,
      review_candidate_id text NOT NULL,
      review_scope text NOT NULL,
      channel_code text NOT NULL,
      channel_product_code text,
      channel_option_code text,
      suggested_sku_id uuid,
      suggested_selfpia_sku text,
      decision_status text NOT NULL,
      decision_reason text,
      reviewer_note text,
      reviewer text NOT NULL,
      decided_at timestamptz NOT NULL DEFAULT now(),
      source_risk_type text,
      source_evidence_level text,
      source_suggested_action text,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),

      CONSTRAINT manual_review_decision_review_scope_chk
        CHECK (review_scope IN (
          'manual_matching_candidate',
          'deletion_or_inactive_review_candidate'
        )),

      CONSTRAINT manual_review_decision_status_chk
        CHECK (decision_status IN (
          'approve_match',
          'hold',
          'exclude_candidate',
          'inactive_reviewed',
          'needs_source_fix'
        )),

      CONSTRAINT manual_review_decision_scope_status_chk
        CHECK (
          (review_scope = 'manual_matching_candidate'
            AND decision_status IN (
              'approve_match',
              'hold',
              'exclude_candidate',
              'needs_source_fix'
            ))
          OR
          (review_scope = 'deletion_or_inactive_review_candidate'
            AND decision_status IN (
              'hold',
              'exclude_candidate',
              'inactive_reviewed',
              'needs_source_fix'
            ))
        ),

      CONSTRAINT manual_review_decision_candidate_unique
        UNIQUE (review_candidate_id)
    );

    CREATE INDEX IF NOT EXISTS manual_review_decision_status_idx
      ON product_code_review.manual_review_decision (decision_status);

    CREATE INDEX IF NOT EXISTS manual_review_decision_scope_idx
      ON product_code_review.manual_review_decision (review_scope);

    CREATE INDEX IF NOT EXISTS manual_review_decision_channel_idx
      ON product_code_review.manual_review_decision (channel_code);

    CREATE INDEX IF NOT EXISTS manual_review_decision_decided_at_idx
      ON product_code_review.manual_review_decision (decided_at DESC);
  `);
}

function uuidOrNull(value) {
  const text = value ? String(value).trim() : '';
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(text)
    ? text
    : null;
}

function decisionStatusForAction(action, candidate) {
  if (action === 'auto_approve' || action === 'manual_link') {
    return 'approve_match';
  }
  if (action === 'unlink') {
    return 'exclude_candidate';
  }
  if (action === 'discontinue') {
    return candidate.review_scope === 'deletion_or_inactive_review_candidate'
      ? 'inactive_reviewed'
      : 'exclude_candidate';
  }
  return null;
}

async function getCandidateByIdInTransaction(client, reviewCandidateId) {
  const result = await client.query(
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

export async function getManualReviewDecisionByCandidateId(reviewCandidateId) {
  const tableCheck = await readOnlyQuery(
    `SELECT to_regclass('product_code_review.manual_review_decision') AS table_name`
  );

  if (!tableCheck.rows[0]?.table_name) {
    return null;
  }

  const result = await readOnlyQuery(
    `
    SELECT
      decision_id,
      review_candidate_id,
      review_scope,
      channel_code,
      channel_product_code,
      channel_option_code,
      suggested_sku_id,
      suggested_selfpia_sku,
      decision_status,
      decision_reason,
      reviewer_note,
      reviewer,
      decided_at,
      source_risk_type,
      source_evidence_level,
      source_suggested_action,
      created_at,
      updated_at
    FROM product_code_review.manual_review_decision
    WHERE review_candidate_id = $1
    LIMIT 1
    `,
    [reviewCandidateId]
  );

  return result.rows[0] || null;
}

export async function saveManualReviewDecision({
  reviewCandidateId,
  action,
  reviewer,
  reviewerNote = ''
}) {
  return writeLocalDecision(async (client) => {
    await ensureDecisionSchema(client);
    const candidate = await getCandidateByIdInTransaction(client, reviewCandidateId);
    if (!candidate) {
      throw new AppError(
        404,
        'manual_review_candidate_not_found',
        `Manual review candidate not found: ${reviewCandidateId}`
      );
    }

    const decisionStatus = decisionStatusForAction(action, candidate);
    if (!decisionStatus) {
      throw new AppError(400, 'manual_review_decision_action_invalid', `Unsupported decision action: ${action}`);
    }

    const result = await client.query(
      `
      INSERT INTO product_code_review.manual_review_decision (
        decision_id,
        review_candidate_id,
        review_scope,
        channel_code,
        channel_product_code,
        channel_option_code,
        suggested_sku_id,
        suggested_selfpia_sku,
        decision_status,
        decision_reason,
        reviewer_note,
        reviewer,
        decided_at,
        source_risk_type,
        source_evidence_level,
        source_suggested_action,
        created_at,
        updated_at
      )
      VALUES (
        $1, $2, $3, $4, $5, $6, $7::uuid, $8, $9, $10, $11, $12, now(), $13, $14, $15, now(), now()
      )
      ON CONFLICT (review_candidate_id) DO UPDATE
      SET
        review_scope = EXCLUDED.review_scope,
        channel_code = EXCLUDED.channel_code,
        channel_product_code = EXCLUDED.channel_product_code,
        channel_option_code = EXCLUDED.channel_option_code,
        suggested_sku_id = EXCLUDED.suggested_sku_id,
        suggested_selfpia_sku = EXCLUDED.suggested_selfpia_sku,
        decision_status = EXCLUDED.decision_status,
        decision_reason = EXCLUDED.decision_reason,
        reviewer_note = EXCLUDED.reviewer_note,
        reviewer = EXCLUDED.reviewer,
        decided_at = now(),
        source_risk_type = EXCLUDED.source_risk_type,
        source_evidence_level = EXCLUDED.source_evidence_level,
        source_suggested_action = EXCLUDED.source_suggested_action,
        updated_at = now()
      RETURNING *
      `,
      [
        randomUUID(),
        candidate.review_candidate_id,
        candidate.review_scope,
        candidate.channel_code,
        candidate.channel_product_code,
        candidate.channel_option_code,
        uuidOrNull(candidate.matched_sku_id_candidate),
        candidate.selfpia_sku_candidate || candidate.selfpia_sku_code || null,
        decisionStatus,
        action,
        reviewerNote,
        reviewer,
        candidate.risk_type,
        candidate.evidence_level,
        candidate.suggested_action
      ]
    );

    return result.rows[0];
  });
}
