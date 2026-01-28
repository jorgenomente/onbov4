-- 20260127130000_post_mvp3_d2_guardrail_no_in_progress_final_eval.sql
-- Post-MVP 3 / Configuracion del bot — Sub-lote D.2 / C.3
-- Guardrail: bloquear creacion de nueva final_evaluation_config si hay un intento "in_progress"
-- NO schema changes. Solo endurece la RPC existente.

set check_function_bodies = off;

begin;

create or replace function public.create_final_evaluation_config(
  p_program_id uuid,
  p_total_questions integer,
  p_roleplay_ratio numeric,
  p_min_global_score numeric,
  p_must_pass_units integer[],
  p_questions_per_unit integer,
  p_max_attempts integer,
  p_cooldown_hours integer
)
returns uuid
language plpgsql
as $$
declare
  v_role text;
  v_org_id uuid;
  v_new_id uuid;
begin
  v_role := public.current_role();
  v_org_id := public.current_org_id();

  if v_role not in ('admin_org', 'superadmin') then
    raise exception 'forbidden: role % cannot create final evaluation config', v_role
      using errcode = '42501';
  end if;

  -- Validar programa dentro del tenant (y visible por RLS)
  if not exists (
    select 1
    from public.training_programs tp
    where tp.id = p_program_id
      and tp.org_id = v_org_id
  ) then
    raise exception 'not_found: program_id % not in org scope', p_program_id
      using errcode = '22023';
  end if;

  -- Guardrail: no permitir cambios si hay intento en progreso.
  -- Nota: asumimos status = 'in_progress' (alineado a engine). Si tu enum difiere, ajustar el literal.
  if exists (
    select 1
    from public.final_evaluation_attempts a
    where a.program_id = p_program_id
      and a.status = 'in_progress'
  ) then
    raise exception 'conflict: cannot create new config while an attempt is in progress for program_id %', p_program_id
      using errcode = '23505';
  end if;

  -- Validaciones de parametros (guardrails minimos)
  if p_total_questions is null or p_total_questions <= 0 then
    raise exception 'invalid: total_questions must be > 0'
      using errcode = '22023';
  end if;

  if p_roleplay_ratio is null or p_roleplay_ratio < 0 or p_roleplay_ratio > 1 then
    raise exception 'invalid: roleplay_ratio must be between 0 and 1'
      using errcode = '22023';
  end if;

  if p_min_global_score is null or p_min_global_score < 0 or p_min_global_score > 100 then
    raise exception 'invalid: min_global_score must be between 0 and 100'
      using errcode = '22023';
  end if;

  if p_questions_per_unit is null or p_questions_per_unit <= 0 then
    raise exception 'invalid: questions_per_unit must be > 0'
      using errcode = '22023';
  end if;

  if p_max_attempts is null or p_max_attempts <= 0 then
    raise exception 'invalid: max_attempts must be > 0'
      using errcode = '22023';
  end if;

  if p_cooldown_hours is null or p_cooldown_hours < 0 then
    raise exception 'invalid: cooldown_hours must be >= 0'
      using errcode = '22023';
  end if;

  -- Insert-only versioning: siempre insertamos nueva fila (append-only).
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
  values (
    p_program_id,
    p_total_questions,
    p_roleplay_ratio,
    p_min_global_score,
    coalesce(p_must_pass_units, '{}'::integer[]),
    p_questions_per_unit,
    p_max_attempts,
    p_cooldown_hours
  )
  returning id into v_new_id;

  return v_new_id;
end;
$$;

comment on function public.create_final_evaluation_config(
  uuid, integer, numeric, numeric, integer[], integer, integer, integer
) is
'Post-MVP3 D.2/C.3: Insert-only RPC to create a new final_evaluation_configs row. Guardrail: blocks if final_evaluation_attempts has status=in_progress for the program.';

commit;
