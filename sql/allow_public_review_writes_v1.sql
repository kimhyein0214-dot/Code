/*
  allow_public_review_writes_v1.sql

  Purpose:
  - Match the FULL_System / FULL_System_F.v1 operating style.
  - Keep using only the public anon/publishable key on GitHub Pages.
  - Allow manual review write RPCs to run without Supabase Auth login.

  This intentionally relaxes the stricter allowlist gate from secure_review_rpc_auth_v1.sql.
  Do not expose service_role or secret keys in the frontend.
*/

BEGIN;

CREATE OR REPLACE FUNCTION review.require_review_writer(reviewer text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'review', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_reviewer text := nullif(btrim(reviewer), '');
BEGIN
  IF v_reviewer IS NULL THEN
    RAISE EXCEPTION 'reviewer is required';
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
BEGIN
  RETURN jsonb_build_object(
    'authenticated', v_uid IS NOT NULL,
    'allowed', true,
    'public_write_mode', true,
    'email', v_email
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.current_review_writer_status() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.link_match_candidate_option(bigint, text, text, text, text, text, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.unlink_match_candidate_option(bigint, text, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_match_candidate_queue_cell(bigint, text, text, text, text) TO anon, authenticated, service_role;

COMMIT;
