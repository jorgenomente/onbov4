-- Post-MVP6 Sub-lote 3.1: disable practice_scenarios + audit events (append-only)

begin;

-- A) is_enabled flag
alter table public.practice_scenarios
  add column if not exists is_enabled boolean not null default true;

comment on column public.practice_scenarios.is_enabled is
  'Post-MVP6 S3.1: soft-disable flag for practice_scenarios (true = enabled).';

-- B) Audit table (append-only)
create table if not exists public.practice_scenario_change_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  local_id uuid null,
  scenario_id uuid not null references public.practice_scenarios(id) on delete restrict,
  actor_user_id uuid null,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint practice_scenario_change_events_event_type_check check (event_type in ('created', 'disabled', 'enabled'))
);

comment on table public.practice_scenario_change_events is
  'Post-MVP6 S3.1: audit append-only for practice_scenarios create/disable.';
comment on column public.practice_scenario_change_events.event_type is
  'created | disabled | enabled (future).';
comment on column public.practice_scenario_change_events.payload is
  'Payload JSON con contexto minimo (program_id, unit_order, difficulty, reason).';

create index if not exists practice_scenario_change_events_org_created_idx
  on public.practice_scenario_change_events (org_id, created_at desc);

create index if not exists practice_scenario_change_events_scenario_created_idx
  on public.practice_scenario_change_events (scenario_id, created_at desc);

alter table public.practice_scenario_change_events enable row level security;

-- Append-only guard
do $$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgname = 'trg_practice_scenario_change_events_prevent_update'
  ) then
    create trigger trg_practice_scenario_change_events_prevent_update
    before update or delete on public.practice_scenario_change_events
    for each row execute function public.prevent_update_delete();
  end if;

  -- C) RLS policies for audit events
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'practice_scenario_change_events'
      and policyname = 'practice_scenario_change_events_select_superadmin'
  ) then
    create policy practice_scenario_change_events_select_superadmin
    on public.practice_scenario_change_events
    for select
    using (public.current_role() = 'superadmin');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'practice_scenario_change_events'
      and policyname = 'practice_scenario_change_events_select_admin_org'
  ) then
    create policy practice_scenario_change_events_select_admin_org
    on public.practice_scenario_change_events
    for select
    using (
      public.current_role() = 'admin_org'
      and org_id = public.current_org_id()
    );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'practice_scenario_change_events'
      and policyname = 'practice_scenario_change_events_select_referente'
  ) then
    create policy practice_scenario_change_events_select_referente
    on public.practice_scenario_change_events
    for select
    using (
      public.current_role() = 'referente'
      and local_id = public.current_local_id()
    );
  end if;

  -- No policy for aprendiz (blocked by default).

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'practice_scenario_change_events'
      and policyname = 'practice_scenario_change_events_insert_superadmin'
  ) then
    create policy practice_scenario_change_events_insert_superadmin
    on public.practice_scenario_change_events
    for insert
    with check (
      public.current_role() = 'superadmin'
      and actor_user_id = auth.uid()
    );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'practice_scenario_change_events'
      and policyname = 'practice_scenario_change_events_insert_admin_org'
  ) then
    create policy practice_scenario_change_events_insert_admin_org
    on public.practice_scenario_change_events
    for insert
    with check (
      public.current_role() = 'admin_org'
      and org_id = public.current_org_id()
      and local_id is null
      and actor_user_id = auth.uid()
    );
  end if;
end
$$;

-- D) Update create_practice_scenario to emit audit event
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
  v_scenario_local_id uuid;
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

  v_scenario_local_id := case when v_role = 'admin_org' then null else p_local_id end;

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
    v_scenario_local_id,
    p_program_id,
    p_unit_order,
    v_title,
    v_difficulty,
    v_instructions,
    coalesce(p_success_criteria, '{}'::text[])
  )
  returning practice_scenarios.id, practice_scenarios.created_at
    into id, created_at;

  insert into public.practice_scenario_change_events (
    org_id,
    local_id,
    scenario_id,
    actor_user_id,
    event_type,
    payload
  ) values (
    v_program_org_id,
    v_scenario_local_id,
    id,
    auth.uid(),
    'created',
    jsonb_build_object(
      'program_id', p_program_id,
      'unit_order', p_unit_order,
      'difficulty', v_difficulty
    )
  );

  return;
