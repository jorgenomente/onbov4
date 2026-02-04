-- RLS lint cleanup: consolidate remaining permissive policies

-- alert_events insert
drop policy if exists "alert_events_insert_aprendiz_final_evaluation" on public.alert_events;
drop policy if exists "alert_events_insert_reviewer" on public.alert_events;

create policy "alert_events_insert_public_consolidated"
  on public.alert_events
  for insert
  to public
  with check (
    ((("current_role"() = 'aprendiz'::app_role) AND (alert_type = 'final_evaluation_submitted'::alert_type) AND (learner_id = ( SELECT auth.uid() AS uid)) AND (source_table = 'final_evaluation_attempts'::text) AND (EXISTS ( SELECT 1    FROM ((final_evaluation_attempts a      JOIN learner_trainings lt ON ((lt.learner_id = a.learner_id)))      JOIN locals l ON ((l.id = lt.local_id)))   WHERE ((a.id = alert_events.source_id) AND (a.learner_id = ( SELECT auth.uid() AS uid)) AND (alert_events.local_id = lt.local_id) AND (alert_events.org_id = l.org_id))))))
    or ((("current_role"() = ANY (ARRAY['superadmin'::app_role, 'admin_org'::app_role, 'referente'::app_role])) AND (("current_role"() = 'superadmin'::app_role) OR (EXISTS ( SELECT 1    FROM (learner_trainings lt      JOIN locals l ON ((l.id = lt.local_id)))   WHERE ((lt.learner_id = alert_events.learner_id) AND (alert_events.local_id = lt.local_id) AND (alert_events.org_id = l.org_id) AND ((("current_role"() = 'admin_org'::app_role) AND (l.org_id = current_org_id())) OR (("current_role"() = 'referente'::app_role) AND (lt.local_id = current_local_id())))))))))
  );

-- final_evaluation_configs select
drop policy if exists "final_evaluation_configs_select_admin" on public.final_evaluation_configs;
drop policy if exists "final_evaluation_configs_select_aprendiz" on public.final_evaluation_configs;

create policy "final_evaluation_configs_select_public_consolidated"
  on public.final_evaluation_configs
  for select
  to public
  using (
    (("current_role"() = ANY (ARRAY['superadmin'::app_role, 'admin_org'::app_role, 'referente'::app_role])))
    or ((("current_role"() = 'aprendiz'::app_role) AND (EXISTS ( SELECT 1    FROM learner_trainings lt   WHERE ((lt.learner_id = ( SELECT auth.uid() AS uid)) AND (lt.program_id = final_evaluation_configs.program_id))))))
  );

-- knowledge_change_events select
drop policy if exists "knowledge_change_events_select_admin_org" on public.knowledge_change_events;
drop policy if exists "knowledge_change_events_select_superadmin" on public.knowledge_change_events;

