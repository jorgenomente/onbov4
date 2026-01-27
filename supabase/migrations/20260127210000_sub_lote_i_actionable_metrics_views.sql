/*
Fase 3 / Sub-lote I — Views de métricas accionables (read-only)

Crea 3 views tenant-scoped (solo roles: superadmin/admin_org/referente):
- v_local_top_gaps_30d
- v_local_learner_risk_30d
- v_local_unit_coverage_30d

Notas:
- Ventana temporal fija: últimos 30 días (now() - interval '30 days')
- Unnest de arrays (gaps, doubt_signals)
- NO expone a aprendiz (filtro por current_role())
*/

begin;

-- =========================================================
-- A) Top gaps del local (últimos 30 días)
-- =========================================================
create or replace view public.v_local_top_gaps_30d as
with scoped_local as (
  select
    public.current_local_id() as local_id,
    public.current_org_id() as org_id,
    public.current_role() as role_name
),
practice_gaps as (
  select
    pa.local_id,
    pa.learner_id,
    unnest(pe.gaps) as gap,
    pe.created_at
  from public.practice_evaluations pe
  join public.practice_attempts pa on pa.id = pe.attempt_id
  where
    pe.created_at >= now() - interval '30 days'
    and coalesce(array_length(pe.gaps, 1), 0) > 0
),
final_gaps as (
  select
    lt.local_id,
    a.learner_id,
    unnest(ev.gaps) as gap,
    ev.created_at
  from public.final_evaluation_evaluations ev
  join public.final_evaluation_answers ans on ans.id = ev.answer_id
  join public.final_evaluation_questions q on q.id = ans.question_id
  join public.final_evaluation_attempts a on a.id = q.attempt_id
  join public.learner_trainings lt
    on lt.learner_id = a.learner_id
   and lt.program_id = a.program_id
  where
    ev.created_at >= now() - interval '30 days'
    and coalesce(array_length(ev.gaps, 1), 0) > 0
),
unioned as (
  select local_id, learner_id, gap, created_at from practice_gaps
  union all
  select local_id, learner_id, gap, created_at from final_gaps
),
scoped as (
  select u.*
  from unioned u
  join public.locals l on l.id = u.local_id
  cross join scoped_local s
  where
    s.role_name in ('superadmin','admin_org','referente')
    and (
      s.role_name = 'superadmin'
      or (s.role_name = 'referente' and u.local_id = s.local_id)
      or (s.role_name = 'admin_org' and l.org_id = s.org_id)
    )
),
practice_activity as (
  select
    pa.local_id,
    pa.learner_id,
    pe.created_at
  from public.practice_evaluations pe
  join public.practice_attempts pa on pa.id = pe.attempt_id
  where pe.created_at >= now() - interval '30 days'
),
final_activity as (
  select
    lt.local_id,
    a.learner_id,
    ev.created_at
  from public.final_evaluation_evaluations ev
  join public.final_evaluation_answers ans on ans.id = ev.answer_id
  join public.final_evaluation_questions q on q.id = ans.question_id
  join public.final_evaluation_attempts a on a.id = q.attempt_id
  join public.learner_trainings lt
    on lt.learner_id = a.learner_id
   and lt.program_id = a.program_id
  where ev.created_at >= now() - interval '30 days'
),
activity_union as (
  select local_id, learner_id, created_at from practice_activity
  union all
  select local_id, learner_id, created_at from final_activity
),
activity_scoped as (
  select a.*
  from activity_union a
  join public.locals l on l.id = a.local_id
  cross join scoped_local s
  where
    s.role_name in ('superadmin','admin_org','referente')
    and (
      s.role_name = 'superadmin'
      or (s.role_name = 'referente' and a.local_id = s.local_id)
      or (s.role_name = 'admin_org' and l.org_id = s.org_id)
    )
),
local_learners as (
  select distinct learner_id
  from activity_scoped
),
agg as (
  select
    local_id,
    gap,
    count(*)::int as count_total,
    count(distinct learner_id)::int as learners_affected,
    max(created_at) as last_seen_at
  from scoped
  group by local_id, gap
),
denom as (
  select count(*)::int as local_learner_count
  from local_learners
)
select
  a.local_id,
  a.gap,
  a.count_total,
  a.learners_affected,
  case
    when d.local_learner_count = 0 then 0::numeric
    else round((a.learners_affected::numeric / d.local_learner_count::numeric) * 100, 2)
  end as percent_learners_affected,
  a.last_seen_at
from agg a
cross join denom d;

