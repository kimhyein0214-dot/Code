/*
  MakeShop unique evidence AB-excluded dryrun.

  Purpose:
  - Rebuild the 255 clean planned subset from the unique-evidence dryrun.
  - Conservatively exclude 14 broad AB keyword rows.
  - Validate the remaining 241 rows as the final planned subset.
  - Do not apply confirmed aliases.

  Safety:
  - SELECT-only.
  - Read-only summary/sample output.
  - No apply SQL.
  - BEGIN READ ONLY + ROLLBACK dryrun.
  - No file output.
  - No import/export.
  - No stage relation.
  - export_allowed remains false.
  - reviewer_decision remains pending.
*/

BEGIN READ ONLY;

SELECT
  'guard'::text AS section,
  current_database() AS current_database,
  current_user AS current_user,
  current_setting('transaction_read_only') AS transaction_read_only,
  CASE
    WHEN current_database() = 'product_ops_test'
      THEN 'PASS: local product_ops_test database'
    ELSE 'STOP: not product_ops_test'
  END AS database_guard,
  'This dryrun must end with ROLLBACK and leave no DB changes.'::text AS note;

WITH possible_makeshop_columns AS (
  SELECT
    c.table_schema,
    c.table_name,
    c.column_name,
    c.data_type,
    c.ordinal_position
  FROM information_schema.columns AS c
  WHERE c.table_schema = 'product_code'
    AND (
      lower(c.table_name) ~ '(makeshop|shop|mall|goods)'
      OR lower(c.column_name) ~ '(makeshop|shop|mall|product_no|productno|goods|goodsno|option_no|optionno|option|code|sku|own|selfpia)'
    )
)
SELECT
  'catalog_candidate_column'::text AS section,
  table_schema,
  table_name,
  column_name,
  data_type,
  NULL::bigint AS row_count,
  NULL::bigint AS non_null_count,
  NULL::bigint AS distinct_count,
  'Possible MakeShop/code evidence column from information_schema.'::text AS note
FROM possible_makeshop_columns
ORDER BY table_schema, table_name, ordinal_position;

WITH source_stats AS (
  SELECT
    'product_code.code_alias'::text AS source_relation,
    'code_system like makeshop/shop/mall'::text AS source_column,
    COUNT(*) FILTER (
      WHERE lower(code_system) LIKE '%makeshop%'
         OR lower(code_system) LIKE '%shop%'
         OR lower(code_system) LIKE '%mall%'
    ) AS row_count,
    COUNT(code_value) FILTER (
      WHERE (lower(code_system) LIKE '%makeshop%'
          OR lower(code_system) LIKE '%shop%'
          OR lower(code_system) LIKE '%mall%')
        AND NULLIF(btrim(COALESCE(code_value, '')), '') IS NOT NULL
    ) AS non_null_count,
    COUNT(DISTINCT code_value) FILTER (
      WHERE (lower(code_system) LIKE '%makeshop%'
          OR lower(code_system) LIKE '%shop%'
          OR lower(code_system) LIKE '%mall%')
        AND NULLIF(btrim(COALESCE(code_value, '')), '') IS NOT NULL
    ) AS distinct_count,
    'Alias-level MakeShop code evidence. In current local DB this is expected to be empty.'::text AS note
  FROM product_code.code_alias

  UNION ALL

  SELECT
    'product_code.sku_channel_mapping',
    'channel_code=makeshop rows',
    COUNT(*) FILTER (WHERE lower(channel_code) = 'makeshop'),
    COUNT(*) FILTER (WHERE lower(channel_code) = 'makeshop'),
    COUNT(DISTINCT sku_id) FILTER (WHERE lower(channel_code) = 'makeshop'),
    'Existing MakeShop channel mapping rows by sku_id.'
  FROM product_code.sku_channel_mapping

  UNION ALL

  SELECT
    'product_code.sku_channel_mapping',
    'seller_product_code',
    COUNT(*) FILTER (WHERE lower(channel_code) = 'makeshop'),
    COUNT(seller_product_code) FILTER (
      WHERE lower(channel_code) = 'makeshop'
        AND NULLIF(btrim(COALESCE(seller_product_code, '')), '') IS NOT NULL
    ),
    COUNT(DISTINCT seller_product_code) FILTER (
      WHERE lower(channel_code) = 'makeshop'
        AND NULLIF(btrim(COALESCE(seller_product_code, '')), '') IS NOT NULL
    ),
    'Potential MakeShop product-level code from existing channel mapping.'
  FROM product_code.sku_channel_mapping

  UNION ALL

  SELECT
    'product_code.sku_channel_mapping',
    'channel_sku_code',
    COUNT(*) FILTER (WHERE lower(channel_code) = 'makeshop'),
    COUNT(channel_sku_code) FILTER (
      WHERE lower(channel_code) = 'makeshop'
        AND NULLIF(btrim(COALESCE(channel_sku_code, '')), '') IS NOT NULL
    ),
    COUNT(DISTINCT channel_sku_code) FILTER (
      WHERE lower(channel_code) = 'makeshop'
        AND NULLIF(btrim(COALESCE(channel_sku_code, '')), '') IS NOT NULL
    ),
    'Potential MakeShop option/SKU-level code from existing channel mapping.'
  FROM product_code.sku_channel_mapping

  UNION ALL

  SELECT
    'product_code.sku_channel_mapping',
    'own_sku_code',
    COUNT(*) FILTER (WHERE lower(channel_code) = 'makeshop'),
    COUNT(own_sku_code) FILTER (
      WHERE lower(channel_code) = 'makeshop'
        AND NULLIF(btrim(COALESCE(own_sku_code, '')), '') IS NOT NULL
    ),
    COUNT(DISTINCT own_sku_code) FILTER (
      WHERE lower(channel_code) = 'makeshop'
        AND NULLIF(btrim(COALESCE(own_sku_code, '')), '') IS NOT NULL
    ),
    'Own SKU evidence inside existing MakeShop channel mapping.'
  FROM product_code.sku_channel_mapping
)
SELECT
  'source_column_stats'::text AS section,
  source_relation AS table_schema,
  source_column AS table_name,
  NULL::text AS column_name,
  NULL::text AS data_type,
  row_count,
  non_null_count,
  distinct_count,
  note
FROM source_stats
ORDER BY source_relation, source_column;

WITH canonical_sku AS (
  SELECT
    v.sku_id,
    v.product_id,
    v.selfpia_sku_code,
    v.selfpia_product_code,
    v.product_name,
    v.option_value
  FROM product_code.v_sku_canonical AS v
),

sku_universe AS (
  SELECT
    'makeshop'::text AS channel,
    cs.sku_id,
    cs.product_id,
    cs.selfpia_sku_code,
    cs.selfpia_product_code,
    cs.product_name,
    cs.option_value,
    false::boolean AS export_allowed,
    'pending'::text AS reviewer_decision
  FROM canonical_sku AS cs
),

