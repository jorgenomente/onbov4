# SUBLOTE-L1-1-VALIDACION-HUMANA-V2-SELECT-RLS

## Contexto

Micro-migracion para ajustar policies SELECT de learner_review_validations_v2 y evitar confiar en snapshots local_id.

## Prompt ejecutado

```txt
⚠️ Hallazgo importante (para ajustar en L.1.1)

Tus policies SELECT de admin_org y referente hoy filtran por local_id de la fila (snapshot), no por learner_id → learner_trainings. Eso sí confía en snapshot para visibilidad (aunque no para INSERT).

dictionary

Impacto:

No rompe seguridad cross-tenant (INSERT ya está bien).

Pero puede ocultar datos legítimos si alguien inserta con local_id incorrecto (o si en L.2 hay un bug).

Además es inconsistente con el principio “no confiar en snapshots”.

👉 Recomendación: Sub-lote L.1.1 (micro-migración) solo para reemplazar SELECT policies de admin_org/referente por joins via learner_trainings (como en v1). No toca UI.

Smoke SQL de RLS (pendiente) — Copy/Paste

Objetivo: probar INSERT y SELECT como referente y aprendiz en Supabase local.
Credenciales demo (para ubicar emails):

smoke-credentials

0) Obtener UUIDs y contexto (como postgres / service)
-- IDs de usuarios (auth)
select id as user_id, email
from auth.users
where email in ('aprendiz@demo.com','referente@demo.com','admin@demo.com','superadmin@onbo.dev');

-- Contexto del aprendiz: local/program para armar el INSERT (snapshots)
-- Reemplazá :learner_id por el UUID del aprendiz que te devolvió la query anterior.
select learner_id, local_id, program_id
from public.learner_trainings
where learner_id = :learner_id;

1) Helper para “simular sesión” (RLS) por usuario

En Supabase/PostgREST, RLS usa auth.uid() → depende de request.jwt.claim.sub.
Esto sirve para smoke tests en SQL editor/psql.

-- Setea el usuario “logueado” para esta sesión SQL
select
  set_config('request.jwt.claim.role', 'authenticated', true),
  set_config('request.jwt.claim.sub', :user_id, true);

2) Caso A — Aprendiz NO puede INSERT
-- Actuar como aprendiz
select
  set_config('request.jwt.claim.role', 'authenticated', true),
  set_config('request.jwt.claim.sub', :aprendiz_id, true);

-- Intento de INSERT (debe FALLAR por RLS)
insert into public.learner_review_validations_v2 (
  learner_id, reviewer_id, local_id, program_id,
  decision_type, perceived_severity, recommended_action,
  checklist, comment, reviewer_name, reviewer_role
) values (
  :aprendiz_id, :aprendiz_id, :local_id, :program_id,
  'approve', 'low', 'none',
  '{}'::jsonb, 'Intento indebido', 'Aprendiz', 'aprendiz'
);


✅ Esperado: error por RLS / permission denied.

3) Caso B — Referente puede INSERT para learner de SU local
-- Actuar como referente
select
  set_config('request.jwt.claim.role', 'authenticated', true),
  set_config('request.jwt.claim.sub', :referente_id, true);

insert into public.learner_review_validations_v2 (
  learner_id, reviewer_id, local_id, program_id,
  decision_type, perceived_severity, recommended_action,
  checklist, comment, reviewer_name, reviewer_role
) values (
  :aprendiz_id, :referente_id, :local_id, :program_id,
  'request_reinforcement', 'medium', 'retraining',
  jsonb_build_object('needs_followup', true),
  'Faltan conceptos clave en objeciones.',
  'Referente Demo', 'referente'
)
returning id, learner_id, reviewer_id, decision_type, created_at;


✅ Esperado: INSERT OK.

4) Caso C — Aprendiz ve SOLO sus filas
-- Actuar como aprendiz
select
  set_config('request.jwt.claim.role', 'authenticated', true),
  set_config('request.jwt.claim.sub', :aprendiz_id, true);

select id, learner_id, decision_type, created_at, reviewer_name, reviewer_role
from public.learner_review_validations_v2
order by created_at desc;


✅ Esperado: devuelve solo filas con learner_id = aprendiz_id.

5) Caso D — Referente ve filas de su local (y acá detectamos el issue de snapshot)
-- Actuar como referente
select
  set_config('request.jwt.claim.role', 'authenticated', true),
  set_config('request.jwt.claim.sub', :referente_id, true);

select id, learner_id, local_id, decision_type, created_at
from public.learner_review_validations_v2
order by created_at desc;


✅ Esperado: ve las de su local.

📌 Nota: si insertaras accidentalmente con local_id incorrecto, no la vería (por policy actual). Ese es el motivo del ajuste recomendado en L.1.1.

dictionary

Siguiente paso recomendado

Opción 1 (mi recomendación): hacer L.1.1 micro-migración para corregir SELECT policies y que también “no confíen en snapshots”. Luego pasamos a L.2 wiring
```

Resultado esperado

Micro-migracion de policies SELECT y smoke SQL de RLS.

Notas (opcional)

Sin cambios de UI ni server actions.
