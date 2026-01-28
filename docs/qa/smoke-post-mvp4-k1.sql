-- Smoke: Post-MVP4 K1 (views read-only)
-- Objetivo: validar que las views K1 responden sin error para un programa demo.

-- ------------------------------------------------------------
-- Auth: admin_org (por profiles)
-- ------------------------------------------------------------
set role postgres;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', (select user_id from public.profiles where role = 'admin_org' order by created_at desc limit 1),
    'role', 'admin_org'
  )::text,
  false
);

-- ------------------------------------------------------------
-- Resolver program_id demo
-- ------------------------------------------------------------
do $$
declare
  v_program_id uuid;
begin
  select tp.id
    into v_program_id
  from public.training_programs tp
  order by tp.created_at desc
  limit 1;

  if v_program_id is null then
    raise exception 'smoke-k1: no training_programs found';
  end if;

  perform set_config('app.smoke_program_id', v_program_id::text, false);
end $$;

set role authenticated;

-- ------------------------------------------------------------
-- K1 views
-- ------------------------------------------------------------
-- Coverage por unidad
select
  program_id,
  program_name,
  unit_id,
  unit_order,
  unit_title,
  total_knowledge_count,
  org_level_knowledge_count,
  local_level_knowledge_count,
  has_any_mapping,
  is_missing_mapping
from public.v_org_program_unit_knowledge_coverage
where program_id = current_setting('app.smoke_program_id')::uuid
order by unit_order
limit 10;

-- Resumen por programa
select
  program_id,
  program_name,
  total_units,
  units_missing_mapping,
  pct_units_missing_mapping,
  total_knowledge_mappings
from public.v_org_program_knowledge_gaps_summary
where program_id = current_setting('app.smoke_program_id')::uuid
limit 1;

-- Knowledge list (drill-down)
select
  program_id,
  program_name,
  unit_id,
  unit_order,
  knowledge_id,
  knowledge_title,
  knowledge_scope,
  knowledge_created_at
from public.v_org_unit_knowledge_list
where program_id = current_setting('app.smoke_program_id')::uuid
order by unit_order, knowledge_created_at desc
limit 10;
