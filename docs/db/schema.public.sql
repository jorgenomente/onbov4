


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE TYPE "public"."alert_type" AS ENUM (
    'review_submitted_v2',
    'review_rejected_v2',
    'review_reinforcement_requested_v2',
    'learner_at_risk',
    'final_evaluation_submitted'
);


ALTER TYPE "public"."alert_type" OWNER TO "postgres";


CREATE TYPE "public"."app_role" AS ENUM (
    'superadmin',
    'admin_org',
    'referente',
    'aprendiz'
);


ALTER TYPE "public"."app_role" OWNER TO "postgres";


CREATE TYPE "public"."decision_type_v2" AS ENUM (
    'approve',
    'reject',
    'request_reinforcement'
);


ALTER TYPE "public"."decision_type_v2" OWNER TO "postgres";


CREATE TYPE "public"."learner_status" AS ENUM (
    'en_entrenamiento',
    'en_practica',
    'en_riesgo',
    'en_revision',
    'aprobado'
);


ALTER TYPE "public"."learner_status" OWNER TO "postgres";


CREATE TYPE "public"."perceived_severity" AS ENUM (
    'low',
    'medium',
    'high'
);


ALTER TYPE "public"."perceived_severity" OWNER TO "postgres";


CREATE TYPE "public"."recommended_action" AS ENUM (
    'none',
    'follow_up',
    'retraining'
);


ALTER TYPE "public"."recommended_action" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_and_map_knowledge_item"("p_program_id" "uuid", "p_unit_id" "uuid", "p_title" "text", "p_content" "text", "p_scope" "text", "p_local_id" "uuid", "p_reason" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_role text;
  v_org_id uuid;
  v_program_org_id uuid;
  v_unit_order int;
  v_title text;
  v_content text;
  v_knowledge_id uuid;
  v_local_id uuid;
begin
  v_role := public.current_role();
  v_org_id := public.current_org_id();

  if v_role not in ('admin_org', 'superadmin') then
    raise exception 'forbidden: role % cannot create knowledge', v_role
      using errcode = '42501';
  end if;

  select tp.org_id into v_program_org_id
  from public.training_programs tp
  where tp.id = p_program_id;

  if v_program_org_id is null then
    raise exception 'not_found: program_id % not in org scope', p_program_id
      using errcode = '22023';
  end if;
  if v_role = 'admin_org' and v_program_org_id <> v_org_id then
    raise exception 'not_found: program_id % not in org scope', p_program_id
      using errcode = '22023';
  end if;

  select tu.unit_order into v_unit_order
  from public.training_units tu
  where tu.id = p_unit_id
    and tu.program_id = p_program_id;

  if v_unit_order is null then
    raise exception 'not_found: unit_id % not in program', p_unit_id
      using errcode = '22023';
  end if;

  v_title := trim(coalesce(p_title, ''));
  v_content := trim(coalesce(p_content, ''));

  if length(v_title) = 0 or length(v_title) > 120 then
    raise exception 'invalid: title length must be 1..120'
      using errcode = '22023';
  end if;

  if length(v_content) = 0 or length(v_content) > 20000 then
    raise exception 'invalid: content length must be 1..20000'
      using errcode = '22023';
  end if;

  if p_scope = 'org' then
    if p_local_id is not null then
      raise exception 'invalid: local_id must be null for org scope'
        using errcode = '22023';
    end if;
    v_local_id := null;
  elsif p_scope = 'local' then
    if p_local_id is null then
      raise exception 'invalid: local_id required for local scope'
        using errcode = '22023';
    end if;
    if not exists (
      select 1
      from public.locals l
      where l.id = p_local_id
        and l.org_id = v_program_org_id
    ) then
      raise exception 'invalid: local_id % not in org', p_local_id
        using errcode = '22023';
    end if;
    v_local_id := p_local_id;
  else
    raise exception 'invalid: scope must be org or local'
      using errcode = '22023';
  end if;

  insert into public.knowledge_items (
    org_id,
    local_id,
    title,
    content
  ) values (
    v_program_org_id,
    v_local_id,
    v_title,
    v_content
  ) returning id into v_knowledge_id;

  insert into public.unit_knowledge_map (unit_id, knowledge_id)
  values (p_unit_id, v_knowledge_id);

  insert into public.knowledge_change_events (
    org_id,
    local_id,
    program_id,
    unit_id,
    unit_order,
    knowledge_id,
    action,
    created_by_user_id,
    title
  ) values (
    v_program_org_id,
    v_local_id,
    p_program_id,
    p_unit_id,
    v_unit_order,
    v_knowledge_id,
    'create_and_map',
    auth.uid(),
    v_title
  );

  return v_knowledge_id;
end;
$$;


ALTER FUNCTION "public"."create_and_map_knowledge_item"("p_program_id" "uuid", "p_unit_id" "uuid", "p_title" "text", "p_content" "text", "p_scope" "text", "p_local_id" "uuid", "p_reason" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."create_and_map_knowledge_item"("p_program_id" "uuid", "p_unit_id" "uuid", "p_title" "text", "p_content" "text", "p_scope" "text", "p_local_id" "uuid", "p_reason" "text") IS 'Post-MVP4 K2: create knowledge_item + map to unit in one transaction (append-only).';



CREATE OR REPLACE FUNCTION "public"."create_final_evaluation_config"("p_program_id" "uuid", "p_total_questions" integer, "p_roleplay_ratio" numeric, "p_min_global_score" numeric, "p_must_pass_units" integer[], "p_questions_per_unit" integer, "p_max_attempts" integer, "p_cooldown_hours" integer) RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."create_final_evaluation_config"("p_program_id" "uuid", "p_total_questions" integer, "p_roleplay_ratio" numeric, "p_min_global_score" numeric, "p_must_pass_units" integer[], "p_questions_per_unit" integer, "p_max_attempts" integer, "p_cooldown_hours" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."create_final_evaluation_config"("p_program_id" "uuid", "p_total_questions" integer, "p_roleplay_ratio" numeric, "p_min_global_score" numeric, "p_must_pass_units" integer[], "p_questions_per_unit" integer, "p_max_attempts" integer, "p_cooldown_hours" integer) IS 'Post-MVP3 D.2/C.3: Insert-only RPC to create a new final_evaluation_configs row. Guardrail: blocks if final_evaluation_attempts has status=in_progress for the program.';



CREATE OR REPLACE FUNCTION "public"."current_local_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    SET "row_security" TO 'off'
    AS $$
  select p.local_id
  from public.profiles p
  where p.user_id = auth.uid()
  limit 1;
$$;


ALTER FUNCTION "public"."current_local_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_org_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    SET "row_security" TO 'off'
    AS $$
  select p.org_id
  from public.profiles p
  where p.user_id = auth.uid()
  limit 1;
$$;


ALTER FUNCTION "public"."current_org_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_profile"() RETURNS TABLE("user_id" "uuid", "org_id" "uuid", "local_id" "uuid", "role" "public"."app_role", "full_name" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    SET "row_security" TO 'off'
    AS $$
  select
    p.user_id,
    p.org_id,
    p.local_id,
    p.role,
    p.full_name,
    p.created_at,
    p.updated_at
  from public.profiles p
  where p.user_id = auth.uid()
  limit 1;
$$;


ALTER FUNCTION "public"."current_profile"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_role"() RETURNS "public"."app_role"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    SET "row_security" TO 'off'
    AS $$
  select p.role
  from public.profiles p
  where p.user_id = auth.uid()
  limit 1;
$$;


ALTER FUNCTION "public"."current_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_user_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE
    AS $$
  select auth.uid();
$$;


ALTER FUNCTION "public"."current_user_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."disable_knowledge_item"("p_knowledge_id" "uuid", "p_reason" "text" DEFAULT NULL::"text") RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
declare
  v_role text;
  v_org_id uuid;
  v_knowledge_org_id uuid;
  v_knowledge_local_id uuid;
  v_title text;
  v_reason text;
  v_events int;
begin
  v_role := public.current_role();
  v_org_id := public.current_org_id();

  if v_role not in ('admin_org', 'superadmin') then
    raise exception 'forbidden: role % cannot disable knowledge', v_role
      using errcode = '42501';
  end if;

  select ki.org_id, ki.local_id, ki.title
    into v_knowledge_org_id, v_knowledge_local_id, v_title
  from public.knowledge_items ki
  where ki.id = p_knowledge_id;

  if v_knowledge_org_id is null then
    raise exception 'not_found: knowledge_id % not in org scope', p_knowledge_id
      using errcode = '22023';
  end if;

  if v_role = 'admin_org' and v_knowledge_org_id <> v_org_id then
    raise exception 'not_found: knowledge_id % not in org scope', p_knowledge_id
      using errcode = '22023';
  end if;

  if v_knowledge_local_id is not null then
    if not exists (
      select 1
      from public.locals l
      where l.id = v_knowledge_local_id
        and l.org_id = v_knowledge_org_id
    ) then
      raise exception 'not_found: local_id % not in org scope', v_knowledge_local_id
        using errcode = '22023';
    end if;
  end if;

  v_reason := trim(coalesce(p_reason, ''));
  if length(v_reason) > 500 then
    raise exception 'invalid: reason length must be <= 500'
      using errcode = '22023';
  end if;

  update public.knowledge_items
  set is_enabled = false
  where id = p_knowledge_id;

  insert into public.knowledge_change_events (
    org_id,
    local_id,
    program_id,
    unit_id,
    unit_order,
    knowledge_id,
    action,
    created_by_user_id,
    title,
    reason
  )
  select
    tp.org_id,
    v_knowledge_local_id,
    tp.id,
    tu.id,
    tu.unit_order,
    p_knowledge_id,
    'disable',
    auth.uid(),
    v_title,
    nullif(v_reason, '')
  from public.unit_knowledge_map ukm
  join public.training_units tu on tu.id = ukm.unit_id
  join public.training_programs tp on tp.id = tu.program_id
  where ukm.knowledge_id = p_knowledge_id
    and tp.org_id = v_knowledge_org_id;

  get diagnostics v_events = row_count;

  return v_events;
end;
$$;


ALTER FUNCTION "public"."disable_knowledge_item"("p_knowledge_id" "uuid", "p_reason" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."disable_knowledge_item"("p_knowledge_id" "uuid", "p_reason" "text") IS 'Post-MVP4 K3: disable knowledge item (is_enabled=false) and emit audit events per mapping.';



CREATE OR REPLACE FUNCTION "public"."get_user_email"("target_user_id" "uuid") RETURNS "text"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
  select u.email
  from auth.users u
  where u.id = target_user_id
    and (
      public.current_role() = 'superadmin'
      or (
        public.current_role() = 'admin_org'
        and exists (
          select 1
          from public.learner_trainings lt
          join public.locals l on l.id = lt.local_id
          where lt.learner_id = target_user_id
            and l.org_id = public.current_org_id()
        )
      )
      or (
        public.current_role() = 'referente'
        and exists (
          select 1
          from public.learner_trainings lt
          where lt.learner_id = target_user_id
            and lt.local_id = public.current_local_id()
        )
      )
      or (
        public.current_role() = 'aprendiz'
        and target_user_id = auth.uid()
      )
    )
  limit 1;
$$;


ALTER FUNCTION "public"."get_user_email"("target_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guard_knowledge_items_disable_update"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if new.id is distinct from old.id then
    raise exception 'invalid: id cannot be updated'
      using errcode = '42501';
  end if;

  if new.org_id is distinct from old.org_id
     or new.local_id is distinct from old.local_id
     or new.title is distinct from old.title
     or new.content is distinct from old.content
     or new.created_at is distinct from old.created_at then
    raise exception 'invalid: only is_enabled can be updated'
      using errcode = '42501';
  end if;

  if new.is_enabled is distinct from old.is_enabled then
    if old.is_enabled = true and new.is_enabled = false then
      return new;
    end if;
    if old.is_enabled = false then
      raise exception 'conflict: already disabled'
        using errcode = '23505';
    end if;
  end if;

  raise exception 'invalid: only is_enabled true->false is allowed'
    using errcode = '42501';
end;
$$;


ALTER FUNCTION "public"."guard_knowledge_items_disable_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guard_profiles_update"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if new.user_id <> old.user_id
     or new.org_id <> old.org_id
     or new.local_id <> old.local_id
     or new.role <> old.role
     or new.created_at <> old.created_at then
    raise exception 'only full_name can be updated';
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."guard_profiles_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_future_question"("asked_unit_order" integer, "question_text" "text", "conversation_id" "uuid" DEFAULT NULL::"uuid", "message_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    SET "row_security" TO 'off'
    AS $$
declare
  v_learner_id uuid;
  v_local_id uuid;
  v_program_id uuid;
  v_current_unit integer;
  v_id uuid;
begin
  v_learner_id := auth.uid();
  if v_learner_id is null then
    raise exception 'Unauthenticated';
  end if;

  select p.local_id
    into v_local_id
  from public.profiles p
  where p.user_id = v_learner_id
  limit 1;

  if v_local_id is null then
    raise exception 'Local not found';
  end if;

  select lt.program_id, lt.current_unit_order
    into v_program_id, v_current_unit
  from public.learner_trainings lt
  where lt.learner_id = v_learner_id
  limit 1;

  if v_program_id is null then
    select lap.program_id
      into v_program_id
    from public.local_active_programs lap
    where lap.local_id = v_local_id
    limit 1;
  end if;

  if v_program_id is null or v_current_unit is null then
    raise exception 'Active training not found';
  end if;

  if asked_unit_order <= v_current_unit then
    raise exception 'asked_unit_order must be greater than current_unit_order';
  end if;

  insert into public.learner_future_questions (
    learner_id,
    local_id,
    program_id,
    asked_unit_order,
    conversation_id,
    message_id,
    question_text
  )
  values (
    v_learner_id,
    v_local_id,
    v_program_id,
    asked_unit_order,
    conversation_id,
    message_id,
    question_text
  )
  returning id into v_id;

  return v_id;
end;
$$;


ALTER FUNCTION "public"."log_future_question"("asked_unit_order" integer, "question_text" "text", "conversation_id" "uuid", "message_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_update_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  raise exception 'UPDATE/DELETE not allowed on % (append-only).', tg_table_name
    using errcode = '42501';
end;
$$;


ALTER FUNCTION "public"."prevent_update_delete"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_learner_training_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_learner_training_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_local_active_program"("p_local_id" "uuid", "p_program_id" "uuid", "p_reason" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_role text;
  v_org_id uuid;
  v_from_program_id uuid;
  v_new_program_id uuid;
  v_local_org_id uuid;
  v_program_org_id uuid;
  v_program_local_id uuid;
begin
  v_role := public.current_role();
  v_org_id := public.current_org_id();

  if v_role not in ('admin_org', 'superadmin') then
    raise exception 'forbidden: role % cannot set active program', v_role
      using errcode = '42501';
  end if;

  select l.org_id into v_local_org_id
  from public.locals l
  where l.id = p_local_id;

  if v_local_org_id is null then
    raise exception 'not_found: local_id % not in org scope', p_local_id
      using errcode = '22023';
  end if;
  if v_role = 'admin_org' and v_local_org_id <> v_org_id then
    raise exception 'not_found: local_id % not in org scope', p_local_id
      using errcode = '22023';
  end if;

  select tp.org_id, tp.local_id into v_program_org_id, v_program_local_id
  from public.training_programs tp
  where tp.id = p_program_id;

  if v_program_org_id is null then
    raise exception 'not_found: program_id % not in org scope', p_program_id
      using errcode = '22023';
  end if;
  if v_role = 'admin_org' and v_program_org_id <> v_org_id then
    raise exception 'not_found: program_id % not in org scope', p_program_id
      using errcode = '22023';
  end if;
  if v_program_org_id <> v_local_org_id then
    raise exception 'invalid: program_id % not eligible for local_id %', p_program_id, p_local_id
      using errcode = '22023';
  end if;

  if v_program_local_id is not null and v_program_local_id <> p_local_id then
    raise exception 'invalid: program_id % not eligible for local_id %', p_program_id, p_local_id
      using errcode = '22023';
  end if;

  select lap.program_id into v_from_program_id
  from public.local_active_programs lap
  where lap.local_id = p_local_id;

  insert into public.local_active_programs (local_id, program_id, created_at)
  values (p_local_id, p_program_id, now())
  on conflict (local_id)
  do update set program_id = excluded.program_id;

  v_new_program_id := p_program_id;

  insert into public.local_active_program_change_events (
    org_id,
    local_id,
    from_program_id,
    to_program_id,
    changed_by_user_id,
    reason
  )
  values (
    v_local_org_id,
    p_local_id,
    v_from_program_id,
    v_new_program_id,
    auth.uid(),
    p_reason
  );

  return v_new_program_id;
end;
$$;


ALTER FUNCTION "public"."set_local_active_program"("p_local_id" "uuid", "p_program_id" "uuid", "p_reason" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."set_local_active_program"("p_local_id" "uuid", "p_program_id" "uuid", "p_reason" "text") IS 'Post-MVP3 E.1: Set active program for a local (UPSERT) with audit event. Admin Org / Superadmin only.';



CREATE OR REPLACE FUNCTION "public"."set_profile_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_profile_updated_at"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."alert_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "alert_type" "public"."alert_type" NOT NULL,
    "learner_id" "uuid" NOT NULL,
    "local_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "source_table" "text" NOT NULL,
    "source_id" "uuid" NOT NULL,
    "payload" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "alert_events_payload_object" CHECK (("jsonb_typeof"("payload") = 'object'::"text"))
);


ALTER TABLE "public"."alert_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bot_message_evaluations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "message_id" "uuid" NOT NULL,
    "coherence_score" numeric(4,2),
    "omissions" "text"[],
    "tags" "text"[],
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."bot_message_evaluations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."conversation_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "sender" "text" NOT NULL,
    "content" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "conversation_messages_sender_check" CHECK (("sender" = ANY (ARRAY['learner'::"text", 'bot'::"text", 'system'::"text"])))
);


ALTER TABLE "public"."conversation_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."conversations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "learner_id" "uuid" NOT NULL,
    "local_id" "uuid" NOT NULL,
    "program_id" "uuid" NOT NULL,
    "unit_order" integer NOT NULL,
    "context" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "conversations_unit_order_check" CHECK (("unit_order" >= 1))
);


ALTER TABLE "public"."conversations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."final_evaluation_answers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "question_id" "uuid" NOT NULL,
    "learner_answer" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."final_evaluation_answers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."final_evaluation_attempts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "learner_id" "uuid" NOT NULL,
    "program_id" "uuid" NOT NULL,
    "attempt_number" integer NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ended_at" timestamp with time zone,
    "status" "text" NOT NULL,
    "global_score" numeric(5,2),
    "bot_recommendation" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "final_evaluation_attempts_reco_check" CHECK (("bot_recommendation" = ANY (ARRAY['approved'::"text", 'not_approved'::"text"]))),
    CONSTRAINT "final_evaluation_attempts_status_check" CHECK (("status" = ANY (ARRAY['in_progress'::"text", 'completed'::"text", 'blocked'::"text"])))
);


ALTER TABLE "public"."final_evaluation_attempts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."final_evaluation_configs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "program_id" "uuid" NOT NULL,
    "total_questions" integer NOT NULL,
    "roleplay_ratio" numeric(3,2) NOT NULL,
    "min_global_score" numeric(5,2) NOT NULL,
    "must_pass_units" integer[] DEFAULT '{}'::integer[] NOT NULL,
    "questions_per_unit" integer DEFAULT 1 NOT NULL,
    "max_attempts" integer DEFAULT 3 NOT NULL,
    "cooldown_hours" integer DEFAULT 12 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "final_evaluation_configs_roleplay_check" CHECK ((("roleplay_ratio" >= (0)::numeric) AND ("roleplay_ratio" <= (1)::numeric))),
    CONSTRAINT "final_evaluation_configs_total_questions_check" CHECK (("total_questions" > 0))
);


ALTER TABLE "public"."final_evaluation_configs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."final_evaluation_evaluations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "answer_id" "uuid" NOT NULL,
    "unit_order" integer NOT NULL,
    "score" numeric(5,2) NOT NULL,
    "verdict" "text" NOT NULL,
    "strengths" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "gaps" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "feedback" "text" NOT NULL,
    "doubt_signals" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "final_evaluation_evaluations_score_check" CHECK ((("score" >= (0)::numeric) AND ("score" <= (100)::numeric))),
    CONSTRAINT "final_evaluation_evaluations_verdict_check" CHECK (("verdict" = ANY (ARRAY['pass'::"text", 'partial'::"text", 'fail'::"text"])))
);


ALTER TABLE "public"."final_evaluation_evaluations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."final_evaluation_questions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "attempt_id" "uuid" NOT NULL,
    "unit_order" integer NOT NULL,
    "question_type" "text" NOT NULL,
    "prompt" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "final_evaluation_questions_type_check" CHECK (("question_type" = ANY (ARRAY['direct'::"text", 'roleplay'::"text"]))),
    CONSTRAINT "final_evaluation_questions_unit_order_check" CHECK (("unit_order" >= 1))
);


ALTER TABLE "public"."final_evaluation_questions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."knowledge_change_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "local_id" "uuid",
    "program_id" "uuid" NOT NULL,
    "unit_id" "uuid" NOT NULL,
    "unit_order" integer NOT NULL,
    "knowledge_id" "uuid" NOT NULL,
    "action" "text" DEFAULT 'create_and_map'::"text" NOT NULL,
    "created_by_user_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "reason" "text"
);


