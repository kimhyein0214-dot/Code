/*
  dryrun_auto_approval_candidates_v1.sql

  Purpose:
  - Read-only dry-run for reducing manual product-code matching review rows.
  - Build a queue_id based candidate list from public.mapping_matrix_review_full_v3.
  - Report the current state, proposed dry-run group, conflict checks, and preview rows.

  Status:
  - SELECT only.
  - No INSERT/UPDATE/DELETE.
  - No DDL.
  - Safe to run against the operating Supabase database for verification.

  Current intended candidate policy:
  - P1_SAFE_UNTAGGED:
      Existing non-"자동 승인하지 않음" rows that pass strict matching gates.
  - P2_HOLD_PROMOTION_SAFE:
      Rows currently marked "자동 승인하지 않음" but passing the stricter H1 gate:
      MakeShop only, product exact, option exact, no conflict.

  Important:
  - This file does not approve anything.
  - Treat all counts as dry-run evidence until a separate apply SQL is reviewed.
*/

WITH manual_scope AS (
  SELECT
    m.*,
    lower(regexp_replace(coalesce(m.channel_product_name, ''), '[\s\[\]\(\)\{\}<>_\-\./|]+', '', 'g')) AS cp_norm,
    lower(regexp_replace(coalesce(m.best_sellpia_product_name, ''), '[\s\[\]\(\)\{\}<>_\-\./|]+', '', 'g')) AS sp_norm,
    lower(
      regexp_replace(
        regexp_replace(
          regexp_replace(
            regexp_replace(coalesce(m.channel_option_name, ''), '\[[^\]]*\]', '', 'g'),
            '(=|\r|\n).*$', '', 'g'
          ),
          '-?모델착용', '', 'g'
        ),
        '[\s\[\]\(\)\{\}<>_\-\./|,*]+', '', 'g'
      )
    ) AS co_clean_norm,
    lower(
      regexp_replace(
        regexp_replace(
          regexp_replace(
            regexp_replace(coalesce(m.best_sellpia_option_name, ''), '\[[^\]]*\]', '', 'g'),
            '(=|\r|\n).*$', '', 'g'
          ),
          '-?모델착용', '', 'g'
        ),
        '[\s\[\]\(\)\{\}<>_\-\./|,*]+', '', 'g'
      )
    ) AS so_clean_norm,
    lower(
      concat_ws(
        ' ',
        m.channel_product_name,
        m.channel_option_name,
        m.best_sellpia_product_name,
        m.best_sellpia_option_name,
        m.match_reason,
        m.recommended_action
      )
    ) AS risk_text
  FROM public.mapping_matrix_review_full_v3 m
  WHERE m.match_tier IN ('REVIEW', 'NO_MATCH')
),
classified AS (
  SELECT
    m.*,
    m.best_sellpia_product_code IS NOT NULL
      AND m.best_sellpia_sku_code IS NOT NULL AS has_code_pair,
    coalesce(m.duplicate_candidate_count, 0) <= 1
      AND coalesce(m.duplicate_risk::text, '') NOT IN ('true', 't', '1', 'yes', 'Y') AS no_duplicate,
    coalesce(m.stock_compare_status, 'STOCK_MATCH') = 'STOCK_MATCH' AS stock_ok,
    NOT (
      m.risk_text LIKE ANY (
        ARRAY[
          '%세트%',
          '%묶음%',
          '%1+1%',
          '%랜덤%',
          '%혼합%',
          '%대체%',
          '%교환%',
          '%단종%',
          '%삭제%',
          '%품절%',
          '%sold out%',
          '%crystal ab%',
          '%크리스탈ab%',
          '%[xxx]%'
        ]
      )
      OR m.risk_text ~ '(^|[^a-z0-9가-힣])ab([^a-z0-9가-힣]|$)'
      OR m.risk_text ~ '(^|[^a-z0-9가-힣])set([^a-z0-9가-힣]|$)'
    ) AS no_risk_text,
    m.cp_norm <> ''
      AND m.sp_norm <> ''
      AND m.cp_norm = m.sp_norm AS product_exact,
    m.cp_norm <> ''
      AND m.sp_norm <> ''
      AND (
        m.cp_norm = m.sp_norm
        OR position(m.sp_norm IN m.cp_norm) > 0
        OR position(m.cp_norm IN m.sp_norm) > 0
      ) AS product_match,
    m.co_clean_norm <> ''
      AND m.so_clean_norm <> ''
      AND m.co_clean_norm = m.so_clean_norm AS option_exact
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
    s.*,
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
    s.*,
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
    count(*) AS rows_per_key,
    count(DISTINCT h.sellpia_key) AS distinct_sellpia_keys
  FROM hold_candidates h
  GROUP BY h.candidate_rule, h.source_channel, h.channel_option_key
),
p2_candidates AS (
  SELECT
    h.*,
    'P2_HOLD_PROMOTION_SAFE'::text AS dryrun_group
  FROM hold_candidates h
  JOIN hold_key_conflicts k
    ON k.candidate_rule = h.candidate_rule
   AND k.source_channel = h.source_channel
   AND k.channel_option_key = h.channel_option_key
  WHERE h.candidate_rule = 'H1_PRODUCT_EXACT_OPTION_EXACT'
    AND h.source_channel = 'makeshop'
    AND k.distinct_sellpia_keys = 1
),
proposed_candidates AS (
  SELECT * FROM p1_candidates
  UNION ALL
  SELECT * FROM p2_candidates
),
proposed_key_conflicts AS (
  SELECT
    p.dryrun_group,
    p.source_channel,
    p.channel_option_key,
    count(*) AS rows_per_key,
    count(DISTINCT p.sellpia_key) AS distinct_sellpia_keys
  FROM proposed_candidates p
  GROUP BY p.dryrun_group, p.source_channel, p.channel_option_key
)
SELECT
  '01_manual_scope_summary' AS report_section,
  count(*) AS total_rows,
  count(*) FILTER (WHERE match_tier = 'REVIEW') AS review_rows,
  count(*) FILTER (WHERE match_tier = 'NO_MATCH') AS no_match_rows,
  count(*) FILTER (WHERE review_required IS TRUE) AS review_required_rows
