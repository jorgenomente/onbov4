-- RLS lint cleanup: initplan fixes + select policy consolidations (batch 1)

-- InitPlan fixes (wrap auth.uid() in select)

drop policy if exists "final_evaluation_questions_insert_learner" on public.final_evaluation_questions;
create policy "final_evaluation_questions_insert_learner"
  on public.final_evaluation_questions
  for insert
  with check (
    exists (
      select 1
      from public.final_evaluation_attempts a
      where a.id = final_evaluation_questions.attempt_id
        and a.learner_id = (select auth.uid())
    )
  );

drop policy if exists "practice_scenario_change_events_insert_admin_org" on public.practice_scenario_change_events;
create policy "practice_scenario_change_events_insert_admin_org"
  on public.practice_scenario_change_events
  for insert
  with check (
    (public.current_role() = 'admin_org'::public.app_role)
    and (org_id = public.current_org_id())
    and (local_id is null)
    and (actor_user_id = (select auth.uid()))
  );

drop policy if exists "practice_scenario_change_events_insert_superadmin" on public.practice_scenario_change_events;
create policy "practice_scenario_change_events_insert_superadmin"
  on public.practice_scenario_change_events
  for insert
  with check (
    (public.current_role() = 'superadmin'::public.app_role)
    and (actor_user_id = (select auth.uid()))
  );

-- Multiple permissive policies: consolidate SELECT (batch 1)

-- alert_events

drop policy if exists "alert_events_select_admin_org" on public.alert_events;
drop policy if exists "alert_events_select_aprendiz" on public.alert_events;
drop policy if exists "alert_events_select_referente" on public.alert_events;
drop policy if exists "alert_events_select_superadmin" on public.alert_events;

create policy "alert_events_select_authenticated"
  on public.alert_events
  for select
  to public
  using (
    ((public.current_role() = 'admin_org'::public.app_role) and (org_id = public.current_org_id()))
    or ((public.current_role() = 'aprendiz'::public.app_role) and (learner_id = (select auth.uid())))
    or ((public.current_role() = 'referente'::public.app_role) and (local_id = public.current_local_id()))
    or (public.current_role() = 'superadmin'::public.app_role)
  );

-- final_evaluation_attempts

drop policy if exists "final_evaluation_attempts_select_admin_org" on public.final_evaluation_attempts;
drop policy if exists "final_evaluation_attempts_select_aprendiz" on public.final_evaluation_attempts;
drop policy if exists "final_evaluation_attempts_select_referente" on public.final_evaluation_attempts;
drop policy if exists "final_evaluation_attempts_select_superadmin" on public.final_evaluation_attempts;

create policy "final_evaluation_attempts_select_authenticated"
  on public.final_evaluation_attempts
  for select
  to public
  using (
    ((public.current_role() = 'admin_org'::public.app_role) and (exists (
      select 1
      from public.learner_trainings lt
        join public.locals l on (l.id = lt.local_id)
      where (lt.learner_id = final_evaluation_attempts.learner_id)
        and (l.org_id = public.current_org_id())
    )))
    or ((public.current_role() = 'aprendiz'::public.app_role) and (learner_id = (select auth.uid())))
    or ((public.current_role() = 'referente'::public.app_role) and (exists (
      select 1
      from public.learner_trainings lt
      where (lt.learner_id = final_evaluation_attempts.learner_id)
        and (lt.local_id = public.current_local_id())
    )))
    or (public.current_role() = 'superadmin'::public.app_role)
  );

-- learner_trainings

drop policy if exists "learner_trainings_select_admin_org" on public.learner_trainings;
drop policy if exists "learner_trainings_select_aprendiz" on public.learner_trainings;
drop policy if exists "learner_trainings_select_referente" on public.learner_trainings;
drop policy if exists "learner_trainings_select_superadmin" on public.learner_trainings;

