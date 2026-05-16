-- =============================================================================
-- Supabase SELECT-only export
-- Purpose: 운영 Supabase Product_code 의 스마트스토어 productNo(상품번호)를
--          local Docker product_ops_test 의 product_code.code_alias 에
--          smartstore_product_no / smartstore_product_no_candidate 로 import 하기 위한 CSV export.
--
-- Run target  : Supabase Product_code (project_id=mrqoqmidnrawflwezxlm)
-- Schema      : public
-- Mode        : SELECT-only. INSERT/UPDATE/DELETE/DDL 금지.
-- Output files:
--   exports/smartstore_product_no_alias.csv             (confirmed, 약 908 rows)
--   exports/smartstore_product_no_alias_candidates.csv  (candidate, 약 11,691 rows)
--
-- 데이터 경로:
--   sku_master ← sku_channel_mapping → channel_sku → channel_product
--   productNo 는 public.channel_product.channel_product_code (11자리 숫자)
--
-- 정책:
--   * confirmed (is_confirmed=true, decision_status='confirmed') →
--     code_system='smartstore_product_no'
--   * candidate (is_confirmed=false, decision_status='auto_candidate') →
--     code_system='smartstore_product_no_candidate'
--   * 운영 Supabase 의 is_confirmed / decision_status 값은 절대 변경하지 않는다.
--   * memo 안에 optionNo(channel_sku_code)와 channel_product_name 동봉해
--     productNo↔optionNo 추적 가능하게 유지.
-- =============================================================================


-- ### 1) confirmed export — exports/smartstore_product_no_alias.csv
select
  'SKU'::text                              as target_type,
  scm.sku_id                               as target_id,
  'smartstore_product_no'::text            as code_system,
  cp.channel_product_code                  as code_value,
  cp.channel_product_code_raw              as parsed_part1,
  cs.channel_sku_code                      as parsed_part2,   -- optionNo (추적용)
  cp.seller_product_code_raw               as selfpia_product_code,
  null::text                               as selfpia_option_no,
  false                                    as is_primary,
  cs.channel                               as memo_channel,
  scm.match_stage                          as memo_match_stage,
  scm.confidence                           as memo_confidence,
  scm.decision_status                      as memo_decision_status,
  scm.is_confirmed                         as memo_is_confirmed,
  sm.virtual_sku_code                      as memo_vsku,
  cs.channel_sku_code                      as memo_option_no,
  cp.channel_product_name                  as memo_product_name
from public.sku_channel_mapping scm
join public.channel_sku     cs on cs.id = scm.channel_sku_id
join public.channel_product cp on cp.id = cs.channel_product_id
join public.sku_master      sm on sm.id = scm.sku_id
where cs.channel = 'smartstore'
  and scm.is_confirmed = true
  and cp.channel_product_code is not null
order by scm.sku_id, cp.channel_product_code;


-- ### 2) candidate export — exports/smartstore_product_no_alias_candidates.csv
-- IMPORTANT: Supabase SQL Editor 에서 1번과 따로 실행해 두 개의 CSV 로 다운로드.
select
  'SKU'::text                              as target_type,
  scm.sku_id                               as target_id,
  'smartstore_product_no_candidate'::text  as code_system,
  cp.channel_product_code                  as code_value,
  cp.channel_product_code_raw              as parsed_part1,
  cs.channel_sku_code                      as parsed_part2,
  cp.seller_product_code_raw               as selfpia_product_code,
  null::text                               as selfpia_option_no,
  false                                    as is_primary,
  cs.channel                               as memo_channel,
  scm.match_stage                          as memo_match_stage,
  scm.confidence                           as memo_confidence,
  scm.decision_status                      as memo_decision_status,
  scm.is_confirmed                         as memo_is_confirmed,
  sm.virtual_sku_code                      as memo_vsku,
  cs.channel_sku_code                      as memo_option_no,
  cp.channel_product_name                  as memo_product_name
from public.sku_channel_mapping scm
join public.channel_sku     cs on cs.id = scm.channel_sku_id
join public.channel_product cp on cp.id = cs.channel_product_id
join public.sku_master      sm on sm.id = scm.sku_id
where cs.channel = 'smartstore'
  and scm.is_confirmed = false
  and cp.channel_product_code is not null
order by scm.sku_id, cp.channel_product_code;