ALTER TABLE "public"."knowledge_change_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."knowledge_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "local_id" "uuid",
    "title" "text" NOT NULL,
    "content" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_enabled" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."knowledge_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."learner_future_questions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "learner_id" "uuid" NOT NULL,
    "local_id" "uuid" NOT NULL,
    "program_id" "uuid" NOT NULL,
    "asked_unit_order" integer NOT NULL,
    "conversation_id" "uuid",
    "message_id" "uuid",
    "question_text" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."learner_future_questions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."learner_review_decisions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "learner_id" "uuid" NOT NULL,
    "reviewer_id" "uuid" NOT NULL,
    "decision" "text" NOT NULL,
    "reason" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "reviewer_name" "text",
    CONSTRAINT "learner_review_decisions_decision_check" CHECK (("decision" = ANY (ARRAY['approved'::"text", 'needs_reinforcement'::"text"])))
);


ALTER TABLE "public"."learner_review_decisions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."learner_review_validations_v2" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "learner_id" "uuid" NOT NULL,
    "reviewer_id" "uuid" NOT NULL,
    "local_id" "uuid" NOT NULL,
    "program_id" "uuid" NOT NULL,
    "decision_type" "public"."decision_type_v2" NOT NULL,
    "perceived_severity" "public"."perceived_severity" DEFAULT 'low'::"public"."perceived_severity" NOT NULL,
    "recommended_action" "public"."recommended_action" DEFAULT 'none'::"public"."recommended_action" NOT NULL,
    "checklist" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "comment" "text",
    "reviewer_name" "text" NOT NULL,
    "reviewer_role" "public"."app_role" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "learner_review_validations_v2_checklist_object" CHECK (("jsonb_typeof"("checklist") = 'object'::"text"))
);


ALTER TABLE "public"."learner_review_validations_v2" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."learner_state_transitions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "learner_id" "uuid" NOT NULL,
    "from_status" "public"."learner_status",
    "to_status" "public"."learner_status" NOT NULL,
    "reason" "text",
    "actor_user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."learner_state_transitions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."learner_trainings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "learner_id" "uuid" NOT NULL,
    "local_id" "uuid" NOT NULL,
    "program_id" "uuid" NOT NULL,
    "status" "public"."learner_status" DEFAULT 'en_entrenamiento'::"public"."learner_status" NOT NULL,
    "current_unit_order" integer DEFAULT 1 NOT NULL,
    "progress_percent" numeric(5,2) DEFAULT 0 NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "learner_trainings_current_unit_check" CHECK (("current_unit_order" >= 1)),
    CONSTRAINT "learner_trainings_progress_check" CHECK ((("progress_percent" >= (0)::numeric) AND ("progress_percent" <= (100)::numeric)))
);


ALTER TABLE "public"."learner_trainings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."local_active_program_change_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "local_id" "uuid" NOT NULL,
    "from_program_id" "uuid",
    "to_program_id" "uuid" NOT NULL,
    "changed_by_user_id" "uuid" NOT NULL,
    "reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."local_active_program_change_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."local_active_programs" (
    "local_id" "uuid" NOT NULL,
    "program_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."local_active_programs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."locals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."locals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notification_emails" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "local_id" "uuid" NOT NULL,
    "learner_id" "uuid" NOT NULL,
    "decision_id" "uuid" NOT NULL,
    "email_type" "text" NOT NULL,
    "to_email" "text" NOT NULL,
    "subject" "text" NOT NULL,
    "provider" "text" DEFAULT 'resend'::"text" NOT NULL,
    "provider_message_id" "text",
    "status" "text" NOT NULL,
    "error" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "notification_emails_status_check" CHECK (("status" = ANY (ARRAY['sent'::"text", 'failed'::"text"]))),
    CONSTRAINT "notification_emails_type_check" CHECK (("email_type" = ANY (ARRAY['decision_approved'::"text", 'decision_needs_reinforcement'::"text"])))
);


ALTER TABLE "public"."notification_emails" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."organizations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."organizations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."practice_attempt_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "attempt_id" "uuid" NOT NULL,
    "event_type" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "practice_attempt_events_type_check" CHECK (("event_type" = 'completed'::"text"))
);


ALTER TABLE "public"."practice_attempt_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."practice_attempts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "scenario_id" "uuid" NOT NULL,
    "learner_id" "uuid" NOT NULL,
    "local_id" "uuid" NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ended_at" timestamp with time zone,
    "status" "text" NOT NULL,
    CONSTRAINT "practice_attempts_status_check" CHECK (("status" = ANY (ARRAY['in_progress'::"text", 'completed'::"text"])))
);


ALTER TABLE "public"."practice_attempts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."practice_evaluations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "attempt_id" "uuid" NOT NULL,
    "learner_message_id" "uuid" NOT NULL,
    "score" numeric(5,2) NOT NULL,
    "verdict" "text" NOT NULL,
    "strengths" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "gaps" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "feedback" "text" NOT NULL,
    "doubt_signals" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "practice_evaluations_score_check" CHECK ((("score" >= (0)::numeric) AND ("score" <= (100)::numeric))),
    CONSTRAINT "practice_evaluations_verdict_check" CHECK (("verdict" = ANY (ARRAY['pass'::"text", 'partial'::"text", 'fail'::"text"])))
);


ALTER TABLE "public"."practice_evaluations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."practice_scenarios" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "local_id" "uuid",
    "program_id" "uuid" NOT NULL,
    "unit_order" integer NOT NULL,
    "title" "text" NOT NULL,
    "difficulty" integer DEFAULT 1 NOT NULL,
    "instructions" "text" NOT NULL,
    "success_criteria" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "practice_scenarios_difficulty_check" CHECK ((("difficulty" >= 1) AND ("difficulty" <= 5))),
    CONSTRAINT "practice_scenarios_unit_order_check" CHECK (("unit_order" >= 1))
);


ALTER TABLE "public"."practice_scenarios" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "user_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "local_id" "uuid" NOT NULL,
    "role" "public"."app_role" NOT NULL,
    "full_name" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."training_programs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "local_id" "uuid",
    "name" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."training_programs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."training_units" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "program_id" "uuid" NOT NULL,
    "unit_order" integer NOT NULL,
    "title" "text" NOT NULL,
    "objectives" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "training_units_unit_order_check" CHECK (("unit_order" >= 1))
);


ALTER TABLE "public"."training_units" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."unit_knowledge_map" (
    "unit_id" "uuid" NOT NULL,
    "knowledge_id" "uuid" NOT NULL
);


ALTER TABLE "public"."unit_knowledge_map" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_conversation_thread" AS
 SELECT "id" AS "message_id",
    "sender",
    "content",
    "created_at"
   FROM "public"."conversation_messages" "cm"
  ORDER BY "created_at";


ALTER VIEW "public"."v_conversation_thread" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_learner_active_conversation" AS
 SELECT "c"."id" AS "conversation_id",
    "c"."unit_order",
    "c"."context",
    "c"."created_at"
   FROM ("public"."learner_trainings" "lt"
     LEFT JOIN LATERAL ( SELECT "conv"."id",
            "conv"."unit_order",
            "conv"."context",
            "conv"."created_at"
           FROM "public"."conversations" "conv"
          WHERE (("conv"."learner_id" = "lt"."learner_id") AND ("conv"."unit_order" = "lt"."current_unit_order"))
          ORDER BY "conv"."created_at" DESC
         LIMIT 1) "c" ON (true))
  WHERE ("lt"."learner_id" = "auth"."uid"());


ALTER VIEW "public"."v_learner_active_conversation" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_learner_doubt_signals" AS
 WITH "scoped_learners" AS (
         SELECT "lt"."learner_id",
            "lt"."program_id",
            "lt"."local_id",
            "l"."org_id"
           FROM ("public"."learner_trainings" "lt"
             JOIN "public"."locals" "l" ON (("l"."id" = "lt"."local_id")))
          WHERE (("public"."current_role"() = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])) AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR (("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "public"."current_org_id"())) OR (("public"."current_role"() = 'referente'::"public"."app_role") AND ("lt"."local_id" = "public"."current_local_id"()))))
        ), "final_signals" AS (
         SELECT "sl"."org_id",
            "sl"."local_id",
            "a"."learner_id",
            "a"."program_id",
            "q"."unit_order",
            "unnest"("ev"."doubt_signals") AS "signal",
            "ev"."created_at" AS "seen_at",
            'final'::"text" AS "source"
           FROM (((("scoped_learners" "sl"
             JOIN "public"."final_evaluation_attempts" "a" ON ((("a"."learner_id" = "sl"."learner_id") AND ("a"."program_id" = "sl"."program_id"))))
             JOIN "public"."final_evaluation_questions" "q" ON (("q"."attempt_id" = "a"."id")))
             JOIN "public"."final_evaluation_answers" "ans" ON (("ans"."question_id" = "q"."id")))
             JOIN "public"."final_evaluation_evaluations" "ev" ON (("ev"."answer_id" = "ans"."id")))
          WHERE (COALESCE("array_length"("ev"."doubt_signals", 1), 0) > 0)
        ), "practice_signals" AS (
         SELECT "sl"."org_id",
            "sl"."local_id",
            "pa"."learner_id",
            "ps"."program_id",
            "ps"."unit_order",
            "unnest"("pe"."doubt_signals") AS "signal",
            "pe"."created_at" AS "seen_at",
            'practice'::"text" AS "source"
           FROM ((("scoped_learners" "sl"
             JOIN "public"."practice_attempts" "pa" ON (("pa"."learner_id" = "sl"."learner_id")))
             JOIN "public"."practice_scenarios" "ps" ON ((("ps"."id" = "pa"."scenario_id") AND ("ps"."program_id" = "sl"."program_id"))))
             JOIN "public"."practice_evaluations" "pe" ON (("pe"."attempt_id" = "pa"."id")))
          WHERE (COALESCE("array_length"("pe"."doubt_signals", 1), 0) > 0)
        ), "all_signals" AS (
         SELECT "final_signals"."org_id",
            "final_signals"."local_id",
            "final_signals"."learner_id",
            "final_signals"."program_id",
            "final_signals"."unit_order",
            "final_signals"."signal",
            "final_signals"."seen_at",
            "final_signals"."source"
           FROM "final_signals"
        UNION ALL
         SELECT "practice_signals"."org_id",
            "practice_signals"."local_id",
            "practice_signals"."learner_id",
            "practice_signals"."program_id",
            "practice_signals"."unit_order",
            "practice_signals"."signal",
            "practice_signals"."seen_at",
            "practice_signals"."source"
           FROM "practice_signals"
        )
 SELECT "org_id",
    "local_id",
    "learner_id",
    "program_id",
    "unit_order",
    "signal",
    ("count"(*))::integer AS "total_count",
    "max"("seen_at") AS "last_seen_at",
    "array_agg"(DISTINCT "source") AS "sources"
   FROM "all_signals"
  GROUP BY "org_id", "local_id", "learner_id", "program_id", "unit_order", "signal";


ALTER VIEW "public"."v_learner_doubt_signals" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_learner_evaluation_summary" AS
 WITH "scoped_attempts" AS (
         SELECT "a"."id" AS "attempt_id",
            "a"."learner_id",
            "a"."program_id",
            "a"."attempt_number",
            "a"."status",
            "a"."global_score",
            "a"."bot_recommendation",
            "a"."started_at",
            "a"."ended_at",
            "a"."created_at",
            "lt"."local_id",
            "l"."org_id"
           FROM (("public"."final_evaluation_attempts" "a"
             JOIN "public"."learner_trainings" "lt" ON ((("lt"."learner_id" = "a"."learner_id") AND ("lt"."program_id" = "a"."program_id"))))
             JOIN "public"."locals" "l" ON (("l"."id" = "lt"."local_id")))
          WHERE (("public"."current_role"() = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])) AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR (("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "public"."current_org_id"())) OR (("public"."current_role"() = 'referente'::"public"."app_role") AND ("lt"."local_id" = "public"."current_local_id"()))))
        )
 SELECT "sa"."org_id",
    "sa"."local_id",
    "sa"."learner_id",
    "sa"."program_id",
    "sa"."attempt_id",
    "sa"."attempt_number",
    "sa"."status",
    "sa"."global_score",
    "sa"."bot_recommendation",
    "q"."unit_order",
    ("count"(*))::integer AS "total_questions",
    ("avg"("ev"."score"))::numeric(5,2) AS "avg_score",
    ("count"(*) FILTER (WHERE ("ev"."verdict" = 'pass'::"text")))::integer AS "pass_count",
    ("count"(*) FILTER (WHERE ("ev"."verdict" = 'partial'::"text")))::integer AS "partial_count",
    ("count"(*) FILTER (WHERE ("ev"."verdict" = 'fail'::"text")))::integer AS "fail_count",
    "max"("ev"."created_at") AS "last_evaluated_at"
   FROM ((("scoped_attempts" "sa"
     JOIN "public"."final_evaluation_questions" "q" ON (("q"."attempt_id" = "sa"."attempt_id")))
     LEFT JOIN "public"."final_evaluation_answers" "ans" ON (("ans"."question_id" = "q"."id")))
     LEFT JOIN "public"."final_evaluation_evaluations" "ev" ON (("ev"."answer_id" = "ans"."id")))
  GROUP BY "sa"."org_id", "sa"."local_id", "sa"."learner_id", "sa"."program_id", "sa"."attempt_id", "sa"."attempt_number", "sa"."status", "sa"."global_score", "sa"."bot_recommendation", "q"."unit_order";


ALTER VIEW "public"."v_learner_evaluation_summary" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_learner_evidence" AS
 SELECT "lt"."learner_id",
    "practice"."practice_summary",
    "doubts"."doubt_signals",
    "messages"."recent_messages"
   FROM ((("public"."learner_trainings" "lt"
     LEFT JOIN LATERAL ( SELECT COALESCE("json_agg"("json_build_object"('scenario_title', "pe"."scenario_title", 'score', "pe"."score", 'verdict', "pe"."verdict", 'feedback', "pe"."feedback", 'created_at', "pe"."created_at") ORDER BY "pe"."created_at" DESC), '[]'::json) AS "practice_summary"
           FROM ( SELECT "ps"."title" AS "scenario_title",
                    "pev"."score",
                    "pev"."verdict",
                    "pev"."feedback",
                    "pev"."created_at"
                   FROM (("public"."practice_evaluations" "pev"
                     JOIN "public"."practice_attempts" "pa" ON (("pa"."id" = "pev"."attempt_id")))
                     JOIN "public"."practice_scenarios" "ps" ON (("ps"."id" = "pa"."scenario_id")))
                  WHERE ("pa"."learner_id" = "lt"."learner_id")
                  ORDER BY "pev"."created_at" DESC
                 LIMIT 10) "pe") "practice" ON (true))
     LEFT JOIN LATERAL ( SELECT COALESCE("array_agg"(DISTINCT "signal"."signal"), '{}'::"text"[]) AS "doubt_signals"
           FROM (("public"."practice_evaluations" "pev"
             JOIN "public"."practice_attempts" "pa" ON (("pa"."id" = "pev"."attempt_id")))
             LEFT JOIN LATERAL "unnest"("pev"."doubt_signals") "signal"("signal") ON (true))
          WHERE ("pa"."learner_id" = "lt"."learner_id")) "doubts" ON (true))
     LEFT JOIN LATERAL ( SELECT COALESCE("json_agg"("json_build_object"('sender', "cm"."sender", 'content', "cm"."content", 'created_at', "cm"."created_at") ORDER BY "cm"."created_at" DESC), '[]'::json) AS "recent_messages"
           FROM ( SELECT "cm_1"."sender",
                    "cm_1"."content",
                    "cm_1"."created_at"
                   FROM ("public"."conversation_messages" "cm_1"
                     JOIN "public"."conversations" "c" ON (("c"."id" = "cm_1"."conversation_id")))
                  WHERE ("c"."learner_id" = "lt"."learner_id")
                  ORDER BY "cm_1"."created_at" DESC
                 LIMIT 5) "cm") "messages" ON (true));


ALTER VIEW "public"."v_learner_evidence" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_learner_progress" AS
 SELECT "lt"."learner_id",
    "lt"."status",
    "lt"."progress_percent",
    "lt"."current_unit_order",
    COALESCE("json_agg"("json_build_object"('unit_order', "tu"."unit_order", 'title', "tu"."title", 'is_completed', ("tu"."unit_order" < "lt"."current_unit_order")) ORDER BY "tu"."unit_order") FILTER (WHERE ("tu"."id" IS NOT NULL)), '[]'::json) AS "units"
   FROM ("public"."learner_trainings" "lt"
     JOIN "public"."training_units" "tu" ON (("tu"."program_id" = "lt"."program_id")))
  WHERE ("lt"."learner_id" = "auth"."uid"())
  GROUP BY "lt"."learner_id", "lt"."status", "lt"."progress_percent", "lt"."current_unit_order";


ALTER VIEW "public"."v_learner_progress" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_learner_training_home" AS
 SELECT "lt"."learner_id",
    "lt"."status",
    "lt"."program_id",
    "tp"."name" AS "program_name",
    "lt"."current_unit_order",
    "total_units"."total_units",
    "cu"."title" AS "current_unit_title",
    "cu"."objectives",
    "lt"."progress_percent"
   FROM ((("public"."learner_trainings" "lt"
     JOIN "public"."training_programs" "tp" ON (("tp"."id" = "lt"."program_id")))
     LEFT JOIN "public"."training_units" "cu" ON ((("cu"."program_id" = "lt"."program_id") AND ("cu"."unit_order" = "lt"."current_unit_order"))))
     LEFT JOIN ( SELECT "tu"."program_id",
            ("count"(1))::integer AS "total_units"
           FROM "public"."training_units" "tu"
          GROUP BY "tu"."program_id") "total_units" ON (("total_units"."program_id" = "lt"."program_id")))
  WHERE ("lt"."learner_id" = "auth"."uid"());


ALTER VIEW "public"."v_learner_training_home" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_learner_wrong_answers" AS
 WITH "scoped_attempts" AS (
         SELECT "a"."id" AS "attempt_id",
            "a"."learner_id",
            "a"."program_id",
            "lt"."local_id",
            "l"."org_id"
           FROM (("public"."final_evaluation_attempts" "a"
             JOIN "public"."learner_trainings" "lt" ON ((("lt"."learner_id" = "a"."learner_id") AND ("lt"."program_id" = "a"."program_id"))))
             JOIN "public"."locals" "l" ON (("l"."id" = "lt"."local_id")))
          WHERE (("public"."current_role"() = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])) AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR (("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "public"."current_org_id"())) OR (("public"."current_role"() = 'referente'::"public"."app_role") AND ("lt"."local_id" = "public"."current_local_id"()))))
        )
 SELECT "sa"."org_id",
    "sa"."local_id",
    "sa"."learner_id",
    "sa"."program_id",
    "sa"."attempt_id",
    "q"."unit_order",
    "q"."id" AS "question_id",
    "q"."question_type",
    "q"."prompt",
    "ans"."id" AS "answer_id",
    "ans"."learner_answer",
    "ev"."score",
    "ev"."verdict",
    "ev"."strengths",
    "ev"."gaps",
    "ev"."feedback",
    "ev"."doubt_signals",
    "ev"."created_at"
   FROM ((("scoped_attempts" "sa"
     JOIN "public"."final_evaluation_questions" "q" ON (("q"."attempt_id" = "sa"."attempt_id")))
     JOIN "public"."final_evaluation_answers" "ans" ON (("ans"."question_id" = "q"."id")))
     JOIN "public"."final_evaluation_evaluations" "ev" ON (("ev"."answer_id" = "ans"."id")))
  WHERE ("ev"."verdict" <> 'pass'::"text");


ALTER VIEW "public"."v_learner_wrong_answers" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_local_learner_risk_30d" AS
 WITH "scoped_ctx" AS (
         SELECT "public"."current_local_id"() AS "local_id",
            "public"."current_org_id"() AS "org_id",
            "public"."current_role"() AS "role_name"
        ), "practice_events" AS (
         SELECT "pa"."local_id",
            "pa"."learner_id",
            "pe"."verdict",
            "pe"."doubt_signals",
            "pe"."created_at"
           FROM ("public"."practice_evaluations" "pe"
             JOIN "public"."practice_attempts" "pa" ON (("pa"."id" = "pe"."attempt_id")))
          WHERE ("pe"."created_at" >= ("now"() - '30 days'::interval))
        ), "final_events" AS (
         SELECT "lt"."local_id",
            "a"."learner_id",
            "ev"."verdict",
            "ev"."doubt_signals",
            "ev"."created_at"
           FROM (((("public"."final_evaluation_evaluations" "ev"
             JOIN "public"."final_evaluation_answers" "ans" ON (("ans"."id" = "ev"."answer_id")))
             JOIN "public"."final_evaluation_questions" "q" ON (("q"."id" = "ans"."question_id")))
             JOIN "public"."final_evaluation_attempts" "a" ON (("a"."id" = "q"."attempt_id")))
             JOIN "public"."learner_trainings" "lt" ON ((("lt"."learner_id" = "a"."learner_id") AND ("lt"."program_id" = "a"."program_id"))))
          WHERE ("ev"."created_at" >= ("now"() - '30 days'::interval))
        ), "scoped_practice" AS (
         SELECT "p"."local_id",
            "p"."learner_id",
            "p"."verdict",
            "p"."doubt_signals",
            "p"."created_at"
           FROM (("practice_events" "p"
             JOIN "public"."locals" "l" ON (("l"."id" = "p"."local_id")))
             CROSS JOIN "scoped_ctx" "s")
          WHERE (("s"."role_name" = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])) AND (("s"."role_name" = 'superadmin'::"public"."app_role") OR (("s"."role_name" = 'referente'::"public"."app_role") AND ("p"."local_id" = "s"."local_id")) OR (("s"."role_name" = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "s"."org_id"))))
        ), "scoped_final" AS (
         SELECT "f"."local_id",
            "f"."learner_id",
            "f"."verdict",
            "f"."doubt_signals",
            "f"."created_at"
           FROM (("final_events" "f"
             JOIN "public"."locals" "l" ON (("l"."id" = "f"."local_id")))
             CROSS JOIN "scoped_ctx" "s")
          WHERE (("s"."role_name" = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])) AND (("s"."role_name" = 'superadmin'::"public"."app_role") OR (("s"."role_name" = 'referente'::"public"."app_role") AND ("f"."local_id" = "s"."local_id")) OR (("s"."role_name" = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "s"."org_id"))))
        ), "practice_agg" AS (
         SELECT "scoped_practice"."local_id",
            "scoped_practice"."learner_id",
            ("count"(*) FILTER (WHERE ("scoped_practice"."verdict" = 'fail'::"text")))::integer AS "failed_practice_count",
            ("count"(*) FILTER (WHERE ("scoped_practice"."verdict" = 'partial'::"text")))::integer AS "partial_practice_count",
            ("sum"(COALESCE("array_length"("scoped_practice"."doubt_signals", 1), 0)))::integer AS "practice_doubt_signals_count",
            "max"("scoped_practice"."created_at") AS "last_practice_at"
           FROM "scoped_practice"
          GROUP BY "scoped_practice"."local_id", "scoped_practice"."learner_id"
        ), "final_agg" AS (
         SELECT "scoped_final"."local_id",
            "scoped_final"."learner_id",
            ("count"(*) FILTER (WHERE ("scoped_final"."verdict" = 'fail'::"text")))::integer AS "failed_final_count",
            ("count"(*) FILTER (WHERE ("scoped_final"."verdict" = 'partial'::"text")))::integer AS "partial_final_count",
            ("sum"(COALESCE("array_length"("scoped_final"."doubt_signals", 1), 0)))::integer AS "final_doubt_signals_count",
            "max"("scoped_final"."created_at") AS "last_final_at"
           FROM "scoped_final"
          GROUP BY "scoped_final"."local_id", "scoped_final"."learner_id"
        ), "merged" AS (
         SELECT COALESCE("p"."local_id", "f"."local_id") AS "local_id",
            COALESCE("p"."learner_id", "f"."learner_id") AS "learner_id",
            COALESCE("p"."failed_practice_count", 0) AS "failed_practice_count",
            COALESCE("f"."failed_final_count", 0) AS "failed_final_count",
            (COALESCE("p"."practice_doubt_signals_count", 0) + COALESCE("f"."final_doubt_signals_count", 0)) AS "doubt_signals_count",
            GREATEST(COALESCE("p"."last_practice_at", '1970-01-01 00:00:00+00'::timestamp with time zone), COALESCE("f"."last_final_at", '1970-01-01 00:00:00+00'::timestamp with time zone)) AS "last_activity_at"
           FROM ("practice_agg" "p"
             FULL JOIN "final_agg" "f" ON ((("f"."local_id" = "p"."local_id") AND ("f"."learner_id" = "p"."learner_id"))))
        )
 SELECT "local_id",
    "learner_id",
    "failed_practice_count",
    "failed_final_count",
    "doubt_signals_count",
    NULLIF("last_activity_at", '1970-01-01 00:00:00+00'::timestamp with time zone) AS "last_activity_at",
        CASE
            WHEN (("failed_final_count" >= 1) OR ("failed_practice_count" >= 3) OR ("doubt_signals_count" >= 3)) THEN 'high'::"text"
            WHEN ((("failed_practice_count" >= 1) AND ("failed_practice_count" <= 2)) OR (("doubt_signals_count" >= 1) AND ("doubt_signals_count" <= 2))) THEN 'medium'::"text"
            ELSE 'low'::"text"
        END AS "risk_level",
    "array_remove"(ARRAY[
        CASE
            WHEN ("failed_final_count" >= 1) THEN 'failed_final>=1'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("failed_practice_count" >= 3) THEN 'failed_practice>=3'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("doubt_signals_count" >= 3) THEN 'doubt_signals>=3'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN (("failed_practice_count" >= 1) AND ("failed_practice_count" <= 2)) THEN 'failed_practice=1..2'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN (("doubt_signals_count" >= 1) AND ("doubt_signals_count" <= 2)) THEN 'doubt_signals=1..2'::"text"
            ELSE NULL::"text"
        END], NULL::"text") AS "reasons"
   FROM "merged" "m";


