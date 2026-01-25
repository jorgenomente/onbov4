import Link from 'next/link';

import {
  approveLearner,
  requestReinforcement,
} from '../../../../app/referente/review/actions';
import { getSupabaseServerClient } from '../../../../lib/server/supabase';

type ReviewPageProps = {
  params: Promise<{ learnerId: string }>;
};

export default async function ReviewDetailPage({ params }: ReviewPageProps) {
  const { learnerId } = await params;
  const supabase = await getSupabaseServerClient();

  const { data: evidence, error: evidenceError } = await supabase
    .from('v_learner_evidence')
    .select('learner_id, practice_summary, doubt_signals, recent_messages')
    .eq('learner_id', learnerId)
    .maybeSingle();

  const { data: learnerProfile } = await supabase
    .from('profiles')
    .select('full_name')
    .eq('user_id', learnerId)
    .maybeSingle();

  if (evidenceError || !evidence) {
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

  const doubtSignals = (evidence.doubt_signals as string[]) ?? [];

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

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="text-sm font-semibold text-slate-700">
          Señales de duda
        </h2>
        {doubtSignals.length === 0 ? (
          <p className="mt-2 text-sm text-slate-500">Sin señales.</p>
        ) : (
          <div className="mt-2 flex flex-wrap gap-2 text-xs">
            {doubtSignals.map((signal) => (
              <span
                key={signal}
                className="rounded-full bg-amber-100 px-2 py-1 text-amber-700"
              >
                {signal}
              </span>
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
