-- 20260128133000_post_mvp5_m1_org_metrics_views.sql
-- Post-MVP 5 / Sub-lote M1: métricas accionables Admin Org (30 días)

set check_function_bodies = off;

begin;

-- ------------------------------------------------------------
-- 1) Org top gaps 30d
-- ------------------------------------------------------------
drop view if exists public.v_org_top_gaps_30d;

create view public.v_org_top_gaps_30d
with (security_barrier = true)
as
with org_learners as (
  select l.org_id, count(distinct lt.learner_id) as learners_count
  from public.learner_trainings lt
  join public.locals l on l.id = lt.local_id
  where lt.updated_at >= now() - interval '30 days'
  group by l.org_id
)
select
  l.org_id,
  v.gap as gap_key,
  null::integer as unit_order,
  v.gap as title,
  sum(v.learners_affected) as learners_affected_count,
  case
    when coalesce(ol.learners_count, 0) = 0 then 0
    else round(sum(v.learners_affected)::numeric / ol.learners_count * 100, 2)
  end as percent_learners_affected,
  sum(v.count_total) as total_fail_events,
  30 as window_days
from public.v_local_top_gaps_30d v
join public.locals l on l.id = v.local_id
left join org_learners ol on ol.org_id = l.org_id
where public.current_role() in ('admin_org', 'superadmin')
  and (
    public.current_role() = 'superadmin'
    or l.org_id = public.current_org_id()
  )
group by l.org_id, v.gap, ol.learners_count
order by total_fail_events desc;

comment on view public.v_org_top_gaps_30d is
'Post-MVP5 M1: Top gaps por org (ventana 30d). Deriva de v_local_top_gaps_30d; percent_learners_affected usa learners_count en 30d por org.';

-- ------------------------------------------------------------
-- 2) Org learner risk 30d
-- ------------------------------------------------------------
drop view if exists public.v_org_learner_risk_30d;

create view public.v_org_learner_risk_30d
with (security_barrier = true)
as
select
  l.org_id,
  v.local_id,
  v.learner_id,
  v.risk_level,
  (coalesce(v.failed_practice_count, 0)
   + coalesce(v.failed_final_count, 0)
   + coalesce(v.doubt_signals_count, 0)) as risk_score,
  (coalesce(v.failed_practice_count, 0)
   + coalesce(v.failed_final_count, 0)
   + coalesce(v.doubt_signals_count, 0)) as signals_count_30d,
  v.last_activity_at as last_signal_at
from public.v_local_learner_risk_30d v
join public.locals l on l.id = v.local_id
where public.current_role() in ('admin_org', 'superadmin')
  and (
    public.current_role() = 'superadmin'
    or l.org_id = public.current_org_id()
  );

comment on view public.v_org_learner_risk_30d is
'Post-MVP5 M1: Riesgo por aprendiz (30d) agregado a org. risk_score=failed_practice+failed_final+doubt_signals.';

-- ------------------------------------------------------------
-- 3) Org unit coverage 30d
-- ------------------------------------------------------------
drop view if exists public.v_org_unit_coverage_30d;

create view public.v_org_unit_coverage_30d
with (security_barrier = true)
as
select
  l.org_id,
  v.local_id,
  l.name as local_name,
  v.program_id,
  v.unit_order,
  case
    when v.practice_fail_rate is null and v.final_fail_rate is null then null
    else round(
      (1 - (coalesce(v.practice_fail_rate, 0) + coalesce(v.final_fail_rate, 0)) / 2) * 100,
      2
    )
  end as coverage_percent,
  (
    select count(distinct lt.learner_id)
    from public.learner_trainings lt
    where lt.local_id = v.local_id
      and lt.program_id = v.program_id
      and lt.updated_at >= now() - interval '30 days'
  ) as learners_active_count,
  (
    select count(distinct learner_id) from (
      select pa.learner_id
      from public.practice_attempts pa
      join public.practice_scenarios ps on ps.id = pa.scenario_id
      where pa.local_id = v.local_id
        and ps.program_id = v.program_id
        and ps.unit_order = v.unit_order
        and pa.started_at >= now() - interval '30 days'
      union
      select a.learner_id
      from public.final_evaluation_evaluations ev
      join public.final_evaluation_answers ans on ans.id = ev.answer_id
      join public.final_evaluation_questions q on q.id = ans.question_id
      join public.final_evaluation_attempts a on a.id = q.attempt_id
      where a.program_id = v.program_id
        and q.unit_order = v.unit_order
        and ev.created_at >= now() - interval '30 days'
    ) as evidence
  ) as learners_with_evidence_count,
  (
    select greatest(
      (
        select max(pa.started_at)
        from public.practice_attempts pa
        join public.practice_scenarios ps on ps.id = pa.scenario_id
        where pa.local_id = v.local_id
          and ps.program_id = v.program_id
          and ps.unit_order = v.unit_order
      ),
      (
        select max(ev.created_at)
        from public.final_evaluation_evaluations ev
        join public.final_evaluation_answers ans on ans.id = ev.answer_id
        join public.final_evaluation_questions q on q.id = ans.question_id
        join public.final_evaluation_attempts a on a.id = q.attempt_id
        where a.program_id = v.program_id
          and q.unit_order = v.unit_order
      )
    )
  ) as last_activity_at
from public.v_local_unit_coverage_30d v
join public.locals l on l.id = v.local_id
where public.current_role() in ('admin_org', 'superadmin')
  and (
    public.current_role() = 'superadmin'
    or l.org_id = public.current_org_id()
  );

comment on view public.v_org_unit_coverage_30d is
'Post-MVP5 M1: Cobertura por unidad (30d) agregada por org. coverage_percent deriva de fail rates promedio.';

commit;
