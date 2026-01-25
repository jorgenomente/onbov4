-- LOTE 9: Seed demo/local completo (DB-first, idempotente)
-- PASSWORD DEMO: "prueba123"

-- 1) Demo org/local/program/base data
insert into public.organizations (id, name)
select
  'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid,
  'Demo Org'
where not exists (
  select 1
  from public.organizations o
  where o.id = 'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid
);

insert into public.locals (id, org_id, name)
select
  '1af5842d-68c0-4c56-8025-73d416730016'::uuid,
  'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid,
  'Local Centro'
where not exists (
  select 1
  from public.locals l
  where l.id = '1af5842d-68c0-4c56-8025-73d416730016'::uuid
);

insert into public.training_programs (id, org_id, local_id, name, is_active)
select
  '6381856a-3e5c-43b4-afce-f83983418f29'::uuid,
  'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid,
  '1af5842d-68c0-4c56-8025-73d416730016'::uuid,
  'Onboarding Camareros',
  true
where not exists (
  select 1
  from public.training_programs tp
  where tp.id = '6381856a-3e5c-43b4-afce-f83983418f29'::uuid
);

insert into public.local_active_programs (local_id, program_id)
select
  '1af5842d-68c0-4c56-8025-73d416730016'::uuid,
  '6381856a-3e5c-43b4-afce-f83983418f29'::uuid
where not exists (
  select 1
  from public.local_active_programs lap
  where lap.local_id = '1af5842d-68c0-4c56-8025-73d416730016'::uuid
);

-- 2) Units (2)
insert into public.training_units (id, program_id, unit_order, title, objectives)
select
  '8b0c5c4c-8c35-4c3a-bd6c-1b1f7a2e0001'::uuid,
  '6381856a-3e5c-43b4-afce-f83983418f29'::uuid,
  1,
  'Bienvenida y estándar de servicio',
  array['Saludo inicial', 'Presentación', 'Oferta de ayuda']
where not exists (
  select 1
  from public.training_units tu
  where tu.program_id = '6381856a-3e5c-43b4-afce-f83983418f29'::uuid
    and tu.unit_order = 1
);

insert into public.training_units (id, program_id, unit_order, title, objectives)
select
  '8b0c5c4c-8c35-4c3a-bd6c-1b1f7a2e0002'::uuid,
  '6381856a-3e5c-43b4-afce-f83983418f29'::uuid,
  2,
  'Venta sugestiva básica',
  array['Sugerir complementos', 'Incrementar ticket promedio']
where not exists (
  select 1
  from public.training_units tu
  where tu.program_id = '6381856a-3e5c-43b4-afce-f83983418f29'::uuid
    and tu.unit_order = 2
);

-- 3) Knowledge items + mapping
insert into public.knowledge_items (id, org_id, local_id, title, content)
select
  '9c1d5e5d-1a1a-4b4b-bbbb-000000000001'::uuid,
  'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid,
  null,
  'Guión de saludo',
  'Saludá con una sonrisa, presentate con tu nombre y ofrecé ayuda. Ejemplo: “Hola, soy Ana, voy a estar atendiéndolos. ¿Puedo ofrecerles algo para comenzar?”'
where not exists (
  select 1
  from public.knowledge_items ki
  where ki.id = '9c1d5e5d-1a1a-4b4b-bbbb-000000000001'::uuid
);

insert into public.knowledge_items (id, org_id, local_id, title, content)
select
  '9c1d5e5d-1a1a-4b4b-bbbb-000000000002'::uuid,
  'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid,
  null,
  'Venta sugestiva (upselling)',
  'Sugerí un complemento simple y relevante: “Si te gusta la pasta, podés sumar una copa de vino blanco de la casa.”'
where not exists (
  select 1
  from public.knowledge_items ki
  where ki.id = '9c1d5e5d-1a1a-4b4b-bbbb-000000000002'::uuid
);

insert into public.unit_knowledge_map (unit_id, knowledge_id)
select
  '8b0c5c4c-8c35-4c3a-bd6c-1b1f7a2e0001'::uuid,
  '9c1d5e5d-1a1a-4b4b-bbbb-000000000001'::uuid
where not exists (
  select 1
  from public.unit_knowledge_map ukm
  where ukm.unit_id = '8b0c5c4c-8c35-4c3a-bd6c-1b1f7a2e0001'::uuid
    and ukm.knowledge_id = '9c1d5e5d-1a1a-4b4b-bbbb-000000000001'::uuid
);

insert into public.unit_knowledge_map (unit_id, knowledge_id)
select
  '8b0c5c4c-8c35-4c3a-bd6c-1b1f7a2e0002'::uuid,
  '9c1d5e5d-1a1a-4b4b-bbbb-000000000002'::uuid
where not exists (
  select 1
  from public.unit_knowledge_map ukm
  where ukm.unit_id = '8b0c5c4c-8c35-4c3a-bd6c-1b1f7a2e0002'::uuid
    and ukm.knowledge_id = '9c1d5e5d-1a1a-4b4b-bbbb-000000000002'::uuid
);

