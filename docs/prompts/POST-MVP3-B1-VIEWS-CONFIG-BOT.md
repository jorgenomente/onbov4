# POST-MVP3 B1 VIEWS CONFIG BOT

## Contexto

Agregar views read-only para configuracion del bot (config actual, historial, coverage knowledge, programa activo) como sub-lote B.1.

## Prompt ejecutado

```txt
-- 20260127120000_post_mvp3_b1_views_config_bot.sql
-- Post-MVP 3 / Configuración del bot — Sub-lote B.1
-- DB-first: Views read-only de "config actual" (sin UI, sin writes)

set check_function_bodies = off;

begin;

-- -------------------------------------------------------------------
-- 1) Config vigente por programa (latest final_evaluation_configs)
-- -------------------------------------------------------------------
drop view if exists public.v_org_program_final_eval_config_current;

create view public.v_org_program_final_eval_config_current
with (security_barrier = true)
as
select
  tp.id as program_id,
  tp.org_id as org_id,
  tp.local_id as program_local_id,
  tp.name as program_name,
  tp.is_active as program_is_active,

  fec.id as config_id,
  fec.total_questions,
  fec.roleplay_ratio,
  fec.min_global_score,
  fec.must_pass_units,
  fec.questions_per_unit,
  fec.max_attempts,
  fec.cooldown_hours,
  fec.created_at as config_created_at
from public.training_programs tp
left join (
  select distinct on (program_id)
    id,
    program_id,
    total_questions,
    roleplay_ratio,
    min_global_score,
    must_pass_units,
    questions_per_unit,
    max_attempts,
    cooldown_hours,
    created_at
  from public.final_evaluation_configs
  order by program_id, created_at desc
) fec
  on fec.program_id = tp.id;

comment on view public.v_org_program_final_eval_config_current is
'Post-MVP3 B.1: Config vigente de evaluación final por programa (latest by created_at). Read-only; tenant-scoped por RLS de tablas base.';


-- -------------------------------------------------------------------
-- 2) Historial de configs por programa
-- -------------------------------------------------------------------
drop view if exists public.v_org_program_final_eval_config_history;

create view public.v_org_program_final_eval_config_history
with (security_barrier = true)
as
select
  tp.id as program_id,
  tp.org_id as org_id,
  tp.local_id as program_local_id,
  tp.name as program_name,
  tp.is_active as program_is_active,

  fec.id as config_id,
  fec.total_questions,
  fec.roleplay_ratio,
  fec.min_global_score,
  fec.must_pass_units,
  fec.questions_per_unit,
  fec.max_attempts,
  fec.cooldown_hours,
  fec.created_at as config_created_at
from public.final_evaluation_configs fec
join public.training_programs tp
  on tp.id = fec.program_id
order by
  tp.id,
  fec.created_at desc;

comment on view public.v_org_program_final_eval_config_history is
'Post-MVP3 B.1: Historial completo de configs de evaluación final por programa. Read-only; tenant-scoped por RLS.';


-- -------------------------------------------------------------------
-- 3) Coverage de knowledge por unidad (detecta unidades sin knowledge mapeado)
--    Nota: refleja lo visible para el rol actual (RLS). Para referente/aprendiz,
--    incluye org-level + su local; para admin_org incluye todo lo de la org.
-- -------------------------------------------------------------------
drop view if exists public.v_org_program_unit_knowledge_coverage;

create view public.v_org_program_unit_knowledge_coverage
with (security_barrier = true)
as
select
  tp.id as program_id,
  tp.org_id as org_id,
  tp.local_id as program_local_id,
  tp.name as program_name,

  tu.id as unit_id,
  tu.unit_order,
  tu.title as unit_title,

  count(ukm.knowledge_id) as knowledge_total,
  count(ki.id) filter (where ki.local_id is null) as knowledge_org_scoped,
  count(ki.id) filter (where ki.local_id is not null) as knowledge_local_scoped,

  (count(ukm.knowledge_id) = 0) as is_missing_knowledge_mapping
from public.training_programs tp
join public.training_units tu
  on tu.program_id = tp.id
left join public.unit_knowledge_map ukm
  on ukm.unit_id = tu.id
left join public.knowledge_items ki
  on ki.id = ukm.knowledge_id
group by
  tp.id, tp.org_id, tp.local_id, tp.name,
  tu.id, tu.unit_order, tu.title
order by
  tp.id,
  tu.unit_order asc;

comment on view public.v_org_program_unit_knowledge_coverage is
'Post-MVP3 B.1: Coverage de knowledge por unidad (counts + flag is_missing_knowledge_mapping). Read-only; tenant-scoped por RLS.';


-- -------------------------------------------------------------------
-- 4) Programa activo por local (coherencia operativa / observabilidad)
-- -------------------------------------------------------------------
drop view if exists public.v_org_local_active_programs;

create view public.v_org_local_active_programs
with (security_barrier = true)
as
select
  l.id as local_id,
  l.org_id as org_id,
  l.name as local_name,

  lap.program_id,
  tp.name as program_name,
  tp.local_id as program_local_id,
  tp.is_active as program_is_active,
  lap.created_at as activated_at
from public.locals l
join public.local_active_programs lap
  on lap.local_id = l.id
join public.training_programs tp
  on tp.id = lap.program_id;

comment on view public.v_org_local_active_programs is
'Post-MVP3 B.1: Programa activo por local (local_active_programs + locals + training_programs). Read-only; tenant-scoped por RLS.';

commit;
```

Resultado esperado

Crear migracion con views read-only para configuracion del bot.

Notas (opcional)

Sin notas.
