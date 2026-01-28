-- 20260128152000_post_mvp5_m3_org_recommended_actions.sql
-- Post-MVP5 M3: acciones sugeridas (read-only)

set check_function_bodies = off;

begin;

-- ------------------------------------------------------------
-- View: v_org_recommended_actions_30d
-- ------------------------------------------------------------
drop view if exists public.v_org_recommended_actions_30d;

create view public.v_org_recommended_actions_30d
with (security_barrier = true)
as
with
-- A) Top gaps (alto impacto)
ranked_gaps as (
  select
    org_id,
    gap_key,
    learners_affected_count,
    percent_learners_affected,
    total_fail_events,
    row_number() over (partition by org_id order by total_fail_events desc) as gap_rank
  from public.v_org_top_gaps_30d
  where (percent_learners_affected >= 25)
     or (learners_affected_count >= 3)
),

-- B) Cobertura baja por unidad/local
ranked_coverage as (
  select
    org_id,
    local_id,
    program_id,
    unit_order,
    coverage_percent,
    learners_active_count,
    row_number() over (partition by org_id order by coverage_percent asc nulls last) as coverage_rank
  from public.v_org_unit_coverage_30d
  where coverage_percent is not null
    and coverage_percent < 60
    and coalesce(learners_active_count, 0) >= 2
),

-- C) Learners en riesgo
ranked_risk as (
  select
    org_id,
    local_id,
    learner_id,
    risk_level,
    last_signal_at,
    row_number() over (partition by org_id order by
      case risk_level when 'high' then 1 when 'medium' then 2 else 3 end,
      last_signal_at desc nulls last
    ) as risk_rank
  from public.v_org_learner_risk_30d
  where risk_level in ('high', 'medium')
)

select
  org_id,
  action_key,
  priority,
  title,
  reason,
  evidence,
  cta_label,
  cta_href,
  now() as created_at
from (
  -- A) gaps
  select
    g.org_id,
    'top_gap'::text as action_key,
    (90 - (g.gap_rank * 5)) as priority,
    'Gap con alto impacto'::text as title,
    ('% learners afectados por "' || g.gap_key || '"')::text as reason,
    jsonb_build_object(
      'gap_key', g.gap_key,
      'learners_affected_count', g.learners_affected_count,
      'percent_learners_affected', g.percent_learners_affected
    ) as evidence,
    'Ver gaps'::text as cta_label,
    ('/org/metrics/gaps/' || g.gap_key) as cta_href
  from ranked_gaps g

  union all

  -- B) coverage
  select
    c.org_id,
    'low_coverage'::text as action_key,
    (80 - (c.coverage_rank * 5)) as priority,
    'Cobertura baja en unidad'::text as title,
    ('Cobertura ' || round(c.coverage_percent, 1) || '% con learners activos')::text as reason,
    jsonb_build_object(
      'local_id', c.local_id,
      'program_id', c.program_id,
      'unit_order', c.unit_order,
      'coverage_percent', c.coverage_percent
    ) as evidence,
    'Abrir cobertura'::text as cta_label,
    ('/org/metrics/coverage/' || c.program_id || '/' || c.unit_order) as cta_href
  from ranked_coverage c

  union all

  -- C) risk
  select
    r.org_id,
    'learner_risk'::text as action_key,
    (70 - (r.risk_rank * 3)) as priority,
    'Learner en riesgo'::text as title,
    ('Riesgo ' || r.risk_level)::text as reason,
    jsonb_build_object(
      'learner_id', r.learner_id,
      'local_id', r.local_id,
      'risk_level', r.risk_level,
      'last_signal_at', r.last_signal_at
    ) as evidence,
    'Revisar learner'::text as cta_label,
    ('/referente/review/' || r.learner_id) as cta_href
  from ranked_risk r
) actions
where public.current_role() in ('admin_org', 'superadmin')
  and (
    public.current_role() = 'superadmin'
    or org_id = public.current_org_id()
  )
order by priority desc
limit 10;

comment on view public.v_org_recommended_actions_30d is
'Post-MVP5 M3: Acciones sugeridas (30d) para Admin Org. Combina gaps, cobertura baja y learners en riesgo; read-only.';

commit;