makeshop_alias AS (
  SELECT
    ca.target_id AS sku_id,
    COUNT(*) AS alias_rows,
    COUNT(*) FILTER (
      WHERE ca.code_system IN ('makeshop_product_code', 'makeshop_option_code')
    ) AS confirmed_alias_rows,
    COUNT(*) FILTER (
      WHERE ca.code_system IN ('makeshop_product_code_candidate', 'makeshop_option_code_candidate')
    ) AS candidate_alias_rows,
    COUNT(DISTINCT ca.code_value) FILTER (
      WHERE ca.code_system IN ('makeshop_product_code', 'makeshop_product_code_candidate')
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS product_code_distinct_count,
    COUNT(DISTINCT ca.code_value) FILTER (
      WHERE ca.code_system IN ('makeshop_option_code', 'makeshop_option_code_candidate')
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS option_code_distinct_count,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system IN ('makeshop_product_code', 'makeshop_product_code_candidate')
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS product_code_any,
    MIN(ca.code_value) FILTER (
      WHERE ca.code_system IN ('makeshop_option_code', 'makeshop_option_code_candidate')
        AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
    ) AS option_code_any
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system LIKE 'makeshop%'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.target_id
),

makeshop_mapping AS (
  SELECT
    scm.sku_id,
    COUNT(*) AS mapping_rows,
    COUNT(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS mapping_identity_rows,
    COUNT(DISTINCT scm.seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
    ) AS mapping_product_code_distinct_count,
    COUNT(DISTINCT scm.channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS mapping_option_code_distinct_count,
    COUNT(DISTINCT scm.own_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.own_sku_code, '')), '') IS NOT NULL
    ) AS mapping_own_sku_distinct_count,
    MIN(scm.seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
    ) AS mapping_product_code_any,
    MIN(scm.channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS mapping_option_code_any
  FROM product_code.sku_channel_mapping AS scm
  WHERE lower(scm.channel_code) = 'makeshop'
  GROUP BY scm.sku_id
),

own_sku_value_by_sku AS (
  SELECT DISTINCT
    ca.target_id AS sku_id,
    ca.code_value AS own_sku_code
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL

  UNION

  SELECT DISTINCT
    scm.sku_id,
    scm.own_sku_code
  FROM product_code.sku_channel_mapping AS scm
  WHERE lower(scm.channel_code) = 'makeshop'
    AND NULLIF(btrim(COALESCE(scm.own_sku_code, '')), '') IS NOT NULL
),

own_sku_scope AS (
  SELECT
    osv.own_sku_code,
    su.sku_id,
    su.product_id,
    su.selfpia_product_code,
    COALESCE(ma.product_code_any, mm.mapping_product_code_any) AS makeshop_code_key,
    COALESCE(ma.option_code_any, mm.mapping_option_code_any) AS makeshop_option_key
  FROM own_sku_value_by_sku AS osv
  JOIN sku_universe AS su
    ON su.sku_id = osv.sku_id
  LEFT JOIN makeshop_alias AS ma
    ON ma.sku_id = osv.sku_id
  LEFT JOIN makeshop_mapping AS mm
    ON mm.sku_id = osv.sku_id
),

own_sku_scope_stats AS (
  SELECT
    own_sku_code,
    COUNT(DISTINCT sku_id) AS own_sku_sku_count,
    COUNT(DISTINCT product_id) FILTER (
      WHERE product_id IS NOT NULL
    ) AS own_sku_product_id_count,
    COUNT(DISTINCT selfpia_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(selfpia_product_code, '')), '') IS NOT NULL
    ) AS own_sku_selfpia_product_count,
    COUNT(DISTINCT makeshop_code_key) FILTER (
      WHERE NULLIF(btrim(COALESCE(makeshop_code_key, '')), '') IS NOT NULL
    ) AS own_sku_makeshop_code_count
  FROM own_sku_scope
  GROUP BY own_sku_code
),

own_sku_scope_by_sku AS (
  SELECT
    osv.sku_id,
    COUNT(DISTINCT osv.own_sku_code) AS own_sku_code_count,
    MAX(oss.own_sku_sku_count) AS max_own_sku_sku_count,
    MAX(oss.own_sku_product_id_count) AS max_own_sku_product_id_count,
    MAX(oss.own_sku_selfpia_product_count) AS max_own_sku_selfpia_product_count,
    MAX(oss.own_sku_makeshop_code_count) AS max_own_sku_makeshop_code_count
  FROM own_sku_value_by_sku AS osv
  JOIN own_sku_scope_stats AS oss
    ON oss.own_sku_code = osv.own_sku_code
  GROUP BY osv.sku_id
),

