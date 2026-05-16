-- =============================================================================
-- dryrun_smartstore_alias_import.sql
-- Run target : local Docker (product_ops_test_postgres 컨테이너 내부 psql)
-- Mode       : BEGIN ... ROLLBACK. 절대 COMMIT 하지 않음.
-- 전제       : stage_smartstore_alias_import.sql 로 staging 적재 완료.
-- 핵심 변경  :
--   * code_alias 에 (target_id, code_system, code_value) UNIQUE 제약이 없으므로
--     ON CONFLICT 를 쓰지 않는다. NOT EXISTS 로 중복 삽입을 방지.
--   * 중복 판정 키: target_type, target_id, code_system, code_value 모두 동일.
--   * BEGIN 직전 TEMP 테이블 _dryrun_baseline 에 사전 카운트 stamp →
--     ROLLBACK 후 OVERALL 비교 가능.
-- 실행:
--   docker cp sql/dryrun_smartstore_alias_import.sql product_ops_test_postgres:/tmp/dryrun_smartstore_alias_import.sql
--   docker exec -i product_ops_test_postgres psql -U postgres -d product_ops_test \
--     -v ON_ERROR_STOP=1 -f /tmp/dryrun_smartstore_alias_import.sql
-- =============================================================================

-- 0) BEGIN 직전 baseline stamp (autocommit, ROLLBACK 영향 없음)
drop table if exists _dryrun_baseline;
create temp table _dryrun_baseline as
select
  count(*) filter (where code_system='smartstore_option_no')           as smartstore_confirmed,
  count(*) filter (where code_system='smartstore_option_no_candidate') as smartstore_candidate,
  count(*) filter (where code_system='selfpia_sku')                    as selfpia_sku,
  count(*) filter (where code_system='own_sku')                        as own_sku,
  count(*) filter (where code_system='selfpia_product')                as selfpia_product,
  count(*) filter (where code_system ilike 'makeshop%')                as makeshop_total,
  count(*)                                                             as total_alias
from product_code.code_alias;

-- baseline 출력
select 'BASELINE' as stage, * from _dryrun_baseline;

begin;

-- 1) BEFORE (트랜잭션 안에서도 동일해야 함)
select 'BEFORE' as stage,
       count(*) filter (where code_system='smartstore_option_no')           as smartstore_confirmed,
       count(*) filter (where code_system='smartstore_option_no_candidate') as smartstore_candidate,
       count(*) filter (where code_system='selfpia_sku')                    as selfpia_sku,
       count(*) filter (where code_system='own_sku')                        as own_sku,
       count(*) filter (where code_system='selfpia_product')                as selfpia_product,
       count(*) filter (where code_system ilike 'makeshop%')                as makeshop_total,
       count(*)                                                             as total_alias
from product_code.code_alias;

-- 2) confirmed INSERT (NOT EXISTS 중복 방지)
with ins_confirmed as (
  insert into product_code.code_alias (
    target_type, target_id, code_system, code_value,
    parsed_part1, parsed_part2,
    selfpia_product_code, selfpia_option_no,
    is_primary, memo
  )
  select
    'SKU',
    s.target_id,
    'smartstore_option_no',
    s.code_value,
    s.parsed_part1,
    s.parsed_part2,
    s.selfpia_product_code,
    s.selfpia_option_no,
    coalesce(s.is_primary, false),
    concat_ws('|',
      'src=supabase_sku_channel_mapping',
      'channel=' || s.memo_channel,
      'stage=' || s.memo_match_stage,
      'conf=' || s.memo_confidence::text,
      'decision=' || s.memo_decision_status,
      'vsku=' || s.memo_vsku
    )
  from product_code.smartstore_option_no_stage s
  join product_code.sku_master sm on sm.id = s.target_id
  where s.code_system = 'smartstore_option_no'
    and not exists (
      select 1 from product_code.code_alias ca
      where ca.target_type = 'SKU'
        and ca.target_id   = s.target_id
        and ca.code_system = 'smartstore_option_no'
        and ca.code_value  = s.code_value
    )
  returning 1
)
select 'INSERTED_CONFIRMED' as stage, count(*) as rows from ins_confirmed;

