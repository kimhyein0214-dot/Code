-- =============================================================================
-- dryrun_smartstore_product_no_import.sql
-- Run target : local Docker (product_ops_test_postgres)
-- Mode       : BEGIN ... ROLLBACK. 절대 COMMIT 하지 않음.
-- 전제       : stage_smartstore_product_no_import.sql 로 staging 적재 완료.
--
-- 변경(v2)   :
--   * productNo 는 한 SKU 가 여러 channel_sku option 을 통해 같은 channel_product
--     (=같은 productNo) 에 연결될 수 있어 stage 단계에서 (target_id, code_system,
--     code_value) 중복이 정상적으로 발생.
--   * local code_alias 에는 UNIQUE (code_system, code_value, target_type, target_id)
--     제약이 실제로 존재 → NOT EXISTS 만으로는 같은 INSERT 안의 중복 행을 못 막음.
--   * 해결: INSERT source 에서 DISTINCT ON (target_id, code_system, code_value)
--     로 사전 dedupe + NOT EXISTS 가드 유지. ON CONFLICT 는 쓰지 않음.
--   * OVERALL PASS 기준을 stage raw rows 가 아니라 distinct pair 기준으로 변경.
-- =============================================================================

-- 0) baseline stamp (autocommit, ROLLBACK 영향 없음)
drop table if exists _dryrun_baseline;
create temp table _dryrun_baseline as
select
  count(*) filter (where code_system='smartstore_product_no')           as smartstore_product_confirmed,
  count(*) filter (where code_system='smartstore_product_no_candidate') as smartstore_product_candidate,
  count(*) filter (where code_system='smartstore_option_no')            as smartstore_option_confirmed,
  count(*) filter (where code_system='smartstore_option_no_candidate')  as smartstore_option_candidate,
  count(*) filter (where code_system='selfpia_sku')                     as selfpia_sku,
  count(*) filter (where code_system='own_sku')                         as own_sku,
  count(*) filter (where code_system='selfpia_product')                 as selfpia_product,
  count(*) filter (where code_system ilike 'makeshop%')                 as makeshop_total,
  count(*)                                                              as total_alias
from product_code.code_alias;

select 'BASELINE' as stage, * from _dryrun_baseline;

-- 0-a) STAGE_ROWS — raw count
select 'STAGE_ROWS' as stage,
       code_system,
       count(*) as raw_rows
from product_code.smartstore_product_no_stage
group by code_system
order by code_system;

-- 0-b) STAGE_DISTINCT_PAIRS — (target_id, code_value) distinct count
--      INSERT 가 실제로 시도할 대상 수 (NOT EXISTS 가드 전).
select 'STAGE_DISTINCT_PAIRS' as stage,
       code_system,
       count(distinct (target_id, code_value)) as distinct_pairs
from product_code.smartstore_product_no_stage
group by code_system
order by code_system;

begin;

-- 1) BEFORE
select 'BEFORE' as stage,
       count(*) filter (where code_system='smartstore_product_no')           as smartstore_product_confirmed,
       count(*) filter (where code_system='smartstore_product_no_candidate') as smartstore_product_candidate,
       count(*) filter (where code_system='smartstore_option_no')            as smartstore_option_confirmed,
       count(*) filter (where code_system='smartstore_option_no_candidate')  as smartstore_option_candidate,
       count(*) filter (where code_system='selfpia_sku')                     as selfpia_sku,
       count(*) filter (where code_system='own_sku')                         as own_sku,
       count(*) filter (where code_system='selfpia_product')                 as selfpia_product,
       count(*) filter (where code_system ilike 'makeshop%')                 as makeshop_total,
       count(*)                                                              as total_alias
from product_code.code_alias;

-- 2) confirmed INSERT — DISTINCT ON dedupe + NOT EXISTS 가드
with dedupe_confirmed as (
  select distinct on (s.target_id, s.code_value)
    s.target_id, s.code_value,
    s.parsed_part1, s.parsed_part2,
    s.selfpia_product_code, s.selfpia_option_no,
    s.is_primary,
    s.memo_channel, s.memo_match_stage, s.memo_confidence,
    s.memo_decision_status, s.memo_vsku, s.memo_option_no, s.memo_product_name
  from product_code.smartstore_product_no_stage s
  where s.code_system = 'smartstore_product_no'
  order by s.target_id, s.code_value,
           s.memo_option_no nulls last,
           s.memo_vsku       nulls last
),
ins_confirmed as (
  insert into product_code.code_alias (
    target_type, target_id, code_system, code_value,
    parsed_part1, parsed_part2,
    selfpia_product_code, selfpia_option_no,
    is_primary, memo
  )
  select
    'SKU',
    d.target_id,
    'smartstore_product_no',
    d.code_value,
    d.parsed_part1,
    d.parsed_part2,
    d.selfpia_product_code,
    d.selfpia_option_no,
    coalesce(d.is_primary, false),
    concat_ws('|',
      'src=supabase_sku_channel_mapping',
      'channel=' || d.memo_channel,
      'stage=' || d.memo_match_stage,
      'conf=' || d.memo_confidence::text,
      'decision=' || d.memo_decision_status,
      'vsku=' || d.memo_vsku,
      'optionNo=' || d.memo_option_no,
      'productName=' || d.memo_product_name
    )
  from dedupe_confirmed d
  join product_code.sku_master sm on sm.id = d.target_id
  where not exists (
    select 1 from product_code.code_alias ca
    where ca.target_type = 'SKU'
      and ca.target_id   = d.target_id
      and ca.code_system = 'smartstore_product_no'
      and ca.code_value  = d.code_value
  )
  returning 1
)
select 'INSERTED_CONFIRMED' as stage, count(*) as rows from ins_confirmed;

