/*
  postcheck_read_model_v1.sql

  Purpose:
  - Validate draft read model parity after applying draft_read_model_v1.sql without the ROLLBACK wrapper.

  Status:
  - Draft only.
  - SELECT-only.
*/

BEGIN READ ONLY;

SELECT
  'total_parity' AS check_name,
  (SELECT COUNT(*) FROM public.mapping_matrix_review_full_v3) AS base_count,
  (SELECT COUNT(*) FROM public.mapping_matrix_list_v1) AS list_count,
  CASE
    WHEN (SELECT COUNT(*) FROM public.mapping_matrix_review_full_v3)
       = (SELECT COUNT(*) FROM public.mapping_matrix_list_v1)
    THEN 'PASS'
    ELSE 'FAIL'
  END AS result;

SELECT
  'channel_parity' AS check_name,
  base.source_channel,
  base.row_count AS base_count,
  list.row_count AS list_count,
  CASE WHEN base.row_count = list.row_count THEN 'PASS' ELSE 'FAIL' END AS result
FROM (
  SELECT source_channel, COUNT(*) AS row_count
  FROM public.mapping_matrix_review_full_v3
  GROUP BY source_channel
) AS base
FULL OUTER JOIN (
  SELECT source_channel, COUNT(*) AS row_count
  FROM public.mapping_matrix_list_v1
  GROUP BY source_channel
) AS list
  ON list.source_channel IS NOT DISTINCT FROM base.source_channel
ORDER BY COALESCE(base.source_channel, list.source_channel);

SELECT
  'match_tier_parity' AS check_name,
  base.match_tier,
  base.row_count AS base_count,
  list.row_count AS list_count,
  CASE WHEN base.row_count = list.row_count THEN 'PASS' ELSE 'FAIL' END AS result
FROM (
  SELECT match_tier, COUNT(*) AS row_count
  FROM public.mapping_matrix_review_full_v3
  GROUP BY match_tier
) AS base
FULL OUTER JOIN (
  SELECT match_tier, COUNT(*) AS row_count
  FROM public.mapping_matrix_list_v1
  GROUP BY match_tier
) AS list
  ON list.match_tier IS NOT DISTINCT FROM base.match_tier
ORDER BY COALESCE(base.match_tier, list.match_tier);

SELECT
  'manual_queue_scope' AS check_name,
  source_channel,
  match_tier,
  review_required,
  stock_compare_status,
  COUNT(*) AS row_count
FROM public.manual_review_queue_light_v1
GROUP BY source_channel, match_tier, review_required, stock_compare_status
ORDER BY row_count DESC, source_channel, match_tier
LIMIT 100;

SELECT
  'summary_rows' AS check_name,
  dimension,
  value,
  row_count
FROM public.mapping_matrix_summary_v1
ORDER BY dimension, row_count DESC, value
LIMIT 200;

ROLLBACK;
