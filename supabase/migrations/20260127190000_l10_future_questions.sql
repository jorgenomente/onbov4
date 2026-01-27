-- LOTE Post-MVP 1 — Sub-lote D: logging de consultas a unidades futuras (infra)

create table if not exists public.learner_future_questions (
  id uuid primary key default gen_random_uuid(),
  learner_id uuid not null references auth.users(id) on delete cascade,
  local_id uuid not null references public.locals(id) on delete restrict,
  program_id uuid not null references public.training_programs(id) on delete restrict,
  asked_unit_order integer not null,
  conversation_id uuid references public.conversations(id) on delete set null,
  message_id uuid references public.conversation_messages(id) on delete set null,
  question_text text not null,
  created_at timestamptz not null default now()
);

create index if not exists learner_future_questions_learner_created_idx
  on public.learner_future_questions (learner_id, created_at desc);

create index if not exists learner_future_questions_local_created_idx
  on public.learner_future_questions (local_id, created_at desc);

create index if not exists learner_future_questions_program_created_idx
  on public.learner_future_questions (program_id, created_at desc);

alter table public.learner_future_questions enable row level security;

create policy learner_future_questions_select_superadmin
on public.learner_future_questions
for select
using (public.current_role() = 'superadmin');

create policy learner_future_questions_select_admin_org
on public.learner_future_questions
for select
using (
  public.current_role() = 'admin_org'
  and exists (
    select 1
    from public.locals l
    where l.id = learner_future_questions.local_id
      and l.org_id = public.current_org_id()
  )
);

create policy learner_future_questions_select_referente
on public.learner_future_questions
for select
using (
  public.current_role() = 'referente'
  and local_id = public.current_local_id()
);

create policy learner_future_questions_select_aprendiz
on public.learner_future_questions
for select
using (
  public.current_role() = 'aprendiz'
  and learner_id = auth.uid()
);

create or replace function public.log_future_question(
  asked_unit_order integer,
  question_text text,
  conversation_id uuid default null,
  message_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_learner_id uuid;
  v_local_id uuid;
  v_program_id uuid;
  v_current_unit integer;
  v_id uuid;
begin
  v_learner_id := auth.uid();
  if v_learner_id is null then
    raise exception 'Unauthenticated';
  end if;

  select p.local_id
    into v_local_id
  from public.profiles p
  where p.user_id = v_learner_id
  limit 1;

  if v_local_id is null then
    raise exception 'Local not found';
  end if;

  select lt.program_id, lt.current_unit_order
    into v_program_id, v_current_unit
  from public.learner_trainings lt
  where lt.learner_id = v_learner_id
  limit 1;

  if v_program_id is null then
    select lap.program_id
      into v_program_id
    from public.local_active_programs lap
    where lap.local_id = v_local_id
    limit 1;
  end if;

  if v_program_id is null or v_current_unit is null then
    raise exception 'Active training not found';
  end if;

  if asked_unit_order <= v_current_unit then
    raise exception 'asked_unit_order must be greater than current_unit_order';
  end if;

  insert into public.learner_future_questions (
    learner_id,
    local_id,
    program_id,
    asked_unit_order,
    conversation_id,
    message_id,
    question_text
  )
  values (
    v_learner_id,
    v_local_id,
    v_program_id,
    asked_unit_order,
    conversation_id,
    message_id,
    question_text
  )
  returning id into v_id;

  return v_id;
end;
$$;
