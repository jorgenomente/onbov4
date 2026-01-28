-- 20260128120000_post_mvp4_k2_add_knowledge_rpc.sql
-- Post-MVP 4 / Sub-lote K2: add knowledge to unit (write guided)

set check_function_bodies = off;

begin;

-- ------------------------------------------------------------
-- 1) RLS write policies
-- ------------------------------------------------------------
create policy knowledge_items_insert_admin_org
on public.knowledge_items
for insert
with check (
  public.current_role() = 'superadmin'
  or (
    public.current_role() = 'admin_org'
    and org_id = public.current_org_id()
    and (
      local_id is null
      or exists (
        select 1
        from public.locals l
        where l.id = knowledge_items.local_id
          and l.org_id = public.current_org_id()
      )
    )
  )
);

create policy unit_knowledge_map_insert_admin_org
on public.unit_knowledge_map
for insert
with check (
  public.current_role() = 'superadmin'
  or (
    public.current_role() = 'admin_org'
    and exists (
      select 1
      from public.training_units tu
      join public.training_programs tp on tp.id = tu.program_id
      where tu.id = unit_knowledge_map.unit_id
        and tp.org_id = public.current_org_id()
    )
    and exists (
      select 1
      from public.knowledge_items ki
      where ki.id = unit_knowledge_map.knowledge_id
        and ki.org_id = public.current_org_id()
    )
  )
);

-- ------------------------------------------------------------
-- 2) Audit table (append-only)
-- ------------------------------------------------------------
create table if not exists public.knowledge_change_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete restrict,
  local_id uuid null references public.locals(id) on delete restrict,
  program_id uuid not null references public.training_programs(id) on delete restrict,
  unit_id uuid not null references public.training_units(id) on delete restrict,
  unit_order int not null,
  knowledge_id uuid not null references public.knowledge_items(id) on delete restrict,
  action text not null default 'create_and_map',
  created_by_user_id uuid not null references public.profiles(user_id) on delete restrict,
  title text not null,
  created_at timestamptz not null default now()
);

create index if not exists knowledge_change_events_program_id_idx
  on public.knowledge_change_events (program_id);

create index if not exists knowledge_change_events_unit_id_idx
  on public.knowledge_change_events (unit_id);

create index if not exists knowledge_change_events_created_at_idx
  on public.knowledge_change_events (created_at desc);

alter table public.knowledge_change_events enable row level security;

create or replace function public.prevent_update_delete()
returns trigger
language plpgsql
as $$
begin
  raise exception 'UPDATE/DELETE not allowed on % (append-only).', tg_table_name
    using errcode = '42501';
end;
$$;

drop trigger if exists trg_knowledge_change_events_prevent_update on public.knowledge_change_events;

create trigger trg_knowledge_change_events_prevent_update
before update or delete on public.knowledge_change_events
for each row
execute function public.prevent_update_delete();

create policy knowledge_change_events_select_superadmin
on public.knowledge_change_events
for select
using (public.current_role() = 'superadmin');

create policy knowledge_change_events_select_admin_org
on public.knowledge_change_events
for select
using (
  public.current_role() = 'admin_org'
  and org_id = public.current_org_id()
);

create policy knowledge_change_events_insert_admin_org
on public.knowledge_change_events
for insert
with check (
  public.current_role() = 'superadmin'
  or (public.current_role() = 'admin_org' and org_id = public.current_org_id())
);

-- ------------------------------------------------------------
-- 3) RPC create_and_map_knowledge_item (security invoker)
-- ------------------------------------------------------------
create or replace function public.create_and_map_knowledge_item(
  p_program_id uuid,
  p_unit_id uuid,
  p_title text,
  p_content text,
  p_scope text,
  p_local_id uuid,
  p_reason text default null
)
returns uuid
language plpgsql
as $$
declare
  v_role text;
  v_org_id uuid;
  v_program_org_id uuid;
  v_unit_order int;
  v_title text;
  v_content text;
  v_knowledge_id uuid;
  v_local_id uuid;
begin
  v_role := public.current_role();
  v_org_id := public.current_org_id();

  if v_role not in ('admin_org', 'superadmin') then
    raise exception 'forbidden: role % cannot create knowledge', v_role
      using errcode = '42501';
  end if;

  select tp.org_id into v_program_org_id
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

  select tu.unit_order into v_unit_order
  from public.training_units tu
  where tu.id = p_unit_id
    and tu.program_id = p_program_id;

  if v_unit_order is null then
    raise exception 'not_found: unit_id % not in program', p_unit_id
      using errcode = '22023';
  end if;

  v_title := trim(coalesce(p_title, ''));
  v_content := trim(coalesce(p_content, ''));

  if length(v_title) = 0 or length(v_title) > 120 then
    raise exception 'invalid: title length must be 1..120'
      using errcode = '22023';
  end if;

  if length(v_content) = 0 or length(v_content) > 20000 then
    raise exception 'invalid: content length must be 1..20000'
      using errcode = '22023';
  end if;

  if p_scope = 'org' then
    if p_local_id is not null then
      raise exception 'invalid: local_id must be null for org scope'
        using errcode = '22023';
    end if;
    v_local_id := null;
  elsif p_scope = 'local' then
    if p_local_id is null then
      raise exception 'invalid: local_id required for local scope'
        using errcode = '22023';
    end if;
    if not exists (
      select 1
      from public.locals l
      where l.id = p_local_id
        and l.org_id = v_program_org_id
    ) then
      raise exception 'invalid: local_id % not in org', p_local_id
        using errcode = '22023';
    end if;
    v_local_id := p_local_id;
  else
    raise exception 'invalid: scope must be org or local'
      using errcode = '22023';
  end if;

  insert into public.knowledge_items (
    org_id,
    local_id,
    title,
    content
  ) values (
    v_program_org_id,
    v_local_id,
    v_title,
    v_content
  ) returning id into v_knowledge_id;

  insert into public.unit_knowledge_map (unit_id, knowledge_id)
  values (p_unit_id, v_knowledge_id);

  insert into public.knowledge_change_events (
    org_id,
    local_id,
    program_id,
    unit_id,
    unit_order,
    knowledge_id,
    action,
    created_by_user_id,
    title
  ) values (
    v_program_org_id,
    v_local_id,
    p_program_id,
    p_unit_id,
    v_unit_order,
    v_knowledge_id,
    'create_and_map',
    auth.uid(),
    v_title
  );

  return v_knowledge_id;
end;
$$;

comment on function public.create_and_map_knowledge_item(
  uuid, uuid, text, text, text, uuid, text
) is
'Post-MVP4 K2: create knowledge_item + map to unit in one transaction (append-only).';

grant execute on function public.create_and_map_knowledge_item(
  uuid, uuid, text, text, text, uuid, text
) to authenticated;

commit;