grant select on public.v_local_top_gaps_30d to authenticated;

-- =========================================================
-- B) Riesgo por aprendiz (últimos 30 días)
-- =========================================================
create or replace view public.v_local_learner_risk_30d as
with scoped_ctx as (
  select
    public.current_local_id() as local_id,
    public.current_org_id() as org_id,
    public.current_role() as role_name
),
practice_events as (
  select
    pa.local_id,
    pa.learner_id,
    pe.verdict,
    pe.doubt_signals,
    pe.created_at
  from public.practice_evaluations pe
  join public.practice_attempts pa on pa.id = pe.attempt_id
  where pe.created_at >= now() - interval '30 days'
),
final_events as (
  select
    lt.local_id,
    a.learner_id,
    ev.verdict,
    ev.doubt_signals,
    ev.created_at
  from public.final_evaluation_evaluations ev
  join public.final_evaluation_answers ans on ans.id = ev.answer_id
  join public.final_evaluation_questions q on q.id = ans.question_id
  join public.final_evaluation_attempts a on a.id = q.attempt_id
  join public.learner_trainings lt
    on lt.learner_id = a.learner_id
   and lt.program_id = a.program_id
  where ev.created_at >= now() - interval '30 days'
),
scoped_practice as (
  select p.*
  from practice_events p
  join public.locals l on l.id = p.local_id
  cross join scoped_ctx s
  where
    s.role_name in ('superadmin','admin_org','referente')
    and (
      s.role_name = 'superadmin'
      or (s.role_name = 'referente' and p.local_id = s.local_id)
      or (s.role_name = 'admin_org' and l.org_id = s.org_id)
    )
),
scoped_final as (
  select f.*
  from final_events f
  join public.locals l on l.id = f.local_id
  cross join scoped_ctx s
  where
    s.role_name in ('superadmin','admin_org','referente')
    and (
      s.role_name = 'superadmin'
      or (s.role_name = 'referente' and f.local_id = s.local_id)
      or (s.role_name = 'admin_org' and l.org_id = s.org_id)
    )
),
practice_agg as (
  select
    local_id,
    learner_id,
    count(*) filter (where verdict = 'fail')::int as failed_practice_count,
    count(*) filter (where verdict = 'partial')::int as partial_practice_count,
    sum(coalesce(array_length(doubt_signals, 1), 0))::int as practice_doubt_signals_count,
    max(created_at) as last_practice_at
  from scoped_practice
  group by local_id, learner_id
),
final_agg as (
  select
    local_id,
    learner_id,
    count(*) filter (where verdict = 'fail')::int as failed_final_count,
    count(*) filter (where verdict = 'partial')::int as partial_final_count,
    sum(coalesce(array_length(doubt_signals, 1), 0))::int as final_doubt_signals_count,
    max(created_at) as last_final_at
  from scoped_final
  group by local_id, learner_id
),
merged as (
  select
    coalesce(p.local_id, f.local_id) as local_id,
    coalesce(p.learner_id, f.learner_id) as learner_id,
    coalesce(p.failed_practice_count, 0) as failed_practice_count,
    coalesce(f.failed_final_count, 0) as failed_final_count,
    coalesce(p.practice_doubt_signals_count, 0) + coalesce(f.final_doubt_signals_count, 0) as doubt_signals_count,
    greatest(coalesce(p.last_practice_at, 'epoch'::timestamptz), coalesce(f.last_final_at, 'epoch'::timestamptz)) as last_activity_at
  from practice_agg p
  full join final_agg f
    on f.local_id = p.local_id
   and f.learner_id = p.learner_id
)
select
  m.local_id,
  m.learner_id,
  m.failed_practice_count,
  m.failed_final_count,
  m.doubt_signals_count,
  nullif(m.last_activity_at, 'epoch'::timestamptz) as last_activity_at,
  case
    when (m.failed_final_count >= 1) or (m.failed_practice_count >= 3) or (m.doubt_signals_count >= 3) then 'high'
    when (m.failed_practice_count between 1 and 2) or (m.doubt_signals_count between 1 and 2) then 'medium'
    else 'low'
  end as risk_level,
  array_remove(array[
    case when m.failed_final_count >= 1 then 'failed_final>=1' end,
    case when m.failed_practice_count >= 3 then 'failed_practice>=3' end,
    case when m.doubt_signals_count >= 3 then 'doubt_signals>=3' end,
    case when m.failed_practice_count between 1 and 2 then 'failed_practice=1..2' end,
    case when m.doubt_signals_count between 1 and 2 then 'doubt_signals=1..2' end
  ]::text[], null) as reasons