end;
$$;

comment on function public.create_practice_scenario(
  uuid, integer, text, text, text[], integer, uuid
) is
  'Post-MVP6 S3.1: create-only practice_scenarios + audit event. Admin Org: org-level only (local_id NULL). Superadmin: org/local. Validates program + unit_order + difficulty.';

-- E) disable RPC
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
  ) values (
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

  return;
end;
$$;

comment on function public.disable_practice_scenario(uuid, text) is
  'Post-MVP6 S3.1: disable (soft) practice_scenarios + audit event. Admin Org: org-level only. Superadmin: org/local.';

-- Update policies for practice_scenarios (idempotent)
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'practice_scenarios'
      and policyname = 'practice_scenarios_update_superadmin'
  ) then
    create policy practice_scenarios_update_superadmin
      on public.practice_scenarios
      for update
      using (public.current_role() = 'superadmin')
      with check (public.current_role() = 'superadmin');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'practice_scenarios'
      and policyname = 'practice_scenarios_update_admin_org'
  ) then
    create policy practice_scenarios_update_admin_org
      on public.practice_scenarios
      for update
      using (
        public.current_role() = 'admin_org'
        and org_id = public.current_org_id()
        and local_id is null
      )
      with check (
        public.current_role() = 'admin_org'
        and org_id = public.current_org_id()
        and local_id is null
      );
  end if;
end
$$;

-- Filter views to enabled scenarios only
create or replace view public.v_local_bot_config_summary
with (security_barrier = 'true') as
select
  lap.local_id,
  l.org_id,
  tp.id as active_program_id,
  tp.name as active_program_name,
  coalesce(units.total_units, 0)::integer as total_units,
  fec.config_id as current_final_eval_config_id,
  fec.total_questions as final_eval_total_questions,
  fec.roleplay_ratio,
  fec.min_global_score,
  fec.must_pass_units,
  fec.questions_per_unit,
  fec.max_attempts,
  fec.cooldown_hours,
  coalesce(knowledge.total_knowledge_items, 0)::integer as total_knowledge_items_active_program,
  coalesce(practice.total_practice_scenarios, 0)::integer as total_practice_scenarios_active_program,
  knowledge.knowledge_count_by_type
from public.local_active_programs lap
join public.locals l on l.id = lap.local_id
join public.training_programs tp on tp.id = lap.program_id
left join lateral (
  select count(*) as total_units
  from public.training_units tu
  where tu.program_id = tp.id
) units on true
left join lateral (
  select
    fec_inner.id as config_id,
    fec_inner.total_questions,
    fec_inner.roleplay_ratio,
    fec_inner.min_global_score,
    fec_inner.must_pass_units,
    fec_inner.questions_per_unit,
    fec_inner.max_attempts,
    fec_inner.cooldown_hours
  from public.final_evaluation_configs fec_inner
  where fec_inner.program_id = tp.id
  order by fec_inner.created_at desc
  limit 1
) fec on true
left join lateral (
  select
    count(distinct ki.id) as total_knowledge_items,
    jsonb_build_object(
      'concepto', count(distinct ki.id) filter (where ki.content_type = 'concepto'),
      'procedimiento', count(distinct ki.id) filter (where ki.content_type = 'procedimiento'),
      'regla', count(distinct ki.id) filter (where ki.content_type = 'regla'),
      'guion', count(distinct ki.id) filter (where ki.content_type = 'guion'),
      'sin_tipo', count(distinct ki.id) filter (where ki.content_type is null)
    ) as knowledge_count_by_type
  from public.training_units tu
  join public.unit_knowledge_map ukm on ukm.unit_id = tu.id
  join public.knowledge_items ki on ki.id = ukm.knowledge_id
  where tu.program_id = tp.id
    and ki.is_enabled = true
    and (ki.local_id is null or ki.local_id = lap.local_id)
) knowledge on true
left join lateral (
  select
    count(*) as total_practice_scenarios
  from public.practice_scenarios ps
  where ps.program_id = tp.id
    and ps.is_enabled = true
    and (ps.local_id is null or ps.local_id = lap.local_id)
) practice on true;

