-- LOTE 5: Server-only writes for conversations/messages

-- conversations INSERT (learner only, active unit)
create policy conversations_insert_learner
on public.conversations
for insert
with check (
  public.current_role() = 'aprendiz'
  and learner_id = auth.uid()
  and exists (
    select 1
    from public.learner_trainings lt
    where lt.learner_id = auth.uid()
      and lt.local_id = conversations.local_id
      and lt.program_id = conversations.program_id
      and lt.current_unit_order = conversations.unit_order
  )
);

-- conversation_messages INSERT (learner owns conversation)
create policy conversation_messages_insert_learner
on public.conversation_messages
for insert
with check (
  exists (
    select 1
    from public.conversations c
    where c.id = conversation_messages.conversation_id
      and c.learner_id = auth.uid()
  )
);

-- bot_message_evaluations INSERT (learner owns message via conversation)
create policy bot_message_evaluations_insert_learner
on public.bot_message_evaluations
for insert
with check (
  exists (
    select 1
    from public.conversation_messages cm
    join public.conversations c on c.id = cm.conversation_id
    where cm.id = bot_message_evaluations.message_id
      and c.learner_id = auth.uid()
  )
);
