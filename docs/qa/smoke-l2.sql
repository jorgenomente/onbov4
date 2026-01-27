-- Smoke L.2 (server-only wiring v2): RLS DB checks + app validation notes
-- Requiere ejecutar en SQL editor/psql con acceso a auth.users.

-- 0) Bootstrap: obtener IDs
select id as user_id, email
from auth.users
where email in ('aprendiz@demo.com','referente@demo.com','admin@demo.com','superadmin@onbo.dev')
order by email;

-- Reemplazar :learner_id con el UUID del aprendiz obtenido arriba.
select learner_id, local_id, program_id, status
from public.learner_trainings
where learner_id = :learner_id;

-- 1) Caso Referente OK (RLS permite INSERT)
set role authenticated;
select
  set_config('request.jwt.claim.role', 'authenticated', true),
  set_config('request.jwt.claim.sub', :referente_id, true);

insert into public.learner_review_validations_v2 (
  learner_id,
  reviewer_id,
  local_id,
  program_id,
  decision_type,
  perceived_severity,
  recommended_action,
  checklist,
  comment,
  reviewer_name,
  reviewer_role
) values (
  :learner_id,
  :referente_id,
  :local_id,
  :program_id,
  'request_reinforcement',
  'medium',
  'retraining',
  jsonb_build_object('needs_followup', true),
  'Smoke L.2: referente OK',
  'Referente Demo',
  'referente'
)
returning id, learner_id, reviewer_id, decision_type, created_at;

select id, learner_id, reviewer_id, decision_type, perceived_severity, recommended_action, created_at
from public.learner_review_validations_v2
order by created_at desc
limit 5;

-- 2) Caso Aprendiz FAIL (RLS bloquea INSERT)
select
  set_config('request.jwt.claim.role', 'authenticated', true),
  set_config('request.jwt.claim.sub', :aprendiz_id, true);

insert into public.learner_review_validations_v2 (
  learner_id,
  reviewer_id,
  local_id,
  program_id,
  decision_type,
  perceived_severity,
  recommended_action,
  checklist,
  comment,
  reviewer_name,
  reviewer_role
) values (
  :learner_id,
  :aprendiz_id,
  :local_id,
  :program_id,
  'approve',
  'low',
  'none',
  '{}'::jsonb,
  'Smoke L.2: aprendiz NO',
  'Aprendiz',
  'aprendiz'
);

-- Esperado: error RLS "new row violates row-level security policy".

-- 3) APP validation (fuera de SQL / RLS)
-- Caso: learner fuera de en_revision debe fallar en la Server Action.
-- Pasos manuales:
--  a) Loguearse como referente/admin en la app.
--  b) Ejecutar la Server Action con un learner cuyo status != 'en_revision'.
--  c) Esperado: error claro tipo "Learner is not in review".
