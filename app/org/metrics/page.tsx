import Link from 'next/link';

import { requireUserAndRole } from '../../../lib/server/requireRole';
import { getSupabaseServerClient } from '../../../lib/server/supabase';

type SearchParams = Record<string, string | string[] | undefined>;

type PageProps = {
  searchParams: Promise<SearchParams>;
};

type GapRow = {
  org_id: string;
  gap_key: string;
  unit_order: number | null;
  title: string | null;
  learners_affected_count: number;
  percent_learners_affected: number;
  total_fail_events: number;
  window_days: number;
};

type RiskRow = {
  org_id: string;
  local_id: string;
  learner_id: string;
  risk_level: string;
  risk_score: number;
  signals_count_30d: number;
  last_signal_at: string | null;
};

type CoverageRow = {
  org_id: string;
  local_id: string;
  local_name: string | null;
  program_id: string;
  unit_order: number;
  coverage_percent: number | null;
  learners_active_count: number | null;
  learners_with_evidence_count: number | null;
  last_activity_at: string | null;
};

const TABS = [
  { id: 'summary', label: 'Resumen' },
  { id: 'gaps', label: 'Gaps' },
  { id: 'coverage', label: 'Cobertura' },
  { id: 'risk', label: 'Riesgo' },
];

function coerceParam(value?: string | string[]) {
  if (!value) return undefined;
  return Array.isArray(value) ? value[0] : value;
}

function formatPercent(value: number | null | undefined) {
  if (value === null || value === undefined) return '—';
  return `${Number(value).toFixed(1)}%`;
}

function formatDate(value: string | null | undefined) {
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleDateString('es-AR', { dateStyle: 'medium' });
}

