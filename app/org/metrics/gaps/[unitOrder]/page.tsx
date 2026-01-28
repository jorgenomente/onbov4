import Link from 'next/link';

import { requireUserAndRole } from '../../../../../lib/server/requireRole';
import { getSupabaseServerClient } from '../../../../../lib/server/supabase';

type PageProps = {
  params: Promise<{ unitOrder: string }>;
};

type GapLocalRow = {
  org_id: string;
  gap_key: string;
  local_id: string;
  local_name: string | null;
  learners_affected_count: number;
  percent_learners_affected_local: number;
  total_events_30d: number;
  last_event_at: string | null;
};

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

export default async function GapLocalsPage({ params }: PageProps) {
  await requireUserAndRole(['admin_org', 'superadmin']);

  const { unitOrder } = await params;
  const gapKey = decodeURIComponent(unitOrder);

  const supabase = await getSupabaseServerClient();

  const { data, error } = await supabase
    .from('v_org_gap_locals_30d')
    .select(
      'org_id, gap_key, local_id, local_name, learners_affected_count, percent_learners_affected_local, total_events_30d, last_event_at',
    )
    .eq('gap_key', gapKey)
    .order('total_events_30d', { ascending: false });

  if (error) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-4 px-4 py-6">
        <div className="flex flex-wrap gap-2">
          <Link
            href="/org/metrics"
            className="rounded-md bg-slate-900 px-3 py-2 text-sm font-semibold text-white"
          >
            Volver a métricas
          </Link>
          <Link
            href="/org/config/knowledge-coverage"
            className="rounded-md border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-700"
          >
            Cobertura de knowledge
          </Link>
        </div>
        <p className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Error al cargar el detalle del gap.
        </p>
      </main>
    );
  }

  const rows = (data as GapLocalRow[]) ?? [];

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-6 px-4 py-6">
      <header className="flex flex-col gap-2">
        <div>
          <h1 className="text-2xl font-semibold text-slate-900">Gap</h1>
          <p className="text-sm text-slate-500">{gapKey}</p>
        </div>
      </header>

      <div className="flex flex-wrap gap-2">
        <Link
          href="/org/metrics"
          className="rounded-md bg-slate-900 px-3 py-2 text-sm font-semibold text-white"
        >
          Volver a métricas
        </Link>
        <Link
          href="/org/config/knowledge-coverage"
          className="rounded-md border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-700"
        >
          Cobertura de knowledge
        </Link>
      </div>

      {rows.length === 0 ? (
        <div className="rounded-md border border-dashed border-slate-200 p-4 text-sm text-slate-500">
          No hay actividad para este gap en 30 días.
        </div>
      ) : (
        <section className="rounded-lg border border-slate-200 bg-white p-4">
          <h2 className="text-base font-semibold text-slate-800">
            Distribución por local
          </h2>
          <div className="mt-4 overflow-x-auto">
            <table className="min-w-full text-left text-xs text-slate-600">
              <thead className="border-b border-slate-200 text-[11px] text-slate-400 uppercase">
                <tr>
                  <th className="px-3 py-2">Local</th>
                  <th className="px-3 py-2">Learners afectados</th>
                  <th className="px-3 py-2">% local</th>
                  <th className="px-3 py-2">Eventos</th>
                  <th className="px-3 py-2">Última señal</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {rows.map((row) => (
                  <tr key={row.local_id}>
                    <td className="px-3 py-2 text-slate-700">
                      {row.local_name ?? row.local_id}
                    </td>
                    <td className="px-3 py-2 text-slate-700">
                      {row.learners_affected_count}
                    </td>
                    <td className="px-3 py-2 text-slate-500">
                      {formatPercent(row.percent_learners_affected_local)}
                    </td>
                    <td className="px-3 py-2 text-slate-500">
                      {row.total_events_30d}
                    </td>
                    <td className="px-3 py-2 text-slate-500">
                      {formatDate(row.last_event_at)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      <div className="text-xs text-slate-500">
        Para ver cobertura por unidad, revisá la pestaña Cobertura.
      </div>
    </main>
  );
}
