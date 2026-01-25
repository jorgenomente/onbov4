-- LOTE 8.5: Seed minimo de escenarios de practica para demo/local

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
select distinct
  l.org_id,
  lt.local_id,
  lt.program_id,
  1,
  'Saludo inicial al cliente',
  1,
  'Simula el saludo inicial a un cliente que acaba de llegar a su mesa. Presentate, ofrece ayuda y confirma la reserva si aplica.',
  array[
    'Saluda cordialmente',
    'Se presenta con nombre',
    'Ofrece ayuda o acompañamiento',
    'Confirma cantidad o reserva si corresponde'
  ]
from public.learner_trainings lt
join public.locals l on l.id = lt.local_id
where not exists (
  select 1
  from public.practice_scenarios ps
  where ps.program_id = lt.program_id
    and ps.unit_order = 1
    and (ps.local_id = lt.local_id or ps.local_id is null)
);
