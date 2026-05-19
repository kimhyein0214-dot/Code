/*
  Smartstore Excel evidence confidence-tier validation draft.

  Purpose:
  - Assume a future stage relation named stage_excel_smartstore_evidence.
  - Join parsed Excel evidence to product_code reference relations.
  - Classify rows into practical automatic matching confidence tiers.

  Safety:
  - SELECT-only.
  - Read-only design.
  - No file output.
  - No import.
  - export_allowed remains false.
  - reviewer_decision remains pending.
*/

WITH expected_stage AS (
  SELECT
    s.source_file,
    s.source_sheet,
    s.row_no,
    s.normalized_selfpia_product_code,
    s.normalized_selfpia_sku_code,
    s.raw_product_name,
    s.normalized_product_name,
    s.raw_option_text,
    s.normalized_option_text,
    s.extracted_own_sku,
    s.smartstore_product_no_candidate,
    s.parse_status,
    s.parse_warning,
    s.evidence_level,
    false::boolean AS export_allowed,
    'pending'::text AS reviewer_decision
  FROM stage_excel_smartstore_evidence AS s
),

selfpia_alias_counts AS (
  SELECT
    ca.code_value AS selfpia_sku_code,
    COUNT(*) AS selfpia_alias_row_count,
    COUNT(DISTINCT ca.target_id) AS selfpia_sku_id_count
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'selfpia_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.code_value
),

selfpia_alias AS (
  SELECT
    ca.code_value AS selfpia_sku_code,
    ca.target_id AS sku_id,
    sac.selfpia_alias_row_count,
    sac.selfpia_sku_id_count
  FROM product_code.code_alias AS ca
  JOIN selfpia_alias_counts AS sac
    ON sac.selfpia_sku_code = ca.code_value
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'selfpia_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
),

own_sku_alias_counts AS (
  SELECT
    ca.code_value AS own_sku_code,
    COUNT(*) AS own_sku_alias_row_count,
    COUNT(DISTINCT ca.target_id) AS own_sku_id_count
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.code_value
),

own_sku_alias AS (
  SELECT
    ca.code_value AS own_sku_code,
    ca.target_id AS sku_id,
    oac.own_sku_alias_row_count,
    oac.own_sku_id_count
  FROM product_code.code_alias AS ca
  JOIN own_sku_alias_counts AS oac
    ON oac.own_sku_code = ca.code_value
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
),

