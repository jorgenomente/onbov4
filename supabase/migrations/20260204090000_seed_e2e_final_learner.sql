-- 20260204090000_seed_e2e_final_learner.sql
-- Seed: E2E learner listo para evaluación final (sin intentos previos).

-- Identificadores demo
-- Org: Demo Org
-- Local: Local Centro
-- Programa: Onboarding Camareros

-- 1) Auth user
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
  '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0002'::uuid,
  'authenticated',
  'authenticated',
  'e2e-final@demo.com',
  crypt('prueba123', gen_salt('bf')),
  '',
  '',
  '',
  '',
  '',
  '',
  now(),
  jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
  jsonb_build_object('full_name', 'Aprendiz E2E Final'),
  now(),
  now(),
  false
where not exists (
  select 1
  from auth.users u
  where u.email = 'e2e-final@demo.com'
);

-- 2) Identity
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
  '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0002',
  '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0002'::uuid,
  jsonb_build_object('sub', '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0002', 'email', 'e2e-final@demo.com'),
  'email',
  now(),
  now(),
  now()
where not exists (
  select 1
  from auth.identities i
  where i.provider = 'email'
    and i.provider_id = '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0002'
);

-- 3) Profile (Local Centro)
insert into public.profiles (user_id, org_id, local_id, role, full_name)
select
  '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0002'::uuid,
  'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid,
  '1af5842d-68c0-4c56-8025-73d416730016'::uuid,
  'aprendiz'::public.app_role,
  'Aprendiz E2E Final'
where not exists (
  select 1
  from public.profiles p
  where p.user_id = '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0002'::uuid
);

-- 4) Learner training listo para evaluación final (programa demo)
with program as (
  select id
  from public.training_programs
  where id = '6381856a-3e5c-43b4-afce-f83983418f29'::uuid
),
max_unit as (
  select max(unit_order) as max_order
  from public.training_units
  where program_id = '6381856a-3e5c-43b4-afce-f83983418f29'::uuid
)
insert into public.learner_trainings (
  learner_id,
  local_id,
  program_id,
  status,
  current_unit_order,
  progress_percent
)
select
  '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0002'::uuid,
  '1af5842d-68c0-4c56-8025-73d416730016'::uuid,
  (select id from program),
  'en_entrenamiento',
  greatest(1, (select max_order from max_unit)),
  100
where not exists (
  select 1
  from public.learner_trainings lt
  where lt.learner_id = '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0002'::uuid
);
