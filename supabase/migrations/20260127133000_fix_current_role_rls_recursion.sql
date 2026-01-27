-- Fix recursion: make current_* helpers bypass RLS via security definer

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
security definer
set search_path = public
set row_security = off
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
security definer
set search_path = public
set row_security = off
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
security definer
set search_path = public
set row_security = off
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
security definer
set search_path = public
set row_security = off
as $$
  select p.local_id
  from public.profiles p
  where p.user_id = auth.uid()
  limit 1;
$$;
