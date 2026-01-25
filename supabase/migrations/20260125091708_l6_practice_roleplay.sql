-- LOTE 6: Practica integrada + evaluacion semantica (append-only)

-- 1) practice_scenarios
create table if not exists public.practice_scenarios (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete restrict,
  local_id uuid null references public.locals(id) on delete restrict,
  program_id uuid not null references public.training_programs(id) on delete cascade,
  unit_order int not null,
  title text not null,
  difficulty int not null default 1,
  instructions text not null,
  success_criteria text[] not null default '{}',
  created_at timestamptz not null default now(),
  constraint practice_scenarios_unit_order_check check (unit_order >= 1),
  constraint practice_scenarios_difficulty_check check (difficulty between 1 and 5)
);

create index if not exists practice_scenarios_org_id_idx on public.practice_scenarios (org_id);
create index if not exists practice_scenarios_local_id_idx on public.practice_scenarios (local_id);
create index if not exists practice_scenarios_program_id_idx on public.practice_scenarios (program_id);
create index if not exists practice_scenarios_program_unit_idx on public.practice_scenarios (program_id, unit_order);

-- 2) practice_attempts (append-only)
create table if not exists public.practice_attempts (
  id uuid primary key default gen_random_uuid(),
  scenario_id uuid not null references public.practice_scenarios(id) on delete restrict,
  learner_id uuid not null references public.profiles(user_id) on delete cascade,
  local_id uuid not null references public.locals(id) on delete restrict,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  started_at timestamptz not null default now(),
  ended_at timestamptz null,
  status text not null,
  constraint practice_attempts_status_check check (status in ('in_progress', 'completed'))
);

create index if not exists practice_attempts_learner_id_idx on public.practice_attempts (learner_id);
create index if not exists practice_attempts_local_id_idx on public.practice_attempts (local_id);
create index if not exists practice_attempts_scenario_id_idx on public.practice_attempts (scenario_id);
create index if not exists practice_attempts_conversation_id_idx on public.practice_attempts (conversation_id);

-- 3) practice_evaluations (append-only)
create table if not exists public.practice_evaluations (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.practice_attempts(id) on delete cascade,
  learner_message_id uuid not null references public.conversation_messages(id) on delete cascade,
  score numeric(5,2) not null,
  verdict text not null,
  strengths text[] not null default '{}',
  gaps text[] not null default '{}',
  feedback text not null,
  doubt_signals text[] not null default '{}',
  created_at timestamptz not null default now(),
  constraint practice_evaluations_score_check check (score between 0 and 100),
  constraint practice_evaluations_verdict_check check (verdict in ('pass', 'partial', 'fail'))
);

create index if not exists practice_evaluations_attempt_id_idx on public.practice_evaluations (attempt_id);
create index if not exists practice_evaluations_learner_message_id_idx on public.practice_evaluations (learner_message_id);
create index if not exists practice_evaluations_created_at_idx on public.practice_evaluations (created_at);

-- 4) practice_attempt_events (append-only)
create table if not exists public.practice_attempt_events (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.practice_attempts(id) on delete cascade,
  event_type text not null,
  created_at timestamptz not null default now(),
  constraint practice_attempt_events_type_check check (event_type in ('completed'))
);

create index if not exists practice_attempt_events_attempt_id_idx on public.practice_attempt_events (attempt_id);
create index if not exists practice_attempt_events_created_at_idx on public.practice_attempt_events (created_at);

-- 5) Append-only guards (no update/delete)
create or replace function public.prevent_update_delete()
returns trigger
language plpgsql
as $$
begin
  raise exception 'append-only table: % is not allowed', tg_op;
end;
$$;

drop trigger if exists trg_practice_attempts_prevent_update on public.practice_attempts;
create trigger trg_practice_attempts_prevent_update
before update or delete on public.practice_attempts
for each row
execute function public.prevent_update_delete();

drop trigger if exists trg_practice_evaluations_prevent_update on public.practice_evaluations;
create trigger trg_practice_evaluations_prevent_update
before update or delete on public.practice_evaluations
for each row
execute function public.prevent_update_delete();

drop trigger if exists trg_practice_attempt_events_prevent_update on public.practice_attempt_events;
create trigger trg_practice_attempt_events_prevent_update
before update or delete on public.practice_attempt_events
for each row
execute function public.prevent_update_delete();

-- 6) RLS
alter table public.practice_scenarios enable row level security;
alter table public.practice_attempts enable row level security;
alter table public.practice_evaluations enable row level security;
alter table public.practice_attempt_events enable row level security;

-- practice_scenarios SELECT
create policy practice_scenarios_select_superadmin
on public.practice_scenarios
for select
using (public.current_role() = 'superadmin');

create policy practice_scenarios_select_admin_org
on public.practice_scenarios
for select
using (
  public.current_role() = 'admin_org'
  and org_id = public.current_org_id()
);

