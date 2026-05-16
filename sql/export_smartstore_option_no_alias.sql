-- =============================================================================
-- Supabase SELECT-only export
-- Purpose: 운영 Supabase Product_code 프로젝트의 스마트스토어 옵션번호 매핑을
--          local Docker product_ops_test 의 product_code.code_alias 에
--          smartstore_option_no 로 import 하기 위한 CSV export 쿼리.
--
-- Run target  : Supabase Product_code (project_id=mrqoqmidnrawflwezxlm)
-- Schema      : public  (운영은 product_code 스키마가 아니라 public 사용)
-- Mode        : SELECT-only. INSERT/UPDATE/DELETE/DDL 금지.
-- Output file : exports/smartstore_option_no_alias.csv
--
-- 데이터 경로:
--   sku_master  ←  sku_channel_mapping  →  channel_sku (channel='smartstore')
--   code_alias 에는 smartstore 가 아예 없음 (selfpia_*, own_sku 만 존재).
--   따라서 channel_sku.channel_sku_code(=channel_option_id, 11자리 숫자)를
--   smartstore_option_no 코드값으로 사용한다.
--
-- 정책:
--   * confirmed (decision_status='confirmed', is_confirmed=true) →
--     code_system = 'smartstore_option_no'           (운영 기준 908 rows / 895 SKU)
--   * candidate (decision_status='auto_candidate', is_confirmed=false) →
--     code_system = 'smartstore_option_no_candidate' (운영 기준 11,691 rows / 11,681 SKU)
--   * 운영 Supabase 의 is_confirmed / decision_status 값은 절대 변경하지 않는다.
--     code_system 분리는 local code_alias 에 적재할 때의 라벨일 뿐이다.
-- =============================================================================

-- 1) 1차 export : confirmed only (local 적용 1차 후보)
-- File: exports/smartstore_option_no_alias.csv
select
  'SKU'::text                              as target_type,
  scm.sku_id                               as target_id,
  'smartstore_option_no'::text             as code_system,
  cs.channel_sku_code                      as code_value,
  cs.channel_option_id                     as parsed_part1,
  cs.combined_option_text                  as parsed_part2,
  null::text                               as selfpia_product_code,
  null::text                               as selfpia_option_no,
  false                                    as is_primary,
  cs.channel                               as memo_channel,
  scm.match_stage                          as memo_match_stage,
  scm.confidence                           as memo_confidence,
  scm.decision_status                      as memo_decision_status,
  scm.is_confirmed                         as memo_is_confirmed,
  sm.virtual_sku_code                      as memo_vsku
from public.sku_channel_mapping scm
join public.channel_sku cs on cs.id = scm.channel_sku_id
join public.sku_master   sm on sm.id = scm.sku_id
where cs.channel = 'smartstore'
  and scm.is_confirmed = true
  and cs.channel_sku_code is not null
order by scm.sku_id, cs.channel_sku_code;


-- 2) 2차 export : candidate(검수전) — 별도 파일, 별도 code_system
-- File: exports/smartstore_option_no_alias_candidates.csv
-- IMPORTANT: code_system 을 'smartstore_option_no_candidate' 로 명시.
--            confirmed 와 같은 라벨로 섞어 import 하지 않는다.
select
  'SKU'::text                              as target_type,
  scm.sku_id                               as target_id,
  'smartstore_option_no_candidate'::text   as code_system,
  cs.channel_sku_code                      as code_value,
  cs.channel_option_id                     as parsed_part1,
  cs.combined_option_text                  as parsed_part2,
  null::text                               as selfpia_product_code,
  null::text                               as selfpia_option_no,
  false                                    as is_primary,
  cs.channel                               as memo_channel,
  scm.match_stage                          as memo_match_stage,
  scm.confidence                           as memo_confidence,
  scm.decision_status                      as memo_decision_status,
  scm.is_confirmed                         as memo_is_confirmed,
  sm.virtual_sku_code                      as memo_vsku
from public.sku_channel_mapping scm
join public.channel_sku cs on cs.id = scm.channel_sku_id
join public.sku_master   sm on sm.id = scm.sku_id
where cs.channel = 'smartstore'
  and scm.is_confirmed = false
  and cs.channel_sku_code is not null
order by scm.sku_id, cs.channel_sku_code;
