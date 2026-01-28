-- Fix: resolve ambiguous id in disable_practice_scenario

begin;

create or replace function public.disable_practice_scenario(
  p_scenario_id uuid,
  p_reason text default null
) returns table (id uuid, disabled_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_org_id uuid;
  v_scenario_org_id uuid;
  v_scenario_local_id uuid;
  v_program_id uuid;
  v_unit_order integer;
  v_difficulty integer;
  v_is_enabled boolean;
begin
  perform set_config('row_security', 'on', true);

  v_role := public.current_role();
  v_org_id := public.current_org_id();

  if v_role not in ('admin_org', 'superadmin') then
    raise exception 'forbidden: role % cannot disable practice scenario', v_role
      using errcode = '42501';
  end if;

  select ps.org_id, ps.local_id, ps.program_id, ps.unit_order, ps.difficulty, ps.is_enabled
    into v_scenario_org_id, v_scenario_local_id, v_program_id, v_unit_order, v_difficulty, v_is_enabled
  from public.practice_scenarios ps
  where ps.id = p_scenario_id;

  if v_scenario_org_id is null then
    raise exception 'not_found: scenario_id % not found', p_scenario_id
      using errcode = '22023';
  end if;

  if v_role = 'admin_org' then
    if v_scenario_org_id <> v_org_id then
      raise exception 'not_found: scenario_id % not in org scope', p_scenario_id
        using errcode = '22023';
    end if;
    if v_scenario_local_id is not null then
      raise exception 'invalid: scenario_id % is local-specific and not allowed for admin_org', p_scenario_id
        using errcode = '22023';
    end if;
  end if;

  update public.practice_scenarios ps
    set is_enabled = false
  where ps.id = p_scenario_id;

  disabled_at := now();
  id := p_scenario_id;

  insert into public.practice_scenario_change_events (
    org_id,
    local_id,
    scenario_id,
    actor_user_id,
    event_type,
    payload
  )
  values (
    v_scenario_org_id,
    v_scenario_local_id,
    p_scenario_id,
    auth.uid(),
    'disabled',
    jsonb_build_object(
      'reason', p_reason,
      'program_id', v_program_id,
      'unit_order', v_unit_order,
      'difficulty', v_difficulty,
      'was_enabled', v_is_enabled
    )
  );

  return query select id, disabled_at;
end;
$$;

comment on function public.disable_practice_scenario(uuid, text) is
  'Post-MVP6 S4 fix: resolve ambiguous id in disable_practice_scenario update.';

commit;
