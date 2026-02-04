-- 20260131131000_training_progress_practice.sql
-- Allow learner progress updates in training + RPC to advance after practice completion.

-- Update learner_trainings UPDATE policy to allow aprendiz updates while en_entrenamiento/en_practica/en_riesgo/en_revision.
drop policy if exists "learner_trainings_update_public_consolidated" on public.learner_trainings;

drop policy if exists "learner_trainings_insert_aprendiz" on public.learner_trainings;

create policy "learner_trainings_update_public_consolidated"
  on public.learner_trainings
  for update
  using (
    (
      (public.current_role() = 'aprendiz'::public.app_role)
      and (learner_id = (select auth.uid() as uid))
    )
    or (
      (public.current_role() = any (array['superadmin'::public.app_role, 'admin_org'::public.app_role, 'referente'::public.app_role]))
      and (
        (public.current_role() = 'superadmin'::public.app_role)
        or exists (
          select 1
          from public.locals l
          where l.id = learner_trainings.local_id
            and (
              (public.current_role() = 'admin_org'::public.app_role and l.org_id = public.current_org_id())
              or (public.current_role() = 'referente'::public.app_role and learner_trainings.local_id = public.current_local_id())
            )
        )
      )
    )
  )
  with check (
    (
      (public.current_role() = 'aprendiz'::public.app_role)
      and (learner_id = (select auth.uid() as uid))
      and (status = any (array[
        'en_entrenamiento'::public.learner_status,
        'en_practica'::public.learner_status,
        'en_riesgo'::public.learner_status,
        'en_revision'::public.learner_status
      ]))
    )
    or (
      (public.current_role() = any (array['superadmin'::public.app_role, 'admin_org'::public.app_role, 'referente'::public.app_role]))
      and (
        (public.current_role() = 'superadmin'::public.app_role)
        or exists (
          select 1
          from public.locals l
          where l.id = learner_trainings.local_id
            and (
              (public.current_role() = 'admin_org'::public.app_role and l.org_id = public.current_org_id())
              or (public.current_role() = 'referente'::public.app_role and learner_trainings.local_id = public.current_local_id())
            )
        )
      )
    )
  );

-- Allow aprendiz to insert own learner_training when missing (active program by local).
create policy "learner_trainings_insert_aprendiz"
  on public.learner_trainings
  for insert
  with check (
    public.current_role() = 'aprendiz'::public.app_role
    and learner_id = (select auth.uid() as uid)
    and local_id = public.current_local_id()
    and exists (
      select 1
      from public.local_active_programs lap
      where lap.local_id = learner_trainings.local_id
        and lap.program_id = learner_trainings.program_id
    )
  );

-- RPC: advance learner training after a completed practice attempt.
create or replace function public.advance_learner_training_from_practice(
  p_attempt_id uuid
)
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

  v_current_unit_order := greatest(v_current_unit_order, v_unit_order + 1);
  v_progress := least(
    100,
    ((v_current_unit_order - 1)::numeric / v_max_unit_order::numeric) * 100
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

comment on function public.advance_learner_training_from_practice(uuid) is
'Advance learner current_unit_order and progress_percent after a completed practice attempt. Learner-only.';

grant execute on function public.advance_learner_training_from_practice(uuid) to authenticated;

-- RPC: ensure learner_training exists for current learner based on local_active_programs.
create or replace function public.ensure_learner_training_from_active_program()
returns uuid
language plpgsql
as $$
declare
  v_role text;
  v_learner_id uuid;
  v_local_id uuid;
  v_program_id uuid;
  v_existing_id uuid;
begin
  v_role := public.current_role();
  if v_role <> 'aprendiz' then
    raise exception 'forbidden: role % cannot init training', v_role
      using errcode = '42501';
  end if;

  v_learner_id := auth.uid();
  if v_learner_id is null then
    raise exception 'unauthenticated'
      using errcode = '42501';
  end if;

  select lt.id
    into v_existing_id
  from public.learner_trainings lt
  where lt.learner_id = v_learner_id;

  if v_existing_id is not null then
    return v_existing_id;
  end if;

  select p.local_id
    into v_local_id
  from public.profiles p
  where p.user_id = v_learner_id;

  if v_local_id is null then
    raise exception 'not_found: learner has no local assigned'
      using errcode = '22023';
  end if;

  select lap.program_id
    into v_program_id
  from public.local_active_programs lap
  where lap.local_id = v_local_id;

  if v_program_id is null then
    raise exception 'not_found: no active program for local'
      using errcode = '22023';
  end if;

  insert into public.learner_trainings (
    learner_id,
    local_id,
    program_id,
    status,
    current_unit_order,
    progress_percent
  ) values (
    v_learner_id,
    v_local_id,
    v_program_id,
    'en_entrenamiento',
    1,
    0
  )
  returning id into v_existing_id;

  return v_existing_id;
end;
$$;

comment on function public.ensure_learner_training_from_active_program() is
'Create learner_trainings row for current learner based on local_active_programs if missing. Learner-only.';

grant execute on function public.ensure_learner_training_from_active_program() to authenticated;
