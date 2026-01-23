-- LOTE 2: Modelo de entrenamiento + estado del aprendiz + views base

-- 1) Enum learner_status (idempotent)
do $$
begin
  create type public.learner_status as enum (
    'en_entrenamiento',
    'en_practica',
    'en_riesgo',
    'en_revision',
    'aprobado'
  );
exception
  when duplicate_object then null;
end $$;

-- 2) training_programs
create table if not exists public.training_programs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete restrict,
  local_id uuid null references public.locals(id) on delete restrict,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists training_programs_org_id_idx on public.training_programs (org_id);
create index if not exists training_programs_local_id_idx on public.training_programs (local_id);
create index if not exists training_programs_org_local_idx on public.training_programs (org_id, local_id);

-- 3) training_units
create table if not exists public.training_units (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.training_programs(id) on delete cascade,
  unit_order int not null,
  title text not null,
  objectives text[] not null default '{}',
  created_at timestamptz not null default now(),
  constraint training_units_program_order_unique unique (program_id, unit_order),
  constraint training_units_unit_order_check check (unit_order >= 1)
);

create index if not exists training_units_program_id_idx on public.training_units (program_id);

-- 4) local_active_programs
create table if not exists public.local_active_programs (
  local_id uuid primary key references public.locals(id) on delete cascade,
  program_id uuid not null references public.training_programs(id) on delete restrict,
  created_at timestamptz not null default now()
);

-- 5) learner_trainings
create table if not exists public.learner_trainings (
  id uuid primary key default gen_random_uuid(),
  learner_id uuid not null references public.profiles(user_id) on delete cascade,
  local_id uuid not null references public.locals(id) on delete restrict,
  program_id uuid not null references public.training_programs(id) on delete restrict,
  status public.learner_status not null default 'en_entrenamiento',
  current_unit_order int not null default 1,
  progress_percent numeric(5,2) not null default 0,
  started_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint learner_trainings_unique_learner unique (learner_id),
  constraint learner_trainings_progress_check check (progress_percent >= 0 and progress_percent <= 100),
  constraint learner_trainings_current_unit_check check (current_unit_order >= 1)
);

create index if not exists learner_trainings_local_id_idx on public.learner_trainings (local_id);
create index if not exists learner_trainings_program_id_idx on public.learner_trainings (program_id);
create index if not exists learner_trainings_status_idx on public.learner_trainings (status);

-- 6) learner_state_transitions (append-only)
create table if not exists public.learner_state_transitions (
  id uuid primary key default gen_random_uuid(),
  learner_id uuid not null references public.profiles(user_id) on delete cascade,
  from_status public.learner_status null,
  to_status public.learner_status not null,
  reason text null,
  actor_user_id uuid null references public.profiles(user_id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists learner_state_transitions_learner_id_idx on public.learner_state_transitions (learner_id);
create index if not exists learner_state_transitions_to_status_idx on public.learner_state_transitions (to_status);
create index if not exists learner_state_transitions_created_at_idx on public.learner_state_transitions (created_at);

-- 7) updated_at trigger for learner_trainings
create or replace function public.set_learner_training_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_learner_trainings_set_updated_at on public.learner_trainings;
create trigger trg_learner_trainings_set_updated_at
before update on public.learner_trainings
for each row
execute function public.set_learner_training_updated_at();

-- 8) RLS
alter table public.training_programs enable row level security;
alter table public.training_units enable row level security;
alter table public.local_active_programs enable row level security;
alter table public.learner_trainings enable row level security;
alter table public.learner_state_transitions enable row level security;

-- training_programs SELECT
create policy training_programs_select_superadmin
on public.training_programs
for select
using (public.current_role() = 'superadmin');

create policy training_programs_select_admin_org
on public.training_programs
for select
using (
  public.current_role() = 'admin_org'
  and org_id = public.current_org_id()
);

create policy training_programs_select_local_roles
on public.training_programs
for select
using (
  public.current_role() in ('referente', 'aprendiz')
  and org_id = public.current_org_id()
  and (local_id is null or local_id = public.current_local_id())
);

-- training_units SELECT (visibility via training_programs RLS)
create policy training_units_select_visible_programs
on public.training_units
for select
using (
  exists (
    select 1
    from public.training_programs tp
    where tp.id = training_units.program_id
  )
);

