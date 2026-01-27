


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



CREATE TYPE "public"."app_role" AS ENUM (
    'superadmin',
    'admin_org',
    'referente',
    'aprendiz'
);


ALTER TYPE "public"."app_role" OWNER TO "postgres";


CREATE TYPE "public"."learner_status" AS ENUM (
    'en_entrenamiento',
    'en_practica',
    'en_riesgo',
    'en_revision',
    'aprobado'
);


ALTER TYPE "public"."learner_status" OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."prevent_update_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  raise exception 'append-only table: % is not allowed', tg_op;
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


CREATE TABLE IF NOT EXISTS "public"."knowledge_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "local_id" "uuid",
    "title" "text" NOT NULL,
    "content" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."knowledge_items" OWNER TO "postgres";


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



ALTER TABLE ONLY "public"."knowledge_items"
    ADD CONSTRAINT "knowledge_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."learner_review_decisions"
    ADD CONSTRAINT "learner_review_decisions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."learner_state_transitions"
    ADD CONSTRAINT "learner_state_transitions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."learner_trainings"
    ADD CONSTRAINT "learner_trainings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."learner_trainings"
    ADD CONSTRAINT "learner_trainings_unique_learner" UNIQUE ("learner_id");



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



CREATE INDEX "knowledge_items_local_id_idx" ON "public"."knowledge_items" USING "btree" ("local_id");



CREATE INDEX "knowledge_items_org_id_idx" ON "public"."knowledge_items" USING "btree" ("org_id");



CREATE INDEX "learner_review_decisions_created_at_idx" ON "public"."learner_review_decisions" USING "btree" ("created_at");



CREATE INDEX "learner_review_decisions_learner_id_idx" ON "public"."learner_review_decisions" USING "btree" ("learner_id");



CREATE INDEX "learner_review_decisions_reviewer_id_idx" ON "public"."learner_review_decisions" USING "btree" ("reviewer_id");



CREATE INDEX "learner_state_transitions_created_at_idx" ON "public"."learner_state_transitions" USING "btree" ("created_at");



CREATE INDEX "learner_state_transitions_learner_id_idx" ON "public"."learner_state_transitions" USING "btree" ("learner_id");



CREATE INDEX "learner_state_transitions_to_status_idx" ON "public"."learner_state_transitions" USING "btree" ("to_status");



CREATE INDEX "learner_trainings_local_id_idx" ON "public"."learner_trainings" USING "btree" ("local_id");



CREATE INDEX "learner_trainings_program_id_idx" ON "public"."learner_trainings" USING "btree" ("program_id");



CREATE INDEX "learner_trainings_status_idx" ON "public"."learner_trainings" USING "btree" ("status");



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



CREATE OR REPLACE TRIGGER "trg_bot_message_evaluations_prevent_update" BEFORE DELETE OR UPDATE ON "public"."bot_message_evaluations" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_conversation_messages_prevent_update" BEFORE DELETE OR UPDATE ON "public"."conversation_messages" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_conversations_prevent_update" BEFORE DELETE OR UPDATE ON "public"."conversations" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_final_evaluation_answers_prevent_update" BEFORE DELETE OR UPDATE ON "public"."final_evaluation_answers" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_final_evaluation_evaluations_prevent_update" BEFORE DELETE OR UPDATE ON "public"."final_evaluation_evaluations" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_final_evaluation_questions_prevent_update" BEFORE DELETE OR UPDATE ON "public"."final_evaluation_questions" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_learner_review_decisions_prevent_update" BEFORE DELETE OR UPDATE ON "public"."learner_review_decisions" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_learner_trainings_set_updated_at" BEFORE UPDATE ON "public"."learner_trainings" FOR EACH ROW EXECUTE FUNCTION "public"."set_learner_training_updated_at"();



CREATE OR REPLACE TRIGGER "trg_notification_emails_prevent_update" BEFORE DELETE OR UPDATE ON "public"."notification_emails" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_practice_attempt_events_prevent_update" BEFORE DELETE OR UPDATE ON "public"."practice_attempt_events" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_practice_attempts_prevent_update" BEFORE DELETE OR UPDATE ON "public"."practice_attempts" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_practice_evaluations_prevent_update" BEFORE DELETE OR UPDATE ON "public"."practice_evaluations" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_update_delete"();



CREATE OR REPLACE TRIGGER "trg_profiles_guard_update" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."guard_profiles_update"();



CREATE OR REPLACE TRIGGER "trg_profiles_set_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_profile_updated_at"();



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



ALTER TABLE ONLY "public"."knowledge_items"
    ADD CONSTRAINT "knowledge_items_local_id_fkey" FOREIGN KEY ("local_id") REFERENCES "public"."locals"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."knowledge_items"
    ADD CONSTRAINT "knowledge_items_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."learner_review_decisions"
    ADD CONSTRAINT "learner_review_decisions_learner_id_fkey" FOREIGN KEY ("learner_id") REFERENCES "public"."profiles"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."learner_review_decisions"
    ADD CONSTRAINT "learner_review_decisions_reviewer_id_fkey" FOREIGN KEY ("reviewer_id") REFERENCES "public"."profiles"("user_id") ON DELETE RESTRICT;



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
  WHERE (("q"."id" = "final_evaluation_answers"."question_id") AND ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("a"."learner_id" = "auth"."uid"())) OR ("public"."current_role"() = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])))))));



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
  WHERE (("ans"."id" = "final_evaluation_evaluations"."answer_id") AND ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("a"."learner_id" = "auth"."uid"())) OR ("public"."current_role"() = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])))))));