ALTER VIEW "public"."v_local_learner_risk_30d" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_local_top_gaps_30d" AS
 WITH "scoped_local" AS (
         SELECT "public"."current_local_id"() AS "local_id",
            "public"."current_org_id"() AS "org_id",
            "public"."current_role"() AS "role_name"
        ), "practice_gaps" AS (
         SELECT "pa"."local_id",
            "pa"."learner_id",
            "unnest"("pe"."gaps") AS "gap",
            "pe"."created_at"
           FROM ("public"."practice_evaluations" "pe"
             JOIN "public"."practice_attempts" "pa" ON (("pa"."id" = "pe"."attempt_id")))
          WHERE (("pe"."created_at" >= ("now"() - '30 days'::interval)) AND (COALESCE("array_length"("pe"."gaps", 1), 0) > 0))
        ), "final_gaps" AS (
         SELECT "lt"."local_id",
            "a_1"."learner_id",
            "unnest"("ev"."gaps") AS "gap",
            "ev"."created_at"
           FROM (((("public"."final_evaluation_evaluations" "ev"
             JOIN "public"."final_evaluation_answers" "ans" ON (("ans"."id" = "ev"."answer_id")))
             JOIN "public"."final_evaluation_questions" "q" ON (("q"."id" = "ans"."question_id")))
             JOIN "public"."final_evaluation_attempts" "a_1" ON (("a_1"."id" = "q"."attempt_id")))
             JOIN "public"."learner_trainings" "lt" ON ((("lt"."learner_id" = "a_1"."learner_id") AND ("lt"."program_id" = "a_1"."program_id"))))
          WHERE (("ev"."created_at" >= ("now"() - '30 days'::interval)) AND (COALESCE("array_length"("ev"."gaps", 1), 0) > 0))
        ), "unioned" AS (
         SELECT "practice_gaps"."local_id",
            "practice_gaps"."learner_id",
            "practice_gaps"."gap",
            "practice_gaps"."created_at"
           FROM "practice_gaps"
        UNION ALL
         SELECT "final_gaps"."local_id",
            "final_gaps"."learner_id",
            "final_gaps"."gap",
            "final_gaps"."created_at"
           FROM "final_gaps"
        ), "scoped" AS (
         SELECT "u"."local_id",
            "u"."learner_id",
            "u"."gap",
            "u"."created_at"
           FROM (("unioned" "u"
             JOIN "public"."locals" "l" ON (("l"."id" = "u"."local_id")))
             CROSS JOIN "scoped_local" "s")
          WHERE (("s"."role_name" = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])) AND (("s"."role_name" = 'superadmin'::"public"."app_role") OR (("s"."role_name" = 'referente'::"public"."app_role") AND ("u"."local_id" = "s"."local_id")) OR (("s"."role_name" = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "s"."org_id"))))
        ), "practice_activity" AS (
         SELECT "pa"."local_id",
            "pa"."learner_id",
            "pe"."created_at"
           FROM ("public"."practice_evaluations" "pe"
             JOIN "public"."practice_attempts" "pa" ON (("pa"."id" = "pe"."attempt_id")))
          WHERE ("pe"."created_at" >= ("now"() - '30 days'::interval))
        ), "final_activity" AS (
         SELECT "lt"."local_id",
            "a_1"."learner_id",
            "ev"."created_at"
           FROM (((("public"."final_evaluation_evaluations" "ev"
             JOIN "public"."final_evaluation_answers" "ans" ON (("ans"."id" = "ev"."answer_id")))
             JOIN "public"."final_evaluation_questions" "q" ON (("q"."id" = "ans"."question_id")))
             JOIN "public"."final_evaluation_attempts" "a_1" ON (("a_1"."id" = "q"."attempt_id")))
             JOIN "public"."learner_trainings" "lt" ON ((("lt"."learner_id" = "a_1"."learner_id") AND ("lt"."program_id" = "a_1"."program_id"))))
          WHERE ("ev"."created_at" >= ("now"() - '30 days'::interval))
        ), "activity_union" AS (
         SELECT "practice_activity"."local_id",
            "practice_activity"."learner_id",
            "practice_activity"."created_at"
           FROM "practice_activity"
        UNION ALL
         SELECT "final_activity"."local_id",
            "final_activity"."learner_id",
            "final_activity"."created_at"
           FROM "final_activity"
        ), "activity_scoped" AS (
         SELECT "a_1"."local_id",
            "a_1"."learner_id",
            "a_1"."created_at"
           FROM (("activity_union" "a_1"
             JOIN "public"."locals" "l" ON (("l"."id" = "a_1"."local_id")))
             CROSS JOIN "scoped_local" "s")
          WHERE (("s"."role_name" = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])) AND (("s"."role_name" = 'superadmin'::"public"."app_role") OR (("s"."role_name" = 'referente'::"public"."app_role") AND ("a_1"."local_id" = "s"."local_id")) OR (("s"."role_name" = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "s"."org_id"))))
        ), "local_learners" AS (
         SELECT DISTINCT "activity_scoped"."learner_id"
           FROM "activity_scoped"
        ), "agg" AS (
         SELECT "scoped"."local_id",
            "scoped"."gap",
            ("count"(*))::integer AS "count_total",
            ("count"(DISTINCT "scoped"."learner_id"))::integer AS "learners_affected",
            "max"("scoped"."created_at") AS "last_seen_at"
           FROM "scoped"
          GROUP BY "scoped"."local_id", "scoped"."gap"
        ), "denom" AS (
         SELECT ("count"(*))::integer AS "local_learner_count"
           FROM "local_learners"
        )
 SELECT "a"."local_id",
    "a"."gap",
    "a"."count_total",
    "a"."learners_affected",
        CASE
            WHEN ("d"."local_learner_count" = 0) THEN (0)::numeric
            ELSE "round"(((("a"."learners_affected")::numeric / ("d"."local_learner_count")::numeric) * (100)::numeric), 2)
        END AS "percent_learners_affected",
    "a"."last_seen_at"
   FROM ("agg" "a"
     CROSS JOIN "denom" "d");


ALTER VIEW "public"."v_local_top_gaps_30d" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_local_unit_coverage_30d" AS
 WITH "ctx" AS (
         SELECT "public"."current_local_id"() AS "local_id",
            "public"."current_org_id"() AS "org_id",
            "public"."current_role"() AS "role_name"
        ), "practice_scoped" AS (
         SELECT "pa"."local_id",
            "ps"."program_id",
            "ps"."unit_order",
            "pe"."score",
            "pe"."verdict",
            "pe"."gaps",
            "pe"."created_at"
           FROM (("public"."practice_evaluations" "pe"
             JOIN "public"."practice_attempts" "pa" ON (("pa"."id" = "pe"."attempt_id")))
             JOIN "public"."practice_scenarios" "ps" ON (("ps"."id" = "pa"."scenario_id")))
          WHERE ("pe"."created_at" >= ("now"() - '30 days'::interval))
        ), "final_scoped" AS (
         SELECT "lt"."local_id",
            "a"."program_id",
            "ev"."unit_order",
            "ev"."score",
            "ev"."verdict",
            "ev"."gaps",
            "ev"."created_at"
           FROM (((("public"."final_evaluation_evaluations" "ev"
             JOIN "public"."final_evaluation_answers" "ans" ON (("ans"."id" = "ev"."answer_id")))
             JOIN "public"."final_evaluation_questions" "q" ON (("q"."id" = "ans"."question_id")))
             JOIN "public"."final_evaluation_attempts" "a" ON (("a"."id" = "q"."attempt_id")))
             JOIN "public"."learner_trainings" "lt" ON ((("lt"."learner_id" = "a"."learner_id") AND ("lt"."program_id" = "a"."program_id"))))
          WHERE ("ev"."created_at" >= ("now"() - '30 days'::interval))
        ), "practice_filtered" AS (
         SELECT "p_1"."local_id",
            "p_1"."program_id",
            "p_1"."unit_order",
            "p_1"."score",
            "p_1"."verdict",
            "p_1"."gaps",
            "p_1"."created_at"
           FROM (("practice_scoped" "p_1"
             JOIN "public"."locals" "l" ON (("l"."id" = "p_1"."local_id")))
             CROSS JOIN "ctx" "c")
          WHERE (("c"."role_name" = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])) AND (("c"."role_name" = 'superadmin'::"public"."app_role") OR (("c"."role_name" = 'referente'::"public"."app_role") AND ("p_1"."local_id" = "c"."local_id")) OR (("c"."role_name" = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "c"."org_id"))))
        ), "final_filtered" AS (
         SELECT "f_1"."local_id",
            "f_1"."program_id",
            "f_1"."unit_order",
            "f_1"."score",
            "f_1"."verdict",
            "f_1"."gaps",
            "f_1"."created_at"
           FROM (("final_scoped" "f_1"
             JOIN "public"."locals" "l" ON (("l"."id" = "f_1"."local_id")))
             CROSS JOIN "ctx" "c")
          WHERE (("c"."role_name" = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])) AND (("c"."role_name" = 'superadmin'::"public"."app_role") OR (("c"."role_name" = 'referente'::"public"."app_role") AND ("f_1"."local_id" = "c"."local_id")) OR (("c"."role_name" = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "c"."org_id"))))
        ), "practice_unit" AS (
         SELECT "practice_filtered"."local_id",
            "practice_filtered"."program_id",
            "practice_filtered"."unit_order",
            ("avg"("practice_filtered"."score"))::numeric(5,2) AS "avg_practice_score",
            (("count"(*) FILTER (WHERE ("practice_filtered"."verdict" = 'fail'::"text")))::numeric / NULLIF(("count"(*))::numeric, (0)::numeric)) AS "practice_fail_rate"
           FROM "practice_filtered"
          GROUP BY "practice_filtered"."local_id", "practice_filtered"."program_id", "practice_filtered"."unit_order"
        ), "final_unit" AS (
         SELECT "final_filtered"."local_id",
            "final_filtered"."program_id",
            "final_filtered"."unit_order",
            ("avg"("final_filtered"."score"))::numeric(5,2) AS "avg_final_score",
            (("count"(*) FILTER (WHERE ("final_filtered"."verdict" = 'fail'::"text")))::numeric / NULLIF(("count"(*))::numeric, (0)::numeric)) AS "final_fail_rate"
           FROM "final_filtered"
          GROUP BY "final_filtered"."local_id", "final_filtered"."program_id", "final_filtered"."unit_order"
        ), "gaps_union" AS (
         SELECT "practice_filtered"."local_id",
            "practice_filtered"."program_id",
            "practice_filtered"."unit_order",
            "unnest"("practice_filtered"."gaps") AS "gap"
           FROM "practice_filtered"
          WHERE (COALESCE("array_length"("practice_filtered"."gaps", 1), 0) > 0)
        UNION ALL
         SELECT "final_filtered"."local_id",
            "final_filtered"."program_id",
            "final_filtered"."unit_order",
            "unnest"("final_filtered"."gaps") AS "gap"
           FROM "final_filtered"
          WHERE (COALESCE("array_length"("final_filtered"."gaps", 1), 0) > 0)
        ), "top_gap" AS (
         SELECT DISTINCT ON ("gaps_union"."local_id", "gaps_union"."program_id", "gaps_union"."unit_order") "gaps_union"."local_id",
            "gaps_union"."program_id",
            "gaps_union"."unit_order",
            "gaps_union"."gap" AS "top_gap",
            "count"(*) OVER (PARTITION BY "gaps_union"."local_id", "gaps_union"."program_id", "gaps_union"."unit_order", "gaps_union"."gap") AS "gap_count"
           FROM "gaps_union"
          ORDER BY "gaps_union"."local_id", "gaps_union"."program_id", "gaps_union"."unit_order", ("count"(*) OVER (PARTITION BY "gaps_union"."local_id", "gaps_union"."program_id", "gaps_union"."unit_order", "gaps_union"."gap")) DESC, "gaps_union"."gap"
        )
 SELECT COALESCE("p"."local_id", "f"."local_id") AS "local_id",
    COALESCE("p"."program_id", "f"."program_id") AS "program_id",
    COALESCE("p"."unit_order", "f"."unit_order") AS "unit_order",
    "p"."avg_practice_score",
    "f"."avg_final_score",
    "round"(COALESCE("p"."practice_fail_rate", (0)::numeric), 4) AS "practice_fail_rate",
    "round"(COALESCE("f"."final_fail_rate", (0)::numeric), 4) AS "final_fail_rate",
    "tg"."top_gap"
   FROM (("practice_unit" "p"
     FULL JOIN "final_unit" "f" ON ((("f"."local_id" = "p"."local_id") AND ("f"."program_id" = "p"."program_id") AND ("f"."unit_order" = "p"."unit_order"))))
     LEFT JOIN "top_gap" "tg" ON ((("tg"."local_id" = COALESCE("p"."local_id", "f"."local_id")) AND ("tg"."program_id" = COALESCE("p"."program_id", "f"."program_id")) AND ("tg"."unit_order" = COALESCE("p"."unit_order", "f"."unit_order")))));


ALTER VIEW "public"."v_local_unit_coverage_30d" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_org_gap_locals_30d" WITH ("security_barrier"='true') AS
 SELECT "l"."org_id",
    "v"."gap" AS "gap_key",
    "v"."local_id",
    "l"."name" AS "local_name",
    "v"."learners_affected" AS "learners_affected_count",
    "v"."percent_learners_affected" AS "percent_learners_affected_local",
    "v"."count_total" AS "total_events_30d",
    "v"."last_seen_at" AS "last_event_at"
   FROM ("public"."v_local_top_gaps_30d" "v"
     JOIN "public"."locals" "l" ON (("l"."id" = "v"."local_id")))
  WHERE (("public"."current_role"() = ANY (ARRAY['admin_org'::"public"."app_role", 'superadmin'::"public"."app_role"])) AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR ("l"."org_id" = "public"."current_org_id"())));


ALTER VIEW "public"."v_org_gap_locals_30d" OWNER TO "postgres";


COMMENT ON VIEW "public"."v_org_gap_locals_30d" IS 'Post-MVP5 M2: Distribucion de gaps (gap_key) por local en 30d. gap_key proviene de v_local_top_gaps_30d; no hay unit_order.';



CREATE OR REPLACE VIEW "public"."v_org_learner_risk_30d" WITH ("security_barrier"='true') AS
 SELECT "l"."org_id",
    "v"."local_id",
    "v"."learner_id",
    "v"."risk_level",
    ((COALESCE("v"."failed_practice_count", 0) + COALESCE("v"."failed_final_count", 0)) + COALESCE("v"."doubt_signals_count", 0)) AS "risk_score",
    ((COALESCE("v"."failed_practice_count", 0) + COALESCE("v"."failed_final_count", 0)) + COALESCE("v"."doubt_signals_count", 0)) AS "signals_count_30d",
    "v"."last_activity_at" AS "last_signal_at"
   FROM ("public"."v_local_learner_risk_30d" "v"
     JOIN "public"."locals" "l" ON (("l"."id" = "v"."local_id")))
  WHERE (("public"."current_role"() = ANY (ARRAY['admin_org'::"public"."app_role", 'superadmin'::"public"."app_role"])) AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR ("l"."org_id" = "public"."current_org_id"())));


ALTER VIEW "public"."v_org_learner_risk_30d" OWNER TO "postgres";


COMMENT ON VIEW "public"."v_org_learner_risk_30d" IS 'Post-MVP5 M1: Riesgo por aprendiz (30d) agregado a org. risk_score=failed_practice+failed_final+doubt_signals.';



