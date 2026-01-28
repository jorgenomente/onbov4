import Link from 'next/link';

import { requireUserAndRole } from '../../../lib/server/requireRole';
import { getSupabaseServerClient } from '../../../lib/server/supabase';
import PracticeScenarioPanel from './_components/PracticeScenarioPanel';

type SearchParams = Record<string, string | string[] | undefined>;

type PageProps = {
  searchParams: Promise<SearchParams>;
};

type SummaryRow = {
  local_id: string;
  org_id: string;
  active_program_id: string | null;
  active_program_name: string | null;
  total_units: number | null;
  current_final_eval_config_id: string | null;
  final_eval_total_questions: number | null;
  roleplay_ratio: number | null;
  min_global_score: number | null;
  must_pass_units: number[] | null;
  questions_per_unit: number | null;
  max_attempts: number | null;
  cooldown_hours: number | null;
  total_knowledge_items_active_program: number | null;
  total_practice_scenarios_active_program: number | null;
  knowledge_count_by_type: Record<string, number> | null;
};

type UnitRow = {
  local_id: string;
  program_id: string;
  unit_order: number;
  unit_title: string;
  knowledge_count: number | null;
  knowledge_count_by_type: Record<string, number> | null;
  practice_scenarios_count: number | null;
  practice_difficulty_min: number | null;
  practice_difficulty_max: number | null;
  success_criteria_count_total: number | null;
};

type GapRow = {
  local_id: string;
  program_id: string;
  unit_order: number;
  unit_title: string;
  is_missing_knowledge: boolean;
  is_missing_practice: boolean;
};

type ScenarioRow = {
  id: string;
  program_id: string;
  unit_order: number;
  title: string;
  difficulty: number;
  created_at: string;
  local_id: string | null;
  org_id: string;
  is_enabled: boolean;
};

type LocalRow = {
  id: string;
  name: string;
  org_id: string;
};

function coerceParam(value?: string | string[]) {
  if (!value) return undefined;
  return Array.isArray(value) ? value[0] : value;
}

function formatPercent(value: number | null | undefined) {
  if (value === null || value === undefined) return '—';
  return `${Math.round(value * 100)}%`;
}

function formatNumber(value: number | null | undefined) {
  if (value === null || value === undefined) return '—';
  return String(value);
}

