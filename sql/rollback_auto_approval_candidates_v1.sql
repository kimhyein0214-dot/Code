/*
  rollback_auto_approval_candidates_v1.sql

  Purpose:
  - Roll back apply_auto_approval_candidates_v1.sql using the persistent backup table.

  Safety:
  - Stops unless exactly 4467 backup rows exist for marker auto_approval_candidates_v1.
  - Restores only queue_id rows present in review.auto_approval_apply_backup_v1.
*/

BEGIN;

DO $$
DECLARE
  v_backup_rows integer;
  v_rollback_rows integer;
BEGIN
  SELECT count(*)
    INTO v_backup_rows
  FROM review.auto_approval_apply_backup_v1
  WHERE apply_marker = 'auto_approval_candidates_v1';

  IF v_backup_rows <> 4467 THEN
    RAISE EXCEPTION 'rollback backup count mismatch: expected 4467, got %', v_backup_rows;
  END IF;

  UPDATE review.match_candidate_queue q
  SET
    match_tier = b.before_match_tier,
    review_required = b.before_review_required,
    recommended_action = b.before_recommended_action,
    best_sellpia_product_code = b.before_best_sellpia_product_code,
    best_sellpia_sku_code = b.before_best_sellpia_sku_code,
    best_sellpia_product_name = b.before_best_sellpia_product_name,
    best_sellpia_option_name = b.before_best_sellpia_option_name,
    evidence_json = b.before_evidence_json,
    updated_at = b.before_updated_at
  FROM review.auto_approval_apply_backup_v1 b
  WHERE b.apply_marker = 'auto_approval_candidates_v1'
    AND b.queue_id = q.queue_id;

  GET DIAGNOSTICS v_rollback_rows = ROW_COUNT;
  IF v_rollback_rows <> 4467 THEN
    RAISE EXCEPTION 'rollback row count mismatch: expected 4467, got %', v_rollback_rows;
  END IF;
END $$;

SELECT
  'rollback_auto_approval_candidates_v1' AS check_name,
  count(*) AS restored_rows,
  count(*) FILTER (WHERE q.match_tier = b.before_match_tier) AS match_tier_restored_rows,
  count(*) FILTER (WHERE q.review_required IS NOT DISTINCT FROM b.before_review_required) AS review_required_restored_rows,
  count(*) FILTER (WHERE q.recommended_action IS NOT DISTINCT FROM b.before_recommended_action) AS recommended_action_restored_rows,
  count(*) FILTER (WHERE q.evidence_json IS NOT DISTINCT FROM b.before_evidence_json) AS evidence_json_restored_rows
FROM review.match_candidate_queue q
JOIN review.auto_approval_apply_backup_v1 b
  ON b.queue_id = q.queue_id
WHERE b.apply_marker = 'auto_approval_candidates_v1';

COMMIT;