create policy practice_scenarios_select_local_roles
on public.practice_scenarios
for select
using (
  public.current_role() in ('referente', 'aprendiz')
  and org_id = public.current_org_id()
  and (local_id is null or local_id = public.current_local_id())
);

-- practice_attempts SELECT
create policy practice_attempts_select_superadmin
on public.practice_attempts
for select
using (public.current_role() = 'superadmin');

create policy practice_attempts_select_admin_org
on public.practice_attempts
for select
using (
  public.current_role() = 'admin_org'
  and exists (
    select 1
    from public.locals l
    where l.id = practice_attempts.local_id
      and l.org_id = public.current_org_id()
  )
);

create policy practice_attempts_select_referente
on public.practice_attempts
for select
using (
  public.current_role() = 'referente'
  and local_id = public.current_local_id()
);

create policy practice_attempts_select_aprendiz
on public.practice_attempts
for select
using (
  public.current_role() = 'aprendiz'
  and learner_id = auth.uid()
);

-- practice_evaluations SELECT
create policy practice_evaluations_select_superadmin
on public.practice_evaluations
for select
using (public.current_role() = 'superadmin');

create policy practice_evaluations_select_admin_org
on public.practice_evaluations
for select
using (
  public.current_role() = 'admin_org'
  and exists (
    select 1
    from public.practice_attempts pa
    join public.locals l on l.id = pa.local_id
    where pa.id = practice_evaluations.attempt_id
      and l.org_id = public.current_org_id()
  )
);

create policy practice_evaluations_select_referente
on public.practice_evaluations
for select
using (
  public.current_role() = 'referente'
  and exists (
    select 1
    from public.practice_attempts pa
    where pa.id = practice_evaluations.attempt_id
      and pa.local_id = public.current_local_id()
  )
);

create policy practice_evaluations_select_aprendiz
on public.practice_evaluations
for select
using (
  public.current_role() = 'aprendiz'
  and exists (
    select 1
    from public.practice_attempts pa
    where pa.id = practice_evaluations.attempt_id
      and pa.learner_id = auth.uid()
  )
);

-- practice_attempt_events SELECT
create policy practice_attempt_events_select_superadmin
on public.practice_attempt_events
for select
using (public.current_role() = 'superadmin');

create policy practice_attempt_events_select_admin_org
on public.practice_attempt_events
for select
using (
  public.current_role() = 'admin_org'
  and exists (
    select 1
    from public.practice_attempts pa
    join public.locals l on l.id = pa.local_id
    where pa.id = practice_attempt_events.attempt_id
      and l.org_id = public.current_org_id()
  )
);

create policy practice_attempt_events_select_referente
on public.practice_attempt_events
for select
using (
  public.current_role() = 'referente'
  and exists (
    select 1
    from public.practice_attempts pa
    where pa.id = practice_attempt_events.attempt_id
      and pa.local_id = public.current_local_id()
  )
);

create policy practice_attempt_events_select_aprendiz
on public.practice_attempt_events
for select
using (
  public.current_role() = 'aprendiz'
  and exists (
    select 1
    from public.practice_attempts pa
    where pa.id = practice_attempt_events.attempt_id
      and pa.learner_id = auth.uid()
  )
);

-- INSERT policies (server flows via user session)
create policy practice_attempts_insert_learner
on public.practice_attempts
for insert
with check (
  learner_id = auth.uid()
  and public.current_role() = 'aprendiz'
  and exists (
    select 1
    from public.practice_scenarios ps
    where ps.id = practice_attempts.scenario_id
      and ps.org_id = public.current_org_id()
      and (ps.local_id is null or ps.local_id = public.current_local_id())
  )
);

create policy practice_evaluations_insert_learner
on public.practice_evaluations
for insert
with check (
  exists (
    select 1
    from public.practice_attempts pa
    where pa.id = practice_evaluations.attempt_id
      and pa.learner_id = auth.uid()
  )
);

create policy practice_attempt_events_insert_learner
on public.practice_attempt_events
for insert
with check (
  exists (
    select 1
    from public.practice_attempts pa
    where pa.id = practice_attempt_events.attempt_id
      and pa.learner_id = auth.uid()
  )
);

-- 7) View (optional)
create or replace view public.v_referente_practice_summary as
select
  pa.learner_id,
  pa.id as attempt_id,
  ps.title as scenario_title,
  pe.score,
  pe.verdict,
  pe.created_at
from public.practice_attempts pa
join public.practice_scenarios ps on ps.id = pa.scenario_id
left join lateral (
  select
    eval.score,
    eval.verdict,
    eval.created_at
  from public.practice_evaluations eval
  where eval.attempt_id = pa.id
  order by eval.created_at desc
  limit 1
) pe on true;
