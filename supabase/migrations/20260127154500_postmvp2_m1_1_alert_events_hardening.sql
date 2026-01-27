-- POST-MVP 2 / SUB-LOTE M.1.1: Hardening alert_events (FK + RLS)

-- 1) Ajuste FK learner_id (no cascade)
ALTER TABLE public.alert_events
  DROP CONSTRAINT IF EXISTS alert_events_learner_id_fkey;

ALTER TABLE public.alert_events
  ADD CONSTRAINT alert_events_learner_id_fkey
  FOREIGN KEY (learner_id) REFERENCES public.profiles(user_id) ON DELETE RESTRICT;

-- 2) Hardening INSERT policy (coherencia org/local)
DROP POLICY IF EXISTS alert_events_insert_reviewer ON public.alert_events;

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
        AND alert_events.local_id = lt.local_id
        AND alert_events.org_id = l.org_id
        AND (
          (public.current_role() = 'admin_org'::public.app_role AND l.org_id = public.current_org_id())
          OR (public.current_role() = 'referente'::public.app_role AND lt.local_id = public.current_local_id())
        )
    )
  )
);
