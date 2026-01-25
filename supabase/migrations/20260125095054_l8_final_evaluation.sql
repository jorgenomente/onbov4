-- LOTE 8: Evaluacion final (Mesa Complicada)

-- 1) final_evaluation_configs
create table if not exists public.final_evaluation_configs (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.training_programs(id) on delete cascade,
  total_questions int not null,
  roleplay_ratio numeric(3,2) not null,
  min_global_score numeric(5,2) not null,
  must_pass_units int[] not null default '{}',
  questions_per_unit int not null default 1,
  max_attempts int not null default 3,
  cooldown_hours int not null default 12,
  created_at timestamptz not null default now(),
  constraint final_evaluation_configs_roleplay_check check (roleplay_ratio between 0 and 1),
  constraint final_evaluation_configs_total_questions_check check (total_questions > 0)
);

create index if not exists final_evaluation_configs_program_id_idx on public.final_evaluation_configs (program_id);

-- 2) final_evaluation_attempts
create table if not exists public.final_evaluation_attempts (
  id uuid primary key default gen_random_uuid(),
  learner_id uuid not null references public.profiles(user_id) on delete cascade,
  program_id uuid not null references public.training_programs(id) on delete restrict,
  attempt_number int not null,
  started_at timestamptz not null default now(),
  ended_at timestamptz null,
  status text not null,
  global_score numeric(5,2) null,
  bot_recommendation text null,
  created_at timestamptz not null default now(),
  constraint final_evaluation_attempts_status_check check (status in ('in_progress', 'completed', 'blocked')),
  constraint final_evaluation_attempts_reco_check check (bot_recommendation in ('approved', 'not_approved')),
  constraint final_evaluation_attempts_unique unique (learner_id, attempt_number)
);

create index if not exists final_evaluation_attempts_learner_id_idx on public.final_evaluation_attempts (learner_id);
create index if not exists final_evaluation_attempts_program_id_idx on public.final_evaluation_attempts (program_id);
create index if not exists final_evaluation_attempts_created_at_idx on public.final_evaluation_attempts (created_at);

-- 3) final_evaluation_questions
create table if not exists public.final_evaluation_questions (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.final_evaluation_attempts(id) on delete cascade,
  unit_order int not null,
  question_type text not null,
  prompt text not null,
  created_at timestamptz not null default now(),
  constraint final_evaluation_questions_type_check check (question_type in ('direct', 'roleplay')),
  constraint final_evaluation_questions_unit_order_check check (unit_order >= 1)
);

create index if not exists final_evaluation_questions_attempt_id_idx on public.final_evaluation_questions (attempt_id);
create index if not exists final_evaluation_questions_unit_order_idx on public.final_evaluation_questions (unit_order);

-- 4) final_evaluation_answers
create table if not exists public.final_evaluation_answers (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.final_evaluation_questions(id) on delete cascade,
  learner_answer text not null,
  created_at timestamptz not null default now()
);

create index if not exists final_evaluation_answers_question_id_idx on public.final_evaluation_answers (question_id);
create index if not exists final_evaluation_answers_created_at_idx on public.final_evaluation_answers (created_at);

-- 5) final_evaluation_evaluations
create table if not exists public.final_evaluation_evaluations (
  id uuid primary key default gen_random_uuid(),
  answer_id uuid not null references public.final_evaluation_answers(id) on delete cascade,
  unit_order int not null,
  score numeric(5,2) not null,
  verdict text not null,
  strengths text[] not null default '{}',
  gaps text[] not null default '{}',
  feedback text not null,
  doubt_signals text[] not null default '{}',
  created_at timestamptz not null default now(),
  constraint final_evaluation_evaluations_score_check check (score between 0 and 100),
  constraint final_evaluation_evaluations_verdict_check check (verdict in ('pass', 'partial', 'fail'))
);

create index if not exists final_evaluation_evaluations_answer_id_idx on public.final_evaluation_evaluations (answer_id);
create index if not exists final_evaluation_evaluations_unit_order_idx on public.final_evaluation_evaluations (unit_order);
create index if not exists final_evaluation_evaluations_created_at_idx on public.final_evaluation_evaluations (created_at);

-- 6) Append-only guards for answers/evaluations/questions
create or replace function public.prevent_update_delete()
returns trigger
language plpgsql
as $$
begin
  raise exception 'append-only table: % is not allowed', tg_op;
end;
$$;

drop trigger if exists trg_final_evaluation_questions_prevent_update on public.final_evaluation_questions;
create trigger trg_final_evaluation_questions_prevent_update
before update or delete on public.final_evaluation_questions
for each row
execute function public.prevent_update_delete();

drop trigger if exists trg_final_evaluation_answers_prevent_update on public.final_evaluation_answers;
create trigger trg_final_evaluation_answers_prevent_update
before update or delete on public.final_evaluation_answers
for each row
execute function public.prevent_update_delete();

drop trigger if exists trg_final_evaluation_evaluations_prevent_update on public.final_evaluation_evaluations;
create trigger trg_final_evaluation_evaluations_prevent_update
before update or delete on public.final_evaluation_evaluations
for each row
execute function public.prevent_update_delete();

-- 7) RLS
alter table public.final_evaluation_configs enable row level security;
alter table public.final_evaluation_attempts enable row level security;
alter table public.final_evaluation_questions enable row level security;
alter table public.final_evaluation_answers enable row level security;
alter table public.final_evaluation_evaluations enable row level security;

