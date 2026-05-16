-- =============================================================================
-- dryrun_makeshop_select_only.sql
--
-- SELECT-only DRYRUN. Classifies makeshop CSV rows against existing
-- product_code.* data and emits 4 result sets:
--
--   1) SUMMARY          - row counts by classification / reason
--   2) AUTO_CONFIRM     - rows that pass every auto criterion
--   3) REVIEW_REQUIRED  - rows that fail one or more criteria, with reason
--   4) CONFLICT         - rows whose (channel, sto_id) already exists
--                         in sku_channel_mapping
--
-- Strictly read-only against product_code.*:
--   - No INSERT / UPDATE / DELETE / TRUNCATE
--   - No ALTER / CREATE on persistent objects
--   - Only session-scoped TEMP TABLEs are created
--   - Entire script wrapped in BEGIN ... ROLLBACK as extra safety
--
-- Allowed target: local Docker PostgreSQL database `product_ops_test` only.
-- Forbidden targets:
--   - Operating Supabase
--   - Synology NAS PostgreSQL
--
-- Usage (PowerShell, run from workspace root)
-- -------------------------------------------
--   $env:PGPASSWORD = '<password>'
--   psql -h localhost -p 5433 -U product_ops_tester -d product_ops_test `
--        -v ON_ERROR_STOP=1 `
--        -f sql/dryrun_makeshop_select_only.sql
--
-- Prerequisite: scripts/extract_makeshop_minimal_csv.py has produced
--   outputs/makeshop_minimal_sample100.csv  (default input below)
--
-- To run against the full file, override the \set CSV_PATH line at the top
-- of this script, or pass `-v CSV_PATH='outputs/makeshop_minimal_full.csv'`
-- on the psql command line.
-- =============================================================================

\set ON_ERROR_STOP on

-- Override on the command line via:
--   psql ... -v CSV_PATH='outputs/makeshop_minimal_full.csv' -f ...
\if :{?CSV_PATH}
\else
  \set CSV_PATH 'outputs/makeshop_minimal_sample100.csv'
\endif

-- ---------------------------------------------------------------------------
-- 0. Guard: only allow on local Docker DB
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'dryrun is allowed only on product_ops_test. Current database: %',
      current_database();
  END IF;
END
$$;

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Raw landing (session-scoped TEMP table)
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE mk_src (
  product_uid   text,
  sto_id        text,
  sto_code      text,
  opt_value     text,
  opt_values    text,
  barcode       text,
  product_name  text,
  status        text,
  gid           text,
  ps_num        text
);

\copy mk_src FROM '/tmp/makeshop_minimal_full.csv' WITH (FORMAT CSV, HEADER true, ENCODING 'UTF8')

-- ---------------------------------------------------------------------------
-- 2. Extract own_sku candidate (priority chain) + composite channel_sku_code
--    1) sto_code              (when non-blank)
--    2) opt_value  bracket    [ALPHA-NN-NN(_N)]
--    3) opt_values bracket    [ALPHA-NN-NN(_N)]
--
-- channel_sku_code (composite):
--   product_uid || '-' || sto_id, only when BOTH are non-blank.
--   Raw values are preserved as product_uid and sto_id columns; the composite
--   is the channel-side unique identifier used for conflict/mapping checks.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE mk_extracted AS
SELECT
  s.product_uid,
  s.sto_id,
  s.sto_code,
  s.opt_value,
  s.opt_values,
  s.barcode,
  s.product_name,
  s.status                                          AS source_status,
  substring(s.opt_value  FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]')
                                                    AS opt_value_bracket,
  substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]')
                                                    AS opt_values_bracket,
  CASE
    WHEN s.sto_code IS NOT NULL AND btrim(s.sto_code) <> ''
      THEN btrim(s.sto_code)
    WHEN substring(s.opt_value  FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]')
         IS NOT NULL
      THEN substring(s.opt_value  FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]')
    WHEN substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]')
         IS NOT NULL
      THEN substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]')
    ELSE NULL
  END                                               AS own_sku_candidate,
  CASE
    WHEN s.sto_code IS NOT NULL AND btrim(s.sto_code) <> ''
      THEN 'sto_code'
    WHEN substring(s.opt_value  FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]')
         IS NOT NULL
      THEN 'opt_value_bracket'
    WHEN substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]')
         IS NOT NULL
      THEN 'opt_values_bracket'
    ELSE NULL
  END                                               AS extraction_method,
  CASE
    WHEN s.product_uid IS NOT NULL AND btrim(s.product_uid) <> ''
     AND s.sto_id      IS NOT NULL AND btrim(s.sto_id)      <> ''
      THEN btrim(s.product_uid) || '-' || btrim(s.sto_id)
    ELSE NULL
  END                                               AS channel_sku_code
FROM mk_src s;

