-- 20260128100000_post_mvp3_e1_local_active_program.sql
-- Post-MVP 3 / Sub-lote E.1: programa activo por local (Admin Org)
-- Incluye auditoria append-only + RPC set_local_active_program + RLS writes.

set check_function_bodies = off;

begin;

-- ------------------------------------------------------------
-- 1) Audit table (append-only)
-- ------------------------------------------------------------
create table if not exists public.local_active_program_change_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete restrict,
  local_id uuid not null references public.locals(id) on delete restrict,
  from_program_id uuid null references public.training_programs(id) on delete restrict,
  to_program_id uuid not null references public.training_programs(id) on delete restrict,
  changed_by_user_id uuid not null references public.profiles(user_id) on delete restrict,
  reason text null,
  created_at timestamptz not null default now()
);

create index if not exists local_active_program_change_events_local_id_idx
  on public.local_active_program_change_events (local_id);

create index if not exists local_active_program_change_events_created_at_idx
  on public.local_active_program_change_events (created_at desc);

alter table public.local_active_program_change_events enable row level security;

-- Append-only enforcement
create or replace function public.prevent_update_delete()
returns trigger
language plpgsql
as $$
begin
  raise exception 'UPDATE/DELETE not allowed on % (append-only).', tg_table_name
    using errcode = '42501';
end;
$$;

drop trigger if exists trg_local_active_program_change_events_prevent_update on public.local_active_program_change_events;

create trigger trg_local_active_program_change_events_prevent_update
before update or delete on public.local_active_program_change_events
for each row
execute function public.prevent_update_delete();

-- ------------------------------------------------------------
-- 2) RLS policies
-- ------------------------------------------------------------
-- local_active_programs INSERT/UPDATE for admin_org/superadmin
create policy local_active_programs_insert_admin_org
on public.local_active_programs
for insert
with check (
  exists (
    select 1
    from public.locals l
    join public.training_programs tp on tp.id = local_active_programs.program_id
    where l.id = local_active_programs.local_id
      and tp.org_id = l.org_id
      and (
        public.current_role() = 'superadmin'
        or (public.current_role() = 'admin_org' and l.org_id = public.current_org_id())
      )
  )
);

create policy local_active_programs_update_admin_org
on public.local_active_programs
for update
using (
  exists (
    select 1
    from public.locals l
    where l.id = local_active_programs.local_id
      and (
        public.current_role() = 'superadmin'
        or (public.current_role() = 'admin_org' and l.org_id = public.current_org_id())
      )
  )
)
with check (
  exists (
    select 1
    from public.locals l
    join public.training_programs tp on tp.id = local_active_programs.program_id
    where l.id = local_active_programs.local_id
      and tp.org_id = l.org_id
      and (
        public.current_role() = 'superadmin'
        or (public.current_role() = 'admin_org' and l.org_id = public.current_org_id())
      )
  )
);

-- local_active_program_change_events SELECT
create policy local_active_program_change_events_select_superadmin
on public.local_active_program_change_events
for select
using (public.current_role() = 'superadmin');

create policy local_active_program_change_events_select_admin_org
on public.local_active_program_change_events
for select
using (
  public.current_role() = 'admin_org'
  and org_id = public.current_org_id()
);

-- local_active_program_change_events INSERT
create policy local_active_program_change_events_insert_admin_org
on public.local_active_program_change_events
for insert
with check (
  public.current_role() = 'superadmin'
  or (public.current_role() = 'admin_org' and org_id = public.current_org_id())
);

-- ------------------------------------------------------------
-- 3) RPC set_local_active_program (security invoker)
-- ------------------------------------------------------------
create or replace function public.set_local_active_program(
  p_local_id uuid,
  p_program_id uuid,
  p_reason text default null
)
returns uuid
language plpgsql
as $$
declare
  v_role text;
  v_org_id uuid;
  v_from_program_id uuid;
  v_new_program_id uuid;
  v_local_org_id uuid;
  v_program_org_id uuid;
  v_program_local_id uuid;
begin
  v_role := public.current_role();
  v_org_id := public.current_org_id();

  if v_role not in ('admin_org', 'superadmin') then
    raise exception 'forbidden: role % cannot set active program', v_role
      using errcode = '42501';
  end if;

  select l.org_id into v_local_org_id
  from public.locals l
  where l.id = p_local_id;

  if v_local_org_id is null then
    raise exception 'not_found: local_id % not in org scope', p_local_id
      using errcode = '22023';
  end if;
  if v_role = 'admin_org' and v_local_org_id <> v_org_id then
    raise exception 'not_found: local_id % not in org scope', p_local_id
      using errcode = '22023';
  end if;

  select tp.org_id, tp.local_id into v_program_org_id, v_program_local_id
  from public.training_programs tp
  where tp.id = p_program_id;

  if v_program_org_id is null then
    raise exception 'not_found: program_id % not in org scope', p_program_id
      using errcode = '22023';
  end if;
  if v_role = 'admin_org' and v_program_org_id <> v_org_id then
    raise exception 'not_found: program_id % not in org scope', p_program_id
      using errcode = '22023';
  end if;
  if v_program_org_id <> v_local_org_id then
    raise exception 'invalid: program_id % not eligible for local_id %', p_program_id, p_local_id
      using errcode = '22023';
  end if;

  if v_program_local_id is not null and v_program_local_id <> p_local_id then
    raise exception 'invalid: program_id % not eligible for local_id %', p_program_id, p_local_id
      using errcode = '22023';
  end if;

  select lap.program_id into v_from_program_id
  from public.local_active_programs lap
  where lap.local_id = p_local_id;

  insert into public.local_active_programs (local_id, program_id, created_at)
  values (p_local_id, p_program_id, now())
  on conflict (local_id)
  do update set program_id = excluded.program_id;

  v_new_program_id := p_program_id;

  insert into public.local_active_program_change_events (
    org_id,
    local_id,
    from_program_id,
    to_program_id,
    changed_by_user_id,
    reason
  )
  values (
    v_local_org_id,
    p_local_id,
    v_from_program_id,
    v_new_program_id,
    auth.uid(),
    p_reason
  );

  return v_new_program_id;
end;
$$;

comment on function public.set_local_active_program(uuid, uuid, text) is
'Post-MVP3 E.1: Set active program for a local (UPSERT) with audit event. Admin Org / Superadmin only.';

grant execute on function public.set_local_active_program(uuid, uuid, text) to authenticated;

commit;
