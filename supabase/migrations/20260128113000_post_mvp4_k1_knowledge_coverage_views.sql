-- 20260128113000_post_mvp4_k1_knowledge_coverage_views.sql
-- Post-MVP 4 / Sub-lote K1: coverage de knowledge por unidad (read-only)

set check_function_bodies = off;

begin;

-- -------------------------------------------------------------------
-- 1) Coverage por unidad
-- Nota: local_level_knowledge_count solo aplica cuando training_programs.local_id is not null.
-- Para programas org-level, local_level_knowledge_count = 0 (evita ambiguedad).
-- -------------------------------------------------------------------
drop view if exists public.v_org_program_knowledge_gaps_summary;
drop view if exists public.v_org_unit_knowledge_list;
drop view if exists public.v_org_program_unit_knowledge_coverage;

create or replace view public.v_org_program_unit_knowledge_coverage
with (security_barrier = true)
as
select
  tp.id as program_id,
  tp.name as program_name,
  tu.id as unit_id,
  tu.unit_order,
  tu.title as unit_title,
  count(ki.id) as total_knowledge_count,
  count(ki.id) filter (where ki.local_id is null) as org_level_knowledge_count,
  count(ki.id) filter (
    where tp.local_id is not null
      and ki.local_id = tp.local_id
  ) as local_level_knowledge_count,
  (count(ukm.knowledge_id) > 0) as has_any_mapping,
  (count(ukm.knowledge_id) = 0) as is_missing_mapping
from public.training_programs tp
join public.training_units tu on tu.program_id = tp.id
left join public.unit_knowledge_map ukm on ukm.unit_id = tu.id
left join public.knowledge_items ki on ki.id = ukm.knowledge_id
where public.current_role() in ('admin_org', 'superadmin', 'referente')
group by
  tp.id,
  tp.name,
  tu.id,
  tu.unit_order,
  tu.title
order by
  tp.id,
  tu.unit_order;

comment on view public.v_org_program_unit_knowledge_coverage is
'Post-MVP4 K1: Coverage de knowledge por unidad. local_level_knowledge_count solo se computa si training_programs.local_id no es NULL; para programas org-level se reporta 0.';

-- -------------------------------------------------------------------
-- 2) Resumen por programa
-- -------------------------------------------------------------------
create or replace view public.v_org_program_knowledge_gaps_summary
with (security_barrier = true)
as
select
  program_id,
  program_name,
  count(*)::integer as total_units,
  count(*) filter (where is_missing_mapping)::integer as units_missing_mapping,
  case
    when count(*) = 0 then 0
    else round((count(*) filter (where is_missing_mapping))::numeric / count(*)::numeric * 100, 2)
  end as pct_units_missing_mapping,
  sum(total_knowledge_count)::integer as total_knowledge_mappings
from public.v_org_program_unit_knowledge_coverage
where public.current_role() in ('admin_org', 'superadmin', 'referente')
group by program_id, program_name;

comment on view public.v_org_program_knowledge_gaps_summary is
'Post-MVP4 K1: Resumen de gaps por programa (unidades, gaps, % gaps, mappings totales).';

-- -------------------------------------------------------------------
-- 3) Listado de knowledge por unidad (drill-down)
-- -------------------------------------------------------------------
create or replace view public.v_org_unit_knowledge_list
with (security_barrier = true)
as
select
  tp.id as program_id,
  tp.name as program_name,
  tu.id as unit_id,
  tu.unit_order,
  ki.id as knowledge_id,
  ki.title as knowledge_title,
  case when ki.local_id is null then 'org' else 'local' end as knowledge_scope,
  ki.created_at as knowledge_created_at
from public.training_programs tp
join public.training_units tu on tu.program_id = tp.id
join public.unit_knowledge_map ukm on ukm.unit_id = tu.id
join public.knowledge_items ki on ki.id = ukm.knowledge_id
where public.current_role() in ('admin_org', 'superadmin', 'referente')
order by tp.id, tu.unit_order, ki.created_at desc;

comment on view public.v_org_unit_knowledge_list is
'Post-MVP4 K1: Knowledge asociado por unidad (drill-down, read-only).';

commit;