from merged m;

grant select on public.v_local_learner_risk_30d to authenticated;

-- =========================================================
-- C) Cobertura por unidad (local) — últimos 30 días
-- =========================================================
create or replace view public.v_local_unit_coverage_30d as
with ctx as (
  select
    public.current_local_id() as local_id,
    public.current_org_id() as org_id,
    public.current_role() as role_name
),
practice_scoped as (
  select
    pa.local_id,
    ps.program_id,
    ps.unit_order,
    pe.score,
    pe.verdict,
    pe.gaps,
    pe.created_at
  from public.practice_evaluations pe
  join public.practice_attempts pa on pa.id = pe.attempt_id
  join public.practice_scenarios ps on ps.id = pa.scenario_id
  where pe.created_at >= now() - interval '30 days'
),
final_scoped as (
  select
    lt.local_id,
    a.program_id,
    ev.unit_order,
    ev.score,
    ev.verdict,
    ev.gaps,
    ev.created_at
  from public.final_evaluation_evaluations ev
  join public.final_evaluation_answers ans on ans.id = ev.answer_id
  join public.final_evaluation_questions q on q.id = ans.question_id
  join public.final_evaluation_attempts a on a.id = q.attempt_id
  join public.learner_trainings lt
    on lt.learner_id = a.learner_id
   and lt.program_id = a.program_id
  where ev.created_at >= now() - interval '30 days'
),
practice_filtered as (
  select p.*
  from practice_scoped p
  join public.locals l on l.id = p.local_id
  cross join ctx c
  where
    c.role_name in ('superadmin','admin_org','referente')
    and (
      c.role_name = 'superadmin'
      or (c.role_name = 'referente' and p.local_id = c.local_id)
      or (c.role_name = 'admin_org' and l.org_id = c.org_id)
    )
),
final_filtered as (
  select f.*
  from final_scoped f
  join public.locals l on l.id = f.local_id
  cross join ctx c
  where
    c.role_name in ('superadmin','admin_org','referente')
    and (
      c.role_name = 'superadmin'
      or (c.role_name = 'referente' and f.local_id = c.local_id)
      or (c.role_name = 'admin_org' and l.org_id = c.org_id)
    )
),
practice_unit as (
  select
    local_id,
    program_id,
    unit_order,
    avg(score)::numeric(5,2) as avg_practice_score,
    (count(*) filter (where verdict = 'fail')::numeric / nullif(count(*)::numeric, 0)) as practice_fail_rate
  from practice_filtered
  group by local_id, program_id, unit_order
),
final_unit as (
  select
    local_id,
    program_id,
    unit_order,
    avg(score)::numeric(5,2) as avg_final_score,
    (count(*) filter (where verdict = 'fail')::numeric / nullif(count(*)::numeric, 0)) as final_fail_rate
  from final_filtered
  group by local_id, program_id, unit_order
),
gaps_union as (
  select local_id, program_id, unit_order, unnest(gaps) as gap
  from practice_filtered
  where coalesce(array_length(gaps, 1), 0) > 0
  union all
  select local_id, program_id, unit_order, unnest(gaps) as gap
  from final_filtered
  where coalesce(array_length(gaps, 1), 0) > 0
),
top_gap as (
  select distinct on (local_id, program_id, unit_order)
    local_id,
    program_id,
    unit_order,
    gap as top_gap,
    count(*) over (partition by local_id, program_id, unit_order, gap) as gap_count
  from gaps_union
  order by local_id, program_id, unit_order, gap_count desc, gap asc
)
select
  coalesce(p.local_id, f.local_id) as local_id,
  coalesce(p.program_id, f.program_id) as program_id,
  coalesce(p.unit_order, f.unit_order) as unit_order,
  p.avg_practice_score,
  f.avg_final_score,
  round(coalesce(p.practice_fail_rate, 0)::numeric, 4) as practice_fail_rate,
  round(coalesce(f.final_fail_rate, 0)::numeric, 4) as final_fail_rate,
  tg.top_gap
from practice_unit p
full join final_unit f
  on f.local_id = p.local_id
 and f.program_id = p.program_id
 and f.unit_order = p.unit_order
left join top_gap tg
  on tg.local_id = coalesce(p.local_id, f.local_id)
 and tg.program_id = coalesce(p.program_id, f.program_id)
 and tg.unit_order = coalesce(p.unit_order, f.unit_order);

grant select on public.v_local_unit_coverage_30d to authenticated;

commit;