CREATE OR REPLACE VIEW "public"."v_org_local_active_programs" WITH ("security_barrier"='true') AS
 SELECT "l"."id" AS "local_id",
    "l"."org_id",
    "l"."name" AS "local_name",
    "lap"."program_id",
    "tp"."name" AS "program_name",
    "tp"."local_id" AS "program_local_id",
    "tp"."is_active" AS "program_is_active",
    "lap"."created_at" AS "activated_at"
   FROM (("public"."locals" "l"
     JOIN "public"."local_active_programs" "lap" ON (("lap"."local_id" = "l"."id")))
     JOIN "public"."training_programs" "tp" ON (("tp"."id" = "lap"."program_id")));


ALTER VIEW "public"."v_org_local_active_programs" OWNER TO "postgres";


COMMENT ON VIEW "public"."v_org_local_active_programs" IS 'Post-MVP3 B.1: Programa activo por local (local_active_programs + locals + training_programs). Read-only; tenant-scoped por RLS.';



CREATE OR REPLACE VIEW "public"."v_org_program_final_eval_config_current" WITH ("security_barrier"='true') AS
 SELECT "tp"."id" AS "program_id",
    "tp"."org_id",
    "tp"."local_id" AS "program_local_id",
    "tp"."name" AS "program_name",
    "tp"."is_active" AS "program_is_active",
    "fec"."id" AS "config_id",
    "fec"."total_questions",
    "fec"."roleplay_ratio",
    "fec"."min_global_score",
    "fec"."must_pass_units",
    "fec"."questions_per_unit",
    "fec"."max_attempts",
    "fec"."cooldown_hours",
    "fec"."created_at" AS "config_created_at"
   FROM ("public"."training_programs" "tp"
     LEFT JOIN ( SELECT DISTINCT ON ("final_evaluation_configs"."program_id") "final_evaluation_configs"."id",
            "final_evaluation_configs"."program_id",
            "final_evaluation_configs"."total_questions",
            "final_evaluation_configs"."roleplay_ratio",
            "final_evaluation_configs"."min_global_score",
            "final_evaluation_configs"."must_pass_units",
            "final_evaluation_configs"."questions_per_unit",
            "final_evaluation_configs"."max_attempts",
            "final_evaluation_configs"."cooldown_hours",
            "final_evaluation_configs"."created_at"
           FROM "public"."final_evaluation_configs"
          ORDER BY "final_evaluation_configs"."program_id", "final_evaluation_configs"."created_at" DESC) "fec" ON (("fec"."program_id" = "tp"."id")));


ALTER VIEW "public"."v_org_program_final_eval_config_current" OWNER TO "postgres";


COMMENT ON VIEW "public"."v_org_program_final_eval_config_current" IS 'Post-MVP3 B.1: Config vigente de evaluacion final por programa (latest by created_at). Read-only; tenant-scoped por RLS de tablas base.';



CREATE OR REPLACE VIEW "public"."v_org_program_final_eval_config_history" WITH ("security_barrier"='true') AS
 SELECT "tp"."id" AS "program_id",
    "tp"."org_id",
    "tp"."local_id" AS "program_local_id",
    "tp"."name" AS "program_name",
    "tp"."is_active" AS "program_is_active",
    "fec"."id" AS "config_id",
    "fec"."total_questions",
    "fec"."roleplay_ratio",
    "fec"."min_global_score",
    "fec"."must_pass_units",
    "fec"."questions_per_unit",
    "fec"."max_attempts",
    "fec"."cooldown_hours",
    "fec"."created_at" AS "config_created_at"
   FROM ("public"."final_evaluation_configs" "fec"
     JOIN "public"."training_programs" "tp" ON (("tp"."id" = "fec"."program_id")))
  ORDER BY "tp"."id", "fec"."created_at" DESC;


ALTER VIEW "public"."v_org_program_final_eval_config_history" OWNER TO "postgres";


COMMENT ON VIEW "public"."v_org_program_final_eval_config_history" IS 'Post-MVP3 B.1: Historial completo de configs de evaluacion final por programa. Read-only; tenant-scoped por RLS.';



CREATE OR REPLACE VIEW "public"."v_org_program_unit_knowledge_coverage" WITH ("security_barrier"='true') AS
 SELECT "tp"."id" AS "program_id",
    "tp"."name" AS "program_name",
    "tu"."id" AS "unit_id",
    "tu"."unit_order",
    "tu"."title" AS "unit_title",
    "count"("ki"."id") AS "total_knowledge_count",
    "count"("ki"."id") FILTER (WHERE ("ki"."local_id" IS NULL)) AS "org_level_knowledge_count",
    "count"("ki"."id") FILTER (WHERE (("tp"."local_id" IS NOT NULL) AND ("ki"."local_id" = "tp"."local_id"))) AS "local_level_knowledge_count",
    ("count"("ki"."id") > 0) AS "has_any_mapping",
    ("count"("ki"."id") = 0) AS "is_missing_mapping"
   FROM ((("public"."training_programs" "tp"
     JOIN "public"."training_units" "tu" ON (("tu"."program_id" = "tp"."id")))
     LEFT JOIN "public"."unit_knowledge_map" "ukm" ON (("ukm"."unit_id" = "tu"."id")))
     LEFT JOIN "public"."knowledge_items" "ki" ON ((("ki"."id" = "ukm"."knowledge_id") AND ("ki"."is_enabled" = true))))
  WHERE ("public"."current_role"() = ANY (ARRAY['admin_org'::"public"."app_role", 'superadmin'::"public"."app_role", 'referente'::"public"."app_role"]))
  GROUP BY "tp"."id", "tp"."name", "tu"."id", "tu"."unit_order", "tu"."title"
  ORDER BY "tp"."id", "tu"."unit_order";


ALTER VIEW "public"."v_org_program_unit_knowledge_coverage" OWNER TO "postgres";


COMMENT ON VIEW "public"."v_org_program_unit_knowledge_coverage" IS 'Post-MVP4 K3: Coverage de knowledge por unidad (filtra is_enabled=true). local_level_knowledge_count solo se computa si training_programs.local_id no es NULL; para programas org-level se reporta 0.';



CREATE OR REPLACE VIEW "public"."v_org_program_knowledge_gaps_summary" WITH ("security_barrier"='true') AS
 SELECT "program_id",
    "program_name",
    ("count"(*))::integer AS "total_units",
    ("count"(*) FILTER (WHERE "is_missing_mapping"))::integer AS "units_missing_mapping",
        CASE
            WHEN ("count"(*) = 0) THEN (0)::numeric
            ELSE "round"(((("count"(*) FILTER (WHERE "is_missing_mapping"))::numeric / ("count"(*))::numeric) * (100)::numeric), 2)
        END AS "pct_units_missing_mapping",
    ("sum"("total_knowledge_count"))::integer AS "total_knowledge_mappings"
   FROM "public"."v_org_program_unit_knowledge_coverage"
  WHERE ("public"."current_role"() = ANY (ARRAY['admin_org'::"public"."app_role", 'superadmin'::"public"."app_role", 'referente'::"public"."app_role"]))
  GROUP BY "program_id", "program_name";


ALTER VIEW "public"."v_org_program_knowledge_gaps_summary" OWNER TO "postgres";


COMMENT ON VIEW "public"."v_org_program_knowledge_gaps_summary" IS 'Post-MVP4 K3: Resumen de gaps por programa (unidades, gaps, % gaps, mappings totales).';



CREATE OR REPLACE VIEW "public"."v_org_top_gaps_30d" WITH ("security_barrier"='true') AS
 WITH "org_learners" AS (
         SELECT "l_1"."org_id",
            "count"(DISTINCT "lt"."learner_id") AS "learners_count"
           FROM ("public"."learner_trainings" "lt"
             JOIN "public"."locals" "l_1" ON (("l_1"."id" = "lt"."local_id")))
          WHERE ("lt"."updated_at" >= ("now"() - '30 days'::interval))
          GROUP BY "l_1"."org_id"
        )
 SELECT "l"."org_id",
    "v"."gap" AS "gap_key",
    NULL::integer AS "unit_order",
    "v"."gap" AS "title",
    "sum"("v"."learners_affected") AS "learners_affected_count",
        CASE
            WHEN (COALESCE("ol"."learners_count", (0)::bigint) = 0) THEN (0)::numeric
            ELSE "round"(((("sum"("v"."learners_affected"))::numeric / ("ol"."learners_count")::numeric) * (100)::numeric), 2)
        END AS "percent_learners_affected",
    "sum"("v"."count_total") AS "total_fail_events",
    30 AS "window_days"
   FROM (("public"."v_local_top_gaps_30d" "v"
     JOIN "public"."locals" "l" ON (("l"."id" = "v"."local_id")))
     LEFT JOIN "org_learners" "ol" ON (("ol"."org_id" = "l"."org_id")))
  WHERE (("public"."current_role"() = ANY (ARRAY['admin_org'::"public"."app_role", 'superadmin'::"public"."app_role"])) AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR ("l"."org_id" = "public"."current_org_id"())))
  GROUP BY "l"."org_id", "v"."gap", "ol"."learners_count"
  ORDER BY ("sum"("v"."count_total")) DESC;


ALTER VIEW "public"."v_org_top_gaps_30d" OWNER TO "postgres";


COMMENT ON VIEW "public"."v_org_top_gaps_30d" IS 'Post-MVP5 M1: Top gaps por org (ventana 30d). Deriva de v_local_top_gaps_30d; percent_learners_affected usa learners_count en 30d por org.';



CREATE OR REPLACE VIEW "public"."v_org_unit_coverage_30d" WITH ("security_barrier"='true') AS
 SELECT "l"."org_id",
    "v"."local_id",
    "l"."name" AS "local_name",
    "v"."program_id",
    "v"."unit_order",
        CASE
            WHEN (("v"."practice_fail_rate" IS NULL) AND ("v"."final_fail_rate" IS NULL)) THEN NULL::numeric
            ELSE "round"((((1)::numeric - ((COALESCE("v"."practice_fail_rate", (0)::numeric) + COALESCE("v"."final_fail_rate", (0)::numeric)) / (2)::numeric)) * (100)::numeric), 2)
        END AS "coverage_percent",
    ( SELECT "count"(DISTINCT "lt"."learner_id") AS "count"
           FROM "public"."learner_trainings" "lt"
          WHERE (("lt"."local_id" = "v"."local_id") AND ("lt"."program_id" = "v"."program_id") AND ("lt"."updated_at" >= ("now"() - '30 days'::interval)))) AS "learners_active_count",
    ( SELECT "count"(DISTINCT "evidence"."learner_id") AS "count"
           FROM ( SELECT "pa"."learner_id"
                   FROM ("public"."practice_attempts" "pa"
                     JOIN "public"."practice_scenarios" "ps" ON (("ps"."id" = "pa"."scenario_id")))
                  WHERE (("pa"."local_id" = "v"."local_id") AND ("ps"."program_id" = "v"."program_id") AND ("ps"."unit_order" = "v"."unit_order") AND ("pa"."started_at" >= ("now"() - '30 days'::interval)))
                UNION
                 SELECT "a"."learner_id"
                   FROM ((("public"."final_evaluation_evaluations" "ev"
                     JOIN "public"."final_evaluation_answers" "ans" ON (("ans"."id" = "ev"."answer_id")))
                     JOIN "public"."final_evaluation_questions" "q" ON (("q"."id" = "ans"."question_id")))
                     JOIN "public"."final_evaluation_attempts" "a" ON (("a"."id" = "q"."attempt_id")))
                  WHERE (("a"."program_id" = "v"."program_id") AND ("q"."unit_order" = "v"."unit_order") AND ("ev"."created_at" >= ("now"() - '30 days'::interval)))) "evidence") AS "learners_with_evidence_count",
    ( SELECT GREATEST(( SELECT "max"("pa"."started_at") AS "max"
                   FROM ("public"."practice_attempts" "pa"
                     JOIN "public"."practice_scenarios" "ps" ON (("ps"."id" = "pa"."scenario_id")))
                  WHERE (("pa"."local_id" = "v"."local_id") AND ("ps"."program_id" = "v"."program_id") AND ("ps"."unit_order" = "v"."unit_order"))), ( SELECT "max"("ev"."created_at") AS "max"
                   FROM ((("public"."final_evaluation_evaluations" "ev"
                     JOIN "public"."final_evaluation_answers" "ans" ON (("ans"."id" = "ev"."answer_id")))
                     JOIN "public"."final_evaluation_questions" "q" ON (("q"."id" = "ans"."question_id")))
                     JOIN "public"."final_evaluation_attempts" "a" ON (("a"."id" = "q"."attempt_id")))
                  WHERE (("a"."program_id" = "v"."program_id") AND ("q"."unit_order" = "v"."unit_order")))) AS "greatest") AS "last_activity_at"
   FROM ("public"."v_local_unit_coverage_30d" "v"
     JOIN "public"."locals" "l" ON (("l"."id" = "v"."local_id")))
  WHERE (("public"."current_role"() = ANY (ARRAY['admin_org'::"public"."app_role", 'superadmin'::"public"."app_role"])) AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR ("l"."org_id" = "public"."current_org_id"())));


ALTER VIEW "public"."v_org_unit_coverage_30d" OWNER TO "postgres";


COMMENT ON VIEW "public"."v_org_unit_coverage_30d" IS 'Post-MVP5 M1: Cobertura por unidad (30d) agregada por org. coverage_percent deriva de fail rates promedio.';



CREATE OR REPLACE VIEW "public"."v_org_recommended_actions_30d" WITH ("security_barrier"='true') AS
 WITH "ranked_gaps" AS (
         SELECT "v_org_top_gaps_30d"."org_id",
            "v_org_top_gaps_30d"."gap_key",
            "v_org_top_gaps_30d"."learners_affected_count",
            "v_org_top_gaps_30d"."percent_learners_affected",
            "v_org_top_gaps_30d"."total_fail_events",
            "row_number"() OVER (PARTITION BY "v_org_top_gaps_30d"."org_id" ORDER BY "v_org_top_gaps_30d"."total_fail_events" DESC) AS "gap_rank"
           FROM "public"."v_org_top_gaps_30d"
          WHERE (("v_org_top_gaps_30d"."percent_learners_affected" >= (25)::numeric) OR ("v_org_top_gaps_30d"."learners_affected_count" >= 3))
        ), "ranked_coverage" AS (
         SELECT "v_org_unit_coverage_30d"."org_id",
            "v_org_unit_coverage_30d"."local_id",
            "v_org_unit_coverage_30d"."program_id",
            "v_org_unit_coverage_30d"."unit_order",
            "v_org_unit_coverage_30d"."coverage_percent",
            "v_org_unit_coverage_30d"."learners_active_count",
            "row_number"() OVER (PARTITION BY "v_org_unit_coverage_30d"."org_id" ORDER BY "v_org_unit_coverage_30d"."coverage_percent") AS "coverage_rank"
           FROM "public"."v_org_unit_coverage_30d"
          WHERE (("v_org_unit_coverage_30d"."coverage_percent" IS NOT NULL) AND ("v_org_unit_coverage_30d"."coverage_percent" < (60)::numeric) AND (COALESCE("v_org_unit_coverage_30d"."learners_active_count", (0)::bigint) >= 2))
        ), "ranked_risk" AS (
         SELECT "v_org_learner_risk_30d"."org_id",
            "v_org_learner_risk_30d"."local_id",
            "v_org_learner_risk_30d"."learner_id",
            "v_org_learner_risk_30d"."risk_level",
            "v_org_learner_risk_30d"."last_signal_at",
            "row_number"() OVER (PARTITION BY "v_org_learner_risk_30d"."org_id" ORDER BY
                CASE "v_org_learner_risk_30d"."risk_level"
                    WHEN 'high'::"text" THEN 1
                    WHEN 'medium'::"text" THEN 2
                    ELSE 3
                END, "v_org_learner_risk_30d"."last_signal_at" DESC NULLS LAST) AS "risk_rank"
           FROM "public"."v_org_learner_risk_30d"
          WHERE ("v_org_learner_risk_30d"."risk_level" = ANY (ARRAY['high'::"text", 'medium'::"text"]))
        )
 SELECT "org_id",
    "action_key",
    "priority",
    "title",
    "reason",
    "evidence",
    "cta_label",
    "cta_href",
    "now"() AS "created_at"
   FROM ( SELECT "g"."org_id",
            'top_gap'::"text" AS "action_key",
            (90 - ("g"."gap_rank" * 5)) AS "priority",
            'Gap con alto impacto'::"text" AS "title",
            (('% learners afectados por "'::"text" || "g"."gap_key") || '"'::"text") AS "reason",
            "jsonb_build_object"('gap_key', "g"."gap_key", 'learners_affected_count', "g"."learners_affected_count", 'percent_learners_affected', "g"."percent_learners_affected") AS "evidence",
            'Ver gaps'::"text" AS "cta_label",
            ('/org/metrics/gaps/'::"text" || "g"."gap_key") AS "cta_href"
           FROM "ranked_gaps" "g"
        UNION ALL
         SELECT "c"."org_id",
            'low_coverage'::"text" AS "action_key",
            (80 - ("c"."coverage_rank" * 5)) AS "priority",
            'Cobertura baja en unidad'::"text" AS "title",
            (('Cobertura '::"text" || "round"("c"."coverage_percent", 1)) || '% con learners activos'::"text") AS "reason",
            "jsonb_build_object"('local_id', "c"."local_id", 'program_id', "c"."program_id", 'unit_order', "c"."unit_order", 'coverage_percent', "c"."coverage_percent") AS "evidence",
            'Abrir cobertura'::"text" AS "cta_label",
            ((('/org/metrics/coverage/'::"text" || "c"."program_id") || '/'::"text") || "c"."unit_order") AS "cta_href"
           FROM "ranked_coverage" "c"
        UNION ALL
         SELECT "r"."org_id",
            'learner_risk'::"text" AS "action_key",
            (70 - ("r"."risk_rank" * 3)) AS "priority",
            'Learner en riesgo'::"text" AS "title",
            ('Riesgo '::"text" || "r"."risk_level") AS "reason",
            "jsonb_build_object"('learner_id', "r"."learner_id", 'local_id', "r"."local_id", 'risk_level', "r"."risk_level", 'last_signal_at', "r"."last_signal_at") AS "evidence",
            'Revisar learner'::"text" AS "cta_label",
            ('/referente/review/'::"text" || "r"."learner_id") AS "cta_href"
           FROM "ranked_risk" "r") "actions"
  WHERE (("public"."current_role"() = ANY (ARRAY['admin_org'::"public"."app_role", 'superadmin'::"public"."app_role"])) AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR ("org_id" = "public"."current_org_id"())))
  ORDER BY "priority" DESC
 LIMIT 10;


ALTER VIEW "public"."v_org_recommended_actions_30d" OWNER TO "postgres";


COMMENT ON VIEW "public"."v_org_recommended_actions_30d" IS 'Post-MVP5 M3: Acciones sugeridas (30d) para Admin Org. Combina gaps, cobertura baja y learners en riesgo; read-only.';



CREATE OR REPLACE VIEW "public"."v_org_recommended_actions_playbooks_30d" WITH ("security_barrier"='true') AS
 SELECT "org_id",
    "action_key",
    "priority",
    "title",
    "reason",
    "evidence",
    "cta_label",
    "cta_href",
        CASE "action_key"
            WHEN 'top_gap'::"text" THEN ARRAY['Abrí el gap y revisá en qué locales pega más.'::"text", 'Revisá cobertura de knowledge de la unidad asociada (si aplica) y completá faltantes.'::"text", 'Revisá si hay knowledge desactualizado y desactivalo.'::"text", 'Pedí al referente revisar conversaciones de 2–3 aprendices afectados.'::"text"]
            WHEN 'low_coverage'::"text" THEN ARRAY['Abrí la unidad/local con baja cobertura.'::"text", 'Confirmá si falta knowledge mapeado o si está deshabilitado.'::"text", 'Agregá knowledge faltante con el wizard (si corresponde).'::"text", 'Monitoreá la cobertura en 24–48h.'::"text"]
            WHEN 'learner_risk'::"text" THEN ARRAY['Abrí el detalle del aprendiz y revisá evidencia (errores y señales).'::"text", 'Si corresponde, pedí refuerzo con decisión humana.'::"text", 'Verificá si el programa activo del local está bien asignado.'::"text"]
            ELSE ARRAY['Revisá el detalle y validá si requiere intervención.'::"text"]
        END AS "checklist",
        CASE "action_key"
            WHEN 'top_gap'::"text" THEN 'Reducir este gap suele mejorar respuestas en escenarios reales y bajar revisiones.'::"text"
            WHEN 'low_coverage'::"text" THEN 'Más cobertura suele reducir dudas y respuestas incompletas.'::"text"
            WHEN 'learner_risk'::"text" THEN 'Intervenir temprano reduce el tiempo en revisión y mejora consistencia.'::"text"
            ELSE 'Acción sugerida para mantener operación estable.'::"text"
        END AS "impact_note",
        CASE "action_key"
            WHEN 'top_gap'::"text" THEN "jsonb_build_array"("jsonb_build_object"('label', 'Ver gap por local', 'href', "cta_href"), "jsonb_build_object"('label', 'Cobertura de conocimiento', 'href', '/org/config/knowledge-coverage'), "jsonb_build_object"('label', 'Configuración evaluación final', 'href', '/org/config/bot'))
            WHEN 'low_coverage'::"text" THEN "jsonb_build_array"("jsonb_build_object"('label', 'Abrir detalle cobertura', 'href', "cta_href"), "jsonb_build_object"('label', 'Cobertura de conocimiento', 'href', '/org/config/knowledge-coverage'))
            WHEN 'learner_risk'::"text" THEN "jsonb_build_array"("jsonb_build_object"('label', 'Abrir revisión del aprendiz', 'href', "cta_href"), "jsonb_build_object"('label', 'Programa activo por local', 'href', '/org/config/locals-program'))
            ELSE "jsonb_build_array"()
        END AS "secondary_links",
    "created_at"
   FROM "public"."v_org_recommended_actions_30d" "a"
  WHERE (("public"."current_role"() = ANY (ARRAY['admin_org'::"public"."app_role", 'superadmin'::"public"."app_role"])) AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR ("org_id" = "public"."current_org_id"())));


