-- 20260128143000_post_mvp5_m2_org_metrics_drilldowns.sql
-- Post-MVP 5 / Sub-lote M2: drill-down org metrics (read-only)

set check_function_bodies = off;

begin;

-- ------------------------------------------------------------
-- 1) Gap distribution by local (30d)
--    Nota: gaps son strings libres (no unit_order). Se expone gap_key.
-- ------------------------------------------------------------
drop view if exists public.v_org_gap_locals_30d;

create view public.v_org_gap_locals_30d
with (security_barrier = true)
as
select
  l.org_id,
  v.gap as gap_key,
  v.local_id,
  l.name as local_name,
  v.learners_affected as learners_affected_count,
  v.percent_learners_affected as percent_learners_affected_local,
  v.count_total as total_events_30d,
  v.last_seen_at as last_event_at
from public.v_local_top_gaps_30d v
join public.locals l on l.id = v.local_id
where public.current_role() in ('admin_org', 'superadmin')
  and (
    public.current_role() = 'superadmin'
    or l.org_id = public.current_org_id()
  );

comment on view public.v_org_gap_locals_30d is
'Post-MVP5 M2: Distribucion de gaps (gap_key) por local en 30d. gap_key proviene de v_local_top_gaps_30d; no hay unit_order.';

-- ------------------------------------------------------------
-- 2) Active knowledge by unit (org-scoped)
-- ------------------------------------------------------------
drop view if exists public.v_org_unit_knowledge_active;

create view public.v_org_unit_knowledge_active
with (security_barrier = true)
as
select
  tp.org_id,
  tp.id as program_id,
  tp.name as program_name,
  tu.id as unit_id,
  tu.unit_order,
  tu.title as unit_title,
  ki.id as knowledge_id,
  ki.title as knowledge_title,
  case when ki.local_id is null then 'org' else 'local' end as knowledge_scope,
  ki.created_at as knowledge_created_at
from public.training_units tu
join public.training_programs tp on tp.id = tu.program_id
join public.unit_knowledge_map ukm on ukm.unit_id = tu.id
join public.knowledge_items ki on ki.id = ukm.knowledge_id
where ki.is_enabled = true
  and public.current_role() in ('admin_org', 'superadmin')
  and (
    public.current_role() = 'superadmin'
    or tp.org_id = public.current_org_id()
  );

comment on view public.v_org_unit_knowledge_active is
'Post-MVP5 M2: Knowledge activo por unidad (org-scoped). Filtra is_enabled=true; scope deriva de knowledge_items.local_id.';

commit;