-- 3) candidate INSERT — DISTINCT ON dedupe + NOT EXISTS + is_primary=false 강제
with dedupe_candidate as (
  select distinct on (s.target_id, s.code_value)
    s.target_id, s.code_value,
    s.parsed_part1, s.parsed_part2,
    s.selfpia_product_code, s.selfpia_option_no,
    s.memo_channel, s.memo_match_stage, s.memo_confidence,
    s.memo_decision_status, s.memo_vsku, s.memo_option_no, s.memo_product_name
  from product_code.smartstore_product_no_stage s
  where s.code_system = 'smartstore_product_no_candidate'
  order by s.target_id, s.code_value,
           s.memo_option_no nulls last,
           s.memo_vsku       nulls last
),
ins_candidate as (
  insert into product_code.code_alias (
    target_type, target_id, code_system, code_value,
    parsed_part1, parsed_part2,
    selfpia_product_code, selfpia_option_no,
    is_primary, memo
  )
  select
    'SKU',
    d.target_id,
    'smartstore_product_no_candidate',
    d.code_value,
    d.parsed_part1,
    d.parsed_part2,
    d.selfpia_product_code,
    d.selfpia_option_no,
    false,                              -- candidate 는 절대 primary 아님
    concat_ws('|',
      'src=supabase_sku_channel_mapping',
      'channel=' || d.memo_channel,
      'stage=' || d.memo_match_stage,
      'conf=' || d.memo_confidence::text,
      'decision=' || d.memo_decision_status,
      'vsku=' || d.memo_vsku,
      'optionNo=' || d.memo_option_no,
      'productName=' || d.memo_product_name,
      'NOTE=auto_candidate_not_confirmed'
    )
  from dedupe_candidate d
  join product_code.sku_master sm on sm.id = d.target_id
  where not exists (
    select 1 from product_code.code_alias ca
    where ca.target_type = 'SKU'
      and ca.target_id   = d.target_id
      and ca.code_system = 'smartstore_product_no_candidate'
      and ca.code_value  = d.code_value
  )
  returning 1
)
select 'INSERTED_CANDIDATE' as stage, count(*) as rows from ins_candidate;

-- 4) AFTER_IN_TX
select 'AFTER_IN_TX' as stage,
       count(*) filter (where code_system='smartstore_product_no')           as smartstore_product_confirmed,
       count(*) filter (where code_system='smartstore_product_no_candidate') as smartstore_product_candidate,
       count(*) filter (where code_system='smartstore_option_no')            as smartstore_option_confirmed,
       count(*) filter (where code_system='smartstore_option_no_candidate')  as smartstore_option_candidate,
       count(*) filter (where code_system='selfpia_sku')                     as selfpia_sku,
       count(*) filter (where code_system='own_sku')                         as own_sku,
       count(*) filter (where code_system='selfpia_product')                 as selfpia_product,
       count(*) filter (where code_system ilike 'makeshop%')                 as makeshop_total,
       count(*)                                                              as total_alias
from product_code.code_alias;

-- 5) CHK_1000_3_IN_TX — 원본 매핑 없으므로 0
select 'CHK_1000_3_IN_TX' as stage,
       code_system, count(*) as rows
from product_code.code_alias
where target_id = 'd4c0a5bf-73f1-4203-a6f8-9a27a44f58da'
  and code_system in ('smartstore_product_no','smartstore_product_no_candidate')
group by code_system
order by code_system;

-- 6) CHK_CANDIDATE_NOT_PRIMARY — 0 이어야 함
select 'CHK_CANDIDATE_NOT_PRIMARY' as stage,
       count(*) as candidate_primary_violations
from product_code.code_alias
where code_system='smartstore_product_no_candidate'
  and is_primary = true;

-- 7) ROLLBACK
rollback;