FROM manual_scope;

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
  WHERE c.has_code_pair AND c.no_duplicate AND c.stock_ok AND c.no_risk_text AND c.product_match AND c.option_exact
),
p1_candidates AS (
  SELECT
    s.*,
    CASE WHEN s.product_exact THEN 'P1A_PRODUCT_EXACT_OPTION_EXACT' ELSE 'P1B_PRODUCT_CONTAINS_OPTION_EXACT' END AS candidate_rule,
    'P1_SAFE_UNTAGGED'::text AS dryrun_group
  FROM strict_match s
  WHERE s.recommended_action <> '자동 승인하지 않음' AND NOT s.has_manual_tag
),
hold_candidates AS (
  SELECT
    s.*,
    CASE WHEN s.product_exact THEN 'H1_PRODUCT_EXACT_OPTION_EXACT' ELSE 'H2_PRODUCT_CONTAINS_OPTION_EXACT' END AS candidate_rule
  FROM strict_match s
  WHERE s.recommended_action = '자동 승인하지 않음' AND NOT s.has_manual_tag
),
hold_key_conflicts AS (
  SELECT h.candidate_rule, h.source_channel, h.channel_option_key, count(*) AS rows_per_key, count(DISTINCT h.sellpia_key) AS distinct_sellpia_keys
  FROM hold_candidates h
  GROUP BY h.candidate_rule, h.source_channel, h.channel_option_key
),
p2_candidates AS (
  SELECT h.*, 'P2_HOLD_PROMOTION_SAFE'::text AS dryrun_group
  FROM hold_candidates h
  JOIN hold_key_conflicts k ON k.candidate_rule = h.candidate_rule AND k.source_channel = h.source_channel AND k.channel_option_key = h.channel_option_key
  WHERE h.candidate_rule = 'H1_PRODUCT_EXACT_OPTION_EXACT' AND h.source_channel = 'makeshop' AND k.distinct_sellpia_keys = 1
),
proposed_candidates AS (
  SELECT * FROM p1_candidates
  UNION ALL
  SELECT * FROM p2_candidates
)
SELECT
  '02_proposed_candidate_summary' AS report_section,
  dryrun_group,
  candidate_rule,
  source_channel,
  count(*) AS row_count,
  count(DISTINCT source_candidate_key) AS distinct_candidate_keys,
  count(DISTINCT channel_option_key) AS distinct_channel_option_keys,
  count(DISTINCT sellpia_key) AS distinct_sellpia_keys
