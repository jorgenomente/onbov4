-- Fix Supabase linter: auth_rls_initplan
-- Recreate affected RLS policies replacing auth.* and current_setting() calls
-- to be initplan-friendly: (select auth.uid()), etc.
-- Safe: does not change logic, only wraps volatile calls to avoid per-row re-eval.

do $$
declare
  r record;
  v_roles text;
  v_as text;
  v_cmd text;
  v_qual text;
  v_check text;
begin
  -- Iterate policies that match the known problematic names list
  for r in
    select
      schemaname,
      tablename,
      policyname,
      permissive,
      roles,
      cmd,
      qual,
      with_check
    from pg_policies
    where schemaname = 'public'
      and (
        -- alert_events
        (tablename = 'alert_events' and policyname in (
          'alert_events_insert_aprendiz_final_evaluation',
          'alert_events_select_aprendiz'
        ))
        -- bot_message_evaluations
        or (tablename = 'bot_message_evaluations' and policyname in (
          'bot_message_evaluations_insert_learner'
        ))
        -- conversation_messages
        or (tablename = 'conversation_messages' and policyname in (
          'conversation_messages_insert_learner'
        ))
        -- conversations
        or (tablename = 'conversations' and policyname in (
          'conversations_insert_learner',
          'conversations_select_aprendiz'
        ))
        -- final_evaluation_answers
        or (tablename = 'final_evaluation_answers' and policyname in (
          'final_evaluation_answers_insert_learner',
          'final_evaluation_answers_select_visible'
        ))
        -- final_evaluation_attempts
        or (tablename = 'final_evaluation_attempts' and policyname in (
          'final_evaluation_attempts_insert_learner',
          'final_evaluation_attempts_select_aprendiz',
          'final_evaluation_attempts_update_learner'
        ))
        -- final_evaluation_configs
        or (tablename = 'final_evaluation_configs' and policyname in (
          'final_evaluation_configs_select_aprendiz'
        ))
        -- final_evaluation_evaluations
        or (tablename = 'final_evaluation_evaluations' and policyname in (
          'final_evaluation_evaluations_insert_learner',
          'final_evaluation_evaluations_select_visible'
        ))
        -- learner_future_questions
        or (tablename = 'learner_future_questions' and policyname in (
          'learner_future_questions_select_aprendiz'
        ))
        -- learner_review_decisions
        or (tablename = 'learner_review_decisions' and policyname in (
          'learner_review_decisions_insert_reviewer',
          'learner_review_decisions_select_aprendiz'
        ))
        -- learner_review_validations_v2
        or (tablename = 'learner_review_validations_v2' and policyname in (
          'learner_review_validations_v2_insert_reviewer',
          'learner_review_validations_v2_select_aprendiz'
        ))
        -- learner_state_transitions
        or (tablename = 'learner_state_transitions' and policyname in (
          'learner_state_transitions_insert_learner',
          'learner_state_transitions_insert_reviewer',
          'learner_state_transitions_select_aprendiz'
        ))
        -- learner_trainings
        or (tablename = 'learner_trainings' and policyname in (
          'learner_trainings_select_aprendiz',
          'learner_trainings_update_learner_final'
        ))
        -- notification_emails
        or (tablename = 'notification_emails' and policyname in (
          'notification_emails_select_aprendiz'
        ))
        -- practice_attempt_events
        or (tablename = 'practice_attempt_events' and policyname in (
          'practice_attempt_events_insert_learner',
          'practice_attempt_events_select_aprendiz'
        ))
        -- practice_attempts
        or (tablename = 'practice_attempts' and policyname in (
          'practice_attempts_insert_learner',
          'practice_attempts_select_aprendiz'
        ))
        -- practice_evaluations
        or (tablename = 'practice_evaluations' and policyname in (
          'practice_evaluations_insert_learner',
          'practice_evaluations_select_aprendiz'
        ))
        -- practice_scenario_change_events
        or (tablename = 'practice_scenario_change_events' and policyname in (
          'practice_scenario_change_events_insert_admin_org',
          'practice_scenario_change_events_insert_superadmin'
        ))
        -- profiles
        or (tablename = 'profiles' and policyname in (
          'profiles_select_own',
          'profiles_update_own'
        ))
      )
  loop
    if r.permissive = 'PERMISSIVE' then
      v_as := 'as permissive';
    else
      v_as := 'as restrictive';
    end if;

    if r.roles is null or array_length(r.roles, 1) is null then
      v_roles := 'to public';
    else
      select 'to ' || string_agg(quote_ident(x), ', ')
      into v_roles
      from unnest(r.roles) as x;
    end if;

    v_cmd := lower(r.cmd);

    v_qual := r.qual;
    v_check := r.with_check;

    if v_qual is not null then
      v_qual := replace(v_qual, 'auth.uid()', '(select auth.uid())');
      v_qual := replace(v_qual, 'auth.role()', '(select auth.role())');
      v_qual := replace(v_qual, 'current_setting(', '(select current_setting(');
    end if;

    if v_check is not null then
      v_check := replace(v_check, 'auth.uid()', '(select auth.uid())');
      v_check := replace(v_check, 'auth.role()', '(select auth.role())');
      v_check := replace(v_check, 'current_setting(', '(select current_setting(');
    end if;

    execute format(
      'drop policy if exists %I on %I.%I;',
      r.policyname, r.schemaname, r.tablename
    );

    execute (
      'create policy ' || quote_ident(r.policyname) ||
      ' on ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' ' ||
      v_as || ' for ' || v_cmd || ' ' ||
      v_roles ||
      case when v_qual is not null then ' using (' || v_qual || ')' else '' end ||
      case when v_check is not null then ' with check (' || v_check || ')' else '' end ||
      ';'
    );
  end loop;
end $$;
