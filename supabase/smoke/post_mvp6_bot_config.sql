-- Post-MVP6 Bot Config Smoke (CLI)
-- Requiere: local_active_programs + training_units + RPCs create/disable + views S2
-- Ejecutar con psql contra DB local.

\set ON_ERROR_STOP on

-- 0) Seleccionar un local "real" (el primero que tenga programa activo)
do $$
declare
  v_local_id uuid;
  v_program_id uuid;
  v_unit_order int;
  v_created record;
begin
  -- Elegimos un local con active program
  select lap.local_id, lap.program_id
    into v_local_id, v_program_id
  from public.local_active_programs lap
  order by lap.created_at desc
  limit 1;

  if v_local_id is null or v_program_id is null then
    raise exception 'No hay local_active_programs. Seed incompleto o no seteaste programa activo.';
  end if;

  -- Elegimos un unit_order valido para ese programa
  select tu.unit_order
    into v_unit_order
  from public.training_units tu
  where tu.program_id = v_program_id
  order by tu.unit_order asc
  limit 1;

  if v_unit_order is null then
    raise exception 'Programa % no tiene training_units', v_program_id;
  end if;

  raise notice 'Selected local_id=% program_id=% unit_order=%', v_local_id, v_program_id, v_unit_order;

  -- 1) Simular admin_org (claims) y CREATE escenario (debe funcionar)
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', (select user_id from public.profiles where role = 'admin_org' order by created_at desc limit 1),
      'role', 'admin_org',
      'local_id', v_local_id
    )::text,
    true
  );

  select *
    into v_created
  from public.create_practice_scenario(
    v_program_id,
    v_unit_order,
    'Smoke escenario',
    'Instrucciones smoke',
    array['criterio 1','criterio 2'],
    2,
    null
  );

  if v_created.id is null then
    raise exception 'create_practice_scenario no devolvio id';
  end if;

  raise notice 'Created scenario id=% at %', v_created.id, v_created.created_at;

  -- 2) Verificar que aparece en views (conteos > 0)
  raise notice 'Summary:';
  perform 1 from public.v_local_bot_config_summary s where s.local_id = v_local_id;

  raise notice 'Units:';
  perform 1 from public.v_local_bot_config_units u where u.local_id = v_local_id and u.unit_order = v_unit_order;

  -- 3) DISABLE escenario (debe funcionar)
  perform public.disable_practice_scenario(v_created.id, 'smoke disable');

  -- 4) Verificar que is_enabled=false
  if not exists (
    select 1 from public.practice_scenarios ps
    where ps.id = v_created.id and ps.is_enabled = false
  ) then
    raise exception 'disable_practice_scenario no deshabilito el escenario %', v_created.id;
  end if;

  -- 5) Verificar audit events (created + disabled)
  if (select count(*) from public.practice_scenario_change_events e where e.scenario_id = v_created.id) < 2 then
    raise exception 'Faltan eventos de auditoria para scenario %', v_created.id;
  end if;

  raise notice 'OK: create + disable + audit';

  -- 6) Negativo: referente no puede disable (debe fallar)
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', (select user_id from public.profiles where role = 'referente' order by created_at desc limit 1),
      'role', 'referente',
      'local_id', v_local_id
    )::text,
    true
  );

  begin
    perform public.disable_practice_scenario(v_created.id, 'should fail');
    raise exception 'ERROR: referente pudo deshabilitar (no deberia)';
  exception
    when others then
      raise notice 'OK: referente bloqueado (expected error: %)', sqlerrm;
  end;

end $$;

-- 7) Output rapido legible (opcional)
select local_id, active_program_name, total_units, total_practice_scenarios_active_program
from public.v_local_bot_config_summary
order by local_id
limit 10;
