import Link from 'next/link';

import { getSupabaseServerClient } from '../../../lib/server/supabase';

export default async function ReviewQueuePage() {
  const supabase = await getSupabaseServerClient();

  const { data, error } = await supabase
    .from('v_review_queue')
    .select(
      'learner_id, full_name, local_id, status, progress_percent, last_activity_at, has_doubt_signals, has_failed_practice',
    )
    .order('last_activity_at', { ascending: false });

  if (error) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-xl flex-col gap-4 px-4 py-6">
        <h1 className="text-xl font-semibold">Revisión</h1>
        <p className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Error al cargar la cola de revisión.
        </p>
      </main>
    );
  }

  if (!data || data.length === 0) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-xl flex-col gap-4 px-4 py-6">
        <h1 className="text-xl font-semibold">Revisión</h1>
        <div className="rounded-md border border-dashed border-slate-200 p-4 text-sm text-slate-500">
          No hay aprendices en revisión.
        </div>
      </main>
    );
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-xl flex-col gap-4 px-4 py-6">
      <div className="flex flex-col gap-1">
        <h1 className="text-xl font-semibold">Revisión</h1>
        <p className="text-sm text-slate-500">
          Aprendices pendientes de decisión humana.
        </p>
      </div>

      <ul className="flex flex-col gap-3" data-testid="review-queue">
        {data.map((learner) => (
          <li
            key={learner.learner_id}
            data-testid="review-learner-row"
            className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm"
          >
            <div className="flex flex-col gap-2">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-base font-medium">
                    {learner.full_name ?? 'Aprendiz'}
                  </p>
                  <p className="text-xs text-slate-500">
                    Estado: {learner.status}
                  </p>
                </div>
                <span className="text-xs text-slate-500">
                  {Math.round(Number(learner.progress_percent) || 0)}%
                </span>
              </div>

              <div className="flex flex-wrap gap-2 text-xs">
                {learner.has_doubt_signals && (
                  <span className="rounded-full bg-amber-100 px-2 py-1 text-amber-700">
                    Dudas detectadas
                  </span>
                )}
                {learner.has_failed_practice && (
                  <span className="rounded-full bg-red-100 px-2 py-1 text-red-700">
                    Prácticas fallidas
                  </span>
                )}
              </div>

              <Link
                href={`/referente/review/${learner.learner_id}`}
                className="mt-2 inline-flex items-center justify-center rounded-md bg-slate-900 px-3 py-2 text-sm font-medium text-white"
              >
                Revisar evidencia
              </Link>
            </div>
          </li>
        ))}
      </ul>
    </main>
  );
}
