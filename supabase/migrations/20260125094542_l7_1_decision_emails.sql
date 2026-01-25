-- LOTE 7.1: Emails de decision (append-only)

-- 1) notification_emails
create table if not exists public.notification_emails (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete restrict,
  local_id uuid not null references public.locals(id) on delete restrict,
  learner_id uuid not null references public.profiles(user_id) on delete cascade,
  decision_id uuid not null references public.learner_review_decisions(id) on delete cascade,
  email_type text not null,
  to_email text not null,
  subject text not null,
  provider text not null default 'resend',
  provider_message_id text null,
  status text not null,
  error text null,
  created_at timestamptz not null default now(),
  constraint notification_emails_type_check check (email_type in ('decision_approved', 'decision_needs_reinforcement')),
  constraint notification_emails_status_check check (status in ('sent', 'failed')),
  constraint notification_emails_unique_decision unique (decision_id, email_type)
);

create index if not exists notification_emails_learner_id_idx on public.notification_emails (learner_id);
create index if not exists notification_emails_decision_id_idx on public.notification_emails (decision_id);
create index if not exists notification_emails_created_at_idx on public.notification_emails (created_at);

-- 2) Append-only guard
create or replace function public.prevent_update_delete()
returns trigger
language plpgsql
as $$
begin
  raise exception 'append-only table: % is not allowed', tg_op;
end;
$$;

drop trigger if exists trg_notification_emails_prevent_update on public.notification_emails;
create trigger trg_notification_emails_prevent_update
before update or delete on public.notification_emails
for each row
execute function public.prevent_update_delete();

-- 3) RLS
alter table public.notification_emails enable row level security;

create policy notification_emails_select_superadmin
on public.notification_emails
for select
using (public.current_role() = 'superadmin');

create policy notification_emails_select_admin_org
on public.notification_emails
for select
using (
  public.current_role() = 'admin_org'
  and exists (
    select 1
    from public.learner_trainings lt
    join public.locals l on l.id = lt.local_id
    where lt.learner_id = notification_emails.learner_id
      and l.org_id = public.current_org_id()
  )
);

create policy notification_emails_select_referente
on public.notification_emails
for select
using (
  public.current_role() = 'referente'
  and exists (
    select 1
    from public.learner_trainings lt
    where lt.learner_id = notification_emails.learner_id
      and lt.local_id = public.current_local_id()
  )
);

create policy notification_emails_select_aprendiz
on public.notification_emails
for select
using (
  public.current_role() = 'aprendiz'
  and learner_id = auth.uid()
);

create policy notification_emails_insert_reviewer
on public.notification_emails
for insert
with check (
  public.current_role() in ('superadmin', 'admin_org', 'referente')
  and (
    public.current_role() = 'superadmin'
    or exists (
      select 1
      from public.learner_trainings lt
      join public.locals l on l.id = lt.local_id
      where lt.learner_id = notification_emails.learner_id
        and (
          (public.current_role() = 'admin_org' and l.org_id = public.current_org_id())
          or (public.current_role() = 'referente' and lt.local_id = public.current_local_id())
        )
    )
  )
);

-- 4) helper to read learner email (security definer)
create or replace function public.get_user_email(target_user_id uuid)
returns text
language sql
security definer
set search_path = public, auth
as $$
  select u.email
  from auth.users u
  where u.id = target_user_id
    and (
      public.current_role() = 'superadmin'
      or (
        public.current_role() = 'admin_org'
        and exists (
          select 1
          from public.learner_trainings lt
          join public.locals l on l.id = lt.local_id
          where lt.learner_id = target_user_id
            and l.org_id = public.current_org_id()
        )
      )
      or (
        public.current_role() = 'referente'
        and exists (
          select 1
          from public.learner_trainings lt
          where lt.learner_id = target_user_id
            and lt.local_id = public.current_local_id()
        )
      )
      or (
        public.current_role() = 'aprendiz'
        and target_user_id = auth.uid()
      )
    )
  limit 1;
$$;