create policy "knowledge_change_events_select_public_consolidated"
  on public.knowledge_change_events
  for select
  to public
  using (
    ((("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id())))
    or (("current_role"() = 'superadmin'::app_role))
  );

-- knowledge_items select
drop policy if exists "knowledge_items_select_admin_org" on public.knowledge_items;
drop policy if exists "knowledge_items_select_local_roles" on public.knowledge_items;
drop policy if exists "knowledge_items_select_superadmin" on public.knowledge_items;

create policy "knowledge_items_select_public_consolidated"
  on public.knowledge_items
  for select
  to public
  using (
    ((("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id())))
    or ((("current_role"() = ANY (ARRAY['referente'::app_role, 'aprendiz'::app_role])) AND (org_id = current_org_id()) AND ((local_id IS NULL) OR (local_id = current_local_id())) AND (is_enabled = true)))
    or (("current_role"() = 'superadmin'::app_role))
  );

-- learner_future_questions select
drop policy if exists "learner_future_questions_select_admin_org" on public.learner_future_questions;
drop policy if exists "learner_future_questions_select_aprendiz" on public.learner_future_questions;
drop policy if exists "learner_future_questions_select_referente" on public.learner_future_questions;
drop policy if exists "learner_future_questions_select_superadmin" on public.learner_future_questions;

create policy "learner_future_questions_select_public_consolidated"
  on public.learner_future_questions
  for select
  to public
  using (
    ((("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1    FROM locals l   WHERE ((l.id = learner_future_questions.local_id) AND (l.org_id = current_org_id()))))))
    or ((("current_role"() = 'aprendiz'::app_role) AND (learner_id = ( SELECT auth.uid() AS uid))))
    or ((("current_role"() = 'referente'::app_role) AND (local_id = current_local_id())))
    or (("current_role"() = 'superadmin'::app_role))
  );

-- learner_review_decisions select
drop policy if exists "learner_review_decisions_select_admin_org" on public.learner_review_decisions;
drop policy if exists "learner_review_decisions_select_aprendiz" on public.learner_review_decisions;
drop policy if exists "learner_review_decisions_select_referente" on public.learner_review_decisions;
drop policy if exists "learner_review_decisions_select_superadmin" on public.learner_review_decisions;

create policy "learner_review_decisions_select_public_consolidated"
  on public.learner_review_decisions
  for select
  to public
  using (
    ((("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1    FROM (learner_trainings lt      JOIN locals l ON ((l.id = lt.local_id)))   WHERE ((lt.learner_id = learner_review_decisions.learner_id) AND (l.org_id = current_org_id()))))))
    or ((("current_role"() = 'aprendiz'::app_role) AND (learner_id = ( SELECT auth.uid() AS uid))))
    or ((("current_role"() = 'referente'::app_role) AND (EXISTS ( SELECT 1    FROM learner_trainings lt   WHERE ((lt.learner_id = learner_review_decisions.learner_id) AND (lt.local_id = current_local_id()))))))
    or (("current_role"() = 'superadmin'::app_role))
  );

-- learner_review_validations_v2 select
drop policy if exists "learner_review_validations_v2_select_admin_org" on public.learner_review_validations_v2;
drop policy if exists "learner_review_validations_v2_select_aprendiz" on public.learner_review_validations_v2;
drop policy if exists "learner_review_validations_v2_select_referente" on public.learner_review_validations_v2;
drop policy if exists "learner_review_validations_v2_select_superadmin" on public.learner_review_validations_v2;

create policy "learner_review_validations_v2_select_public_consolidated"
  on public.learner_review_validations_v2
  for select
  to public
  using (
    ((("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1    FROM (learner_trainings lt      JOIN locals l ON ((l.id = lt.local_id)))   WHERE ((lt.learner_id = learner_review_validations_v2.learner_id) AND (l.org_id = current_org_id()))))))
    or ((("current_role"() = 'aprendiz'::app_role) AND (learner_id = ( SELECT auth.uid() AS uid))))
    or ((("current_role"() = 'referente'::app_role) AND (EXISTS ( SELECT 1    FROM learner_trainings lt   WHERE ((lt.learner_id = learner_review_validations_v2.learner_id) AND (lt.local_id = current_local_id()))))))
    or (("current_role"() = 'superadmin'::app_role))
  );

-- learner_state_transitions insert
drop policy if exists "learner_state_transitions_insert_learner" on public.learner_state_transitions;
drop policy if exists "learner_state_transitions_insert_reviewer" on public.learner_state_transitions;

create policy "learner_state_transitions_insert_public_consolidated"
  on public.learner_state_transitions
  for insert
  to public
  with check (
    ((("current_role"() = 'aprendiz'::app_role) AND (learner_id = ( SELECT auth.uid() AS uid)) AND (actor_user_id = ( SELECT auth.uid() AS uid))))
    or (((actor_user_id = ( SELECT auth.uid() AS uid)) AND ("current_role"() = ANY (ARRAY['superadmin'::app_role, 'admin_org'::app_role, 'referente'::app_role])) AND (("current_role"() = 'superadmin'::app_role) OR (EXISTS ( SELECT 1    FROM (learner_trainings lt      JOIN locals l ON ((l.id = lt.local_id)))   WHERE ((lt.learner_id = learner_state_transitions.learner_id) AND ((("current_role"() = 'admin_org'::app_role) AND (l.org_id = current_org_id())) OR (("current_role"() = 'referente'::app_role) AND (lt.local_id = current_local_id())))))))))
  );

-- learner_state_transitions select
drop policy if exists "learner_state_transitions_select_admin_org" on public.learner_state_transitions;
drop policy if exists "learner_state_transitions_select_aprendiz" on public.learner_state_transitions;
drop policy if exists "learner_state_transitions_select_referente" on public.learner_state_transitions;
drop policy if exists "learner_state_transitions_select_superadmin" on public.learner_state_transitions;

create policy "learner_state_transitions_select_public_consolidated"
  on public.learner_state_transitions
  for select
  to public
  using (
    ((("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1    FROM (learner_trainings lt      JOIN locals l ON ((l.id = lt.local_id)))   WHERE ((lt.learner_id = learner_state_transitions.learner_id) AND (l.org_id = current_org_id()))))))
    or ((("current_role"() = 'aprendiz'::app_role) AND (learner_id = ( SELECT auth.uid() AS uid))))
    or ((("current_role"() = 'referente'::app_role) AND (EXISTS ( SELECT 1    FROM learner_trainings lt   WHERE ((lt.learner_id = learner_state_transitions.learner_id) AND (lt.local_id = current_local_id()))))))
    or (("current_role"() = 'superadmin'::app_role))
  );

-- learner_trainings update
drop policy if exists "learner_trainings_update_learner_final" on public.learner_trainings;
drop policy if exists "learner_trainings_update_reviewer" on public.learner_trainings;

create policy "learner_trainings_update_public_consolidated"
  on public.learner_trainings
  for update
  to public
  using (
    ((("current_role"() = 'aprendiz'::app_role) AND (learner_id = ( SELECT auth.uid() AS uid))))
    or ((("current_role"() = ANY (ARRAY['superadmin'::app_role, 'admin_org'::app_role, 'referente'::app_role])) AND (("current_role"() = 'superadmin'::app_role) OR (EXISTS ( SELECT 1    FROM locals l   WHERE ((l.id = learner_trainings.local_id) AND ((("current_role"() = 'admin_org'::app_role) AND (l.org_id = current_org_id())) OR (("current_role"() = 'referente'::app_role) AND (learner_trainings.local_id = current_local_id())))))))))
  )
  with check (
    ((("current_role"() = 'aprendiz'::app_role) AND (learner_id = ( SELECT auth.uid() AS uid)) AND (status = ANY (ARRAY['en_practica'::learner_status, 'en_revision'::learner_status]))))
    or ((("current_role"() = ANY (ARRAY['superadmin'::app_role, 'admin_org'::app_role, 'referente'::app_role])) AND (("current_role"() = 'superadmin'::app_role) OR (EXISTS ( SELECT 1    FROM locals l   WHERE ((l.id = learner_trainings.local_id) AND ((("current_role"() = 'admin_org'::app_role) AND (l.org_id = current_org_id())) OR (("current_role"() = 'referente'::app_role) AND (learner_trainings.local_id = current_local_id())))))))))
  );

-- local_active_program_change_events select
drop policy if exists "local_active_program_change_events_select_admin_org" on public.local_active_program_change_events;
drop policy if exists "local_active_program_change_events_select_superadmin" on public.local_active_program_change_events;

create policy "local_active_program_change_events_select_public_consolidated"
  on public.local_active_program_change_events
  for select
  to public
  using (
    ((("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id())))
    or (("current_role"() = 'superadmin'::app_role))
  );

-- local_active_programs select
drop policy if exists "local_active_programs_select_admin_org" on public.local_active_programs;
drop policy if exists "local_active_programs_select_local_roles" on public.local_active_programs;
drop policy if exists "local_active_programs_select_superadmin" on public.local_active_programs;

create policy "local_active_programs_select_public_consolidated"
  on public.local_active_programs
  for select
  to public
  using (
    ((("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1    FROM locals l   WHERE ((l.id = local_active_programs.local_id) AND (l.org_id = current_org_id()))))))
    or ((("current_role"() = ANY (ARRAY['referente'::app_role, 'aprendiz'::app_role])) AND (local_id = current_local_id())))
    or (("current_role"() = 'superadmin'::app_role))
  );

-- locals select
drop policy if exists "locals_select_admin_org" on public.locals;
drop policy if exists "locals_select_own" on public.locals;
drop policy if exists "locals_select_superadmin" on public.locals;

create policy "locals_select_public_consolidated"
  on public.locals
  for select
  to public
  using (
    ((("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id())))
    or ((("current_role"() = ANY (ARRAY['referente'::app_role, 'aprendiz'::app_role])) AND (id = current_local_id())))
    or (("current_role"() = 'superadmin'::app_role))
  );

-- notification_emails select
drop policy if exists "notification_emails_select_admin_org" on public.notification_emails;
drop policy if exists "notification_emails_select_aprendiz" on public.notification_emails;
drop policy if exists "notification_emails_select_referente" on public.notification_emails;
drop policy if exists "notification_emails_select_superadmin" on public.notification_emails;

create policy "notification_emails_select_public_consolidated"
  on public.notification_emails
  for select
  to public
  using (
    ((("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1    FROM (learner_trainings lt      JOIN locals l ON ((l.id = lt.local_id)))   WHERE ((lt.learner_id = notification_emails.learner_id) AND (l.org_id = current_org_id()))))))
    or ((("current_role"() = 'aprendiz'::app_role) AND (learner_id = ( SELECT auth.uid() AS uid))))
    or ((("current_role"() = 'referente'::app_role) AND (EXISTS ( SELECT 1    FROM learner_trainings lt   WHERE ((lt.learner_id = notification_emails.learner_id) AND (lt.local_id = current_local_id()))))))
    or (("current_role"() = 'superadmin'::app_role))
  );

-- organizations select
drop policy if exists "organizations_select_own" on public.organizations;
drop policy if exists "organizations_select_superadmin" on public.organizations;

create policy "organizations_select_public_consolidated"
  on public.organizations
  for select
  to public
  using (
    ((id = current_org_id()))
    or (("current_role"() = 'superadmin'::app_role))
  );

-- practice_scenario_change_events insert
drop policy if exists "practice_scenario_change_events_insert_admin_org" on public.practice_scenario_change_events;
drop policy if exists "practice_scenario_change_events_insert_superadmin" on public.practice_scenario_change_events;

create policy "practice_scenario_change_events_insert_public_consolidated"
  on public.practice_scenario_change_events
  for insert
  to public
  with check (
    ((("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id()) AND (local_id IS NULL) AND (actor_user_id = ( SELECT auth.uid() AS uid))))
    or ((("current_role"() = 'superadmin'::app_role) AND (actor_user_id = ( SELECT auth.uid() AS uid))))
  );

-- practice_scenario_change_events select
drop policy if exists "practice_scenario_change_events_select_admin_org" on public.practice_scenario_change_events;
drop policy if exists "practice_scenario_change_events_select_referente" on public.practice_scenario_change_events;
drop policy if exists "practice_scenario_change_events_select_superadmin" on public.practice_scenario_change_events;

create policy "practice_scenario_change_events_select_public_consolidated"
  on public.practice_scenario_change_events
  for select
  to public
  using (
    ((("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id())))
    or ((("current_role"() = 'referente'::app_role) AND (local_id = current_local_id())))
    or (("current_role"() = 'superadmin'::app_role))
  );

-- practice_scenarios insert
drop policy if exists "practice_scenarios_insert_admin_org" on public.practice_scenarios;
drop policy if exists "practice_scenarios_insert_superadmin" on public.practice_scenarios;

create policy "practice_scenarios_insert_public_consolidated"
  on public.practice_scenarios
  for insert
  to public
  with check (
    ((("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id()) AND (local_id IS NULL)))
    or (("current_role"() = 'superadmin'::app_role))
  );

-- practice_scenarios select
drop policy if exists "practice_scenarios_select_admin_org" on public.practice_scenarios;
drop policy if exists "practice_scenarios_select_local_roles" on public.practice_scenarios;
drop policy if exists "practice_scenarios_select_superadmin" on public.practice_scenarios;

create policy "practice_scenarios_select_public_consolidated"
  on public.practice_scenarios
  for select
  to public
  using (
    ((("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id())))
    or ((("current_role"() = ANY (ARRAY['referente'::app_role, 'aprendiz'::app_role])) AND (org_id = current_org_id()) AND ((local_id IS NULL) OR (local_id = current_local_id()))))
    or (("current_role"() = 'superadmin'::app_role))
  );

-- practice_scenarios update
drop policy if exists "practice_scenarios_update_admin_org" on public.practice_scenarios;
drop policy if exists "practice_scenarios_update_superadmin" on public.practice_scenarios;

create policy "practice_scenarios_update_public_consolidated"
  on public.practice_scenarios
  for update
  to public
  using (
    ((("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id()) AND (local_id IS NULL)))
    or (("current_role"() = 'superadmin'::app_role))
  )
  with check (
    ((("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id()) AND (local_id IS NULL)))
    or (("current_role"() = 'superadmin'::app_role))
  );

-- profiles select
drop policy if exists "profiles_select_admin_org" on public.profiles;
drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_select_referente" on public.profiles;
drop policy if exists "profiles_select_superadmin" on public.profiles;

create policy "profiles_select_public_consolidated"
  on public.profiles
  for select
  to public
  using (
    ((("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id())))
    or ((user_id = ( SELECT auth.uid() AS uid)))
    or ((("current_role"() = 'referente'::app_role) AND (local_id = current_local_id())))
    or (("current_role"() = 'superadmin'::app_role))
  );

-- training_programs select
drop policy if exists "training_programs_select_admin_org" on public.training_programs;
drop policy if exists "training_programs_select_local_roles" on public.training_programs;
drop policy if exists "training_programs_select_superadmin" on public.training_programs;

create policy "training_programs_select_public_consolidated"
  on public.training_programs
  for select
  to public
  using (
    ((("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id())))
    or ((("current_role"() = ANY (ARRAY['referente'::app_role, 'aprendiz'::app_role])) AND (org_id = current_org_id()) AND ((local_id IS NULL) OR (local_id = current_local_id()))))
    or (("current_role"() = 'superadmin'::app_role))
  );
