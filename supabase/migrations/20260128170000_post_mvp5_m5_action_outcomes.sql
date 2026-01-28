-- 20260128170000_post_mvp5_m5_action_outcomes.sql
-- Post-MVP5 M5: outcomes (7d vs 30d) for suggested actions (read-only)

set check_function_bodies = off;

begin;

-- ------------------------------------------------------------
-- 1) Outcomes per action_key (org-scoped)
-- NOTE: 7d signal not derivable from existing 30d views without duplicating logic.
-- Fallback: score_7d is NULL => trend = stable.
-- ------------------------------------------------------------
drop view if exists public.v_org_actions_outcomes_30d;

create view public.v_org_actions_outcomes_30d
with (security_barrier = true)
as
with orgs as (
  select distinct org_id from public.v_org_top_gaps_30d
  union
  select distinct org_id from public.v_org_unit_coverage_30d
  union
  select distinct org_id from public.v_org_learner_risk_30d
),

-- 30d scores from existing org views
score_top_gap as (
  select org_id,
    max(percent_learners_affected)::numeric as score_30d,
    count(*)::int as sample_size_30d
  from public.v_org_top_gaps_30d
  group by org_id
),

score_low_coverage as (
  select org_id,
    avg(coverage_percent)::numeric as score_30d,
    count(*)::int as sample_size_30d
  from public.v_org_unit_coverage_30d
  where coverage_percent is not null
  group by org_id
),

score_learner_risk as (
  select org_id,
    count(*)::numeric as score_30d,
    count(*)::int as sample_size_30d
  from public.v_org_learner_risk_30d
  where risk_level in ('high', 'medium')
  group by org_id
),

all_scores as (
  select o.org_id,
    'top_gap'::text as action_key,
    s.score_30d,
    s.sample_size_30d
  from orgs o
  left join score_top_gap s on s.org_id = o.org_id

  union all

  select o.org_id,
    'low_coverage'::text as action_key,
    s.score_30d,
    s.sample_size_30d
  from orgs o
  left join score_low_coverage s on s.org_id = o.org_id

  union all

  select o.org_id,
    'learner_risk'::text as action_key,
    s.score_30d,
    s.sample_size_30d
  from orgs o
  left join score_learner_risk s on s.org_id = o.org_id
)

select
  org_id,
  action_key,
  'stable'::text as trend,
  null::numeric as delta_score,
  null::numeric as score_7d,
  score_30d,
  sample_size_30d,
  now() as computed_at
from all_scores
where public.current_role() in ('admin_org', 'superadmin')
  and (
    public.current_role() = 'superadmin'
    or org_id = public.current_org_id()
  );

comment on view public.v_org_actions_outcomes_30d is
'Post-MVP5 M5: Outcomes 7d vs 30d por action_key. Fallback: sin señal 7d (score_7d NULL => trend=stable).';

-- ------------------------------------------------------------
-- 2) Optional join view for UI convenience
-- ------------------------------------------------------------
drop view if exists public.v_org_recommended_actions_playbooks_with_outcomes_30d;

create view public.v_org_recommended_actions_playbooks_with_outcomes_30d
with (security_barrier = true)
as
select
  p.org_id,
  p.action_key,
  p.priority,
  p.title,
  p.reason,
  p.evidence,
  p.cta_label,
  p.cta_href,
  p.checklist,
  p.impact_note,
  p.secondary_links,
  o.trend,
  o.delta_score,
  o.score_7d,
  o.score_30d,
  o.sample_size_30d,
  o.computed_at,
  p.created_at
from public.v_org_recommended_actions_playbooks_30d p
left join public.v_org_actions_outcomes_30d o
  on o.org_id = p.org_id
  and o.action_key = p.action_key
where public.current_role() in ('admin_org', 'superadmin')
  and (
    public.current_role() = 'superadmin'
    or p.org_id = public.current_org_id()
  );

comment on view public.v_org_recommended_actions_playbooks_with_outcomes_30d is
'Post-MVP5 M5: Playbooks + outcomes (trend, scores) para acciones sugeridas.';

commit;
