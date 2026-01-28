import Link from 'next/link';

import { requireUserAndRole } from '../../../../lib/server/requireRole';
import { getSupabaseServerClient } from '../../../../lib/server/supabase';
import { createFinalEvalConfigAction } from './actions';

type SearchParams = {
  programId?: string | string[];
  success?: string | string[];
  error?: string | string[];
  configId?: string | string[];
};

function coerceParam(value?: string | string[]) {
  if (!value) return undefined;
  return Array.isArray(value) ? value[0] : value;
}

function formatPercent(value: number | null | undefined) {
  if (value === null || value === undefined) return '—';
  const percent = Math.round(Number(value) * 100);
  return `${percent}%`;
}

function formatNumber(value: number | null | undefined) {
  if (value === null || value === undefined) return '—';
  return Number(value).toString();
}

function formatDate(value: string | null | undefined) {
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleString('es-AR', {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
}

type PageProps = {
  searchParams: Promise<SearchParams>;
};

export default async function OrgBotConfigPage({ searchParams }: PageProps) {
  await requireUserAndRole(['admin_org', 'superadmin']);

  const supabase = await getSupabaseServerClient();

  const sp = await searchParams;
  const programId = coerceParam(sp?.programId) ?? '';
  const success = coerceParam(sp?.success);
  const error = coerceParam(sp?.error);
  const configId = coerceParam(sp?.configId);

  const { data: programs, error: programsError } = await supabase
    .from('training_programs')
    .select('id, name, local_id, created_at')
    .order('created_at', { ascending: false });

  const hasPrograms = (programs ?? []).length > 0;

  const programSelected = programId.length > 0;

  const { data: currentConfig, error: currentError } = programSelected
    ? await supabase
        .from('v_org_program_final_eval_config_current')
        .select(
          'program_id, program_name, config_id, total_questions, roleplay_ratio, min_global_score, must_pass_units, questions_per_unit, max_attempts, cooldown_hours, config_created_at',
        )
        .eq('program_id', programId)
        .maybeSingle()
    : { data: null, error: null };

  const { data: history, error: historyError } = programSelected
    ? await supabase
        .from('v_org_program_final_eval_config_history')
        .select(
          'config_id, total_questions, roleplay_ratio, min_global_score, max_attempts, cooldown_hours, config_created_at',
        )
        .eq('program_id', programId)
        .order('config_created_at', { ascending: false })
        .limit(10)
    : { data: null, error: null };

  const { data: units, error: unitsError } = programSelected
    ? await supabase
        .from('training_units')
        .select('unit_order, title')
        .eq('program_id', programId)
        .order('unit_order', { ascending: true })
    : { data: null, error: null };

  const { data: coverage, error: coverageError } = programSelected
    ? await supabase
        .from('v_org_program_unit_knowledge_coverage')
        .select('unit_order, unit_title, is_missing_knowledge_mapping')
        .eq('program_id', programId)
        .order('unit_order', { ascending: true })
    : { data: null, error: null };

  const missingKnowledge = (coverage ?? []).filter(
    (row) => row.is_missing_knowledge_mapping,
  );

  const configMissing =
    programSelected && (!currentConfig || !currentConfig.config_id);

  const defaultTotalQuestions = Number(currentConfig?.total_questions) || 10;
  const defaultRoleplayPercent =
    currentConfig?.roleplay_ratio !== null &&
    currentConfig?.roleplay_ratio !== undefined
      ? Math.round(Number(currentConfig.roleplay_ratio) * 100)
      : 40;
  const defaultMinScore = Number(currentConfig?.min_global_score) || 75;
  const defaultQuestionsPerUnit =
    Number(currentConfig?.questions_per_unit) || 2;
  const defaultMaxAttempts = Number(currentConfig?.max_attempts) || 3;
  const defaultCooldown = Number(currentConfig?.cooldown_hours) || 12;
  const defaultMustPass = (
    (currentConfig?.must_pass_units as number[] | null | undefined) ?? []
  ).map((value: number) => String(value));

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-5xl flex-col gap-6 px-4 py-6">
      <header className="flex flex-col gap-2">
        <div>
          <h1 className="text-2xl font-semibold text-slate-900">
            Configuración de evaluación final
          </h1>
          <p className="text-sm text-slate-500">
            Admin Org · Configuración insert-only por programa.
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
          Error al cargar programas. Intentá nuevamente.
        </div>
      ) : null}

      {error ? (
        <div className="rounded-md border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          {decodeURIComponent(error)}
        </div>
      ) : null}

      {success === '1' ? (
        <div className="rounded-md border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-700">
          Nueva configuración guardada. ID: {configId ?? '—'}
        </div>
      ) : null}

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <div className="flex flex-col gap-2">
          <h2 className="text-base font-semibold text-slate-800">Programa</h2>
          <p className="text-xs text-slate-500">
            Seleccioná el programa para ver la configuración vigente e
            historial.
          </p>
          <form action="/org/config/bot" method="get" className="flex gap-2">
            <select
              name="programId"
              defaultValue={programId || ''}
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
        </div>
      </section>

      {!hasPrograms ? (
        <div className="rounded-md border border-slate-200 bg-slate-50 p-4 text-sm text-slate-600">
          No hay programas disponibles para configurar.
        </div>
      ) : null}

      {hasPrograms && !programSelected ? (
        <div className="rounded-md border border-dashed border-slate-200 p-4 text-sm text-slate-500">
          Seleccioná un programa para continuar.
        </div>
      ) : null}

      {programSelected ? (
        <section className="grid gap-6 lg:grid-cols-[1.1fr_0.9fr]">
          <div className="flex flex-col gap-6">
            <article className="rounded-lg border border-slate-200 bg-white p-4">
              <div className="flex flex-col gap-2">
                <h2 className="text-base font-semibold text-slate-800">
                  Configuración vigente
                </h2>
                <p className="text-xs text-slate-500">
                  Visible para el programa seleccionado.
                </p>
              </div>

              {currentError ? (
                <div className="mt-3 rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
                  Error al cargar configuración vigente.
                </div>
              ) : null}

              {configMissing ? (
                <div className="mt-3 rounded-md border border-amber-200 bg-amber-50 p-3 text-sm text-amber-700">
                  Falta configuración (config_missing).
                </div>
              ) : null}

              <dl className="mt-4 grid grid-cols-2 gap-3 text-sm">
                <div>
                  <dt className="text-xs text-slate-500">Total preguntas</dt>
                  <dd className="font-medium text-slate-800">
                    {formatNumber(currentConfig?.total_questions)}
                  </dd>
                </div>
                <div>
                  <dt className="text-xs text-slate-500">Roleplay</dt>
                  <dd className="font-medium text-slate-800">
                    {formatPercent(currentConfig?.roleplay_ratio)}
                  </dd>
                </div>
                <div>
                  <dt className="text-xs text-slate-500">Min score</dt>
                  <dd className="font-medium text-slate-800">
                    {formatNumber(currentConfig?.min_global_score)}
                  </dd>
                </div>
                <div>
                  <dt className="text-xs text-slate-500">
                    Preguntas por unidad
                  </dt>
                  <dd className="font-medium text-slate-800">
                    {formatNumber(currentConfig?.questions_per_unit)}
                  </dd>
                </div>
                <div>
                  <dt className="text-xs text-slate-500">Unidades críticas</dt>
                  <dd className="font-medium text-slate-800">
                    {(currentConfig?.must_pass_units ?? []).length > 0
                      ? (currentConfig?.must_pass_units ?? []).join(', ')
                      : '—'}
                  </dd>
                </div>
                <div>
                  <dt className="text-xs text-slate-500">Máx. intentos</dt>
                  <dd className="font-medium text-slate-800">
                    {formatNumber(currentConfig?.max_attempts)}
                  </dd>
                </div>
                <div>
                  <dt className="text-xs text-slate-500">Cooldown (hs)</dt>
                  <dd className="font-medium text-slate-800">
                    {formatNumber(currentConfig?.cooldown_hours)}
                  </dd>
                </div>
                <div>
                  <dt className="text-xs text-slate-500">
                    Última actualización
                  </dt>
                  <dd className="font-medium text-slate-800">
                    {formatDate(currentConfig?.config_created_at)}
                  </dd>
                </div>
              </dl>
            </article>

            <article className="rounded-lg border border-slate-200 bg-white p-4">
              <div className="flex flex-col gap-2">
                <h2 className="text-base font-semibold text-slate-800">
                  Nueva configuración (aplica desde ahora)
                </h2>
                <p className="text-xs text-slate-500">
                  Se crea una nueva versión. No modifica intentos anteriores.
                  (Append-only)
                </p>
              </div>

              <form
                action={createFinalEvalConfigAction}
                className="mt-4 flex flex-col gap-4"
              >
                <input type="hidden" name="program_id" value={programId} />

                <div className="grid gap-4 sm:grid-cols-2">
                  <label className="flex flex-col gap-1 text-sm">
                    <span className="text-xs text-slate-500">
                      Total preguntas
                    </span>
                    <input
                      type="number"
                      name="total_questions"
                      min={1}
                      defaultValue={defaultTotalQuestions}
                      className="rounded-md border border-slate-300 px-3 py-2"
                      required
                    />
                  </label>
                  <label className="flex flex-col gap-1 text-sm">
                    <span className="text-xs text-slate-500">Roleplay %</span>
                    <input
                      type="number"
                      name="roleplay_percent"
                      min={0}
                      max={100}
                      defaultValue={defaultRoleplayPercent}
                      className="rounded-md border border-slate-300 px-3 py-2"
                      required
                    />
                  </label>
                  <label className="flex flex-col gap-1 text-sm">
                    <span className="text-xs text-slate-500">
                      Min score (0–100)
                    </span>
                    <input
                      type="number"
                      name="min_global_score"
                      min={0}
                      max={100}
                      defaultValue={defaultMinScore}
                      className="rounded-md border border-slate-300 px-3 py-2"
                      required
                    />
                  </label>
                  <label className="flex flex-col gap-1 text-sm">
                    <span className="text-xs text-slate-500">
                      Preguntas por unidad
                    </span>
                    <input
                      type="number"
                      name="questions_per_unit"
                      min={1}
                      defaultValue={defaultQuestionsPerUnit}
                      className="rounded-md border border-slate-300 px-3 py-2"
                      required
                    />
                  </label>
                  <label className="flex flex-col gap-1 text-sm">
                    <span className="text-xs text-slate-500">
                      Máx. intentos
                    </span>
                    <input
                      type="number"
                      name="max_attempts"
                      min={1}
                      defaultValue={defaultMaxAttempts}
                      className="rounded-md border border-slate-300 px-3 py-2"
                      required
                    />
                  </label>
                  <label className="flex flex-col gap-1 text-sm">
                    <span className="text-xs text-slate-500">
                      Cooldown (hs)
                    </span>
                    <input
                      type="number"
                      name="cooldown_hours"
                      min={0}
                      defaultValue={defaultCooldown}
                      className="rounded-md border border-slate-300 px-3 py-2"
                      required
                    />
                  </label>
                </div>

                <div className="flex flex-col gap-1 text-sm">
                  <span className="text-xs text-slate-500">
                    Unidades críticas (must_pass_units)
                  </span>
                  {(units ?? []).length === 0 ? (
                    <div className="rounded-md border border-slate-200 bg-slate-50 p-3 text-xs text-slate-500">
                      No hay unidades cargadas para este programa.
                    </div>
                  ) : (
                    <select
                      name="must_pass_units"
                      multiple
                      defaultValue={defaultMustPass}
                      className="h-32 rounded-md border border-slate-300 px-3 py-2 text-sm"
                    >
                      {(units ?? []).map((unit) => (
                        <option key={unit.unit_order} value={unit.unit_order}>
                          Unidad {unit.unit_order} · {unit.title}
                        </option>
                      ))}
                    </select>
                  )}
                  <p className="text-xs text-slate-500">
                    Seleccioná las unidades que deben aprobarse (si aplica).
                  </p>
                </div>

                <button
                  type="submit"
                  className="rounded-md bg-slate-900 px-4 py-2 text-sm font-semibold text-white"
                >
                  Guardar nueva configuración
                </button>
              </form>
            </article>
          </div>

          <div className="flex flex-col gap-6">
            <article className="rounded-lg border border-slate-200 bg-white p-4">
              <div className="flex flex-col gap-2">
                <h2 className="text-base font-semibold text-slate-800">
                  Historial
                </h2>
                <p className="text-xs text-slate-500">
                  Últimas 10 configuraciones por programa.
                </p>
              </div>

              {historyError ? (
                <div className="mt-3 rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
                  Error al cargar historial.
                </div>
              ) : null}

              {(history ?? []).length === 0 ? (
                <div className="mt-4 rounded-md border border-dashed border-slate-200 p-3 text-sm text-slate-500">
                  Sin historial disponible.
                </div>
              ) : (
                <div className="mt-4 overflow-x-auto">
                  <table className="w-full text-left text-xs text-slate-600">
                    <thead className="border-b border-slate-200">
                      <tr>
                        <th className="pb-2 font-medium">Fecha</th>
                        <th className="pb-2 font-medium">Total</th>
                        <th className="pb-2 font-medium">Roleplay</th>
                        <th className="pb-2 font-medium">Min score</th>
                        <th className="pb-2 font-medium">Intentos</th>
                        <th className="pb-2 font-medium">Cooldown</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                      {(history ?? []).map((item) => (
                        <tr key={item.config_id}>
                          <td className="py-2">
                            {formatDate(item.config_created_at)}
                          </td>
                          <td className="py-2">
                            {formatNumber(item.total_questions)}
                          </td>
                          <td className="py-2">
                            {formatPercent(item.roleplay_ratio)}
                          </td>
                          <td className="py-2">
                            {formatNumber(item.min_global_score)}
                          </td>
                          <td className="py-2">
                            {formatNumber(item.max_attempts)}
                          </td>
                          <td className="py-2">
                            {formatNumber(item.cooldown_hours)}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </article>

            <article className="rounded-lg border border-slate-200 bg-white p-4">
              <div className="flex flex-col gap-2">
                <h2 className="text-base font-semibold text-slate-800">
                  Warnings coverage
                </h2>
                <p className="text-xs text-slate-500">
                  Unidades sin knowledge mapping rompen el chat.
                </p>
              </div>

              {coverageError ? (
                <div className="mt-3 rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
                  Error al cargar coverage.
                </div>
              ) : null}

              {missingKnowledge.length === 0 ? (
                <div className="mt-4 rounded-md border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-700">
                  No se detectaron unidades sin knowledge mapping.
                </div>
              ) : (
                <ul className="mt-4 space-y-2 text-sm text-amber-700">
                  {missingKnowledge.map((row) => (
                    <li
                      key={row.unit_order}
                      className="rounded-md border border-amber-200 bg-amber-50 p-3"
                    >
                      Unidad {row.unit_order}: {row.unit_title}
                    </li>
                  ))}
                </ul>
              )}
            </article>

            <article className="rounded-lg border border-slate-200 bg-slate-50 p-4 text-xs text-slate-500">
              Esta pantalla es de solo configuración. No cambia intentos
              anteriores.
            </article>
          </div>
        </section>
      ) : null}

      {unitsError ? (
        <div className="rounded-md border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          Error al cargar unidades del programa.
        </div>
      ) : null}
    </main>
  );
}
