-- LOTE 8.6: Seed demo de escenario de practica para local Centro

-- 1) Ensure demo org/local/program exist (idempotent)
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
  'Programa Demo',
  true
where not exists (
  select 1
  from public.training_programs tp
  where tp.id = '6381856a-3e5c-43b4-afce-f83983418f29'::uuid
);

-- 2) Seed practice scenario (idempotent)
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