smartstore_alias_by_sku AS (
  SELECT
    ca.target_id AS sku_id,
    COUNT(DISTINCT ca.code_value) FILTER (
      WHERE ca.code_system IN ('smartstore_product_no', 'smartstore_product_no_candidate')
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS smartstore_product_no_alias_count,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system = 'smartstore_product_no'
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS registered_smartstore_product_no,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system = 'smartstore_product_no_candidate'
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS registered_smartstore_product_no_candidate
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system IN (
      'smartstore_product_no',
      'smartstore_product_no_candidate',
      'smartstore_option_no',
      'smartstore_option_no_candidate'
    )
  GROUP BY ca.target_id
),

smartstore_mapping_by_sku AS (
  SELECT
    scm.sku_id,
    COUNT(DISTINCT scm.seller_product_code) FILTER (
      WHERE NULLIF(btrim(scm.seller_product_code), '') IS NOT NULL
    ) AS mapping_product_no_count,
    MIN(scm.seller_product_code) FILTER (
      WHERE NULLIF(btrim(scm.seller_product_code), '') IS NOT NULL
    ) AS mapping_product_no
  FROM product_code.sku_channel_mapping AS scm
  WHERE lower(scm.channel_code) = 'smartstore'
  GROUP BY scm.sku_id
),

stage_joined AS (
  SELECT
    es.*,
    sa.sku_id AS selfpia_joined_sku_id,
    sa.selfpia_alias_row_count,
    sa.selfpia_sku_id_count,
    oa.sku_id AS own_sku_joined_sku_id,
    oa.own_sku_alias_row_count,
    oa.own_sku_id_count,
    vc.product_id,
    vc.product_name AS db_product_name,
    vc.option_value AS db_option_text,
    sm.virtual_sku_code,
    sm.status AS sku_status,
    pm.virtual_product_code,
    pm.product_name AS product_master_name,
    sab.registered_smartstore_product_no,
    sab.registered_smartstore_product_no_candidate,
    sab.smartstore_product_no_alias_count,
    smb.mapping_product_no,
    smb.mapping_product_no_count,
    lower(regexp_replace(COALESCE(es.normalized_product_name, es.raw_product_name, ''), '[^[:alnum:]가-힣]+', '', 'g')) AS stage_product_name_key,
    lower(regexp_replace(COALESCE(vc.product_name, pm.product_name, ''), '[^[:alnum:]가-힣]+', '', 'g')) AS db_product_name_key,
    lower(COALESCE(es.normalized_option_text, es.raw_option_text, '')) AS stage_option_raw_key,
    lower(COALESCE(vc.option_value, '')) AS db_option_raw_key
  FROM expected_stage AS es
  LEFT JOIN selfpia_alias AS sa
    ON sa.selfpia_sku_code = es.normalized_selfpia_sku_code
  LEFT JOIN own_sku_alias AS oa
    ON oa.own_sku_code = es.extracted_own_sku
  LEFT JOIN product_code.v_sku_canonical AS vc
    ON vc.sku_id = sa.sku_id
  LEFT JOIN product_code.sku_master AS sm
    ON sm.id = sa.sku_id
  LEFT JOIN product_code.product_master AS pm
    ON pm.id = sm.product_id
  LEFT JOIN smartstore_alias_by_sku AS sab
    ON sab.sku_id = sa.sku_id
  LEFT JOIN smartstore_mapping_by_sku AS smb
    ON smb.sku_id = sa.sku_id
),

option_features AS (
  SELECT
    sj.*,
    (
      sj.stage_option_raw_key LIKE '%핑골%'
      OR sj.stage_option_raw_key LIKE '%핑크골드%'
      OR sj.stage_option_raw_key LIKE '%로즈골드%'
      OR sj.stage_option_raw_key LIKE '%rose gold%'
      OR sj.stage_option_raw_key ~* '(^|[^[:alnum:]])RG([^[:alnum:]]|$)'
    ) AS stage_rose_gold_family,
    (
      sj.db_option_raw_key LIKE '%핑골%'
      OR sj.db_option_raw_key LIKE '%핑크골드%'
      OR sj.db_option_raw_key LIKE '%로즈골드%'
      OR sj.db_option_raw_key LIKE '%rose gold%'
      OR sj.db_option_raw_key ~* '(^|[^[:alnum:]])RG([^[:alnum:]]|$)'
    ) AS db_rose_gold_family,
    (
      sj.stage_option_raw_key LIKE '%옐로우골드%'
      OR sj.stage_option_raw_key LIKE '%골드%'
      OR sj.stage_option_raw_key LIKE '%yellow gold%'
      OR sj.stage_option_raw_key ~* '(^|[^[:alnum:]])YG([^[:alnum:]]|$)'
    ) AS stage_yellow_gold_family,
    (
      sj.db_option_raw_key LIKE '%옐로우골드%'
      OR sj.db_option_raw_key LIKE '%골드%'
      OR sj.db_option_raw_key LIKE '%yellow gold%'
      OR sj.db_option_raw_key ~* '(^|[^[:alnum:]])YG([^[:alnum:]]|$)'
    ) AS db_yellow_gold_family,
    (
      sj.stage_option_raw_key LIKE '%주문제작%'
      OR sj.db_option_raw_key LIKE '%주문제작%'
    ) AS order_made_text_absorbed,
    (
      sj.stage_option_raw_key LIKE '%원타입%'
      OR sj.stage_option_raw_key LIKE '%단일옵션%'
      OR sj.stage_option_raw_key LIKE '%one type%'
      OR sj.db_option_raw_key LIKE '%원타입%'
      OR sj.db_option_raw_key LIKE '%단일옵션%'
      OR sj.db_option_raw_key LIKE '%one type%'
    ) AS one_type_absorbed,
    (
      sj.stage_option_raw_key ~ '[0-9]+mm바'
      OR sj.db_option_raw_key ~ '[0-9]+mm바'
    ) AS mm_bar_absorbed,
    regexp_replace(
      regexp_replace(
        regexp_replace(
          regexp_replace(
            regexp_replace(
              regexp_replace(
                regexp_replace(
                  regexp_replace(
                    regexp_replace(
                      regexp_replace(
                        regexp_replace(sj.stage_option_raw_key, 'rose[[:space:]]*gold|핑크골드|로즈골드|핑골|(^|[^[:alnum:]])rg([^[:alnum:]]|$)', 'rosegold', 'gi'),
                        'yellow[[:space:]]*gold|옐로우골드|골드|(^|[^[:alnum:]])yg([^[:alnum:]]|$)', 'yellowgold', 'gi'),
                      '원타입|단일옵션|one[[:space:]]*type', 'onetype', 'gi'),
                    '([0-9]+)mm바', '\1mm', 'gi'),
                  '주문제작', '', 'gi'),
                '\\([^)]*\\)', '', 'g'),
              '\\[[^]]*\\]', '', 'g'),
            '[[:space:]]+', '', 'g'),
          '[^[:alnum:]가-힣]+', '', 'g'),
        '14k|써지컬|925실버|실버925', '', 'gi'),
      'rosegold', 'rosegold', 'g'
    ) AS normalized_stage_option_key,
    regexp_replace(
      regexp_replace(
        regexp_replace(
          regexp_replace(
            regexp_replace(
              regexp_replace(
                regexp_replace(
                  regexp_replace(
                    regexp_replace(
                      regexp_replace(
                        regexp_replace(sj.db_option_raw_key, 'rose[[:space:]]*gold|핑크골드|로즈골드|핑골|(^|[^[:alnum:]])rg([^[:alnum:]]|$)', 'rosegold', 'gi'),
                        'yellow[[:space:]]*gold|옐로우골드|골드|(^|[^[:alnum:]])yg([^[:alnum:]]|$)', 'yellowgold', 'gi'),
                      '원타입|단일옵션|one[[:space:]]*type', 'onetype', 'gi'),
                    '([0-9]+)mm바', '\1mm', 'gi'),
                  '주문제작', '', 'gi'),
                '\\([^)]*\\)', '', 'g'),
              '\\[[^]]*\\]', '', 'g'),
            '[[:space:]]+', '', 'g'),
          '[^[:alnum:]가-힣]+', '', 'g'),
        '14k|써지컬|925실버|실버925', '', 'gi'),
      'rosegold', 'rosegold', 'g'
    ) AS normalized_db_option_key
  FROM stage_joined AS sj
),

stage_product_no_by_selfpia AS (
  SELECT
    normalized_selfpia_sku_code,
    COUNT(DISTINCT smartstore_product_no_candidate) AS stage_product_no_count_per_selfpia
  FROM option_features
  WHERE NULLIF(btrim(COALESCE(normalized_selfpia_sku_code, '')), '') IS NOT NULL
    AND NULLIF(btrim(COALESCE(smartstore_product_no_candidate, '')), '') IS NOT NULL
  GROUP BY normalized_selfpia_sku_code
),

stage_selfpia_by_product_option AS (
  SELECT
    smartstore_product_no_candidate,
    normalized_stage_option_key,
    COUNT(DISTINCT normalized_selfpia_sku_code) AS stage_selfpia_count_per_product_option
  FROM option_features
  WHERE NULLIF(btrim(COALESCE(smartstore_product_no_candidate, '')), '') IS NOT NULL
    AND NULLIF(btrim(COALESCE(normalized_stage_option_key, '')), '') IS NOT NULL
    AND NULLIF(btrim(COALESCE(normalized_selfpia_sku_code, '')), '') IS NOT NULL
  GROUP BY
    smartstore_product_no_candidate,
    normalized_stage_option_key
),

diagnosis AS (
  SELECT
    ofe.*,
    COALESCE(pns.stage_product_no_count_per_selfpia, 0) AS stage_product_no_count_per_selfpia,
    COALESCE(spo.stage_selfpia_count_per_product_option, 0) AS stage_selfpia_count_per_product_option,
    (
      ofe.stage_product_name_key <> ''
      AND ofe.db_product_name_key <> ''
      AND ofe.stage_product_name_key = ofe.db_product_name_key
    ) AS product_name_support,
    (
      ofe.stage_product_name_key <> ''
      AND ofe.db_product_name_key <> ''
      AND ofe.stage_product_name_key <> ofe.db_product_name_key
    ) AS product_name_conflict,
    (
      NULLIF(btrim(COALESCE(ofe.normalized_stage_option_key, '')), '') IS NOT NULL
      AND ofe.normalized_stage_option_key = ofe.normalized_db_option_key
    ) AS normalized_option_match,
    (
      ofe.normalized_stage_option_key = ofe.normalized_db_option_key
      AND ofe.stage_option_raw_key <> ofe.db_option_raw_key
    ) AS normalization_absorbed,
    (
      COALESCE(ofe.parse_warning, '') <> ''
      OR lower(COALESCE(ofe.parse_status, '')) NOT IN ('', 'parsed', 'ok', 'clean')
    ) AS parser_warning,
    (
      COALESCE(ofe.parse_warning, '') ILIKE '%bracket%'
      OR COALESCE(ofe.parse_warning, '') LIKE '%대괄호%'
      OR (
        COALESCE(ofe.raw_option_text, '') LIKE '%[%'
        AND COALESCE(ofe.raw_option_text, '') NOT LIKE '%]%'
      )
    ) AS bracket_parse_error,
    (
      (
        COALESCE(ofe.raw_option_text, '') LIKE '%크리스탈AB%'
        OR COALESCE(ofe.normalized_option_text, '') LIKE '%크리스탈AB%'
        OR COALESCE(ofe.db_option_text, '') LIKE '%크리스탈AB%'
      )
      AND (
        COALESCE(ofe.raw_option_text, '') LIKE '%크리스탈%'
        OR COALESCE(ofe.normalized_option_text, '') LIKE '%크리스탈%'
        OR COALESCE(ofe.db_option_text, '') LIKE '%크리스탈%'
      )
    ) AS crystal_crystal_ab_blocked,
    (
      COALESCE(ofe.parse_warning, '') ILIKE '%ab%'
      OR COALESCE(ofe.raw_option_text, '') ~* '(^|[^[:alnum:]])AB([^[:alnum:]]|$)'
      OR COALESCE(ofe.normalized_option_text, '') ~* '(^|[^[:alnum:]])AB([^[:alnum:]]|$)'
      OR COALESCE(ofe.raw_option_text, '') ~* '[[:alnum:]]AB[[:alnum:]]'
    ) AS ab_token_warning,
    (
      (
        COALESCE(ofe.raw_option_text, '') LIKE '%화이트골드%'
        OR COALESCE(ofe.normalized_option_text, '') LIKE '%화이트골드%'
        OR COALESCE(ofe.db_option_text, '') LIKE '%화이트골드%'
      )
      AND (
        COALESCE(ofe.raw_option_text, '') LIKE '%실버%'
        OR COALESCE(ofe.normalized_option_text, '') LIKE '%실버%'
        OR COALESCE(ofe.db_option_text, '') LIKE '%실버%'
      )
    ) AS white_gold_silver_blocked,
    (
      COALESCE(ofe.raw_option_text, '') LIKE '%세트%'
      OR COALESCE(ofe.raw_option_text, '') LIKE '%한쌍%'
      OR COALESCE(ofe.raw_option_text, '') LIKE '%낱개%'
      OR COALESCE(ofe.raw_option_text, '') ~ '[0-9]+[[:space:]]*(개|pcs|ea|set)'
      OR COALESCE(ofe.normalized_option_text, '') LIKE '%세트%'
      OR COALESCE(ofe.normalized_option_text, '') LIKE '%한쌍%'
      OR COALESCE(ofe.normalized_option_text, '') LIKE '%낱개%'
    ) AS quantity_set_blocked,
    (
      COALESCE(ofe.parse_warning, '') ILIKE '%multiline%'
      OR COALESCE(ofe.parse_warning, '') LIKE '%줄 수%'
      OR COALESCE(ofe.parse_warning, '') ILIKE '%alignment%'
    ) AS multiline_alignment_blocked,
    (
      COALESCE(ofe.selfpia_sku_id_count, 0) > 1
      OR COALESCE(pns.stage_product_no_count_per_selfpia, 0) > 1
    ) AS duplicate_selfpia_sku_blocked,
    (
      COALESCE(spo.stage_selfpia_count_per_product_option, 0) > 1
    ) AS duplicate_product_option_blocked,
    (
      COALESCE(ofe.own_sku_id_count, 0) > 1
      OR (
        ofe.own_sku_joined_sku_id IS NOT NULL
        AND ofe.selfpia_joined_sku_id IS NOT NULL
        AND ofe.own_sku_joined_sku_id <> ofe.selfpia_joined_sku_id
      )
    ) AS own_sku_blocked,
    (
      (
        ofe.registered_smartstore_product_no IS NOT NULL
        AND ofe.smartstore_product_no_candidate IS NOT NULL
        AND ofe.registered_smartstore_product_no <> ofe.smartstore_product_no_candidate
      )
      OR (
        ofe.registered_smartstore_product_no_candidate IS NOT NULL
        AND ofe.smartstore_product_no_candidate IS NOT NULL
        AND ofe.registered_smartstore_product_no_candidate <> ofe.smartstore_product_no_candidate
      )
      OR (
        ofe.mapping_product_no IS NOT NULL
        AND ofe.smartstore_product_no_candidate IS NOT NULL
        AND ofe.mapping_product_no <> ofe.smartstore_product_no_candidate
      )
    ) AS smartstore_product_no_blocked
  FROM option_features AS ofe
  LEFT JOIN stage_product_no_by_selfpia AS pns
    ON pns.normalized_selfpia_sku_code = ofe.normalized_selfpia_sku_code
  LEFT JOIN stage_selfpia_by_product_option AS spo
    ON spo.smartstore_product_no_candidate = ofe.smartstore_product_no_candidate
   AND spo.normalized_stage_option_key = ofe.normalized_stage_option_key
),

classified AS (
  SELECT
    d.*,
    (
      NULLIF(btrim(COALESCE(d.normalized_selfpia_sku_code, '')), '') IS NOT NULL
      AND NULLIF(btrim(COALESCE(d.smartstore_product_no_candidate, '')), '') IS NOT NULL
      AND NULLIF(btrim(COALESCE(d.raw_option_text, d.normalized_option_text, '')), '') IS NOT NULL
      AND NOT d.duplicate_selfpia_sku_blocked
      AND NOT d.duplicate_product_option_blocked
    ) AS excel_parse_good_candidate,
    (
      d.crystal_crystal_ab_blocked
      OR d.ab_token_warning
      OR d.white_gold_silver_blocked
      OR d.quantity_set_blocked
      OR d.bracket_parse_error
      OR d.multiline_alignment_blocked
      OR d.duplicate_selfpia_sku_blocked
      OR d.duplicate_product_option_blocked
      OR d.own_sku_blocked
      OR d.smartstore_product_no_blocked
      OR d.product_name_conflict
    ) AS blocked_risk,
    CASE
      WHEN (
        d.crystal_crystal_ab_blocked
        OR d.ab_token_warning
        OR d.white_gold_silver_blocked
        OR d.quantity_set_blocked
        OR d.bracket_parse_error
        OR d.multiline_alignment_blocked
        OR d.duplicate_selfpia_sku_blocked
        OR d.duplicate_product_option_blocked
        OR d.own_sku_blocked
        OR d.smartstore_product_no_blocked
        OR d.product_name_conflict
      ) THEN 'blocked_risk'
      WHEN d.parser_warning THEN 'parse_warning'
      WHEN d.selfpia_joined_sku_id IS NOT NULL
       AND NULLIF(btrim(COALESCE(d.smartstore_product_no_candidate, '')), '') IS NOT NULL
       AND NULLIF(btrim(COALESCE(d.raw_option_text, d.normalized_option_text, '')), '') IS NOT NULL
       AND d.normalized_option_match
       AND COALESCE(d.selfpia_sku_id_count, 0) = 1
       AND COALESCE(d.own_sku_id_count, 0) <= 1
       AND COALESCE(d.stage_product_no_count_per_selfpia, 0) = 1
       AND COALESCE(d.stage_selfpia_count_per_product_option, 0) = 1 THEN 'auto_match_high_confidence'
      WHEN d.selfpia_joined_sku_id IS NOT NULL
       AND NULLIF(btrim(COALESCE(d.smartstore_product_no_candidate, '')), '') IS NOT NULL
       AND NULLIF(btrim(COALESCE(d.raw_option_text, d.normalized_option_text, '')), '') IS NOT NULL
       AND (
         d.normalized_option_match
         OR d.normalization_absorbed
         OR d.stage_rose_gold_family
         OR d.stage_yellow_gold_family
         OR d.order_made_text_absorbed
         OR d.one_type_absorbed
         OR d.mm_bar_absorbed
       ) THEN 'auto_match_medium_confidence'
      WHEN (
        NULLIF(btrim(COALESCE(d.normalized_selfpia_sku_code, '')), '') IS NOT NULL
        AND NULLIF(btrim(COALESCE(d.smartstore_product_no_candidate, '')), '') IS NOT NULL
        AND NULLIF(btrim(COALESCE(d.raw_option_text, d.normalized_option_text, '')), '') IS NOT NULL
      ) THEN 'excel_parse_good_candidate'
      ELSE 'manual_review_required'
    END AS confidence_tier,
    false::boolean AS export_allowed_safe,
    'pending'::text AS reviewer_decision_safe
  FROM diagnosis AS d
)

SELECT
  'summary'::text AS section,
  COUNT(*) AS total_stage_rows,
  COUNT(*) FILTER (
    WHERE excel_parse_good_candidate
  ) AS excel_parse_good_candidate_count,
  COUNT(*) FILTER (
    WHERE confidence_tier = 'auto_match_high_confidence'
  ) AS auto_match_high_confidence_count,
  COUNT(*) FILTER (
    WHERE confidence_tier = 'auto_match_medium_confidence'
  ) AS auto_match_medium_confidence_count,
  COUNT(*) FILTER (
    WHERE confidence_tier = 'manual_review_required'
  ) AS manual_review_required_count,
  COUNT(*) FILTER (
    WHERE confidence_tier = 'blocked_risk'
  ) AS blocked_risk_count,
  COUNT(*) FILTER (
    WHERE confidence_tier = 'parse_warning'
  ) AS parse_warning_count,
  COUNT(*) FILTER (
    WHERE selfpia_joined_sku_id IS NOT NULL
  ) AS selfpia_sku_joined_count,
  COUNT(*) FILTER (
    WHERE own_sku_joined_sku_id IS NOT NULL
  ) AS own_sku_joined_count,
  COUNT(*) FILTER (
    WHERE NULLIF(btrim(COALESCE(smartstore_product_no_candidate, '')), '') IS NOT NULL
  ) AS smartstore_product_no_candidate_count,
  COUNT(*) FILTER (
    WHERE normalized_option_match
  ) AS normalized_option_match_count,
  COUNT(*) FILTER (
    WHERE normalization_absorbed
  ) AS normalization_absorbed_count,
  COUNT(*) FILTER (
    WHERE stage_rose_gold_family OR db_rose_gold_family
  ) AS rose_gold_family_count,
  COUNT(*) FILTER (
    WHERE stage_yellow_gold_family OR db_yellow_gold_family
  ) AS yellow_gold_family_count,
  COUNT(*) FILTER (
    WHERE order_made_text_absorbed
  ) AS order_made_text_absorbed_count,
  COUNT(*) FILTER (
    WHERE one_type_absorbed
  ) AS one_type_absorbed_count,
  COUNT(*) FILTER (
    WHERE mm_bar_absorbed
  ) AS mm_bar_absorbed_count,
  COUNT(*) FILTER (
    WHERE crystal_crystal_ab_blocked
  ) AS crystal_crystal_ab_blocked_count,
  COUNT(*) FILTER (
    WHERE ab_token_warning
  ) AS ab_token_warning_count,
  COUNT(*) FILTER (
    WHERE white_gold_silver_blocked
  ) AS white_gold_silver_blocked_count,
  COUNT(*) FILTER (
    WHERE quantity_set_blocked
  ) AS quantity_set_blocked_count,
  COUNT(*) FILTER (
    WHERE duplicate_selfpia_sku_blocked
  ) AS duplicate_selfpia_sku_blocked_count,
  COUNT(*) FILTER (
    WHERE duplicate_product_option_blocked
  ) AS duplicate_product_option_blocked_count,
  bool_and(export_allowed_safe = false) AS export_allowed_is_always_false,
  bool_and(reviewer_decision_safe = 'pending') AS reviewer_decision_is_always_pending
FROM classified;