FROM proposed_candidates
GROUP BY dryrun_group, candidate_rule, source_channel
ORDER BY dryrun_group, candidate_rule, source_channel;

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
  SELECT c.*, concat_ws('|', c.source_channel, c.channel_product_code, c.channel_option_code) AS channel_option_key, concat_ws('|', c.best_sellpia_product_code, c.best_sellpia_sku_code) AS sellpia_key
  FROM classified c
  WHERE c.has_code_pair AND c.no_duplicate AND c.stock_ok AND c.no_risk_text AND c.product_match AND c.option_exact
),
p1_candidates AS (
  SELECT s.*, CASE WHEN s.product_exact THEN 'P1A_PRODUCT_EXACT_OPTION_EXACT' ELSE 'P1B_PRODUCT_CONTAINS_OPTION_EXACT' END AS candidate_rule, 'P1_SAFE_UNTAGGED'::text AS dryrun_group
  FROM strict_match s
  WHERE s.recommended_action <> '자동 승인하지 않음' AND NOT s.has_manual_tag
),
hold_candidates AS (
  SELECT s.*, CASE WHEN s.product_exact THEN 'H1_PRODUCT_EXACT_OPTION_EXACT' ELSE 'H2_PRODUCT_CONTAINS_OPTION_EXACT' END AS candidate_rule
  FROM strict_match s
  WHERE s.recommended_action = '자동 승인하지 않음' AND NOT s.has_manual_tag
),
hold_key_conflicts AS (
  SELECT h.candidate_rule, h.source_channel, h.channel_option_key, count(*) AS rows_per_key, count(DISTINCT h.sellpia_key) AS distinct_sellpia_keys
  FROM hold_candidates h
  GROUP BY h.candidate_rule, h.source_channel, h.channel_option_key
),
p2_candidates AS (
  SELECT h.*, 'P2_HOLD_PROMOTION_SAFE'::text AS dryrun_group
  FROM hold_candidates h
  JOIN hold_key_conflicts k ON k.candidate_rule = h.candidate_rule AND k.source_channel = h.source_channel AND k.channel_option_key = h.channel_option_key
  WHERE h.candidate_rule = 'H1_PRODUCT_EXACT_OPTION_EXACT' AND h.source_channel = 'makeshop' AND k.distinct_sellpia_keys = 1
),
proposed_candidates AS (
  SELECT * FROM p1_candidates
  UNION ALL
  SELECT * FROM p2_candidates
),
proposed_key_conflicts AS (
  SELECT dryrun_group, source_channel, channel_option_key, count(*) AS rows_per_key, count(DISTINCT sellpia_key) AS distinct_sellpia_keys
  FROM proposed_candidates
  GROUP BY dryrun_group, source_channel, channel_option_key
)
SELECT
  '03_conflict_check' AS report_section,
  dryrun_group,
  source_channel,
  count(*) AS channel_option_key_count,
  count(*) FILTER (WHERE distinct_sellpia_keys > 1) AS conflicting_channel_option_keys,
  coalesce(sum(rows_per_key) FILTER (WHERE distinct_sellpia_keys > 1), 0) AS conflicting_rows,
  max(distinct_sellpia_keys) AS max_sellpia_keys_per_channel_option
FROM proposed_key_conflicts
GROUP BY dryrun_group, source_channel
ORDER BY dryrun_group, source_channel;

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
  SELECT c.*, concat_ws('|', c.source_channel, c.channel_product_code, c.channel_option_code) AS channel_option_key, concat_ws('|', c.best_sellpia_product_code, c.best_sellpia_sku_code) AS sellpia_key
  FROM classified c
  WHERE c.has_code_pair AND c.no_duplicate AND c.stock_ok AND c.no_risk_text AND c.product_match AND c.option_exact
),
p1_candidates AS (
  SELECT s.*, CASE WHEN s.product_exact THEN 'P1A_PRODUCT_EXACT_OPTION_EXACT' ELSE 'P1B_PRODUCT_CONTAINS_OPTION_EXACT' END AS candidate_rule, 'P1_SAFE_UNTAGGED'::text AS dryrun_group
  FROM strict_match s
  WHERE s.recommended_action <> '자동 승인하지 않음' AND NOT s.has_manual_tag
),
hold_candidates AS (
  SELECT s.*, CASE WHEN s.product_exact THEN 'H1_PRODUCT_EXACT_OPTION_EXACT' ELSE 'H2_PRODUCT_CONTAINS_OPTION_EXACT' END AS candidate_rule
  FROM strict_match s
  WHERE s.recommended_action = '자동 승인하지 않음' AND NOT s.has_manual_tag
),
hold_key_conflicts AS (
  SELECT h.candidate_rule, h.source_channel, h.channel_option_key, count(*) AS rows_per_key, count(DISTINCT h.sellpia_key) AS distinct_sellpia_keys
  FROM hold_candidates h
  GROUP BY h.candidate_rule, h.source_channel, h.channel_option_key
),
p2_candidates AS (
  SELECT h.*, 'P2_HOLD_PROMOTION_SAFE'::text AS dryrun_group
  FROM hold_candidates h
  JOIN hold_key_conflicts k ON k.candidate_rule = h.candidate_rule AND k.source_channel = h.source_channel AND k.channel_option_key = h.channel_option_key
  WHERE h.candidate_rule = 'H1_PRODUCT_EXACT_OPTION_EXACT' AND h.source_channel = 'makeshop' AND k.distinct_sellpia_keys = 1
),
proposed_candidates AS (
  SELECT * FROM p1_candidates
  UNION ALL
  SELECT * FROM p2_candidates
)
SELECT
  '04_apply_preview' AS report_section,
  dryrun_group,
  candidate_rule,
  queue_id,
  source_channel,
  source_candidate_key,
  channel_product_code,
  channel_option_code,
  channel_product_name,
  channel_option_name,
  best_sellpia_product_code,
  best_sellpia_sku_code,
  best_sellpia_product_name,
  best_sellpia_option_name,
  match_tier AS current_match_tier,
  review_required AS current_review_required,
  recommended_action AS current_recommended_action,
  'AUTO_APPROVE_CANDIDATE' AS proposed_match_tier,
  false AS proposed_review_required,
  'dryrun_auto_approval_candidates_v1' AS proposed_evidence_marker
FROM proposed_candidates
ORDER BY dryrun_group, candidate_rule, source_channel, queue_id
LIMIT 200;
