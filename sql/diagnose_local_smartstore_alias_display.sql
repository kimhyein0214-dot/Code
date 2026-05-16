-- =============================================================================
-- diagnose_local_smartstore_alias_display.sql
-- Run target : local Docker (product_ops_test_postgres) — SELECT-only
-- 목적       : 프론트 "연결 채널" 카드가 Smartstore 를 인식하지 못하는 원인 진단.
--             smartstore_* alias 와 sku_channel_mapping 분포, 그리고 productNo
--             계열 code_system 이 이미 적재되어 있는지 점검.
-- 실행:
--   docker cp sql/diagnose_local_smartstore_alias_display.sql product_ops_test_postgres:/tmp/diagnose_local_smartstore_alias_display.sql
--   docker exec -i product_ops_test_postgres psql -U product_ops_tester -d product_ops_test \
--     -v ON_ERROR_STOP=1 -f /tmp/diagnose_local_smartstore_alias_display.sql
-- =============================================================================


-- 1) smartstore 관련 code_alias 카운트
select 'ALIAS_COUNT' as stage,
       code_system,
       count(*)                  as rows,
       count(distinct target_id) as distinct_sku,
       count(distinct code_value) as distinct_code
from product_code.code_alias
where code_system ilike '%smart%'
   or code_system ilike '%naver%'
group by code_system
order by code_system;


-- 2) smartstore productNo 계열 alias 가 이미 있는지 (apply 이후에도 보통 0)
select 'PRODUCT_NO_ALIAS_EXISTS' as stage,
       code_system, count(*) as rows
from product_code.code_alias
where code_system in (
  'smartstore_product_no',
  'smartstore_product_no_candidate',
  'smartstore_product_code',
  'smartstore_origin_product_no'
)
group by code_system
order by code_system;


-- 3) sku_channel_mapping 의 채널 분포 (현재 makeshop 만 있을 것)
select 'CHANNEL_MAPPING_DISTRIBUTION' as stage,
       channel_code,
       count(*)                   as rows,
       count(distinct sku_id)     as distinct_sku
from product_code.sku_channel_mapping
group by channel_code
order by channel_code;


-- 4) 확인 대상 SKU 들 (selfpia_sku 기준)
with target_sku as (
  select code_value as selfpia_sku, target_id as sku_id
  from product_code.code_alias
  where code_system='selfpia_sku'
    and code_value in ('10310-238','11008-15','11188-1','5275-1','1678-2','1000-3')
)
select 'TARGET_SKU_LOOKUP' as stage,
       t.selfpia_sku, t.sku_id, sm.virtual_sku_code, sm.option_value
from target_sku t
join product_code.sku_master sm on sm.id = t.sku_id
order by t.selfpia_sku;


-- 5) 각 확인 SKU 의 alias 분포 (smartstore 표시 여부)
with target_sku as (
  select code_value as selfpia_sku, target_id as sku_id
  from product_code.code_alias
  where code_system='selfpia_sku'
    and code_value in ('10310-238','11008-15','11188-1','5275-1','1678-2','1000-3')
)
select 'TARGET_SKU_ALIAS' as stage,
       t.selfpia_sku,
       ca.code_system,
       ca.code_value,
       ca.is_primary
from target_sku t
join product_code.code_alias ca
  on ca.target_type='SKU' and ca.target_id = t.sku_id
order by t.selfpia_sku, ca.code_system, ca.code_value;


-- 6) 각 확인 SKU 의 channel mapping (makeshop / smartstore 등)
with target_sku as (
  select code_value as selfpia_sku, target_id as sku_id
  from product_code.code_alias
  where code_system='selfpia_sku'
    and code_value in ('10310-238','11008-15','11188-1','5275-1','1678-2','1000-3')
)
select 'TARGET_SKU_MAPPING' as stage,
       t.selfpia_sku,
       scm.channel_code,
       scm.channel_sku_code,
       scm.seller_product_code,
       scm.own_sku_code,
       scm.is_primary
from target_sku t
left join product_code.sku_channel_mapping scm
  on scm.sku_id = t.sku_id
order by t.selfpia_sku, scm.channel_code;


-- 7) 1000-3 SKU smartstore_* 0건 유지 검증
select 'CHK_1000_3' as stage,
       code_system, count(*) as rows
from product_code.code_alias
where target_id = 'd4c0a5bf-73f1-4203-a6f8-9a27a44f58da'
  and (code_system ilike '%smart%' or code_system ilike '%naver%')
group by code_system
order by code_system;


-- 8) API repository.js 가 사용하는 view (product_code.v_sku_canonical) 가
--    aliases 를 join 하지 않고 그대로 노출하는지 sanity check.
--    실제 API 흐름:
--      service.getSkuDetail()
--        → repository.getSkuById()            → v_sku_canonical 단일행
--        → repository.listAliasesBySkuId()    → code_alias 별도 호출 (smartstore_option_no 포함)
--        → repository.listChannelMappingsBySkuId() → sku_channel_mapping (smartstore 0건)
--    => 프론트 buildConnectionSummary 에서 mappings 만 보고 카운트하므로
--       smartstore alias 가 카드에 안 보임. 본 진단 SQL 은 이 가설을 검증하기 위한 메모.
select 'V_SKU_CANONICAL_COLUMNS' as stage,
       column_name, data_type
from information_schema.columns
where table_schema='product_code' and table_name='v_sku_canonical'
order by ordinal_position;
