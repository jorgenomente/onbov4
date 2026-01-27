begin;

-- =========================================================
-- F.1 Seed cross-tenant (2do local misma org) — idempotente
-- =========================================================

do $$
declare
  v_org_id uuid := 'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid; -- Demo Org
  v_local_a uuid := '1af5842d-68c0-4c56-8025-73d416730016'::uuid; -- Local Centro (A)

  -- Nuevo Local B (determinístico)
  v_local_b uuid := '2af5842d-68c0-4c56-8025-73d416730017'::uuid;

  -- Usuarios demo B (determinísticos)
  v_ref_b uuid := 'dddddddd-dddd-dddd-dddd-dddddddddddd'::uuid;
  v_learner_b uuid := 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'::uuid;

  v_ref_b_email text := 'referente+localb@demo.onbo';
  v_learner_b_email text := 'aprendiz+localb@demo.onbo';

  v_program_id uuid;

  -- Conversación/práctica
  v_conversation_id uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaab'::uuid;
  v_message_id uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbba'::uuid;
  v_practice_attempt_id uuid := 'cccccccc-0000-0000-0000-cccccccccccc'::uuid;
  v_practice_eval_id uuid := 'cccccccc-1111-1111-1111-cccccccccccc'::uuid;
  v_scenario_id uuid;

  -- Final evaluation
  v_final_attempt_id uuid := 'ffffffff-0000-0000-0000-ffffffffffff'::uuid;
  v_question_id uuid := 'ffffffff-1111-1111-1111-ffffffffffff'::uuid;
  v_answer_id uuid := 'ffffffff-2222-2222-2222-ffffffffffff'::uuid;
  v_final_eval_id uuid := 'ffffffff-3333-3333-3333-ffffffffffff'::uuid;
