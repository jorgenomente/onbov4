-- Smoke: Post-MVP3 D.2 guardrail create_final_evaluation_config
-- Caso A: sin intento activo -> RPC OK
-- Caso B: con intento activo -> RPC FAIL (conflict)

-- ------------------------------------------------------------
-- Setup: elegir program_id y learner_id validos (seed demo)
-- ------------------------------------------------------------
-- Ejemplo (ajustar si cambia):
-- select id as program_id from public.training_programs order by created_at desc limit 1;
-- select learner_id from public.learner_trainings order by started_at desc limit 1;

-- Reemplazar:
-- <PROGRAM_UUID>
-- <LEARNER_UUID>

-- ------------------------------------------------------------
-- Caso A: sin intento activo -> RPC OK
-- ------------------------------------------------------------
select public.create_final_evaluation_config(
  '<PROGRAM_UUID>'::uuid,
  10,
  0.4,
  75,
  array[1,2],
  2,
  3,
  12
) as new_config_id;

-- ------------------------------------------------------------
-- Caso B: con intento activo -> RPC FAIL (conflict)
-- ------------------------------------------------------------
insert into public.final_evaluation_attempts (
  id,
  learner_id,
  program_id,
  status,
  created_at
)
values (
  gen_random_uuid(),
  '<LEARNER_UUID>'::uuid,
  '<PROGRAM_UUID>'::uuid,
  'in_progress',
  now()
);

-- Debe FALLAR con conflict
select public.create_final_evaluation_config(
  '<PROGRAM_UUID>'::uuid,
  10,
  0.4,
  75,
  array[1],
  2,
  3,
  12
);
