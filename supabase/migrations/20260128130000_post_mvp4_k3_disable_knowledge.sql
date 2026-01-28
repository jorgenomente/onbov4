-- 20260128130000_post_mvp4_k3_disable_knowledge.sql
-- Post-MVP 4 / Sub-lote K3: disable knowledge items (no delete)

set check_function_bodies = off;

begin;

-- ------------------------------------------------------------
-- 1) Schema: add is_enabled
-- ------------------------------------------------------------
alter table public.knowledge_items
  add column if not exists is_enabled boolean not null default true;

update public.knowledge_items
set is_enabled = true
where is_enabled is null;

alter table public.knowledge_change_events
  add column if not exists reason text null;

-- ------------------------------------------------------------
-- 2) Guardrail trigger: only allow is_enabled true -> false
-- ------------------------------------------------------------
create or replace function public.guard_knowledge_items_disable_update()
returns trigger
language plpgsql
as $$
begin
  if new.id is distinct from old.id then
    raise exception 'invalid: id cannot be updated'
      using errcode = '42501';
  end if;

  if new.org_id is distinct from old.org_id
     or new.local_id is distinct from old.local_id
     or new.title is distinct from old.title
     or new.content is distinct from old.content
     or new.created_at is distinct from old.created_at then
    raise exception 'invalid: only is_enabled can be updated'
      using errcode = '42501';
  end if;

  if new.is_enabled is distinct from old.is_enabled then
    if old.is_enabled = true and new.is_enabled = false then
      return new;
    end if;
    if old.is_enabled = false then
      raise exception 'conflict: already disabled'
        using errcode = '23505';
    end if;
  end if;

  raise exception 'invalid: only is_enabled true->false is allowed'
    using errcode = '42501';
end;
$$;

drop trigger if exists trg_knowledge_items_guard_disable_update on public.knowledge_items;

create trigger trg_knowledge_items_guard_disable_update
before update on public.knowledge_items
for each row
execute function public.guard_knowledge_items_disable_update();

-- ------------------------------------------------------------
-- 3) RLS updates + select adjustment
-- ------------------------------------------------------------
drop policy if exists knowledge_items_select_local_roles on public.knowledge_items;

create policy knowledge_items_select_local_roles
on public.knowledge_items
for select
using (
  public.current_role() in ('referente', 'aprendiz')
  and org_id = public.current_org_id()
  and (local_id is null or local_id = public.current_local_id())
  and is_enabled = true
);

create policy knowledge_items_update_admin_org
on public.knowledge_items
for update
using (
  public.current_role() = 'superadmin'
  or (public.current_role() = 'admin_org' and org_id = public.current_org_id())
)
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

-- ------------------------------------------------------------
-- 4) Update K1 views to ignore disabled knowledge
-- ------------------------------------------------------------
drop view if exists public.v_org_program_knowledge_gaps_summary;
drop view if exists public.v_org_unit_knowledge_list;
drop view if exists public.v_org_program_unit_knowledge_coverage;

create view public.v_org_program_unit_knowledge_coverage
with (security_barrier = true)
as
select
  tp.id as program_id,
  tp.name as program_name,
  tu.id as unit_id,
  tu.unit_order,
  tu.title as unit_title,
  count(ki.id) as total_knowledge_count,
  count(ki.id) filter (where ki.local_id is null) as org_level_knowledge_count,
  count(ki.id) filter (
    where tp.local_id is not null
      and ki.local_id = tp.local_id
  ) as local_level_knowledge_count,
  (count(ki.id) > 0) as has_any_mapping,
  (count(ki.id) = 0) as is_missing_mapping
from public.training_programs tp
join public.training_units tu on tu.program_id = tp.id
left join public.unit_knowledge_map ukm on ukm.unit_id = tu.id
left join public.knowledge_items ki
  on ki.id = ukm.knowledge_id
  and ki.is_enabled = true
where public.current_role() in ('admin_org', 'superadmin', 'referente')
group by
  tp.id,
  tp.name,
  tu.id,
  tu.unit_order,
  tu.title
order by
  tp.id,
  tu.unit_order;

comment on view public.v_org_program_unit_knowledge_coverage is
'Post-MVP4 K3: Coverage de knowledge por unidad (filtra is_enabled=true). local_level_knowledge_count solo se computa si training_programs.local_id no es NULL; para programas org-level se reporta 0.';

