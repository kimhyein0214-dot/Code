/*
  apply_auto_approval_candidates_v1.sql

  Purpose:
  - Apply the reviewed auto-approval candidate reduction to operating Supabase.
  - Update review.match_candidate_queue rows selected by the v1 candidate policy.
  - Persist a before-state snapshot for rollback.

  Safety:
  - Stops unless candidate counts exactly match the approved dry-run.
  - Stops if any channel option key maps to more than one Sellpia key.
  - Stops if this apply marker was already backed up.

  Expected counts:
  - P1_SAFE_UNTAGGED / ably: 1179
  - P1_SAFE_UNTAGGED / coupang: 662
  - P1_SAFE_UNTAGGED / makeshop: 595
  - P2_HOLD_PROMOTION_SAFE / makeshop: 2031
  - Total: 4467

  Rollback:
  - Use sql/rollback_auto_approval_candidates_v1.sql.
*/

BEGIN;

CREATE TABLE IF NOT EXISTS review.auto_approval_apply_backup_v1 (
  apply_marker text NOT NULL,
  queue_id bigint NOT NULL,
  backed_up_at timestamptz NOT NULL DEFAULT now(),
  dryrun_group text NOT NULL,
  candidate_rule text NOT NULL,
  source_channel text,
  source_candidate_key text,
  channel_product_code text,
  channel_option_code text,
  best_sellpia_product_code text,
  best_sellpia_sku_code text,
  before_match_tier text,
  before_review_required boolean,
  before_recommended_action text,
  before_best_sellpia_product_code text,
  before_best_sellpia_sku_code text,
  before_best_sellpia_product_name text,
  before_best_sellpia_option_name text,
  before_evidence_json jsonb,
  before_updated_at timestamptz,
  PRIMARY KEY (apply_marker, queue_id)
);

DROP TABLE IF EXISTS pg_temp.auto_approval_candidates_v1;