-- configs SELECT
create policy final_evaluation_configs_select_admin
on public.final_evaluation_configs
for select
using (public.current_role() in ('superadmin', 'admin_org', 'referente'));

create policy final_evaluation_configs_insert_admin
on public.final_evaluation_configs
for insert
with check (public.current_role() in ('superadmin', 'admin_org'));

create policy final_evaluation_configs_update_admin
on public.final_evaluation_configs
for update
using (public.current_role() in ('superadmin', 'admin_org'))
with check (public.current_role() in ('superadmin', 'admin_org'));

-- attempts SELECT
create policy final_evaluation_attempts_select_superadmin
on public.final_evaluation_attempts
for select
using (public.current_role() = 'superadmin');

create policy final_evaluation_attempts_select_admin_org
on public.final_evaluation_attempts
for select
using (
  public.current_role() = 'admin_org'
  and exists (
    select 1
    from public.learner_trainings lt
    join public.locals l on l.id = lt.local_id
    where lt.learner_id = final_evaluation_attempts.learner_id
      and l.org_id = public.current_org_id()
  )
);

create policy final_evaluation_attempts_select_referente
on public.final_evaluation_attempts
for select
using (
  public.current_role() = 'referente'
  and exists (
    select 1
    from public.learner_trainings lt
    where lt.learner_id = final_evaluation_attempts.learner_id
      and lt.local_id = public.current_local_id()
  )
);

create policy final_evaluation_attempts_select_aprendiz
on public.final_evaluation_attempts
for select
using (public.current_role() = 'aprendiz' and learner_id = auth.uid());

create policy final_evaluation_attempts_insert_learner
on public.final_evaluation_attempts
for insert
with check (public.current_role() = 'aprendiz' and learner_id = auth.uid());

create policy final_evaluation_attempts_update_learner
on public.final_evaluation_attempts
for update
using (public.current_role() = 'aprendiz' and learner_id = auth.uid())
with check (public.current_role() = 'aprendiz' and learner_id = auth.uid());

-- questions SELECT
create policy final_evaluation_questions_select_visible
on public.final_evaluation_questions
for select
using (
  exists (
    select 1
    from public.final_evaluation_attempts a
    where a.id = final_evaluation_questions.attempt_id
      and (
        (public.current_role() = 'aprendiz' and a.learner_id = auth.uid())
        or public.current_role() in ('superadmin', 'admin_org', 'referente')
      )
  )
);

create policy final_evaluation_questions_insert_learner
on public.final_evaluation_questions
for insert
with check (
  exists (
    select 1
    from public.final_evaluation_attempts a
    where a.id = final_evaluation_questions.attempt_id
      and a.learner_id = auth.uid()
  )
);

-- answers SELECT
create policy final_evaluation_answers_select_visible
on public.final_evaluation_answers
for select
using (
  exists (
    select 1
    from public.final_evaluation_questions q
    join public.final_evaluation_attempts a on a.id = q.attempt_id
    where q.id = final_evaluation_answers.question_id
      and (
        (public.current_role() = 'aprendiz' and a.learner_id = auth.uid())
        or public.current_role() in ('superadmin', 'admin_org', 'referente')
      )
  )
);

create policy final_evaluation_answers_insert_learner
on public.final_evaluation_answers
for insert
with check (
  exists (
    select 1
    from public.final_evaluation_questions q
    join public.final_evaluation_attempts a on a.id = q.attempt_id
    where q.id = final_evaluation_answers.question_id
      and a.learner_id = auth.uid()
  )
);

-- evaluations SELECT
create policy final_evaluation_evaluations_select_visible
on public.final_evaluation_evaluations
for select
using (
  exists (
    select 1
    from public.final_evaluation_answers ans
    join public.final_evaluation_questions q on q.id = ans.question_id
    join public.final_evaluation_attempts a on a.id = q.attempt_id
    where ans.id = final_evaluation_evaluations.answer_id
      and (
        (public.current_role() = 'aprendiz' and a.learner_id = auth.uid())
        or public.current_role() in ('superadmin', 'admin_org', 'referente')
      )
  )
);

create policy final_evaluation_evaluations_insert_learner
on public.final_evaluation_evaluations
for insert
with check (
  exists (
    select 1
    from public.final_evaluation_answers ans
    join public.final_evaluation_questions q on q.id = ans.question_id
    join public.final_evaluation_attempts a on a.id = q.attempt_id
    where ans.id = final_evaluation_evaluations.answer_id
      and a.learner_id = auth.uid()
    )
);

-- learner_state_transitions INSERT for learner self actions (final evaluation)
create policy learner_state_transitions_insert_learner
on public.learner_state_transitions
for insert
with check (
  public.current_role() = 'aprendiz'
  and learner_id = auth.uid()
  and actor_user_id = auth.uid()
);

-- learner_trainings UPDATE for learner (status to en_practica/en_revision)
create policy learner_trainings_update_learner_final
on public.learner_trainings
for update
using (
  public.current_role() = 'aprendiz'
  and learner_id = auth.uid()
)
with check (
  public.current_role() = 'aprendiz'
  and learner_id = auth.uid()
  and status in ('en_practica', 'en_revision')
);
