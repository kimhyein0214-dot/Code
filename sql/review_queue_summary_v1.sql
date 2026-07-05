/*
  review_queue_summary_v1.sql

  Full-count summary for the GitHub Pages static review app.
  The app may load only a page of rows for responsiveness, but count widgets
  must reflect the full operating review queue.
*/

BEGIN;

CREATE OR REPLACE FUNCTION public.review_queue_summary_v1()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
WITH base AS (
  SELECT
    source_channel,
    match_tier,
    review_required,
    recommended_action,
    match_reason,
    duplicate_candidate_count,
    duplicate_risk,
    stock_compare_status,
    has_sellpia_image,
    best_sellpia_product_code,
    best_sellpia_sku_code,
    lower(concat_ws(
      ' ',
      match_tier,
      recommended_action,
      match_reason,
      duplicate_risk,
      channel_product_name,
      channel_option_name
    )) AS text_blob
  FROM public.mapping_matrix_review_full_v3
),
classified AS (
  SELECT
    *,
    (best_sellpia_product_code IS NOT NULL OR best_sellpia_sku_code IS NOT NULL) AS has_sellpia_link,
    (
      coalesce(duplicate_candidate_count, 0) > 1
      OR coalesce(duplicate_risk::text, '') ILIKE ANY (ARRAY['%duplicate%', '%conflict%', '%중복%', '%충돌%'])
      OR coalesce(match_reason, '') ILIKE ANY (ARRAY['%duplicate%', '%conflict%', '%중복%', '%충돌%'])
      OR coalesce(recommended_action, '') ILIKE ANY (ARRAY['%duplicate%', '%conflict%', '%중복%', '%충돌%'])
    ) AS is_conflict,
    (
      match_tier = 'NO_MATCH'
      OR best_sellpia_product_code IS NULL
      OR best_sellpia_sku_code IS NULL
      OR stock_compare_status = 'STOCK_SMARTSTORE_NOT_FOUND'
    ) AS needs_linking,
    (recommended_action = '수동 연동 해제됨') AS is_manually_unlinked,
    CASE
      WHEN match_tier = 'NO_MATCH' THEN 'no_match'
      WHEN text_blob ~ '(단종|삭제|제외|excluded|discontinued|hidden)' THEN 'excluded'
      WHEN text_blob ~ '(세트|조합|bundle|(^|[^a-z0-9])set([^a-z0-9]|$))' THEN 'bundle'
      WHEN text_blob ~ '(보조옵션|보조 옵션|하위옵션|suboption|추가상품)' THEN 'suboption'
      WHEN text_blob ~ '(코드 근거|코드공백|코드 공백|자사코드 공백|code blank|blank code)' THEN 'code_blank'
      WHEN match_tier IN ('AUTO_APPROVE_CANDIDATE', 'MANUAL_LINKED') THEN 'candidate'
      WHEN stock_compare_status = 'STOCK_MATCH' THEN 'stock_match'
      WHEN stock_compare_status = 'STOCK_DIFF' THEN 'stock_diff'
      WHEN stock_compare_status = 'STOCK_SMARTSTORE_NOT_FOUND' THEN 'stock_missing'
      WHEN review_required IS TRUE OR match_tier IN ('REVIEW', 'FAST_REVIEW', 'DUPLICATE_REVIEW') THEN 'hold'
      ELSE 'hold'
    END AS workflow_bucket
  FROM base
),
by_channel AS (
  SELECT
    source_channel,
    count(*)::bigint AS rows,
    count(*) FILTER (WHERE review_required IS TRUE)::bigint AS review_required_rows,
    count(*) FILTER (WHERE match_tier IN ('REVIEW', 'NO_MATCH'))::bigint AS manual_scope_rows,
    count(*) FILTER (WHERE match_tier = 'AUTO_APPROVE_CANDIDATE')::bigint AS auto_candidate_rows,
    count(*) FILTER (WHERE match_tier = 'FAST_REVIEW')::bigint AS fast_review_rows,
    count(*) FILTER (WHERE is_conflict)::bigint AS conflict_rows,
    count(*) FILTER (WHERE needs_linking)::bigint AS needs_linking_rows,
    count(*) FILTER (WHERE has_sellpia_link AND NOT is_manually_unlinked)::bigint AS linked_rows,
    count(*) FILTER (WHERE is_manually_unlinked)::bigint AS manually_unlinked_rows,
    count(*) FILTER (
      WHERE review_required IS TRUE
         OR is_conflict
         OR needs_linking
         OR match_tier <> 'AUTO_APPROVE_CANDIDATE'
    )::bigint AS manual_pending_rows,
    count(*) FILTER (WHERE has_sellpia_image IS TRUE)::bigint AS image_linked_rows,
    coalesce(sum(coalesce(duplicate_candidate_count, 0)), 0)::bigint AS duplicate_detail_estimate,
    count(*) FILTER (WHERE workflow_bucket = 'candidate')::bigint AS workflow_candidate_rows,
    count(*) FILTER (WHERE workflow_bucket = 'hold')::bigint AS workflow_hold_rows,
    count(*) FILTER (WHERE workflow_bucket = 'code_blank')::bigint AS workflow_code_blank_rows,
    count(*) FILTER (WHERE workflow_bucket = 'no_match')::bigint AS workflow_no_match_rows,
    count(*) FILTER (WHERE workflow_bucket = 'excluded')::bigint AS workflow_excluded_rows,
    count(*) FILTER (WHERE workflow_bucket = 'bundle')::bigint AS workflow_bundle_rows,
    count(*) FILTER (WHERE workflow_bucket = 'suboption')::bigint AS workflow_suboption_rows,
    count(*) FILTER (WHERE source_channel = 'smartstore')::bigint AS smartstore_rows,
    count(*) FILTER (WHERE source_channel = 'smartstore' AND stock_compare_status = 'STOCK_MATCH')::bigint AS stock_match_rows,
    count(*) FILTER (WHERE source_channel = 'smartstore' AND stock_compare_status = 'STOCK_DIFF')::bigint AS stock_diff_rows,
    count(*) FILTER (WHERE source_channel = 'smartstore' AND stock_compare_status = 'STOCK_HOLD_REVIEW')::bigint AS stock_hold_rows,
    count(*) FILTER (WHERE source_channel = 'smartstore' AND stock_compare_status = 'STOCK_SMARTSTORE_NOT_FOUND')::bigint AS stock_missing_rows
  FROM classified
  GROUP BY source_channel
),
totals AS (
  SELECT
    count(*)::bigint AS rows,
    count(*) FILTER (WHERE review_required IS TRUE)::bigint AS review_required_rows,
    count(*) FILTER (WHERE match_tier IN ('REVIEW', 'NO_MATCH'))::bigint AS manual_scope_rows,
    count(*) FILTER (WHERE match_tier = 'AUTO_APPROVE_CANDIDATE')::bigint AS auto_candidate_rows,
    count(*) FILTER (WHERE match_tier = 'FAST_REVIEW')::bigint AS fast_review_rows,
    count(*) FILTER (WHERE is_conflict)::bigint AS conflict_rows,
    count(*) FILTER (WHERE needs_linking)::bigint AS needs_linking_rows,
    count(*) FILTER (WHERE has_sellpia_link AND NOT is_manually_unlinked)::bigint AS linked_rows,
    count(*) FILTER (WHERE is_manually_unlinked)::bigint AS manually_unlinked_rows,
    count(*) FILTER (
      WHERE review_required IS TRUE
         OR is_conflict
         OR needs_linking
         OR match_tier <> 'AUTO_APPROVE_CANDIDATE'
    )::bigint AS manual_pending_rows,
    count(*) FILTER (WHERE has_sellpia_image IS TRUE)::bigint AS image_linked_rows,
    coalesce(sum(coalesce(duplicate_candidate_count, 0)), 0)::bigint AS duplicate_detail_estimate,
    count(*) FILTER (WHERE workflow_bucket = 'candidate')::bigint AS workflow_candidate_rows,
    count(*) FILTER (WHERE workflow_bucket = 'hold')::bigint AS workflow_hold_rows,
    count(*) FILTER (WHERE workflow_bucket = 'code_blank')::bigint AS workflow_code_blank_rows,
    count(*) FILTER (WHERE workflow_bucket = 'no_match')::bigint AS workflow_no_match_rows,
    count(*) FILTER (WHERE workflow_bucket = 'excluded')::bigint AS workflow_excluded_rows,
    count(*) FILTER (WHERE workflow_bucket = 'bundle')::bigint AS workflow_bundle_rows,
    count(*) FILTER (WHERE workflow_bucket = 'suboption')::bigint AS workflow_suboption_rows,
    count(*) FILTER (WHERE source_channel = 'smartstore')::bigint AS smartstore_rows,
    count(*) FILTER (WHERE source_channel = 'smartstore' AND stock_compare_status = 'STOCK_MATCH')::bigint AS stock_match_rows,
    count(*) FILTER (WHERE source_channel = 'smartstore' AND stock_compare_status = 'STOCK_DIFF')::bigint AS stock_diff_rows,
    count(*) FILTER (WHERE source_channel = 'smartstore' AND stock_compare_status = 'STOCK_HOLD_REVIEW')::bigint AS stock_hold_rows,
    count(*) FILTER (WHERE source_channel = 'smartstore' AND stock_compare_status = 'STOCK_SMARTSTORE_NOT_FOUND')::bigint AS stock_missing_rows
  FROM classified
)
SELECT jsonb_build_object(
  'generated_at', now(),
  'totals', to_jsonb(totals.*),
  'by_channel', coalesce(
    (SELECT jsonb_object_agg(source_channel, to_jsonb(by_channel.*) - 'source_channel') FROM by_channel),
    '{}'::jsonb
  )
)
FROM totals;
$function$;

REVOKE EXECUTE ON FUNCTION public.review_queue_summary_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.review_queue_summary_v1() TO anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS review.review_queue_summary_cache_v1 (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  summary_json jsonb NOT NULL,
  refreshed_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO review.review_queue_summary_cache_v1 (singleton, summary_json, refreshed_at)
SELECT true, public.review_queue_summary_v1(), now()
ON CONFLICT (singleton)
DO UPDATE SET
  summary_json = EXCLUDED.summary_json,
  refreshed_at = EXCLUDED.refreshed_at;

CREATE OR REPLACE FUNCTION public.review_queue_summary_v1()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'review', 'public', 'pg_temp'
AS $function$
  SELECT summary_json || jsonb_build_object('refreshed_at', refreshed_at)
  FROM review.review_queue_summary_cache_v1
  WHERE singleton IS TRUE;
$function$;

REVOKE EXECUTE ON FUNCTION public.review_queue_summary_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.review_queue_summary_v1() TO anon, authenticated, service_role;

COMMIT;