create policy "learner_trainings_select_authenticated"
  on public.learner_trainings
  for select
  to public
  using (
    ((public.current_role() = 'admin_org'::public.app_role) and (exists (
      select 1
      from public.locals l
      where (l.id = learner_trainings.local_id)
        and (l.org_id = public.current_org_id())
    )))
    or ((public.current_role() = 'aprendiz'::public.app_role) and (learner_id = (select auth.uid())))
    or ((public.current_role() = 'referente'::public.app_role) and (local_id = public.current_local_id()))
    or (public.current_role() = 'superadmin'::public.app_role)
  );

-- practice_attempt_events

drop policy if exists "practice_attempt_events_select_admin_org" on public.practice_attempt_events;
drop policy if exists "practice_attempt_events_select_aprendiz" on public.practice_attempt_events;
drop policy if exists "practice_attempt_events_select_referente" on public.practice_attempt_events;
drop policy if exists "practice_attempt_events_select_superadmin" on public.practice_attempt_events;

create policy "practice_attempt_events_select_authenticated"
  on public.practice_attempt_events
  for select
  to public
  using (
    ((public.current_role() = 'admin_org'::public.app_role) and (exists (
      select 1
      from public.practice_attempts pa
        join public.locals l on (l.id = pa.local_id)
      where (pa.id = practice_attempt_events.attempt_id)
        and (l.org_id = public.current_org_id())
    )))
    or ((public.current_role() = 'aprendiz'::public.app_role) and (exists (
      select 1
      from public.practice_attempts pa
      where (pa.id = practice_attempt_events.attempt_id)
        and (pa.learner_id = (select auth.uid()))
    )))
    or ((public.current_role() = 'referente'::public.app_role) and (exists (
      select 1
      from public.practice_attempts pa
      where (pa.id = practice_attempt_events.attempt_id)
        and (pa.local_id = public.current_local_id())
    )))
    or (public.current_role() = 'superadmin'::public.app_role)
  );

-- practice_attempts

drop policy if exists "practice_attempts_select_admin_org" on public.practice_attempts;
drop policy if exists "practice_attempts_select_aprendiz" on public.practice_attempts;
drop policy if exists "practice_attempts_select_referente" on public.practice_attempts;
drop policy if exists "practice_attempts_select_superadmin" on public.practice_attempts;

create policy "practice_attempts_select_authenticated"
  on public.practice_attempts
  for select
  to public
  using (
    ((public.current_role() = 'admin_org'::public.app_role) and (exists (
      select 1
      from public.locals l
      where (l.id = practice_attempts.local_id)
        and (l.org_id = public.current_org_id())
    )))
    or ((public.current_role() = 'aprendiz'::public.app_role) and (learner_id = (select auth.uid())))
    or ((public.current_role() = 'referente'::public.app_role) and (local_id = public.current_local_id()))
    or (public.current_role() = 'superadmin'::public.app_role)
  );

-- practice_evaluations

drop policy if exists "practice_evaluations_select_admin_org" on public.practice_evaluations;
drop policy if exists "practice_evaluations_select_aprendiz" on public.practice_evaluations;
drop policy if exists "practice_evaluations_select_referente" on public.practice_evaluations;
drop policy if exists "practice_evaluations_select_superadmin" on public.practice_evaluations;

create policy "practice_evaluations_select_authenticated"
  on public.practice_evaluations
  for select
  to public
  using (
    ((public.current_role() = 'admin_org'::public.app_role) and (exists (
      select 1
      from public.practice_attempts pa
        join public.locals l on (l.id = pa.local_id)
      where (pa.id = practice_evaluations.attempt_id)
        and (l.org_id = public.current_org_id())
    )))
    or ((public.current_role() = 'aprendiz'::public.app_role) and (exists (
      select 1
      from public.practice_attempts pa
      where (pa.id = practice_evaluations.attempt_id)
        and (pa.learner_id = (select auth.uid()))
    )))
    or ((public.current_role() = 'referente'::public.app_role) and (exists (
      select 1
      from public.practice_attempts pa
      where (pa.id = practice_evaluations.attempt_id)
        and (pa.local_id = public.current_local_id())
    )))
    or (public.current_role() = 'superadmin'::public.app_role)
  );
