-- =============================================================================
-- postcheck_smartstore_alias_import.sql
-- Run target : local Docker (product_ops_test_postgres) — apply 이후 검증 전용.
-- Mode       : SELECT-only. apply SQL 은 별도 작성 필요. 본 파일은 그대로 사용.
-- 전제       : 사용자 승인 후 apply SQL 로 commit 완료된 상태에서 실행.
--             (dryrun 직후 실행하면 ROLLBACK 이라 smartstore_* 0 rows 가 정상)
-- 라벨       : dryrun 과 동일하게 stage 컬럼으로 구분.
-- =============================================================================

-- 1) smartstore 적재 결과 (confirmed / candidate 분리)
select 'APPLIED_BY_CODE_SYSTEM' as stage,
       code_system,
       count(*)                  as rows,
       count(distinct target_id) as distinct_sku,
       count(distinct code_value) as distinct_code
from product_code.code_alias
where code_system in ('smartstore_option_no','smartstore_option_no_candidate')
group by code_system
order by code_system;

-- 2) staging 대비 적재율 (apply 후 100% 가 정상; dryrun 직후엔 0%)
select 'STAGE_VS_APPLIED' as stage,
       s.code_system,
       count(distinct s.target_id || '|' || s.code_value)  as staged_pairs,
       count(distinct ca.target_id || '|' || ca.code_value) as inserted_pairs
from product_code.smartstore_option_no_stage s
left join product_code.code_alias ca
  on ca.target_type = 'SKU'
 and ca.target_id   = s.target_id
 and ca.code_system = s.code_system
 and ca.code_value  = s.code_value
group by s.code_system
order by s.code_system;

-- 3) 기존 카운트 (precheck stamp 와 비교)
select 'CURRENT_COUNTS' as stage,
       count(*) filter (where code_system='selfpia_sku')                    as selfpia_sku,
       count(*) filter (where code_system='own_sku')                        as own_sku,
       count(*) filter (where code_system='selfpia_product')                as selfpia_product,
       count(*) filter (where code_system ilike 'makeshop%')                as makeshop_total,
       count(*) filter (where code_system='smartstore_option_no')           as smartstore_confirmed,
       count(*) filter (where code_system='smartstore_option_no_candidate') as smartstore_candidate,
       count(*)                                                             as total_alias
from product_code.code_alias;

-- 4) 1000-3 SKU smartstore_* 0건 유지 검증
select 'CHK_1000_3' as stage,
       code_system, code_value, is_primary
from product_code.code_alias
where target_id = 'd4c0a5bf-73f1-4203-a6f8-9a27a44f58da'
order by code_system;

-- 5) confirmed 샘플 — 프론트 "스마트스토어" 노출용
select 'SAMPLE_CONFIRMED' as stage,
       ca.target_id, sm.virtual_sku_code, ca.code_value, ca.parsed_part2 as option_text
from product_code.code_alias ca
join product_code.sku_master sm on sm.id = ca.target_id
where ca.code_system='smartstore_option_no'
order by ca.target_id
limit 5;

-- 6) candidate 샘플 — 프론트 "스마트스토어 후보" 노출용
select 'SAMPLE_CANDIDATE' as stage,
       ca.target_id, sm.virtual_sku_code, ca.code_value, ca.parsed_part2 as option_text
from product_code.code_alias ca
join product_code.sku_master sm on sm.id = ca.target_id
where ca.code_system='smartstore_option_no_candidate'
order by ca.target_id
limit 5;

-- 7) is_primary 위반 검증 — candidate 는 모두 false 여야 함
select 'CHK_CANDIDATE_NOT_PRIMARY' as stage,
       count(*) as candidate_primary_violations
from product_code.code_alias
where code_system='smartstore_option_no_candidate'
  and is_primary = true;

-- 8) v_sku_canonical 노출 (frontend 표시 진단)
select 'VIEW_SAMPLE' as stage, v.*
from product_code.v_sku_canonical v
where v.sku_id in (
  select target_id from product_code.code_alias
  where code_system='smartstore_option_no'
  order by target_id
  limit 5
);

-- 9) MISSING_PAIRS — staging 의 resolvable row 중 code_alias 에 들어가지 않은 건수
--    0 이 정상. > 0 이면 apply 가 누락된 stage row 가 있다는 뜻.
select 'MISSING_PAIRS' as stage,
       s.code_system,
       count(*) as missing_pairs
from product_code.smartstore_option_no_stage s
join product_code.sku_master sm on sm.id = s.target_id
where not exists (
  select 1 from product_code.code_alias ca
  where ca.target_type = 'SKU'
    and ca.target_id   = s.target_id
    and ca.code_system = s.code_system
    and ca.code_value  = s.code_value
)
group by s.code_system
order by s.code_system;

-- 10) OVERALL verdict (apply 후 기대값 충족 여부)
-- 핵심 기준 : staging 의 resolvable row 가 모두 code_alias 에 존재해야 함.
-- (baseline 에 사전 smartstore alias 가 있어도 NOT EXISTS dedup 로 자연 처리되므로
--  equality 가 아니라 missing_pairs = 0 으로 검증)
with cur as (
  select
    count(*) filter (where code_system='smartstore_option_no')           as smartstore_confirmed,
    count(*) filter (where code_system='smartstore_option_no_candidate') as smartstore_candidate
  from product_code.code_alias
),
stg as (
  select
    count(distinct (target_id || '|' || code_value)) filter (where code_system='smartstore_option_no')           as stg_confirmed,
    count(distinct (target_id || '|' || code_value)) filter (where code_system='smartstore_option_no_candidate') as stg_candidate
  from product_code.smartstore_option_no_stage
),
missing as (
  select count(*) as missing_pairs
  from product_code.smartstore_option_no_stage s
  join product_code.sku_master sm on sm.id = s.target_id
  where not exists (
    select 1 from product_code.code_alias ca
    where ca.target_type = 'SKU'
      and ca.target_id   = s.target_id
      and ca.code_system = s.code_system
      and ca.code_value  = s.code_value
  )
),
prim as (
  select count(*) as candidate_primary_violations
  from product_code.code_alias
  where code_system='smartstore_option_no_candidate'
    and is_primary = true
),
chk_1000_3 as (
  select count(*) as smartstore_rows
  from product_code.code_alias
  where target_id = 'd4c0a5bf-73f1-4203-a6f8-9a27a44f58da'
    and code_system in ('smartstore_option_no','smartstore_option_no_candidate')
)
select 'OVERALL' as stage,
       case
         when m.missing_pairs <> 0                then 'FAIL: stage rows not fully applied'
         when p.candidate_primary_violations <> 0 then 'FAIL: candidate has is_primary=true'
         when t.smartstore_rows <> 0              then 'FAIL: 1000-3 has smartstore alias'
         else 'PASS'
       end as verdict,
       c.smartstore_confirmed                    as applied_confirmed,
       s.stg_confirmed                            as stage_confirmed,
       c.smartstore_candidate                    as applied_candidate,
       s.stg_candidate                            as stage_candidate,
       m.missing_pairs,
       p.candidate_primary_violations,
       t.smartstore_rows                          as sku_1000_3_smartstore_rows
from cur c cross join stg s cross join missing m cross join prim p cross join chk_1000_3 t;