ALTER VIEW "public"."v_org_recommended_actions_playbooks_30d" OWNER TO "postgres";


COMMENT ON VIEW "public"."v_org_recommended_actions_playbooks_30d" IS 'Post-MVP5 M4: Playbooks determinísticos para acciones sugeridas (checklist, impacto, links secundarios).';



CREATE OR REPLACE VIEW "public"."v_org_unit_knowledge_active" WITH ("security_barrier"='true') AS
 SELECT "tp"."org_id",
    "tp"."id" AS "program_id",
    "tp"."name" AS "program_name",
    "tu"."id" AS "unit_id",
    "tu"."unit_order",
    "tu"."title" AS "unit_title",
    "ki"."id" AS "knowledge_id",
    "ki"."title" AS "knowledge_title",
        CASE
            WHEN ("ki"."local_id" IS NULL) THEN 'org'::"text"
            ELSE 'local'::"text"
        END AS "knowledge_scope",
    "ki"."created_at" AS "knowledge_created_at"
   FROM ((("public"."training_units" "tu"
     JOIN "public"."training_programs" "tp" ON (("tp"."id" = "tu"."program_id")))
     JOIN "public"."unit_knowledge_map" "ukm" ON (("ukm"."unit_id" = "tu"."id")))
     JOIN "public"."knowledge_items" "ki" ON (("ki"."id" = "ukm"."knowledge_id")))
  WHERE (("ki"."is_enabled" = true) AND ("public"."current_role"() = ANY (ARRAY['admin_org'::"public"."app_role", 'superadmin'::"public"."app_role"])) AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR ("tp"."org_id" = "public"."current_org_id"())));


ALTER VIEW "public"."v_org_unit_knowledge_active" OWNER TO "postgres";


COMMENT ON VIEW "public"."v_org_unit_knowledge_active" IS 'Post-MVP5 M2: Knowledge activo por unidad (org-scoped). Filtra is_enabled=true; scope deriva de knowledge_items.local_id.';



CREATE OR REPLACE VIEW "public"."v_org_unit_knowledge_list" WITH ("security_barrier"='true') AS
 SELECT "tp"."id" AS "program_id",
    "tp"."name" AS "program_name",
    "tu"."id" AS "unit_id",
    "tu"."unit_order",
    "ki"."id" AS "knowledge_id",
    "ki"."title" AS "knowledge_title",
        CASE
            WHEN ("ki"."local_id" IS NULL) THEN 'org'::"text"
            ELSE 'local'::"text"
        END AS "knowledge_scope",
    "ki"."created_at" AS "knowledge_created_at"
   FROM ((("public"."training_programs" "tp"
     JOIN "public"."training_units" "tu" ON (("tu"."program_id" = "tp"."id")))
     JOIN "public"."unit_knowledge_map" "ukm" ON (("ukm"."unit_id" = "tu"."id")))
     JOIN "public"."knowledge_items" "ki" ON (("ki"."id" = "ukm"."knowledge_id")))
  WHERE (("public"."current_role"() = ANY (ARRAY['admin_org'::"public"."app_role", 'superadmin'::"public"."app_role", 'referente'::"public"."app_role"])) AND ("ki"."is_enabled" = true))
  ORDER BY "tp"."id", "tu"."unit_order", "ki"."created_at" DESC;


ALTER VIEW "public"."v_org_unit_knowledge_list" OWNER TO "postgres";


COMMENT ON VIEW "public"."v_org_unit_knowledge_list" IS 'Post-MVP4 K3: Knowledge asociado por unidad (drill-down, read-only, filtra is_enabled=true).';



CREATE OR REPLACE VIEW "public"."v_referente_conversation_summary" AS
 SELECT "c"."id" AS "conversation_id",
    "c"."learner_id",
    "p"."full_name",
    "c"."unit_order",
    "max"("cm"."created_at") AS "last_message_at",
    ("count"("cm"."id"))::integer AS "total_messages"
   FROM (("public"."conversations" "c"
     JOIN "public"."profiles" "p" ON (("p"."user_id" = "c"."learner_id")))
     LEFT JOIN "public"."conversation_messages" "cm" ON (("cm"."conversation_id" = "c"."id")))
  WHERE ("p"."role" = 'aprendiz'::"public"."app_role")
  GROUP BY "c"."id", "c"."learner_id", "p"."full_name", "c"."unit_order";


ALTER VIEW "public"."v_referente_conversation_summary" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_referente_learners" AS
 SELECT "p"."user_id" AS "learner_id",
    "p"."full_name",
    "lt"."status",
    "lt"."progress_percent",
    "lt"."current_unit_order",
    "lt"."updated_at"
   FROM ("public"."learner_trainings" "lt"
     JOIN "public"."profiles" "p" ON (("p"."user_id" = "lt"."learner_id")))
  WHERE ("p"."role" = 'aprendiz'::"public"."app_role");


ALTER VIEW "public"."v_referente_learners" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_referente_practice_summary" AS
 SELECT "pa"."learner_id",
    "pa"."id" AS "attempt_id",
    "ps"."title" AS "scenario_title",
    "pe"."score",
    "pe"."verdict",
    "pe"."created_at"
   FROM (("public"."practice_attempts" "pa"
     JOIN "public"."practice_scenarios" "ps" ON (("ps"."id" = "pa"."scenario_id")))
     LEFT JOIN LATERAL ( SELECT "eval"."score",
            "eval"."verdict",
            "eval"."created_at"
           FROM "public"."practice_evaluations" "eval"
          WHERE ("eval"."attempt_id" = "pa"."id")
          ORDER BY "eval"."created_at" DESC
         LIMIT 1) "pe" ON (true));


ALTER VIEW "public"."v_referente_practice_summary" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_review_queue" AS
 SELECT "lt"."learner_id",
    "p"."full_name",
    "lt"."local_id",
    "lt"."status",
    "lt"."progress_percent",
    GREATEST(COALESCE("msgs"."last_message_at", "lt"."updated_at"), COALESCE("pract"."last_practice_at", "lt"."updated_at"), "lt"."updated_at") AS "last_activity_at",
    (EXISTS ( SELECT 1
           FROM ("public"."practice_evaluations" "pe"
             JOIN "public"."practice_attempts" "pa" ON (("pa"."id" = "pe"."attempt_id")))
          WHERE (("pa"."learner_id" = "lt"."learner_id") AND (("pe"."verdict" = 'fail'::"text") OR (COALESCE("array_length"("pe"."doubt_signals", 1), 0) > 0))))) AS "has_doubt_signals",
    (EXISTS ( SELECT 1
           FROM ("public"."practice_evaluations" "pe"
             JOIN "public"."practice_attempts" "pa" ON (("pa"."id" = "pe"."attempt_id")))
          WHERE (("pa"."learner_id" = "lt"."learner_id") AND ("pe"."verdict" = 'fail'::"text")))) AS "has_failed_practice"
   FROM ((("public"."learner_trainings" "lt"
     JOIN "public"."profiles" "p" ON (("p"."user_id" = "lt"."learner_id")))
     LEFT JOIN LATERAL ( SELECT "max"("cm"."created_at") AS "last_message_at"
           FROM ("public"."conversation_messages" "cm"
             JOIN "public"."conversations" "c" ON (("c"."id" = "cm"."conversation_id")))
          WHERE ("c"."learner_id" = "lt"."learner_id")) "msgs" ON (true))
     LEFT JOIN LATERAL ( SELECT "max"("pe"."created_at") AS "last_practice_at"
           FROM ("public"."practice_evaluations" "pe"
             JOIN "public"."practice_attempts" "pa" ON (("pa"."id" = "pe"."attempt_id")))
          WHERE ("pa"."learner_id" = "lt"."learner_id")) "pract" ON (true))
  WHERE ("lt"."status" = 'en_revision'::"public"."learner_status");


ALTER VIEW "public"."v_review_queue" OWNER TO "postgres";


ALTER TABLE ONLY "public"."alert_events"
    ADD CONSTRAINT "alert_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bot_message_evaluations"
    ADD CONSTRAINT "bot_message_evaluations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."conversation_messages"
    ADD CONSTRAINT "conversation_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."final_evaluation_answers"
    ADD CONSTRAINT "final_evaluation_answers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."final_evaluation_attempts"
    ADD CONSTRAINT "final_evaluation_attempts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."final_evaluation_attempts"
    ADD CONSTRAINT "final_evaluation_attempts_unique" UNIQUE ("learner_id", "attempt_number");



ALTER TABLE ONLY "public"."final_evaluation_configs"
    ADD CONSTRAINT "final_evaluation_configs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."final_evaluation_evaluations"
    ADD CONSTRAINT "final_evaluation_evaluations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."final_evaluation_questions"
    ADD CONSTRAINT "final_evaluation_questions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."knowledge_change_events"
    ADD CONSTRAINT "knowledge_change_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."knowledge_items"
    ADD CONSTRAINT "knowledge_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."learner_future_questions"
    ADD CONSTRAINT "learner_future_questions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."learner_review_decisions"
    ADD CONSTRAINT "learner_review_decisions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."learner_review_validations_v2"
    ADD CONSTRAINT "learner_review_validations_v2_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."learner_state_transitions"
    ADD CONSTRAINT "learner_state_transitions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."learner_trainings"
    ADD CONSTRAINT "learner_trainings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."learner_trainings"
    ADD CONSTRAINT "learner_trainings_unique_learner" UNIQUE ("learner_id");



ALTER TABLE ONLY "public"."local_active_program_change_events"
    ADD CONSTRAINT "local_active_program_change_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."local_active_programs"
    ADD CONSTRAINT "local_active_programs_pkey" PRIMARY KEY ("local_id");



ALTER TABLE ONLY "public"."locals"
    ADD CONSTRAINT "locals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_emails"
    ADD CONSTRAINT "notification_emails_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_emails"
    ADD CONSTRAINT "notification_emails_unique_decision" UNIQUE ("decision_id", "email_type");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."practice_attempt_events"
    ADD CONSTRAINT "practice_attempt_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."practice_attempts"
    ADD CONSTRAINT "practice_attempts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."practice_evaluations"
    ADD CONSTRAINT "practice_evaluations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."practice_scenarios"
    ADD CONSTRAINT "practice_scenarios_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."training_programs"
    ADD CONSTRAINT "training_programs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."training_units"
    ADD CONSTRAINT "training_units_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."training_units"
    ADD CONSTRAINT "training_units_program_order_unique" UNIQUE ("program_id", "unit_order");



ALTER TABLE ONLY "public"."unit_knowledge_map"
    ADD CONSTRAINT "unit_knowledge_map_pkey" PRIMARY KEY ("unit_id", "knowledge_id");



CREATE INDEX "alert_events_learner_created_at_idx" ON "public"."alert_events" USING "btree" ("learner_id", "created_at" DESC);



CREATE INDEX "alert_events_local_created_at_idx" ON "public"."alert_events" USING "btree" ("local_id", "created_at" DESC);



CREATE INDEX "alert_events_org_created_at_idx" ON "public"."alert_events" USING "btree" ("org_id", "created_at" DESC);



CREATE INDEX "alert_events_type_created_at_idx" ON "public"."alert_events" USING "btree" ("alert_type", "created_at" DESC);



CREATE INDEX "bot_message_evaluations_created_at_idx" ON "public"."bot_message_evaluations" USING "btree" ("created_at");



CREATE INDEX "bot_message_evaluations_message_id_idx" ON "public"."bot_message_evaluations" USING "btree" ("message_id");



CREATE INDEX "conversation_messages_conversation_id_idx" ON "public"."conversation_messages" USING "btree" ("conversation_id");



CREATE INDEX "conversation_messages_created_at_idx" ON "public"."conversation_messages" USING "btree" ("created_at");



CREATE INDEX "conversations_learner_id_idx" ON "public"."conversations" USING "btree" ("learner_id");



CREATE INDEX "conversations_local_id_idx" ON "public"."conversations" USING "btree" ("local_id");



CREATE INDEX "conversations_program_id_idx" ON "public"."conversations" USING "btree" ("program_id");



CREATE INDEX "final_evaluation_answers_created_at_idx" ON "public"."final_evaluation_answers" USING "btree" ("created_at");



CREATE INDEX "final_evaluation_answers_question_id_idx" ON "public"."final_evaluation_answers" USING "btree" ("question_id");



CREATE INDEX "final_evaluation_attempts_created_at_idx" ON "public"."final_evaluation_attempts" USING "btree" ("created_at");



CREATE INDEX "final_evaluation_attempts_learner_id_idx" ON "public"."final_evaluation_attempts" USING "btree" ("learner_id");



CREATE INDEX "final_evaluation_attempts_program_id_idx" ON "public"."final_evaluation_attempts" USING "btree" ("program_id");



CREATE INDEX "final_evaluation_configs_program_id_idx" ON "public"."final_evaluation_configs" USING "btree" ("program_id");



CREATE INDEX "final_evaluation_evaluations_answer_id_idx" ON "public"."final_evaluation_evaluations" USING "btree" ("answer_id");



CREATE INDEX "final_evaluation_evaluations_created_at_idx" ON "public"."final_evaluation_evaluations" USING "btree" ("created_at");



CREATE INDEX "final_evaluation_evaluations_unit_order_idx" ON "public"."final_evaluation_evaluations" USING "btree" ("unit_order");



CREATE INDEX "final_evaluation_questions_attempt_id_idx" ON "public"."final_evaluation_questions" USING "btree" ("attempt_id");



CREATE INDEX "final_evaluation_questions_unit_order_idx" ON "public"."final_evaluation_questions" USING "btree" ("unit_order");



CREATE INDEX "knowledge_change_events_created_at_idx" ON "public"."knowledge_change_events" USING "btree" ("created_at" DESC);



CREATE INDEX "knowledge_change_events_program_id_idx" ON "public"."knowledge_change_events" USING "btree" ("program_id");



CREATE INDEX "knowledge_change_events_unit_id_idx" ON "public"."knowledge_change_events" USING "btree" ("unit_id");



CREATE INDEX "knowledge_items_local_id_idx" ON "public"."knowledge_items" USING "btree" ("local_id");



CREATE INDEX "knowledge_items_org_id_idx" ON "public"."knowledge_items" USING "btree" ("org_id");



CREATE INDEX "learner_future_questions_learner_created_idx" ON "public"."learner_future_questions" USING "btree" ("learner_id", "created_at" DESC);



CREATE INDEX "learner_future_questions_local_created_idx" ON "public"."learner_future_questions" USING "btree" ("local_id", "created_at" DESC);



CREATE INDEX "learner_future_questions_program_created_idx" ON "public"."learner_future_questions" USING "btree" ("program_id", "created_at" DESC);



CREATE INDEX "learner_review_decisions_created_at_idx" ON "public"."learner_review_decisions" USING "btree" ("created_at");



CREATE INDEX "learner_review_decisions_learner_id_idx" ON "public"."learner_review_decisions" USING "btree" ("learner_id");



CREATE INDEX "learner_review_decisions_reviewer_id_idx" ON "public"."learner_review_decisions" USING "btree" ("reviewer_id");



CREATE INDEX "learner_review_validations_v2_decision_created_at_idx" ON "public"."learner_review_validations_v2" USING "btree" ("decision_type", "created_at" DESC);



CREATE INDEX "learner_review_validations_v2_learner_created_at_idx" ON "public"."learner_review_validations_v2" USING "btree" ("learner_id", "created_at" DESC);



CREATE INDEX "learner_review_validations_v2_local_created_at_idx" ON "public"."learner_review_validations_v2" USING "btree" ("local_id", "created_at" DESC);



CREATE INDEX "learner_review_validations_v2_program_created_at_idx" ON "public"."learner_review_validations_v2" USING "btree" ("program_id", "created_at" DESC);



CREATE INDEX "learner_state_transitions_created_at_idx" ON "public"."learner_state_transitions" USING "btree" ("created_at");



CREATE INDEX "learner_state_transitions_learner_id_idx" ON "public"."learner_state_transitions" USING "btree" ("learner_id");



CREATE INDEX "learner_state_transitions_to_status_idx" ON "public"."learner_state_transitions" USING "btree" ("to_status");



CREATE INDEX "learner_trainings_local_id_idx" ON "public"."learner_trainings" USING "btree" ("local_id");



CREATE INDEX "learner_trainings_program_id_idx" ON "public"."learner_trainings" USING "btree" ("program_id");



CREATE INDEX "learner_trainings_status_idx" ON "public"."learner_trainings" USING "btree" ("status");



CREATE INDEX "local_active_program_change_events_created_at_idx" ON "public"."local_active_program_change_events" USING "btree" ("created_at" DESC);



CREATE INDEX "local_active_program_change_events_local_id_idx" ON "public"."local_active_program_change_events" USING "btree" ("local_id");



CREATE INDEX "locals_org_id_idx" ON "public"."locals" USING "btree" ("org_id");



CREATE INDEX "notification_emails_created_at_idx" ON "public"."notification_emails" USING "btree" ("created_at");



CREATE INDEX "notification_emails_decision_id_idx" ON "public"."notification_emails" USING "btree" ("decision_id");



CREATE INDEX "notification_emails_learner_id_idx" ON "public"."notification_emails" USING "btree" ("learner_id");



CREATE INDEX "practice_attempt_events_attempt_id_idx" ON "public"."practice_attempt_events" USING "btree" ("attempt_id");



CREATE INDEX "practice_attempt_events_created_at_idx" ON "public"."practice_attempt_events" USING "btree" ("created_at");



CREATE INDEX "practice_attempts_conversation_id_idx" ON "public"."practice_attempts" USING "btree" ("conversation_id");



CREATE INDEX "practice_attempts_learner_id_idx" ON "public"."practice_attempts" USING "btree" ("learner_id");



CREATE INDEX "practice_attempts_local_id_idx" ON "public"."practice_attempts" USING "btree" ("local_id");



CREATE INDEX "practice_attempts_scenario_id_idx" ON "public"."practice_attempts" USING "btree" ("scenario_id");



CREATE INDEX "practice_evaluations_attempt_id_idx" ON "public"."practice_evaluations" USING "btree" ("attempt_id");



CREATE INDEX "practice_evaluations_created_at_idx" ON "public"."practice_evaluations" USING "btree" ("created_at");



CREATE INDEX "practice_evaluations_learner_message_id_idx" ON "public"."practice_evaluations" USING "btree" ("learner_message_id");



CREATE INDEX "practice_scenarios_local_id_idx" ON "public"."practice_scenarios" USING "btree" ("local_id");



CREATE INDEX "practice_scenarios_org_id_idx" ON "public"."practice_scenarios" USING "btree" ("org_id");



CREATE INDEX "practice_scenarios_program_id_idx" ON "public"."practice_scenarios" USING "btree" ("program_id");



CREATE INDEX "practice_scenarios_program_unit_idx" ON "public"."practice_scenarios" USING "btree" ("program_id", "unit_order");



CREATE INDEX "profiles_local_id_idx" ON "public"."profiles" USING "btree" ("local_id");



CREATE INDEX "profiles_org_id_idx" ON "public"."profiles" USING "btree" ("org_id");



CREATE INDEX "profiles_role_idx" ON "public"."profiles" USING "btree" ("role");



CREATE INDEX "training_programs_local_id_idx" ON "public"."training_programs" USING "btree" ("local_id");



CREATE INDEX "training_programs_org_id_idx" ON "public"."training_programs" USING "btree" ("org_id");



CREATE INDEX "training_programs_org_local_idx" ON "public"."training_programs" USING "btree" ("org_id", "local_id");



CREATE INDEX "training_units_program_id_idx" ON "public"."training_units" USING "btree" ("program_id");



