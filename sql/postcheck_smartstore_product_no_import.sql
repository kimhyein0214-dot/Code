-- =============================================================================
-- postcheck_smartstore_product_no_import.sql
-- Run target : local Docker (product_ops_test_postgres) — apply 이후 검증 전용.
-- Mode       : SELECT-only.
-- 변경(v2)   : stage 단계에 (target_id, code_value) 중복이 있을 수 있으므로
--             STAGE_VS_APPLIED / MISSING_PAIRS / OVERALL 모두 raw row 가 아닌
--             distinct pair 기준으로 비교한다.
-- =============================================================================

-- 1) smartstore productNo 적재 결과
select 'APPLIED_BY_CODE_SYSTEM' as stage,
       code_system,
       count(*)                   as rows,
       count(distinct target_id)  as distinct_sku,
       count(distinct code_value) as distinct_product_no
from product_code.code_alias
where code_system in ('smartstore_product_no','smartstore_product_no_candidate')
group by code_system
order by code_system;

-- 2) staging 대비 적재율 — distinct pair 기준
with stage_distinct as (
  select distinct code_system, target_id, code_value
  from product_code.smartstore_product_no_stage
),
applied_match as (
  select distinct ca.target_id, ca.code_system, ca.code_value
  from product_code.code_alias ca
  where ca.target_type='SKU'
    and ca.code_system in ('smartstore_product_no','smartstore_product_no_candidate')
)
select 'STAGE_VS_APPLIED' as stage,
       sd.code_system,
       count(*)                                              as staged_distinct_pairs,
       count(*) filter (where am.target_id is not null)      as inserted_distinct_pairs,
       count(*) filter (where am.target_id is null)          as missing_distinct_pairs
from stage_distinct sd
left join applied_match am
  on am.target_id   = sd.target_id
 and am.code_system = sd.code_system
 and am.code_value  = sd.code_value
group by sd.code_system
order by sd.code_system;

-- 3) 기존 카운트 (precheck stamp 와 비교 — smartstore_product_* 외에는 변화 없어야 함)
select 'CURRENT_COUNTS' as stage,
       count(*) filter (where code_system='selfpia_sku')                    as selfpia_sku,
       count(*) filter (where code_system='own_sku')                        as own_sku,
       count(*) filter (where code_system='selfpia_product')                as selfpia_product,
       count(*) filter (where code_system ilike 'makeshop%')                as makeshop_total,
       count(*) filter (where code_system='smartstore_option_no')           as smartstore_option_confirmed,
       count(*) filter (where code_system='smartstore_option_no_candidate') as smartstore_option_candidate,
       count(*) filter (where code_system='smartstore_product_no')          as smartstore_product_confirmed,
       count(*) filter (where code_system='smartstore_product_no_candidate') as smartstore_product_candidate,
       count(*)                                                             as total_alias
from product_code.code_alias;

-- 4) 1000-3 SKU smartstore_product_no_* 0 rows 유지
select 'CHK_1000_3' as stage,
       code_system, code_value, is_primary
from product_code.code_alias
where target_id = 'd4c0a5bf-73f1-4203-a6f8-9a27a44f58da'
order by code_system;

-- 5) confirmed 샘플
select 'SAMPLE_CONFIRMED' as stage,
       ca.target_id, sm.virtual_sku_code,
       ca.code_value as smartstore_product_no,
       ca.parsed_part2 as option_no_from_stage
from product_code.code_alias ca
join product_code.sku_master sm on sm.id = ca.target_id
where ca.code_system='smartstore_product_no'
order by ca.target_id
limit 5;

-- 6) candidate 샘플
select 'SAMPLE_CANDIDATE' as stage,
       ca.target_id, sm.virtual_sku_code,
       ca.code_value as smartstore_product_no,
       ca.parsed_part2 as option_no_from_stage
from product_code.code_alias ca
join product_code.sku_master sm on sm.id = ca.target_id
where ca.code_system='smartstore_product_no_candidate'
order by ca.target_id
limit 5;

-- 7) candidate is_primary 위반 — 0 이어야 함
select 'CHK_CANDIDATE_NOT_PRIMARY' as stage,
       count(*) as candidate_primary_violations
from product_code.code_alias
where code_system='smartstore_product_no_candidate'
  and is_primary = true;

