-- POST-MVP 2 / SUB-LOTE L.1: Validacion humana v2 (append-only) + RLS

-- 1) Enums (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'decision_type_v2') THEN
    CREATE TYPE public.decision_type_v2 AS ENUM ('approve', 'reject', 'request_reinforcement');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'perceived_severity') THEN
    CREATE TYPE public.perceived_severity AS ENUM ('low', 'medium', 'high');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'recommended_action') THEN
    CREATE TYPE public.recommended_action AS ENUM ('none', 'follow_up', 'retraining');
  END IF;
END$$;

-- 2) Tabla v2 (append-only)
CREATE TABLE IF NOT EXISTS public.learner_review_validations_v2 (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  learner_id uuid NOT NULL,
  reviewer_id uuid NOT NULL,
  local_id uuid NOT NULL,
  program_id uuid NOT NULL,
  decision_type public.decision_type_v2 NOT NULL,
  perceived_severity public.perceived_severity NOT NULL DEFAULT 'low',
  recommended_action public.recommended_action NOT NULL DEFAULT 'none',
  checklist jsonb NOT NULL DEFAULT '{}'::jsonb,
  comment text,
  reviewer_name text NOT NULL,
  reviewer_role public.app_role NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT learner_review_validations_v2_pkey PRIMARY KEY (id),
  CONSTRAINT learner_review_validations_v2_checklist_object CHECK (jsonb_typeof(checklist) = 'object')
);

ALTER TABLE public.learner_review_validations_v2 OWNER TO postgres;

ALTER TABLE ONLY public.learner_review_validations_v2
  ADD CONSTRAINT learner_review_validations_v2_learner_id_fkey
  FOREIGN KEY (learner_id) REFERENCES public.profiles(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY public.learner_review_validations_v2
  ADD CONSTRAINT learner_review_validations_v2_reviewer_id_fkey
  FOREIGN KEY (reviewer_id) REFERENCES public.profiles(user_id) ON DELETE RESTRICT;

ALTER TABLE ONLY public.learner_review_validations_v2
  ADD CONSTRAINT learner_review_validations_v2_local_id_fkey
  FOREIGN KEY (local_id) REFERENCES public.locals(id) ON DELETE RESTRICT;

ALTER TABLE ONLY public.learner_review_validations_v2
  ADD CONSTRAINT learner_review_validations_v2_program_id_fkey
  FOREIGN KEY (program_id) REFERENCES public.training_programs(id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS learner_review_validations_v2_learner_created_at_idx
  ON public.learner_review_validations_v2 (learner_id, created_at DESC);

CREATE INDEX IF NOT EXISTS learner_review_validations_v2_local_created_at_idx
  ON public.learner_review_validations_v2 (local_id, created_at DESC);

CREATE INDEX IF NOT EXISTS learner_review_validations_v2_program_created_at_idx
  ON public.learner_review_validations_v2 (program_id, created_at DESC);

CREATE INDEX IF NOT EXISTS learner_review_validations_v2_decision_created_at_idx
  ON public.learner_review_validations_v2 (decision_type, created_at DESC);

-- 3) Append-only trigger
CREATE OR REPLACE TRIGGER trg_learner_review_validations_v2_prevent_update
BEFORE UPDATE OR DELETE ON public.learner_review_validations_v2
FOR EACH ROW EXECUTE FUNCTION public.prevent_update_delete();

-- 4) RLS
ALTER TABLE public.learner_review_validations_v2 ENABLE ROW LEVEL SECURITY;

-- SELECT policies
CREATE POLICY learner_review_validations_v2_select_superadmin
ON public.learner_review_validations_v2
FOR SELECT
USING (public.current_role() = 'superadmin'::public.app_role);

CREATE POLICY learner_review_validations_v2_select_admin_org
ON public.learner_review_validations_v2
FOR SELECT
USING (
  public.current_role() = 'admin_org'::public.app_role
  AND EXISTS (
    SELECT 1
    FROM public.locals l
    WHERE l.id = learner_review_validations_v2.local_id
      AND l.org_id = public.current_org_id()
  )
);

CREATE POLICY learner_review_validations_v2_select_referente
ON public.learner_review_validations_v2
FOR SELECT
USING (
  public.current_role() = 'referente'::public.app_role
  AND learner_review_validations_v2.local_id = public.current_local_id()
);

CREATE POLICY learner_review_validations_v2_select_aprendiz
ON public.learner_review_validations_v2
FOR SELECT
USING (
  public.current_role() = 'aprendiz'::public.app_role
  AND learner_review_validations_v2.learner_id = auth.uid()
);

-- INSERT policies
CREATE POLICY learner_review_validations_v2_insert_reviewer
ON public.learner_review_validations_v2
FOR INSERT
WITH CHECK (
  reviewer_id = auth.uid()
  AND public.current_role() = ANY (ARRAY['superadmin'::public.app_role, 'admin_org'::public.app_role, 'referente'::public.app_role])
  AND (
    public.current_role() = 'superadmin'::public.app_role
    OR EXISTS (
      SELECT 1
      FROM public.learner_trainings lt
      JOIN public.locals l ON l.id = lt.local_id
      WHERE lt.learner_id = learner_review_validations_v2.learner_id
        AND (
          (public.current_role() = 'admin_org'::public.app_role AND l.org_id = public.current_org_id())
          OR (public.current_role() = 'referente'::public.app_role AND lt.local_id = public.current_local_id())
        )
    )
  )
);

-- 5) Grants (sin anon)
REVOKE ALL ON TABLE public.learner_review_validations_v2 FROM anon;
REVOKE ALL ON TABLE public.learner_review_validations_v2 FROM authenticated;
GRANT SELECT, INSERT ON TABLE public.learner_review_validations_v2 TO authenticated;
