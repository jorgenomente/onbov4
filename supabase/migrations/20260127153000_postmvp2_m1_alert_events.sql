-- POST-MVP 2 / SUB-LOTE M.1: Alertas (eventos) DB-first + RLS

-- 1) Enum alert_type (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'alert_type') THEN
    CREATE TYPE public.alert_type AS ENUM (
      'review_submitted_v2',
      'review_rejected_v2',
      'review_reinforcement_requested_v2',
      'learner_at_risk',
      'final_evaluation_submitted'
    );
  END IF;
END$$;

-- 2) Tabla alert_events (append-only)
CREATE TABLE IF NOT EXISTS public.alert_events (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  alert_type public.alert_type NOT NULL,
  learner_id uuid NOT NULL,
  local_id uuid NOT NULL,
  org_id uuid NOT NULL,
  source_table text NOT NULL,
  source_id uuid NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT alert_events_pkey PRIMARY KEY (id),
  CONSTRAINT alert_events_payload_object CHECK (jsonb_typeof(payload) = 'object')
);

ALTER TABLE public.alert_events OWNER TO postgres;

ALTER TABLE ONLY public.alert_events
  ADD CONSTRAINT alert_events_learner_id_fkey
  FOREIGN KEY (learner_id) REFERENCES public.profiles(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY public.alert_events
  ADD CONSTRAINT alert_events_local_id_fkey
  FOREIGN KEY (local_id) REFERENCES public.locals(id) ON DELETE RESTRICT;

ALTER TABLE ONLY public.alert_events
  ADD CONSTRAINT alert_events_org_id_fkey
  FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;

-- source_id is generic and intentionally not constrained by FK

CREATE INDEX IF NOT EXISTS alert_events_org_created_at_idx
  ON public.alert_events (org_id, created_at DESC);

CREATE INDEX IF NOT EXISTS alert_events_local_created_at_idx
  ON public.alert_events (local_id, created_at DESC);

CREATE INDEX IF NOT EXISTS alert_events_learner_created_at_idx
  ON public.alert_events (learner_id, created_at DESC);

CREATE INDEX IF NOT EXISTS alert_events_type_created_at_idx
  ON public.alert_events (alert_type, created_at DESC);

-- 3) Append-only trigger
CREATE OR REPLACE TRIGGER trg_alert_events_prevent_update
BEFORE UPDATE OR DELETE ON public.alert_events
FOR EACH ROW EXECUTE FUNCTION public.prevent_update_delete();

-- 4) RLS
ALTER TABLE public.alert_events ENABLE ROW LEVEL SECURITY;

-- SELECT policies
CREATE POLICY alert_events_select_superadmin
ON public.alert_events
FOR SELECT
USING (public.current_role() = 'superadmin'::public.app_role);

CREATE POLICY alert_events_select_admin_org
ON public.alert_events
FOR SELECT
USING (
  public.current_role() = 'admin_org'::public.app_role
  AND alert_events.org_id = public.current_org_id()
);

CREATE POLICY alert_events_select_referente
ON public.alert_events
FOR SELECT
USING (
  public.current_role() = 'referente'::public.app_role
  AND alert_events.local_id = public.current_local_id()
);

CREATE POLICY alert_events_select_aprendiz
ON public.alert_events
FOR SELECT
USING (
  public.current_role() = 'aprendiz'::public.app_role
  AND alert_events.learner_id = auth.uid()
);

-- INSERT policies (server-only via RLS scope)
CREATE POLICY alert_events_insert_reviewer
ON public.alert_events
FOR INSERT
WITH CHECK (
  public.current_role() = ANY (ARRAY['superadmin'::public.app_role, 'admin_org'::public.app_role, 'referente'::public.app_role])
  AND (
    public.current_role() = 'superadmin'::public.app_role
    OR EXISTS (
      SELECT 1
      FROM public.learner_trainings lt
      JOIN public.locals l ON l.id = lt.local_id
      WHERE lt.learner_id = alert_events.learner_id
        AND (
          (public.current_role() = 'admin_org'::public.app_role AND l.org_id = public.current_org_id())
          OR (public.current_role() = 'referente'::public.app_role AND lt.local_id = public.current_local_id())
        )
    )
  )
);

-- 5) Grants (sin anon)
REVOKE ALL ON TABLE public.alert_events FROM anon;
REVOKE ALL ON TABLE public.alert_events FROM authenticated;
GRANT SELECT, INSERT ON TABLE public.alert_events TO authenticated;