CREATE OR REPLACE TRIGGER "trg_alert_events_prevent_update" BEFORE DELETE OR UPDATE ON "public"."alert_events" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_bot_message_evaluations_prevent_update" BEFORE DELETE OR UPDATE ON "public"."bot_message_evaluations" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_conversation_messages_prevent_update" BEFORE DELETE OR UPDATE ON "public"."conversation_messages" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_conversations_prevent_update" BEFORE DELETE OR UPDATE ON "public"."conversations" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_final_evaluation_answers_prevent_update" BEFORE DELETE OR UPDATE ON "public"."final_evaluation_answers" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_final_evaluation_configs_prevent_update_delete" BEFORE DELETE OR UPDATE ON "public"."final_evaluation_configs" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



COMMENT ON TRIGGER "trg_final_evaluation_configs_prevent_update_delete" ON "public"."final_evaluation_configs" IS 'Post-MVP3 C.1: Enforce append-only (no UPDATE/DELETE). Insert new rows to version configs.';



CREATE OR REPLACE TRIGGER "trg_final_evaluation_evaluations_prevent_update" BEFORE DELETE OR UPDATE ON "public"."final_evaluation_evaluations" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_final_evaluation_questions_prevent_update" BEFORE DELETE OR UPDATE ON "public"."final_evaluation_questions" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_knowledge_change_events_prevent_update" BEFORE DELETE OR UPDATE ON "public"."knowledge_change_events" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_knowledge_items_guard_disable_update" BEFORE UPDATE ON "public"."knowledge_items" FOR EACH ROW EXECUTE FUNCTION "public"."guard_knowledge_items_disable_update"();



CREATE OR REPLACE TRIGGER "trg_learner_review_decisions_prevent_update" BEFORE DELETE OR UPDATE ON "public"."learner_review_decisions" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_learner_review_validations_v2_prevent_update" BEFORE DELETE OR UPDATE ON "public"."learner_review_validations_v2" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_learner_trainings_set_updated_at" BEFORE UPDATE ON "public"."learner_trainings" FOR EACH ROW EXECUTE FUNCTION "public"."set_learner_training_updated_at"();



CREATE OR REPLACE TRIGGER "trg_local_active_program_change_events_prevent_update" BEFORE DELETE OR UPDATE ON "public"."local_active_program_change_events" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_notification_emails_prevent_update" BEFORE DELETE OR UPDATE ON "public"."notification_emails" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_practice_attempt_events_prevent_update" BEFORE DELETE OR UPDATE ON "public"."practice_attempt_events" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_practice_attempts_prevent_update" BEFORE DELETE OR UPDATE ON "public"."practice_attempts" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_practice_evaluations_prevent_update" BEFORE DELETE OR UPDATE ON "public"."practice_evaluations" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_profiles_guard_update" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."guard_profiles_update"();



CREATE OR REPLACE TRIGGER "trg_profiles_set_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_profile_updated_at"();



ALTER TABLE ONLY "public"."alert_events"
    ADD CONSTRAINT "alert_events_learner_id_fkey" FOREIGN KEY ("learner_id") REFERENCES "public"."profiles"("user_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."alert_events"
    ADD CONSTRAINT "alert_events_local_id_fkey" FOREIGN KEY ("local_id") REFERENCES "public"."locals"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."alert_events"
    ADD CONSTRAINT "alert_events_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."bot_message_evaluations"
    ADD CONSTRAINT "bot_message_evaluations_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "public"."conversation_messages"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversation_messages"
    ADD CONSTRAINT "conversation_messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_learner_id_fkey" FOREIGN KEY ("learner_id") REFERENCES "public"."profiles"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_local_id_fkey" FOREIGN KEY ("local_id") REFERENCES "public"."locals"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_program_id_fkey" FOREIGN KEY ("program_id") REFERENCES "public"."training_programs"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."final_evaluation_answers"
    ADD CONSTRAINT "final_evaluation_answers_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "public"."final_evaluation_questions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."final_evaluation_attempts"
    ADD CONSTRAINT "final_evaluation_attempts_learner_id_fkey" FOREIGN KEY ("learner_id") REFERENCES "public"."profiles"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."final_evaluation_attempts"
    ADD CONSTRAINT "final_evaluation_attempts_program_id_fkey" FOREIGN KEY ("program_id") REFERENCES "public"."training_programs"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."final_evaluation_configs"
    ADD CONSTRAINT "final_evaluation_configs_program_id_fkey" FOREIGN KEY ("program_id") REFERENCES "public"."training_programs"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."final_evaluation_evaluations"
    ADD CONSTRAINT "final_evaluation_evaluations_answer_id_fkey" FOREIGN KEY ("answer_id") REFERENCES "public"."final_evaluation_answers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."final_evaluation_questions"
    ADD CONSTRAINT "final_evaluation_questions_attempt_id_fkey" FOREIGN KEY ("attempt_id") REFERENCES "public"."final_evaluation_attempts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."knowledge_change_events"
    ADD CONSTRAINT "knowledge_change_events_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."profiles"("user_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."knowledge_change_events"
    ADD CONSTRAINT "knowledge_change_events_knowledge_id_fkey" FOREIGN KEY ("knowledge_id") REFERENCES "public"."knowledge_items"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."knowledge_change_events"
    ADD CONSTRAINT "knowledge_change_events_local_id_fkey" FOREIGN KEY ("local_id") REFERENCES "public"."locals"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."knowledge_change_events"
    ADD CONSTRAINT "knowledge_change_events_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."knowledge_change_events"
    ADD CONSTRAINT "knowledge_change_events_program_id_fkey" FOREIGN KEY ("program_id") REFERENCES "public"."training_programs"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."knowledge_change_events"
    ADD CONSTRAINT "knowledge_change_events_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "public"."training_units"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."knowledge_items"
    ADD CONSTRAINT "knowledge_items_local_id_fkey" FOREIGN KEY ("local_id") REFERENCES "public"."locals"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."knowledge_items"
    ADD CONSTRAINT "knowledge_items_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."learner_future_questions"
    ADD CONSTRAINT "learner_future_questions_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."learner_future_questions"
    ADD CONSTRAINT "learner_future_questions_learner_id_fkey" FOREIGN KEY ("learner_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."learner_future_questions"
    ADD CONSTRAINT "learner_future_questions_local_id_fkey" FOREIGN KEY ("local_id") REFERENCES "public"."locals"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."learner_future_questions"
    ADD CONSTRAINT "learner_future_questions_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "public"."conversation_messages"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."learner_future_questions"
    ADD CONSTRAINT "learner_future_questions_program_id_fkey" FOREIGN KEY ("program_id") REFERENCES "public"."training_programs"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."learner_review_decisions"
    ADD CONSTRAINT "learner_review_decisions_learner_id_fkey" FOREIGN KEY ("learner_id") REFERENCES "public"."profiles"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."learner_review_decisions"
    ADD CONSTRAINT "learner_review_decisions_reviewer_id_fkey" FOREIGN KEY ("reviewer_id") REFERENCES "public"."profiles"("user_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."learner_review_validations_v2"
    ADD CONSTRAINT "learner_review_validations_v2_learner_id_fkey" FOREIGN KEY ("learner_id") REFERENCES "public"."profiles"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."learner_review_validations_v2"
    ADD CONSTRAINT "learner_review_validations_v2_local_id_fkey" FOREIGN KEY ("local_id") REFERENCES "public"."locals"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."learner_review_validations_v2"
    ADD CONSTRAINT "learner_review_validations_v2_program_id_fkey" FOREIGN KEY ("program_id") REFERENCES "public"."training_programs"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."learner_review_validations_v2"
    ADD CONSTRAINT "learner_review_validations_v2_reviewer_id_fkey" FOREIGN KEY ("reviewer_id") REFERENCES "public"."profiles"("user_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."learner_state_transitions"
    ADD CONSTRAINT "learner_state_transitions_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "public"."profiles"("user_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."learner_state_transitions"
    ADD CONSTRAINT "learner_state_transitions_learner_id_fkey" FOREIGN KEY ("learner_id") REFERENCES "public"."profiles"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."learner_trainings"
    ADD CONSTRAINT "learner_trainings_learner_id_fkey" FOREIGN KEY ("learner_id") REFERENCES "public"."profiles"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."learner_trainings"
    ADD CONSTRAINT "learner_trainings_local_id_fkey" FOREIGN KEY ("local_id") REFERENCES "public"."locals"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."learner_trainings"
    ADD CONSTRAINT "learner_trainings_program_id_fkey" FOREIGN KEY ("program_id") REFERENCES "public"."training_programs"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."local_active_program_change_events"
    ADD CONSTRAINT "local_active_program_change_events_changed_by_user_id_fkey" FOREIGN KEY ("changed_by_user_id") REFERENCES "public"."profiles"("user_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."local_active_program_change_events"
    ADD CONSTRAINT "local_active_program_change_events_from_program_id_fkey" FOREIGN KEY ("from_program_id") REFERENCES "public"."training_programs"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."local_active_program_change_events"
    ADD CONSTRAINT "local_active_program_change_events_local_id_fkey" FOREIGN KEY ("local_id") REFERENCES "public"."locals"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."local_active_program_change_events"
    ADD CONSTRAINT "local_active_program_change_events_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."local_active_program_change_events"
    ADD CONSTRAINT "local_active_program_change_events_to_program_id_fkey" FOREIGN KEY ("to_program_id") REFERENCES "public"."training_programs"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."local_active_programs"
    ADD CONSTRAINT "local_active_programs_local_id_fkey" FOREIGN KEY ("local_id") REFERENCES "public"."locals"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."local_active_programs"
    ADD CONSTRAINT "local_active_programs_program_id_fkey" FOREIGN KEY ("program_id") REFERENCES "public"."training_programs"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."locals"
    ADD CONSTRAINT "locals_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."notification_emails"
    ADD CONSTRAINT "notification_emails_decision_id_fkey" FOREIGN KEY ("decision_id") REFERENCES "public"."learner_review_decisions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_emails"
    ADD CONSTRAINT "notification_emails_learner_id_fkey" FOREIGN KEY ("learner_id") REFERENCES "public"."profiles"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_emails"
    ADD CONSTRAINT "notification_emails_local_id_fkey" FOREIGN KEY ("local_id") REFERENCES "public"."locals"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."notification_emails"
    ADD CONSTRAINT "notification_emails_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."practice_attempt_events"
    ADD CONSTRAINT "practice_attempt_events_attempt_id_fkey" FOREIGN KEY ("attempt_id") REFERENCES "public"."practice_attempts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."practice_attempts"
    ADD CONSTRAINT "practice_attempts_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."practice_attempts"
    ADD CONSTRAINT "practice_attempts_learner_id_fkey" FOREIGN KEY ("learner_id") REFERENCES "public"."profiles"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."practice_attempts"
    ADD CONSTRAINT "practice_attempts_local_id_fkey" FOREIGN KEY ("local_id") REFERENCES "public"."locals"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."practice_attempts"
    ADD CONSTRAINT "practice_attempts_scenario_id_fkey" FOREIGN KEY ("scenario_id") REFERENCES "public"."practice_scenarios"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."practice_evaluations"
    ADD CONSTRAINT "practice_evaluations_attempt_id_fkey" FOREIGN KEY ("attempt_id") REFERENCES "public"."practice_attempts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."practice_evaluations"
    ADD CONSTRAINT "practice_evaluations_learner_message_id_fkey" FOREIGN KEY ("learner_message_id") REFERENCES "public"."conversation_messages"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."practice_scenarios"
    ADD CONSTRAINT "practice_scenarios_local_id_fkey" FOREIGN KEY ("local_id") REFERENCES "public"."locals"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."practice_scenarios"
    ADD CONSTRAINT "practice_scenarios_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."practice_scenarios"
    ADD CONSTRAINT "practice_scenarios_program_id_fkey" FOREIGN KEY ("program_id") REFERENCES "public"."training_programs"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_local_id_fkey" FOREIGN KEY ("local_id") REFERENCES "public"."locals"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."training_programs"
    ADD CONSTRAINT "training_programs_local_id_fkey" FOREIGN KEY ("local_id") REFERENCES "public"."locals"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."training_programs"
    ADD CONSTRAINT "training_programs_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."training_units"
    ADD CONSTRAINT "training_units_program_id_fkey" FOREIGN KEY ("program_id") REFERENCES "public"."training_programs"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."unit_knowledge_map"
    ADD CONSTRAINT "unit_knowledge_map_knowledge_id_fkey" FOREIGN KEY ("knowledge_id") REFERENCES "public"."knowledge_items"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."unit_knowledge_map"
    ADD CONSTRAINT "unit_knowledge_map_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "public"."training_units"("id") ON DELETE CASCADE;



ALTER TABLE "public"."alert_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "alert_events_insert_aprendiz_final_evaluation" ON "public"."alert_events" FOR INSERT WITH CHECK ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("alert_type" = 'final_evaluation_submitted'::"public"."alert_type") AND ("learner_id" = "auth"."uid"()) AND ("source_table" = 'final_evaluation_attempts'::"text") AND (EXISTS ( SELECT 1
   FROM (("public"."final_evaluation_attempts" "a"
     JOIN "public"."learner_trainings" "lt" ON (("lt"."learner_id" = "a"."learner_id")))
     JOIN "public"."locals" "l" ON (("l"."id" = "lt"."local_id")))
  WHERE (("a"."id" = "alert_events"."source_id") AND ("a"."learner_id" = "auth"."uid"()) AND ("alert_events"."local_id" = "lt"."local_id") AND ("alert_events"."org_id" = "l"."org_id"))))));



CREATE POLICY "alert_events_insert_reviewer" ON "public"."alert_events" FOR INSERT WITH CHECK ((("public"."current_role"() = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])) AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR (EXISTS ( SELECT 1
   FROM ("public"."learner_trainings" "lt"
     JOIN "public"."locals" "l" ON (("l"."id" = "lt"."local_id")))
  WHERE (("lt"."learner_id" = "alert_events"."learner_id") AND ("alert_events"."local_id" = "lt"."local_id") AND ("alert_events"."org_id" = "l"."org_id") AND ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "public"."current_org_id"())) OR (("public"."current_role"() = 'referente'::"public"."app_role") AND ("lt"."local_id" = "public"."current_local_id"())))))))));



CREATE POLICY "alert_events_select_admin_org" ON "public"."alert_events" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("org_id" = "public"."current_org_id"())));



CREATE POLICY "alert_events_select_aprendiz" ON "public"."alert_events" FOR SELECT USING ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("learner_id" = "auth"."uid"())));



CREATE POLICY "alert_events_select_referente" ON "public"."alert_events" FOR SELECT USING ((("public"."current_role"() = 'referente'::"public"."app_role") AND ("local_id" = "public"."current_local_id"())));



CREATE POLICY "alert_events_select_superadmin" ON "public"."alert_events" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



ALTER TABLE "public"."bot_message_evaluations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "bot_message_evaluations_insert_learner" ON "public"."bot_message_evaluations" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."conversation_messages" "cm"
     JOIN "public"."conversations" "c" ON (("c"."id" = "cm"."conversation_id")))
  WHERE (("cm"."id" = "bot_message_evaluations"."message_id") AND ("c"."learner_id" = "auth"."uid"())))));



CREATE POLICY "bot_message_evaluations_select_visible" ON "public"."bot_message_evaluations" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM ("public"."conversation_messages" "cm"
     JOIN "public"."conversations" "c" ON (("c"."id" = "cm"."conversation_id")))
  WHERE ("cm"."id" = "bot_message_evaluations"."message_id"))));



ALTER TABLE "public"."conversation_messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "conversation_messages_insert_learner" ON "public"."conversation_messages" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."conversations" "c"
  WHERE (("c"."id" = "conversation_messages"."conversation_id") AND ("c"."learner_id" = "auth"."uid"())))));



CREATE POLICY "conversation_messages_select_visible" ON "public"."conversation_messages" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."conversations" "c"
  WHERE ("c"."id" = "conversation_messages"."conversation_id"))));



ALTER TABLE "public"."conversations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "conversations_insert_learner" ON "public"."conversations" FOR INSERT WITH CHECK ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("learner_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."learner_trainings" "lt"
  WHERE (("lt"."learner_id" = "auth"."uid"()) AND ("lt"."local_id" = "conversations"."local_id") AND ("lt"."program_id" = "conversations"."program_id") AND ("lt"."current_unit_order" = "conversations"."unit_order"))))));



CREATE POLICY "conversations_select_admin_org" ON "public"."conversations" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM "public"."locals" "l"
  WHERE (("l"."id" = "conversations"."local_id") AND ("l"."org_id" = "public"."current_org_id"()))))));



CREATE POLICY "conversations_select_aprendiz" ON "public"."conversations" FOR SELECT USING ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("learner_id" = "auth"."uid"())));



CREATE POLICY "conversations_select_referente" ON "public"."conversations" FOR SELECT USING ((("public"."current_role"() = 'referente'::"public"."app_role") AND ("local_id" = "public"."current_local_id"())));



CREATE POLICY "conversations_select_superadmin" ON "public"."conversations" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



ALTER TABLE "public"."final_evaluation_answers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "final_evaluation_answers_insert_learner" ON "public"."final_evaluation_answers" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."final_evaluation_questions" "q"
     JOIN "public"."final_evaluation_attempts" "a" ON (("a"."id" = "q"."attempt_id")))
  WHERE (("q"."id" = "final_evaluation_answers"."question_id") AND ("a"."learner_id" = "auth"."uid"())))));



CREATE POLICY "final_evaluation_answers_select_visible" ON "public"."final_evaluation_answers" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM ("public"."final_evaluation_questions" "q"
     JOIN "public"."final_evaluation_attempts" "a" ON (("a"."id" = "q"."attempt_id")))
  WHERE (("q"."id" = "final_evaluation_answers"."question_id") AND ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("a"."learner_id" = "auth"."uid"())) OR (("public"."current_role"() = 'referente'::"public"."app_role") AND (EXISTS ( SELECT 1
           FROM "public"."learner_trainings" "lt"
          WHERE (("lt"."learner_id" = "a"."learner_id") AND ("lt"."program_id" = "a"."program_id") AND ("lt"."local_id" = "public"."current_local_id"()))))) OR (("public"."current_role"() = 'admin_org'::"public"."app_role") AND (EXISTS ( SELECT 1
           FROM ("public"."learner_trainings" "lt"
             JOIN "public"."locals" "l" ON (("l"."id" = "lt"."local_id")))
          WHERE (("lt"."learner_id" = "a"."learner_id") AND ("lt"."program_id" = "a"."program_id") AND ("l"."org_id" = "public"."current_org_id"()))))) OR ("public"."current_role"() = 'superadmin'::"public"."app_role"))))));



ALTER TABLE "public"."final_evaluation_attempts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "final_evaluation_attempts_insert_learner" ON "public"."final_evaluation_attempts" FOR INSERT WITH CHECK ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("learner_id" = "auth"."uid"())));



CREATE POLICY "final_evaluation_attempts_select_admin_org" ON "public"."final_evaluation_attempts" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM ("public"."learner_trainings" "lt"
     JOIN "public"."locals" "l" ON (("l"."id" = "lt"."local_id")))
  WHERE (("lt"."learner_id" = "final_evaluation_attempts"."learner_id") AND ("l"."org_id" = "public"."current_org_id"()))))));



CREATE POLICY "final_evaluation_attempts_select_aprendiz" ON "public"."final_evaluation_attempts" FOR SELECT USING ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("learner_id" = "auth"."uid"())));



CREATE POLICY "final_evaluation_attempts_select_referente" ON "public"."final_evaluation_attempts" FOR SELECT USING ((("public"."current_role"() = 'referente'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM "public"."learner_trainings" "lt"
  WHERE (("lt"."learner_id" = "final_evaluation_attempts"."learner_id") AND ("lt"."local_id" = "public"."current_local_id"()))))));



CREATE POLICY "final_evaluation_attempts_select_superadmin" ON "public"."final_evaluation_attempts" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



CREATE POLICY "final_evaluation_attempts_update_learner" ON "public"."final_evaluation_attempts" FOR UPDATE USING ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("learner_id" = "auth"."uid"()))) WITH CHECK ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("learner_id" = "auth"."uid"())));



ALTER TABLE "public"."final_evaluation_configs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "final_evaluation_configs_insert_admin" ON "public"."final_evaluation_configs" FOR INSERT WITH CHECK (("public"."current_role"() = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role"])));



CREATE POLICY "final_evaluation_configs_select_admin" ON "public"."final_evaluation_configs" FOR SELECT USING (("public"."current_role"() = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])));



CREATE POLICY "final_evaluation_configs_select_aprendiz" ON "public"."final_evaluation_configs" FOR SELECT USING ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM "public"."learner_trainings" "lt"
  WHERE (("lt"."learner_id" = "auth"."uid"()) AND ("lt"."program_id" = "final_evaluation_configs"."program_id"))))));



CREATE POLICY "final_evaluation_configs_update_admin" ON "public"."final_evaluation_configs" FOR UPDATE USING (("public"."current_role"() = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role"]))) WITH CHECK (("public"."current_role"() = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role"])));



