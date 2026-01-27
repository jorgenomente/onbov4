import Link from 'next/link';

import {
  approveLearner,
  requestReinforcement,
} from '../../../../app/referente/review/actions';
import ReviewHistory, {
  type ReviewDecision,
} from '../../../../components/ReviewHistory';
import { getSupabaseServerClient } from '../../../../lib/server/supabase';

type ReviewPageProps = {
  params: Promise<{ learnerId: string }>;
};

export default async function ReviewDetailPage({ params }: ReviewPageProps) {
  const { learnerId } = await params;
  const supabase = await getSupabaseServerClient();

  const { data: evidence, error: evidenceError } = await supabase
    .from('v_learner_evidence')
    .select('learner_id, practice_summary, recent_messages')
    .eq('learner_id', learnerId)
    .maybeSingle();

  const { data: evaluationSummaryData, error: evaluationSummaryError } =
    await supabase
      .from('v_learner_evaluation_summary')
      .select(
        'attempt_id, attempt_number, status, global_score, bot_recommendation, unit_order, total_questions, avg_score, pass_count, partial_count, fail_count, last_evaluated_at',
      )
      .eq('learner_id', learnerId)
      .order('attempt_number', { ascending: false })
      .order('unit_order', { ascending: true });

  const { data: wrongAnswersData, error: wrongAnswersError } = await supabase
    .from('v_learner_wrong_answers')
    .select(
      'attempt_id, unit_order, question_type, prompt, learner_answer, score, verdict, strengths, gaps, feedback, doubt_signals, created_at',
    )
    .eq('learner_id', learnerId)
    .order('created_at', { ascending: false });

  const { data: doubtSignalsData, error: doubtSignalsError } = await supabase
    .from('v_learner_doubt_signals')
    .select(
      'unit_order, signal, total_count, last_seen_at, sources, learner_id',
    )
    .eq('learner_id', learnerId)
    .order('unit_order', { ascending: true })
    .order('signal', { ascending: true });

  const { data: unitCoverageData, error: unitCoverageError } = await supabase
    .from('v_local_unit_coverage_30d')
    .select(
      'unit_order, avg_practice_score, avg_final_score, practice_fail_rate, final_fail_rate, top_gap',
    )
    .order('unit_order', { ascending: true });

  const { data: learnerProfile } = await supabase
    .from('profiles')
    .select('full_name')
    .eq('user_id', learnerId)
    .maybeSingle();

  const { data: reviewDecisions } = await supabase
    .from('learner_review_decisions')
    .select('id, decision, reason, reviewer_name, created_at')
    .eq('learner_id', learnerId)
    .order('created_at', { ascending: false });

  if (
    evidenceError ||
    evaluationSummaryError ||
    wrongAnswersError ||
    doubtSignalsError ||
    unitCoverageError ||
    !evidence
  ) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-xl flex-col gap-4 px-4 py-6">
        <Link href="/referente/review" className="text-sm text-slate-500">
          ← Volver
        </Link>
        <p className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Error al cargar evidencia.
        </p>
      </main>
    );
  }

  const practiceSummary =
    (evidence.practice_summary as Array<{
      scenario_title: string;
      score: number;
      verdict: string;
      feedback: string;
      created_at: string;
    }>) ?? [];

  const recentMessages =
    (evidence.recent_messages as Array<{
      sender: string;
      content: string;
      created_at: string;
    }>) ?? [];

  const evaluationSummary =
    (evaluationSummaryData as Array<{
      attempt_id: string;
      attempt_number: number;
      status: string;
      global_score: number | null;
      bot_recommendation: string | null;
      unit_order: number;
      total_questions: number;
      avg_score: number | null;
      pass_count: number;
      partial_count: number;
      fail_count: number;
      last_evaluated_at: string | null;
    }>) ?? [];

  const wrongAnswers =
    (wrongAnswersData as Array<{
      attempt_id: string;
      unit_order: number;
      question_type: string;
      prompt: string;
      learner_answer: string;
      score: number;
      verdict: string;
      strengths: string[];
      gaps: string[];
      feedback: string;
      doubt_signals: string[];
      created_at: string;
    }>) ?? [];

  const doubtSignals =
    (doubtSignalsData as Array<{
      unit_order: number;
      signal: string;
      total_count: number;
      last_seen_at: string | null;
      sources: string[] | null;
    }>) ?? [];

  const unitCoverage =
    (unitCoverageData as Array<{
      unit_order: number;
      avg_practice_score: number | null;
      avg_final_score: number | null;
      practice_fail_rate: number | null;
      final_fail_rate: number | null;
      top_gap: string | null;
    }>) ?? [];

  const summaryByAttempt = evaluationSummary.reduce(
    (acc, row) => {
      const existing = acc.get(row.attempt_id);
      if (existing) {
        existing.rows.push(row);
        return acc;
      }
      acc.set(row.attempt_id, {
        attemptNumber: row.attempt_number,
        status: row.status,
        globalScore: row.global_score,
        recommendation: row.bot_recommendation,
        rows: [row],
      });
      return acc;
    },
    new Map<
      string,
      {
        attemptNumber: number;
        status: string;
        globalScore: number | null;
        recommendation: string | null;
        rows: typeof evaluationSummary;
      }
    >(),
  );

  async function approve(formData: FormData) {
    'use server';
    const reason = String(formData.get('reason') ?? '');
    await approveLearner({ learnerId, reason });
  }

  async function reinforce(formData: FormData) {
    'use server';
    const reason = String(formData.get('reason') ?? '');
    await requestReinforcement({ learnerId, reason });
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-xl flex-col gap-6 px-4 py-6">
      <Link href="/referente/review" className="text-sm text-slate-500">
        ← Volver
      </Link>

      <div>
        <h1 className="text-xl font-semibold">
          {learnerProfile?.full_name ?? 'Aprendiz'}
        </h1>
        <p className="text-sm text-slate-500">Evidencias y decisión final.</p>
      </div>

      <ReviewHistory
        decisions={reviewDecisions as ReviewDecision[] | null}
        compact={false}
      />

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="text-sm font-semibold text-slate-700">
          Resumen por unidad
        </h2>
        {evaluationSummary.length === 0 ? (
          <p className="mt-2 text-sm text-slate-500">
            No hay evaluación final registrada.
          </p>
        ) : (
          <div className="mt-3 flex flex-col gap-4">
            {[...summaryByAttempt.entries()].map(([attemptId, summary]) => (
              <div
                key={attemptId}
                className="rounded-md border border-slate-200 p-3"
              >
                <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-slate-500">
                  <span className="font-semibold text-slate-700">
                    Intento {summary.attemptNumber}
                  </span>
                  <span className="rounded-full bg-slate-100 px-2 py-0.5 text-slate-600">
                    {summary.status}
                  </span>
                </div>
                <p className="mt-2 text-xs text-slate-500">
                  Score global:{' '}
                  {summary.globalScore === null
                    ? '—'
                    : Math.round(summary.globalScore)}
                  {' · '}Recomendación: {summary.recommendation ?? '—'}
                </p>
                <ul className="mt-3 flex flex-col gap-3 text-sm">
                  {summary.rows.map((row) => (
                    <li key={`${attemptId}-${row.unit_order}`}>
                      <p className="font-medium text-slate-700">
                        Unidad {row.unit_order}
                      </p>
                      <p className="text-xs text-slate-500">
                        {row.total_questions} preguntas · promedio{' '}
                        {row.avg_score === null
                          ? '—'
                          : Math.round(row.avg_score)}
                      </p>
                      <div className="mt-2 flex flex-wrap gap-2 text-xs text-slate-600">
                        <span className="rounded-full bg-emerald-50 px-2 py-1 text-emerald-700">
                          Pass {row.pass_count}
                        </span>
                        <span className="rounded-full bg-amber-50 px-2 py-1 text-amber-700">
                          Partial {row.partial_count}
                        </span>
                        <span className="rounded-full bg-rose-50 px-2 py-1 text-rose-700">
                          Fail {row.fail_count}
                        </span>
                      </div>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="text-sm font-semibold text-slate-700">
          Cobertura (30 días)
        </h2>
        {unitCoverage.length === 0 ? (
          <p className="mt-2 text-sm text-slate-500">
            No hay cobertura registrada.
          </p>
        ) : (
          <div className="mt-2 overflow-x-auto">
            <table className="min-w-full text-left text-xs text-slate-600">
              <thead className="text-[11px] text-slate-400 uppercase">
                <tr>
                  <th className="py-2 pr-4">Unidad</th>
                  <th className="py-2 pr-4">Avg práctica</th>
                  <th className="py-2 pr-4">Avg final</th>
                  <th className="py-2 pr-4">Fail práctica</th>
                  <th className="py-2 pr-4">Fail final</th>
                  <th className="py-2 pr-4">Top gap</th>
                </tr>
              </thead>
              <tbody>
                {unitCoverage.map((row) => (
                  <tr key={`unit-${row.unit_order}`} className="border-t">
                    <td className="py-2 pr-4 text-slate-700">
                      {row.unit_order}
                    </td>
                    <td className="py-2 pr-4">
                      {row.avg_practice_score === null
                        ? '—'
                        : Math.round(row.avg_practice_score)}
                    </td>
                    <td className="py-2 pr-4">
                      {row.avg_final_score === null
                        ? '—'
                        : Math.round(row.avg_final_score)}
                    </td>
                    <td className="py-2 pr-4">
                      {row.practice_fail_rate === null
                        ? '—'
                        : (row.practice_fail_rate * 100).toFixed(1)}
                      %
                    </td>
                    <td className="py-2 pr-4">
                      {row.final_fail_rate === null
                        ? '—'
                        : (row.final_fail_rate * 100).toFixed(1)}
                      %
                    </td>
                    <td className="py-2 pr-4 text-slate-500">
                      {row.top_gap ?? '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="text-sm font-semibold text-slate-700">
          Respuestas fallidas
        </h2>
        {wrongAnswers.length === 0 ? (
          <p className="mt-2 text-sm text-slate-500">
            No hay respuestas fallidas registradas.
          </p>
        ) : (
          <ul className="mt-3 flex flex-col gap-4">
            {wrongAnswers.map((answer, index) => (
              <li
                key={`${answer.attempt_id}-${answer.unit_order}-${index}`}
                className="rounded-md border border-slate-200 p-3"
              >
                <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-slate-500">
                  <span>Unidad {answer.unit_order}</span>
                  <span className="rounded-full bg-rose-50 px-2 py-0.5 text-rose-700">
                    {answer.verdict}
                  </span>
                </div>
                <p className="mt-2 text-sm font-medium text-slate-700">
                  {answer.prompt}
                </p>
                <p className="mt-2 text-sm text-slate-600">
                  <span className="font-semibold">Respuesta:</span>{' '}
                  {answer.learner_answer}
                </p>
                <p className="mt-2 text-xs text-slate-500">
                  Score {Math.round(answer.score)}
                </p>
                {answer.gaps?.length ? (
                  <div className="mt-2 flex flex-wrap gap-2 text-xs">
                    {answer.gaps.map((gap) => (
                      <span
                        key={gap}
                        className="rounded-full bg-slate-100 px-2 py-1 text-slate-600"
                      >
                        {gap}
                      </span>
                    ))}
                  </div>
                ) : null}
                <p className="mt-2 text-sm text-slate-600">{answer.feedback}</p>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="text-sm font-semibold text-slate-700">Señales</h2>
        {doubtSignals.length === 0 ? (
          <p className="mt-2 text-sm text-slate-500">Sin señales.</p>
        ) : (
          <div className="mt-3 flex flex-col gap-3">
            {doubtSignals.map((signal) => (
              <div
                key={`${signal.unit_order}-${signal.signal}`}
                className="rounded-md border border-slate-200 p-3 text-sm"
              >
                <div className="flex items-center justify-between text-xs text-slate-500">
                  <span>Unidad {signal.unit_order}</span>
                  <span className="rounded-full bg-amber-100 px-2 py-0.5 text-amber-700">
                    {signal.signal}
                  </span>
                </div>
                <p className="mt-2 text-xs text-slate-500">
                  Total: {signal.total_count} · Fuentes:{' '}
                  {signal.sources?.length ? signal.sources.join(', ') : '—'}
                </p>
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="text-sm font-semibold text-slate-700">Prácticas</h2>
        {practiceSummary.length === 0 ? (
          <p className="mt-2 text-sm text-slate-500">
            No hay prácticas registradas.
          </p>
        ) : (
          <ul className="mt-3 flex flex-col gap-3">
            {practiceSummary.map((practice, index) => (
              <li key={`${practice.scenario_title}-${index}`}>
                <p className="text-sm font-medium">{practice.scenario_title}</p>
                <p className="text-xs text-slate-500">
                  Score {Math.round(practice.score)} · {practice.verdict}
                </p>
                <p className="mt-1 text-sm text-slate-600">
                  {practice.feedback}
                </p>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="text-sm font-semibold text-slate-700">
          Últimos mensajes
        </h2>
        {recentMessages.length === 0 ? (
          <p className="mt-2 text-sm text-slate-500">Sin mensajes.</p>
        ) : (
          <ul className="mt-3 flex flex-col gap-3 text-sm">
            {recentMessages.map((message, index) => (
              <li key={`${message.created_at}-${index}`}>
                <span className="text-xs text-slate-400 uppercase">
                  {message.sender}
                </span>
                <p className="text-slate-700">{message.content}</p>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="flex flex-col gap-4">
        <form action={approve} className="flex flex-col gap-3">
          <label className="text-sm font-medium text-slate-700">
            Motivo de aprobación
          </label>
          <textarea
            name="reason"
            required
            rows={3}
            className="w-full rounded-md border border-slate-300 p-2 text-sm"
            placeholder="Motivo de aprobación..."
          />
          <button
            type="submit"
            className="rounded-md bg-emerald-600 px-3 py-2 text-sm font-semibold text-white"
          >
            Aprobar
          </button>
        </form>

        <form action={reinforce} className="flex flex-col gap-3">
          <label className="text-sm font-medium text-slate-700">
            Motivo de refuerzo
          </label>
          <textarea
            name="reason"
            required
            rows={3}
            className="w-full rounded-md border border-slate-300 p-2 text-sm"
            placeholder="Motivo de refuerzo..."
          />
          <button
            type="submit"
            className="rounded-md bg-slate-900 px-3 py-2 text-sm font-semibold text-white"
          >
            Pedir refuerzo
          </button>
        </form>
      </section>
    </main>
  );
}
