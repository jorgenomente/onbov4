-- LOTE 1: Multi-tenant base + roles (DB-first + RLS-first)

-- 1) Base tables
create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.locals (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete restrict,
  name text not null,
  created_at timestamptz not null default now()
);

create index if not exists locals_org_id_idx on public.locals (org_id);

-- 2) Roles enum (idempotent)
do $$
begin
  create type public.app_role as enum (
    'superadmin',
    'admin_org',
    'referente',
    'aprendiz'
  );
exception
  when duplicate_object then null;
end $$;

-- 3) Profiles (1:1 with auth.users)
create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  org_id uuid not null references public.organizations(id) on delete restrict,
  local_id uuid not null references public.locals(id) on delete restrict,
  role public.app_role not null,
  full_name text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profiles_org_id_idx on public.profiles (org_id);
create index if not exists profiles_local_id_idx on public.profiles (local_id);
create index if not exists profiles_role_idx on public.profiles (role);

-- 4) updated_at trigger for profiles
create or replace function public.set_profile_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_set_updated_at on public.profiles;
create trigger trg_profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_profile_updated_at();

-- Guardrail: only allow updating full_name (and updated_at)
create or replace function public.guard_profiles_update()
returns trigger
language plpgsql
as $$
begin
  if new.user_id <> old.user_id
     or new.org_id <> old.org_id
     or new.local_id <> old.local_id
     or new.role <> old.role
     or new.created_at <> old.created_at then
    raise exception 'only full_name can be updated';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_guard_update on public.profiles;
create trigger trg_profiles_guard_update
before update on public.profiles
for each row
execute function public.guard_profiles_update();

-- 5) Helper functions
create or replace function public.current_user_id()
returns uuid
language sql
stable
as $$
  select auth.uid();
$$;

create or replace function public.current_profile()
returns table (
  user_id uuid,
  org_id uuid,
  local_id uuid,
  role public.app_role,
  full_name text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
as $$
  select
    p.user_id,
    p.org_id,
    p.local_id,
    p.role,
    p.full_name,
    p.created_at,
    p.updated_at
  from public.profiles p
  where p.user_id = auth.uid()
  limit 1;
$$;

create or replace function public.current_role()
returns public.app_role
language sql
stable
as $$
  select p.role
  from public.profiles p
  where p.user_id = auth.uid()
  limit 1;
$$;

create or replace function public.current_org_id()
returns uuid
language sql
stable
as $$
  select p.org_id
  from public.profiles p
  where p.user_id = auth.uid()
  limit 1;
$$;

create or replace function public.current_local_id()
returns uuid
language sql
stable
as $$
  select p.local_id
  from public.profiles p
  where p.user_id = auth.uid()
  limit 1;
$$;

-- 6) RLS
alter table public.organizations enable row level security;
alter table public.locals enable row level security;
alter table public.profiles enable row level security;

-- Profiles policies
create policy profiles_select_own
on public.profiles
for select
using (user_id = auth.uid());

create policy profiles_update_own
on public.profiles
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- No insert policy for profiles in MVP (restricted to server/admin flows)

-- Organizations policies
create policy organizations_select_superadmin
on public.organizations
for select
using (public.current_role() = 'superadmin');

create policy organizations_select_own
on public.organizations
for select
using (id = public.current_org_id());

-- Locals policies
create policy locals_select_superadmin
on public.locals
for select
using (public.current_role() = 'superadmin');

create policy locals_select_admin_org
on public.locals
for select
using (
  public.current_role() = 'admin_org'
  and org_id = public.current_org_id()
);

create policy locals_select_own
on public.locals
for select
using (
  public.current_role() in ('referente', 'aprendiz')
  and id = public.current_local_id()
);

-- 7) Optional dev seed (manual, local only)
-- Insert an organization and local for quick local testing.
-- Replace UUIDs as needed.
--
-- insert into public.organizations (id, name)
-- values ('00000000-0000-0000-0000-000000000001', 'Demo Org');
--
-- insert into public.locals (id, org_id, name)
-- values ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'Local Centro');
