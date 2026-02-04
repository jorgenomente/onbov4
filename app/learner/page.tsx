import Link from 'next/link';

import { getLearnerStatusUi } from '../../lib/learner/status-ui';
import { getSupabaseServerClient } from '../../lib/server/supabase';

export default async function LearnerHomePage() {
  const supabase = await getSupabaseServerClient();

  const { data: trainingHome, error: trainingError } = await supabase
    .from('v_learner_training_home')
    .select(
      'program_name, status, progress_percent, current_unit_order, current_unit_title, total_units',
    )
    .maybeSingle();

  const { data: progressData, error: progressError } = await supabase
    .from('v_learner_progress')
    .select('units, current_unit_order')
    .maybeSingle();

  if (trainingError || progressError) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-4 px-4 py-6">
        <h1 className="text-2xl font-semibold text-slate-900">
          Tu entrenamiento
        </h1>
        <p className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Error al cargar la información.
        </p>
      </main>
    );
  }

  const statusUi = getLearnerStatusUi(trainingHome?.status ?? null);
  const currentUnitOrder = Number(
    progressData?.current_unit_order ?? trainingHome?.current_unit_order ?? 0,
  );
  const homeHintMap: Record<string, string> = {
    en_entrenamiento: 'Tu próximo paso es aprender esta unidad.',
    en_practica: 'Tu próximo paso es practicar esta unidad.',
    en_revision: 'Tu evaluación final está en revisión.',
    en_riesgo: 'Tu próximo paso es reforzar esta unidad.',
    aprobado: 'Entrenamiento completado.',
  };
  const badgeToneStyles = {
    neutral: 'bg-slate-100 text-slate-600',
    info: 'bg-blue-50 text-blue-700',
    warning: 'bg-amber-50 text-amber-700',
    success: 'bg-emerald-50 text-emerald-700',
  };

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-6 px-4 py-6">
      <header className="flex flex-col gap-2">
        <h1 className="text-2xl font-semibold text-slate-900">
          Tu entrenamiento
        </h1>
        <p className="text-sm text-slate-600">
          {trainingHome?.program_name ?? 'Programa activo'}
        </p>
        <div className="flex flex-wrap items-center gap-2 text-xs text-slate-500">
          <span
            data-testid="learner-status"
            className={`rounded-full px-2 py-1 font-semibold ${badgeToneStyles[statusUi.badge.tone]}`}
          >
            {statusUi.badge.label}
          </span>
          <span>{statusUi.statusHint}</span>
        </div>
      </header>

      <section
        data-testid="learner-current-unit"
        className="rounded-lg border border-slate-200 bg-white p-4"
      >
        <div className="flex items-center justify-between text-sm">
          <span className="text-slate-500">Avance</span>
          <span
            data-testid="learner-progress"
            className="font-semibold text-slate-700"
          >
            {Math.round(Number(trainingHome?.progress_percent ?? 0))}%
          </span>
        </div>
        <div className="mt-2 text-xs text-slate-500">
          Unidad actual: {currentUnitOrder || '—'}
          {trainingHome?.total_units ? ` de ${trainingHome.total_units}` : ''}
          {trainingHome?.current_unit_title
            ? ` — ${trainingHome.current_unit_title}`
            : ''}
        </div>
      </section>

      <div className="flex flex-col gap-2">
        <Link
          href="/learner/training"
          data-testid="learner-cta-continue"
          className="rounded-md bg-emerald-600 px-3 py-2 text-center text-sm font-semibold text-white"
        >
          Continuar
        </Link>
        <p className="text-xs text-slate-500">
          {homeHintMap[trainingHome?.status ?? 'en_entrenamiento']}
        </p>
      </div>
    </main>
  );
}