begin
  -- 1) Crear Local B (misma org demo)
  insert into public.locals (id, org_id, name, created_at)
  values (v_local_b, v_org_id, 'Local Norte (Seed Leakage)', now())
  on conflict (id) do nothing;

  -- 2) Resolver program_id activo para Local A (lo reutilizamos)
  select lap.program_id into v_program_id
  from public.local_active_programs lap
  where lap.local_id = v_local_a
  limit 1;

  if v_program_id is null then
    raise exception 'Seed F.1: no existe local_active_programs para local A (%).', v_local_a;
  end if;

  -- 3) Activar mismo program para Local B (PK(local_id))
  insert into public.local_active_programs (local_id, program_id, created_at)
  values (v_local_b, v_program_id, now())
  on conflict (local_id) do nothing;

  -- 4) Seed auth.users + auth.identities + profiles para Referente B y Aprendiz B
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    email_change_token_current, reauthentication_token, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at, is_super_admin
  )
  select
    '00000000-0000-0000-0000-000000000000'::uuid,
    du.id,
    'authenticated',
    'authenticated',
    du.email,
    crypt('prueba123', gen_salt('bf')),
    '', '', '', '', '', '',
    now(),
    jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
    jsonb_build_object('full_name', du.full_name),
    now(),
    now(),
    du.is_super_admin
  from (
    values
      (v_ref_b, v_ref_b_email, 'Referente Local B', false),
      (v_learner_b, v_learner_b_email, 'Aprendiz Local B', false)
  ) as du(id, email, full_name, is_super_admin)
  where not exists (select 1 from auth.users u where u.email = du.email);

  insert into auth.identities (
    provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  )
  select
    du.id::text,
    du.id,
    jsonb_build_object('sub', du.id::text, 'email', du.email),
    'email',
    now(), now(), now()
  from (
    values
      (v_ref_b, v_ref_b_email),
      (v_learner_b, v_learner_b_email)
  ) as du(id, email)
  where not exists (
    select 1 from auth.identities i
    where i.provider = 'email' and i.provider_id = du.id::text
  );

  insert into public.profiles (user_id, org_id, local_id, role, full_name)
  select
    du.id,
    v_org_id,
    v_local_b,
    du.role::public.app_role,
    du.full_name
  from (
    values
      (v_ref_b, 'referente', 'Referente Local B'),
      (v_learner_b, 'aprendiz', 'Aprendiz Local B')
  ) as du(id, role, full_name)
  where not exists (select 1 from public.profiles p where p.user_id = du.id);

  -- 5) learner_trainings para Aprendiz B (UNIQUE(learner_id))
  insert into public.learner_trainings (
    learner_id, local_id, program_id, status, current_unit_order, progress_percent, started_at, updated_at
  )
  values (
    v_learner_b, v_local_b, v_program_id, 'en_entrenamiento', 1, 0, now(), now()
  )
  on conflict (learner_id) do nothing;

  -- 6) Resolver un scenario del program
  select ps.id into v_scenario_id
  from public.practice_scenarios ps
  where ps.program_id = v_program_id
  order by ps.unit_order asc, ps.created_at asc
  limit 1;

  if v_scenario_id is null then
    raise exception 'Seed F.1: no hay practice_scenarios para program_id=%', v_program_id;
  end if;

  -- 7) Conversación + mensaje (Local B)
  insert into public.conversations (id, learner_id, local_id, program_id, unit_order, context, created_at)
  values (v_conversation_id, v_learner_b, v_local_b, v_program_id, 1, 'Seed leakage Local B: contexto.', now())
  on conflict (id) do nothing;

  insert into public.conversation_messages (id, conversation_id, sender, content, created_at)
  values (v_message_id, v_conversation_id, 'learner', 'Seed leakage Local B: práctica.', now())
  on conflict (id) do nothing;

  -- 8) Practice attempt + evaluation (Local B)
  insert into public.practice_attempts (
    id, scenario_id, learner_id, local_id, conversation_id, status, started_at, ended_at
  )
  values (
    v_practice_attempt_id, v_scenario_id, v_learner_b, v_local_b, v_conversation_id,
    'completed', now() - interval '8 minutes', now() - interval '6 minutes'
  )
  on conflict (id) do nothing;

  insert into public.practice_evaluations (
    id, attempt_id, learner_message_id, score, verdict, strengths, gaps, feedback, doubt_signals, created_at
  )
  values (
    v_practice_eval_id,
    v_practice_attempt_id,
    v_message_id,
    40.00,
    'fail',
    array['Amable y rápido'],
    array['No confirma pedido', 'No repite comanda'],
    'Seed leakage Local B: confirmá el pedido y repetí la comanda.',
    array['uncertainty', 'omission'],
    now() - interval '6 minutes'
  )
  on conflict (id) do nothing;

  -- 9) Final evaluation attempt + Q/A + evaluation (Local B)
  insert into public.final_evaluation_attempts (
    id, learner_id, program_id, attempt_number, status, global_score, bot_recommendation, started_at, ended_at, created_at
  )
  values (
    v_final_attempt_id,
    v_learner_b,
    v_program_id,
    999,
    'completed',
    50.00,
    'not_approved',
    now() - interval '20 minutes',
    now() - interval '18 minutes',
    now() - interval '18 minutes'
  )
  on conflict (learner_id, attempt_number) do nothing;

  insert into public.final_evaluation_questions (id, attempt_id, unit_order, question_type, prompt, created_at)
  values (
    v_question_id,
    v_final_attempt_id,
    1,
    'direct',
    'Seed leakage Local B: cliente con restricción. ¿Qué validás y qué ofrecés?',
    now() - interval '18 minutes'
  )
  on conflict (id) do nothing;

  insert into public.final_evaluation_answers (id, question_id, learner_answer, created_at)
  values (
    v_answer_id,
    v_question_id,
    'Sí, seguro. Te traigo algo.',
    now() - interval '17 minutes'
  )
  on conflict (id) do nothing;

  insert into public.final_evaluation_evaluations (
    id, answer_id, unit_order, score, verdict, strengths, gaps, feedback, doubt_signals, created_at
  )
  values (
    v_final_eval_id,
    v_answer_id,
    1,
    30.00,
    'fail',
    array['Intención de ayudar'],
    array['No valida restricciones', 'No consulta cocina'],
    'Seed leakage Local B: validá restricciones, consultá cocina y proponé alternativas específicas.',
    array['uncertainty', 'omission'],
    now() - interval '16 minutes'
  )
  on conflict (id) do nothing;

  raise notice 'Seed F.1 OK: local_b=%, learner_b=% (program_id=%)', v_local_b, v_learner_b, v_program_id;
end $$;

commit;
