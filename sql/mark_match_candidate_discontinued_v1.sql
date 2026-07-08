/*
  mark_match_candidate_discontinued_v1.sql

  Purpose:
  - Store manual discontinue/exclude decisions in the same review bucket shape
    as existing discontinued/excluded rows.
  - Preserve existing Sellpia link fields.
  - Keep public anon write mode, without exposing service_role keys.
*/

BEGIN;

CREATE OR REPLACE FUNCTION public.mark_match_candidate_discontinued(
  queue_id bigint,
  reviewer text,
  memo text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'review', 'pg_temp'
AS $function$
DECLARE
  v_reviewer text := nullif(btrim(reviewer), '');
  v_writer_id uuid;
  v_before jsonb;
  v_after jsonb;
  v_event jsonb;
BEGIN
  v_writer_id := review.require_review_writer(v_reviewer);

  SELECT to_jsonb(q.*)
    INTO v_before
  FROM review.match_candidate_queue q
  WHERE q.queue_id = mark_match_candidate_discontinued.queue_id
  FOR UPDATE;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'queue_id % not found', queue_id;
  END IF;

  v_event := jsonb_build_object(
    'decision', 'discontinue',
    'reviewer', v_reviewer,
    'auth_user_id', v_writer_id,
    'memo', nullif(btrim(coalesce(memo, '')), ''),
    'decided_at', now(),
    'before', v_before,
    'after', jsonb_build_object(
      'match_tier', 'REVIEW',
      'recommended_action', '현재 범위에서 제외',
      'review_required', true
    )
  );

  UPDATE review.match_candidate_queue q
  SET
    match_tier = 'REVIEW',
    recommended_action = '현재 범위에서 제외',
    review_required = true,
    evidence_json = jsonb_set(
      coalesce(q.evidence_json, '{}'::jsonb),
      '{local_html_discontinue_decision}',
      coalesce(coalesce(q.evidence_json, '{}'::jsonb)->'local_html_discontinue_decision', '[]'::jsonb) || jsonb_build_array(v_event),
      true
    ),
    updated_at = now()
  WHERE q.queue_id = mark_match_candidate_discontinued.queue_id
  RETURNING to_jsonb(q.*) INTO v_after;

  RETURN jsonb_build_object('ok', true, 'queue_id', queue_id, 'decision', 'discontinue', 'before', v_before, 'row', v_after);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.mark_match_candidate_discontinued(bigint, text, text) TO anon, authenticated, service_role;

COMMIT;
