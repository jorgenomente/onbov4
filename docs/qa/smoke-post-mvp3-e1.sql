-- docs/qa/smoke-post-mvp3-e1.sql
-- Post-MVP3 E.1 — Smoke DB-first (RLS real): set_local_active_program + auditoría
-- Requiere ejecutar como sesión authenticated con claims válidos (admin_org / referente).
-- Nota: en local, esto suele hacerse con psql + JWT claims.

-- ------------------------------------------------------------
-- A) DESCUBRIR IDs (solo lectura)
-- ------------------------------------------------------------

-- 1) Locals visibles (admin_org debería ver todos los de su org)
select l.id as local_id, l.name as local_name, l.org_id
from public.locals l
order by l.created_at desc
limit 10;

-- 2) Programs visibles por org (incluye org-level y local-specific)
select tp.id as program_id, tp.name, tp.org_id, tp.local_id, tp.is_active, tp.created_at
from public.training_programs tp
order by tp.created_at desc
limit 10;

-- 2.1) Locales + programas elegibles (org-level o local-specific)
select
  l.id as local_id,
  l.name as local_name,
  tp.id as program_id,
  tp.name as program_name,
  tp.local_id as program_local_id
from public.locals l
join public.training_programs tp
  on tp.org_id = l.org_id
 and (tp.local_id is null or tp.local_id = l.id)
order by l.name, tp.created_at desc;

-- 3) Estado actual del programa activo por local (view)
select *
from public.v_org_local_active_programs
order by activated_at desc
limit 20;

-- ------------------------------------------------------------
-- B) HAPPY PATH (admin_org): cambiar programa activo (UPSERT) + auditar
-- ------------------------------------------------------------
-- Reemplazar placeholders:
--   <LOCAL_UUID>
--   <PROGRAM_UUID_ELEGIBLE>

select public.set_local_active_program(
  '<LOCAL_UUID>'::uuid,
  '<PROGRAM_UUID_ELEGIBLE>'::uuid,
  'smoke: cambio manual E.1'
);

-- Verificar que cambió en la view
select
  local_id, local_name, program_id, program_name, program_is_active, activated_at
from public.v_org_local_active_programs
where local_id = '<LOCAL_UUID>'::uuid;

-- Verificar evento de auditoría (últimos 5 del local)
select
  id,
  created_at,
  org_id,
  local_id,
  from_program_id,
  to_program_id,
  changed_by_user_id,
  reason
from public.local_active_program_change_events
where local_id = '<LOCAL_UUID>'::uuid
order by created_at desc
limit 5;

-- ------------------------------------------------------------
-- C) GUARDRAILS: programa NO elegible para ese local => FAIL
-- ------------------------------------------------------------
-- Caso 1: program_id de OTRA ORG (si tenés seed cross-tenant)
-- Esperado: exception not_found / forbidden por validación + RLS.
-- select public.set_local_active_program('<LOCAL_UUID>'::uuid, '<PROGRAM_OTHER_ORG>'::uuid, 'smoke: should fail');

-- Caso 2: program local-specific de OTRO local dentro de la misma org (si existe)
-- Esperado: exception invalid/elegibility.
-- select public.set_local_active_program('<LOCAL_UUID>'::uuid, '<PROGRAM_OTHER_LOCAL>'::uuid, 'smoke: should fail');

-- ------------------------------------------------------------
-- D) RLS NEGATIVE: referente no puede escribir
-- ------------------------------------------------------------
-- Ejecutar este bloque estando autenticado como REFERENTE.
-- Esperado: error 42501 forbidden (por rol) o RLS violation.

-- select public.set_local_active_program(
--   '<LOCAL_UUID>'::uuid,
--   '<PROGRAM_UUID_ELEGIBLE>'::uuid,
--   'smoke: referente should fail'
-- );

-- ------------------------------------------------------------
-- E) APPEND-ONLY audit table: UPDATE/DELETE deben fallar
-- ------------------------------------------------------------
-- (admin_org o superadmin)
-- Esperado: trigger prevent_update_delete()

-- update public.local_active_program_change_events
-- set reason = reason
-- where id = (
--   select id from public.local_active_program_change_events
--   order by created_at desc
--   limit 1
-- );

-- delete from public.local_active_program_change_events
-- where id = (
--   select id from public.local_active_program_change_events
--   order by created_at desc
--   limit 1
-- );
