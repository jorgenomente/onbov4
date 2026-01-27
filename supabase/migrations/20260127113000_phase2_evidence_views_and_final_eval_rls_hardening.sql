/*
Fase 2 / Sub-lote F — Views de evidencia + hardening RLS (read-only)

- Crea:
  - v_learner_evaluation_summary
  - v_learner_wrong_answers
  - v_learner_doubt_signals

- Endurece RLS (evita cross-tenant) en:
  - final_evaluation_questions
  - final_evaluation_answers
  - final_evaluation_evaluations

Nota:
- Estas views NIEGAN aprendiz por definición (no RLS en views),
  y filtran por local/org usando current_local_id/current_org_id.
*/

begin;

-- =========================================================
-- 1) RLS hardening: final_evaluation_* (SELECT tenant-scoped)
-- =========================================================

-- final_evaluation_questions
DROP POLICY IF EXISTS final_evaluation_questions_select_visible ON public.final_evaluation_questions;

CREATE POLICY final_evaluation_questions_select_visible
ON public.final_evaluation_questions
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.final_evaluation_attempts a
    WHERE a.id = public.final_evaluation_questions.attempt_id
      AND (
        -- aprendiz: solo sus intentos
        (public.current_role() = 'aprendiz' AND a.learner_id = auth.uid())

        -- referente: mismo local (via learner_trainings)
        OR (
          public.current_role() = 'referente'
          AND EXISTS (
            SELECT 1
            FROM public.learner_trainings lt
            WHERE lt.learner_id = a.learner_id
              AND lt.program_id = a.program_id
              AND lt.local_id = public.current_local_id()
          )
        )

        -- admin_org: misma org (via locals)
        OR (
          public.current_role() = 'admin_org'
          AND EXISTS (
            SELECT 1
            FROM public.learner_trainings lt
            JOIN public.locals l ON l.id = lt.local_id
            WHERE lt.learner_id = a.learner_id
              AND lt.program_id = a.program_id
              AND l.org_id = public.current_org_id()
          )
        )

        -- superadmin: todo
        OR (public.current_role() = 'superadmin')
      )
  )
);

-- final_evaluation_answers
DROP POLICY IF EXISTS final_evaluation_answers_select_visible ON public.final_evaluation_answers;

CREATE POLICY final_evaluation_answers_select_visible
ON public.final_evaluation_answers
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.final_evaluation_questions q
    JOIN public.final_evaluation_attempts a ON a.id = q.attempt_id
    WHERE q.id = public.final_evaluation_answers.question_id
      AND (
        (public.current_role() = 'aprendiz' AND a.learner_id = auth.uid())
        OR (
          public.current_role() = 'referente'
          AND EXISTS (
            SELECT 1
            FROM public.learner_trainings lt
            WHERE lt.learner_id = a.learner_id
              AND lt.program_id = a.program_id
              AND lt.local_id = public.current_local_id()
          )
        )
        OR (
          public.current_role() = 'admin_org'
          AND EXISTS (
            SELECT 1
            FROM public.learner_trainings lt
            JOIN public.locals l ON l.id = lt.local_id
            WHERE lt.learner_id = a.learner_id
              AND lt.program_id = a.program_id
              AND l.org_id = public.current_org_id()
          )
        )
        OR (public.current_role() = 'superadmin')
      )
  )
);

-- final_evaluation_evaluations
DROP POLICY IF EXISTS final_evaluation_evaluations_select_visible ON public.final_evaluation_evaluations;

CREATE POLICY final_evaluation_evaluations_select_visible
ON public.final_evaluation_evaluations
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.final_evaluation_answers ans
    JOIN public.final_evaluation_questions q ON q.id = ans.question_id
    JOIN public.final_evaluation_attempts a ON a.id = q.attempt_id
    WHERE ans.id = public.final_evaluation_evaluations.answer_id
      AND (
        (public.current_role() = 'aprendiz' AND a.learner_id = auth.uid())
        OR (
          public.current_role() = 'referente'
          AND EXISTS (
            SELECT 1
            FROM public.learner_trainings lt
            WHERE lt.learner_id = a.learner_id
              AND lt.program_id = a.program_id
              AND lt.local_id = public.current_local_id()
          )
        )
        OR (
          public.current_role() = 'admin_org'
          AND EXISTS (
            SELECT 1
            FROM public.learner_trainings lt
            JOIN public.locals l ON l.id = lt.local_id
            WHERE lt.learner_id = a.learner_id
              AND lt.program_id = a.program_id
              AND l.org_id = public.current_org_id()
          )
        )
        OR (public.current_role() = 'superadmin')
      )
  )
);

-- =========================================================
-- 2) Views — evidencia (read-only)
-- =========================================================

-- A) Resumen por unidad (final evaluation)
CREATE OR REPLACE VIEW public.v_learner_evaluation_summary AS
WITH scoped_attempts AS (
  SELECT
    a.id AS attempt_id,
    a.learner_id,
    a.program_id,
    a.attempt_number,
    a.status,
    a.global_score,
    a.bot_recommendation,
    a.started_at,
    a.ended_at,
    a.created_at,
    lt.local_id,
    l.org_id
  FROM public.final_evaluation_attempts a
  JOIN public.learner_trainings lt
    ON lt.learner_id = a.learner_id
   AND lt.program_id = a.program_id
  JOIN public.locals l
    ON l.id = lt.local_id
  WHERE
    public.current_role() IN ('superadmin','admin_org','referente')
    AND (
      public.current_role() = 'superadmin'
      OR (public.current_role() = 'admin_org' AND l.org_id = public.current_org_id())
      OR (public.current_role() = 'referente' AND lt.local_id = public.current_local_id())
    )
)
SELECT
  sa.org_id,
  sa.local_id,
  sa.learner_id,
  sa.program_id,
  sa.attempt_id,
  sa.attempt_number,
  sa.status,
  sa.global_score,
  sa.bot_recommendation,
  q.unit_order,
  COUNT(*)::int AS total_questions,
  AVG(ev.score)::numeric(5,2) AS avg_score,
  COUNT(*) FILTER (WHERE ev.verdict = 'pass')::int AS pass_count,
  COUNT(*) FILTER (WHERE ev.verdict = 'partial')::int AS partial_count,
  COUNT(*) FILTER (WHERE ev.verdict = 'fail')::int AS fail_count,
  MAX(ev.created_at) AS last_evaluated_at