-- 8) ROLLBACK_CHECK (트랜잭션 밖, baseline 과 동일해야 함)
select 'ROLLBACK_CHECK' as stage,
       count(*) filter (where code_system='smartstore_product_no')           as smartstore_product_confirmed,
       count(*) filter (where code_system='smartstore_product_no_candidate') as smartstore_product_candidate,
       count(*) filter (where code_system='smartstore_option_no')            as smartstore_option_confirmed,
       count(*) filter (where code_system='smartstore_option_no_candidate')  as smartstore_option_candidate,
       count(*) filter (where code_system='selfpia_sku')                     as selfpia_sku,
       count(*) filter (where code_system='own_sku')                         as own_sku,
       count(*) filter (where code_system='selfpia_product')                 as selfpia_product,
       count(*) filter (where code_system ilike 'makeshop%')                 as makeshop_total,
       count(*)                                                              as total_alias
from product_code.code_alias;

-- 9) OVERALL verdict
--    기준 (distinct pair 기반):
--      - baseline 카운트 == ROLLBACK_CHECK 카운트 (모든 code_system)
--      - stage distinct_pairs > 0 (confirmed/candidate 모두)
--      - stage unresolved = 0
--      - 1000-3 의 smartstore_product_no_* = 0
--    INSERTED_CONFIRMED / INSERTED_CANDIDATE 의 rows 가
--    STAGE_DISTINCT_PAIRS 의 distinct_pairs 와 같은지는 출력 컬럼으로 노출,
--    OVERALL 자체는 baseline 보존 + stage 건전성 으로 PASS/FAIL.
with cur as (
  select
    count(*) filter (where code_system='smartstore_product_no')           as smartstore_product_confirmed,
    count(*) filter (where code_system='smartstore_product_no_candidate') as smartstore_product_candidate,
    count(*) filter (where code_system='smartstore_option_no')            as smartstore_option_confirmed,
    count(*) filter (where code_system='smartstore_option_no_candidate')  as smartstore_option_candidate,
    count(*) filter (where code_system='selfpia_sku')                     as selfpia_sku,
    count(*) filter (where code_system='own_sku')                         as own_sku,
    count(*) filter (where code_system='selfpia_product')                 as selfpia_product,
    count(*) filter (where code_system ilike 'makeshop%')                 as makeshop_total,
    count(*)                                                              as total_alias
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
resv as (
  select count(*) filter (where sm.id is null) as unresolved
  from product_code.smartstore_product_no_stage s
  left join product_code.sku_master sm on sm.id = s.target_id
),
chk_1000_3 as (
  select count(*) as smartstore_rows
  from product_code.code_alias
  where target_id = 'd4c0a5bf-73f1-4203-a6f8-9a27a44f58da'
    and code_system in ('smartstore_product_no','smartstore_product_no_candidate')
)
select 'OVERALL' as stage,
       case
         when b.smartstore_product_confirmed <> c.smartstore_product_confirmed then 'FAIL: smartstore_product_no not rolled back'
         when b.smartstore_product_candidate <> c.smartstore_product_candidate then 'FAIL: smartstore_product_no_candidate not rolled back'
         when b.smartstore_option_confirmed  <> c.smartstore_option_confirmed  then 'FAIL: smartstore_option_no count changed'
         when b.smartstore_option_candidate  <> c.smartstore_option_candidate  then 'FAIL: smartstore_option_no_candidate count changed'
         when b.selfpia_sku                  <> c.selfpia_sku                  then 'FAIL: selfpia_sku count changed'
         when b.own_sku                      <> c.own_sku                      then 'FAIL: own_sku count changed'
         when b.selfpia_product              <> c.selfpia_product              then 'FAIL: selfpia_product count changed'
         when b.makeshop_total               <> c.makeshop_total               then 'FAIL: makeshop_* count changed'
         when b.total_alias                  <> c.total_alias                  then 'FAIL: total_alias not restored'
         when s.stg_distinct_confirmed = 0                                     then 'FAIL: stage confirmed distinct=0'
         when s.stg_distinct_candidate = 0                                     then 'FAIL: stage candidate distinct=0'
         when r.unresolved <> 0                                                then 'FAIL: stage has unresolved target_id'
         when t.smartstore_rows <> 0                                           then 'FAIL: 1000-3 has smartstore_product_*'
         else 'PASS'
       end as verdict,
       s.stg_raw_confirmed       as stage_raw_confirmed,
       s.stg_distinct_confirmed  as stage_distinct_confirmed,
       s.stg_raw_candidate       as stage_raw_candidate,
       s.stg_distinct_candidate  as stage_distinct_candidate,
       r.unresolved              as stage_unresolved,
       t.smartstore_rows         as sku_1000_3_smartstore_product_rows,
       b.smartstore_product_confirmed  as baseline_pno_confirmed,
       c.smartstore_product_confirmed  as current_pno_confirmed,
       b.smartstore_product_candidate  as baseline_pno_candidate,
       c.smartstore_product_candidate  as current_pno_candidate
from _dryrun_baseline b cross join cur c cross join stg s cross join resv r cross join chk_1000_3 t;