-- ---------------------------------------------------------------------------
-- 3. Match own_sku candidate against code_alias(code_system='own_sku').
--    Aggregate so a single source row resolves to a single match_count.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE mk_match_agg AS
SELECT
  e.product_uid,
  e.sto_id,
  e.channel_sku_code,
  e.sto_code,
  e.opt_value,
  e.opt_values,
  e.barcode,
  e.product_name,
  e.source_status,
  e.own_sku_candidate,
  e.extraction_method,
  e.opt_value_bracket,
  e.opt_values_bracket,
  COUNT(ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL) AS match_count,
  array_agg(DISTINCT ca.target_id)
    FILTER (WHERE ca.target_id IS NOT NULL)                    AS candidate_sku_ids,
  CASE
    WHEN COUNT(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL) = 1
      THEN (array_agg(DISTINCT ca.target_id)
              FILTER (WHERE ca.target_id IS NOT NULL))[1]
    ELSE NULL
  END                                                          AS resolved_sku_id
FROM mk_extracted e
LEFT JOIN product_code.code_alias ca
  ON ca.target_type = 'SKU'
 AND ca.code_system = 'own_sku'
 AND ca.code_value  = e.own_sku_candidate
 AND e.own_sku_candidate IS NOT NULL
 AND btrim(e.own_sku_candidate) <> ''
GROUP BY
  e.product_uid, e.sto_id, e.channel_sku_code, e.sto_code, e.opt_value,
  e.opt_values, e.barcode, e.product_name, e.source_status, e.own_sku_candidate,
  e.extraction_method, e.opt_value_bracket, e.opt_values_bracket;

-- ---------------------------------------------------------------------------
-- 4. Lookup existing sku_channel_mapping conflict and SKU status
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE mk_classified AS
WITH collision AS (
  -- conflict 검사는 composite channel_sku_code 기준 (product_uid + '-' + sto_id)
  SELECT
    m.product_uid,
    m.sto_id,
    m.channel_sku_code,
    m.resolved_sku_id,
    scm.id                  AS existing_mapping_id,
    scm.sku_id              AS existing_mapped_sku_id,
    scm.is_primary          AS existing_is_primary
  FROM mk_match_agg m
  LEFT JOIN product_code.sku_channel_mapping scm
    ON scm.channel_code     = 'makeshop'
   AND scm.channel_sku_code = m.channel_sku_code
   AND m.channel_sku_code IS NOT NULL
),
sku_status AS (
  SELECT
    m.product_uid,
    m.sto_id,
    sm.id                   AS sku_master_id,
    sm.status               AS sku_master_status
  FROM mk_match_agg m
  LEFT JOIN product_code.sku_master sm
    ON sm.id = m.resolved_sku_id
)
SELECT
  m.product_uid,
  m.sto_id,
  m.channel_sku_code,
  m.sto_code,
  m.opt_value,
  m.opt_values,
  m.barcode,
  m.product_name,
  m.source_status,
  m.own_sku_candidate,
  m.extraction_method,
  m.opt_value_bracket,
  m.opt_values_bracket,
  m.match_count,
  m.candidate_sku_ids,
  m.resolved_sku_id,
  c.existing_mapping_id,
  c.existing_mapped_sku_id,
  c.existing_is_primary,
  ss.sku_master_status,
  -- Precedence: null_key > extraction failure > match issues > conflict > inactive
  CASE
    WHEN m.product_uid IS NULL OR btrim(m.product_uid) = ''
      OR m.sto_id IS NULL OR btrim(m.sto_id) = ''
      THEN 'null_key'
    WHEN (m.sto_code IS NULL OR btrim(m.sto_code) = '')
     AND ((m.opt_value  IS NOT NULL AND btrim(m.opt_value)  <> '')
       OR (m.opt_values IS NOT NULL AND btrim(m.opt_values) <> ''))
     AND m.opt_value_bracket IS NULL
     AND m.opt_values_bracket IS NULL
      THEN 'pattern_unmatched'
    WHEN m.own_sku_candidate IS NULL OR btrim(m.own_sku_candidate) = ''
      THEN 'own_sku_missing'
    WHEN m.match_count = 0
      THEN 'own_sku_not_in_alias'
    WHEN m.match_count > 1
      THEN 'own_sku_ambiguous'
    WHEN c.existing_mapping_id IS NOT NULL
      THEN 'channel_sku_conflict'
    WHEN ss.sku_master_status IS NOT NULL
     AND (ss.sku_master_status ILIKE '%inactive%'
       OR ss.sku_master_status ILIKE '%deleted%'
       OR ss.sku_master_status ILIKE '%archive%')
      THEN 'sku_inactive'
    ELSE NULL
  END                                              AS review_reason,
  CASE
    WHEN m.product_uid IS NULL OR btrim(m.product_uid) = ''
      OR m.sto_id IS NULL OR btrim(m.sto_id) = ''
      THEN 'review_required'
    WHEN (m.sto_code IS NULL OR btrim(m.sto_code) = '')
     AND ((m.opt_value  IS NOT NULL AND btrim(m.opt_value)  <> '')
       OR (m.opt_values IS NOT NULL AND btrim(m.opt_values) <> ''))
     AND m.opt_value_bracket IS NULL
     AND m.opt_values_bracket IS NULL
      THEN 'review_required'
    WHEN m.own_sku_candidate IS NULL OR btrim(m.own_sku_candidate) = ''
      THEN 'review_required'
    WHEN m.match_count = 0
      THEN 'review_required'
    WHEN m.match_count > 1
      THEN 'review_required'
    WHEN c.existing_mapping_id IS NOT NULL
      THEN 'review_required'
    WHEN ss.sku_master_status IS NOT NULL
     AND (ss.sku_master_status ILIKE '%inactive%'
       OR ss.sku_master_status ILIKE '%deleted%'
       OR ss.sku_master_status ILIKE '%archive%')
      THEN 'review_required'
    ELSE 'auto_confirm'
  END                                              AS classification
