-- Seed: dejar aprendiz demo listo para evaluación final
-- Idempotente y seguro para db reset

with learner as (
  select id
  from auth.users
  where email = 'aprendiz@demo.com'
),
training as (
  select lt.id, lt.program_id
  from public.learner_trainings lt
  join learner l on lt.learner_id = l.id
),
max_unit as (
  select
    tu.program_id,
    max(tu.unit_order) as max_unit_order
  from public.training_units tu
  join training t on tu.program_id = t.program_id
  group by tu.program_id
)
update public.learner_trainings lt
set
  progress_percent = 100,
  current_unit_order = mu.max_unit_order,
  status = 'en_entrenamiento',
  updated_at = now()
from training t
join max_unit mu on mu.program_id = t.program_id
where lt.id = t.id;
