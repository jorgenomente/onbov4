import Link from 'next/link';

import { requireUserAndRole } from '../../../../lib/server/requireRole';
import { getSupabaseServerClient } from '../../../../lib/server/supabase';
import {
  addKnowledgeToUnitAction,
  disableKnowledgeItemAction,
} from './actions';
import { DisableKnowledgeButton } from './DisableKnowledgeButton';

type SearchParams = Record<string, string | string[] | undefined>;

type PageProps = {
  searchParams: Promise<SearchParams>;
};

type CoverageRow = {
  program_id: string;
  program_name: string;
  unit_id: string;
  unit_order: number;
  unit_title: string;
  total_knowledge_count: number;
  org_level_knowledge_count: number;
  local_level_knowledge_count: number;
  has_any_mapping: boolean;
  is_missing_mapping: boolean;
};

type KnowledgeRow = {
  program_id: string;
  unit_id: string;
  unit_order: number;
  knowledge_id: string;
  knowledge_title: string;
  knowledge_scope: string;
  knowledge_created_at: string;
};

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

export default async function KnowledgeCoveragePage({
  searchParams,
}: PageProps) {
  await requireUserAndRole(['admin_org', 'superadmin']);

  const sp = await searchParams;
  const programId = coerceParam(sp?.programId) ?? '';
  const success = coerceParam(sp?.success);
  const error = coerceParam(sp?.error);
  const knowledgeId = coerceParam(sp?.knowledgeId);

  const supabase = await getSupabaseServerClient();

  const { data: programs, error: programsError } = await supabase
    .from('training_programs')
    .select('id, name, local_id, created_at')
    .order('created_at', { ascending: false });

  const hasPrograms = (programs ?? []).length > 0;
  const programSelected = programId.length > 0;

  const { data: summary, error: summaryError } = programSelected
    ? await supabase
        .from('v_org_program_knowledge_gaps_summary')
        .select(
          'program_id, program_name, total_units, units_missing_mapping, pct_units_missing_mapping, total_knowledge_mappings',
        )
        .eq('program_id', programId)
        .maybeSingle()
    : { data: null, error: null };

  const { data: units, error: unitsError } = programSelected
    ? await supabase
        .from('training_units')
        .select('id, unit_order, title')
        .eq('program_id', programId)
        .order('unit_order', { ascending: true })
    : { data: null, error: null };

  const { data: locals, error: localsError } = programSelected
    ? await supabase
        .from('locals')
        .select('id, name')
        .order('name', { ascending: true })
    : { data: null, error: null };

  const { data: coverage, error: coverageError } = programSelected
    ? await supabase
        .from('v_org_program_unit_knowledge_coverage')
        .select(
          'program_id, program_name, unit_id, unit_order, unit_title, total_knowledge_count, org_level_knowledge_count, local_level_knowledge_count, has_any_mapping, is_missing_mapping',
        )
        .eq('program_id', programId)
        .order('unit_order', { ascending: true })
    : { data: null, error: null };

  const { data: knowledgeList, error: knowledgeError } = programSelected
    ? await supabase
        .from('v_org_unit_knowledge_list')
        .select(
          'program_id, unit_id, unit_order, knowledge_id, knowledge_title, knowledge_scope, knowledge_created_at',
        )
        .eq('program_id', programId)
        .order('unit_order', { ascending: true })
    : { data: null, error: null };

  const knowledgeByUnit = new Map<string, KnowledgeRow[]>();
  (knowledgeList ?? []).forEach((row) => {
    const current = knowledgeByUnit.get(row.unit_id) ?? [];
    current.push(row);
    knowledgeByUnit.set(row.unit_id, current);
  });

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-5xl flex-col gap-6 px-4 py-6">
      <header className="flex flex-col gap-2">
        <div>
          <h1 className="text-2xl font-semibold text-slate-900">
            Cobertura de knowledge por unidad
          </h1>
          <p className="text-sm text-slate-500">
            Si una unidad no tiene knowledge, el bot falla al construir
            contexto.
          </p>
        </div>
      </header>

      <div className="flex flex-wrap gap-2">
        <Link
          href="/org/metrics"
          className="rounded-md border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-700"
        >
          Volver a métricas
        </Link>
      </div>

      {programsError ? (
        <div className="rounded-md border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          Error al cargar programas.
        </div>
      ) : null}

      {error ? (
        <div className="rounded-md border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          {decodeURIComponent(error)}
        </div>
      ) : null}

      {success === '1' ? (
        <div className="rounded-md border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-700">
          Knowledge agregado. ID: {knowledgeId ?? '—'}
        </div>
      ) : null}

      {success === 'disabled' ? (
        <div className="rounded-md border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-700">
          Knowledge desactivado.
        </div>
      ) : null}

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="text-base font-semibold text-slate-800">Programa</h2>
        <p className="text-xs text-slate-500">
          Seleccioná un programa para ver cobertura y gaps.
        </p>
        <form
          action="/org/config/knowledge-coverage"
          method="get"
          className="mt-3 flex gap-2"
        >
          <select
            name="programId"
            defaultValue={programId}
            className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm"
          >
            <option value="">Seleccionar programa</option>
            {(programs ?? []).map((program) => (
              <option key={program.id} value={program.id}>
                {program.name}
                {program.local_id ? ' · Local' : ' · Org'}
              </option>
            ))}
          </select>
          <button
            type="submit"
            className="rounded-md bg-slate-900 px-4 py-2 text-sm font-semibold text-white"
          >
            Ver
          </button>
        </form>
      </section>

      {!hasPrograms ? (
        <div className="rounded-md border border-slate-200 bg-slate-50 p-4 text-sm text-slate-600">
          No hay programas disponibles.
        </div>
      ) : null}

      {hasPrograms && !programSelected ? (
        <div className="rounded-md border border-dashed border-slate-200 p-4 text-sm text-slate-500">
          Seleccioná un programa para continuar.
        </div>
      ) : null}

      {programSelected ? (
        <section className="grid gap-6 lg:grid-cols-[1fr_1fr]">
          <article className="rounded-lg border border-slate-200 bg-white p-4">
            <h2 className="text-base font-semibold text-slate-800">
              Resumen del programa
            </h2>
            {summaryError ? (
              <div className="mt-3 rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
                Error al cargar resumen.
              </div>
            ) : null}

            {!summary ? (
              <div className="mt-3 rounded-md border border-slate-200 bg-slate-50 p-3 text-sm text-slate-600">
                Sin datos de resumen para este programa.
              </div>
            ) : (
              <dl className="mt-4 grid grid-cols-2 gap-3 text-sm">
                <div>
                  <dt className="text-xs text-slate-500">Unidades</dt>
                  <dd className="font-medium text-slate-800">
                    {summary.total_units}
                  </dd>
                </div>
                <div>
                  <dt className="text-xs text-slate-500">Gaps</dt>
                  <dd className="font-medium text-amber-700">
                    {summary.units_missing_mapping}
                  </dd>
                </div>
                <div>
                  <dt className="text-xs text-slate-500">% gaps</dt>
                  <dd className="font-medium text-slate-800">
                    {formatPercent(summary.pct_units_missing_mapping)}
                  </dd>
                </div>
                <div>
                  <dt className="text-xs text-slate-500">Mappings</dt>
                  <dd className="font-medium text-slate-800">
                    {summary.total_knowledge_mappings}
                  </dd>
                </div>
              </dl>
            )}
          </article>

          <article className="rounded-lg border border-slate-200 bg-white p-4">
            <h2 className="text-base font-semibold text-slate-800">
              Mensaje operativo
            </h2>
            <p className="mt-3 text-sm text-slate-600">
              Si una unidad no tiene knowledge asociado, el bot fallará al
              construir contexto. Priorizar gaps antes de habilitar nuevos
              learners.
            </p>
          </article>
        </section>
      ) : null}

      {programSelected ? (
        <section className="rounded-lg border border-slate-200 bg-white p-4">
          <div className="flex flex-col gap-2">
            <h2 className="text-base font-semibold text-slate-800">
              Agregar knowledge a unidad
            </h2>
            <p className="text-xs text-slate-500">
              Esto crea un item nuevo (append-only) y lo mapea a una unidad. No
              edita items existentes.
            </p>
          </div>

          {(unitsError || localsError) && (
            <div className="mt-3 rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
              Error al cargar unidades o locales.
            </div>
          )}

          <form
            action={addKnowledgeToUnitAction}
            className="mt-4 flex flex-col gap-4"
          >
            <input type="hidden" name="program_id" value={programId} />

            <div className="grid gap-4 sm:grid-cols-2">
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-xs text-slate-500">Unidad</span>
                <select
                  name="unit_id"
                  className="rounded-md border border-slate-300 bg-white px-3 py-2 text-sm"
                  required
                >
                  <option value="">Seleccionar unidad</option>
                  {(units ?? []).map((unit) => (
                    <option key={unit.id} value={unit.id}>
                      Unidad {unit.unit_order} · {unit.title}
                    </option>
                  ))}
                </select>
              </label>

              <label className="flex flex-col gap-1 text-sm">
                <span className="text-xs text-slate-500">Scope</span>
                <select
                  name="scope"
                  className="rounded-md border border-slate-300 bg-white px-3 py-2 text-sm"
                  required
                >
                  <option value="org">Compartido (Organización)</option>
                  <option value="local">Específico (Local)</option>
                </select>
              </label>

              <label className="flex flex-col gap-1 text-sm">
                <span className="text-xs text-slate-500">
                  Local (solo si scope=local)
                </span>
                <select
                  name="local_id"
                  className="rounded-md border border-slate-300 bg-white px-3 py-2 text-sm"
                >
                  <option value="">—</option>
                  {(locals ?? []).map((local) => (
                    <option key={local.id} value={local.id}>
                      {local.name}
                    </option>
                  ))}
                </select>
              </label>

              <label className="flex flex-col gap-1 text-sm">
                <span className="text-xs text-slate-500">Título</span>
                <input
                  type="text"
                  name="title"
                  maxLength={120}
                  placeholder="Introduccion (obligatorio)"
                  className="rounded-md border border-slate-300 px-3 py-2 text-sm"
                  required
                />
                <span className="text-[11px] text-slate-500">
                  Usa prefijos sugeridos: &quot;Introduccion
                  (obligatorio)&quot;, &quot;Estandar / reglas&quot;,
                  &quot;Ejemplo&quot;.
                </span>
              </label>
            </div>

            <label className="flex flex-col gap-1 text-sm">
              <span className="text-xs text-slate-500">Contenido</span>
              <textarea
                name="content"
                rows={5}
                placeholder="Texto breve y operativo (5-15 líneas)."
                className="rounded-md border border-slate-300 px-3 py-2 text-sm"
                required
              />
              <span className="text-[11px] text-slate-500">
                Evita manuales largos. Todo lo evaluado debe estar aca o en el
                recordatorio previo.
              </span>
            </label>

            <label className="flex flex-col gap-1 text-sm">
              <span className="text-xs text-slate-500">Motivo (opcional)</span>
              <textarea
                name="reason"
                rows={2}
                className="rounded-md border border-slate-300 px-3 py-2 text-sm"
              />
            </label>

            <button
              type="submit"
              className="rounded-md bg-slate-900 px-4 py-2 text-sm font-semibold text-white"
            >
              Agregar knowledge
            </button>
          </form>
        </section>
      ) : null}

      {programSelected ? (
        <section className="rounded-lg border border-slate-200 bg-white p-4">
          <div className="flex flex-col gap-2">
            <h2 className="text-base font-semibold text-slate-800">Unidades</h2>
            <p className="text-xs text-slate-500">
              Cobertura de knowledge por unidad (org-level vs local-specific).
            </p>
          </div>

          {coverageError ? (
            <div className="mt-3 rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
              Error al cargar unidades.
            </div>
          ) : null}

          {(coverage ?? []).length === 0 ? (
            <div className="mt-4 rounded-md border border-dashed border-slate-200 p-3 text-sm text-slate-500">
              Este programa no tiene unidades configuradas.
            </div>
          ) : (
            <div className="mt-4 space-y-3">
              {(coverage as CoverageRow[]).map((row) => {
                const unitKnowledge = knowledgeByUnit.get(row.unit_id) ?? [];
                return (
                  <div
                    key={row.unit_id}
                    className="rounded-lg border border-slate-200 p-3"
                  >
                    <div className="flex flex-col gap-1">
                      <div className="flex items-center justify-between gap-2">
                        <div className="text-sm font-semibold text-slate-800">
                          Unidad {row.unit_order}: {row.unit_title}
                        </div>
                        <span
                          className={`rounded-full px-2 py-1 text-xs font-semibold ${
                            row.is_missing_mapping
                              ? 'bg-amber-100 text-amber-800'
                              : 'bg-emerald-100 text-emerald-800'
                          }`}
                        >
                          {row.is_missing_mapping ? 'FALTA KNOWLEDGE' : 'OK'}
                        </span>
                      </div>
                      <div className="text-xs text-slate-500">
                        Total: {row.total_knowledge_count} · Org:{' '}
                        {row.org_level_knowledge_count} · Local:{' '}
                        {row.local_level_knowledge_count}
                      </div>
                    </div>

                    <details className="mt-3">
                      <summary className="cursor-pointer text-xs font-semibold text-slate-700">
                        Ver detalle
                      </summary>
                      {knowledgeError ? (
                        <div className="mt-2 rounded-md border border-red-200 bg-red-50 p-2 text-xs text-red-700">
                          Error al cargar detalle de knowledge.
                        </div>
                      ) : unitKnowledge.length === 0 ? (
                        <div className="mt-2 rounded-md border border-slate-200 bg-slate-50 p-2 text-xs text-slate-500">
                          Sin knowledge asociado.
                        </div>
                      ) : (
                        <ul className="mt-2 space-y-2 text-xs text-slate-600">
                          {unitKnowledge.map((item) => (
                            <li
                              key={item.knowledge_id}
                              className="rounded-md border border-slate-200 bg-white p-2"
                            >
                              <div className="flex items-center justify-between">
                                <span className="font-medium text-slate-800">
                                  {item.knowledge_title}
                                </span>
                                <span className="rounded-full bg-slate-100 px-2 py-0.5 text-[10px] text-slate-600">
                                  {item.knowledge_scope}
                                </span>
                              </div>
                              <div className="text-[11px] text-slate-500">
                                {formatDate(item.knowledge_created_at)}
                              </div>
                              <DisableKnowledgeButton
                                knowledgeId={item.knowledge_id}
                                programId={programId}
                                action={disableKnowledgeItemAction}
                              />
                            </li>
                          ))}
                        </ul>
                      )}
                    </details>
                  </div>
                );
              })}
            </div>
          )}
        </section>
      ) : null}
    </main>
  );
}
