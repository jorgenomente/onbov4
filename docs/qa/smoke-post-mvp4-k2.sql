-- Smoke: Post-MVP4 K2 (create + map knowledge)
-- Objetivo: crear knowledge_item y mapearlo a una unidad via RPC; validar inserts y audit.

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
-- Resolver program_id + unit_id demo
-- ------------------------------------------------------------
do $$
declare
  v_program_id uuid;
  v_unit_id uuid;
begin
  select tp.id
    into v_program_id
  from public.training_programs tp
  order by tp.created_at desc
  limit 1;

  if v_program_id is null then
    raise exception 'smoke-k2: no training_programs found';
  end if;

  select tu.id
    into v_unit_id
  from public.training_units tu
  where tu.program_id = v_program_id
  order by tu.unit_order asc
  limit 1;

  if v_unit_id is null then
    raise exception 'smoke-k2: no training_units for program_id=%', v_program_id;
  end if;

  perform set_config('app.smoke_program_id', v_program_id::text, false);
  perform set_config('app.smoke_unit_id', v_unit_id::text, false);
end $$;

set role authenticated;

-- ------------------------------------------------------------
-- RPC create_and_map_knowledge_item
-- ------------------------------------------------------------
create temporary table tmp_k2 (knowledge_id uuid);

insert into tmp_k2 (knowledge_id)
select public.create_and_map_knowledge_item(
  current_setting('app.smoke_program_id')::uuid,
  current_setting('app.smoke_unit_id')::uuid,
  'Smoke K2 ' || to_char(now(), 'YYYYMMDDHH24MISS'),
  'Smoke content K2 ' || now()::text,
  'org',
  null,
  'smoke: k2 create_and_map'
);

-- Verificar knowledge_items
select
  ki.id,
  ki.org_id,
  ki.local_id,
  ki.title,
  ki.is_enabled,
  ki.created_at
from public.knowledge_items ki
join tmp_k2 t on t.knowledge_id = ki.id;

-- Verificar mapping
select
  ukm.unit_id,
  ukm.knowledge_id
from public.unit_knowledge_map ukm
join tmp_k2 t on t.knowledge_id = ukm.knowledge_id;

-- Verificar audit
select
  kce.id,
  kce.action,
  kce.program_id,
  kce.unit_id,
  kce.unit_order,
  kce.knowledge_id,
  kce.title,
  kce.reason,
  kce.created_at
from public.knowledge_change_events kce
join tmp_k2 t on t.knowledge_id = kce.knowledge_id
order by kce.created_at desc
limit 1;
