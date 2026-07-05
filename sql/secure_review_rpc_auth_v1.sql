/*
  secure_review_rpc_auth_v1.sql

  Purpose:
  - Keep GitHub Pages usable with a public Supabase anon key.
  - Block anonymous writes to manual review RPCs.
  - Require a signed-in Supabase Auth user on an allowlist before DB writes.

  Notes:
  - The allowlist starts empty. Add operator emails before expecting writes to pass.
  - Read-only REST access is intentionally not changed here.
*/

BEGIN;

CREATE TABLE IF NOT EXISTS review.review_user_allowlist (
  user_id uuid,
  email text,
  display_name text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by text NOT NULL DEFAULT current_user,
  note text,
  CONSTRAINT review_user_allowlist_identity_check CHECK (user_id IS NOT NULL OR nullif(btrim(email), '') IS NOT NULL)
);

CREATE UNIQUE INDEX IF NOT EXISTS review_user_allowlist_user_id_uidx
  ON review.review_user_allowlist (user_id)
  WHERE user_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS review_user_allowlist_email_uidx
  ON review.review_user_allowlist (lower(email))
  WHERE email IS NOT NULL;

COMMENT ON TABLE review.review_user_allowlist IS
  'Allowed Supabase Auth users for public GitHub Pages manual review writes.';

CREATE OR REPLACE FUNCTION review.require_review_writer(reviewer text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'review', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_email text := nullif(lower(btrim(auth.jwt() ->> 'email')), '');
  v_reviewer text := nullif(btrim(reviewer), '');
BEGIN
  IF v_reviewer IS NULL THEN
    RAISE EXCEPTION 'reviewer is required';
  END IF;

  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'login is required for review writes';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM review.review_user_allowlist a
    WHERE a.is_active IS TRUE
      AND (
        a.user_id = v_uid
        OR (a.email IS NOT NULL AND lower(a.email) = v_email)
      )
  ) THEN
    RAISE EXCEPTION 'review writer is not allowlisted';
  END IF;

  RETURN v_uid;
END;
$function$;

CREATE OR REPLACE FUNCTION public.current_review_writer_status()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'review', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_email text := nullif(lower(btrim(auth.jwt() ->> 'email')), '');
  v_allowed boolean := false;
