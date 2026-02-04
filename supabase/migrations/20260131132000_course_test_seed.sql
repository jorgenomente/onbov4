-- 20260131132000_course_test_seed.sql
-- Seed: Curso Test (E2E) + knowledge + practice scenario + active program for Local Centro.

-- Demo org/local identifiers (from seed).
-- Org: Demo Org
-- Local: Local Centro

-- 1) Training program (Curso Test E2E)
insert into public.training_programs (id, org_id, local_id, name, is_active)
select
  'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0001'::uuid,
  'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid,
  '1af5842d-68c0-4c56-8025-73d416730016'::uuid,
  'Curso Test (E2E)',
  true
where not exists (
  select 1
  from public.training_programs tp
  where tp.id = 'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0001'::uuid
);

-- 2) Unit 1
insert into public.training_units (id, program_id, unit_order, title, objectives)
select
  'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0002'::uuid,
  'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0001'::uuid,
  1,
  'Unidad 1: Bienvenida y primer contacto',
  array[
    'Saludar de forma clara y amable',
    'Presentarse y ofrecer ayuda',
    'Guiar el siguiente paso'
  ]
where not exists (
  select 1
  from public.training_units tu
  where tu.program_id = 'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0001'::uuid
    and tu.unit_order = 1
);

-- 3) Knowledge items (Intro + Estandar + Ejemplo)
insert into public.knowledge_items (id, org_id, local_id, title, content)
select
  'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0003'::uuid,
  'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid,
  null,
  'INTRO: Bienvenida',
  'En esta unidad vas a aprender como iniciar el contacto con una mesa. El objetivo es generar confianza y guiar el primer paso del cliente.'
where not exists (
  select 1
  from public.knowledge_items ki
  where ki.id = 'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0003'::uuid
);

insert into public.knowledge_items (id, org_id, local_id, title, content)
select
  'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0004'::uuid,
  'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid,
  null,
  'ESTANDAR: Regla de saludo',
  'Saluda con una sonrisa, presentate con tu nombre y ofrece ayuda inmediata. Mantene el tono claro y cordial.'
where not exists (
  select 1
  from public.knowledge_items ki
  where ki.id = 'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0004'::uuid
);

insert into public.knowledge_items (id, org_id, local_id, title, content)
select
  'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0005'::uuid,
  'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid,
  null,
  'EJEMPLO: Primer contacto',
  'Ejemplo: "Hola, soy Sofia y voy a estar atendiendolos. Quieren agua o alguna bebida para comenzar?"'
where not exists (
  select 1
  from public.knowledge_items ki
  where ki.id = 'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0005'::uuid
);

-- 4) Knowledge mapping
insert into public.unit_knowledge_map (unit_id, knowledge_id)
select
  'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0002'::uuid,
  'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0003'::uuid
where not exists (
  select 1
  from public.unit_knowledge_map ukm
  where ukm.unit_id = 'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0002'::uuid
    and ukm.knowledge_id = 'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0003'::uuid
);

insert into public.unit_knowledge_map (unit_id, knowledge_id)
select
  'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0002'::uuid,
  'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0004'::uuid
where not exists (
  select 1
  from public.unit_knowledge_map ukm
  where ukm.unit_id = 'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0002'::uuid
    and ukm.knowledge_id = 'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0004'::uuid
);

insert into public.unit_knowledge_map (unit_id, knowledge_id)
select
  'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0002'::uuid,
  'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0005'::uuid
where not exists (
  select 1
  from public.unit_knowledge_map ukm
  where ukm.unit_id = 'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0002'::uuid
    and ukm.knowledge_id = 'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0005'::uuid
);

-- 5) Practice scenario
insert into public.practice_scenarios (
  id,
  org_id,
  local_id,
  program_id,
  unit_order,
  title,
  difficulty,
  instructions,
  success_criteria,
  is_enabled
)
select
  'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0006'::uuid,
  'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid,
  '1af5842d-68c0-4c56-8025-73d416730016'::uuid,
  'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0001'::uuid,
  1,
  'Role-play: Primer contacto',
  1,
  'Simula el primer contacto con una mesa de 2 personas que acaba de sentarse. Presentate y ofrece ayuda sin presionar.',
  array[
    'Saludo cordial al iniciar la interaccion',
    'Se presenta con nombre',
    'Ofrece ayuda o primer paso concreto',
    'Mantiene tono amable y claro',
    'No inventa detalles del menu'
  ],
  true
where not exists (
  select 1
  from public.practice_scenarios ps
  where ps.id = 'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0006'::uuid
);

-- 6) Set active program for Local Centro
insert into public.local_active_programs (local_id, program_id, created_at)
values (
  '1af5842d-68c0-4c56-8025-73d416730016'::uuid,
  'd5f1a3b8-8f23-4b3f-9b7b-8d2e7a1a0001'::uuid,
  now()
)
on conflict (local_id)
  do update set program_id = excluded.program_id;
