/*
Seed mínimo (idempotente) para testear views de evidencia en local.

- Crea (si no existe):
  - 1 conversación + 1 mensaje de aprendiz
  - 1 practice_attempt + 1 practice_evaluation (con doubt_signals)
  - 1 final_evaluation_attempt + 1 question + 1 answer + 1 evaluation (fail + doubt_signals)

Notas:
- Usa el primer aprendiz en profiles y su primer learner_training.
- Falla si no hay aprendiz o learner_trainings.
- Idempotente vía marcadores de seed en feedback/prompt.
*/

do $$
declare
  v_learner_id uuid;
  v_local_id uuid;
  v_program_id uuid;
  v_scenario_id uuid;

  v_conversation_id uuid;
  v_message_id uuid;

  v_practice_attempt_id uuid;
  v_practice_eval_id uuid;
  v_existing_practice_eval uuid;

  v_final_attempt_id uuid;
  v_question_id uuid;
  v_answer_id uuid;
  v_final_eval_id uuid;
  v_existing_question uuid;

  v_seed_attempt_number integer := 999;

  v_practice_feedback text := 'Seed evidencia: feedback práctica.';
  v_final_prompt text := 'Seed evidencia: Cliente pide un plato sin gluten y sin lácteos. ¿Qué preguntas hacés y qué ofrecés?';
begin
  -- 1) Resolver aprendiz + training (local/program)
  select p.user_id
    into v_learner_id
  from public.profiles p
  where p.role = 'aprendiz'
  order by p.created_at asc
  limit 1;

  if v_learner_id is null then
    raise exception 'Seed evidencia: no existe ningún profile con role=aprendiz. Creá/seed un aprendiz primero.';
  end if;

  select lt.local_id, lt.program_id
    into v_local_id, v_program_id
  from public.learner_trainings lt
  where lt.learner_id = v_learner_id
  order by lt.started_at asc
  limit 1;

  if v_local_id is null or v_program_id is null then
    raise exception 'Seed evidencia: el aprendiz % no tiene learner_trainings. Seed de trainings requerido.', v_learner_id;
  end if;

  -- 2) Resolver scenario de práctica (mismo program)
  select ps.id
    into v_scenario_id
  from public.practice_scenarios ps
  where ps.program_id = v_program_id
  order by ps.unit_order asc, ps.created_at asc
  limit 1;

  if v_scenario_id is null then
    select ps.id
      into v_scenario_id
    from public.practice_scenarios ps
    order by ps.created_at asc
    limit 1;
  end if;

  if v_scenario_id is null then
    raise exception 'Seed evidencia: no hay practice_scenarios. Revisar seed.';
  end if;

  -- 3) Practice attempt + evaluation (si no existe seed previa)
  select pe.id
    into v_existing_practice_eval
  from public.practice_evaluations pe
  where pe.feedback = v_practice_feedback
  limit 1;

  if v_existing_practice_eval is null then
    v_conversation_id := gen_random_uuid();
    insert into public.conversations (id, learner_id, local_id, program_id, unit_order, context, created_at)
    values (v_conversation_id, v_learner_id, v_local_id, v_program_id, 1, 'Seed evidencia: contexto conversación.', now())
    on conflict (id) do nothing;

    v_message_id := gen_random_uuid();
    insert into public.conversation_messages (id, conversation_id, sender, content, created_at)
    values (v_message_id, v_conversation_id, 'learner', 'Seed evidencia: respuesta demo para práctica.', now())
    on conflict (id) do nothing;

    v_practice_attempt_id := gen_random_uuid();
    insert into public.practice_attempts (id, scenario_id, learner_id, local_id, conversation_id, started_at, ended_at, status)
    values (v_practice_attempt_id, v_scenario_id, v_learner_id, v_local_id, v_conversation_id, now() - interval '10 minutes', now(), 'completed')
    on conflict (id) do nothing;

    v_practice_eval_id := gen_random_uuid();
    insert into public.practice_evaluations (
      id, attempt_id, learner_message_id, score, verdict, strengths, gaps, feedback, doubt_signals, created_at
    )
    values (
      v_practice_eval_id,
      v_practice_attempt_id,
      v_message_id,
      45.00,
      'fail',
      array['Buena intención de servicio'],
      array['No confirma alergias', 'No ofrece alternativas claras'],
      v_practice_feedback,
      array['uncertainty', 'omission'],
      now()
    )
    on conflict (id) do nothing;
  end if;

  -- 4) Final evaluation seed (si no existe pregunta seed previa)
  select q.id
    into v_existing_question
  from public.final_evaluation_questions q
  where q.prompt = v_final_prompt
  limit 1;

  if v_existing_question is null then
    v_final_attempt_id := gen_random_uuid();
    insert into public.final_evaluation_attempts (
      id, learner_id, program_id, attempt_number, status, global_score, bot_recommendation, started_at, ended_at, created_at
    )
    values (
      v_final_attempt_id,
      v_learner_id,
      v_program_id,
      v_seed_attempt_number,
      'completed',
      52.00,
      'not_approved',
      now() - interval '30 minutes',
      now() - interval '25 minutes',
      now()
    )
    on conflict (learner_id, attempt_number) do nothing;

    select a.id
      into v_final_attempt_id
    from public.final_evaluation_attempts a
    where a.learner_id = v_learner_id
      and a.attempt_number = v_seed_attempt_number
    limit 1;

    if v_final_attempt_id is null then
      raise exception 'Seed evidencia: no pude resolver final_evaluation_attempts para learner_id=%', v_learner_id;
    end if;

    v_question_id := gen_random_uuid();
    insert into public.final_evaluation_questions (id, attempt_id, unit_order, question_type, prompt, created_at)
    values (
      v_question_id,
      v_final_attempt_id,
      1,
      'direct',
      v_final_prompt,
      now()
    )
    on conflict (id) do nothing;

    v_answer_id := gen_random_uuid();
    insert into public.final_evaluation_answers (id, question_id, learner_answer, created_at)
    values (
      v_answer_id,
      v_question_id,
      'Seed evidencia: Le diría que sí se puede y le traigo una ensalada.',
      now()
    )
    on conflict (id) do nothing;

    v_final_eval_id := gen_random_uuid();
    insert into public.final_evaluation_evaluations (
      id, answer_id, unit_order, score, verdict, strengths, gaps, feedback, doubt_signals, created_at
    )
    values (
      v_final_eval_id,
      v_answer_id,
      1,
      35.00,
      'fail',
      array['Mantiene intención de ayudar'],
      array['No valida alergias', 'No consulta cocina', 'Propone opción genérica'],
      'Seed evidencia: Debés confirmar restricciones, consultar cocina y ofrecer alternativas seguras y específicas.',
      array['uncertainty', 'omission'],
      now()
    )
    on conflict (id) do nothing;
  end if;

  raise notice 'Seed evidencia OK: learner_id=%, local_id=%, program_id=%', v_learner_id, v_local_id, v_program_id;
end $$;