comment on view public.v_local_bot_config_summary is
  'Post-MVP6 S2: Resumen config del bot por local (programa activo, config final vigente, coverage knowledge y escenarios). Read-only; tenant-scoped por RLS de tablas base.';

create or replace view public.v_local_bot_config_units
with (security_barrier = 'true') as
select
  lap.local_id,
  tp.id as program_id,
  tu.unit_order,
  tu.title as unit_title,
  coalesce(knowledge.knowledge_count, 0)::integer as knowledge_count,
  knowledge.knowledge_count_by_type,
  coalesce(practice.practice_scenarios_count, 0)::integer as practice_scenarios_count,
  practice.practice_difficulty_min,
  practice.practice_difficulty_max,
  coalesce(practice.success_criteria_count_total, 0)::integer as success_criteria_count_total
from public.local_active_programs lap
join public.training_programs tp on tp.id = lap.program_id
join public.training_units tu on tu.program_id = tp.id
left join lateral (
  select
    count(*) as knowledge_count,
    jsonb_build_object(
      'concepto', count(*) filter (where ki.content_type = 'concepto'),
      'procedimiento', count(*) filter (where ki.content_type = 'procedimiento'),
      'regla', count(*) filter (where ki.content_type = 'regla'),
      'guion', count(*) filter (where ki.content_type = 'guion'),
      'sin_tipo', count(*) filter (where ki.content_type is null)
    ) as knowledge_count_by_type
  from public.unit_knowledge_map ukm
  join public.knowledge_items ki on ki.id = ukm.knowledge_id
  where ukm.unit_id = tu.id
    and ki.is_enabled = true
    and (ki.local_id is null or ki.local_id = lap.local_id)
) knowledge on true
left join lateral (
  select
    count(*) as practice_scenarios_count,
    min(ps.difficulty) as practice_difficulty_min,
    max(ps.difficulty) as practice_difficulty_max,
    sum(coalesce(array_length(ps.success_criteria, 1), 0)) as success_criteria_count_total
  from public.practice_scenarios ps
  where ps.program_id = tp.id
    and ps.unit_order = tu.unit_order
    and ps.is_enabled = true
    and (ps.local_id is null or ps.local_id = lap.local_id)
) practice on true;

comment on view public.v_local_bot_config_units is
  'Post-MVP6 S2: Detalle por unidad del programa activo (knowledge por tipo, escenarios de practica). Read-only; tenant-scoped por RLS de tablas base.';

create or replace view public.v_local_bot_config_gaps
with (security_barrier = 'true') as
select
  u.local_id,
  u.program_id,
  u.unit_order,
  u.unit_title,
  (u.knowledge_count = 0) as is_missing_knowledge,
  (u.practice_scenarios_count = 0) as is_missing_practice
from public.v_local_bot_config_units u;

comment on view public.v_local_bot_config_gaps is
  'Post-MVP6 S2: Huecos deterministas del programa activo por local (sin knowledge o sin practica). Read-only; tenant-scoped por RLS de tablas base.';

grant all on function public.create_practice_scenario(
  uuid, integer, text, text, text[], integer, uuid
) to anon;

grant all on function public.create_practice_scenario(
  uuid, integer, text, text, text[], integer, uuid
) to authenticated;

grant all on function public.create_practice_scenario(
  uuid, integer, text, text, text[], integer, uuid
) to service_role;

grant all on function public.disable_practice_scenario(uuid, text) to anon;

grant all on function public.disable_practice_scenario(uuid, text) to authenticated;

grant all on function public.disable_practice_scenario(uuid, text) to service_role;

commit;
