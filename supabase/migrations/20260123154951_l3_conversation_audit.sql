-- LOTE 3: Conversacion persistente + auditoria (append-only)

-- 1) conversations
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  learner_id uuid not null references public.profiles(user_id) on delete cascade,
  local_id uuid not null references public.locals(id) on delete restrict,
  program_id uuid not null references public.training_programs(id) on delete restrict,
  unit_order int not null,
  context text not null,
  created_at timestamptz not null default now(),
  constraint conversations_unit_order_check check (unit_order >= 1)
);

create index if not exists conversations_learner_id_idx on public.conversations (learner_id);
create index if not exists conversations_local_id_idx on public.conversations (local_id);
create index if not exists conversations_program_id_idx on public.conversations (program_id);

-- 2) conversation_messages (append-only)
create table if not exists public.conversation_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender text not null,
  content text not null,
  created_at timestamptz not null default now(),
  constraint conversation_messages_sender_check check (sender in ('learner', 'bot', 'system'))
);

create index if not exists conversation_messages_conversation_id_idx on public.conversation_messages (conversation_id);
create index if not exists conversation_messages_created_at_idx on public.conversation_messages (created_at);

-- 3) bot_message_evaluations (optional base for metrics)
create table if not exists public.bot_message_evaluations (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.conversation_messages(id) on delete cascade,
  coherence_score numeric(4,2) null,
  omissions text[] null,
  tags text[] null,
  created_at timestamptz not null default now()
);

create index if not exists bot_message_evaluations_message_id_idx on public.bot_message_evaluations (message_id);
create index if not exists bot_message_evaluations_created_at_idx on public.bot_message_evaluations (created_at);

-- 4) Append-only guards (no update/delete)
create or replace function public.prevent_update_delete()
returns trigger
language plpgsql
as $$
begin
  raise exception 'append-only table: % is not allowed', tg_op;
end;
$$;

drop trigger if exists trg_conversations_prevent_update on public.conversations;
create trigger trg_conversations_prevent_update
before update or delete on public.conversations
for each row
execute function public.prevent_update_delete();

drop trigger if exists trg_conversation_messages_prevent_update on public.conversation_messages;
create trigger trg_conversation_messages_prevent_update
before update or delete on public.conversation_messages
for each row
execute function public.prevent_update_delete();

drop trigger if exists trg_bot_message_evaluations_prevent_update on public.bot_message_evaluations;
create trigger trg_bot_message_evaluations_prevent_update
before update or delete on public.bot_message_evaluations
for each row
execute function public.prevent_update_delete();

-- 5) RLS
alter table public.conversations enable row level security;
alter table public.conversation_messages enable row level security;
alter table public.bot_message_evaluations enable row level security;

-- conversations SELECT
create policy conversations_select_superadmin
on public.conversations
for select
using (public.current_role() = 'superadmin');

create policy conversations_select_admin_org
on public.conversations
for select
using (
  public.current_role() = 'admin_org'
  and exists (
    select 1
    from public.locals l
    where l.id = conversations.local_id
      and l.org_id = public.current_org_id()
  )
);

create policy conversations_select_referente
on public.conversations
for select
using (
  public.current_role() = 'referente'
  and local_id = public.current_local_id()
);

create policy conversations_select_aprendiz
on public.conversations
for select
using (
  public.current_role() = 'aprendiz'
  and learner_id = auth.uid()
);

-- conversation_messages SELECT (via conversations visibility)
create policy conversation_messages_select_visible
on public.conversation_messages
for select
using (
  exists (
    select 1
    from public.conversations c
    where c.id = conversation_messages.conversation_id
  )
);

-- bot_message_evaluations SELECT (via conversation_messages visibility)
create policy bot_message_evaluations_select_visible
on public.bot_message_evaluations
for select
using (
  exists (
    select 1
    from public.conversation_messages cm
    join public.conversations c on c.id = cm.conversation_id
    where cm.id = bot_message_evaluations.message_id
  )
);

-- Writes are server-only (RPC/Server Actions). No INSERT/UPDATE/DELETE policies defined here.

-- 6) Views
create or replace view public.v_learner_active_conversation as
select
  c.id as conversation_id,
  c.unit_order,
  c.context,
  c.created_at
from public.learner_trainings lt
left join lateral (
  select
    conv.id,
    conv.unit_order,
    conv.context,
    conv.created_at
  from public.conversations conv
  where conv.learner_id = lt.learner_id
    and conv.unit_order = lt.current_unit_order
  order by conv.created_at desc
  limit 1
) c on true
where lt.learner_id = auth.uid();

create or replace view public.v_conversation_thread as
select
  cm.id as message_id,
  cm.sender,
  cm.content,
  cm.created_at
from public.conversation_messages cm
order by cm.created_at asc;

create or replace view public.v_referente_conversation_summary as
select
  c.id as conversation_id,
  c.learner_id,
  p.full_name,
  c.unit_order,
  max(cm.created_at) as last_message_at,
  count(cm.id)::int as total_messages
from public.conversations c
join public.profiles p on p.user_id = c.learner_id
left join public.conversation_messages cm on cm.conversation_id = c.id
where p.role = 'aprendiz'
group by
  c.id,
  c.learner_id,
  p.full_name,
  c.unit_order;