-- local_active_programs SELECT
create policy local_active_programs_select_superadmin
on public.local_active_programs
for select
using (public.current_role() = 'superadmin');

create policy local_active_programs_select_admin_org
on public.local_active_programs
for select
using (
  public.current_role() = 'admin_org'
  and exists (
    select 1
    from public.locals l
    where l.id = local_active_programs.local_id
      and l.org_id = public.current_org_id()
  )
);

create policy local_active_programs_select_local_roles
on public.local_active_programs
for select
using (
  public.current_role() in ('referente', 'aprendiz')
  and local_id = public.current_local_id()
);

-- learner_trainings SELECT
create policy learner_trainings_select_superadmin
on public.learner_trainings
for select
using (public.current_role() = 'superadmin');

create policy learner_trainings_select_admin_org
on public.learner_trainings
for select
using (
  public.current_role() = 'admin_org'
  and exists (
    select 1
    from public.locals l
    where l.id = learner_trainings.local_id
      and l.org_id = public.current_org_id()
  )
);

create policy learner_trainings_select_referente
on public.learner_trainings
for select
using (
  public.current_role() = 'referente'
  and local_id = public.current_local_id()
);

create policy learner_trainings_select_aprendiz
on public.learner_trainings
for select
using (
  public.current_role() = 'aprendiz'
  and learner_id = auth.uid()
);

-- learner_state_transitions SELECT
create policy learner_state_transitions_select_superadmin
on public.learner_state_transitions
for select
using (public.current_role() = 'superadmin');

create policy learner_state_transitions_select_admin_org
on public.learner_state_transitions
for select
using (
  public.current_role() = 'admin_org'
  and exists (
    select 1
    from public.learner_trainings lt
    join public.locals l on l.id = lt.local_id
    where lt.learner_id = learner_state_transitions.learner_id
      and l.org_id = public.current_org_id()
  )
);

create policy learner_state_transitions_select_referente
on public.learner_state_transitions
for select
using (
  public.current_role() = 'referente'
  and exists (
    select 1
    from public.learner_trainings lt
    where lt.learner_id = learner_state_transitions.learner_id
      and lt.local_id = public.current_local_id()
  )
);

create policy learner_state_transitions_select_aprendiz
on public.learner_state_transitions
for select
using (
  public.current_role() = 'aprendiz'
  and learner_id = auth.uid()
);

-- 9) Views (read-only)
create or replace view public.v_learner_training_home as
select
  lt.learner_id,
  lt.status,
  lt.program_id,
  tp.name as program_name,
  lt.current_unit_order,
  total_units.total_units,
  cu.title as current_unit_title,
  cu.objectives,
  lt.progress_percent
from public.learner_trainings lt
join public.training_programs tp on tp.id = lt.program_id
left join public.training_units cu
  on cu.program_id = lt.program_id
  and cu.unit_order = lt.current_unit_order
left join (
  select
    tu.program_id,
    count(1)::int as total_units
  from public.training_units tu
  group by tu.program_id
) as total_units on total_units.program_id = lt.program_id
where lt.learner_id = auth.uid();

create or replace view public.v_learner_progress as
select
  lt.learner_id,
  lt.status,
  lt.progress_percent,
  lt.current_unit_order,
  coalesce(
    json_agg(
      json_build_object(
        'unit_order', tu.unit_order,
        'title', tu.title,
        'is_completed', (tu.unit_order < lt.current_unit_order)
      )
      order by tu.unit_order
    ) filter (where tu.id is not null),
    '[]'::json
  ) as units
from public.learner_trainings lt
join public.training_units tu on tu.program_id = lt.program_id
where lt.learner_id = auth.uid()
group by
  lt.learner_id,
  lt.status,
  lt.progress_percent,
  lt.current_unit_order;

create or replace view public.v_referente_learners as
select
  p.user_id as learner_id,
  p.full_name,
  lt.status,
  lt.progress_percent,
  lt.current_unit_order,
  lt.updated_at
from public.learner_trainings lt
join public.profiles p on p.user_id = lt.learner_id
where p.role = 'aprendiz';
