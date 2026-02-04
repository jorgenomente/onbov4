-- 20260204092000_seed_e2e_course_training.sql
-- Seed: learner_training base para Curso Test E2E (e2e-aprendiz).

insert into public.learner_trainings (
  learner_id,
  local_id,
  program_id,
  status,
  current_unit_order,
  progress_percent
)
select
  '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0001'::uuid,
  '1af5842d-68c0-4c56-8025-73d416730016'::uuid,
  'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0001'::uuid,
  'en_entrenamiento',
  1,
  0
where not exists (
  select 1
  from public.learner_trainings lt
  where lt.learner_id = '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0001'::uuid
);
