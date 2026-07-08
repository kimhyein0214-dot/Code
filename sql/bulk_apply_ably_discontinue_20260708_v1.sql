/*
  bulk_apply_ably_discontinue_20260708_v1.sql

  Applied on 2026-07-08.

  Purpose:
  - Mark all Ably discontinue/exclude candidates with the same shape used by
    existing excluded rows:
      match_tier = 'REVIEW'
      recommended_action = '현재 범위에서 제외'
      review_required = true
  - Preserve Sellpia link fields.
  - Append local_html_discontinue_decision audit evidence.

  Result at apply time:
  - Total Ably discontinue/exclude candidates: 830
  - Already in excluded shape: 13
  - Newly updated rows: 817
  - Backup table: review.match_candidate_queue_backup_ably_discontinue_20260708_v1
*/

BEGIN;

CREATE TABLE IF NOT EXISTS review.match_candidate_queue_backup_ably_discontinue_20260708_v1 AS
WITH candidates AS (
  SELECT v.queue_id
  FROM mapping_matrix_review_full_v3 v
  WHERE v.source_channel = 'ably'
    AND lower(concat_ws(' ', v.match_tier, v.recommended_action, v.match_reason, v.duplicate_risk, v.channel_product_name, v.channel_option_name)) ~ '(단종|삭제|제외|excluded|discontinued|hidden)'
    AND NOT (v.match_tier = 'REVIEW' AND v.recommended_action = '현재 범위에서 제외' AND v.review_required IS TRUE)
)
SELECT
  now() AS backup_created_at,
  'ably_discontinue_bulk_20260708_v1'::text AS backup_reason,
  q.*
FROM review.match_candidate_queue q
JOIN candidates c ON c.queue_id = q.queue_id;

DO $do$
DECLARE
  v_target_count bigint;
BEGIN
  WITH candidates AS (
    SELECT v.queue_id
    FROM mapping_matrix_review_full_v3 v
    WHERE v.source_channel = 'ably'
      AND lower(concat_ws(' ', v.match_tier, v.recommended_action, v.match_reason, v.duplicate_risk, v.channel_product_name, v.channel_option_name)) ~ '(단종|삭제|제외|excluded|discontinued|hidden)'
      AND NOT (v.match_tier = 'REVIEW' AND v.recommended_action = '현재 범위에서 제외' AND v.review_required IS TRUE)
  )
  SELECT count(*) INTO v_target_count FROM candidates;

  IF v_target_count <> 817 THEN
    RAISE EXCEPTION 'Expected 817 Ably discontinue candidates, got %', v_target_count;
  END IF;
END;
$do$;

WITH candidates AS (
  SELECT v.queue_id
  FROM mapping_matrix_review_full_v3 v
  WHERE v.source_channel = 'ably'
    AND lower(concat_ws(' ', v.match_tier, v.recommended_action, v.match_reason, v.duplicate_risk, v.channel_product_name, v.channel_option_name)) ~ '(단종|삭제|제외|excluded|discontinued|hidden)'
    AND NOT (v.match_tier = 'REVIEW' AND v.recommended_action = '현재 범위에서 제외' AND v.review_required IS TRUE)
), updated AS (
  UPDATE review.match_candidate_queue q
  SET
    match_tier = 'REVIEW',
    recommended_action = '현재 범위에서 제외',
    review_required = true,
    evidence_json = jsonb_set(
      coalesce(q.evidence_json, '{}'::jsonb),
      '{local_html_discontinue_decision}',
      coalesce(coalesce(q.evidence_json, '{}'::jsonb)->'local_html_discontinue_decision', '[]'::jsonb) || jsonb_build_array(
        jsonb_build_object(
          'decision', 'discontinue',
          'reviewer', 'public-review',
          'auth_user_id', null,
          'memo', 'bulk Ably discontinue/exclude candidates 20260708',
          'decided_at', now(),
          'source', 'bulk_ably_discontinue_20260708_v1',
          'before', to_jsonb(q.*),
          'after', jsonb_build_object(
            'match_tier', 'REVIEW',
            'recommended_action', '현재 범위에서 제외',
            'review_required', true
          )
        )
      ),
      true
    ),
    updated_at = now()
  FROM candidates c
  WHERE q.queue_id = c.queue_id
  RETURNING q.queue_id
)
SELECT count(*)::bigint AS updated_rows FROM updated;

COMMIT;

/*
  Rollback outline, if needed:

  UPDATE review.match_candidate_queue q
  SET
    best_sellpia_product_code = b.best_sellpia_product_code,
    best_sellpia_sku_code = b.best_sellpia_sku_code,
    best_sellpia_product_name = b.best_sellpia_product_name,
    best_sellpia_option_name = b.best_sellpia_option_name,
    match_tier = b.match_tier,
    recommended_action = b.recommended_action,
    review_required = b.review_required,
    evidence_json = b.evidence_json,
    updated_at = now()
  FROM review.match_candidate_queue_backup_ably_discontinue_20260708_v1 b
  WHERE q.queue_id = b.queue_id;
*/
