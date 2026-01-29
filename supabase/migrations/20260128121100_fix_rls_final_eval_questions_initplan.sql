-- Fix linter: auth_rls_initplan on final_evaluation_questions_select_visible
-- Wrap auth.uid() in SELECT to avoid per-row re-evaluation.

begin;

drop policy if exists "final_evaluation_questions_select_visible"
  on public.final_evaluation_questions;

create policy "final_evaluation_questions_select_visible"
on public.final_evaluation_questions
for select
to public
using (
  exists (
    select 1
    from public.final_evaluation_attempts a
    where a.id = final_evaluation_questions.attempt_id
      and (
        (
          public.current_role() = 'aprendiz'::public.app_role
          and a.learner_id = (select auth.uid())
        )
        or (
          public.current_role() = 'referente'::public.app_role
          and exists (
            select 1
            from public.learner_trainings lt
            where lt.learner_id = a.learner_id
              and lt.program_id = a.program_id
              and lt.local_id = public.current_local_id()
          )
        )
        or (
          public.current_role() = 'admin_org'::public.app_role
          and exists (
            select 1
            from public.learner_trainings lt
            join public.locals l on l.id = lt.local_id
            where lt.learner_id = a.learner_id
              and lt.program_id = a.program_id
              and l.org_id = public.current_org_id()
          )
        )
        or (
          public.current_role() = 'superadmin'::public.app_role
        )
      )
  )
);

commit;
