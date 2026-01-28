import Link from 'next/link';

import { requireUserAndRole } from '../../../../../../lib/server/requireRole';
import { getSupabaseServerClient } from '../../../../../../lib/server/supabase';

type PageProps = {
  params: Promise<{ programId: string; unitOrder: string }>;
};

type CoverageRow = {
  local_id: string;
  local_name: string | null;
  coverage_percent: number | null;
  learners_active_count: number | null;
  learners_with_evidence_count: number | null;
  last_activity_at: string | null;
};

type KnowledgeRow = {
  program_name: string | null;
  unit_title: string | null;
  unit_order: number;
  knowledge_id: string;
  knowledge_title: string;
  knowledge_scope: string;
  knowledge_created_at: string | null;
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

export default async function CoverageDetailPage({ params }: PageProps) {
  await requireUserAndRole(['admin_org', 'superadmin']);

  const { programId, unitOrder } = await params;
  const unitOrderNumber = Number(unitOrder);

  if (!programId || Number.isNaN(unitOrderNumber)) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-4xl flex-col gap-4 px-4 py-6">
        <Link
          href="/org/metrics?tab=coverage"
          className="text-xs text-slate-500"
        >
          ← Volver a cobertura
        </Link>
        <p className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Parámetros inválidos para cobertura.
        </p>
      </main>
    );
  }

  const supabase = await getSupabaseServerClient();

  const { data: coverageData, error: coverageError } = await supabase
    .from('v_org_unit_coverage_30d')
    .select(
      'local_id, local_name, coverage_percent, learners_active_count, learners_with_evidence_count, last_activity_at',
    )
    .eq('program_id', programId)
    .eq('unit_order', unitOrderNumber)
    .order('coverage_percent', { ascending: true });

  const { data: knowledgeData, error: knowledgeError } = await supabase
    .from('v_org_unit_knowledge_active')
    .select(
      'program_name, unit_title, unit_order, knowledge_id, knowledge_title, knowledge_scope, knowledge_created_at',
    )
    .eq('program_id', programId)
    .eq('unit_order', unitOrderNumber)
    .order('knowledge_created_at', { ascending: false });

  if (coverageError || knowledgeError) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-4xl flex-col gap-4 px-4 py-6">
        <Link
          href="/org/metrics?tab=coverage"
          className="text-xs text-slate-500"
        >
          ← Volver a cobertura
        </Link>
        <p className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Error al cargar el detalle de cobertura.
        </p>
      </main>
    );
  }

  const coverageRows = (coverageData as CoverageRow[]) ?? [];
  const knowledgeRows = (knowledgeData as KnowledgeRow[]) ?? [];
  const headerProgram = knowledgeRows[0]?.program_name ?? programId;
  const headerUnitTitle = knowledgeRows[0]?.unit_title;

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-4xl flex-col gap-6 px-4 py-6">
      <header className="flex flex-col gap-2">
        <Link
          href="/org/metrics?tab=coverage"
          className="text-xs text-slate-500"
        >
          ← Volver a cobertura
        </Link>
        <div>
          <h1 className="text-2xl font-semibold text-slate-900">
            Cobertura unidad {unitOrderNumber}
          </h1>
          <p className="text-sm text-slate-500">
            {headerProgram}
            {headerUnitTitle ? ` · ${headerUnitTitle}` : ''}
          </p>
        </div>
      </header>

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="text-base font-semibold text-slate-800">
          Cobertura por local
        </h2>
        {coverageRows.length === 0 ? (
          <div className="mt-3 rounded-md border border-dashed border-slate-200 p-3 text-sm text-slate-500">
            Sin actividad registrada en 30 días.
          </div>
        ) : (
          <div className="mt-4 overflow-x-auto">
            <table className="min-w-full text-left text-xs text-slate-600">
              <thead className="border-b border-slate-200 text-[11px] text-slate-400 uppercase">
                <tr>
                  <th className="px-3 py-2">Local</th>
                  <th className="px-3 py-2">Cobertura</th>
                  <th className="px-3 py-2">Learners activos</th>
                  <th className="px-3 py-2">Con evidencia</th>
                  <th className="px-3 py-2">Última actividad</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {coverageRows.map((row) => (
                  <tr key={row.local_id}>
                    <td className="px-3 py-2 text-slate-700">
                      {row.local_name ?? row.local_id}
                    </td>
                    <td className="px-3 py-2 text-slate-500">
                      {formatPercent(row.coverage_percent)}
                    </td>
                    <td className="px-3 py-2 text-slate-500">
                      {row.learners_active_count ?? 0}
                    </td>
                    <td className="px-3 py-2 text-slate-500">
                      {row.learners_with_evidence_count ?? 0}
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

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="text-base font-semibold text-slate-800">
          Knowledge activo de la unidad
        </h2>
        <p className="mt-1 text-xs text-slate-500">
          Knowledge desactivado no aparece en esta lista.
        </p>
        {knowledgeRows.length === 0 ? (
          <div className="mt-3 rounded-md border border-dashed border-slate-200 p-3 text-sm text-slate-500">
            Sin knowledge activo mapeado a esta unidad.
          </div>
        ) : (
          <div className="mt-4 space-y-3">
            {knowledgeRows.map((row) => (
              <div
                key={row.knowledge_id}
                className="rounded-md border border-slate-200 p-3"
              >
                <div className="flex items-center justify-between text-xs text-slate-500">
                  <span>{row.knowledge_scope === 'org' ? 'Org' : 'Local'}</span>
                  <span>{formatDate(row.knowledge_created_at)}</span>
                </div>
                <p className="mt-1 text-sm font-semibold text-slate-800">
                  {row.knowledge_title}
                </p>
              </div>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
