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

  const { data: topGaps, error: topGapsError } = await supabase
    .from('v_local_top_gaps_30d')
    .select(
      'gap, count_total, learners_affected, percent_learners_affected, last_seen_at',
    )
    .order('count_total', { ascending: false })
    .limit(10);

  const { data: learnerRisk, error: learnerRiskError } = await supabase
    .from('v_local_learner_risk_30d')
    .select(
      'learner_id, risk_level, reasons, last_activity_at, failed_practice_count, failed_final_count, doubt_signals_count',
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

  const sortedRisk =
    (learnerRisk ?? []).slice().sort((a, b) => {
      const order = { high: 3, medium: 2, low: 1 } as const;
      const aScore = order[(a.risk_level ?? 'low') as keyof typeof order] ?? 0;
      const bScore = order[(b.risk_level ?? 'low') as keyof typeof order] ?? 0;
      if (aScore !== bScore) {
        return bScore - aScore;
      }
      const aDate = a.last_activity_at
        ? new Date(a.last_activity_at).getTime()
        : 0;
      const bDate = b.last_activity_at
        ? new Date(b.last_activity_at).getTime()
        : 0;
      return bDate - aDate;
    }) ?? [];
  const firstLearnerId = data?.[0]?.learner_id ?? null;
  const reviewHref = firstLearnerId
    ? `/referente/review/${firstLearnerId}`
    : null;

  if (!data || data.length === 0) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-xl flex-col gap-4 px-4 py-6">
        <h1 className="text-xl font-semibold">Revisión</h1>
        <div className="flex flex-col gap-2">
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              disabled
              className="rounded-md bg-slate-200 px-3 py-2 text-sm font-semibold text-slate-500"
            >
              Abrir revisión
            </button>
            <Link
              href="/referente/alerts"
              className="rounded-md border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-700"
            >
              Ver alertas
            </Link>
          </div>
          <p className="text-xs text-slate-500">Sin aprendices para revisar.</p>
        </div>
        <div className="rounded-md border border-dashed border-slate-200 p-4 text-sm text-slate-500">
          No hay aprendices en revisión.
        </div>

        <section className="rounded-lg border border-slate-200 bg-white p-4">
          <h2 className="text-sm font-semibold text-slate-700">
            Métricas (30 días)
          </h2>
          {topGapsError || learnerRiskError ? (
            <p className="mt-2 text-sm text-slate-500">
              No se pudieron cargar métricas.
            </p>
          ) : (
            <div className="mt-3 flex flex-col gap-4">
              <div>
                <p className="text-xs font-semibold text-slate-500 uppercase">
                  Top gaps del local
                </p>
                {topGaps && topGaps.length > 0 ? (
                  <div className="mt-2 overflow-x-auto">
                    <table className="min-w-full text-left text-xs text-slate-600">
                      <thead className="text-[11px] text-slate-400 uppercase">
                        <tr>
                          <th className="py-2 pr-4">Gap</th>
                          <th className="py-2 pr-4">Casos</th>
                          <th className="py-2 pr-4">% learners</th>
                          <th className="py-2 pr-4">Última vez</th>
                        </tr>
                      </thead>
                      <tbody>
                        {topGaps.map((gap, index) => (
                          <tr key={`${gap.gap}-${index}`} className="border-t">
                            <td className="py-2 pr-4 text-slate-700">
                              {gap.gap}
                            </td>
                            <td className="py-2 pr-4">{gap.count_total}</td>
                            <td className="py-2 pr-4">
                              {Number(gap.percent_learners_affected).toFixed(2)}
                              %
                            </td>
                            <td className="py-2 pr-4 text-slate-500">
                              {gap.last_seen_at
                                ? new Date(gap.last_seen_at).toLocaleDateString(
                                    'es-AR',
                                  )
                                : '—'}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : (
                  <p className="mt-2 text-xs text-slate-500">
                    Sin gaps registrados.
                  </p>
                )}
              </div>

              <div>
                <p className="text-xs font-semibold text-slate-500 uppercase">
                  Riesgo por aprendiz
                </p>
                {sortedRisk.length > 0 ? (
                  <ul className="mt-2 flex flex-col gap-3 text-sm">
                    {sortedRisk.map((item) => {
                      const reasons = (item.reasons as string[] | null) ?? [];
                      const visibleReasons = reasons.slice(0, 2);
                      const badgeStyles =
                        item.risk_level === 'high'
                          ? 'bg-rose-100 text-rose-700'
                          : item.risk_level === 'medium'
                            ? 'bg-amber-100 text-amber-700'
                            : 'bg-emerald-100 text-emerald-700';

                      return (
                        <li
                          key={item.learner_id}
                          className="rounded-md border border-slate-200 p-3"
                        >
                          <div className="flex items-center justify-between gap-2 text-xs text-slate-500">
                            <span>{item.learner_id}</span>
                            <span
                              className={`rounded-full px-2 py-0.5 text-xs ${badgeStyles}`}
                            >
                              {item.risk_level ?? 'low'}
                            </span>
                          </div>
                          <div className="mt-2 flex flex-wrap gap-2 text-xs text-slate-500">
                            <span>
                              Práctica fail: {item.failed_practice_count ?? 0}
                            </span>
                            <span>
                              Final fail: {item.failed_final_count ?? 0}
                            </span>
                            <span>Dudas: {item.doubt_signals_count ?? 0}</span>
                          </div>
                          {visibleReasons.length > 0 ? (
                            <p className="mt-2 text-xs text-slate-600">
                              Razones: {visibleReasons.join(', ')}
                            </p>
                          ) : null}
                          <Link
                            href={`/referente/review/${item.learner_id}`}
                            className="mt-3 inline-flex text-xs font-semibold text-slate-700"
                          >
                            Ver detalle →
                          </Link>
                        </li>
                      );
                    })}
                  </ul>
                ) : (
                  <p className="mt-2 text-xs text-slate-500">
                    Sin riesgos detectados.
                  </p>
                )}
              </div>
            </div>
          )}
        </section>
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

      <div className="flex flex-wrap gap-2">
        {reviewHref ? (
          <Link
            href={reviewHref}
            className="rounded-md bg-slate-900 px-3 py-2 text-sm font-semibold text-white"
          >
            Abrir revisión
          </Link>
        ) : (
          <button
            type="button"
            disabled
            className="rounded-md bg-slate-200 px-3 py-2 text-sm font-semibold text-slate-500"
          >
            Abrir revisión
          </button>
        )}
        <Link
          href="/referente/alerts"
          className="rounded-md border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-700"
        >
          Ver alertas
        </Link>
      </div>

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="text-sm font-semibold text-slate-700">
          Métricas (30 días)
        </h2>
        {topGapsError || learnerRiskError ? (
          <p className="mt-2 text-sm text-slate-500">
            No se pudieron cargar métricas.
          </p>
        ) : (
          <div className="mt-3 flex flex-col gap-4">
            <div>
              <p className="text-xs font-semibold text-slate-500 uppercase">
                Top gaps del local
              </p>
              {topGaps && topGaps.length > 0 ? (
                <div className="mt-2 overflow-x-auto">
                  <table className="min-w-full text-left text-xs text-slate-600">
                    <thead className="text-[11px] text-slate-400 uppercase">
                      <tr>
                        <th className="py-2 pr-4">Gap</th>
                        <th className="py-2 pr-4">Casos</th>
                        <th className="py-2 pr-4">% learners</th>
                        <th className="py-2 pr-4">Última vez</th>
                      </tr>
                    </thead>
                    <tbody>
                      {topGaps.map((gap, index) => (
                        <tr key={`${gap.gap}-${index}`} className="border-t">
                          <td className="py-2 pr-4 text-slate-700">
                            {gap.gap}
                          </td>
                          <td className="py-2 pr-4">{gap.count_total}</td>
                          <td className="py-2 pr-4">
                            {Number(gap.percent_learners_affected).toFixed(2)}%
                          </td>
                          <td className="py-2 pr-4 text-slate-500">
                            {gap.last_seen_at
                              ? new Date(gap.last_seen_at).toLocaleDateString(
                                  'es-AR',
                                )
                              : '—'}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <p className="mt-2 text-xs text-slate-500">
                  Sin gaps registrados.
                </p>
              )}
            </div>

            <div>
              <p className="text-xs font-semibold text-slate-500 uppercase">
                Riesgo por aprendiz
              </p>
              {sortedRisk.length > 0 ? (
                <ul className="mt-2 flex flex-col gap-3 text-sm">
                  {sortedRisk.map((item) => {
                    const reasons = (item.reasons as string[] | null) ?? [];
                    const visibleReasons = reasons.slice(0, 2);
                    const badgeStyles =
                      item.risk_level === 'high'
                        ? 'bg-rose-100 text-rose-700'
                        : item.risk_level === 'medium'
                          ? 'bg-amber-100 text-amber-700'
                          : 'bg-emerald-100 text-emerald-700';

                    return (
                      <li
                        key={item.learner_id}
                        className="rounded-md border border-slate-200 p-3"
                      >
                        <div className="flex items-center justify-between gap-2 text-xs text-slate-500">
                          <span>{item.learner_id}</span>
                          <span
                            className={`rounded-full px-2 py-0.5 text-xs ${badgeStyles}`}
                          >
                            {item.risk_level ?? 'low'}
                          </span>
                        </div>
                        <div className="mt-2 flex flex-wrap gap-2 text-xs text-slate-500">
                          <span>
                            Práctica fail: {item.failed_practice_count ?? 0}
                          </span>
                          <span>
                            Final fail: {item.failed_final_count ?? 0}
                          </span>
                          <span>Dudas: {item.doubt_signals_count ?? 0}</span>
                        </div>
                        {visibleReasons.length > 0 ? (
                          <p className="mt-2 text-xs text-slate-600">
                            Razones: {visibleReasons.join(', ')}
                          </p>
                        ) : null}
                        <Link
                          href={`/referente/review/${item.learner_id}`}
                          className="mt-3 inline-flex text-xs font-semibold text-slate-700"
                        >
                          Ver detalle →
                        </Link>
                      </li>
                    );
                  })}
                </ul>
              ) : (
                <p className="mt-2 text-xs text-slate-500">
                  Sin riesgos detectados.
                </p>
              )}
            </div>
          </div>
        )}
      </section>

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
