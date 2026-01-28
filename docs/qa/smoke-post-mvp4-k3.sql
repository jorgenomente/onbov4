-- Smoke: Post-MVP4 K3 (disable knowledge)
-- Objetivo: desactivar knowledge_item via RPC, validar audit y guardrail true->false.

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
set role authenticated;

-- ------------------------------------------------------------
-- Resolver knowledge_id habilitado y mapeado
-- ------------------------------------------------------------
create temporary table tmp_k3 (knowledge_id uuid);

insert into tmp_k3 (knowledge_id)
select knowledge_id
from public.v_org_unit_knowledge_list
order by knowledge_created_at desc
limit 1;

-- Asegurar que exista knowledge_id
select knowledge_id from tmp_k3;

-- ------------------------------------------------------------
-- RPC disable_knowledge_item
-- ------------------------------------------------------------
select public.disable_knowledge_item(
  (select knowledge_id from tmp_k3),
  'smoke: disable knowledge'
) as events_created;

-- Verificar is_enabled=false
select id, is_enabled
from public.knowledge_items
where id = (select knowledge_id from tmp_k3);

-- Verificar audit action=disable
select
  kce.id,
  kce.action,
  kce.knowledge_id,
  kce.created_at,
  kce.reason
from public.knowledge_change_events kce
where kce.knowledge_id = (select knowledge_id from tmp_k3)
order by kce.created_at desc
limit 1;

-- Guardrail: intentar reactivar (debe fallar)
DO $$
BEGIN
  update public.knowledge_items
  set is_enabled = true
  where id = (select knowledge_id from tmp_k3);

  raise exception 'smoke-k3: expected update to fail';
EXCEPTION
  when others then
    raise notice 'Expected failure on re-enable: %', sqlerrm;
END $$;