create view public.v_org_program_knowledge_gaps_summary
with (security_barrier = true)
as
select
  program_id,
  program_name,
  count(*)::integer as total_units,
  count(*) filter (where is_missing_mapping)::integer as units_missing_mapping,
  case
    when count(*) = 0 then 0
    else round((count(*) filter (where is_missing_mapping))::numeric / count(*)::numeric * 100, 2)
  end as pct_units_missing_mapping,
  sum(total_knowledge_count)::integer as total_knowledge_mappings
from public.v_org_program_unit_knowledge_coverage
where public.current_role() in ('admin_org', 'superadmin', 'referente')
group by program_id, program_name;

comment on view public.v_org_program_knowledge_gaps_summary is
'Post-MVP4 K3: Resumen de gaps por programa (unidades, gaps, % gaps, mappings totales).';

create view public.v_org_unit_knowledge_list
with (security_barrier = true)
as
select
  tp.id as program_id,
  tp.name as program_name,
  tu.id as unit_id,
  tu.unit_order,
  ki.id as knowledge_id,
  ki.title as knowledge_title,
  case when ki.local_id is null then 'org' else 'local' end as knowledge_scope,
  ki.created_at as knowledge_created_at
from public.training_programs tp
join public.training_units tu on tu.program_id = tp.id
join public.unit_knowledge_map ukm on ukm.unit_id = tu.id
join public.knowledge_items ki on ki.id = ukm.knowledge_id
where public.current_role() in ('admin_org', 'superadmin', 'referente')
  and ki.is_enabled = true
order by tp.id, tu.unit_order, ki.created_at desc;

comment on view public.v_org_unit_knowledge_list is
'Post-MVP4 K3: Knowledge asociado por unidad (drill-down, read-only, filtra is_enabled=true).';

-- ------------------------------------------------------------
-- 5) RPC disable_knowledge_item
-- ------------------------------------------------------------
create or replace function public.disable_knowledge_item(
  p_knowledge_id uuid,
  p_reason text default null
)
returns integer
language plpgsql
as $$
declare
  v_role text;
  v_org_id uuid;
  v_knowledge_org_id uuid;
  v_knowledge_local_id uuid;
  v_title text;
  v_reason text;
  v_events int;
begin
  v_role := public.current_role();
  v_org_id := public.current_org_id();

  if v_role not in ('admin_org', 'superadmin') then
    raise exception 'forbidden: role % cannot disable knowledge', v_role
      using errcode = '42501';
  end if;

  select ki.org_id, ki.local_id, ki.title
    into v_knowledge_org_id, v_knowledge_local_id, v_title
  from public.knowledge_items ki
  where ki.id = p_knowledge_id;

  if v_knowledge_org_id is null then
    raise exception 'not_found: knowledge_id % not in org scope', p_knowledge_id
      using errcode = '22023';
  end if;

  if v_role = 'admin_org' and v_knowledge_org_id <> v_org_id then
    raise exception 'not_found: knowledge_id % not in org scope', p_knowledge_id
      using errcode = '22023';
  end if;

  if v_knowledge_local_id is not null then
    if not exists (
      select 1
      from public.locals l
      where l.id = v_knowledge_local_id
        and l.org_id = v_knowledge_org_id
    ) then
      raise exception 'not_found: local_id % not in org scope', v_knowledge_local_id
        using errcode = '22023';
    end if;
  end if;

  v_reason := trim(coalesce(p_reason, ''));
  if length(v_reason) > 500 then
    raise exception 'invalid: reason length must be <= 500'
      using errcode = '22023';
  end if;

  update public.knowledge_items
  set is_enabled = false
  where id = p_knowledge_id;

  insert into public.knowledge_change_events (
    org_id,
    local_id,
    program_id,
    unit_id,
    unit_order,
    knowledge_id,
    action,
    created_by_user_id,
    title,
    reason
  )
  select
    tp.org_id,
    v_knowledge_local_id,
    tp.id,
    tu.id,
    tu.unit_order,
    p_knowledge_id,
    'disable',
    auth.uid(),
    v_title,
    nullif(v_reason, '')
  from public.unit_knowledge_map ukm
  join public.training_units tu on tu.id = ukm.unit_id
  join public.training_programs tp on tp.id = tu.program_id
  where ukm.knowledge_id = p_knowledge_id
    and tp.org_id = v_knowledge_org_id;

  get diagnostics v_events = row_count;

  return v_events;
end;
$$;

comment on function public.disable_knowledge_item(uuid, text) is
'Post-MVP4 K3: disable knowledge item (is_enabled=false) and emit audit events per mapping.';

grant execute on function public.disable_knowledge_item(uuid, text) to authenticated;

commit;
