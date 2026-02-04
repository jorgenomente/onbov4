import Link from 'next/link';

import { canStartFinalEvaluation } from '../../../lib/ai/final-evaluation-engine';
import {
  getNextStepUi,
  getPracticeState,
} from '../../../lib/learner/next-step';
import { getLearnerStatusUi } from '../../../lib/learner/status-ui';
import { getSupabaseServerClient } from '../../../lib/server/supabase';

type ProgressUnit = {
  unit_order: number;
  title: string;
  is_completed: boolean;
};

export default async function LearnerProgressPage() {
  const supabase = await getSupabaseServerClient();
  const { data: userData } = await supabase.auth.getUser();

  const { data: trainingHome, error: trainingError } = await supabase
    .from('v_learner_training_home')
    .select(
      'program_name, status, progress_percent, current_unit_order, total_units',
    )
    .maybeSingle();

  const { data: progressData, error: progressError } = await supabase
    .from('v_learner_progress')
    .select('units, current_unit_order')
    .maybeSingle();

  const { data: trainingMeta } = await supabase
    .from('learner_trainings')
    .select('local_id, program_id')
    .eq('learner_id', userData?.user?.id ?? '')
    .maybeSingle();

  if (trainingError || progressError) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-4 px-4 py-6">
        <h1 className="text-2xl font-semibold text-slate-900">Progreso</h1>
        <p className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Error al cargar el progreso.
        </p>
      </main>
    );
  }

  const units = (progressData?.units as ProgressUnit[] | undefined) ?? [];
  const currentUnitOrder = Number(
    progressData?.current_unit_order ?? trainingHome?.current_unit_order ?? 0,
  );
  const completedUnits = units.filter((unit) => unit.is_completed);
  const lastCompletedUnit = completedUnits.sort(
    (a, b) => b.unit_order - a.unit_order,
  )[0];
  const reviewHref = lastCompletedUnit
    ? `/learner/review/${lastCompletedUnit.unit_order}`
    : null;
  const statusUi = getLearnerStatusUi(trainingHome?.status ?? null);
  const practiceState = await getPracticeState({
    supabase,
    learnerId: userData?.user?.id ?? '',
    programId: trainingMeta?.program_id ?? null,
    unitOrder: currentUnitOrder || null,
    localId: trainingMeta?.local_id ?? null,
  });
  const finalEvalReady = userData?.user?.id
    ? (await canStartFinalEvaluation(userData.user.id)).allowed
    : false;
  const nextStep = getNextStepUi({
    status: trainingHome?.status ?? null,
    practiceState,
    unitOrder: currentUnitOrder || null,
    finalEvalReady,
  });
  const badgeToneStyles = {
    neutral: 'bg-slate-100 text-slate-600',
    info: 'bg-blue-50 text-blue-700',
    warning: 'bg-amber-50 text-amber-700',
    success: 'bg-emerald-50 text-emerald-700',
  };

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-6 px-4 py-6">
      <header className="flex flex-col gap-2">
        <h1 className="text-2xl font-semibold text-slate-900">Progreso</h1>
        <div className="rounded-lg border border-slate-200 bg-white p-4">
          <p className="text-sm font-semibold text-slate-800">
            {trainingHome?.program_name ?? 'Programa activo'}
          </p>
          <div className="mt-2 flex flex-wrap items-center gap-2 text-xs text-slate-500">
            <span
              className={`rounded-full px-2 py-1 font-semibold ${badgeToneStyles[statusUi.badge.tone]}`}
            >
              {statusUi.badge.label}
            </span>
            <span>{statusUi.statusHint}</span>
          </div>
          <div className="mt-3 flex items-center justify-between text-sm">
            <span className="text-slate-500">Avance</span>
            <span className="font-semibold text-slate-700">
              {Math.round(Number(trainingHome?.progress_percent ?? 0))}%
            </span>
          </div>
          <div className="mt-2 text-xs text-slate-500">
            Unidad actual: {currentUnitOrder || '—'} /{' '}
            {trainingHome?.total_units ?? '—'}
          </div>
        </div>
      </header>

      <div className="flex flex-col gap-2">
        <div className="flex flex-wrap gap-2">
          <Link
            href="/learner/training"
            className="rounded-md bg-emerald-600 px-3 py-2 text-sm font-semibold text-white"
          >
            Volver a entrenamiento
          </Link>
          {reviewHref ? (
            <Link
              href={reviewHref}
              className="rounded-md border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-700"
            >
              Repasar unidad
            </Link>
          ) : (
            <button
              type="button"
              disabled
              className="rounded-md border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-400"
            >
              Repasar unidad
            </button>
          )}
        </div>
        <p className="text-xs text-slate-500">
          Próximo paso: {nextStep.hintLine}
        </p>
        {!reviewHref ? (
          <p className="text-xs text-slate-500">
            Completa una unidad para habilitar repaso.
          </p>
        ) : null}
      </div>

      <section className="flex flex-col gap-3">
        {units.length === 0 ? (
          <div className="rounded-md border border-dashed border-slate-200 p-4 text-sm text-slate-500">
            Todavía no hay unidades completadas. Empezá desde entrenamiento para
            avanzar.
            <Link
              href="/learner/training"
              className="ml-1 font-semibold text-emerald-700"
            >
              Ir a entrenamiento
            </Link>
          </div>
        ) : (
          units.map((unit) => {
            const isCurrent = unit.unit_order === currentUnitOrder;

            return (
              <div
                key={unit.unit_order}
                className="rounded-lg border border-slate-200 bg-white p-4"
                data-testid="progress-unit"
              >
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <p className="text-sm font-semibold text-slate-800">
                      Unidad {unit.unit_order}
                    </p>
                    <p className="text-sm text-slate-600">{unit.title}</p>
                  </div>
                  {unit.is_completed ? (
                    <span className="rounded-full bg-emerald-50 px-2 py-1 text-xs font-semibold text-emerald-700">
                      Completada
                    </span>
                  ) : isCurrent ? (
                    <span className="rounded-full bg-blue-50 px-2 py-1 text-xs font-semibold text-blue-700">
                      Actual
                    </span>
                  ) : (
                    <span className="rounded-full bg-slate-100 px-2 py-1 text-xs font-semibold text-slate-500">
                      Bloqueada
                    </span>
                  )}
                </div>

                {unit.is_completed ? (
                  <Link
                    href={`/learner/review/${unit.unit_order}`}
                    className="mt-3 inline-flex items-center justify-center rounded-md border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm font-semibold text-emerald-700"
                    data-testid={`review-cta-${unit.unit_order}`}
                  >
                    Repasar
                  </Link>
                ) : null}
              </div>
            );
          })
        )}
      </section>
    </main>
  );
}