export default async function OrgMetricsPage({ searchParams }: PageProps) {
  await requireUserAndRole(['admin_org', 'superadmin']);

  const sp = await searchParams;
  const tab = coerceParam(sp?.tab) ?? 'summary';
  const activeTab = TABS.some((t) => t.id === tab) ? tab : 'summary';

  const supabase = await getSupabaseServerClient();

  const { data: gaps, error: gapsError } = await supabase
    .from('v_org_top_gaps_30d')
    .select(
      'org_id, gap_key, unit_order, title, learners_affected_count, percent_learners_affected, total_fail_events, window_days',
    )
    .order('total_fail_events', { ascending: false })
    .limit(50);

  const { data: risks, error: riskError } = await supabase
    .from('v_org_learner_risk_30d')
    .select(
      'org_id, local_id, learner_id, risk_level, risk_score, signals_count_30d, last_signal_at',
    )
    .order('risk_score', { ascending: false })
    .limit(100);

  const { data: coverage, error: coverageError } = await supabase
    .from('v_org_unit_coverage_30d')
    .select(
      'org_id, local_id, local_name, program_id, unit_order, coverage_percent, learners_active_count, learners_with_evidence_count, last_activity_at',
    )
    .order('coverage_percent', { ascending: true })
    .limit(200);

  const topGap = (gaps ?? [])[0];
  const learnersAtRisk = (risks ?? []).length;
  const avgCoverage =
    (coverage ?? []).length > 0
      ? (coverage ?? []).reduce((acc, row) => {
          const value = row.coverage_percent ?? 0;
          return acc + value;
        }, 0) / (coverage ?? []).length
      : null;

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-6xl flex-col gap-6 px-4 py-6">
      <header className="flex flex-col gap-2">
        <Link href="/" className="text-xs text-slate-500">
          ← Volver
        </Link>
        <div>
          <h1 className="text-2xl font-semibold text-slate-900">
            Métricas (últimos 30 días)
          </h1>
          <p className="text-sm text-slate-500">
            Operación a nivel organización (read-only).
          </p>
        </div>
      </header>

      {(gapsError || riskError || coverageError) && (
        <div className="rounded-md border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          Error al cargar métricas. Intentá nuevamente.
        </div>
      )}

      <nav className="flex flex-wrap gap-2">
        {TABS.map((tabItem) => (
          <Link
            key={tabItem.id}
            href={`/org/metrics?tab=${tabItem.id}`}
            className={`rounded-full px-3 py-1 text-xs font-semibold ${
              activeTab === tabItem.id
                ? 'bg-slate-900 text-white'
                : 'bg-slate-100 text-slate-600'
            }`}
          >
            {tabItem.label}
          </Link>
        ))}
      </nav>

      {activeTab === 'summary' ? (
        <section className="grid gap-4 sm:grid-cols-3">
          <div className="rounded-lg border border-slate-200 bg-white p-4">
            <p className="text-xs text-slate-500">Learners en riesgo</p>
            <p className="text-2xl font-semibold text-slate-900">
              {learnersAtRisk}
            </p>
          </div>
          <div className="rounded-lg border border-slate-200 bg-white p-4">
            <p className="text-xs text-slate-500">Top gap</p>
            <p className="text-base font-semibold text-slate-900">
              {topGap?.title ?? '—'}
            </p>
            <p className="text-xs text-slate-500">
              {topGap?.learners_affected_count ?? 0} learners afectados
            </p>
          </div>
          <div className="rounded-lg border border-slate-200 bg-white p-4">
            <p className="text-xs text-slate-500">Cobertura promedio</p>
            <p className="text-2xl font-semibold text-slate-900">
              {avgCoverage === null ? '—' : formatPercent(avgCoverage)}
            </p>
          </div>
        </section>
      ) : null}

      {activeTab === 'gaps' ? (
        <section className="rounded-lg border border-slate-200 bg-white p-4">
          <h2 className="text-base font-semibold text-slate-800">Top gaps</h2>
          {(gaps ?? []).length === 0 ? (
            <div className="mt-3 rounded-md border border-dashed border-slate-200 p-3 text-sm text-slate-500">
              Sin gaps detectados en 30 días.
            </div>
          ) : (
            <div className="mt-4 overflow-x-auto">
              <table className="min-w-full text-left text-xs text-slate-600">
                <thead className="border-b border-slate-200 text-[11px] text-slate-400 uppercase">
                  <tr>
                    <th className="px-3 py-2">Gap</th>
                    <th className="px-3 py-2">Learners afectados</th>
                    <th className="px-3 py-2">% afectados</th>
                    <th className="px-3 py-2">Eventos</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {(gaps as GapRow[]).map((row) => (
                    <tr key={row.gap_key}>
                      <td className="px-3 py-2 text-slate-700">
                        {row.title ?? row.gap_key}
                      </td>
                      <td className="px-3 py-2 text-slate-700">
                        {row.learners_affected_count}
                      </td>
                      <td className="px-3 py-2 text-slate-500">
                        {formatPercent(row.percent_learners_affected)}
                      </td>
                      <td className="px-3 py-2 text-slate-500">
                        {row.total_fail_events}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      ) : null}

      {activeTab === 'coverage' ? (
        <section className="rounded-lg border border-slate-200 bg-white p-4">
          <h2 className="text-base font-semibold text-slate-800">Cobertura</h2>
          {(coverage ?? []).length === 0 ? (
            <div className="mt-3 rounded-md border border-dashed border-slate-200 p-3 text-sm text-slate-500">
              Sin cobertura en 30 días.
            </div>
          ) : (
            <div className="mt-4 overflow-x-auto">
              <table className="min-w-full text-left text-xs text-slate-600">
                <thead className="border-b border-slate-200 text-[11px] text-slate-400 uppercase">
                  <tr>
                    <th className="px-3 py-2">Local</th>
                    <th className="px-3 py-2">Unidad</th>
                    <th className="px-3 py-2">Cobertura</th>
                    <th className="px-3 py-2">Actividad</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {(coverage as CoverageRow[]).map((row) => (
                    <tr key={`${row.local_id}-${row.unit_order}`}>
                      <td className="px-3 py-2 text-slate-700">
                        {row.local_name ?? row.local_id}
                      </td>
                      <td className="px-3 py-2 text-slate-700">
                        Unidad {row.unit_order}
                      </td>
                      <td className="px-3 py-2 text-slate-500">
                        {formatPercent(row.coverage_percent)}
                      </td>
                      <td className="px-3 py-2 text-slate-500">
                        {formatDate(row.last_activity_at)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      ) : null}

      {activeTab === 'risk' ? (
        <section className="rounded-lg border border-slate-200 bg-white p-4">
          <h2 className="text-base font-semibold text-slate-800">Riesgo</h2>
          {(risks ?? []).length === 0 ? (
            <div className="mt-3 rounded-md border border-dashed border-slate-200 p-3 text-sm text-slate-500">
              Sin learners en riesgo en 30 días.
            </div>
          ) : (
            <div className="mt-4 overflow-x-auto">
              <table className="min-w-full text-left text-xs text-slate-600">
                <thead className="border-b border-slate-200 text-[11px] text-slate-400 uppercase">
                  <tr>
                    <th className="px-3 py-2">Learner</th>
                    <th className="px-3 py-2">Local</th>
                    <th className="px-3 py-2">Nivel</th>
                    <th className="px-3 py-2">Última señal</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {(risks as RiskRow[]).map((row) => (
                    <tr key={row.learner_id}>
                      <td className="px-3 py-2 text-slate-700">
                        {row.learner_id}
                      </td>
                      <td className="px-3 py-2 text-slate-700">
                        {row.local_id}
                      </td>
                      <td className="px-3 py-2 text-slate-500">
                        {row.risk_level}
                      </td>
                      <td className="px-3 py-2 text-slate-500">
                        {formatDate(row.last_signal_at)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      ) : null}
    </main>
  );
}
