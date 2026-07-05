/*
  postcheck_auto_approval_candidates_v1.sql

  Purpose:
  - Read-only verification after apply_auto_approval_candidates_v1.sql.
  - Confirms backup count, applied row count, marker count, and conflict state.

  Safety:
  - SELECT only.
*/

WITH backup_rows AS (
  SELECT *
  FROM review.auto_approval_apply_backup_v1
  WHERE apply_marker = 'auto_approval_candidates_v1'
),
applied_rows AS (
  SELECT
    q.queue_id,
    q.source_channel,
    b.dryrun_group,
    b.candidate_rule,
    concat_ws('|', q.source_channel, q.channel_product_code, q.channel_option_code) AS channel_option_key,
    concat_ws('|', q.best_sellpia_product_code, q.best_sellpia_sku_code) AS sellpia_key,
    q.match_tier,
    q.review_required,
    q.recommended_action,
    q.evidence_json,
    b.before_match_tier,
    b.before_review_required,
    b.before_recommended_action
  FROM review.match_candidate_queue q
  JOIN backup_rows b ON b.queue_id = q.queue_id
),
conflicts AS (
  SELECT
    dryrun_group,
    source_channel,
    channel_option_key,
    count(DISTINCT sellpia_key) AS distinct_sellpia_keys,
    count(*) AS row_count
  FROM applied_rows
  GROUP BY dryrun_group, source_channel, channel_option_key
),
summary AS (
  SELECT
    count(*) AS backup_rows,
    count(*) FILTER (WHERE dryrun_group = 'P1_SAFE_UNTAGGED' AND source_channel = 'ably') AS p1_ably_rows,
    count(*) FILTER (WHERE dryrun_group = 'P1_SAFE_UNTAGGED' AND source_channel = 'coupang') AS p1_coupang_rows,
    count(*) FILTER (WHERE dryrun_group = 'P1_SAFE_UNTAGGED' AND source_channel = 'makeshop') AS p1_makeshop_rows,
    count(*) FILTER (WHERE dryrun_group = 'P2_HOLD_PROMOTION_SAFE' AND source_channel = 'makeshop') AS p2_makeshop_rows
  FROM backup_rows
),
applied_summary AS (
  SELECT
    count(*) AS applied_rows,
    count(*) FILTER (WHERE match_tier = 'AUTO_APPROVE_CANDIDATE') AS auto_approve_rows,
    count(*) FILTER (WHERE review_required IS FALSE) AS review_not_required_rows,
    count(*) FILTER (WHERE recommended_action = '자동 승인됨 - auto_approval_candidates_v1') AS marker_rows,
    count(*) FILTER (
      WHERE coalesce(evidence_json->'auto_approval_events', '[]'::jsonb) @> '[{"marker":"auto_approval_candidates_v1"}]'::jsonb
    ) AS evidence_marker_rows
  FROM applied_rows
),
conflict_summary AS (
  SELECT
    count(*) FILTER (WHERE distinct_sellpia_keys > 1) AS conflicting_channel_option_keys,
    coalesce(sum(row_count) FILTER (WHERE distinct_sellpia_keys > 1), 0) AS conflicting_rows
  FROM conflicts
)
SELECT
  'postcheck_auto_approval_candidates_v1' AS check_name,
  s.backup_rows,
  s.p1_ably_rows,
  s.p1_coupang_rows,
  s.p1_makeshop_rows,
  s.p2_makeshop_rows,
  a.applied_rows,
  a.auto_approve_rows,
  a.review_not_required_rows,
  a.marker_rows,
  a.evidence_marker_rows,
  c.conflicting_channel_option_keys,
  c.conflicting_rows,
  CASE
    WHEN s.backup_rows = 4467
      AND s.p1_ably_rows = 1179
      AND s.p1_coupang_rows = 662
      AND s.p1_makeshop_rows = 595
      AND s.p2_makeshop_rows = 2031
      AND a.applied_rows = 4467
      AND a.auto_approve_rows = 4467
      AND a.review_not_required_rows = 4467
      AND a.marker_rows = 4467
      AND a.evidence_marker_rows = 4467
      AND c.conflicting_channel_option_keys = 0
      AND c.conflicting_rows = 0
    THEN 'PASS'
    ELSE 'FAIL'
  END AS overall_verdict
FROM summary s
CROSS JOIN applied_summary a
CROSS JOIN conflict_summary c;

SELECT
  dryrun_group,
  candidate_rule,
  source_channel,
  count(*) AS row_count
FROM review.auto_approval_apply_backup_v1
WHERE apply_marker = 'auto_approval_candidates_v1'
GROUP BY dryrun_group, candidate_rule, source_channel
ORDER BY dryrun_group, candidate_rule, source_channel;