export default async function OrgBotConfigPage({ searchParams }: PageProps) {
  const { role } = await requireUserAndRole(['admin_org', 'superadmin']);
  const supabase = await getSupabaseServerClient();

  const sp = await searchParams;
  const selectedLocalId = coerceParam(sp?.localId) ?? '';
  const error = coerceParam(sp?.error);
  const success = coerceParam(sp?.success);

  const { data: summaryRows, error: summaryError } = await supabase
    .from('v_local_bot_config_summary')
    .select(
      'local_id, org_id, active_program_id, active_program_name, total_units, current_final_eval_config_id, final_eval_total_questions, roleplay_ratio, min_global_score, must_pass_units, questions_per_unit, max_attempts, cooldown_hours, total_knowledge_items_active_program, total_practice_scenarios_active_program, knowledge_count_by_type',
    )
    .order('local_id', { ascending: true });

  const summaryList = (summaryRows ?? []) as SummaryRow[];
  const defaultLocalId = summaryList[0]?.local_id ?? '';
  const activeLocalId = selectedLocalId || defaultLocalId;
  const selectedSummary = summaryList.find(
    (row) => row.local_id === activeLocalId,
  );

  const { data: locals, error: localsError } = await supabase
    .from('locals')
    .select('id, name, org_id')
    .order('created_at', { ascending: true });

  const localMap = new Map(
    ((locals ?? []) as LocalRow[]).map((local) => [local.id, local]),
  );

  const hasLocals = summaryList.length > 0;

  const { data: units, error: unitsError } = selectedSummary
    ? await supabase
        .from('v_local_bot_config_units')
        .select(
          'local_id, program_id, unit_order, unit_title, knowledge_count, knowledge_count_by_type, practice_scenarios_count, practice_difficulty_min, practice_difficulty_max, success_criteria_count_total',
        )
        .eq('local_id', selectedSummary.local_id)
        .order('unit_order', { ascending: true })
    : { data: null, error: null };

  const { data: gaps, error: gapsError } = selectedSummary
    ? await supabase
        .from('v_local_bot_config_gaps')
        .select(
          'local_id, program_id, unit_order, unit_title, is_missing_knowledge, is_missing_practice',
        )
        .eq('local_id', selectedSummary.local_id)
        .or('is_missing_knowledge.eq.true,is_missing_practice.eq.true')
        .order('unit_order', { ascending: true })
    : { data: null, error: null };

  const { data: scenarios, error: scenariosError } =
    selectedSummary && selectedSummary.active_program_id
      ? await supabase
          .from('practice_scenarios')
          .select(
            'id, program_id, unit_order, title, difficulty, created_at, local_id, org_id, is_enabled',
          )
          .eq('program_id', selectedSummary.active_program_id)
          .eq('org_id', selectedSummary.org_id)
          .eq('is_enabled', true)
          .or(`local_id.is.null,local_id.eq.${selectedSummary.local_id}`)
          .order('unit_order', { ascending: true })
      : { data: null, error: null };

  const hasErrors =
    summaryError || localsError || unitsError || gapsError || scenariosError;

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-6xl flex-col gap-6 px-4 py-6">
      <header className="flex flex-col gap-2">
        <Link href="/org/metrics" className="text-xs text-slate-500">
          ← Volver a métricas
        </Link>
        <div>
          <h1 className="text-2xl font-semibold text-slate-900">
            Config del Bot
          </h1>
          <p className="text-sm text-slate-500">
            Lectura operativa + escenarios de práctica (create/disable).
          </p>
        </div>
      </header>

      {hasErrors ? (
        <div className="rounded-md border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          Error al cargar configuración. Intentá nuevamente.
        </div>
      ) : null}

      {error ? (
        <div className="rounded-md border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          {decodeURIComponent(error)}
        </div>
      ) : null}

      {success === 'created' ? (
        <div className="rounded-md border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-700">
          Escenario creado.
        </div>
      ) : null}

      {success === 'disabled' ? (
        <div className="rounded-md border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-700">
          Escenario deshabilitado.
        </div>
      ) : null}

      {!hasLocals ? (
        <div className="rounded-md border border-slate-200 bg-slate-50 p-4 text-sm text-slate-600">
          No hay locales con programa activo para configurar.
        </div>
      ) : null}

      {hasLocals ? (
        <section className="rounded-lg border border-slate-200 bg-white p-4">
          <div className="flex flex-col gap-2">
            <h2 className="text-base font-semibold text-slate-900">Local</h2>
            <p className="text-xs text-slate-500">
              Seleccioná un local para ver la configuración activa.
            </p>
            <form action="/org/bot-config" method="get" className="flex gap-2">
              <select
                name="localId"
                defaultValue={activeLocalId}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm"
              >
                {summaryList.map((row) => {
                  const localName = localMap.get(row.local_id)?.name;
                  return (
                    <option key={row.local_id} value={row.local_id}>
                      {localName ?? row.local_id}
                    </option>
                  );
                })}
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
      ) : null}

      {selectedSummary ? (
        <section className="grid gap-4 md:grid-cols-2">
          <div className="rounded-lg border border-slate-200 bg-white p-4">
            <h3 className="text-sm font-semibold text-slate-900">
              Programa activo
            </h3>
            <p className="mt-1 text-sm text-slate-700">
              {selectedSummary.active_program_name ?? '—'}
            </p>
            <div className="mt-2 grid gap-1 text-xs text-slate-500">
              <span>Unidades: {formatNumber(selectedSummary.total_units)}</span>
              <span>
                Knowledge:{' '}
                {formatNumber(
                  selectedSummary.total_knowledge_items_active_program,
                )}
              </span>
              <span>
                Escenarios activos:{' '}
                {formatNumber(
                  selectedSummary.total_practice_scenarios_active_program,
                )}
              </span>
            </div>
          </div>
          <div className="rounded-lg border border-slate-200 bg-white p-4">
            <h3 className="text-sm font-semibold text-slate-900">
              Evaluación final
            </h3>
            <div className="mt-2 grid gap-1 text-xs text-slate-500">
              <span>
                Total preguntas:{' '}
                {formatNumber(selectedSummary.final_eval_total_questions)}
              </span>
              <span>
                Roleplay ratio: {formatPercent(selectedSummary.roleplay_ratio)}
              </span>
              <span>
                Puntaje mínimo: {formatNumber(selectedSummary.min_global_score)}
              </span>
              <span>
                Cooldown: {formatNumber(selectedSummary.cooldown_hours)}h
              </span>
            </div>
          </div>
        </section>
      ) : null}

      {selectedSummary ? (
        <PracticeScenarioPanel
          localId={selectedSummary.local_id}
          units={(units ?? []) as UnitRow[]}
          gaps={(gaps ?? []) as GapRow[]}
          scenarios={(scenarios ?? []) as ScenarioRow[]}
          isSuperadmin={role === 'superadmin'}
        />
      ) : null}
    </main>
  );
}
