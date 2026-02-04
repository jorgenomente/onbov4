-- 20260204094000_fix_advance_training_progress_last_unit.sql
-- Fix: progreso 100% al completar la ultima unidad sin exceder current_unit_order.

create or replace function public.advance_learner_training_from_practice(p_attempt_id uuid)
returns table (new_unit_order int, new_progress_percent numeric)
language plpgsql
as $$
declare
  v_role text;
  v_learner_id uuid;
  v_attempt_learner_id uuid;
  v_program_id uuid;
  v_unit_order int;
  v_current_unit_order int;
  v_max_unit_order int;
  v_completed_units int;
  v_progress numeric;
begin
  v_role := public.current_role();
  if v_role <> 'aprendiz' then
    raise exception 'forbidden: role % cannot advance training', v_role
      using errcode = '42501';
  end if;

  v_learner_id := auth.uid();
  if v_learner_id is null then
    raise exception 'unauthenticated'
      using errcode = '42501';
  end if;

  select pa.learner_id, ps.program_id, ps.unit_order
    into v_attempt_learner_id, v_program_id, v_unit_order
  from public.practice_attempts pa
  join public.practice_scenarios ps on ps.id = pa.scenario_id
  where pa.id = p_attempt_id;

  if v_attempt_learner_id is null then
    raise exception 'not_found: practice attempt % not found', p_attempt_id
      using errcode = '22023';
  end if;

  if v_attempt_learner_id <> v_learner_id then
    raise exception 'forbidden: attempt does not belong to learner'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.practice_attempt_events pae
    where pae.attempt_id = p_attempt_id
      and pae.event_type = 'completed'
  ) then
    raise exception 'invalid: practice attempt not completed'
      using errcode = '22023';
  end if;

  select lt.current_unit_order
    into v_current_unit_order
  from public.learner_trainings lt
  where lt.learner_id = v_learner_id
    and lt.program_id = v_program_id;

  if v_current_unit_order is null then
    raise exception 'not_found: learner training not found'
      using errcode = '22023';
  end if;

  select max(tu.unit_order)
    into v_max_unit_order
  from public.training_units tu
  where tu.program_id = v_program_id;

  if v_max_unit_order is null then
    raise exception 'not_found: program has no units'
      using errcode = '22023';
  end if;

  v_current_unit_order := least(
    v_max_unit_order,
    greatest(v_current_unit_order, v_unit_order + 1)
  );

  v_completed_units := least(
    v_max_unit_order,
    greatest(v_current_unit_order - 1, v_unit_order)
  );

  v_progress := least(
    100,
    (v_completed_units::numeric / v_max_unit_order::numeric) * 100
  );

  update public.learner_trainings
  set current_unit_order = v_current_unit_order,
      progress_percent = greatest(progress_percent, v_progress)
  where learner_id = v_learner_id
    and program_id = v_program_id;

  return query
  select v_current_unit_order, v_progress;
end;
$$;