BEGIN
  IF v_uid IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM review.review_user_allowlist a
      WHERE a.is_active IS TRUE
        AND (
          a.user_id = v_uid
          OR (a.email IS NOT NULL AND lower(a.email) = v_email)
        )
    )
    INTO v_allowed;
  END IF;

  RETURN jsonb_build_object(
    'authenticated', v_uid IS NOT NULL,
    'allowed', v_allowed,
    'email', v_email
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.link_match_candidate_option(
  queue_id bigint,
  sellpia_product_code text,
  sellpia_sku_code text,
  sellpia_product_name text,
  sellpia_option_name text,
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
  WHERE q.queue_id = link_match_candidate_option.queue_id
  FOR UPDATE;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'queue_id % not found', queue_id;
  END IF;

  v_event := jsonb_build_object(
    'decision', 'link',
    'reviewer', v_reviewer,
    'auth_user_id', v_writer_id,
    'memo', nullif(btrim(coalesce(memo, '')), ''),
    'decided_at', now(),
    'before', v_before,
    'after', jsonb_build_object(
      'best_sellpia_product_code', sellpia_product_code,
      'best_sellpia_sku_code', sellpia_sku_code,
      'best_sellpia_product_name', sellpia_product_name,
      'best_sellpia_option_name', sellpia_option_name,
      'match_tier', 'MANUAL_LINKED',
      'recommended_action', '수동 연동됨',
      'review_required', false
    )
  );

  UPDATE review.match_candidate_queue q
  SET
    best_sellpia_product_code = link_match_candidate_option.sellpia_product_code,
    best_sellpia_sku_code = link_match_candidate_option.sellpia_sku_code,
    best_sellpia_product_name = link_match_candidate_option.sellpia_product_name,
    best_sellpia_option_name = link_match_candidate_option.sellpia_option_name,
    match_tier = 'MANUAL_LINKED',
    recommended_action = '수동 연동됨',
    review_required = false,
    evidence_json = jsonb_set(
      coalesce(q.evidence_json, '{}'::jsonb),
      '{local_html_link_decision}',
      coalesce(coalesce(q.evidence_json, '{}'::jsonb)->'local_html_link_decision', '[]'::jsonb) || jsonb_build_array(v_event),
      true
    ),
    updated_at = now()
  WHERE q.queue_id = link_match_candidate_option.queue_id
  RETURNING to_jsonb(q.*) INTO v_after;

  RETURN jsonb_build_object('ok', true, 'queue_id', queue_id, 'decision', 'link', 'before', v_before, 'row', v_after);
END;
$function$;

CREATE OR REPLACE FUNCTION public.unlink_match_candidate_option(
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
  WHERE q.queue_id = unlink_match_candidate_option.queue_id
  FOR UPDATE;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'queue_id % not found', queue_id;
  END IF;

  v_event := jsonb_build_object(
    'decision', 'unlink',
    'reviewer', v_reviewer,
    'auth_user_id', v_writer_id,
    'memo', nullif(btrim(coalesce(memo, '')), ''),
    'decided_at', now(),
    'before', v_before,
    'after', jsonb_build_object(
      'best_sellpia_product_code', null,
      'best_sellpia_sku_code', null,
      'best_sellpia_product_name', null,
      'best_sellpia_option_name', null,
      'match_tier', 'NO_MATCH',
      'recommended_action', '수동 연동 해제됨',
      'review_required', true
    )
  );

  UPDATE review.match_candidate_queue q
  SET
    best_sellpia_product_code = null,
    best_sellpia_sku_code = null,
    best_sellpia_product_name = null,
    best_sellpia_option_name = null,
    match_tier = 'NO_MATCH',
    recommended_action = '수동 연동 해제됨',
    review_required = true,
    evidence_json = jsonb_set(
      coalesce(q.evidence_json, '{}'::jsonb),
      '{local_html_link_decision}',
      coalesce(coalesce(q.evidence_json, '{}'::jsonb)->'local_html_link_decision', '[]'::jsonb) || jsonb_build_array(v_event),
      true
    ),
    updated_at = now()
  WHERE q.queue_id = unlink_match_candidate_option.queue_id
  RETURNING to_jsonb(q.*) INTO v_after;

  RETURN jsonb_build_object('ok', true, 'queue_id', queue_id, 'decision', 'unlink', 'before', v_before, 'row', v_after);
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_match_candidate_queue_cell(
  queue_id bigint,
  field_name text,
  new_value text,
  reviewer text,
  memo text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'review', 'pg_temp'
AS $function$
DECLARE
  v_field text := lower(btrim(field_name));
  v_reviewer text := nullif(btrim(reviewer), '');
  v_writer_id uuid;
  v_before review.match_candidate_queue%rowtype;
  v_after jsonb;
  v_old_value text;
  v_event jsonb;
BEGIN
  v_writer_id := review.require_review_writer(v_reviewer);

  IF v_field NOT IN (
    'channel_product_code',
    'channel_option_code',
    'channel_product_name',
    'channel_option_name',
    'best_sellpia_product_code',
    'best_sellpia_sku_code',
    'best_sellpia_product_name',
    'best_sellpia_option_name',
    'recommended_action',
    'match_reason'
  ) THEN
    RAISE EXCEPTION 'field % is not editable', field_name;
  END IF;

  SELECT *
    INTO v_before
  FROM review.match_candidate_queue q
  WHERE q.queue_id = update_match_candidate_queue_cell.queue_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'queue_id % not found', queue_id;
  END IF;

  v_old_value := to_jsonb(v_before)->>v_field;
  v_event := jsonb_build_object(
    'field_name', v_field,
    'old_value', v_old_value,
    'new_value', new_value,
    'reviewer', v_reviewer,
    'auth_user_id', v_writer_id,
    'memo', nullif(btrim(coalesce(memo, '')), ''),
    'edited_at', now()
  );

  UPDATE review.match_candidate_queue q
  SET
    channel_product_code = CASE WHEN v_field = 'channel_product_code' THEN new_value ELSE q.channel_product_code END,
    channel_option_code = CASE WHEN v_field = 'channel_option_code' THEN new_value ELSE q.channel_option_code END,
    channel_product_name = CASE WHEN v_field = 'channel_product_name' THEN new_value ELSE q.channel_product_name END,
    channel_option_name = CASE WHEN v_field = 'channel_option_name' THEN new_value ELSE q.channel_option_name END,
    best_sellpia_product_code = CASE WHEN v_field = 'best_sellpia_product_code' THEN new_value ELSE q.best_sellpia_product_code END,
    best_sellpia_sku_code = CASE WHEN v_field = 'best_sellpia_sku_code' THEN new_value ELSE q.best_sellpia_sku_code END,
    best_sellpia_product_name = CASE WHEN v_field = 'best_sellpia_product_name' THEN new_value ELSE q.best_sellpia_product_name END,
    best_sellpia_option_name = CASE WHEN v_field = 'best_sellpia_option_name' THEN new_value ELSE q.best_sellpia_option_name END,
    recommended_action = CASE WHEN v_field = 'recommended_action' THEN new_value ELSE q.recommended_action END,
    match_reason = CASE WHEN v_field = 'match_reason' THEN new_value ELSE q.match_reason END,
    evidence_json = jsonb_set(
      coalesce(q.evidence_json, '{}'::jsonb),
      '{local_html_cell_edits}',
      coalesce(coalesce(q.evidence_json, '{}'::jsonb)->'local_html_cell_edits', '[]'::jsonb) || jsonb_build_array(v_event),
      true
    ),
    updated_at = now()
  WHERE q.queue_id = update_match_candidate_queue_cell.queue_id
  RETURNING to_jsonb(q.*) INTO v_after;

  RETURN jsonb_build_object(
    'ok', true,
    'queue_id', queue_id,
    'field_name', v_field,
    'old_value', v_old_value,
    'new_value', new_value,
    'row', v_after
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION review.require_review_writer(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.current_review_writer_status() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.link_match_candidate_option(bigint, text, text, text, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.unlink_match_candidate_option(bigint, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_match_candidate_queue_cell(bigint, text, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.link_match_candidate_option(bigint, text, text, text, text, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.unlink_match_candidate_option(bigint, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.update_match_candidate_queue_cell(bigint, text, text, text, text) FROM anon;

GRANT EXECUTE ON FUNCTION public.current_review_writer_status() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.link_match_candidate_option(bigint, text, text, text, text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.unlink_match_candidate_option(bigint, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_match_candidate_queue_cell(bigint, text, text, text, text) TO authenticated, service_role;

COMMIT;
