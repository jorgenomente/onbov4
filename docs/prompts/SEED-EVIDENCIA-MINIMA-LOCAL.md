# SEED-EVIDENCIA-MINIMA-LOCAL

## Contexto

Seed mínimo e idempotente para testear las 3 views de evidencia en local.

## Prompt ejecutado

```txt
/*
Seed mínimo (idempotente) para poder TESTEAR las 3 views de evidencia en local.

Qué crea (si no existe ya):
- 1 conversación + 1 mensaje de aprendiz
- 1 practice_attempt + 1 practice_evaluation (con doubt_signals)
- 1 final_evaluation_attempt (completed) + 1 question + 1 answer + 1 evaluation (fail + doubt_signals)

Scope:
- Usa el PRIMER aprendiz existente en profiles (role='aprendiz')
- Usa el PRIMER training asociado del aprendiz (learner_trainings) para resolver local_id + program_id
- Usa el PRIMER practice_scenario del mismo program_id (si no hay, el primero global)
- NO crea usuarios auth; si no hay aprendiz o learner_trainings, falla con excepción.

Recomendación:
- Guardalo como migración seed (para reproducibilidad) o corrélo manual en SQL Editor.
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

  v_final_attempt_id uuid;
  v_question_id uuid;
  v_answer_id uuid;
  v_final_eval_id uuid;
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
  order by lt.created_at asc
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
    -- fallback: cualquier scenario (igual te sirve para probar v_learner_doubt_signals)
    select ps.id
      into v_scenario_id
    from public.practice_scenarios ps
    order by ps.created_at asc
    limit 1;
  end if;

  if v_scenario_id is null then
    raise exception 'Seed evidencia: no hay practice_scenarios. Ya viste count=2, pero no encontré ninguno; revisar seed.';
  end if;

  -- 3) Conversación + mensaje (requerido por practice_attempts.conversation_id FK)
  v_conversation_id := gen_random_uuid();
  insert into public.conversations (id, learner_id, local_id, program_id, unit_order, created_at)
  values (v_conversation_id, v_learner_id, v_local_id, v_program_id, 1, now())
  on conflict (id) do nothing;

  v_message_id := gen_random_uuid();
  insert into public.conversation_messages (id, conversation_id, sender, content, created_at)
  values (v_message_id, v_conversation_id, 'learner', 'Respuesta demo para práctica (seed evidencia).', now())
  on conflict (id) do nothing;

  -- 4) Practice attempt + evaluation (con dudas)
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
    'Te faltó confirmar restricciones del cliente y proponer opciones concretas.',
    array['uncertainty', 'omission'],
    now()
  )
  on conflict (id) do nothing;

  -- 5) Final evaluation: attempt + question + answer + evaluation (fail + dudas)
  -- Evitar chocar unique (learner_id, attempt_number): buscamos el próximo attempt_number disponible.
  select gen_random_uuid() into v_final_attempt_id;

  insert into public.final_evaluation_attempts (
    id, learner_id, program_id, attempt_number, status, global_score, bot_recommendation, started_at, ended_at, created_at
  )
  values (
    v_final_attempt_id,
    v_learner_id,
    v_program_id,
    coalesce((
      select max(a.attempt_number) + 1
      from public.final_evaluation_attempts a
      where a.learner_id = v_learner_id
    ), 1),
    'completed',
    52.00,
    'not_approved',
    now() - interval '30 minutes',
    now() - interval '25 minutes',
    now()
  )
  on conflict (learner_id, attempt_number) do nothing;

  v_question_id := gen_random_uuid();
  insert into public.final_evaluation_questions (id, attempt_id, unit_order, question_type, prompt, created_at)
  values (
    v_question_id,
    v_final_attempt_id,
    1,
    'direct',
    'Cliente pide un plato sin gluten y sin lácteos. ¿Qué preguntas hacés y qué ofrecés?',
    now()
  )
  on conflict (id) do nothing;

  v_answer_id := gen_random_uuid();
  insert into public.final_evaluation_answers (id, question_id, learner_answer, created_at)
  values (
    v_answer_id,
    v_question_id,
    'Le diría que sí se puede y le traigo una ensalada.',
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
    'Debés confirmar restricciones, consultar cocina y ofrecer alternativas seguras y específicas.',
    array['uncertainty', 'omission'],
    now()
  )
  on conflict (id) do nothing;

  raise notice 'Seed evidencia OK: learner_id=%, local_id=%, program_id=%', v_learner_id, v_local_id, v_program_id;
end $$;

-- Luego de correr esto, verificá:
-- select * from public.v_learner_evaluation_summary;
-- select * from public.v_learner_wrong_answers;
-- select * from public.v_learner_doubt_signals;
```

Resultado esperado
Seed mínimo para validar vistas de evidencia en local.

Notas (opcional)
N/A
