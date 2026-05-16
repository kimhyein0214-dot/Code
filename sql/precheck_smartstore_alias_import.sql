-- =============================================================================
-- precheck_smartstore_alias_import.sql
-- Run target : local Docker product_ops_test
-- Mode       : SELECT-only. 어떤 변경도 하지 않음.
-- 목적       : import 전에 현재 local 상태 진단.
--   * code_alias 의 code_system 분포
--   * smartstore_* 잔존물 여부 (smartstore_option_no, smartstore_option_no_candidate 둘 다)
--   * sku_master 카운트
--   * staging 테이블 존재 여부
-- =============================================================================

-- 0) staging 테이블 존재 여부
select
  to_regclass('product_code.smartstore_option_no_stage') as stage_relation;

-- 1) code_alias code_system 분포
select code_system, count(*) as rows,
       count(distinct code_value) as distinct_value,
       count(distinct target_id)  as distinct_target_id
from product_code.code_alias
group by code_system
order by code_system;

-- 2) smartstore 관련 alias 잔존 여부
--    기대값: smartstore_option_no, smartstore_option_no_candidate 모두 0 또는 매우 적음
select code_system, count(*) as rows
from product_code.code_alias
where code_system ilike '%smart%'
   or code_system ilike '%store%'
   or code_system ilike '%naver%'
group by code_system
order by code_system;

-- 3) 핵심 카운트 stamp (apply 후 postcheck 와 비교용 — 메모해 둘 것)
select
  count(*) filter (where code_system='selfpia_sku')                    as selfpia_sku,
  count(*) filter (where code_system='own_sku')                        as own_sku,
  count(*) filter (where code_system='selfpia_product')                as selfpia_product,
  count(*) filter (where code_system ilike 'makeshop%')                as makeshop_total,
  count(*) filter (where code_system='smartstore_option_no')           as smartstore_confirmed,
  count(*) filter (where code_system='smartstore_option_no_candidate') as smartstore_candidate,
  count(*)                                                             as total_alias
from product_code.code_alias;

-- 4) sku_master 행수 (target_id 해상도 베이스)
select count(*) as sku_master_rows from product_code.sku_master;

-- 5) 예시 SKU 1000-3 의 현재 alias (smartstore 0건이어야 함)
select code_system, code_value, is_primary
from product_code.code_alias
where target_id = 'd4c0a5bf-73f1-4203-a6f8-9a27a44f58da'
order by code_system;
