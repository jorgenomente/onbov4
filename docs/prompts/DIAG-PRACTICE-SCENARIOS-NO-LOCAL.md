# DIAG-PRACTICE-SCENARIOS-NO-LOCAL

## Contexto

Diagnostico de escenarios de practica faltantes/filtrado por local_id para aprendiz demo.

## Prompt ejecutado

```txt
Qué está pasando (confirmado por schema.public.sql)

Tu tabla sí existe y requiere escenarios para poder iniciar práctica:

public.practice_scenarios tiene (mínimo):

org_id (NOT NULL)

local_id (nullable)

program_id (NOT NULL)

unit_order (NOT NULL)

title, instructions (NOT NULL)

success_criteria (text[]) …

El error viene de startPracticeScenario tirando:

“No hay escenarios de práctica configurados para este local…”

y eso en Next dev aparece como overlay porque estás throweando dentro de una Server Action.

1) Diagnóstico rápido (SQL) — ¿hay escenarios para ese learner/local?

Corré esto logueado como el aprendiz (o usando la email demo):

select
  lt.learner_id,
  lt.program_id,
  lt.current_unit_order,
  p.org_id,
  p.local_id
from public.learner_trainings lt
join public.profiles p on p.id = lt.learner_id
where lt.learner_id = auth.uid();


Con esos valores, chequeá escenarios:

select
  id, org_id, local_id, program_id, unit_order, title, difficulty, created_at
from public.practice_scenarios
where org_id = '<ORG_ID>'::uuid
  and program_id = '<PROGRAM_ID>'::uuid
  and unit_order = <UNIT_ORDER>
  and (local_id = '<LOCAL_ID>'::uuid or local_id is null)
order by local_id nulls last, created_at asc;
```

Resultado esperado
Determinar si hay escenarios y si el filtro por local_id o seeds es el problema.

Notas (opcional)
N/A
