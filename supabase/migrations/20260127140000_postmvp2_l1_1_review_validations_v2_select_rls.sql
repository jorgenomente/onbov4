-- POST-MVP 2 / SUB-LOTE L.1.1: Ajuste SELECT RLS (no confiar en snapshots)

-- Reemplazar policies SELECT para admin_org y referente
DROP POLICY IF EXISTS learner_review_validations_v2_select_admin_org ON public.learner_review_validations_v2;
DROP POLICY IF EXISTS learner_review_validations_v2_select_referente ON public.learner_review_validations_v2;

CREATE POLICY learner_review_validations_v2_select_admin_org
ON public.learner_review_validations_v2
FOR SELECT
USING (
  public.current_role() = 'admin_org'::public.app_role
  AND EXISTS (
    SELECT 1
    FROM public.learner_trainings lt
    JOIN public.locals l ON l.id = lt.local_id
    WHERE lt.learner_id = learner_review_validations_v2.learner_id
      AND l.org_id = public.current_org_id()
  )
);

CREATE POLICY learner_review_validations_v2_select_referente
ON public.learner_review_validations_v2
FOR SELECT
USING (
  public.current_role() = 'referente'::public.app_role
  AND EXISTS (
    SELECT 1
    FROM public.learner_trainings lt
    WHERE lt.learner_id = learner_review_validations_v2.learner_id
      AND lt.local_id = public.current_local_id()
  )
);
