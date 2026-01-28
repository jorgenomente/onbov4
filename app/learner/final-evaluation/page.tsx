import Link from 'next/link';

import { getSupabaseServerClient } from '../../../lib/server/supabase';
import { canStartFinalEvaluation } from '../../../lib/ai/final-evaluation-engine';
import ReviewHistory, {
  type ReviewDecision,
} from '../../../components/ReviewHistory';
import { startFinalEvaluationAction, submitFinalAnswerAction } from './actions';

export default async function FinalEvaluationPage() {
  const supabase = await getSupabaseServerClient();
  const { data: userData } = await supabase.auth.getUser();

  if (!userData?.user?.id) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-xl flex-col gap-4 px-4 py-6">
        <p className="text-sm text-slate-500">Necesitas iniciar sesión.</p>
      </main>
    );
  }

  const learnerId = userData.user.id;

  const { data: reviewDecisions } = await supabase
    .from('learner_review_decisions')
    .select('id, decision, reason, reviewer_name, created_at')
    .eq('learner_id', learnerId)
    .order('created_at', { ascending: false });

  const { data: attempt } = await supabase
    .from('final_evaluation_attempts')
    .select('id, status, attempt_number')
    .eq('learner_id', learnerId)
    .eq('status', 'in_progress')
    .order('started_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!attempt) {
    const { data: training } = await supabase
      .from('learner_trainings')
      .select('status')
      .eq('learner_id', learnerId)
      .maybeSingle();

    if (training?.status === 'en_revision') {
      return (
        <main className="mx-auto flex min-h-screen w-full max-w-xl flex-col gap-4 px-4 py-6">
          <h1 className="text-xl font-semibold">Evaluación enviada</h1>
          <p className="text-sm text-slate-500">
            Tu evaluación fue enviada. Está siendo revisada por tu referente.
          </p>
          <p className="text-sm text-slate-500" data-testid="final-in-review">
            Estado: en revisión
          </p>
          <ReviewHistory
            decisions={reviewDecisions as ReviewDecision[] | null}
            title="Historial de decisiones"
          />
          <div className="flex flex-wrap gap-2">
            <Link
              href="/learner/training"
              className="rounded-md bg-emerald-600 px-3 py-2 text-sm font-semibold text-white"
            >
              Volver a entrenamiento
            </Link>
          </div>
        </main>
      );
    }

    const allowed = await canStartFinalEvaluation(learnerId);

    return (
      <main className="mx-auto flex min-h-screen w-full max-w-xl flex-col gap-4 px-4 py-6">
        <div className="flex flex-col gap-1">
          <h1 className="text-xl font-semibold">Evaluación final</h1>
          <p className="text-sm text-slate-500">
            Mesa complicada — revisión humana final.
          </p>
        </div>

        <div className="flex flex-wrap gap-2">
          <Link
            href="/learner/training"
            className="rounded-md border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-700"
          >
            Volver a entrenamiento
          </Link>
        </div>

        <ReviewHistory
          decisions={reviewDecisions as ReviewDecision[] | null}
          title="Historial de decisiones"
        />

        {!allowed.allowed ? (
          <div className="rounded-md border border-slate-200 bg-slate-50 p-4 text-sm text-slate-600">
            {allowed.reason}
          </div>
        ) : (
          <form action={startFinalEvaluationAction}>
            <button
              type="submit"
              data-testid="final-start"
              className="w-full rounded-md bg-slate-900 px-4 py-3 text-sm font-semibold text-white"
            >
              Iniciar evaluación final
            </button>
          </form>
        )}
      </main>
    );
  }

  const { data: questions } = await supabase
    .from('final_evaluation_questions')
    .select('id, unit_order, question_type, prompt, created_at')
    .eq('attempt_id', attempt.id)
    .order('created_at', { ascending: true });

  const questionIds = (questions ?? []).map((question) => question.id);
  const { data: answers } = await supabase
    .from('final_evaluation_answers')
    .select('question_id')
    .in('question_id', questionIds);

  const answered = new Set((answers ?? []).map((answer) => answer.question_id));
  const nextQuestion = (questions ?? []).find(
    (question) => !answered.has(question.id),
  );

  if (!nextQuestion) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-xl flex-col gap-4 px-4 py-6">
        <h1 className="text-xl font-semibold">Evaluación enviada</h1>
        <p className="text-sm text-slate-500">
          Tu evaluación fue enviada. Está siendo revisada por tu referente.
        </p>
        <p className="text-sm text-slate-500" data-testid="final-in-review">
          Estado: en revisión
        </p>
        <ReviewHistory
          decisions={reviewDecisions as ReviewDecision[] | null}
          title="Historial de decisiones"
        />
        <div className="flex flex-wrap gap-2">
          <Link
            href="/learner/training"
            className="rounded-md bg-emerald-600 px-3 py-2 text-sm font-semibold text-white"
          >
            Volver a entrenamiento
          </Link>
        </div>
      </main>
    );
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-xl flex-col gap-6 px-4 py-6">
      <div className="flex flex-wrap gap-2">
        <Link
          href="/learner/training"
          className="rounded-md border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-700"
        >
          Volver a entrenamiento
        </Link>
      </div>
      <div className="flex flex-col gap-1">
        <h1 className="text-xl font-semibold">Evaluación final</h1>
        <p className="text-sm text-slate-500" data-testid="final-progress">
          Pregunta {answered.size + 1} de {questions?.length ?? 0}
        </p>
      </div>

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <p className="text-sm text-slate-500">
          Unidad {nextQuestion.unit_order} · {nextQuestion.question_type}
        </p>
        <p
          className="mt-2 text-base text-slate-800"
          data-testid="final-question-prompt"
        >
          {nextQuestion.prompt}
        </p>
      </section>

      <form
        action={async (formData: FormData) => {
          'use server';
          const text = String(formData.get('answer') ?? '');
          await submitFinalAnswerAction({
            questionId: nextQuestion.id,
            text,
          });
        }}
        className="flex flex-col gap-3"
      >
        <label className="text-sm font-medium text-slate-700">
          Tu respuesta
        </label>
        <textarea
          name="answer"
          required
          rows={4}
          data-testid="final-answer"
          className="w-full rounded-md border border-slate-300 p-2 text-sm"
          placeholder="Escribí tu respuesta..."
        />
        <button
          type="submit"
          data-testid="final-submit"
          className="rounded-md bg-slate-900 px-4 py-3 text-sm font-semibold text-white"
        >
          Enviar respuesta
        </button>
      </form>
    </main>
  );
}