CREATE TEMP TABLE auto_approval_candidates_v1 AS
WITH manual_scope AS (
  SELECT
    m.*,
    lower(regexp_replace(coalesce(m.channel_product_name, ''), '[\s\[\]\(\)\{\}<>_\-\./|]+', '', 'g')) AS cp_norm,
    lower(regexp_replace(coalesce(m.best_sellpia_product_name, ''), '[\s\[\]\(\)\{\}<>_\-\./|]+', '', 'g')) AS sp_norm,
    lower(regexp_replace(regexp_replace(regexp_replace(regexp_replace(coalesce(m.channel_option_name, ''), '\[[^\]]*\]', '', 'g'), '(=|\r|\n).*$', '', 'g'), '-?모델착용', '', 'g'), '[\s\[\]\(\)\{\}<>_\-\./|,*]+', '', 'g')) AS co_clean_norm,
    lower(regexp_replace(regexp_replace(regexp_replace(regexp_replace(coalesce(m.best_sellpia_option_name, ''), '\[[^\]]*\]', '', 'g'), '(=|\r|\n).*$', '', 'g'), '-?모델착용', '', 'g'), '[\s\[\]\(\)\{\}<>_\-\./|,*]+', '', 'g')) AS so_clean_norm,
    lower(concat_ws(' ', m.channel_product_name, m.channel_option_name, m.best_sellpia_product_name, m.best_sellpia_option_name, m.match_reason, m.recommended_action)) AS risk_text
  FROM public.mapping_matrix_review_full_v3 m
  WHERE m.match_tier IN ('REVIEW', 'NO_MATCH')
),
classified AS (
  SELECT
    m.*,
    m.best_sellpia_product_code IS NOT NULL AND m.best_sellpia_sku_code IS NOT NULL AS has_code_pair,
    coalesce(m.duplicate_candidate_count, 0) <= 1 AND coalesce(m.duplicate_risk::text, '') NOT IN ('true', 't', '1', 'yes', 'Y') AS no_duplicate,
    coalesce(m.stock_compare_status, 'STOCK_MATCH') = 'STOCK_MATCH' AS stock_ok,
    NOT (
      m.risk_text LIKE ANY (ARRAY['%세트%', '%묶음%', '%1+1%', '%랜덤%', '%혼합%', '%대체%', '%교환%', '%단종%', '%삭제%', '%품절%', '%sold out%', '%crystal ab%', '%크리스탈ab%', '%[xxx]%'])
      OR m.risk_text ~ '(^|[^a-z0-9가-힣])ab([^a-z0-9가-힣]|$)'
      OR m.risk_text ~ '(^|[^a-z0-9가-힣])set([^a-z0-9가-힣]|$)'
    ) AS no_risk_text,
    m.cp_norm <> '' AND m.sp_norm <> '' AND m.cp_norm = m.sp_norm AS product_exact,
    m.cp_norm <> '' AND m.sp_norm <> '' AND (m.cp_norm = m.sp_norm OR position(m.sp_norm IN m.cp_norm) > 0 OR position(m.cp_norm IN m.sp_norm) > 0) AS product_match,
    m.co_clean_norm <> '' AND m.so_clean_norm <> '' AND m.co_clean_norm = m.so_clean_norm AS option_exact
  FROM manual_scope m
),
strict_match AS (
  SELECT
    c.*,
    concat_ws('|', c.source_channel, c.channel_product_code, c.channel_option_code) AS channel_option_key,
    concat_ws('|', c.best_sellpia_product_code, c.best_sellpia_sku_code) AS sellpia_key
  FROM classified c
  WHERE c.has_code_pair
    AND c.no_duplicate
    AND c.stock_ok
    AND c.no_risk_text
    AND c.product_match
    AND c.option_exact
),
p1_candidates AS (
  SELECT
    s.queue_id,
    s.source_channel,
    s.source_candidate_key,
    s.channel_product_code,
    s.channel_option_code,
    s.best_sellpia_product_code,
    s.best_sellpia_sku_code,
    s.channel_option_key,
    s.sellpia_key,
    CASE
      WHEN s.product_exact THEN 'P1A_PRODUCT_EXACT_OPTION_EXACT'
      ELSE 'P1B_PRODUCT_CONTAINS_OPTION_EXACT'
    END AS candidate_rule,
    'P1_SAFE_UNTAGGED'::text AS dryrun_group
  FROM strict_match s
  WHERE s.recommended_action <> '자동 승인하지 않음'
    AND NOT s.has_manual_tag
),
hold_candidates AS (
  SELECT
    s.queue_id,
    s.source_channel,
    s.source_candidate_key,
    s.channel_product_code,
    s.channel_option_code,
    s.best_sellpia_product_code,
    s.best_sellpia_sku_code,
    s.channel_option_key,
    s.sellpia_key,
    CASE
      WHEN s.product_exact THEN 'H1_PRODUCT_EXACT_OPTION_EXACT'
      ELSE 'H2_PRODUCT_CONTAINS_OPTION_EXACT'
    END AS candidate_rule
  FROM strict_match s
  WHERE s.recommended_action = '자동 승인하지 않음'
    AND NOT s.has_manual_tag
),
hold_key_conflicts AS (
  SELECT
    h.candidate_rule,
    h.source_channel,
    h.channel_option_key,
    count(DISTINCT h.sellpia_key) AS distinct_sellpia_keys
  FROM hold_candidates h
  GROUP BY h.candidate_rule, h.source_channel, h.channel_option_key
),
p2_candidates AS (
  SELECT
    h.queue_id,
    h.source_channel,
    h.source_candidate_key,
    h.channel_product_code,
    h.channel_option_code,
    h.best_sellpia_product_code,
    h.best_sellpia_sku_code,
    h.channel_option_key,
    h.sellpia_key,
    h.candidate_rule,
    'P2_HOLD_PROMOTION_SAFE'::text AS dryrun_group
  FROM hold_candidates h
  JOIN hold_key_conflicts k
    ON k.candidate_rule = h.candidate_rule
   AND k.source_channel = h.source_channel
   AND k.channel_option_key = h.channel_option_key
  WHERE h.candidate_rule = 'H1_PRODUCT_EXACT_OPTION_EXACT'
    AND h.source_channel = 'makeshop'
    AND k.distinct_sellpia_keys = 1
)
SELECT * FROM p1_candidates
UNION ALL
SELECT * FROM p2_candidates;

DO $$
DECLARE
  v_total integer;
  v_existing_backup integer;
  v_conflict_count integer;
  v_updated integer;
