-- LOTE 7: Panel de revision + decisiones humanas (append-only)

-- 1) learner_review_decisions (append-only)
create table if not exists public.learner_review_decisions (
  id uuid primary key default gen_random_uuid(),
  learner_id uuid not null references public.profiles(user_id) on delete cascade,
  reviewer_id uuid not null references public.profiles(user_id) on delete restrict,
  decision text not null,
  reason text not null,
  created_at timestamptz not null default now(),
  constraint learner_review_decisions_decision_check check (decision in ('approved', 'needs_reinforcement'))
);

create index if not exists learner_review_decisions_learner_id_idx on public.learner_review_decisions (learner_id);
create index if not exists learner_review_decisions_reviewer_id_idx on public.learner_review_decisions (reviewer_id);
create index if not exists learner_review_decisions_created_at_idx on public.learner_review_decisions (created_at);

-- 2) Append-only guard
create or replace function public.prevent_update_delete()
returns trigger
language plpgsql
as $$
begin
  raise exception 'append-only table: % is not allowed', tg_op;
end;
$$;

drop trigger if exists trg_learner_review_decisions_prevent_update on public.learner_review_decisions;
create trigger trg_learner_review_decisions_prevent_update
before update or delete on public.learner_review_decisions
for each row
execute function public.prevent_update_delete();

-- 3) RLS
alter table public.learner_review_decisions enable row level security;

-- SELECT policies
create policy learner_review_decisions_select_superadmin
on public.learner_review_decisions
for select
using (public.current_role() = 'superadmin');

create policy learner_review_decisions_select_admin_org
on public.learner_review_decisions
for select
using (
  public.current_role() = 'admin_org'
  and exists (
    select 1
    from public.learner_trainings lt
    join public.locals l on l.id = lt.local_id
    where lt.learner_id = learner_review_decisions.learner_id
      and l.org_id = public.current_org_id()
  )
);

create policy learner_review_decisions_select_referente
on public.learner_review_decisions
for select
using (
  public.current_role() = 'referente'
  and exists (
    select 1
    from public.learner_trainings lt
    where lt.learner_id = learner_review_decisions.learner_id
      and lt.local_id = public.current_local_id()
  )
);

create policy learner_review_decisions_select_aprendiz_latest
on public.learner_review_decisions
for select
using (
  public.current_role() = 'aprendiz'
  and learner_id = auth.uid()
  and not exists (
    select 1
    from public.learner_review_decisions newer
    where newer.learner_id = learner_review_decisions.learner_id
      and newer.created_at > learner_review_decisions.created_at
  )
);

-- INSERT policies (server flows via user session)
create policy learner_review_decisions_insert_reviewer
on public.learner_review_decisions
for insert
with check (
  reviewer_id = auth.uid()
  and public.current_role() in ('superadmin', 'admin_org', 'referente')
  and (
    public.current_role() = 'superadmin'
    or exists (
      select 1
      from public.learner_trainings lt
      join public.locals l on l.id = lt.local_id
      where lt.learner_id = learner_review_decisions.learner_id
        and (
          (public.current_role() = 'admin_org' and l.org_id = public.current_org_id())
          or (public.current_role() = 'referente' and lt.local_id = public.current_local_id())
        )
    )
  )
);

-- learner_state_transitions INSERT for reviewers
create policy learner_state_transitions_insert_reviewer
on public.learner_state_transitions
for insert
with check (
  actor_user_id = auth.uid()
  and public.current_role() in ('superadmin', 'admin_org', 'referente')
  and (
    public.current_role() = 'superadmin'
    or exists (
      select 1
      from public.learner_trainings lt
      join public.locals l on l.id = lt.local_id
      where lt.learner_id = learner_state_transitions.learner_id
        and (
          (public.current_role() = 'admin_org' and l.org_id = public.current_org_id())
          or (public.current_role() = 'referente' and lt.local_id = public.current_local_id())
        )
    )
  )
);

