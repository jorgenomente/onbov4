-- Post-MVP6 Sub-lote 2: Views read-only Config del Bot (sin UI, sin writes)

begin;

create or replace view public.v_local_bot_config_summary
with (security_barrier = 'true') as
select
  lap.local_id,
  l.org_id,
  tp.id as active_program_id,
  tp.name as active_program_name,
  coalesce(units.total_units, 0)::integer as total_units,
  fec.config_id as current_final_eval_config_id,
  fec.total_questions as final_eval_total_questions,
  fec.roleplay_ratio,
  fec.min_global_score,
  fec.must_pass_units,
  fec.questions_per_unit,
  fec.max_attempts,
  fec.cooldown_hours,
  coalesce(knowledge.total_knowledge_items, 0)::integer as total_knowledge_items_active_program,
  coalesce(practice.total_practice_scenarios, 0)::integer as total_practice_scenarios_active_program,
  knowledge.knowledge_count_by_type
from public.local_active_programs lap
join public.locals l on l.id = lap.local_id
join public.training_programs tp on tp.id = lap.program_id
left join lateral (
  select count(*) as total_units
  from public.training_units tu
  where tu.program_id = tp.id
) units on true
left join lateral (
  select
    fec_inner.id as config_id,
    fec_inner.total_questions,
    fec_inner.roleplay_ratio,
    fec_inner.min_global_score,
    fec_inner.must_pass_units,
    fec_inner.questions_per_unit,
    fec_inner.max_attempts,
    fec_inner.cooldown_hours
  from public.final_evaluation_configs fec_inner
  where fec_inner.program_id = tp.id
  order by fec_inner.created_at desc
  limit 1
) fec on true
left join lateral (
  select
    count(distinct ki.id) as total_knowledge_items,
    jsonb_build_object(
      'concepto', count(distinct ki.id) filter (where ki.content_type = 'concepto'),
      'procedimiento', count(distinct ki.id) filter (where ki.content_type = 'procedimiento'),
      'regla', count(distinct ki.id) filter (where ki.content_type = 'regla'),
      'guion', count(distinct ki.id) filter (where ki.content_type = 'guion'),
      'sin_tipo', count(distinct ki.id) filter (where ki.content_type is null)
    ) as knowledge_count_by_type
  from public.training_units tu
  join public.unit_knowledge_map ukm on ukm.unit_id = tu.id
  join public.knowledge_items ki on ki.id = ukm.knowledge_id
  where tu.program_id = tp.id
    and ki.is_enabled = true
    and (ki.local_id is null or ki.local_id = lap.local_id)
) knowledge on true
left join lateral (
  select
    count(*) as total_practice_scenarios
  from public.practice_scenarios ps
  where ps.program_id = tp.id
    and (ps.local_id is null or ps.local_id = lap.local_id)
) practice on true;

comment on view public.v_local_bot_config_summary is
  'Post-MVP6 S2: Resumen config del bot por local (programa activo, config final vigente, coverage knowledge y escenarios). Read-only; tenant-scoped por RLS de tablas base.';

create or replace view public.v_local_bot_config_units
with (security_barrier = 'true') as
select
  lap.local_id,
  tp.id as program_id,
  tu.unit_order,
  tu.title as unit_title,
  coalesce(knowledge.knowledge_count, 0)::integer as knowledge_count,
  knowledge.knowledge_count_by_type,
  coalesce(practice.practice_scenarios_count, 0)::integer as practice_scenarios_count,
  practice.practice_difficulty_min,
  practice.practice_difficulty_max,
  coalesce(practice.success_criteria_count_total, 0)::integer as success_criteria_count_total
from public.local_active_programs lap
join public.training_programs tp on tp.id = lap.program_id
join public.training_units tu on tu.program_id = tp.id
left join lateral (
  select
    count(*) as knowledge_count,
    jsonb_build_object(
      'concepto', count(*) filter (where ki.content_type = 'concepto'),
      'procedimiento', count(*) filter (where ki.content_type = 'procedimiento'),
      'regla', count(*) filter (where ki.content_type = 'regla'),
      'guion', count(*) filter (where ki.content_type = 'guion'),
      'sin_tipo', count(*) filter (where ki.content_type is null)
    ) as knowledge_count_by_type
  from public.unit_knowledge_map ukm
  join public.knowledge_items ki on ki.id = ukm.knowledge_id
  where ukm.unit_id = tu.id
    and ki.is_enabled = true
    and (ki.local_id is null or ki.local_id = lap.local_id)
) knowledge on true
left join lateral (
  select
    count(*) as practice_scenarios_count,
    min(ps.difficulty) as practice_difficulty_min,
    max(ps.difficulty) as practice_difficulty_max,
    sum(coalesce(array_length(ps.success_criteria, 1), 0)) as success_criteria_count_total
  from public.practice_scenarios ps
  where ps.program_id = tp.id
    and ps.unit_order = tu.unit_order
    and (ps.local_id is null or ps.local_id = lap.local_id)
) practice on true;

comment on view public.v_local_bot_config_units is
  'Post-MVP6 S2: Detalle por unidad del programa activo (knowledge por tipo, escenarios de practica). Read-only; tenant-scoped por RLS de tablas base.';

create or replace view public.v_local_bot_config_gaps
with (security_barrier = 'true') as
select
  u.local_id,
  u.program_id,
  u.unit_order,
  u.unit_title,
  (u.knowledge_count = 0) as is_missing_knowledge,
  (u.practice_scenarios_count = 0) as is_missing_practice
from public.v_local_bot_config_units u;

comment on view public.v_local_bot_config_gaps is
  'Post-MVP6 S2: Huecos deterministas del programa activo por local (sin knowledge o sin practica). Read-only; tenant-scoped por RLS de tablas base.';

commit;