BEGIN
  SELECT count(*) INTO v_total FROM pg_temp.auto_approval_candidates_v1;
  IF v_total <> 4467 THEN
    RAISE EXCEPTION 'candidate total mismatch: expected 4467, got %', v_total;
  END IF;

  IF (SELECT count(*) FROM pg_temp.auto_approval_candidates_v1 WHERE dryrun_group = 'P1_SAFE_UNTAGGED' AND source_channel = 'ably') <> 1179 THEN
    RAISE EXCEPTION 'P1 ably count mismatch';
  END IF;
  IF (SELECT count(*) FROM pg_temp.auto_approval_candidates_v1 WHERE dryrun_group = 'P1_SAFE_UNTAGGED' AND source_channel = 'coupang') <> 662 THEN
    RAISE EXCEPTION 'P1 coupang count mismatch';
  END IF;
  IF (SELECT count(*) FROM pg_temp.auto_approval_candidates_v1 WHERE dryrun_group = 'P1_SAFE_UNTAGGED' AND source_channel = 'makeshop') <> 595 THEN
    RAISE EXCEPTION 'P1 makeshop count mismatch';
  END IF;
  IF (SELECT count(*) FROM pg_temp.auto_approval_candidates_v1 WHERE dryrun_group = 'P2_HOLD_PROMOTION_SAFE' AND source_channel = 'makeshop') <> 2031 THEN
    RAISE EXCEPTION 'P2 makeshop count mismatch';
  END IF;

  SELECT count(*)
    INTO v_conflict_count
  FROM (
    SELECT dryrun_group, source_channel, channel_option_key
    FROM pg_temp.auto_approval_candidates_v1
    GROUP BY dryrun_group, source_channel, channel_option_key
    HAVING count(DISTINCT sellpia_key) > 1
  ) conflicts;

  IF v_conflict_count <> 0 THEN
    RAISE EXCEPTION 'candidate conflict check failed: % conflicting keys', v_conflict_count;
  END IF;

  SELECT count(*)
    INTO v_existing_backup
  FROM review.auto_approval_apply_backup_v1
  WHERE apply_marker = 'auto_approval_candidates_v1';

  IF v_existing_backup <> 0 THEN
    RAISE EXCEPTION 'backup marker auto_approval_candidates_v1 already exists: % rows', v_existing_backup;
  END IF;

  INSERT INTO review.auto_approval_apply_backup_v1 (
    apply_marker,
    queue_id,
    dryrun_group,
    candidate_rule,
    source_channel,
    source_candidate_key,
    channel_product_code,
    channel_option_code,
    best_sellpia_product_code,
    best_sellpia_sku_code,
    before_match_tier,
    before_review_required,
    before_recommended_action,
    before_best_sellpia_product_code,
    before_best_sellpia_sku_code,
    before_best_sellpia_product_name,
    before_best_sellpia_option_name,
    before_evidence_json,
    before_updated_at
  )
  SELECT
    'auto_approval_candidates_v1',
    q.queue_id,
    c.dryrun_group,
    c.candidate_rule,
    q.source_channel,
    q.source_candidate_key,
    q.channel_product_code,
    q.channel_option_code,
    q.best_sellpia_product_code,
    q.best_sellpia_sku_code,
    q.match_tier,
    q.review_required,
    q.recommended_action,
    q.best_sellpia_product_code,
    q.best_sellpia_sku_code,
    q.best_sellpia_product_name,
    q.best_sellpia_option_name,
    q.evidence_json,
    q.updated_at
  FROM review.match_candidate_queue q
  JOIN pg_temp.auto_approval_candidates_v1 c ON c.queue_id = q.queue_id;

  IF (SELECT count(*) FROM review.auto_approval_apply_backup_v1 WHERE apply_marker = 'auto_approval_candidates_v1') <> 4467 THEN
    RAISE EXCEPTION 'backup insert count mismatch';
  END IF;

  UPDATE review.match_candidate_queue q
  SET
    match_tier = 'AUTO_APPROVE_CANDIDATE',
    review_required = false,
    recommended_action = '자동 승인됨 - auto_approval_candidates_v1',
    evidence_json = jsonb_set(
      coalesce(q.evidence_json, '{}'::jsonb),
      '{auto_approval_events}',
      coalesce(coalesce(q.evidence_json, '{}'::jsonb)->'auto_approval_events', '[]'::jsonb)
        || jsonb_build_array(
          jsonb_build_object(
            'event', 'auto_approve',
            'marker', 'auto_approval_candidates_v1',
            'dryrun_group', c.dryrun_group,
            'candidate_rule', c.candidate_rule,
            'applied_at', now(),
            'before', jsonb_build_object(
              'match_tier', q.match_tier,
              'review_required', q.review_required,
              'recommended_action', q.recommended_action
            ),
            'after', jsonb_build_object(
              'match_tier', 'AUTO_APPROVE_CANDIDATE',
              'review_required', false,
              'recommended_action', '자동 승인됨 - auto_approval_candidates_v1'
            )
          )
        ),
      true
    ),
    updated_at = now()
  FROM pg_temp.auto_approval_candidates_v1 c
  WHERE c.queue_id = q.queue_id;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated <> 4467 THEN
    RAISE EXCEPTION 'updated row count mismatch: expected 4467, got %', v_updated;
  END IF;
END $$;

SELECT
  'apply_auto_approval_candidates_v1' AS check_name,
  count(*) AS applied_rows,
  count(*) FILTER (WHERE match_tier = 'AUTO_APPROVE_CANDIDATE') AS auto_approve_rows,
  count(*) FILTER (WHERE review_required IS FALSE) AS review_not_required_rows,
  count(*) FILTER (WHERE recommended_action = '자동 승인됨 - auto_approval_candidates_v1') AS marker_rows
FROM review.match_candidate_queue q
JOIN pg_temp.auto_approval_candidates_v1 c ON c.queue_id = q.queue_id;

COMMIT;
