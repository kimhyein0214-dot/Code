import { badRequest, notFound } from '../../shared/errors.js';
import {
  getManualReviewDecisionByCandidateId,
  getManualReviewCandidateById,
  getManualReviewSummary,
  listManualReviewCandidates,
  saveManualReviewDecision
} from './repository.js';

const FILTER_KEYS = [
  'channel_code',
  'risk_type',
  'evidence_level',
  'review_scope',
  'suggested_action',
  'source_status'
];

function clampLimit(value, fallback = 50, max = 200) {
  const numeric = Number(value || fallback);
  if (!Number.isFinite(numeric) || numeric <= 0) {
    return fallback;
  }
  return Math.min(Math.trunc(numeric), max);
}

function normalizeOffset(value) {
  const numeric = Number(value || 0);
  if (!Number.isFinite(numeric) || numeric < 0) {
    return 0;
  }
  return Math.trunc(numeric);
}

function normalizeSearch(value) {
  const trimmed = value ? String(value).trim() : '';
  return trimmed ? `%${trimmed}%` : null;
}

function normalizeFilters(query) {
  return Object.fromEntries(
    FILTER_KEYS
      .map((key) => [key, query[key] ? String(query[key]).trim() : null])
      .filter(([, value]) => value)
  );
}

export async function getCandidateList(query) {
  const limit = clampLimit(query.limit);
  const offset = normalizeOffset(query.offset);
  const filters = normalizeFilters(query);
  const search = normalizeSearch(query.search);

  const data = await listManualReviewCandidates({ filters, search, limit, offset });
  return {
    data,
    count: data.length,
    limit,
    offset,
    filters: {
      ...filters,
      ...(query.search ? { search: String(query.search).trim() } : {})
    }
  };
}

export async function getCandidateDetail(reviewCandidateId) {
  const id = reviewCandidateId ? String(reviewCandidateId).trim() : '';
  if (!id) {
    throw badRequest('review_candidate_id_required', 'review_candidate_id is required');
  }

  const data = await getManualReviewCandidateById(id);
  if (!data) {
    throw notFound('manual_review_candidate_not_found', `Manual review candidate not found: ${id}`);
  }

  return { data };
}

export async function getSummary() {
  return {
    data: await getManualReviewSummary()
  };
}

export async function getDecision(reviewCandidateId) {
  const id = reviewCandidateId ? String(reviewCandidateId).trim() : '';
  if (!id) {
    throw badRequest('review_candidate_id_required', 'review_candidate_id is required');
  }

  return {
    data: await getManualReviewDecisionByCandidateId(id)
  };
}

export async function saveDecision(body = {}) {
  const reviewCandidateId = body.review_candidate_id ? String(body.review_candidate_id).trim() : '';
  const action = body.action ? String(body.action).trim() : '';
  const reviewer = body.reviewer ? String(body.reviewer).trim() : '';
  const reviewerNote = body.reviewer_note ? String(body.reviewer_note).trim() : '';

  if (!reviewCandidateId) {
    throw badRequest('review_candidate_id_required', 'review_candidate_id is required');
  }
  if (!['auto_approve', 'manual_link', 'unlink', 'discontinue'].includes(action)) {
    throw badRequest('manual_review_decision_action_invalid', 'action must be one of auto_approve, manual_link, unlink, discontinue');
  }
  if (!reviewer) {
    throw badRequest('manual_review_reviewer_required', 'reviewer is required');
  }

  return {
    data: await saveManualReviewDecision({
      reviewCandidateId,
      action,
      reviewer,
      reviewerNote
    })
  };
}
