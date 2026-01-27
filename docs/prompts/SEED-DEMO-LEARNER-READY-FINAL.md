# SEED-DEMO-LEARNER-READY-FINAL

## Contexto

Agregar seed idempotente para dejar al aprendiz demo listo para evaluación final después de db reset.

## Prompt ejecutado

```txt
Agregar un seed idempotente que deje al aprendiz demo listo para la evaluación final.

4️⃣ Seed definitivo: “learner listo para evaluación final”

Creá este archivo nuevo (o agregalo a tu seed demo existente):

supabase/migrations/20260126XXXX_l9_seed_demo_learner_ready_for_final.sql

Contenido completo (copy-paste):
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
```

Resultado esperado
Migration seed idempotente que deja al aprendiz demo listo para iniciar evaluación final.

Notas (opcional)
N/A