-- 3) candidate INSERT (NOT EXISTS, is_primary=false 강제)
with ins_candidate as (
  insert into product_code.code_alias (
    target_type, target_id, code_system, code_value,
    parsed_part1, parsed_part2,
    selfpia_product_code, selfpia_option_no,
    is_primary, memo
  )
  select
    'SKU',
    s.target_id,
    'smartstore_option_no_candidate',
    s.code_value,
    s.parsed_part1,
    s.parsed_part2,
    s.selfpia_product_code,
    s.selfpia_option_no,
    false,                              -- candidate 는 절대 primary 아님
    concat_ws('|',
      'src=supabase_sku_channel_mapping',
      'channel=' || s.memo_channel,
      'stage=' || s.memo_match_stage,
      'conf=' || s.memo_confidence::text,
      'decision=' || s.memo_decision_status,
      'vsku=' || s.memo_vsku,
      'NOTE=auto_candidate_not_confirmed'
    )
  from product_code.smartstore_option_no_stage s
  join product_code.sku_master sm on sm.id = s.target_id
  where s.code_system = 'smartstore_option_no_candidate'
    and not exists (
      select 1 from product_code.code_alias ca
      where ca.target_type = 'SKU'
        and ca.target_id   = s.target_id
        and ca.code_system = 'smartstore_option_no_candidate'
        and ca.code_value  = s.code_value
    )
  returning 1
)
select 'INSERTED_CANDIDATE' as stage, count(*) as rows from ins_candidate;

-- 4) AFTER_IN_TX
select 'AFTER_IN_TX' as stage,
       count(*) filter (where code_system='smartstore_option_no')           as smartstore_confirmed,
       count(*) filter (where code_system='smartstore_option_no_candidate') as smartstore_candidate,
       count(*) filter (where code_system='selfpia_sku')                    as selfpia_sku,
       count(*) filter (where code_system='own_sku')                        as own_sku,
       count(*) filter (where code_system='selfpia_product')                as selfpia_product,
       count(*) filter (where code_system ilike 'makeshop%')                as makeshop_total,
       count(*)                                                             as total_alias
from product_code.code_alias;

-- 5) 트랜잭션 내부 sanity check
-- 5-1) 1000-3 SKU smartstore 매핑은 여전히 0 이어야 함
select 'CHK_1000_3_IN_TX' as stage,
       code_system, count(*) as rows
from product_code.code_alias
where target_id = 'd4c0a5bf-73f1-4203-a6f8-9a27a44f58da'
  and code_system in ('smartstore_option_no','smartstore_option_no_candidate')
group by code_system
order by code_system;

-- 5-2) per-SKU confirmed/candidate 분포
with per_sku as (
  select target_id,
         count(*) filter (where code_system='smartstore_option_no')           as confirmed_n,
         count(*) filter (where code_system='smartstore_option_no_candidate') as candidate_n
  from product_code.code_alias
  where code_system in ('smartstore_option_no','smartstore_option_no_candidate')
  group by target_id
)
select 'PER_SKU_DIST_IN_TX' as stage,
       count(*) filter (where confirmed_n>0 and candidate_n>0) as sku_with_both,
       count(*) filter (where confirmed_n>0 and candidate_n=0) as sku_confirmed_only,
       count(*) filter (where confirmed_n=0 and candidate_n>0) as sku_candidate_only,
       max(confirmed_n) as max_confirmed_per_sku,
       max(candidate_n) as max_candidate_per_sku
from per_sku;

-- 5-3) candidate 가 is_primary=true 로 들어간 게 없어야 함
select 'CHK_CANDIDATE_NOT_PRIMARY' as stage,
       count(*) as candidate_primary_violations
from product_code.code_alias
where code_system='smartstore_option_no_candidate'
  and is_primary = true;

-- 6) ROLLBACK
rollback;