image_by_sku AS (
  SELECT
    pi.sku_id,
    COUNT(*) FILTER (
      WHERE NULLIF(btrim(COALESCE(pi.image_url, '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(pi.thumbnail_url, '')), '') IS NOT NULL
    ) AS image_rows
  FROM product_code.product_image AS pi
  WHERE pi.sku_id IS NOT NULL
  GROUP BY pi.sku_id
),

joined AS (
  SELECT
    su.channel,
    su.sku_id,
    su.product_id,
    su.selfpia_sku_code,
    su.selfpia_product_code,
    su.product_name,
    su.option_value,
    COALESCE(ma.alias_rows, 0) AS alias_rows,
    COALESCE(ma.confirmed_alias_rows, 0) AS confirmed_alias_rows,
    COALESCE(ma.candidate_alias_rows, 0) AS candidate_alias_rows,
    COALESCE(ma.product_code_distinct_count, 0) AS product_code_distinct_count,
    COALESCE(ma.option_code_distinct_count, 0) AS option_code_distinct_count,
    ma.product_code_any,
    ma.option_code_any,
    COALESCE(mm.mapping_rows, 0) AS mapping_rows,
    COALESCE(mm.mapping_identity_rows, 0) AS mapping_identity_rows,
    COALESCE(mm.mapping_product_code_distinct_count, 0) AS mapping_product_code_distinct_count,
    COALESCE(mm.mapping_option_code_distinct_count, 0) AS mapping_option_code_distinct_count,
    COALESCE(mm.mapping_own_sku_distinct_count, 0) AS mapping_own_sku_distinct_count,
    mm.mapping_product_code_any,
    mm.mapping_option_code_any,
    COALESCE(oss.own_sku_code_count, 0) AS own_sku_code_count,
    COALESCE(oss.max_own_sku_sku_count, 0) AS max_own_sku_sku_count,
    COALESCE(oss.max_own_sku_product_id_count, 0) AS max_own_sku_product_id_count,
    COALESCE(oss.max_own_sku_selfpia_product_count, 0) AS max_own_sku_selfpia_product_count,
    COALESCE(oss.max_own_sku_makeshop_code_count, 0) AS max_own_sku_makeshop_code_count,
    COALESCE(img.image_rows, 0) AS image_rows,
    su.export_allowed,
    su.reviewer_decision
  FROM sku_universe AS su
  LEFT JOIN makeshop_alias AS ma
    ON ma.sku_id = su.sku_id
  LEFT JOIN makeshop_mapping AS mm
    ON mm.sku_id = su.sku_id
  LEFT JOIN own_sku_scope_by_sku AS oss
    ON oss.sku_id = su.sku_id
  LEFT JOIN image_by_sku AS img
    ON img.sku_id = su.sku_id
),

pair_key AS (
  SELECT
    j.*,
    COALESCE(j.product_code_any, j.mapping_product_code_any) AS makeshop_code_key,
    COALESCE(j.option_code_any, j.mapping_option_code_any) AS makeshop_option_key,
    lower(COALESCE(j.option_value, '')) AS option_text_lower
  FROM joined AS j
),

makeshop_code_counts AS (
  SELECT
    makeshop_code_key,
    makeshop_option_key,
    COUNT(DISTINCT sku_id) AS sku_count_for_makeshop_code
  FROM pair_key
  WHERE NULLIF(btrim(COALESCE(makeshop_code_key, '')), '') IS NOT NULL
    AND NULLIF(btrim(COALESCE(makeshop_option_key, '')), '') IS NOT NULL
  GROUP BY
    makeshop_code_key,
    makeshop_option_key
),

selfpia_sku_counts AS (
  SELECT
    selfpia_sku_code,
    COUNT(DISTINCT sku_id) AS selfpia_sku_target_count
  FROM canonical_sku
  WHERE NULLIF(btrim(COALESCE(selfpia_sku_code, '')), '') IS NOT NULL
  GROUP BY selfpia_sku_code
),

diagnosis AS (
  SELECT
    pk.*,
    COALESCE(mcc.sku_count_for_makeshop_code, 0) AS sku_count_for_makeshop_code,
    COALESCE(ssc.selfpia_sku_target_count, 0) AS selfpia_sku_target_count,
    (
      pk.confirmed_alias_rows > 0
      OR pk.mapping_identity_rows > 0
    ) AS matched_confirmed,
    (
      pk.candidate_alias_rows > 0
      AND pk.product_code_distinct_count <= 1
      AND pk.option_code_distinct_count <= 1
      AND pk.max_own_sku_sku_count <= 1
    ) AS current_auto_match_high_confidence,
    (
      (
        pk.candidate_alias_rows > 0
        OR pk.alias_rows > 0
        OR pk.mapping_rows > 0
      )
      AND NOT (
        pk.confirmed_alias_rows > 0
        OR pk.mapping_identity_rows > 0
      )
      AND (
        pk.product_code_distinct_count > 0
        OR pk.mapping_product_code_distinct_count > 0
      )
      AND pk.max_own_sku_sku_count <= 1
    ) AS current_auto_match_medium_confidence,
    (
      pk.product_code_distinct_count > 1
      OR pk.option_code_distinct_count > 1
      OR pk.mapping_product_code_distinct_count > 1
      OR pk.mapping_option_code_distinct_count > 1
      OR pk.mapping_own_sku_distinct_count > 1
      OR pk.max_own_sku_sku_count > 1
    ) AS current_blocked_risk,
    (
      pk.alias_rows = 0
      AND pk.mapping_rows = 0
      AND pk.image_rows = 0
    ) AS channel_absent_or_inactive,
    (
      pk.alias_rows = 0
      AND pk.mapping_rows = 0
      AND pk.image_rows > 0
    ) AS unknown_need_check,
    (
      pk.product_code_distinct_count > 1
      OR pk.mapping_product_code_distinct_count > 1
    ) AS duplicate_selfpia_sku_to_makeshop_code,
    (
      pk.mapping_own_sku_distinct_count > 1
      OR pk.max_own_sku_sku_count > 1
    ) AS duplicate_own_sku_blocked,
    (
      NULLIF(btrim(COALESCE(pk.makeshop_code_key, '')), '') IS NOT NULL
    ) AS makeshop_code_candidate_exists,
    (
      NULLIF(btrim(COALESCE(pk.makeshop_code_key, '')), '') IS NOT NULL
      AND (
        NULLIF(btrim(COALESCE(pk.makeshop_option_key, '')), '') IS NOT NULL
        OR NULLIF(btrim(COALESCE(pk.option_value, '')), '') IS NOT NULL
      )
    ) AS makeshop_code_and_option_evidence_exists,
    (
      pk.option_text_lower LIKE '%핑골%'
      OR pk.option_text_lower LIKE '%핑크골드%'
      OR pk.option_text_lower LIKE '%로즈골드%'
      OR pk.option_text_lower LIKE '%rose gold%'
      OR pk.option_text_lower LIKE '%rg%'
    ) AS rose_gold_family_absorbable,
    (
      pk.option_text_lower LIKE '%옐로우골드%'
      OR pk.option_text_lower LIKE '%yellow gold%'
      OR pk.option_text_lower LIKE '%yg%'
      OR (
        pk.option_text_lower LIKE '%골드%'
        AND pk.option_text_lower NOT LIKE '%핑골%'
        AND pk.option_text_lower NOT LIKE '%핑크골드%'
        AND pk.option_text_lower NOT LIKE '%로즈골드%'
        AND pk.option_text_lower NOT LIKE '%rose gold%'
        AND pk.option_text_lower NOT LIKE '%화이트골드%'
      )
    ) AS yellow_gold_family_absorbable,
    (
      pk.option_text_lower LIKE '%mm바%'
      OR pk.option_text_lower LIKE '%6mm%'
      OR pk.option_text_lower LIKE '%8mm%'
    ) AS mm_bar_absorbable,
    (
      pk.option_text_lower LIKE '%원타입%'
      OR pk.option_text_lower LIKE '%단일옵션%'
      OR pk.option_text_lower LIKE '%one type%'
    ) AS one_type_absorbable,
    (
      pk.option_text_lower LIKE '%크리스탈ab%'
    ) AS crystal_crystal_ab_true_risk,
    (
      pk.option_text_lower LIKE '% ab %'
      OR pk.option_text_lower LIKE 'ab %'
      OR pk.option_text_lower LIKE '% ab'
      OR pk.option_text_lower LIKE '%/ab%'
      OR pk.option_text_lower LIKE '%-ab%'
      OR pk.option_text_lower LIKE '%(ab%'
      OR pk.option_text_lower LIKE '%ab)%'
    ) AS ab_token_true_risk,
    (
      pk.option_text_lower LIKE '%화이트골드%'
      AND pk.option_text_lower LIKE '%실버%'
    ) AS white_gold_silver_true_risk,
    (
      pk.option_text_lower LIKE '%세트%'
      OR pk.option_text_lower LIKE '%5개%'
      OR pk.option_text_lower LIKE '%10개%'
      OR pk.option_text_lower LIKE '%pcs%'
      OR pk.option_text_lower LIKE '% ea%'
    ) AS quantity_set_true_risk,
    (
      pk.option_text_lower LIKE '%한쌍%'
      OR pk.option_text_lower LIKE '%낱개%'
      OR pk.option_text_lower LIKE '%pair%'
      OR pk.option_text_lower LIKE '%single%'
    ) AS pair_single_set_risk
  FROM pair_key AS pk
  LEFT JOIN makeshop_code_counts AS mcc
    ON mcc.makeshop_code_key = pk.makeshop_code_key
   AND mcc.makeshop_option_key = pk.makeshop_option_key
  LEFT JOIN selfpia_sku_counts AS ssc
    ON ssc.selfpia_sku_code = pk.selfpia_sku_code
),

classified AS (
  SELECT
    d.*,
    CASE
      WHEN d.matched_confirmed THEN 'matched_confirmed'
      WHEN d.current_blocked_risk THEN 'blocked_risk'
      WHEN d.current_auto_match_high_confidence THEN 'auto_match_high_confidence'
      WHEN d.current_auto_match_medium_confidence THEN 'auto_match_medium_confidence'
      WHEN d.channel_absent_or_inactive THEN 'channel_absent_or_inactive'
      WHEN d.unknown_need_check THEN 'unknown_need_check'
      ELSE 'manual_review_required'
    END AS matching_presence_status,
    (
      d.rose_gold_family_absorbable
      OR d.yellow_gold_family_absorbable
      OR d.mm_bar_absorbable
      OR d.one_type_absorbable
    ) AS option_normalization_absorbable,
    (
      d.crystal_crystal_ab_true_risk
      OR d.ab_token_true_risk
      OR d.white_gold_silver_true_risk
    ) AS semantic_true_risk,
    (
      d.duplicate_own_sku_blocked
      AND (
        d.max_own_sku_product_id_count <= 1
        OR d.max_own_sku_selfpia_product_count <= 1
      )
    ) AS duplicate_own_sku_same_product_family,
    (
      d.duplicate_own_sku_blocked
      AND d.max_own_sku_product_id_count > 1
      AND d.max_own_sku_selfpia_product_count > 1
    ) AS duplicate_own_sku_cross_product,
    (
      d.duplicate_own_sku_blocked
      AND d.max_own_sku_selfpia_product_count <= 1
    ) AS duplicate_own_sku_same_selfpia_product,
    (
      d.duplicate_own_sku_blocked
      AND d.makeshop_code_and_option_evidence_exists
      AND d.sku_count_for_makeshop_code = 1
    ) AS duplicate_own_sku_with_unique_makeshop_code,
    (
      d.duplicate_own_sku_blocked
      AND NOT d.makeshop_code_candidate_exists
    ) AS duplicate_own_sku_without_makeshop_evidence,
    (
      d.duplicate_own_sku_blocked
      AND d.quantity_set_true_risk
    ) AS duplicate_own_sku_due_quantity_set,
    (
      d.duplicate_own_sku_blocked
      AND d.pair_single_set_risk
    ) AS duplicate_own_sku_due_pair_single_set,
    (
      d.duplicate_own_sku_blocked
      AND d.channel_absent_or_inactive
    ) AS duplicate_own_sku_due_channel_absent_or_inactive,
    false::boolean AS export_allowed_safe,
    'pending'::text AS reviewer_decision_safe
  FROM diagnosis AS d
),

promotion AS (
  SELECT
    c.*,
    (
      c.matching_presence_status = 'blocked_risk'
      AND c.duplicate_own_sku_blocked
      AND c.selfpia_sku_target_count = 1
      AND c.makeshop_code_and_option_evidence_exists
      AND c.sku_count_for_makeshop_code = 1
      AND NOT c.duplicate_selfpia_sku_to_makeshop_code
      AND NOT c.semantic_true_risk
      AND NOT c.quantity_set_true_risk
      AND (
        c.duplicate_own_sku_same_product_family
        OR c.duplicate_own_sku_same_selfpia_product
      )
    ) AS promotable_to_high_confidence,
    (
      c.matching_presence_status = 'blocked_risk'
      AND c.duplicate_own_sku_blocked
      AND NOT (
        c.selfpia_sku_target_count = 1
        AND c.makeshop_code_and_option_evidence_exists
        AND c.sku_count_for_makeshop_code = 1
        AND NOT c.duplicate_selfpia_sku_to_makeshop_code
        AND NOT c.semantic_true_risk
        AND NOT c.quantity_set_true_risk
        AND (
          c.duplicate_own_sku_same_product_family
          OR c.duplicate_own_sku_same_selfpia_product
        )
      )
      AND NOT c.duplicate_selfpia_sku_to_makeshop_code
      AND NOT c.semantic_true_risk
      AND NOT c.channel_absent_or_inactive
      AND (
        c.duplicate_own_sku_with_unique_makeshop_code
        OR c.option_normalization_absorbable
        OR c.quantity_set_true_risk
        OR c.pair_single_set_risk
        OR (
          c.makeshop_code_candidate_exists
          AND c.duplicate_own_sku_same_product_family
        )
      )
    ) AS promotable_to_medium_confidence,
    (
      c.matching_presence_status = 'blocked_risk'
      AND c.duplicate_own_sku_blocked
      AND (
        c.duplicate_selfpia_sku_to_makeshop_code
        OR (
          c.makeshop_code_and_option_evidence_exists
          AND c.sku_count_for_makeshop_code > 1
        )
        OR c.semantic_true_risk
        OR (
          c.duplicate_own_sku_cross_product
          AND NOT c.duplicate_own_sku_with_unique_makeshop_code
        )
        OR (
          NOT c.makeshop_code_candidate_exists
          AND NOT c.channel_absent_or_inactive
        )
      )
    ) AS true_conflict_or_residual
  FROM classified AS c
),

candidate_rows AS (
  SELECT
    CASE
      WHEN p.promotable_to_high_confidence THEN 'auto_match_high_confidence'
      WHEN p.promotable_to_medium_confidence THEN 'auto_match_medium_confidence'
      ELSE 'not_candidate'
    END AS confidence_tier,
    p.sku_id,
    p.sku_id::text AS sku_id_text,
    p.selfpia_sku_code AS selfpia_sku,
    (
      SELECT string_agg(DISTINCT osv.own_sku_code, ', ' ORDER BY osv.own_sku_code)
      FROM own_sku_value_by_sku AS osv
      WHERE osv.sku_id = p.sku_id
    ) AS own_sku,
    p.product_name,
    p.option_value AS option_name,
    p.makeshop_code_key AS makeshop_code_candidate,
    p.makeshop_code_key AS makeshop_product_candidate,
    p.makeshop_option_key AS makeshop_option_candidate,
    p.makeshop_code_candidate_exists,
    p.makeshop_code_and_option_evidence_exists,
    p.sku_count_for_makeshop_code,
    p.duplicate_own_sku_same_product_family,
    p.duplicate_own_sku_cross_product,
    p.duplicate_own_sku_blocked,
    p.duplicate_selfpia_sku_to_makeshop_code,
    p.semantic_true_risk,
    p.channel_absent_or_inactive,
    p.true_conflict_or_residual,
    CASE
      WHEN p.promotable_to_high_confidence THEN 'unique MakeShop code + same product family evidence'
      WHEN p.promotable_to_medium_confidence THEN 'own_sku repeat reclassified with MakeShop or normalization evidence'
      ELSE 'excluded'
    END AS match_reason,
    CASE
      WHEN p.duplicate_own_sku_with_unique_makeshop_code THEN 'makeshop_code_and_option_1to1'
      WHEN p.makeshop_code_candidate_exists THEN 'makeshop_code_candidate'
      WHEN p.option_normalization_absorbable THEN 'option_normalization'
      WHEN p.duplicate_own_sku_same_product_family THEN 'same_product_family_own_sku_repeat'
      WHEN p.quantity_set_true_risk OR p.pair_single_set_risk THEN 'quantity_or_set_wording'
      ELSE 'own_sku_repeat_only'
    END AS evidence_source,
    CASE
      WHEN NOT p.makeshop_code_candidate_exists THEN 'MakeShop code missing; do not apply without extra code evidence'
      WHEN p.semantic_true_risk THEN 'semantic risk remains'
      WHEN p.duplicate_selfpia_sku_to_makeshop_code THEN 'selfpia SKU splits to multiple MakeShop codes'
      WHEN p.channel_absent_or_inactive THEN 'channel absent or inactive'
      WHEN p.true_conflict_or_residual THEN 'remain blocked risk'
      ELSE 'dryrun candidate; sample before apply design'
    END AS risk_note,
    false::boolean AS export_allowed,
    'pending'::text AS reviewer_decision
  FROM promotion AS p
  WHERE p.promotable_to_high_confidence
     OR p.promotable_to_medium_confidence
),
candidate_own_sku_values AS (
  SELECT DISTINCT
    cr.sku_id,
    osv.own_sku_code
  FROM candidate_rows AS cr
  JOIN own_sku_value_by_sku AS osv
    ON osv.sku_id = cr.sku_id
  WHERE NULLIF(btrim(COALESCE(osv.own_sku_code, '')), '') IS NOT NULL
),
candidate_own_sku_makeshop_mapping AS (
  SELECT
    cov.sku_id,
    COUNT(*) AS mapping_rows_by_own_sku,
    COUNT(DISTINCT scm.sku_id) AS mapped_sku_count_by_own_sku,
    COUNT(DISTINCT scm.seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
    ) AS seller_product_code_distinct_by_own_sku,
    COUNT(DISTINCT scm.channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS channel_sku_code_distinct_by_own_sku,
    COUNT(DISTINCT concat_ws('|', scm.seller_product_code, scm.channel_sku_code)) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS code_pair_distinct_by_own_sku,
    MIN(scm.seller_product_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.seller_product_code, '')), '') IS NOT NULL
    ) AS sample_seller_product_code_by_own_sku,
    MIN(scm.channel_sku_code) FILTER (
      WHERE NULLIF(btrim(COALESCE(scm.channel_sku_code, '')), '') IS NOT NULL
    ) AS sample_channel_sku_code_by_own_sku
  FROM candidate_own_sku_values AS cov
  JOIN product_code.sku_channel_mapping AS scm
    ON lower(scm.channel_code) = 'makeshop'
   AND scm.own_sku_code = cov.own_sku_code
  GROUP BY cov.sku_id
),
candidate_source_join_stats AS (
  SELECT
    cr.*,
    COALESCE(cmm.mapping_rows_by_own_sku, 0) AS mapping_rows_by_own_sku,
    COALESCE(cmm.mapped_sku_count_by_own_sku, 0) AS mapped_sku_count_by_own_sku,
    COALESCE(cmm.seller_product_code_distinct_by_own_sku, 0) AS seller_product_code_distinct_by_own_sku,
    COALESCE(cmm.channel_sku_code_distinct_by_own_sku, 0) AS channel_sku_code_distinct_by_own_sku,
    COALESCE(cmm.code_pair_distinct_by_own_sku, 0) AS code_pair_distinct_by_own_sku,
    cmm.sample_seller_product_code_by_own_sku,
    cmm.sample_channel_sku_code_by_own_sku
  FROM candidate_rows AS cr
  LEFT JOIN candidate_own_sku_makeshop_mapping AS cmm
    ON cmm.sku_id = cr.sku_id
),
unique_evidence_candidates AS (
  SELECT
    csj.*,
    csj.sample_seller_product_code_by_own_sku AS dryrun_makeshop_product_code,
    csj.sample_channel_sku_code_by_own_sku AS dryrun_makeshop_option_code
  FROM candidate_source_join_stats AS csj
  WHERE csj.code_pair_distinct_by_own_sku = 1
),
duplicate_evidence_excluded AS (
  SELECT *
  FROM candidate_source_join_stats
  WHERE code_pair_distinct_by_own_sku > 1
),
evidence_missing_excluded AS (
  SELECT *
  FROM candidate_source_join_stats
  WHERE NOT makeshop_code_candidate_exists
    AND code_pair_distinct_by_own_sku <> 1
),
unique_evidence_code_counts AS (
  SELECT
    dryrun_makeshop_product_code,
    dryrun_makeshop_option_code,
    COUNT(DISTINCT sku_id) AS sku_count_for_dryrun_code
  FROM unique_evidence_candidates
  GROUP BY
    dryrun_makeshop_product_code,
    dryrun_makeshop_option_code
),
unique_evidence_selfpia_counts AS (
  SELECT
    selfpia_sku,
    COUNT(DISTINCT dryrun_makeshop_product_code) AS product_count_for_selfpia_sku
  FROM unique_evidence_candidates
  GROUP BY selfpia_sku
),
dryrun_plan AS (
  SELECT
    uec.*,
    COALESCE(uecc.sku_count_for_dryrun_code, 0) AS sku_count_for_dryrun_code,
    COALESCE(uesc.product_count_for_selfpia_sku, 0) AS product_count_for_selfpia_sku,
    false::boolean AS has_existing_confirmed,
    false::boolean AS has_existing_manual,
    (
      uec.semantic_true_risk
      OR uec.risk_note LIKE '%semantic%'
      OR lower(COALESCE(uec.option_name, '')) LIKE '%크리스탈ab%'
      OR lower(COALESCE(uec.option_name, '')) LIKE '% ab %'
      OR lower(COALESCE(uec.option_name, '')) LIKE 'ab %'
      OR lower(COALESCE(uec.option_name, '')) LIKE '% ab'
      OR lower(COALESCE(uec.option_name, '')) LIKE '%화이트골드%실버%'
      OR lower(COALESCE(uec.option_name, '')) LIKE '%실버%화이트골드%'
      OR lower(COALESCE(uec.option_name, '')) LIKE '%1+1%'
      OR lower(COALESCE(uec.option_name, '')) LIKE '%수량%'
    ) AS semantic_or_risk_keyword_warning
  FROM unique_evidence_candidates AS uec
  LEFT JOIN unique_evidence_code_counts AS uecc
    ON uecc.dryrun_makeshop_product_code = uec.dryrun_makeshop_product_code
   AND uecc.dryrun_makeshop_option_code = uec.dryrun_makeshop_option_code
  LEFT JOIN unique_evidence_selfpia_counts AS uesc
    ON uesc.selfpia_sku = uec.selfpia_sku
),
clean_dryrun_plan AS (
  SELECT *
  FROM dryrun_plan
  WHERE NOT has_existing_confirmed
    AND NOT has_existing_manual
    AND sku_count_for_dryrun_code = 1
    AND product_count_for_selfpia_sku = 1
    AND NOT semantic_or_risk_keyword_warning
),
ab_keyword_excluded AS (
  SELECT *
  FROM clean_dryrun_plan
  WHERE lower(COALESCE(option_name, '')) LIKE '%ab%'
),
final_planned_plan AS (
  SELECT *
  FROM clean_dryrun_plan
  WHERE lower(COALESCE(option_name, '')) NOT LIKE '%ab%'
),
duplicate_code_pair_excluded AS (
  SELECT *
  FROM dryrun_plan
  WHERE sku_count_for_dryrun_code > 1
),
risk_keyword_excluded AS (
  SELECT *
  FROM dryrun_plan
  WHERE semantic_or_risk_keyword_warning
),
summary_rows AS (
  SELECT 'source_candidate_total'::text AS summary_type, COUNT(*)::bigint AS row_count, 'Original MakeShop medium candidate baseline.'::text AS note FROM candidate_rows
  UNION ALL SELECT 'medium_candidate_count', COUNT(*)::bigint, 'All current MakeShop candidates are medium confidence.' FROM candidate_rows WHERE confidence_tier = 'auto_match_medium_confidence'
  UNION ALL SELECT 'unique_evidence_candidate_count', COUNT(*)::bigint, 'own_sku joins to exactly one existing MakeShop seller_product_code + channel_sku_code pair.' FROM unique_evidence_candidates
  UNION ALL SELECT 'duplicate_evidence_excluded_count', COUNT(*)::bigint, 'own_sku joins to multiple existing MakeShop code pairs; excluded from planned dryrun.' FROM duplicate_evidence_excluded
  UNION ALL SELECT 'evidence_missing_excluded_count', COUNT(*)::bigint, 'no direct MakeShop code and no unique own_sku-based MakeShop code evidence.' FROM evidence_missing_excluded
  UNION ALL SELECT 'duplicate_code_pair_excluded_count', COUNT(*)::bigint, 'unique-evidence rows excluded because the planned MakeShop code pair is not 1:1.' FROM duplicate_code_pair_excluded
  UNION ALL SELECT 'risk_keyword_excluded_count', COUNT(*)::bigint, 'unique-evidence rows excluded by risk keywords or semantic warnings.' FROM risk_keyword_excluded
  UNION ALL SELECT 'clean_subset_before_ab_exclusion_count', COUNT(*)::bigint, 'clean subset before broad AB exclusion.' FROM clean_dryrun_plan
  UNION ALL SELECT 'ab_keyword_excluded_count', COUNT(*)::bigint, 'broad AB keyword rows excluded from final planned subset.' FROM ab_keyword_excluded
  UNION ALL SELECT 'final_planned_count', COUNT(*)::bigint, 'final planned rows after excluding broad AB rows; this SQL does not write.' FROM final_planned_plan
  UNION ALL SELECT 'skipped_existing_confirmed_count', COUNT(*)::bigint, 'must be zero; existing confirmed rows are not overwritten.' FROM dryrun_plan WHERE has_existing_confirmed
  UNION ALL SELECT 'skipped_existing_manual_count', COUNT(*)::bigint, 'must be zero; existing manual rows are not overwritten.' FROM dryrun_plan WHERE has_existing_manual
  UNION ALL SELECT 'duplicate_makeshop_code_count', COUNT(*)::bigint, 'must be zero inside final planned rows.' FROM final_planned_plan WHERE sku_count_for_dryrun_code > 1
  UNION ALL SELECT 'duplicate_selfpia_to_makeshop_count', COUNT(*)::bigint, 'must be zero inside final planned rows.' FROM final_planned_plan WHERE product_count_for_selfpia_sku > 1
  UNION ALL SELECT 'semantic_warning_count', COUNT(*)::bigint, 'must be zero inside final planned rows.' FROM final_planned_plan WHERE semantic_or_risk_keyword_warning
  UNION ALL SELECT 'strict_risk_keyword_remaining_count', COUNT(*)::bigint, 'must be zero; conservative keyword recheck after AB exclusion.' FROM final_planned_plan WHERE lower(COALESCE(option_name, '')) LIKE '%크리스탈%' OR lower(COALESCE(option_name, '')) LIKE '%크리스탈ab%' OR lower(COALESCE(option_name, '')) LIKE '%크리ab%' OR lower(COALESCE(option_name, '')) LIKE '%ab%' OR lower(COALESCE(option_name, '')) LIKE '%화이트골드%' OR lower(COALESCE(option_name, '')) LIKE '%실버%' OR lower(COALESCE(option_name, '')) LIKE '%골드%' OR lower(COALESCE(option_name, '')) LIKE '%로즈골드%' OR lower(COALESCE(option_name, '')) LIKE '%핑크골드%' OR lower(COALESCE(option_name, '')) LIKE '%세트%' OR lower(COALESCE(option_name, '')) LIKE '%1+1%' OR lower(COALESCE(option_name, '')) LIKE '%수량%'
  UNION ALL SELECT 'rollback_after_count', 0::bigint, 'read-only dryrun; no rows are written, ROLLBACK leaves zero dryrun rows.'
  UNION ALL SELECT 'rollback_verdict', 1::bigint, 'PASS when row_count=1; this file ends with ROLLBACK.'
  UNION ALL SELECT 'overall_verdict', CASE
      WHEN (SELECT COUNT(*) FROM candidate_rows) = 1247
       AND (SELECT COUNT(*) FROM unique_evidence_candidates) = 291
       AND (SELECT COUNT(*) FROM duplicate_evidence_excluded) = 18
       AND (SELECT COUNT(*) FROM evidence_missing_excluded) = 956
       AND (SELECT COUNT(*) FROM clean_dryrun_plan) = 255
       AND (SELECT COUNT(*) FROM ab_keyword_excluded) = 14
       AND (SELECT COUNT(*) FROM final_planned_plan) = 241
       AND NOT EXISTS (SELECT 1 FROM dryrun_plan WHERE has_existing_confirmed OR has_existing_manual)
       AND NOT EXISTS (SELECT 1 FROM final_planned_plan WHERE sku_count_for_dryrun_code > 1)
       AND NOT EXISTS (SELECT 1 FROM final_planned_plan WHERE product_count_for_selfpia_sku > 1)
       AND NOT EXISTS (SELECT 1 FROM final_planned_plan WHERE semantic_or_risk_keyword_warning)
       AND NOT EXISTS (
         SELECT 1
         FROM final_planned_plan
         WHERE lower(COALESCE(option_name, '')) LIKE '%크리스탈%'
            OR lower(COALESCE(option_name, '')) LIKE '%크리스탈ab%'
            OR lower(COALESCE(option_name, '')) LIKE '%크리ab%'
            OR lower(COALESCE(option_name, '')) LIKE '%ab%'
            OR lower(COALESCE(option_name, '')) LIKE '%화이트골드%'
            OR lower(COALESCE(option_name, '')) LIKE '%실버%'
            OR lower(COALESCE(option_name, '')) LIKE '%골드%'
            OR lower(COALESCE(option_name, '')) LIKE '%로즈골드%'
            OR lower(COALESCE(option_name, '')) LIKE '%핑크골드%'
            OR lower(COALESCE(option_name, '')) LIKE '%세트%'
            OR lower(COALESCE(option_name, '')) LIKE '%1+1%'
            OR lower(COALESCE(option_name, '')) LIKE '%수량%'
       )
      THEN 1 ELSE 0 END::bigint,
    'PASS when row_count=1; FAIL when row_count=0.'
),
review_bucket_source AS (
  SELECT
    'final_planned_sample'::text AS sample_bucket,
    d.confidence_tier,
    d.sku_id,
    d.sku_id_text,
    d.selfpia_sku,
    d.own_sku,
    d.product_name,
    d.option_name,
    d.dryrun_makeshop_product_code AS makeshop_code_candidate,
    d.dryrun_makeshop_product_code AS makeshop_product_candidate,
    d.dryrun_makeshop_option_code AS makeshop_option_candidate,
    true::boolean AS makeshop_code_candidate_exists,
    true::boolean AS makeshop_code_and_option_evidence_exists,
    d.sku_count_for_dryrun_code AS sku_count_for_makeshop_code,
    d.duplicate_own_sku_same_product_family,
    d.duplicate_own_sku_cross_product,
    d.duplicate_own_sku_blocked,
    d.duplicate_selfpia_sku_to_makeshop_code,
    d.semantic_true_risk,
    d.channel_absent_or_inactive,
    d.true_conflict_or_residual,
    'clean unique own_sku-based MakeShop code evidence' AS match_reason,
    'clean_own_sku_unique_code_pair' AS evidence_source,
    'final planned subset after AB exclusion; review before local apply design' AS risk_note,
    d.export_allowed,
    d.reviewer_decision
  FROM final_planned_plan AS d
  UNION ALL
  SELECT
    'ab_keyword_excluded_sample',
    d.confidence_tier,
    d.sku_id,
    d.sku_id_text,
    d.selfpia_sku,
    d.own_sku,
    d.product_name,
    d.option_name,
    d.dryrun_makeshop_product_code,
    d.dryrun_makeshop_product_code,
    d.dryrun_makeshop_option_code,
    true::boolean,
    true::boolean,
    d.sku_count_for_dryrun_code,
    d.duplicate_own_sku_same_product_family,
    d.duplicate_own_sku_cross_product,
    d.duplicate_own_sku_blocked,
    d.duplicate_selfpia_sku_to_makeshop_code,
    d.semantic_true_risk,
    d.channel_absent_or_inactive,
    d.true_conflict_or_residual,
    'excluded by broad AB keyword after clean subset review',
    'ab_keyword_excluded',
    'broad AB text excluded conservatively from final planned subset',
    d.export_allowed,
    d.reviewer_decision
  FROM ab_keyword_excluded AS d
  UNION ALL
  SELECT
    'same_product_family_clean_sample',
    d.confidence_tier,
    d.sku_id,
    d.sku_id_text,
    d.selfpia_sku,
    d.own_sku,
    d.product_name,
    d.option_name,
    d.dryrun_makeshop_product_code,
    d.dryrun_makeshop_product_code,
    d.dryrun_makeshop_option_code,
    true::boolean,
    true::boolean,
    d.sku_count_for_dryrun_code,
    d.duplicate_own_sku_same_product_family,
    d.duplicate_own_sku_cross_product,
    d.duplicate_own_sku_blocked,
    d.duplicate_selfpia_sku_to_makeshop_code,
    d.semantic_true_risk,
    d.channel_absent_or_inactive,
    d.true_conflict_or_residual,
    'clean subset inside same product family',
    'same_product_family_clean',
    'check option-only repeat inside one product family',
    d.export_allowed,
    d.reviewer_decision
  FROM final_planned_plan AS d
  WHERE d.duplicate_own_sku_same_product_family
  UNION ALL
  SELECT
    'cross_product_possible_clean_sample',
    d.confidence_tier,
    d.sku_id,
    d.sku_id_text,
    d.selfpia_sku,
    d.own_sku,
    d.product_name,
    d.option_name,
    d.dryrun_makeshop_product_code,
    d.dryrun_makeshop_product_code,
    d.dryrun_makeshop_option_code,
    true::boolean,
    true::boolean,
    d.sku_count_for_dryrun_code,
    d.duplicate_own_sku_same_product_family,
    d.duplicate_own_sku_cross_product,
    d.duplicate_own_sku_blocked,
    d.duplicate_selfpia_sku_to_makeshop_code,
    d.semantic_true_risk,
    d.channel_absent_or_inactive,
    d.true_conflict_or_residual,
    'clean subset but own_sku appears across product families',
    'cross_product_possible_clean',
    'review product name and option semantics carefully',
    d.export_allowed,
    d.reviewer_decision
  FROM final_planned_plan AS d
  WHERE d.duplicate_own_sku_cross_product
  UNION ALL
  SELECT
    'seller_product_code_group_sample',
    d.confidence_tier,
    d.sku_id,
    d.sku_id_text,
    d.selfpia_sku,
    d.own_sku,
    d.product_name,
    d.option_name,
    d.dryrun_makeshop_product_code,
    d.dryrun_makeshop_product_code,
    d.dryrun_makeshop_option_code,
    true::boolean,
    true::boolean,
    d.sku_count_for_dryrun_code,
    d.duplicate_own_sku_same_product_family,
    d.duplicate_own_sku_cross_product,
    d.duplicate_own_sku_blocked,
    d.duplicate_selfpia_sku_to_makeshop_code,
    d.semantic_true_risk,
    d.channel_absent_or_inactive,
    d.true_conflict_or_residual,
    'grouped by MakeShop seller_product_code',
    'seller_product_code_group',
    'compare rows sharing one MakeShop product code',
    d.export_allowed,
    d.reviewer_decision
  FROM final_planned_plan AS d
  UNION ALL
  SELECT
    'channel_sku_code_sample',
    d.confidence_tier,
    d.sku_id,
    d.sku_id_text,
    d.selfpia_sku,
    d.own_sku,
    d.product_name,
    d.option_name,
    d.dryrun_makeshop_product_code,
    d.dryrun_makeshop_product_code,
    d.dryrun_makeshop_option_code,
    true::boolean,
    true::boolean,
    d.sku_count_for_dryrun_code,
    d.duplicate_own_sku_same_product_family,
    d.duplicate_own_sku_cross_product,
    d.duplicate_own_sku_blocked,
    d.duplicate_selfpia_sku_to_makeshop_code,
    d.semantic_true_risk,
    d.channel_absent_or_inactive,
    d.true_conflict_or_residual,
    'grouped by MakeShop channel_sku_code',
    'channel_sku_code_group',
    'check MakeShop option/SKU code against option name',
    d.export_allowed,
    d.reviewer_decision
  FROM final_planned_plan AS d
  UNION ALL
  SELECT
    'selfpia_sku_sample',
    d.confidence_tier,
    d.sku_id,
    d.sku_id_text,
    d.selfpia_sku,
    d.own_sku,
    d.product_name,
    d.option_name,
    d.dryrun_makeshop_product_code,
    d.dryrun_makeshop_product_code,
    d.dryrun_makeshop_option_code,
    true::boolean,
    true::boolean,
    d.sku_count_for_dryrun_code,
    d.duplicate_own_sku_same_product_family,
    d.duplicate_own_sku_cross_product,
    d.duplicate_own_sku_blocked,
    d.duplicate_selfpia_sku_to_makeshop_code,
    d.semantic_true_risk,
    d.channel_absent_or_inactive,
    d.true_conflict_or_residual,
    'selfpia SKU sorted sample',
    'selfpia_sku_order',
    'check selfpia SKU, own_sku, product, option, and MakeShop code pair in one row',
    d.export_allowed,
    d.reviewer_decision
  FROM final_planned_plan AS d
  UNION ALL
  SELECT 'medium_candidate_sample'::text AS sample_bucket, c.* FROM candidate_rows AS c WHERE c.confidence_tier = 'auto_match_medium_confidence'
  UNION ALL SELECT 'makeshop_code_present_sample', c.* FROM candidate_rows AS c WHERE c.makeshop_code_candidate_exists
  UNION ALL SELECT 'makeshop_code_missing_sample', c.* FROM candidate_rows AS c WHERE NOT c.makeshop_code_candidate_exists
  UNION ALL
  SELECT
    'own_sku_unique_code_evidence_sample',
    c.confidence_tier,
    c.sku_id,
    c.sku_id_text,
    c.selfpia_sku,
    c.own_sku,
    c.product_name,
    c.option_name,
    c.sample_seller_product_code_by_own_sku AS makeshop_code_candidate,
    c.sample_seller_product_code_by_own_sku AS makeshop_product_candidate,
    c.sample_channel_sku_code_by_own_sku AS makeshop_option_candidate,
    true::boolean AS makeshop_code_candidate_exists,
    true::boolean AS makeshop_code_and_option_evidence_exists,
    c.code_pair_distinct_by_own_sku AS sku_count_for_makeshop_code,
    c.duplicate_own_sku_same_product_family,
    c.duplicate_own_sku_cross_product,
    c.duplicate_own_sku_blocked,
    c.duplicate_selfpia_sku_to_makeshop_code,
    c.semantic_true_risk,
    c.channel_absent_or_inactive,
    c.true_conflict_or_residual,
    'indirect own_sku joins to one existing MakeShop code pair',
    'own_sku_to_existing_makeshop_mapping',
    'Indirect code evidence; validate product/option before any apply design',
    c.export_allowed,
    c.reviewer_decision
  FROM candidate_source_join_stats AS c
  WHERE c.code_pair_distinct_by_own_sku = 1
  UNION ALL
  SELECT
    'duplicate_evidence_excluded_sample',
    c.confidence_tier,
    c.sku_id,
    c.sku_id_text,
    c.selfpia_sku,
    c.own_sku,
    c.product_name,
    c.option_name,
    c.sample_seller_product_code_by_own_sku AS makeshop_code_candidate,
    c.sample_seller_product_code_by_own_sku AS makeshop_product_candidate,
    c.sample_channel_sku_code_by_own_sku AS makeshop_option_candidate,
    true::boolean AS makeshop_code_candidate_exists,
    true::boolean AS makeshop_code_and_option_evidence_exists,
    c.code_pair_distinct_by_own_sku AS sku_count_for_makeshop_code,
    c.duplicate_own_sku_same_product_family,
    c.duplicate_own_sku_cross_product,
    c.duplicate_own_sku_blocked,
    c.duplicate_selfpia_sku_to_makeshop_code,
    c.semantic_true_risk,
    c.channel_absent_or_inactive,
    c.true_conflict_or_residual,
    'excluded because own_sku joins to multiple MakeShop code pairs',
    'duplicate_own_sku_to_makeshop_mapping',
    'Duplicate indirect code evidence; exclude from dryrun plan',
    c.export_allowed,
    c.reviewer_decision
  FROM candidate_source_join_stats AS c
  WHERE c.code_pair_distinct_by_own_sku > 1
  UNION ALL
  SELECT
    'duplicate_code_pair_excluded_sample',
    d.confidence_tier,
    d.sku_id,
    d.sku_id_text,
    d.selfpia_sku,
    d.own_sku,
    d.product_name,
    d.option_name,
    d.dryrun_makeshop_product_code AS makeshop_code_candidate,
    d.dryrun_makeshop_product_code AS makeshop_product_candidate,
    d.dryrun_makeshop_option_code AS makeshop_option_candidate,
    true::boolean AS makeshop_code_candidate_exists,
    true::boolean AS makeshop_code_and_option_evidence_exists,
    d.sku_count_for_dryrun_code AS sku_count_for_makeshop_code,
    d.duplicate_own_sku_same_product_family,
    d.duplicate_own_sku_cross_product,
    d.duplicate_own_sku_blocked,
    d.duplicate_selfpia_sku_to_makeshop_code,
    d.semantic_true_risk,
    d.channel_absent_or_inactive,
    d.true_conflict_or_residual,
    'excluded because the same MakeShop code pair appears on multiple candidate SKUs',
    'duplicate_planned_makeshop_code_pair',
    'Duplicate planned MakeShop code pair; exclude from clean dryrun plan',
    d.export_allowed,
    d.reviewer_decision
  FROM duplicate_code_pair_excluded AS d
  UNION ALL
  SELECT
    'evidence_missing_excluded_sample',
    c.confidence_tier,
    c.sku_id,
    c.sku_id_text,
    c.selfpia_sku,
    c.own_sku,
    c.product_name,
    c.option_name,
    c.makeshop_code_candidate,
    c.makeshop_product_candidate,
    c.makeshop_option_candidate,
    c.makeshop_code_candidate_exists,
    c.makeshop_code_and_option_evidence_exists,
    c.sku_count_for_makeshop_code,
    c.duplicate_own_sku_same_product_family,
    c.duplicate_own_sku_cross_product,
    c.duplicate_own_sku_blocked,
    c.duplicate_selfpia_sku_to_makeshop_code,
    c.semantic_true_risk,
    c.channel_absent_or_inactive,
    c.true_conflict_or_residual,
    'excluded because MakeShop code evidence is missing',
    c.evidence_source,
    'No direct or unique own_sku-based MakeShop code evidence',
    c.export_allowed,
    c.reviewer_decision
  FROM candidate_source_join_stats AS c
  WHERE NOT c.makeshop_code_candidate_exists
    AND c.code_pair_distinct_by_own_sku <> 1
  UNION ALL
  SELECT
    'risk_keyword_sample',
    d.confidence_tier,
    d.sku_id,
    d.sku_id_text,
    d.selfpia_sku,
    d.own_sku,
    d.product_name,
    d.option_name,
    d.dryrun_makeshop_product_code AS makeshop_code_candidate,
    d.dryrun_makeshop_product_code AS makeshop_product_candidate,
    d.dryrun_makeshop_option_code AS makeshop_option_candidate,
    true::boolean AS makeshop_code_candidate_exists,
    true::boolean AS makeshop_code_and_option_evidence_exists,
    d.sku_count_for_dryrun_code AS sku_count_for_makeshop_code,
    d.duplicate_own_sku_same_product_family,
    d.duplicate_own_sku_cross_product,
    d.duplicate_own_sku_blocked,
    d.duplicate_selfpia_sku_to_makeshop_code,
    d.semantic_true_risk,
    d.channel_absent_or_inactive,
    d.true_conflict_or_residual,
    'risk keyword in unique evidence candidate',
    d.evidence_source,
    'Risk keyword row; exclude or manually review before apply',
    d.export_allowed,
    d.reviewer_decision
  FROM dryrun_plan AS d
  WHERE lower(COALESCE(d.option_name, '')) LIKE '%크리스탈%'
     OR lower(COALESCE(d.option_name, '')) LIKE '%ab%'
     OR lower(COALESCE(d.option_name, '')) LIKE '%화이트골드%'
     OR lower(COALESCE(d.option_name, '')) LIKE '%실버%'
     OR lower(COALESCE(d.option_name, '')) LIKE '%세트%'
     OR lower(COALESCE(d.option_name, '')) LIKE '%1+1%'
     OR lower(COALESCE(d.option_name, '')) LIKE '%수량%'
     OR lower(COALESCE(d.option_name, '')) LIKE '%골드%'
     OR lower(COALESCE(d.option_name, '')) LIKE '%로즈골드%'
     OR lower(COALESCE(d.option_name, '')) LIKE '%핑크골드%'
  UNION ALL SELECT 'same_product_family_sample', c.* FROM candidate_rows AS c WHERE c.duplicate_own_sku_same_product_family
  UNION ALL SELECT 'own_sku_repeat_sample', c.* FROM candidate_rows AS c WHERE c.duplicate_own_sku_blocked
  UNION ALL SELECT 'random_sample', c.* FROM candidate_rows AS c
  UNION ALL SELECT 'risk_edge_sample', c.* FROM candidate_rows AS c WHERE NOT c.makeshop_code_candidate_exists OR c.duplicate_own_sku_cross_product OR c.evidence_source IN ('quantity_or_set_wording', 'own_sku_repeat_only')
),
ranked_samples AS (
  SELECT
    rbs.*,
    COUNT(*) OVER (PARTITION BY sample_bucket) AS bucket_candidate_count,
    ROW_NUMBER() OVER (
      PARTITION BY sample_bucket
      ORDER BY
        CASE WHEN sample_bucket = 'random_sample' THEN md5(sku_id_text || sample_bucket)
             ELSE lpad(COALESCE(selfpia_sku, ''), 32, '0') || sku_id_text
        END
    ) AS sample_rank
  FROM review_bucket_source AS rbs
),
final_rows AS (
SELECT
  1 AS result_sort,
  CASE summary_type
    WHEN 'source_candidate_total' THEN 1
    WHEN 'medium_candidate_count' THEN 2
    WHEN 'unique_evidence_candidate_count' THEN 3
    WHEN 'duplicate_evidence_excluded_count' THEN 4
    WHEN 'evidence_missing_excluded_count' THEN 5
    WHEN 'duplicate_code_pair_excluded_count' THEN 6
    WHEN 'risk_keyword_excluded_count' THEN 7
    WHEN 'clean_subset_before_ab_exclusion_count' THEN 8
    WHEN 'ab_keyword_excluded_count' THEN 9
    WHEN 'final_planned_count' THEN 10
    WHEN 'skipped_existing_confirmed_count' THEN 11
    WHEN 'skipped_existing_manual_count' THEN 12
    WHEN 'duplicate_makeshop_code_count' THEN 13
    WHEN 'duplicate_selfpia_to_makeshop_count' THEN 14
    WHEN 'semantic_warning_count' THEN 15
    WHEN 'strict_risk_keyword_remaining_count' THEN 16
    WHEN 'rollback_after_count' THEN 17
    WHEN 'rollback_verdict' THEN 18
    WHEN 'overall_verdict' THEN 19
    ELSE 99
  END AS summary_sort,
  99 AS bucket_sort,
  'summary'::text AS result_kind,
  summary_type,
  row_count,
  note,
  NULL::text AS sample_bucket,
  NULL::bigint AS bucket_candidate_count,
  NULL::text AS confidence_tier,
  NULL::text AS sku_id,
  NULL::text AS selfpia_sku,
  NULL::text AS own_sku,
  NULL::text AS product_name,
  NULL::text AS option_name,
  NULL::text AS makeshop_code_candidate,
  NULL::text AS makeshop_product_candidate,
  NULL::text AS makeshop_option_candidate,
  NULL::text AS match_reason,
  NULL::text AS evidence_source,
  NULL::text AS risk_note,
  NULL::text AS reviewer_check_point,
  NULL::bigint AS sample_rank
FROM summary_rows
UNION ALL
SELECT
  2 AS result_sort,
  99 AS summary_sort,
  CASE sample_bucket
    WHEN 'final_planned_sample' THEN 1
    WHEN 'ab_keyword_excluded_sample' THEN 2
    WHEN 'same_product_family_clean_sample' THEN 3
    WHEN 'cross_product_possible_clean_sample' THEN 4
    WHEN 'seller_product_code_group_sample' THEN 5
    WHEN 'channel_sku_code_sample' THEN 6
    WHEN 'selfpia_sku_sample' THEN 7
    WHEN 'medium_candidate_sample' THEN 8
    WHEN 'makeshop_code_present_sample' THEN 9
    WHEN 'makeshop_code_missing_sample' THEN 10
    WHEN 'own_sku_unique_code_evidence_sample' THEN 11
    WHEN 'duplicate_evidence_excluded_sample' THEN 12
    WHEN 'duplicate_code_pair_excluded_sample' THEN 13
    WHEN 'evidence_missing_excluded_sample' THEN 14
    WHEN 'risk_keyword_sample' THEN 15
    WHEN 'same_product_family_sample' THEN 16
    WHEN 'own_sku_repeat_sample' THEN 17
    WHEN 'random_sample' THEN 18
    WHEN 'risk_edge_sample' THEN 19
    ELSE 99
  END AS bucket_sort,
  'sample'::text AS result_kind,
  NULL::text AS summary_type,
  NULL::bigint AS row_count,
  NULL::text AS note,
  sample_bucket,
  bucket_candidate_count,
  confidence_tier,
  sku_id_text AS sku_id,
  selfpia_sku,
  own_sku,
  product_name,
  option_name,
  makeshop_code_candidate,
  makeshop_product_candidate,
  makeshop_option_candidate,
  match_reason,
  evidence_source,
  risk_note,
  CASE
    WHEN sample_bucket = 'final_planned_sample' THEN 'Review final 241 rows before any local apply SQL is written.'
    WHEN sample_bucket = 'ab_keyword_excluded_sample' THEN 'Confirm these broad AB rows remain excluded for conservative apply.'
    WHEN sample_bucket = 'same_product_family_clean_sample' THEN 'Check same-family own_sku repeat is normal option variation.'
    WHEN sample_bucket = 'cross_product_possible_clean_sample' THEN 'Review cross-product-looking own_sku repeat carefully.'
    WHEN sample_bucket = 'seller_product_code_group_sample' THEN 'Compare product and option rows sharing one MakeShop seller product code.'
    WHEN sample_bucket = 'channel_sku_code_sample' THEN 'Check channel_sku_code against selfpia SKU and option text.'
    WHEN sample_bucket = 'selfpia_sku_sample' THEN 'Review selfpia SKU, own_sku, product, option, and MakeShop code pair in one row.'
    WHEN sample_bucket = 'makeshop_code_present_sample' THEN 'Check whether MakeShop code and option evidence identify this SKU.'
    WHEN sample_bucket = 'makeshop_code_missing_sample' THEN 'Do not apply as confirmed code until MakeShop code source is supplied.'
    WHEN sample_bucket = 'own_sku_unique_code_evidence_sample' THEN 'Check whether indirect own_sku-based MakeShop code evidence is valid for this exact SKU.'
    WHEN sample_bucket = 'duplicate_evidence_excluded_sample' THEN 'Confirm this remains excluded because own_sku maps to multiple MakeShop code pairs.'
    WHEN sample_bucket = 'duplicate_code_pair_excluded_sample' THEN 'Confirm this remains excluded because the planned MakeShop code pair is duplicated.'
    WHEN sample_bucket = 'evidence_missing_excluded_sample' THEN 'Confirm this remains excluded until a MakeShop source code is supplied.'
    WHEN sample_bucket = 'risk_keyword_sample' THEN 'Check risk keyword semantics before any local apply design.'
    WHEN sample_bucket = 'same_product_family_sample' THEN 'Check that repeated own_sku stays inside one product family.'
    WHEN sample_bucket = 'own_sku_repeat_sample' THEN 'Check own_sku repeat is expected and not a cross-product conflict.'
    WHEN sample_bucket = 'risk_edge_sample' THEN 'Review missing-code or edge evidence before any apply design.'
    ELSE 'Spot-check product, option, own_sku, and MakeShop code evidence.'
  END AS reviewer_check_point,
  sample_rank
FROM ranked_samples
WHERE sample_bucket IN (
    'final_planned_sample',
    'ab_keyword_excluded_sample',
    'duplicate_code_pair_excluded_sample',
    'evidence_missing_excluded_sample',
    'seller_product_code_group_sample',
    'channel_sku_code_sample',
    'selfpia_sku_sample'
  )
  AND sample_rank <= CASE
  WHEN sample_bucket = 'final_planned_sample' THEN 80
  WHEN sample_bucket = 'ab_keyword_excluded_sample' THEN 20
  ELSE 20
END
)
SELECT
  result_kind,
  summary_type,
  row_count,
  note,
  sample_bucket,
  bucket_candidate_count,
  confidence_tier,
  sku_id,
  selfpia_sku,
  own_sku,
  product_name,
  option_name,
  makeshop_code_candidate,
  makeshop_product_candidate,
  makeshop_option_candidate,
  match_reason,
  evidence_source,
  risk_note,
  reviewer_check_point,
  sample_rank
FROM final_rows
ORDER BY
  result_sort,
  summary_sort,
  bucket_sort,
  sample_rank;

ROLLBACK;