-- 4) Practice scenario (aligned with selector)
insert into public.practice_scenarios (
  org_id,
  local_id,
  program_id,
  unit_order,
  title,
  difficulty,
  instructions,
  success_criteria
)
select
  'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid,
  '1af5842d-68c0-4c56-8025-73d416730016'::uuid,
  '6381856a-3e5c-43b4-afce-f83983418f29'::uuid,
  1,
  'Mesa complicada — pedido incompleto',
  1,
  'Un cliente apurado recibió un pedido incompleto. Respondé como camarero: pedí disculpas, ofrecé una solución inmediata y confirmá el pedido correcto.',
  array[
    'Pide disculpas con tono cordial',
    'Ofrece una solución inmediata',
    'Confirma el pedido correcto'
  ]
where not exists (
  select 1
  from public.practice_scenarios ps
  where ps.local_id = '1af5842d-68c0-4c56-8025-73d416730016'::uuid
    and ps.program_id = '6381856a-3e5c-43b4-afce-f83983418f29'::uuid
    and ps.unit_order = 1
    and ps.difficulty = 1
);

-- 5) Final evaluation config
insert into public.final_evaluation_configs (
  program_id,
  total_questions,
  roleplay_ratio,
  min_global_score,
  must_pass_units,
  questions_per_unit,
  max_attempts,
  cooldown_hours
)
select
  '6381856a-3e5c-43b4-afce-f83983418f29'::uuid,
  4,
  0.5,
  70,
  array[1]::int[],
  2,
  3,
  12
where not exists (
  select 1
  from public.final_evaluation_configs f
  where f.program_id = '6381856a-3e5c-43b4-afce-f83983418f29'::uuid
);

-- 6) Auth instance (for local auth)
insert into auth.instances (id, uuid, raw_base_config, created_at, updated_at)
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  '00000000-0000-0000-0000-000000000000'::uuid,
  null,
  now(),
  now()
where not exists (
  select 1
  from auth.instances i
  where i.id = '00000000-0000-0000-0000-000000000000'::uuid
);

-- 7) Auth users (email/password)
with demo_users as (
  select
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid as id,
    'admin@demo.com'::text as email,
    'Admin Demo'::text as full_name,
    'admin_org'::text as role,
    false as is_super_admin
  union all
  select
    'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid,
    'referente@demo.com',
    'Referente Demo',
    'referente',
    false
  union all
  select
    '2914f1b6-2694-4488-a10f-7fd85064e697'::uuid,
    'aprendiz@demo.com',
    'Aprendiz Demo',
    'aprendiz',
    false
  union all
  select
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    'superadmin@onbo.dev',
    'Superadmin ONBO',
    'superadmin',
    true
)
insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  confirmation_token,
  recovery_token,
  email_change_token_new,
  email_change,
  email_change_token_current,
  reauthentication_token,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  is_super_admin
)
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  du.id,
  'authenticated',
  'authenticated',
  du.email,
  crypt('prueba123', gen_salt('bf')),
  '',
  '',
  '',
  '',
  '',
  '',
  now(),
  jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
  jsonb_build_object('full_name', du.full_name),
  now(),
  now(),
  du.is_super_admin
from demo_users du
where not exists (
  select 1
  from auth.users u
  where u.email = du.email
);

insert into auth.identities (
  provider_id,
  user_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
)
select
  du.id::text,
  du.id,
  jsonb_build_object('sub', du.id::text, 'email', du.email),
  'email',
  now(),
  now(),
  now()
from (
  select 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid as id, 'admin@demo.com'::text as email
  union all
  select 'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid, 'referente@demo.com'
  union all
  select '2914f1b6-2694-4488-a10f-7fd85064e697'::uuid, 'aprendiz@demo.com'
  union all
  select 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'superadmin@onbo.dev'
) du
where not exists (
  select 1
  from auth.identities i
  where i.provider = 'email'
    and i.provider_id = du.id::text
);

-- 8) Profiles
insert into public.profiles (user_id, org_id, local_id, role, full_name)
select
  du.id,
  'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid,
  '1af5842d-68c0-4c56-8025-73d416730016'::uuid,
  du.role::public.app_role,
  du.full_name
from (
  select 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid as id, 'Admin Demo'::text as full_name, 'admin_org'::text as role
  union all
  select 'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid, 'Referente Demo', 'referente'
  union all
  select '2914f1b6-2694-4488-a10f-7fd85064e697'::uuid, 'Aprendiz Demo', 'aprendiz'
  union all
  select 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'Superadmin ONBO', 'superadmin'
) du
where not exists (
  select 1
  from public.profiles p
  where p.user_id = du.id
);

-- 9) Learner training assignment
insert into public.learner_trainings (
  learner_id,
  local_id,
  program_id,
  status,
  current_unit_order,
  progress_percent
)
select
  '2914f1b6-2694-4488-a10f-7fd85064e697'::uuid,
  '1af5842d-68c0-4c56-8025-73d416730016'::uuid,
  '6381856a-3e5c-43b4-afce-f83983418f29'::uuid,
  'en_entrenamiento'::public.learner_status,
  1,
  0
where not exists (
  select 1
  from public.learner_trainings lt
  where lt.learner_id = '2914f1b6-2694-4488-a10f-7fd85064e697'::uuid
);