-- 7) ROLLBACK_CHECK (트랜잭션 밖, baseline 과 동일해야 함)
select 'ROLLBACK_CHECK' as stage,
       count(*) filter (where code_system='smartstore_option_no')           as smartstore_confirmed,
       count(*) filter (where code_system='smartstore_option_no_candidate') as smartstore_candidate,
       count(*) filter (where code_system='selfpia_sku')                    as selfpia_sku,
       count(*) filter (where code_system='own_sku')                        as own_sku,
       count(*) filter (where code_system='selfpia_product')                as selfpia_product,
       count(*) filter (where code_system ilike 'makeshop%')                as makeshop_total,
       count(*)                                                             as total_alias
from product_code.code_alias;

-- 8) OVERALL verdict (BASELINE 과 ROLLBACK_CHECK 비교 + 스테이지 건전성)
with cur as (
  select
    count(*) filter (where code_system='smartstore_option_no')           as smartstore_confirmed,
    count(*) filter (where code_system='smartstore_option_no_candidate') as smartstore_candidate,
    count(*) filter (where code_system='selfpia_sku')                    as selfpia_sku,
    count(*) filter (where code_system='own_sku')                        as own_sku,
    count(*) filter (where code_system='selfpia_product')                as selfpia_product,
    count(*) filter (where code_system ilike 'makeshop%')                as makeshop_total,
    count(*)                                                             as total_alias
  from product_code.code_alias
),
stg as (
  select
    count(*) filter (where code_system='smartstore_option_no')           as stg_confirmed,
    count(*) filter (where code_system='smartstore_option_no_candidate') as stg_candidate,
    count(*)                                                             as stg_total
  from product_code.smartstore_option_no_stage
),
resv as (
  select count(*) filter (where sm.id is null) as unresolved
  from product_code.smartstore_option_no_stage s
  left join product_code.sku_master sm on sm.id = s.target_id
),
chk_1000_3 as (
  select count(*) as smartstore_rows
  from product_code.code_alias
  where target_id = 'd4c0a5bf-73f1-4203-a6f8-9a27a44f58da'
    and code_system in ('smartstore_option_no','smartstore_option_no_candidate')
)
select 'OVERALL' as stage,
       case
         when b.smartstore_confirmed <> c.smartstore_confirmed then 'FAIL: smartstore_option_no not rolled back'
         when b.smartstore_candidate <> c.smartstore_candidate then 'FAIL: smartstore_option_no_candidate not rolled back'
         when b.selfpia_sku          <> c.selfpia_sku          then 'FAIL: selfpia_sku count changed'
         when b.own_sku              <> c.own_sku              then 'FAIL: own_sku count changed'
         when b.selfpia_product      <> c.selfpia_product      then 'FAIL: selfpia_product count changed'
         when b.makeshop_total       <> c.makeshop_total       then 'FAIL: makeshop_* count changed'
         when b.total_alias          <> c.total_alias          then 'FAIL: total_alias not restored after rollback'
         when s.stg_confirmed = 0                              then 'FAIL: stage confirmed is empty'
         when s.stg_candidate = 0                              then 'FAIL: stage candidate is empty'
         when r.unresolved   <> 0                              then 'FAIL: stage has unresolved target_id'
         when t.smartstore_rows <> 0                           then 'FAIL: 1000-3 has smartstore alias after rollback'
         else 'PASS'
       end as verdict,
       b.smartstore_confirmed as baseline_smartstore_confirmed,
       c.smartstore_confirmed as current_smartstore_confirmed,
       b.smartstore_candidate as baseline_smartstore_candidate,
       c.smartstore_candidate as current_smartstore_candidate,
       s.stg_confirmed         as stage_confirmed_rows,
       s.stg_candidate         as stage_candidate_rows,
       r.unresolved            as stage_unresolved,
       t.smartstore_rows       as sku_1000_3_smartstore_rows
from _dryrun_baseline b cross join cur c cross join stg s cross join resv r cross join chk_1000_3 t;