-- 8) productNo ↔ optionNo 짝 분포
with paired as (
  select target_id,
         count(*) filter (where code_system='smartstore_option_no')  as option_n,
         count(*) filter (where code_system='smartstore_product_no') as product_n
  from product_code.code_alias
  group by target_id
)
select 'OPTION_PRODUCT_PAIR' as stage,
       count(*) filter (where option_n>0 and product_n>0) as sku_with_both,
       count(*) filter (where option_n>0 and product_n=0) as sku_option_only,
       count(*) filter (where option_n=0 and product_n>0) as sku_product_only
from paired;

-- 9) MISSING_PAIRS — distinct (target_id, code_value) 기준
--    resolvable stage pair 중 code_alias 에 없는 것. 0 이 정상.
--    raw stage row 가 11건 중복이라도 distinct pair 기준이라 missing=0 가능.
with stage_distinct_resolvable as (
  select distinct s.code_system, s.target_id, s.code_value
  from product_code.smartstore_product_no_stage s
  join product_code.sku_master sm on sm.id = s.target_id
)
select 'MISSING_PAIRS' as stage,
       d.code_system,
       count(*) as missing_distinct_pairs
from stage_distinct_resolvable d
where not exists (
  select 1 from product_code.code_alias ca
  where ca.target_type='SKU'
    and ca.target_id   = d.target_id
    and ca.code_system = d.code_system
    and ca.code_value  = d.code_value
)
group by d.code_system
order by d.code_system;

-- 10) OVERALL verdict — distinct pair 기준
with cur as (
  select
    count(*) filter (where code_system='smartstore_product_no')           as applied_confirmed,
    count(*) filter (where code_system='smartstore_product_no_candidate') as applied_candidate
  from product_code.code_alias
),
stg as (
  select
    count(distinct (target_id, code_value)) filter (where code_system='smartstore_product_no')           as stg_distinct_confirmed,
    count(distinct (target_id, code_value)) filter (where code_system='smartstore_product_no_candidate') as stg_distinct_candidate,
    count(*) filter (where code_system='smartstore_product_no')           as stg_raw_confirmed,
    count(*) filter (where code_system='smartstore_product_no_candidate') as stg_raw_candidate
  from product_code.smartstore_product_no_stage
),
stage_distinct_resolvable as (
  select distinct s.code_system, s.target_id, s.code_value
  from product_code.smartstore_product_no_stage s
  join product_code.sku_master sm on sm.id = s.target_id
),
missing as (
  select
    count(*) filter (where d.code_system='smartstore_product_no'           and ca.id is null) as missing_confirmed,
    count(*) filter (where d.code_system='smartstore_product_no_candidate' and ca.id is null) as missing_candidate
  from stage_distinct_resolvable d
  left join product_code.code_alias ca
    on ca.target_type='SKU'
   and ca.target_id   = d.target_id
   and ca.code_system = d.code_system
   and ca.code_value  = d.code_value
),
prim as (
  select count(*) as candidate_primary_violations
  from product_code.code_alias
  where code_system='smartstore_product_no_candidate'
    and is_primary = true
),
chk_1000_3 as (
  select count(*) as smartstore_rows
  from product_code.code_alias
  where target_id = 'd4c0a5bf-73f1-4203-a6f8-9a27a44f58da'
    and code_system in ('smartstore_product_no','smartstore_product_no_candidate')
)
select 'OVERALL' as stage,
       case
         when m.missing_confirmed <> 0           then 'FAIL: confirmed distinct pairs not fully applied'
         when m.missing_candidate <> 0           then 'FAIL: candidate distinct pairs not fully applied'
         when p.candidate_primary_violations <> 0 then 'FAIL: candidate has is_primary=true'
         when t.smartstore_rows <> 0              then 'FAIL: 1000-3 has smartstore_product_*'
         else 'PASS'
       end as verdict,
       c.applied_confirmed,
       s.stg_distinct_confirmed   as stage_distinct_confirmed,
       s.stg_raw_confirmed        as stage_raw_confirmed,
       c.applied_candidate,
       s.stg_distinct_candidate   as stage_distinct_candidate,
       s.stg_raw_candidate        as stage_raw_candidate,
       m.missing_confirmed,
       m.missing_candidate,
       p.candidate_primary_violations,
       t.smartstore_rows          as sku_1000_3_smartstore_product_rows
from cur c cross join stg s cross join missing m cross join prim p cross join chk_1000_3 t;
