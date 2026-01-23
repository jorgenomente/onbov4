-- LOTE 4: Knowledge grounding (DB-first + RLS-first)

-- 1) knowledge_items
create table if not exists public.knowledge_items (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete restrict,
  local_id uuid null references public.locals(id) on delete restrict,
  title text not null,
  content text not null,
  created_at timestamptz not null default now()
);

create index if not exists knowledge_items_org_id_idx on public.knowledge_items (org_id);
create index if not exists knowledge_items_local_id_idx on public.knowledge_items (local_id);

-- 2) unit_knowledge_map
create table if not exists public.unit_knowledge_map (
  unit_id uuid not null references public.training_units(id) on delete cascade,
  knowledge_id uuid not null references public.knowledge_items(id) on delete cascade,
  primary key (unit_id, knowledge_id)
);

-- 3) RLS
alter table public.knowledge_items enable row level security;
alter table public.unit_knowledge_map enable row level security;

-- knowledge_items SELECT
create policy knowledge_items_select_superadmin
on public.knowledge_items
for select
using (public.current_role() = 'superadmin');

create policy knowledge_items_select_admin_org
on public.knowledge_items
for select
using (
  public.current_role() = 'admin_org'
  and org_id = public.current_org_id()
);

create policy knowledge_items_select_local_roles
on public.knowledge_items
for select
using (
  public.current_role() in ('referente', 'aprendiz')
  and org_id = public.current_org_id()
  and (local_id is null or local_id = public.current_local_id())
);

-- unit_knowledge_map SELECT (via knowledge visibility)
create policy unit_knowledge_map_select_visible
on public.unit_knowledge_map
for select
using (
  exists (
    select 1
    from public.knowledge_items ki
    where ki.id = unit_knowledge_map.knowledge_id
  )
);

-- Writes are server-only (RPC/Server Actions). No INSERT/UPDATE/DELETE policies defined here.
