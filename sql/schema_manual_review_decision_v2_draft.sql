/*
  Manual review decision v2 schema draft.

  Purpose:
  - Local DB decision storage for the manual review workbench.
  - This table records reviewer intent only.
  - It is NOT an operating apply table.
  - It must not update product_code.code_alias, product_code.sku_channel_mapping,
    product master, SKU master, source files, exports, or production systems.

  Scope:
  - Draft DDL only.
  - Intended DB: product_ops_test.
  - Intended use: apply only after dry-run PASS and explicit user approval.
  - Production Supabase, NAS PostgreSQL, and remote DB execution are prohibited.

  History design note:
  - v2 starts with one current decision per review_candidate_id.
  - The UNIQUE constraint on review_candidate_id prevents multiple active records.
  - If full audit history is needed later, add a separate history table instead of
    weakening this current-decision table.
*/

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

COMMENT ON SCHEMA product_code_review IS
  'Local product ops review schema. Not for operating apply or production writes.';

COMMENT ON TABLE product_code_review.manual_review_decision IS
  'Local-only manual review decision table. Saves reviewer intent only; does not apply matches, deletes, or channel status changes.';

COMMENT ON COLUMN product_code_review.manual_review_decision.decision_id IS
  'Stable id for the local decision record. Generate in v2 API/app layer to avoid DB extension dependency.';

COMMENT ON COLUMN product_code_review.manual_review_decision.review_candidate_id IS
  'Read-only workbench candidate id captured from GET /api/manual-review/candidates.';

COMMENT ON COLUMN product_code_review.manual_review_decision.review_scope IS
  'Candidate scope captured at decision time.';

COMMENT ON COLUMN product_code_review.manual_review_decision.suggested_sku_id IS
  'Suggested local SKU id from the candidate, if present. This is not an applied mapping.';

COMMENT ON COLUMN product_code_review.manual_review_decision.suggested_selfpia_sku IS
  'Suggested Selfpia SKU from the candidate, if present. This is not an applied mapping.';

COMMENT ON COLUMN product_code_review.manual_review_decision.decision_status IS
  'Reviewer decision enum. Does not imply production apply.';

COMMENT ON COLUMN product_code_review.manual_review_decision.decision_reason IS
  'Optional structured reason or reviewer-selected reason category.';

COMMENT ON COLUMN product_code_review.manual_review_decision.reviewer_note IS
  'Optional free-form reviewer note.';

COMMENT ON COLUMN product_code_review.manual_review_decision.reviewer IS
  'Local reviewer identity from admin/session/env.';

COMMENT ON COLUMN product_code_review.manual_review_decision.source_risk_type IS
  'Candidate risk_type snapshot at decision time.';

COMMENT ON COLUMN product_code_review.manual_review_decision.source_evidence_level IS
  'Candidate evidence_level snapshot at decision time.';

COMMENT ON COLUMN product_code_review.manual_review_decision.source_suggested_action IS
  'Candidate suggested_action snapshot at decision time.';
