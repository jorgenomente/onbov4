-- Fix: asegurar retorno de filas en RPCs create/disable practice_scenario

begin;

create or replace function public.create_practice_scenario(
  p_program_id uuid,
  p_unit_order integer,
  p_title text,
  p_instructions text,
  p_success_criteria text[] default null,
  p_difficulty integer default 1,
  p_local_id uuid default null
) returns table (id uuid, created_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_org_id uuid;
  v_program_org_id uuid;
  v_program_local_id uuid;
  v_effective_local_id uuid;
  v_difficulty integer;
begin
  perform set_config('row_security', 'on', true);

  v_role := public.current_role();
  if v_role not in ('admin_org', 'superadmin') then
    raise exception 'forbidden: role % cannot create practice scenario', v_role
      using errcode = '42501';
  end if;

  v_org_id := public.current_org_id();
  if v_org_id is null then
    raise exception 'missing org context'
      using errcode = '22023';
  end if;

  if p_program_id is null then
    raise exception 'program_id is required'
      using errcode = '22004';
  end if;

  select tp.org_id, tp.local_id
    into v_program_org_id, v_program_local_id
  from public.training_programs tp
  where tp.id = p_program_id;

  if v_program_org_id is null then
    raise exception 'program not found'
      using errcode = '22023';
  end if;

  if v_program_org_id <> v_org_id and v_role <> 'superadmin' then
    raise exception 'program does not belong to your org'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.training_units tu
    where tu.program_id = p_program_id
      and tu.unit_order = p_unit_order
  ) then
    raise exception 'not_found: unit_order % not in program_id %', p_unit_order, p_program_id
      using errcode = '22023';
  end if;

  if coalesce(btrim(p_title), '') = '' then
    raise exception 'invalid: title is required'
      using errcode = '22004';
  end if;

  if coalesce(btrim(p_instructions), '') = '' then
    raise exception 'invalid: instructions are required'
      using errcode = '22004';
  end if;

  v_difficulty := coalesce(p_difficulty, 1);
  if v_difficulty < 1 or v_difficulty > 5 then
    raise exception 'invalid: difficulty must be between 1 and 5'
      using errcode = '22023';
  end if;

  if v_role = 'admin_org' then
    v_effective_local_id := null;
  else
    if p_local_id is not null then
      if not exists (
        select 1
        from public.locals l
        where l.id = p_local_id
          and l.org_id = v_program_org_id
      ) then
        raise exception 'invalid: local_id % not in program org scope', p_local_id
          using errcode = '42501';
      end if;
    end if;
    v_effective_local_id := p_local_id;
  end if;

  insert into public.practice_scenarios (
    org_id,
    local_id,
    program_id,
    unit_order,
    title,
    instructions,
    success_criteria,
    difficulty,
    is_enabled
  )
  values (
    v_program_org_id,
    v_effective_local_id,
    p_program_id,
    p_unit_order,
    btrim(p_title),
    p_instructions,
    coalesce(p_success_criteria, array[]::text[]),
    v_difficulty,
    true
  )
  returning public.practice_scenarios.id, public.practice_scenarios.created_at
  into id, created_at;

  insert into public.practice_scenario_change_events (
    org_id,
    local_id,
    scenario_id,
    actor_user_id,
    event_type,
    payload
  )
  values (
    v_program_org_id,
    v_effective_local_id,
    id,
    auth.uid(),
    'created',
    jsonb_build_object(
      'program_id', p_program_id,
      'unit_order', p_unit_order,
      'difficulty', v_difficulty
    )
  );

  return query select id, created_at;
end;
$$;

comment on function public.create_practice_scenario(uuid, integer, text, text, text[], integer, uuid) is
  'Post-MVP6 S4 fix: returns row (id, created_at). Admin Org: org-level only; superadmin: org/local.';

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

  update public.practice_scenarios
    set is_enabled = false
  where id = p_scenario_id;

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
  'Post-MVP6 S4 fix: returns row (id, disabled_at). Admin Org: org-level only; superadmin: org/local.';

commit;
