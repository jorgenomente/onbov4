# POST-MVP3 C APPEND ONLY RPC FINAL EVAL

## Contexto

Sub-lote C: hacer final_evaluation_configs append-only y agregar RPC segura para insertar nueva config.

## Prompt ejecutado

```txt
-- 20260127123000_post_mvp3_c_final_eval_config_insert_only_rpc.sql
-- Post-MVP 3 / Configuración del bot — Sub-lote C (C.1 + C.2)
-- Objetivo: final_evaluation_configs = INSERT-only (append-only real) + RPC segura para crear nueva config
-- NO UI. NO cambios de engine. NO cambios de schema (solo trigger + función).

set check_function_bodies = off;

begin;

-- ------------------------------------------------------------
-- C.1) Hardening: final_evaluation_configs append-only (bloquear UPDATE/DELETE)
-- ------------------------------------------------------------

-- Asegura que exista prevent_update_delete() (en muchos lotes ya existe).
-- Si ya existe con misma firma, esto solo la redefine (misma intención).
create or replace function public.prevent_update_delete()
returns trigger
language plpgsql
as $$
begin
  raise exception 'UPDATE/DELETE not allowed on % (append-only).', tg_table_name
    using errcode = '42501';
end;
$$;

drop trigger if exists trg_final_evaluation_configs_prevent_update_delete on public.final_evaluation_configs;

create trigger trg_final_evaluation_configs_prevent_update_delete
before update or delete on public.final_evaluation_configs
for each row
execute function public.prevent_update_delete();

comment on trigger trg_final_evaluation_configs_prevent_update_delete on public.final_evaluation_configs is
'Post-MVP3 C.1: Enforce append-only (no UPDATE/DELETE). Insert new rows to version configs.';


-- ------------------------------------------------------------
-- C.2) RPC: create_final_evaluation_config (INSERT-only, con validaciones)
-- ------------------------------------------------------------
-- Nota: dejamos RLS ON (security invoker) para que:
-- - solo pueda ejecutar quien ya puede INSERT por policies (admin_org/superadmin)
-- - y además reforzamos con checks por current_role/current_org_id
-- - sin bypass de Zero Trust

drop function if exists public.create_final_evaluation_config(
  uuid,
  integer,
  numeric,
  numeric,
  integer[],
  integer,
  integer,
  integer
);

create function public.create_final_evaluation_config(
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

  -- Validaciones de parámetros (guardrails mínimos)
  if p_total_questions is null or p_total_questions <= 0 then
    raise exception 'invalid: total_questions must be > 0'
      using errcode = '22023';
  end if;

  if p_roleplay_ratio is null or p_roleplay_ratio < 0 or p_roleplay_ratio > 1 then
    raise exception 'invalid: roleplay_ratio must be between 0 and 1'
      using errcode = '22023';
  end if;

  if p_min_global_score is null or p_min_global_score < 0 or p_min_global_score > 1 then
    -- Si tu score no es 0..1, ajustamos esto luego. Lo dejo acotado para evitar configs absurdas.
    raise exception 'invalid: min_global_score must be between 0 and 1'
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
'Post-MVP3 C.2: Insert-only RPC to create a new final_evaluation_configs row (versioning by created_at). Admin Org / Superadmin only.';

-- Permitir ejecutar la RPC desde sesión autenticada (RLS sigue aplicando).
grant execute on function public.create_final_evaluation_config(
  uuid, integer, numeric, numeric, integer[], integer, integer, integer
) to authenticated;

commit;
```

Resultado esperado

Migracion con trigger append-only y RPC create_final_evaluation_config.

Notas (opcional)

Incluye smoke SQL sugerido para validacion manual.
