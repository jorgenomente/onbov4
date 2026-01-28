# POST-MVP6 S4 fix: admin_org create practice_scenarios for local-specific program

## Contexto

Ajustar RPC y policy para permitir admin_org crear practice_scenarios ORG-level aunque el programa sea local-specific.

## Prompt ejecutado

```txt
tengo un error que dice program_id 6381856a-3e5c-43b4-afce-f83983418f29 is local-specific and not allowed for admin_org este es el fix sugerido -- supabase/migrations/20260128194500_post_mvp6_s4_fix_admin_org_create_scenario_local_specific_program.sql
-- Fix: permitir que admin_org cree practice_scenarios aunque el program_id sea local-specific.
-- Mantiene guardrail: admin_org SIEMPRE crea escenarios ORG-level (local_id NULL).

begin;

-- 1) Ajuste RLS: remover la condición "program org-level" del INSERT para admin_org
do $$
begin
  if exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename  = 'practice_scenarios'
      and policyname = 'practice_scenarios_insert_admin_org'
  ) then
    execute 'drop policy practice_scenarios_insert_admin_org on public.practice_scenarios';
  end if;
end $$;

create policy practice_scenarios_insert_admin_org
on public.practice_scenarios
for insert
to authenticated
with check (
  org_id = public.current_org_id()
  and local_id is null
);

comment on policy practice_scenarios_insert_admin_org on public.practice_scenarios is
  'Post-MVP6 S4 fix: admin_org puede insertar escenarios ORG-level (local_id NULL) para programas del org, incluso si el programa es local-specific.';

-- 2) Ajuste RPC: permitir program local-specific para admin_org (pero forzar local_id NULL)
create or replace function public.create_practice_scenario(
  p_program_id uuid,
  p_unit_order int,
  p_title text,
  p_instructions text,
  p_success_criteria text[] default null,
  p_difficulty int default 1,
  p_local_id uuid default null
)
returns table (id uuid, created_at timestamptz)
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
  v_difficulty int;
begin
  v_role := public.current_role(); -- patrón existente del repo
  if v_role not in ('admin_org', 'superadmin') then
    raise exception 'not allowed'
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

  -- Validar unit_order existe para el programa
  if not exists (
    select 1
    from public.training_units tu
    where tu.program_id = p_program_id
      and tu.unit_order = p_unit_order
  ) then
    raise exception 'unit_order % does not exist for program %', p_unit_order, p_program_id
      using errcode = '22023';
  end if;

  if coalesce(btrim(p_title), '') = '' then
    raise exception 'title is required'
      using errcode = '22004';
  end if;

  if coalesce(btrim(p_instructions), '') = '' then
    raise exception 'instructions is required'
      using errcode = '22004';
  end if;

  v_difficulty := coalesce(p_difficulty, 1);
  if v_difficulty < 1 or v_difficulty > 5 then
    raise exception 'difficulty must be between 1 and 5'
      using errcode = '22023';
  end if;

  -- Guardrails por rol
  if v_role = 'admin_org' then
    -- admin_org SIEMPRE ORG-level, aunque el programa sea local-specific
    v_effective_local_id := null;
  else
    -- superadmin puede setear local_id (si viene) pero debe pertenecer al org del programa
    if p_local_id is not null then
      if not exists (
        select 1
        from public.locals l
        where l.id = p_local_id
          and l.org_id = v_program_org_id
      ) then
        raise exception 'local_id % does not belong to program org', p_local_id
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

  -- Emitir evento audit "created" (tabla ya existe en S3.1)
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

  return next;
end;
$$;

comment on function public.create_practice_scenario(uuid,int,text,text,text[],int,uuid) is
  'Post-MVP6 S4 fix: admin_org puede crear escenarios ORG-level para programas local-specific; superadmin puede setear local_id.';

commit;
```

Resultado esperado

Admin Org puede crear practice_scenarios ORG-level aunque el program_id sea local-specific.
