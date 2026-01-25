import Link from 'next/link';

import { getSupabaseServerClient } from '../../../lib/server/supabase';
import {
  canStartFinalEvaluation,
  startFinalEvaluation,
} from '../../../lib/ai/final-evaluation-engine';
import { submitFinalAnswerAction } from './actions';

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

  const { data: attempt } = await supabase
    .from('final_evaluation_attempts')
    .select('id, status, attempt_number')
    .eq('learner_id', learnerId)
    .eq('status', 'in_progress')
    .order('started_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!attempt) {
    const allowed = await canStartFinalEvaluation(learnerId);

    return (
      <main className="mx-auto flex min-h-screen w-full max-w-xl flex-col gap-4 px-4 py-6">
        <div className="flex flex-col gap-1">
          <h1 className="text-xl font-semibold">Evaluación final</h1>
          <p className="text-sm text-slate-500">
            Mesa complicada — revisión humana final.
          </p>
        </div>

        {!allowed.allowed ? (
          <div className="rounded-md border border-slate-200 bg-slate-50 p-4 text-sm text-slate-600">
            {allowed.reason}
          </div>
        ) : (
          <form
            action={async () => {
              'use server';
              await startFinalEvaluation(learnerId);
            }}
          >
            <button
              type="submit"
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
        <Link href="/" className="text-sm text-slate-500">
          Volver
        </Link>
      </main>
    );
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-xl flex-col gap-6 px-4 py-6">
      <div className="flex flex-col gap-1">
        <h1 className="text-xl font-semibold">Evaluación final</h1>
        <p className="text-sm text-slate-500">
          Pregunta {answered.size + 1} de {questions?.length ?? 0}
        </p>
      </div>

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <p className="text-sm text-slate-500">
          Unidad {nextQuestion.unit_order} · {nextQuestion.question_type}
        </p>
        <p className="mt-2 text-base text-slate-800">{nextQuestion.prompt}</p>
      </section>

      <form
        action={async (formData: FormData) => {
          'use server';
          const text = String(formData.get('answer') ?? '');
          await submitFinalAnswerAction({
            attemptId: attempt.id,
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
          className="w-full rounded-md border border-slate-300 p-2 text-sm"
          placeholder="Escribí tu respuesta..."
        />
        <button
          type="submit"
          className="rounded-md bg-slate-900 px-4 py-3 text-sm font-semibold text-white"
        >
          Enviar respuesta
        </button>
      </form>
    </main>
  );
}