-- learner_trainings UPDATE for reviewers (status updates)
create policy learner_trainings_update_reviewer
on public.learner_trainings
for update
using (
  public.current_role() in ('superadmin', 'admin_org', 'referente')
  and (
    public.current_role() = 'superadmin'
    or exists (
      select 1
      from public.locals l
      where l.id = learner_trainings.local_id
        and (
          (public.current_role() = 'admin_org' and l.org_id = public.current_org_id())
          or (public.current_role() = 'referente' and learner_trainings.local_id = public.current_local_id())
        )
    )
  )
)
with check (
  public.current_role() in ('superadmin', 'admin_org', 'referente')
  and (
    public.current_role() = 'superadmin'
    or exists (
      select 1
      from public.locals l
      where l.id = learner_trainings.local_id
        and (
          (public.current_role() = 'admin_org' and l.org_id = public.current_org_id())
          or (public.current_role() = 'referente' and learner_trainings.local_id = public.current_local_id())
        )
    )
  )
);

-- 4) Views
create or replace view public.v_review_queue as
select
  lt.learner_id,
  p.full_name,
  lt.local_id,
  lt.status,
  lt.progress_percent,
  greatest(
    coalesce(msgs.last_message_at, lt.updated_at),
    coalesce(pract.last_practice_at, lt.updated_at),
    lt.updated_at
  ) as last_activity_at,
  exists (
    select 1
    from public.practice_evaluations pe
    join public.practice_attempts pa on pa.id = pe.attempt_id
    where pa.learner_id = lt.learner_id
      and (pe.verdict = 'fail' or coalesce(array_length(pe.doubt_signals, 1), 0) > 0)
  ) as has_doubt_signals,
  exists (
    select 1
    from public.practice_evaluations pe
    join public.practice_attempts pa on pa.id = pe.attempt_id
    where pa.learner_id = lt.learner_id
      and pe.verdict = 'fail'
  ) as has_failed_practice
from public.learner_trainings lt
join public.profiles p on p.user_id = lt.learner_id
left join lateral (
  select max(cm.created_at) as last_message_at
  from public.conversation_messages cm
  join public.conversations c on c.id = cm.conversation_id
  where c.learner_id = lt.learner_id
) msgs on true
left join lateral (
  select max(pe.created_at) as last_practice_at
  from public.practice_evaluations pe
  join public.practice_attempts pa on pa.id = pe.attempt_id
  where pa.learner_id = lt.learner_id
) pract on true
where lt.status = 'en_revision';

create or replace view public.v_learner_evidence as
select
  lt.learner_id,
  practice.practice_summary,
  doubts.doubt_signals,
  messages.recent_messages
from public.learner_trainings lt
left join lateral (
  select coalesce(
    json_agg(
      json_build_object(
        'scenario_title', pe.scenario_title,
        'score', pe.score,
        'verdict', pe.verdict,
        'feedback', pe.feedback,
        'created_at', pe.created_at
      )
      order by pe.created_at desc
    ),
    '[]'::json
  ) as practice_summary
  from (
    select
      ps.title as scenario_title,
      pev.score,
      pev.verdict,
      pev.feedback,
      pev.created_at
    from public.practice_evaluations pev
    join public.practice_attempts pa on pa.id = pev.attempt_id
    join public.practice_scenarios ps on ps.id = pa.scenario_id
    where pa.learner_id = lt.learner_id
    order by pev.created_at desc
    limit 10
  ) pe
) practice on true
left join lateral (
  select coalesce(array_agg(distinct signal), '{}'::text[]) as doubt_signals
  from public.practice_evaluations pev
  join public.practice_attempts pa on pa.id = pev.attempt_id
  left join lateral unnest(pev.doubt_signals) as signal on true
  where pa.learner_id = lt.learner_id
) doubts on true
left join lateral (
  select coalesce(
    json_agg(
      json_build_object(
        'sender', cm.sender,
        'content', cm.content,
        'created_at', cm.created_at
      )
      order by cm.created_at desc
    ),
    '[]'::json
  ) as recent_messages
  from (
    select cm.sender, cm.content, cm.created_at
    from public.conversation_messages cm
    join public.conversations c on c.id = cm.conversation_id
    where c.learner_id = lt.learner_id
    order by cm.created_at desc
    limit 5
  ) cm
) messages on true;
