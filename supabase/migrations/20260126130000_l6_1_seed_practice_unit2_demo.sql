-- Seed: escenario de practica demo para unidad 2 (local demo)
-- Idempotente y seguro para db reset

insert into public.practice_scenarios (
  org_id,
  local_id,
  program_id,
  unit_order,
  title,
  instructions,
  success_criteria,
  difficulty
)
select
  'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid,
  '1af5842d-68c0-4c56-8025-73d416730016'::uuid,
  '6381856a-3e5c-43b4-afce-f83983418f29'::uuid,
  2,
  'Mesa complicada: queja por demora',
  'Atende una queja por demora. Pedí disculpas, explicá la situación y ofrecé una solución concreta sin prometer lo imposible.',
  ARRAY[
    'Pide disculpas de forma clara',
    'Explica la situación sin culpar al cliente',
    'Ofrece una solución concreta',
    'Mantiene tono empático'
  ]::text[],
  1
where not exists (
  select 1
  from public.practice_scenarios
  where org_id = 'b7bf2e75-c667-41bd-a6c0-b1b7d32dc69c'::uuid
    and program_id = '6381856a-3e5c-43b4-afce-f83983418f29'::uuid
    and unit_order = 2
    and local_id = '1af5842d-68c0-4c56-8025-73d416730016'::uuid
);
