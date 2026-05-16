-- =============================================================================
-- diagnose_smartstore_product_code_source.sql
-- Run target  : 운영 Supabase Product_code (project_id=mrqoqmidnrawflwezxlm)
-- Schema      : public  (운영은 product_code 스키마가 아니라 public)
-- Mode        : SELECT-only. INSERT/UPDATE/DELETE/DDL 금지.
-- 목적        : Smartstore productNo / 상품번호가 운영에 존재하는지 확인.
--               존재하면 local code_alias 에 smartstore_product_no(_candidate) 로
--               import 할 수 있도록 컬럼 매핑을 결정.
--
-- 각 SELECT 는 Supabase SQL Editor 에서 개별 실행 가능 (### 으로 구분).
-- =============================================================================


-- ### 1) channel_product 테이블의 컬럼 후보 확인
--     기대: channel_product_code (= 스마트스토어 상품번호 / productNo, 11자리)
--           channel_product_code_raw (원본 동일값)
--           seller_product_code_raw  (판매자 상품코드 = 셀피아 상품코드)
--           raw_payload / raw_data    (jsonb 원본)
select column_name, data_type
from information_schema.columns
where table_schema='public' and table_name='channel_product'
order by ordinal_position;


-- ### 2) channel_sku 의 productNo 관련 컬럼 (이미 옵션번호용 컬럼 외)
select column_name, data_type
from information_schema.columns
where table_schema='public' and table_name='channel_sku'
  and (column_name ilike '%product%'
    or column_name ilike '%origin%'
    or column_name ilike '%payload%'
    or column_name ilike '%raw%'
    or column_name='extra'
    or column_name='memo')
order by ordinal_position;


-- ### 3) smartstore channel_product 행 sample (20건)
select id, channel_product_code, channel_product_code_raw,
       seller_product_code_raw, channel_product_name,
       (raw_data is not null) as has_raw_data,
       (raw_payload is not null) as has_raw_payload
from public.channel_product
where channel='smartstore'
order by channel_product_code
limit 20;


-- ### 4) confirmed smartstore 매핑의 SKU → channel_product_code 결합 sample
--     기대: 각 SKU 에 대응하는 11자리 productNo 가 노출됨.
select cp.channel_product_code            as smartstore_product_no,
       cp.channel_product_code_raw        as smartstore_product_no_raw,
       cp.seller_product_code_raw         as seller_product_code,
       cs.channel_sku_code                as smartstore_option_no,
       cs.channel_option_id,
       scm.sku_id                         as internal_sku_id,
       sm.virtual_sku_code,
       scm.is_confirmed,
       scm.decision_status
from public.sku_channel_mapping scm
join public.channel_sku     cs on cs.id = scm.channel_sku_id
join public.channel_product cp on cp.id = cs.channel_product_id
join public.sku_master      sm on sm.id = scm.sku_id
where cs.channel='smartstore'
  and scm.is_confirmed = true
order by cp.channel_product_code, cs.channel_sku_code
limit 20;


-- ### 5) candidate (is_confirmed=false) 매핑도 동일 검증
select cp.channel_product_code            as smartstore_product_no,
       cs.channel_sku_code                as smartstore_option_no,
       scm.sku_id                         as internal_sku_id,
       sm.virtual_sku_code,
       scm.is_confirmed,
       scm.decision_status
from public.sku_channel_mapping scm
join public.channel_sku     cs on cs.id = scm.channel_sku_id
join public.channel_product cp on cp.id = cs.channel_product_id
join public.sku_master      sm on sm.id = scm.sku_id
where cs.channel='smartstore'
  and scm.is_confirmed = false
order by cp.channel_product_code, cs.channel_sku_code
limit 20;


-- ### 6) channel_product_code 커버리지
--     - confirmed 매핑에 대해 channel_product_code 가 모두 not null 인지
--     - distinct 개수 (한 상품번호에 여러 옵션이 묶임)
select 'confirmed' as bucket,
       count(*)                                              as rows,
       count(*) filter (where cp.channel_product_code is not null) as has_pno,
       count(distinct cp.channel_product_code)               as distinct_pno
from public.sku_channel_mapping scm
join public.channel_sku     cs on cs.id = scm.channel_sku_id
join public.channel_product cp on cp.id = cs.channel_product_id
where cs.channel='smartstore' and scm.is_confirmed=true
union all
select 'candidate' as bucket,
       count(*),
       count(*) filter (where cp.channel_product_code is not null),
       count(distinct cp.channel_product_code)
from public.sku_channel_mapping scm
join public.channel_sku     cs on cs.id = scm.channel_sku_id
join public.channel_product cp on cp.id = cs.channel_product_id
where cs.channel='smartstore' and scm.is_confirmed=false;


-- ### 7) raw_payload 안에 productNo / originProductNo 키가 존재하는지 (JSON 키 점검)
--     2026-05-15 기준 raw_payload 는 한국어 헤더 dict 이므로 productNo 키는 없음.
--     번역키 후보를 한 번 더 점검해 두는 sanity check.
select key as raw_payload_top_level_key, count(*) as occurrences
from public.channel_product,
     lateral jsonb_object_keys(raw_payload) as t(key)
where channel='smartstore'
  and (key ilike '%product%no%'
    or key ilike '%product%id%'
    or key ilike '%origin%product%'
    or key ilike '%상품번호%'
    or key ilike '%상품아이디%')
group by key
order by occurrences desc;


-- ### 8) channel_sku 의 raw_payload / raw_data 에 productNo 키가 있는지
select key as channel_sku_raw_key, count(*) as occurrences
from public.channel_sku,
     lateral jsonb_object_keys(coalesce(raw_payload, raw_data)) as t(key)
where channel='smartstore'
  and (key ilike '%product%no%'
    or key ilike '%product%id%'
    or key ilike '%origin%product%'
    or key ilike '%상품번호%'
    or key ilike '%상품아이디%')
group by key
order by occurrences desc;


-- ### 9) (export 미리보기) 만약 smartstore_product_no alias 를 local 에 import 한다면
--     아래 SELECT 결과가 staging CSV 의 정본이 될 수 있음.
--     본 진단 SQL 에서는 실행 결과를 메모만 하고, 실제 export 는 별도 파일에서 진행.
select
  'SKU'::text                              as target_type,
  scm.sku_id                               as target_id,
  case when scm.is_confirmed
       then 'smartstore_product_no'::text
       else 'smartstore_product_no_candidate'::text
  end                                      as code_system,
  cp.channel_product_code                  as code_value,
  cp.channel_product_code_raw              as parsed_part1,
  cp.channel_product_name                  as parsed_part2,
  cp.seller_product_code_raw               as selfpia_product_code,
  null::text                               as selfpia_option_no,
  false                                    as is_primary,
  scm.is_confirmed                         as memo_is_confirmed,
  scm.decision_status                      as memo_decision_status,
  sm.virtual_sku_code                      as memo_vsku
from public.sku_channel_mapping scm
join public.channel_sku     cs on cs.id = scm.channel_sku_id
join public.channel_product cp on cp.id = cs.channel_product_id
join public.sku_master      sm on sm.id = scm.sku_id
where cs.channel='smartstore'
  and cp.channel_product_code is not null
order by scm.is_confirmed desc, cp.channel_product_code, cs.channel_sku_code
limit 30;
