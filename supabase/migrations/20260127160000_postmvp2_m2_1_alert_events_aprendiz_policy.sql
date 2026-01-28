-- POST-MVP 2 / SUB-LOTE M.2.1: Allow aprendiz insert for final_evaluation_submitted

CREATE POLICY alert_events_insert_aprendiz_final_evaluation
ON public.alert_events
FOR INSERT
WITH CHECK (
  public.current_role() = 'aprendiz'::public.app_role
  AND alert_events.alert_type = 'final_evaluation_submitted'::public.alert_type
  AND alert_events.learner_id = auth.uid()
  AND alert_events.source_table = 'final_evaluation_attempts'
  AND EXISTS (
    SELECT 1
    FROM public.final_evaluation_attempts a
    JOIN public.learner_trainings lt ON lt.learner_id = a.learner_id
    JOIN public.locals l ON l.id = lt.local_id
    WHERE a.id = alert_events.source_id
      AND a.learner_id = auth.uid()
      AND alert_events.local_id = lt.local_id
      AND alert_events.org_id = l.org_id
  )
);
