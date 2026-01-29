-- Fix linter: multiple_permissive_policies (conversations SELECT)
-- Consolidate SELECT policies into a single policy with equivalent OR logic.

begin;

drop policy if exists "conversations_select_admin_org" on public.conversations;
drop policy if exists "conversations_select_aprendiz" on public.conversations;
drop policy if exists "conversations_select_referente" on public.conversations;
drop policy if exists "conversations_select_superadmin" on public.conversations;

create policy "conversations_select_authenticated"
on public.conversations
for select
to public
using (
  (
    (public.current_role() = 'admin_org'::public.app_role)
    and exists (
      select 1
      from public.locals l
      where l.id = conversations.local_id
        and l.org_id = public.current_org_id()
    )
  )
  or (
    (public.current_role() = 'aprendiz'::public.app_role)
    and learner_id = (select auth.uid())
  )
  or (
    (public.current_role() = 'referente'::public.app_role)
    and local_id = public.current_local_id()
  )
  or (
    public.current_role() = 'superadmin'::public.app_role
  )
);

commit;