ALTER TABLE "public"."final_evaluation_evaluations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "final_evaluation_evaluations_insert_learner" ON "public"."final_evaluation_evaluations" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM (("public"."final_evaluation_answers" "ans"
     JOIN "public"."final_evaluation_questions" "q" ON (("q"."id" = "ans"."question_id")))
     JOIN "public"."final_evaluation_attempts" "a" ON (("a"."id" = "q"."attempt_id")))
  WHERE (("ans"."id" = "final_evaluation_evaluations"."answer_id") AND ("a"."learner_id" = "auth"."uid"())))));



CREATE POLICY "final_evaluation_evaluations_select_visible" ON "public"."final_evaluation_evaluations" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM (("public"."final_evaluation_answers" "ans"
     JOIN "public"."final_evaluation_questions" "q" ON (("q"."id" = "ans"."question_id")))
     JOIN "public"."final_evaluation_attempts" "a" ON (("a"."id" = "q"."attempt_id")))
  WHERE (("ans"."id" = "final_evaluation_evaluations"."answer_id") AND ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("a"."learner_id" = "auth"."uid"())) OR (("public"."current_role"() = 'referente'::"public"."app_role") AND (EXISTS ( SELECT 1
           FROM "public"."learner_trainings" "lt"
          WHERE (("lt"."learner_id" = "a"."learner_id") AND ("lt"."program_id" = "a"."program_id") AND ("lt"."local_id" = "public"."current_local_id"()))))) OR (("public"."current_role"() = 'admin_org'::"public"."app_role") AND (EXISTS ( SELECT 1
           FROM ("public"."learner_trainings" "lt"
             JOIN "public"."locals" "l" ON (("l"."id" = "lt"."local_id")))
          WHERE (("lt"."learner_id" = "a"."learner_id") AND ("lt"."program_id" = "a"."program_id") AND ("l"."org_id" = "public"."current_org_id"()))))) OR ("public"."current_role"() = 'superadmin'::"public"."app_role"))))));



ALTER TABLE "public"."final_evaluation_questions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "final_evaluation_questions_insert_learner" ON "public"."final_evaluation_questions" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."final_evaluation_attempts" "a"
  WHERE (("a"."id" = "final_evaluation_questions"."attempt_id") AND ("a"."learner_id" = "auth"."uid"())))));



CREATE POLICY "final_evaluation_questions_select_visible" ON "public"."final_evaluation_questions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."final_evaluation_attempts" "a"
  WHERE (("a"."id" = "final_evaluation_questions"."attempt_id") AND ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("a"."learner_id" = "auth"."uid"())) OR (("public"."current_role"() = 'referente'::"public"."app_role") AND (EXISTS ( SELECT 1
           FROM "public"."learner_trainings" "lt"
          WHERE (("lt"."learner_id" = "a"."learner_id") AND ("lt"."program_id" = "a"."program_id") AND ("lt"."local_id" = "public"."current_local_id"()))))) OR (("public"."current_role"() = 'admin_org'::"public"."app_role") AND (EXISTS ( SELECT 1
           FROM ("public"."learner_trainings" "lt"
             JOIN "public"."locals" "l" ON (("l"."id" = "lt"."local_id")))
          WHERE (("lt"."learner_id" = "a"."learner_id") AND ("lt"."program_id" = "a"."program_id") AND ("l"."org_id" = "public"."current_org_id"()))))) OR ("public"."current_role"() = 'superadmin'::"public"."app_role"))))));



ALTER TABLE "public"."knowledge_change_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "knowledge_change_events_insert_admin_org" ON "public"."knowledge_change_events" FOR INSERT WITH CHECK ((("public"."current_role"() = 'superadmin'::"public"."app_role") OR (("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("org_id" = "public"."current_org_id"()))));



CREATE POLICY "knowledge_change_events_select_admin_org" ON "public"."knowledge_change_events" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("org_id" = "public"."current_org_id"())));



CREATE POLICY "knowledge_change_events_select_superadmin" ON "public"."knowledge_change_events" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



ALTER TABLE "public"."knowledge_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "knowledge_items_insert_admin_org" ON "public"."knowledge_items" FOR INSERT WITH CHECK ((("public"."current_role"() = 'superadmin'::"public"."app_role") OR (("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("org_id" = "public"."current_org_id"()) AND (("local_id" IS NULL) OR (EXISTS ( SELECT 1
   FROM "public"."locals" "l"
  WHERE (("l"."id" = "knowledge_items"."local_id") AND ("l"."org_id" = "public"."current_org_id"()))))))));



CREATE POLICY "knowledge_items_select_admin_org" ON "public"."knowledge_items" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("org_id" = "public"."current_org_id"())));



CREATE POLICY "knowledge_items_select_local_roles" ON "public"."knowledge_items" FOR SELECT USING ((("public"."current_role"() = ANY (ARRAY['referente'::"public"."app_role", 'aprendiz'::"public"."app_role"])) AND ("org_id" = "public"."current_org_id"()) AND (("local_id" IS NULL) OR ("local_id" = "public"."current_local_id"())) AND ("is_enabled" = true)));



CREATE POLICY "knowledge_items_select_superadmin" ON "public"."knowledge_items" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



CREATE POLICY "knowledge_items_update_admin_org" ON "public"."knowledge_items" FOR UPDATE USING ((("public"."current_role"() = 'superadmin'::"public"."app_role") OR (("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("org_id" = "public"."current_org_id"())))) WITH CHECK ((("public"."current_role"() = 'superadmin'::"public"."app_role") OR (("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("org_id" = "public"."current_org_id"()) AND (("local_id" IS NULL) OR (EXISTS ( SELECT 1
   FROM "public"."locals" "l"
  WHERE (("l"."id" = "knowledge_items"."local_id") AND ("l"."org_id" = "public"."current_org_id"()))))))));



ALTER TABLE "public"."learner_future_questions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "learner_future_questions_select_admin_org" ON "public"."learner_future_questions" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM "public"."locals" "l"
  WHERE (("l"."id" = "learner_future_questions"."local_id") AND ("l"."org_id" = "public"."current_org_id"()))))));



CREATE POLICY "learner_future_questions_select_aprendiz" ON "public"."learner_future_questions" FOR SELECT USING ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("learner_id" = "auth"."uid"())));



CREATE POLICY "learner_future_questions_select_referente" ON "public"."learner_future_questions" FOR SELECT USING ((("public"."current_role"() = 'referente'::"public"."app_role") AND ("local_id" = "public"."current_local_id"())));



CREATE POLICY "learner_future_questions_select_superadmin" ON "public"."learner_future_questions" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



ALTER TABLE "public"."learner_review_decisions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "learner_review_decisions_insert_reviewer" ON "public"."learner_review_decisions" FOR INSERT WITH CHECK ((("reviewer_id" = "auth"."uid"()) AND ("public"."current_role"() = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])) AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR (EXISTS ( SELECT 1
   FROM ("public"."learner_trainings" "lt"
     JOIN "public"."locals" "l" ON (("l"."id" = "lt"."local_id")))
  WHERE (("lt"."learner_id" = "learner_review_decisions"."learner_id") AND ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "public"."current_org_id"())) OR (("public"."current_role"() = 'referente'::"public"."app_role") AND ("lt"."local_id" = "public"."current_local_id"())))))))));



CREATE POLICY "learner_review_decisions_select_admin_org" ON "public"."learner_review_decisions" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM ("public"."learner_trainings" "lt"
     JOIN "public"."locals" "l" ON (("l"."id" = "lt"."local_id")))
  WHERE (("lt"."learner_id" = "learner_review_decisions"."learner_id") AND ("l"."org_id" = "public"."current_org_id"()))))));



CREATE POLICY "learner_review_decisions_select_aprendiz" ON "public"."learner_review_decisions" FOR SELECT USING ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("learner_id" = "auth"."uid"())));



CREATE POLICY "learner_review_decisions_select_referente" ON "public"."learner_review_decisions" FOR SELECT USING ((("public"."current_role"() = 'referente'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM "public"."learner_trainings" "lt"
  WHERE (("lt"."learner_id" = "learner_review_decisions"."learner_id") AND ("lt"."local_id" = "public"."current_local_id"()))))));



CREATE POLICY "learner_review_decisions_select_superadmin" ON "public"."learner_review_decisions" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



ALTER TABLE "public"."learner_review_validations_v2" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "learner_review_validations_v2_insert_reviewer" ON "public"."learner_review_validations_v2" FOR INSERT WITH CHECK ((("reviewer_id" = "auth"."uid"()) AND ("public"."current_role"() = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])) AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR (EXISTS ( SELECT 1
   FROM ("public"."learner_trainings" "lt"
     JOIN "public"."locals" "l" ON (("l"."id" = "lt"."local_id")))
  WHERE (("lt"."learner_id" = "learner_review_validations_v2"."learner_id") AND ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "public"."current_org_id"())) OR (("public"."current_role"() = 'referente'::"public"."app_role") AND ("lt"."local_id" = "public"."current_local_id"())))))))));



CREATE POLICY "learner_review_validations_v2_select_admin_org" ON "public"."learner_review_validations_v2" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM ("public"."learner_trainings" "lt"
     JOIN "public"."locals" "l" ON (("l"."id" = "lt"."local_id")))
  WHERE (("lt"."learner_id" = "learner_review_validations_v2"."learner_id") AND ("l"."org_id" = "public"."current_org_id"()))))));



CREATE POLICY "learner_review_validations_v2_select_aprendiz" ON "public"."learner_review_validations_v2" FOR SELECT USING ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("learner_id" = "auth"."uid"())));



CREATE POLICY "learner_review_validations_v2_select_referente" ON "public"."learner_review_validations_v2" FOR SELECT USING ((("public"."current_role"() = 'referente'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM "public"."learner_trainings" "lt"
  WHERE (("lt"."learner_id" = "learner_review_validations_v2"."learner_id") AND ("lt"."local_id" = "public"."current_local_id"()))))));



CREATE POLICY "learner_review_validations_v2_select_superadmin" ON "public"."learner_review_validations_v2" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



ALTER TABLE "public"."learner_state_transitions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "learner_state_transitions_insert_learner" ON "public"."learner_state_transitions" FOR INSERT WITH CHECK ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("learner_id" = "auth"."uid"()) AND ("actor_user_id" = "auth"."uid"())));



CREATE POLICY "learner_state_transitions_insert_reviewer" ON "public"."learner_state_transitions" FOR INSERT WITH CHECK ((("actor_user_id" = "auth"."uid"()) AND ("public"."current_role"() = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])) AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR (EXISTS ( SELECT 1
   FROM ("public"."learner_trainings" "lt"
     JOIN "public"."locals" "l" ON (("l"."id" = "lt"."local_id")))
  WHERE (("lt"."learner_id" = "learner_state_transitions"."learner_id") AND ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "public"."current_org_id"())) OR (("public"."current_role"() = 'referente'::"public"."app_role") AND ("lt"."local_id" = "public"."current_local_id"())))))))));



CREATE POLICY "learner_state_transitions_select_admin_org" ON "public"."learner_state_transitions" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM ("public"."learner_trainings" "lt"
     JOIN "public"."locals" "l" ON (("l"."id" = "lt"."local_id")))
  WHERE (("lt"."learner_id" = "learner_state_transitions"."learner_id") AND ("l"."org_id" = "public"."current_org_id"()))))));



CREATE POLICY "learner_state_transitions_select_aprendiz" ON "public"."learner_state_transitions" FOR SELECT USING ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("learner_id" = "auth"."uid"())));



CREATE POLICY "learner_state_transitions_select_referente" ON "public"."learner_state_transitions" FOR SELECT USING ((("public"."current_role"() = 'referente'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM "public"."learner_trainings" "lt"
  WHERE (("lt"."learner_id" = "learner_state_transitions"."learner_id") AND ("lt"."local_id" = "public"."current_local_id"()))))));



CREATE POLICY "learner_state_transitions_select_superadmin" ON "public"."learner_state_transitions" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



ALTER TABLE "public"."learner_trainings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "learner_trainings_select_admin_org" ON "public"."learner_trainings" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM "public"."locals" "l"
  WHERE (("l"."id" = "learner_trainings"."local_id") AND ("l"."org_id" = "public"."current_org_id"()))))));



CREATE POLICY "learner_trainings_select_aprendiz" ON "public"."learner_trainings" FOR SELECT USING ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("learner_id" = "auth"."uid"())));



CREATE POLICY "learner_trainings_select_referente" ON "public"."learner_trainings" FOR SELECT USING ((("public"."current_role"() = 'referente'::"public"."app_role") AND ("local_id" = "public"."current_local_id"())));



CREATE POLICY "learner_trainings_select_superadmin" ON "public"."learner_trainings" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



CREATE POLICY "learner_trainings_update_learner_final" ON "public"."learner_trainings" FOR UPDATE USING ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("learner_id" = "auth"."uid"()))) WITH CHECK ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("learner_id" = "auth"."uid"()) AND ("status" = ANY (ARRAY['en_practica'::"public"."learner_status", 'en_revision'::"public"."learner_status"]))));



CREATE POLICY "learner_trainings_update_reviewer" ON "public"."learner_trainings" FOR UPDATE USING ((("public"."current_role"() = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])) AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR (EXISTS ( SELECT 1
   FROM "public"."locals" "l"
  WHERE (("l"."id" = "learner_trainings"."local_id") AND ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "public"."current_org_id"())) OR (("public"."current_role"() = 'referente'::"public"."app_role") AND ("learner_trainings"."local_id" = "public"."current_local_id"()))))))))) WITH CHECK ((("public"."current_role"() = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])) AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR (EXISTS ( SELECT 1
   FROM "public"."locals" "l"
  WHERE (("l"."id" = "learner_trainings"."local_id") AND ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "public"."current_org_id"())) OR (("public"."current_role"() = 'referente'::"public"."app_role") AND ("learner_trainings"."local_id" = "public"."current_local_id"())))))))));



ALTER TABLE "public"."local_active_program_change_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "local_active_program_change_events_insert_admin_org" ON "public"."local_active_program_change_events" FOR INSERT WITH CHECK ((("public"."current_role"() = 'superadmin'::"public"."app_role") OR (("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("org_id" = "public"."current_org_id"()))));



CREATE POLICY "local_active_program_change_events_select_admin_org" ON "public"."local_active_program_change_events" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("org_id" = "public"."current_org_id"())));



CREATE POLICY "local_active_program_change_events_select_superadmin" ON "public"."local_active_program_change_events" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



ALTER TABLE "public"."local_active_programs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "local_active_programs_insert_admin_org" ON "public"."local_active_programs" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."locals" "l"
     JOIN "public"."training_programs" "tp" ON (("tp"."id" = "local_active_programs"."program_id")))
  WHERE (("l"."id" = "local_active_programs"."local_id") AND ("tp"."org_id" = "l"."org_id") AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR (("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "public"."current_org_id"())))))));



CREATE POLICY "local_active_programs_select_admin_org" ON "public"."local_active_programs" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM "public"."locals" "l"
  WHERE (("l"."id" = "local_active_programs"."local_id") AND ("l"."org_id" = "public"."current_org_id"()))))));



CREATE POLICY "local_active_programs_select_local_roles" ON "public"."local_active_programs" FOR SELECT USING ((("public"."current_role"() = ANY (ARRAY['referente'::"public"."app_role", 'aprendiz'::"public"."app_role"])) AND ("local_id" = "public"."current_local_id"())));



CREATE POLICY "local_active_programs_select_superadmin" ON "public"."local_active_programs" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



CREATE POLICY "local_active_programs_update_admin_org" ON "public"."local_active_programs" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."locals" "l"
  WHERE (("l"."id" = "local_active_programs"."local_id") AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR (("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "public"."current_org_id"()))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."locals" "l"
     JOIN "public"."training_programs" "tp" ON (("tp"."id" = "local_active_programs"."program_id")))
  WHERE (("l"."id" = "local_active_programs"."local_id") AND ("tp"."org_id" = "l"."org_id") AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR (("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "public"."current_org_id"())))))));



ALTER TABLE "public"."locals" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "locals_select_admin_org" ON "public"."locals" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("org_id" = "public"."current_org_id"())));



CREATE POLICY "locals_select_own" ON "public"."locals" FOR SELECT USING ((("public"."current_role"() = ANY (ARRAY['referente'::"public"."app_role", 'aprendiz'::"public"."app_role"])) AND ("id" = "public"."current_local_id"())));



CREATE POLICY "locals_select_superadmin" ON "public"."locals" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



ALTER TABLE "public"."notification_emails" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notification_emails_insert_reviewer" ON "public"."notification_emails" FOR INSERT WITH CHECK ((("public"."current_role"() = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])) AND (("public"."current_role"() = 'superadmin'::"public"."app_role") OR (EXISTS ( SELECT 1
   FROM ("public"."learner_trainings" "lt"
     JOIN "public"."locals" "l" ON (("l"."id" = "lt"."local_id")))
  WHERE (("lt"."learner_id" = "notification_emails"."learner_id") AND ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("l"."org_id" = "public"."current_org_id"())) OR (("public"."current_role"() = 'referente'::"public"."app_role") AND ("lt"."local_id" = "public"."current_local_id"())))))))));



CREATE POLICY "notification_emails_select_admin_org" ON "public"."notification_emails" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM ("public"."learner_trainings" "lt"
     JOIN "public"."locals" "l" ON (("l"."id" = "lt"."local_id")))
  WHERE (("lt"."learner_id" = "notification_emails"."learner_id") AND ("l"."org_id" = "public"."current_org_id"()))))));



CREATE POLICY "notification_emails_select_aprendiz" ON "public"."notification_emails" FOR SELECT USING ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("learner_id" = "auth"."uid"())));



CREATE POLICY "notification_emails_select_referente" ON "public"."notification_emails" FOR SELECT USING ((("public"."current_role"() = 'referente'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM "public"."learner_trainings" "lt"
  WHERE (("lt"."learner_id" = "notification_emails"."learner_id") AND ("lt"."local_id" = "public"."current_local_id"()))))));



CREATE POLICY "notification_emails_select_superadmin" ON "public"."notification_emails" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



ALTER TABLE "public"."organizations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "organizations_select_own" ON "public"."organizations" FOR SELECT USING (("id" = "public"."current_org_id"()));



CREATE POLICY "organizations_select_superadmin" ON "public"."organizations" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



ALTER TABLE "public"."practice_attempt_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "practice_attempt_events_insert_learner" ON "public"."practice_attempt_events" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."practice_attempts" "pa"
  WHERE (("pa"."id" = "practice_attempt_events"."attempt_id") AND ("pa"."learner_id" = "auth"."uid"())))));



CREATE POLICY "practice_attempt_events_select_admin_org" ON "public"."practice_attempt_events" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM ("public"."practice_attempts" "pa"
     JOIN "public"."locals" "l" ON (("l"."id" = "pa"."local_id")))
  WHERE (("pa"."id" = "practice_attempt_events"."attempt_id") AND ("l"."org_id" = "public"."current_org_id"()))))));



CREATE POLICY "practice_attempt_events_select_aprendiz" ON "public"."practice_attempt_events" FOR SELECT USING ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM "public"."practice_attempts" "pa"
  WHERE (("pa"."id" = "practice_attempt_events"."attempt_id") AND ("pa"."learner_id" = "auth"."uid"()))))));



CREATE POLICY "practice_attempt_events_select_referente" ON "public"."practice_attempt_events" FOR SELECT USING ((("public"."current_role"() = 'referente'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM "public"."practice_attempts" "pa"
  WHERE (("pa"."id" = "practice_attempt_events"."attempt_id") AND ("pa"."local_id" = "public"."current_local_id"()))))));



CREATE POLICY "practice_attempt_events_select_superadmin" ON "public"."practice_attempt_events" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



ALTER TABLE "public"."practice_attempts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "practice_attempts_insert_learner" ON "public"."practice_attempts" FOR INSERT WITH CHECK ((("learner_id" = "auth"."uid"()) AND ("public"."current_role"() = 'aprendiz'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM "public"."practice_scenarios" "ps"
  WHERE (("ps"."id" = "practice_attempts"."scenario_id") AND ("ps"."org_id" = "public"."current_org_id"()) AND (("ps"."local_id" IS NULL) OR ("ps"."local_id" = "public"."current_local_id"())))))));



CREATE POLICY "practice_attempts_select_admin_org" ON "public"."practice_attempts" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM "public"."locals" "l"
  WHERE (("l"."id" = "practice_attempts"."local_id") AND ("l"."org_id" = "public"."current_org_id"()))))));



CREATE POLICY "practice_attempts_select_aprendiz" ON "public"."practice_attempts" FOR SELECT USING ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("learner_id" = "auth"."uid"())));



CREATE POLICY "practice_attempts_select_referente" ON "public"."practice_attempts" FOR SELECT USING ((("public"."current_role"() = 'referente'::"public"."app_role") AND ("local_id" = "public"."current_local_id"())));



CREATE POLICY "practice_attempts_select_superadmin" ON "public"."practice_attempts" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



