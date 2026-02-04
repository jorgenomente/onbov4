-- 20260131133000_seed_e2e_learner.sql
-- Seed: E2E learner (no learner_trainings) for deterministic tests.

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
  '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0001'::uuid,
  'authenticated',
  'authenticated',
  'e2e-aprendiz@demo.com',
  crypt('prueba123', gen_salt('bf')),
  '',
  '',
  '',
  '',
  '',
  '',
  now(),
  jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
  jsonb_build_object('full_name', 'Aprendiz E2E'),
  now(),
  now(),
  false
where not exists (
  select 1
  from auth.users u
  where u.email = 'e2e-aprendiz@demo.com'
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
  '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0001',
  '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0001'::uuid,
  jsonb_build_object('sub', '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0001', 'email', 'e2e-aprendiz@demo.com'),
  'email',
  now(),
  now(),
  now()
where not exists (
  select 1
  from auth.identities i
  where i.provider = 'email'
    and i.provider_id = '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0001'
);

-- 3) Profile (Local Centro)
insert into public.profiles (user_id, org_id, local_id, role, full_name)
select
  '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0001'::uuid,
  'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid,
  '1af5842d-68c0-4c56-8025-73d416730016'::uuid,
  'aprendiz'::public.app_role,
  'Aprendiz E2E'
where not exists (
  select 1
  from public.profiles p
  where p.user_id = '4f1f2a7c-2f0b-4c1e-9a8b-4f1f2a7c0001'::uuid
);