FROM scoped_attempts sa
JOIN public.final_evaluation_questions q
  ON q.attempt_id = sa.attempt_id
LEFT JOIN public.final_evaluation_answers ans
  ON ans.question_id = q.id
LEFT JOIN public.final_evaluation_evaluations ev
  ON ev.answer_id = ans.id
GROUP BY
  sa.org_id,
  sa.local_id,
  sa.learner_id,
  sa.program_id,
  sa.attempt_id,
  sa.attempt_number,
  sa.status,
  sa.global_score,
  sa.bot_recommendation,
  q.unit_order;

GRANT SELECT ON public.v_learner_evaluation_summary TO authenticated;

-- B) Respuestas fallidas (final evaluation)
CREATE OR REPLACE VIEW public.v_learner_wrong_answers AS
WITH scoped_attempts AS (
  SELECT
    a.id AS attempt_id,
    a.learner_id,
    a.program_id,
    lt.local_id,
    l.org_id
  FROM public.final_evaluation_attempts a
  JOIN public.learner_trainings lt
    ON lt.learner_id = a.learner_id
   AND lt.program_id = a.program_id
  JOIN public.locals l
    ON l.id = lt.local_id
  WHERE
    public.current_role() IN ('superadmin','admin_org','referente')
    AND (
      public.current_role() = 'superadmin'
      OR (public.current_role() = 'admin_org' AND l.org_id = public.current_org_id())
      OR (public.current_role() = 'referente' AND lt.local_id = public.current_local_id())
    )
)
SELECT
  sa.org_id,
  sa.local_id,
  sa.learner_id,
  sa.program_id,
  sa.attempt_id,
  q.unit_order,
  q.id AS question_id,
  q.question_type,
  q.prompt,
  ans.id AS answer_id,
  ans.learner_answer,
  ev.score,
  ev.verdict,
  ev.strengths,
  ev.gaps,
  ev.feedback,
  ev.doubt_signals,
  ev.created_at
FROM scoped_attempts sa
JOIN public.final_evaluation_questions q
  ON q.attempt_id = sa.attempt_id
JOIN public.final_evaluation_answers ans
  ON ans.question_id = q.id
JOIN public.final_evaluation_evaluations ev
  ON ev.answer_id = ans.id
WHERE ev.verdict <> 'pass';

GRANT SELECT ON public.v_learner_wrong_answers TO authenticated;

-- C) Señales de duda (practice + final), agregadas por unidad + señal
CREATE OR REPLACE VIEW public.v_learner_doubt_signals AS
WITH scoped_learners AS (
  SELECT
    lt.learner_id,
    lt.program_id,
    lt.local_id,
    l.org_id
  FROM public.learner_trainings lt
  JOIN public.locals l ON l.id = lt.local_id
  WHERE
    public.current_role() IN ('superadmin','admin_org','referente')
    AND (
      public.current_role() = 'superadmin'
      OR (public.current_role() = 'admin_org' AND l.org_id = public.current_org_id())
      OR (public.current_role() = 'referente' AND lt.local_id = public.current_local_id())
    )
),
final_signals AS (
  SELECT
    sl.org_id,
    sl.local_id,
    a.learner_id,
    a.program_id,
    q.unit_order,
    unnest(ev.doubt_signals) AS signal,
    ev.created_at AS seen_at,
    'final'::text AS source
  FROM scoped_learners sl
  JOIN public.final_evaluation_attempts a
    ON a.learner_id = sl.learner_id
   AND a.program_id = sl.program_id
  JOIN public.final_evaluation_questions q
    ON q.attempt_id = a.id
  JOIN public.final_evaluation_answers ans
    ON ans.question_id = q.id
  JOIN public.final_evaluation_evaluations ev
    ON ev.answer_id = ans.id
  WHERE COALESCE(array_length(ev.doubt_signals, 1), 0) > 0
),
practice_signals AS (
  SELECT
    sl.org_id,
    sl.local_id,
    pa.learner_id,
    ps.program_id,
    ps.unit_order,
    unnest(pe.doubt_signals) AS signal,
    pe.created_at AS seen_at,
    'practice'::text AS source
  FROM scoped_learners sl
  JOIN public.practice_attempts pa
    ON pa.learner_id = sl.learner_id
  JOIN public.practice_scenarios ps
    ON ps.id = pa.scenario_id
   AND ps.program_id = sl.program_id
  JOIN public.practice_evaluations pe
    ON pe.attempt_id = pa.id
  WHERE COALESCE(array_length(pe.doubt_signals, 1), 0) > 0
),
all_signals AS (
  SELECT * FROM final_signals
  UNION ALL
  SELECT * FROM practice_signals
)
SELECT
  org_id,
  local_id,
  learner_id,
  program_id,
  unit_order,
  signal,
  COUNT(*)::int AS total_count,
  MAX(seen_at) AS last_seen_at,
  array_agg(DISTINCT source) AS sources
FROM all_signals
GROUP BY
  org_id, local_id, learner_id, program_id, unit_order, signal;

GRANT SELECT ON public.v_learner_doubt_signals TO authenticated;

commit;