ALTER TABLE "public"."practice_evaluations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "practice_evaluations_insert_learner" ON "public"."practice_evaluations" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."practice_attempts" "pa"
  WHERE (("pa"."id" = "practice_evaluations"."attempt_id") AND ("pa"."learner_id" = "auth"."uid"())))));



CREATE POLICY "practice_evaluations_select_admin_org" ON "public"."practice_evaluations" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM ("public"."practice_attempts" "pa"
     JOIN "public"."locals" "l" ON (("l"."id" = "pa"."local_id")))
  WHERE (("pa"."id" = "practice_evaluations"."attempt_id") AND ("l"."org_id" = "public"."current_org_id"()))))));



CREATE POLICY "practice_evaluations_select_aprendiz" ON "public"."practice_evaluations" FOR SELECT USING ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM "public"."practice_attempts" "pa"
  WHERE (("pa"."id" = "practice_evaluations"."attempt_id") AND ("pa"."learner_id" = "auth"."uid"()))))));



CREATE POLICY "practice_evaluations_select_referente" ON "public"."practice_evaluations" FOR SELECT USING ((("public"."current_role"() = 'referente'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM "public"."practice_attempts" "pa"
  WHERE (("pa"."id" = "practice_evaluations"."attempt_id") AND ("pa"."local_id" = "public"."current_local_id"()))))));



CREATE POLICY "practice_evaluations_select_superadmin" ON "public"."practice_evaluations" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



ALTER TABLE "public"."practice_scenarios" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "practice_scenarios_select_admin_org" ON "public"."practice_scenarios" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("org_id" = "public"."current_org_id"())));



CREATE POLICY "practice_scenarios_select_local_roles" ON "public"."practice_scenarios" FOR SELECT USING ((("public"."current_role"() = ANY (ARRAY['referente'::"public"."app_role", 'aprendiz'::"public"."app_role"])) AND ("org_id" = "public"."current_org_id"()) AND (("local_id" IS NULL) OR ("local_id" = "public"."current_local_id"()))));



CREATE POLICY "practice_scenarios_select_superadmin" ON "public"."practice_scenarios" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_select_admin_org" ON "public"."profiles" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("org_id" = "public"."current_org_id"())));



CREATE POLICY "profiles_select_own" ON "public"."profiles" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "profiles_select_referente" ON "public"."profiles" FOR SELECT USING ((("public"."current_role"() = 'referente'::"public"."app_role") AND ("local_id" = "public"."current_local_id"())));



CREATE POLICY "profiles_select_superadmin" ON "public"."profiles" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



CREATE POLICY "profiles_update_own" ON "public"."profiles" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."training_programs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "training_programs_select_admin_org" ON "public"."training_programs" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("org_id" = "public"."current_org_id"())));



CREATE POLICY "training_programs_select_local_roles" ON "public"."training_programs" FOR SELECT USING ((("public"."current_role"() = ANY (ARRAY['referente'::"public"."app_role", 'aprendiz'::"public"."app_role"])) AND ("org_id" = "public"."current_org_id"()) AND (("local_id" IS NULL) OR ("local_id" = "public"."current_local_id"()))));



CREATE POLICY "training_programs_select_superadmin" ON "public"."training_programs" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



ALTER TABLE "public"."training_units" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "training_units_select_visible_programs" ON "public"."training_units" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."training_programs" "tp"
  WHERE ("tp"."id" = "training_units"."program_id"))));



ALTER TABLE "public"."unit_knowledge_map" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "unit_knowledge_map_insert_admin_org" ON "public"."unit_knowledge_map" FOR INSERT WITH CHECK ((("public"."current_role"() = 'superadmin'::"public"."app_role") OR (("public"."current_role"() = 'admin_org'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM ("public"."training_units" "tu"
     JOIN "public"."training_programs" "tp" ON (("tp"."id" = "tu"."program_id")))
  WHERE (("tu"."id" = "unit_knowledge_map"."unit_id") AND ("tp"."org_id" = "public"."current_org_id"())))) AND (EXISTS ( SELECT 1
   FROM "public"."knowledge_items" "ki"
  WHERE (("ki"."id" = "unit_knowledge_map"."knowledge_id") AND ("ki"."org_id" = "public"."current_org_id"())))))));



CREATE POLICY "unit_knowledge_map_select_visible" ON "public"."unit_knowledge_map" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."knowledge_items" "ki"
  WHERE ("ki"."id" = "unit_knowledge_map"."knowledge_id"))));



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."create_and_map_knowledge_item"("p_program_id" "uuid", "p_unit_id" "uuid", "p_title" "text", "p_content" "text", "p_scope" "text", "p_local_id" "uuid", "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_and_map_knowledge_item"("p_program_id" "uuid", "p_unit_id" "uuid", "p_title" "text", "p_content" "text", "p_scope" "text", "p_local_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_and_map_knowledge_item"("p_program_id" "uuid", "p_unit_id" "uuid", "p_title" "text", "p_content" "text", "p_scope" "text", "p_local_id" "uuid", "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_final_evaluation_config"("p_program_id" "uuid", "p_total_questions" integer, "p_roleplay_ratio" numeric, "p_min_global_score" numeric, "p_must_pass_units" integer[], "p_questions_per_unit" integer, "p_max_attempts" integer, "p_cooldown_hours" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."create_final_evaluation_config"("p_program_id" "uuid", "p_total_questions" integer, "p_roleplay_ratio" numeric, "p_min_global_score" numeric, "p_must_pass_units" integer[], "p_questions_per_unit" integer, "p_max_attempts" integer, "p_cooldown_hours" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_final_evaluation_config"("p_program_id" "uuid", "p_total_questions" integer, "p_roleplay_ratio" numeric, "p_min_global_score" numeric, "p_must_pass_units" integer[], "p_questions_per_unit" integer, "p_max_attempts" integer, "p_cooldown_hours" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."current_local_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_local_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_local_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."current_org_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_org_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_org_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."current_profile"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_profile"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_profile"() TO "service_role";



GRANT ALL ON FUNCTION "public"."current_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_role"() TO "service_role";



GRANT ALL ON FUNCTION "public"."current_user_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_user_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_user_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."disable_knowledge_item"("p_knowledge_id" "uuid", "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."disable_knowledge_item"("p_knowledge_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."disable_knowledge_item"("p_knowledge_id" "uuid", "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_email"("target_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_email"("target_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_email"("target_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."guard_knowledge_items_disable_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."guard_knowledge_items_disable_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."guard_knowledge_items_disable_update"() TO "service_role";



GRANT ALL ON FUNCTION "public"."guard_profiles_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."guard_profiles_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."guard_profiles_update"() TO "service_role";



GRANT ALL ON FUNCTION "public"."log_future_question"("asked_unit_order" integer, "question_text" "text", "conversation_id" "uuid", "message_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."log_future_question"("asked_unit_order" integer, "question_text" "text", "conversation_id" "uuid", "message_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_future_question"("asked_unit_order" integer, "question_text" "text", "conversation_id" "uuid", "message_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_update_delete"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_update_delete"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_update_delete"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_learner_training_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_learner_training_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_learner_training_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_local_active_program"("p_local_id" "uuid", "p_program_id" "uuid", "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."set_local_active_program"("p_local_id" "uuid", "p_program_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_local_active_program"("p_local_id" "uuid", "p_program_id" "uuid", "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_profile_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_profile_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_profile_updated_at"() TO "service_role";



GRANT ALL ON TABLE "public"."alert_events" TO "service_role";
GRANT SELECT,INSERT ON TABLE "public"."alert_events" TO "authenticated";



GRANT ALL ON TABLE "public"."bot_message_evaluations" TO "anon";
GRANT ALL ON TABLE "public"."bot_message_evaluations" TO "authenticated";
GRANT ALL ON TABLE "public"."bot_message_evaluations" TO "service_role";



GRANT ALL ON TABLE "public"."conversation_messages" TO "anon";
GRANT ALL ON TABLE "public"."conversation_messages" TO "authenticated";
GRANT ALL ON TABLE "public"."conversation_messages" TO "service_role";



GRANT ALL ON TABLE "public"."conversations" TO "anon";
GRANT ALL ON TABLE "public"."conversations" TO "authenticated";
GRANT ALL ON TABLE "public"."conversations" TO "service_role";



GRANT ALL ON TABLE "public"."final_evaluation_answers" TO "anon";
GRANT ALL ON TABLE "public"."final_evaluation_answers" TO "authenticated";
GRANT ALL ON TABLE "public"."final_evaluation_answers" TO "service_role";



GRANT ALL ON TABLE "public"."final_evaluation_attempts" TO "anon";
GRANT ALL ON TABLE "public"."final_evaluation_attempts" TO "authenticated";
GRANT ALL ON TABLE "public"."final_evaluation_attempts" TO "service_role";



GRANT ALL ON TABLE "public"."final_evaluation_configs" TO "anon";
GRANT ALL ON TABLE "public"."final_evaluation_configs" TO "authenticated";
GRANT ALL ON TABLE "public"."final_evaluation_configs" TO "service_role";



GRANT ALL ON TABLE "public"."final_evaluation_evaluations" TO "anon";
GRANT ALL ON TABLE "public"."final_evaluation_evaluations" TO "authenticated";
GRANT ALL ON TABLE "public"."final_evaluation_evaluations" TO "service_role";



GRANT ALL ON TABLE "public"."final_evaluation_questions" TO "anon";
GRANT ALL ON TABLE "public"."final_evaluation_questions" TO "authenticated";
GRANT ALL ON TABLE "public"."final_evaluation_questions" TO "service_role";



GRANT ALL ON TABLE "public"."knowledge_change_events" TO "anon";
GRANT ALL ON TABLE "public"."knowledge_change_events" TO "authenticated";
GRANT ALL ON TABLE "public"."knowledge_change_events" TO "service_role";



GRANT ALL ON TABLE "public"."knowledge_items" TO "anon";
GRANT ALL ON TABLE "public"."knowledge_items" TO "authenticated";
GRANT ALL ON TABLE "public"."knowledge_items" TO "service_role";



GRANT ALL ON TABLE "public"."learner_future_questions" TO "anon";
GRANT ALL ON TABLE "public"."learner_future_questions" TO "authenticated";
GRANT ALL ON TABLE "public"."learner_future_questions" TO "service_role";



GRANT ALL ON TABLE "public"."learner_review_decisions" TO "anon";
GRANT ALL ON TABLE "public"."learner_review_decisions" TO "authenticated";
GRANT ALL ON TABLE "public"."learner_review_decisions" TO "service_role";



GRANT ALL ON TABLE "public"."learner_review_validations_v2" TO "service_role";
GRANT SELECT,INSERT ON TABLE "public"."learner_review_validations_v2" TO "authenticated";



GRANT ALL ON TABLE "public"."learner_state_transitions" TO "anon";
GRANT ALL ON TABLE "public"."learner_state_transitions" TO "authenticated";
GRANT ALL ON TABLE "public"."learner_state_transitions" TO "service_role";



GRANT ALL ON TABLE "public"."learner_trainings" TO "anon";
GRANT ALL ON TABLE "public"."learner_trainings" TO "authenticated";
GRANT ALL ON TABLE "public"."learner_trainings" TO "service_role";



GRANT ALL ON TABLE "public"."local_active_program_change_events" TO "anon";
GRANT ALL ON TABLE "public"."local_active_program_change_events" TO "authenticated";
GRANT ALL ON TABLE "public"."local_active_program_change_events" TO "service_role";



GRANT ALL ON TABLE "public"."local_active_programs" TO "anon";
GRANT ALL ON TABLE "public"."local_active_programs" TO "authenticated";
GRANT ALL ON TABLE "public"."local_active_programs" TO "service_role";



GRANT ALL ON TABLE "public"."locals" TO "anon";
GRANT ALL ON TABLE "public"."locals" TO "authenticated";
GRANT ALL ON TABLE "public"."locals" TO "service_role";



GRANT ALL ON TABLE "public"."notification_emails" TO "anon";
GRANT ALL ON TABLE "public"."notification_emails" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_emails" TO "service_role";



GRANT ALL ON TABLE "public"."organizations" TO "anon";
GRANT ALL ON TABLE "public"."organizations" TO "authenticated";
GRANT ALL ON TABLE "public"."organizations" TO "service_role";



GRANT ALL ON TABLE "public"."practice_attempt_events" TO "anon";
GRANT ALL ON TABLE "public"."practice_attempt_events" TO "authenticated";
GRANT ALL ON TABLE "public"."practice_attempt_events" TO "service_role";



GRANT ALL ON TABLE "public"."practice_attempts" TO "anon";
GRANT ALL ON TABLE "public"."practice_attempts" TO "authenticated";
GRANT ALL ON TABLE "public"."practice_attempts" TO "service_role";



GRANT ALL ON TABLE "public"."practice_evaluations" TO "anon";
GRANT ALL ON TABLE "public"."practice_evaluations" TO "authenticated";
GRANT ALL ON TABLE "public"."practice_evaluations" TO "service_role";



GRANT ALL ON TABLE "public"."practice_scenarios" TO "anon";
GRANT ALL ON TABLE "public"."practice_scenarios" TO "authenticated";
GRANT ALL ON TABLE "public"."practice_scenarios" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."training_programs" TO "anon";
GRANT ALL ON TABLE "public"."training_programs" TO "authenticated";
GRANT ALL ON TABLE "public"."training_programs" TO "service_role";



GRANT ALL ON TABLE "public"."training_units" TO "anon";
GRANT ALL ON TABLE "public"."training_units" TO "authenticated";
GRANT ALL ON TABLE "public"."training_units" TO "service_role";



GRANT ALL ON TABLE "public"."unit_knowledge_map" TO "anon";
GRANT ALL ON TABLE "public"."unit_knowledge_map" TO "authenticated";
GRANT ALL ON TABLE "public"."unit_knowledge_map" TO "service_role";



GRANT ALL ON TABLE "public"."v_conversation_thread" TO "anon";
GRANT ALL ON TABLE "public"."v_conversation_thread" TO "authenticated";
GRANT ALL ON TABLE "public"."v_conversation_thread" TO "service_role";



GRANT ALL ON TABLE "public"."v_learner_active_conversation" TO "anon";
GRANT ALL ON TABLE "public"."v_learner_active_conversation" TO "authenticated";
GRANT ALL ON TABLE "public"."v_learner_active_conversation" TO "service_role";



GRANT ALL ON TABLE "public"."v_learner_doubt_signals" TO "anon";
GRANT ALL ON TABLE "public"."v_learner_doubt_signals" TO "authenticated";
GRANT ALL ON TABLE "public"."v_learner_doubt_signals" TO "service_role";



GRANT ALL ON TABLE "public"."v_learner_evaluation_summary" TO "anon";
GRANT ALL ON TABLE "public"."v_learner_evaluation_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."v_learner_evaluation_summary" TO "service_role";



GRANT ALL ON TABLE "public"."v_learner_evidence" TO "anon";
GRANT ALL ON TABLE "public"."v_learner_evidence" TO "authenticated";
GRANT ALL ON TABLE "public"."v_learner_evidence" TO "service_role";



GRANT ALL ON TABLE "public"."v_learner_progress" TO "anon";
GRANT ALL ON TABLE "public"."v_learner_progress" TO "authenticated";
GRANT ALL ON TABLE "public"."v_learner_progress" TO "service_role";



GRANT ALL ON TABLE "public"."v_learner_training_home" TO "anon";
GRANT ALL ON TABLE "public"."v_learner_training_home" TO "authenticated";
GRANT ALL ON TABLE "public"."v_learner_training_home" TO "service_role";



GRANT ALL ON TABLE "public"."v_learner_wrong_answers" TO "anon";
GRANT ALL ON TABLE "public"."v_learner_wrong_answers" TO "authenticated";
GRANT ALL ON TABLE "public"."v_learner_wrong_answers" TO "service_role";



GRANT ALL ON TABLE "public"."v_local_learner_risk_30d" TO "anon";
GRANT ALL ON TABLE "public"."v_local_learner_risk_30d" TO "authenticated";
GRANT ALL ON TABLE "public"."v_local_learner_risk_30d" TO "service_role";



GRANT ALL ON TABLE "public"."v_local_top_gaps_30d" TO "anon";
GRANT ALL ON TABLE "public"."v_local_top_gaps_30d" TO "authenticated";
GRANT ALL ON TABLE "public"."v_local_top_gaps_30d" TO "service_role";



GRANT ALL ON TABLE "public"."v_local_unit_coverage_30d" TO "anon";
GRANT ALL ON TABLE "public"."v_local_unit_coverage_30d" TO "authenticated";
GRANT ALL ON TABLE "public"."v_local_unit_coverage_30d" TO "service_role";



GRANT ALL ON TABLE "public"."v_org_gap_locals_30d" TO "anon";
GRANT ALL ON TABLE "public"."v_org_gap_locals_30d" TO "authenticated";
GRANT ALL ON TABLE "public"."v_org_gap_locals_30d" TO "service_role";



GRANT ALL ON TABLE "public"."v_org_learner_risk_30d" TO "anon";
GRANT ALL ON TABLE "public"."v_org_learner_risk_30d" TO "authenticated";
GRANT ALL ON TABLE "public"."v_org_learner_risk_30d" TO "service_role";



GRANT ALL ON TABLE "public"."v_org_local_active_programs" TO "anon";
GRANT ALL ON TABLE "public"."v_org_local_active_programs" TO "authenticated";
GRANT ALL ON TABLE "public"."v_org_local_active_programs" TO "service_role";



GRANT ALL ON TABLE "public"."v_org_program_final_eval_config_current" TO "anon";
GRANT ALL ON TABLE "public"."v_org_program_final_eval_config_current" TO "authenticated";
GRANT ALL ON TABLE "public"."v_org_program_final_eval_config_current" TO "service_role";



GRANT ALL ON TABLE "public"."v_org_program_final_eval_config_history" TO "anon";
GRANT ALL ON TABLE "public"."v_org_program_final_eval_config_history" TO "authenticated";
GRANT ALL ON TABLE "public"."v_org_program_final_eval_config_history" TO "service_role";



GRANT ALL ON TABLE "public"."v_org_program_unit_knowledge_coverage" TO "anon";
GRANT ALL ON TABLE "public"."v_org_program_unit_knowledge_coverage" TO "authenticated";
GRANT ALL ON TABLE "public"."v_org_program_unit_knowledge_coverage" TO "service_role";



GRANT ALL ON TABLE "public"."v_org_program_knowledge_gaps_summary" TO "anon";
GRANT ALL ON TABLE "public"."v_org_program_knowledge_gaps_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."v_org_program_knowledge_gaps_summary" TO "service_role";



GRANT ALL ON TABLE "public"."v_org_top_gaps_30d" TO "anon";
GRANT ALL ON TABLE "public"."v_org_top_gaps_30d" TO "authenticated";
GRANT ALL ON TABLE "public"."v_org_top_gaps_30d" TO "service_role";



GRANT ALL ON TABLE "public"."v_org_unit_coverage_30d" TO "anon";
GRANT ALL ON TABLE "public"."v_org_unit_coverage_30d" TO "authenticated";
GRANT ALL ON TABLE "public"."v_org_unit_coverage_30d" TO "service_role";



GRANT ALL ON TABLE "public"."v_org_recommended_actions_30d" TO "anon";
GRANT ALL ON TABLE "public"."v_org_recommended_actions_30d" TO "authenticated";
GRANT ALL ON TABLE "public"."v_org_recommended_actions_30d" TO "service_role";



GRANT ALL ON TABLE "public"."v_org_recommended_actions_playbooks_30d" TO "anon";
GRANT ALL ON TABLE "public"."v_org_recommended_actions_playbooks_30d" TO "authenticated";
GRANT ALL ON TABLE "public"."v_org_recommended_actions_playbooks_30d" TO "service_role";



GRANT ALL ON TABLE "public"."v_org_unit_knowledge_active" TO "anon";
GRANT ALL ON TABLE "public"."v_org_unit_knowledge_active" TO "authenticated";
GRANT ALL ON TABLE "public"."v_org_unit_knowledge_active" TO "service_role";



GRANT ALL ON TABLE "public"."v_org_unit_knowledge_list" TO "anon";
GRANT ALL ON TABLE "public"."v_org_unit_knowledge_list" TO "authenticated";
GRANT ALL ON TABLE "public"."v_org_unit_knowledge_list" TO "service_role";



GRANT ALL ON TABLE "public"."v_referente_conversation_summary" TO "anon";
GRANT ALL ON TABLE "public"."v_referente_conversation_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."v_referente_conversation_summary" TO "service_role";



GRANT ALL ON TABLE "public"."v_referente_learners" TO "anon";
GRANT ALL ON TABLE "public"."v_referente_learners" TO "authenticated";
GRANT ALL ON TABLE "public"."v_referente_learners" TO "service_role";



GRANT ALL ON TABLE "public"."v_referente_practice_summary" TO "anon";
GRANT ALL ON TABLE "public"."v_referente_practice_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."v_referente_practice_summary" TO "service_role";



GRANT ALL ON TABLE "public"."v_review_queue" TO "anon";
GRANT ALL ON TABLE "public"."v_review_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."v_review_queue" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