ALTER TABLE "public"."final_evaluation_questions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "final_evaluation_questions_insert_learner" ON "public"."final_evaluation_questions" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."final_evaluation_attempts" "a"
  WHERE (("a"."id" = "final_evaluation_questions"."attempt_id") AND ("a"."learner_id" = "auth"."uid"())))));



CREATE POLICY "final_evaluation_questions_select_visible" ON "public"."final_evaluation_questions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."final_evaluation_attempts" "a"
  WHERE (("a"."id" = "final_evaluation_questions"."attempt_id") AND ((("public"."current_role"() = 'aprendiz'::"public"."app_role") AND ("a"."learner_id" = "auth"."uid"())) OR ("public"."current_role"() = ANY (ARRAY['superadmin'::"public"."app_role", 'admin_org'::"public"."app_role", 'referente'::"public"."app_role"])))))));



ALTER TABLE "public"."knowledge_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "knowledge_items_select_admin_org" ON "public"."knowledge_items" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND ("org_id" = "public"."current_org_id"())));



CREATE POLICY "knowledge_items_select_local_roles" ON "public"."knowledge_items" FOR SELECT USING ((("public"."current_role"() = ANY (ARRAY['referente'::"public"."app_role", 'aprendiz'::"public"."app_role"])) AND ("org_id" = "public"."current_org_id"()) AND (("local_id" IS NULL) OR ("local_id" = "public"."current_local_id"()))));



CREATE POLICY "knowledge_items_select_superadmin" ON "public"."knowledge_items" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



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



ALTER TABLE "public"."local_active_programs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "local_active_programs_select_admin_org" ON "public"."local_active_programs" FOR SELECT USING ((("public"."current_role"() = 'admin_org'::"public"."app_role") AND (EXISTS ( SELECT 1
   FROM "public"."locals" "l"
  WHERE (("l"."id" = "local_active_programs"."local_id") AND ("l"."org_id" = "public"."current_org_id"()))))));



CREATE POLICY "local_active_programs_select_local_roles" ON "public"."local_active_programs" FOR SELECT USING ((("public"."current_role"() = ANY (ARRAY['referente'::"public"."app_role", 'aprendiz'::"public"."app_role"])) AND ("local_id" = "public"."current_local_id"())));



CREATE POLICY "local_active_programs_select_superadmin" ON "public"."local_active_programs" FOR SELECT USING (("public"."current_role"() = 'superadmin'::"public"."app_role"));



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


CREATE POLICY "unit_knowledge_map_select_visible" ON "public"."unit_knowledge_map" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."knowledge_items" "ki"
  WHERE ("ki"."id" = "unit_knowledge_map"."knowledge_id"))));



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



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



GRANT ALL ON FUNCTION "public"."get_user_email"("target_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_email"("target_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_email"("target_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."guard_profiles_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."guard_profiles_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."guard_profiles_update"() TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_update_delete"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_update_delete"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_update_delete"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_learner_training_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_learner_training_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_learner_training_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_profile_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_profile_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_profile_updated_at"() TO "service_role";



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



GRANT ALL ON TABLE "public"."knowledge_items" TO "anon";
GRANT ALL ON TABLE "public"."knowledge_items" TO "authenticated";
GRANT ALL ON TABLE "public"."knowledge_items" TO "service_role";



GRANT ALL ON TABLE "public"."learner_review_decisions" TO "anon";
GRANT ALL ON TABLE "public"."learner_review_decisions" TO "authenticated";
GRANT ALL ON TABLE "public"."learner_review_decisions" TO "service_role";



GRANT ALL ON TABLE "public"."learner_state_transitions" TO "anon";
GRANT ALL ON TABLE "public"."learner_state_transitions" TO "authenticated";
GRANT ALL ON TABLE "public"."learner_state_transitions" TO "service_role";



GRANT ALL ON TABLE "public"."learner_trainings" TO "anon";
GRANT ALL ON TABLE "public"."learner_trainings" TO "authenticated";
GRANT ALL ON TABLE "public"."learner_trainings" TO "service_role";



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



GRANT ALL ON TABLE "public"."v_learner_evidence" TO "anon";
GRANT ALL ON TABLE "public"."v_learner_evidence" TO "authenticated";
GRANT ALL ON TABLE "public"."v_learner_evidence" TO "service_role";



GRANT ALL ON TABLE "public"."v_learner_progress" TO "anon";
GRANT ALL ON TABLE "public"."v_learner_progress" TO "authenticated";
GRANT ALL ON TABLE "public"."v_learner_progress" TO "service_role";



GRANT ALL ON TABLE "public"."v_learner_training_home" TO "anon";
GRANT ALL ON TABLE "public"."v_learner_training_home" TO "authenticated";
GRANT ALL ON TABLE "public"."v_learner_training_home" TO "service_role";



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







