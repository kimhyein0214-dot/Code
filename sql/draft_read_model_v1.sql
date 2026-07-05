/*
  draft_read_model_v1.sql

  Purpose:
  - Draft read-only wrappers around mapping_matrix_review_full_v3.
  - Reduce first-screen payload by splitting list, manual-review queue, summary, and search views.

  Status:
  - Draft only.
  - Not applied.
  - Review and run in a safe database session before use.

  Safety:
  - No INSERT/UPDATE/DELETE.
  - No DROP.
  - CREATE OR REPLACE VIEW only.
*/

BEGIN;

CREATE OR REPLACE VIEW public.mapping_matrix_list_v1 AS
SELECT
  queue_id,
  source_batch_id,
  source_channel,
  source_row_no,
  channel_product_code,
  channel_option_code,
  channel_product_name,
  channel_option_name,
  channel_seller_code,
  best_sellpia_product_code,
  best_sellpia_sku_code,
  best_sellpia_product_name,
  best_sellpia_option_name,
  match_tier,
  match_score,
  duplicate_candidate_count,
  duplicate_risk,
  review_required,
  recommended_action,
  stock_compare_status,
  auto_approval_tier,
  has_sellpia_image,
  manual_tag_count,
  has_manual_tag
FROM public.mapping_matrix_review_full_v3;

CREATE OR REPLACE VIEW public.manual_review_queue_light_v1 AS
SELECT
  queue_id,
  source_batch_id,
  source_channel,
  source_row_no,
  channel_product_code,
  channel_option_code,
  channel_product_name,
  channel_option_name,
  channel_seller_code,
  best_sellpia_product_code,
  best_sellpia_sku_code,
  best_sellpia_product_name,
  best_sellpia_option_name,
  match_tier,
  match_score,
  review_required,
  recommended_action,
  stock_compare_status,
  auto_approval_tier,
  has_sellpia_image,
  manual_tag_count,
  has_manual_tag,
  CASE
    WHEN match_tier = 'NO_MATCH' THEN 10
    WHEN stock_compare_status IN ('STOCK_HOLD_REVIEW', 'STOCK_SMARTSTORE_NOT_FOUND') THEN 20
    WHEN match_tier = 'REVIEW' THEN 30
    WHEN match_tier = 'FAST_REVIEW' THEN 40
    WHEN match_tier = 'MANUAL_LINKED' THEN 90
    ELSE 50
  END AS queue_priority
FROM public.mapping_matrix_review_full_v3
WHERE
  review_required IS TRUE
  OR match_tier IN ('REVIEW', 'FAST_REVIEW', 'NO_MATCH', 'MANUAL_LINKED')
  OR stock_compare_status IN ('STOCK_HOLD_REVIEW', 'STOCK_SMARTSTORE_NOT_FOUND');

CREATE OR REPLACE VIEW public.mapping_matrix_summary_v1 AS
SELECT 'total'::text AS dimension, 'total'::text AS value, COUNT(*)::bigint AS row_count
FROM public.mapping_matrix_review_full_v3
UNION ALL
SELECT 'source_channel', COALESCE(source_channel, '(blank)'), COUNT(*)::bigint
FROM public.mapping_matrix_review_full_v3
GROUP BY source_channel
UNION ALL
SELECT 'match_tier', COALESCE(match_tier, '(blank)'), COUNT(*)::bigint
FROM public.mapping_matrix_review_full_v3
GROUP BY match_tier
UNION ALL
SELECT 'review_required', COALESCE(review_required::text, '(blank)'), COUNT(*)::bigint
FROM public.mapping_matrix_review_full_v3
GROUP BY review_required
UNION ALL
SELECT 'stock_compare_status', COALESCE(stock_compare_status, '(blank)'), COUNT(*)::bigint
FROM public.mapping_matrix_review_full_v3
GROUP BY stock_compare_status
UNION ALL
SELECT 'auto_approval_tier', COALESCE(auto_approval_tier, '(blank)'), COUNT(*)::bigint
FROM public.mapping_matrix_review_full_v3
GROUP BY auto_approval_tier
UNION ALL
SELECT 'has_sellpia_image', COALESCE(has_sellpia_image::text, '(blank)'), COUNT(*)::bigint
FROM public.mapping_matrix_review_full_v3
GROUP BY has_sellpia_image
UNION ALL
SELECT 'has_manual_tag', COALESCE(has_manual_tag::text, '(blank)'), COUNT(*)::bigint
FROM public.mapping_matrix_review_full_v3
GROUP BY has_manual_tag;

CREATE OR REPLACE VIEW public.product_code_search_v1 AS
SELECT
  queue_id,
  source_channel,
  channel_product_code,
  channel_option_code,
  channel_product_name,
  channel_option_name,
  best_sellpia_product_code,
  best_sellpia_sku_code,
  best_sellpia_product_name,
  best_sellpia_option_name,
  match_tier,
  review_required,
  concat_ws(
    ' ',
    channel_product_code,
    channel_option_code,
    channel_product_name,
    channel_option_name,
    best_sellpia_product_code,
    best_sellpia_sku_code,
    best_sellpia_product_name,
    best_sellpia_option_name
  ) AS search_text
FROM public.mapping_matrix_review_full_v3;

ROLLBACK;
