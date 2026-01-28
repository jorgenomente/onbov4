-- Post-MVP6 Sub-lote 3: create-only practice_scenarios (RPC + RLS)

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
  v_local_org_id uuid;
  v_title text;
  v_instructions text;
  v_difficulty integer;
begin
  perform set_config('row_security', 'on', true);

  v_role := public.current_role();
  v_org_id := public.current_org_id();

  if v_role not in ('admin_org', 'superadmin') then
    raise exception 'forbidden: role % cannot create practice scenario', v_role
      using errcode = '42501';
  end if;

  select tp.org_id, tp.local_id
    into v_program_org_id, v_program_local_id
  from public.training_programs tp
  where tp.id = p_program_id;

  if v_program_org_id is null then
    raise exception 'not_found: program_id % not found', p_program_id
      using errcode = '22023';
  end if;

  if v_role = 'admin_org' then
    if v_program_org_id <> v_org_id then
      raise exception 'not_found: program_id % not in org scope', p_program_id
        using errcode = '22023';
    end if;
    if v_program_local_id is not null then
      raise exception 'invalid: program_id % is local-specific and not allowed for admin_org', p_program_id
        using errcode = '22023';
    end if;
    if p_local_id is not null then
      raise exception 'invalid: local_id must be null for admin_org'
        using errcode = '22023';
    end if;
  end if;

  if p_unit_order is null or p_unit_order <= 0 then
    raise exception 'invalid: unit_order must be >= 1'
      using errcode = '22023';
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

  v_title := trim(coalesce(p_title, ''));
  v_instructions := trim(coalesce(p_instructions, ''));

  if length(v_title) = 0 then
    raise exception 'invalid: title is required'
      using errcode = '22023';
  end if;

  if length(v_instructions) = 0 then
    raise exception 'invalid: instructions are required'
      using errcode = '22023';
  end if;

  v_difficulty := coalesce(p_difficulty, 1);
  if v_difficulty < 1 or v_difficulty > 5 then
    raise exception 'invalid: difficulty must be between 1 and 5'
      using errcode = '22023';
  end if;

  if p_local_id is not null then
    select l.org_id
      into v_local_org_id
    from public.locals l
    where l.id = p_local_id;

    if v_local_org_id is null then
      raise exception 'not_found: local_id % not found', p_local_id
        using errcode = '22023';
    end if;
    if v_local_org_id <> v_program_org_id then
      raise exception 'invalid: local_id % not in program org scope', p_local_id
        using errcode = '22023';
    end if;
  end if;

  insert into public.practice_scenarios (
    org_id,
    local_id,
    program_id,
    unit_order,
    title,
    difficulty,
    instructions,
    success_criteria
  ) values (
    v_program_org_id,
    case when v_role = 'admin_org' then null else p_local_id end,
    p_program_id,
    p_unit_order,
    v_title,
    v_difficulty,
    v_instructions,
    coalesce(p_success_criteria, '{}'::text[])
  )
  returning practice_scenarios.id, practice_scenarios.created_at
    into id, created_at;

  return;
end;
$$;

comment on function public.create_practice_scenario(
  uuid, integer, text, text, text[], integer, uuid
) is
  'Post-MVP6 S3: create-only practice_scenarios. Admin Org: org-level only (local_id NULL). Superadmin: org/local. Validates program + unit_order + difficulty.';

-- RLS INSERT policies (idempotent)
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'practice_scenarios'
      and policyname = 'practice_scenarios_insert_superadmin'
  ) then
    create policy practice_scenarios_insert_superadmin
      on public.practice_scenarios
      for insert
      with check (public.current_role() = 'superadmin');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'practice_scenarios'
      and policyname = 'practice_scenarios_insert_admin_org'
  ) then
    create policy practice_scenarios_insert_admin_org
      on public.practice_scenarios
      for insert
      with check (
        public.current_role() = 'admin_org'
        and org_id = public.current_org_id()
        and local_id is null
        and exists (
          select 1
          from public.training_programs tp
          where tp.id = practice_scenarios.program_id
            and tp.org_id = public.current_org_id()
            and tp.local_id is null
        )
      );
  end if;
end
$$;

grant all on function public.create_practice_scenario(
  uuid, integer, text, text, text[], integer, uuid
) to anon;

grant all on function public.create_practice_scenario(
  uuid, integer, text, text, text[], integer, uuid
) to authenticated;

grant all on function public.create_practice_scenario(
  uuid, integer, text, text, text[], integer, uuid
) to service_role;

commit;