FROM mk_match_agg m
LEFT JOIN collision c
  ON c.product_uid = m.product_uid
 AND c.sto_id      = m.sto_id
LEFT JOIN sku_status ss
  ON ss.product_uid = m.product_uid
 AND ss.sto_id      = m.sto_id;

-- ---------------------------------------------------------------------------
-- 5. Emit 4 result sets
-- ---------------------------------------------------------------------------
\echo
\echo ===== [SUMMARY] =====
SELECT
  COUNT(*)                                                          AS total_rows,
  COUNT(*) FILTER (WHERE classification = 'auto_confirm')           AS auto_confirm,
  COUNT(*) FILTER (WHERE classification = 'review_required')        AS review_required,
  COUNT(*) FILTER (WHERE review_reason = 'null_key')                AS r_null_key,
  COUNT(*) FILTER (WHERE review_reason = 'pattern_unmatched')       AS r_pattern_unmatched,
  COUNT(*) FILTER (WHERE review_reason = 'own_sku_missing')         AS r_own_sku_missing,
  COUNT(*) FILTER (WHERE review_reason = 'own_sku_not_in_alias')    AS r_own_sku_not_in_alias,
  COUNT(*) FILTER (WHERE review_reason = 'own_sku_ambiguous')       AS r_own_sku_ambiguous,
  COUNT(*) FILTER (WHERE review_reason = 'channel_sku_conflict')    AS r_channel_sku_conflict,
  COUNT(*) FILTER (WHERE review_reason = 'sku_inactive')            AS r_sku_inactive
FROM mk_classified;

\echo
\echo ===== [SUMMARY by extraction_method] =====
SELECT
  COALESCE(extraction_method, '(none)') AS extraction_method,
  COUNT(*)                              AS rows,
  COUNT(*) FILTER (WHERE classification = 'auto_confirm')    AS auto_confirm,
  COUNT(*) FILTER (WHERE classification = 'review_required') AS review_required
FROM mk_classified
GROUP BY extraction_method
ORDER BY 1;

\echo
\echo ===== [AUTO_CONFIRM] =====
-- channel_sku_code 는 composite (product_uid + '-' + sto_id)
-- sto_id_raw 는 XML 원본 sto_id
-- product_uid 는 XML 원본 product_uid (sku_channel_mapping 측 seller_product_code 후보)
SELECT
  'makeshop'::text          AS channel_code,
  product_uid               AS seller_product_code_raw,
  channel_sku_code,
  sto_id                    AS sto_id_raw,
  sto_code,
  opt_value,
  opt_values,
  own_sku_candidate         AS own_sku_code,
  extraction_method,
  resolved_sku_id           AS matched_sku_id,
  product_name
FROM mk_classified
WHERE classification = 'auto_confirm'
ORDER BY product_uid, sto_id;

\echo
\echo ===== [REVIEW_REQUIRED] =====
SELECT
  'makeshop'::text          AS channel_code,
  product_uid               AS seller_product_code_raw,
  channel_sku_code,
  sto_id                    AS sto_id_raw,
  sto_code,
  opt_value,
  opt_values,
  own_sku_candidate         AS own_sku_code,
  extraction_method,
  match_count,
  candidate_sku_ids,
  existing_mapping_id,
  existing_mapped_sku_id,
  sku_master_status,
  review_reason
FROM mk_classified
WHERE classification = 'review_required'
ORDER BY review_reason, product_uid, sto_id;

\echo
\echo ===== [CONFLICT] =====
SELECT
  'makeshop'::text          AS channel_code,
  product_uid               AS seller_product_code_raw,
  channel_sku_code,
  sto_id                    AS sto_id_raw,
  resolved_sku_id           AS would_be_sku_id,
  existing_mapping_id,
  existing_mapped_sku_id,
  existing_is_primary,
  CASE
    WHEN existing_mapped_sku_id IS NOT DISTINCT FROM resolved_sku_id
      THEN 'idempotent_same_sku'
    ELSE 'different_sku'
  END                       AS conflict_kind
FROM mk_classified
WHERE existing_mapping_id IS NOT NULL
ORDER BY product_uid, sto_id;

-- ---------------------------------------------------------------------------
-- 6. ROLLBACK ??undo all TEMP table creations; nothing is persisted.
-- ---------------------------------------------------------------------------
ROLLBACK;

\echo
\echo dryrun_makeshop_select_only.sql complete. ROLLBACK applied. No persistent changes.
