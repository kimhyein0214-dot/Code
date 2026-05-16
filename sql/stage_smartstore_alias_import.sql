-- =============================================================================
-- stage_smartstore_alias_import.sql
-- Run target : local Docker (product_ops_test_postgres 컨테이너 내부 psql)
-- Mode       : DDL + server-side COPY. 운영 Supabase 실행 금지.
-- 사전조건   :
--   docker cp exports/smartstore_option_no_alias.csv             product_ops_test_postgres:/tmp/smartstore_option_no_alias.csv
--   docker cp exports/smartstore_option_no_alias_candidates.csv  product_ops_test_postgres:/tmp/smartstore_option_no_alias_candidates.csv
-- 실행:
--   docker exec -i product_ops_test_postgres psql -U postgres -d product_ops_test \
--     -v ON_ERROR_STOP=1 -f /tmp/stage_smartstore_alias_import.sql
-- =============================================================================

-- 1) staging 테이블 (재실행 안전)
drop table if exists product_code.smartstore_option_no_stage;

create table product_code.smartstore_option_no_stage (
  target_type            text,
  target_id              uuid,
  code_system            text,    -- 'smartstore_option_no' 또는 'smartstore_option_no_candidate'
  code_value             text,
  parsed_part1           text,
  parsed_part2           text,
  selfpia_product_code   text,
  selfpia_option_no      text,
  is_primary             boolean,
  memo_channel           text,
  memo_match_stage       text,
  memo_confidence        numeric,
  memo_decision_status   text,
  memo_is_confirmed      boolean,
  memo_vsku              text
);

-- 2) Server-side COPY (컨테이너 내부 /tmp 경로)
copy product_code.smartstore_option_no_stage
  from '/tmp/smartstore_option_no_alias.csv'
  with (format csv, header true);

copy product_code.smartstore_option_no_stage
  from '/tmp/smartstore_option_no_alias_candidates.csv'
  with (format csv, header true);

-- 3) 적재 합계 (기대: confirmed 약 908 + candidate 약 11,691)
select 'STAGED_TOTAL' as stage,
       count(*) as total_rows
from product_code.smartstore_option_no_stage;

select 'STAGED_BY_CODE_SYSTEM' as stage,
       code_system,
       count(*) as staged_rows,
       count(distinct target_id) as distinct_sku,
       count(distinct code_value) as distinct_code,
       count(*) filter (where target_id is null)  as null_target,
       count(*) filter (where code_value is null) as null_code
from product_code.smartstore_option_no_stage
group by code_system
order by code_system;

-- 4) target_id 해상도 (sku_master 와 매칭되는지)
select 'TARGET_ID_RESOLUTION' as stage,
       s.code_system,
       count(*) as total,
       count(*) filter (where sm.id is not null) as resolvable,
       count(*) filter (where sm.id is null)     as unresolved
from product_code.smartstore_option_no_stage s
left join product_code.sku_master sm on sm.id = s.target_id
group by s.code_system
order by s.code_system;

-- 5) 미매칭 샘플 (조사용)
select 'UNRESOLVED_SAMPLE' as stage,
       s.code_system, s.target_id, s.code_value, s.memo_vsku, s.memo_match_stage
from product_code.smartstore_option_no_stage s
left join product_code.sku_master sm on sm.id = s.target_id
where sm.id is null
order by s.code_system, s.target_id
limit 50;

-- 6) staging 내부 중복 (같은 code_system + target_id + code_value)
select 'STAGE_DUPLICATE' as stage,
       code_system, target_id, code_value, count(*) as dup_count
from product_code.smartstore_option_no_stage
group by code_system, target_id, code_value
having count(*) > 1
order by dup_count desc, target_id
limit 50;

-- 7) confirmed vs candidate 코드 충돌 (같은 code_value 가 양쪽에 있는지)
select 'CONFIRMED_CANDIDATE_OVERLAP' as stage,
       code_value,
       count(*) filter (where code_system='smartstore_option_no')           as confirmed_cnt,
       count(*) filter (where code_system='smartstore_option_no_candidate') as candidate_cnt
from product_code.smartstore_option_no_stage
group by code_value
having count(distinct code_system) > 1
order by code_value
limit 50;

-- 8) 본 테이블과의 사전 충돌 검사 (target_type='SKU' 기준)
select 'PRE_EXISTING_CONFLICT' as stage,
       s.code_system,
       count(*) as conflict_rows
from product_code.smartstore_option_no_stage s
join product_code.code_alias ca
  on ca.target_type = 'SKU'
 and ca.target_id   = s.target_id
 and ca.code_system = s.code_system
 and ca.code_value  = s.code_value
group by s.code_system
order by s.code_system;

-- 9) 한 SKU 에 confirmed + candidate 가 동시에 붙는 케이스 (정상 가능)
with per_sku as (
  select target_id,
         count(*) filter (where code_system='smartstore_option_no')           as confirmed_n,
         count(*) filter (where code_system='smartstore_option_no_candidate') as candidate_n
  from product_code.smartstore_option_no_stage
  group by target_id
)
select 'PER_SKU_DISTRIBUTION' as stage,
       count(*) filter (where confirmed_n>0 and candidate_n>0) as sku_with_both,
       count(*) filter (where confirmed_n>0 and candidate_n=0) as sku_confirmed_only,
       count(*) filter (where confirmed_n=0 and candidate_n>0) as sku_candidate_only,
       max(confirmed_n) as max_confirmed_per_sku,
       max(candidate_n) as max_candidate_per_sku
from per_sku;
