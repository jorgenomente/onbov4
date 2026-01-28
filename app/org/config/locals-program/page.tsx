import Link from 'next/link';

import { requireUserAndRole } from '../../../../lib/server/requireRole';
import { getSupabaseServerClient } from '../../../../lib/server/supabase';
import { setLocalActiveProgramAction } from './actions';

type SearchParams = Record<string, string | string[] | undefined>;

type PageProps = {
  searchParams: Promise<SearchParams>;
};

function coerceParam(value?: string | string[]) {
  if (!value) return undefined;
  return Array.isArray(value) ? value[0] : value;
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

function truncate(value: string | null | undefined, max = 60) {
  if (!value) return '—';
  if (value.length <= max) return value;
  return `${value.slice(0, max)}…`;
}

type LocalRow = {
  id: string;
  name: string;
  program_id: string | null;
  program_name: string | null;
  program_local_id: string | null;
  program_is_active: boolean | null;
  activated_at: string | null;
};

type ProgramRow = {
  id: string;
  name: string;
  local_id: string | null;
  created_at: string | null;
};

type ChangeEventRow = {
  id: string;
  local_id: string;
  from_program_id: string | null;
  to_program_id: string;
  changed_by_user_id: string;
  reason: string | null;
  created_at: string;
};

export default async function OrgLocalActiveProgramPage({
  searchParams,
}: PageProps) {
  await requireUserAndRole(['admin_org', 'superadmin']);

  const sp = await searchParams;
  const error = coerceParam(sp?.error);
  const success = coerceParam(sp?.success);

  const supabase = await getSupabaseServerClient();

  const { data: locals, error: localsError } = await supabase
    .from('v_org_local_active_programs')
    .select(
      'local_id, local_name, program_id, program_name, program_local_id, program_is_active, activated_at',
    )
    .order('local_name', { ascending: true });

  const { data: localList, error: localListError } = await supabase
    .from('locals')
    .select('id, name')
    .order('name', { ascending: true });

  const { data: programs, error: programsError } = await supabase
    .from('training_programs')
    .select('id, name, local_id, created_at')
    .order('created_at', { ascending: false });

  const { data: history, error: historyError } = await supabase
    .from('local_active_program_change_events')
    .select(
      'id, local_id, from_program_id, to_program_id, changed_by_user_id, reason, created_at',
    )
    .order('created_at', { ascending: false })
    .limit(20);

  const localsMap = new Map(
    (localList ?? []).map((local) => [local.id, local.name]),
  );

  const programsMap = new Map(
    (programs ?? []).map((program) => [program.id, program.name]),
  );

  const localsById = new Map((locals ?? []).map((row) => [row.local_id, row]));

  const activeRows: LocalRow[] = (localList ?? []).map((local) => {
    const active = localsById.get(local.id);
    return {
      id: local.id,
      name: local.name,
      program_id: active?.program_id ?? null,
      program_name: active?.program_name ?? null,
      program_local_id: active?.program_local_id ?? null,
      program_is_active: active?.program_is_active ?? null,
      activated_at: active?.activated_at ?? null,
    };
  });

  const eligibleProgramsByLocal = new Map<string, ProgramRow[]>();
  (localList ?? []).forEach((local) => {
    const eligible = (programs ?? []).filter(
      (program) => program.local_id === null || program.local_id === local.id,
    );
    eligibleProgramsByLocal.set(local.id, eligible);
  });

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-6xl flex-col gap-6 px-4 py-6">
      <header className="flex flex-col gap-2">
        <Link href="/" className="text-xs text-slate-500">
          ← Volver
        </Link>
        <div>
          <h1 className="text-2xl font-semibold text-slate-900">
            Programa activo por local
          </h1>
          <p className="text-sm text-slate-500">
            Admin Org · Cambios afectan nuevos learners (no modifica
            entrenamientos en curso).
          </p>
        </div>
      </header>

      {error ? (
        <div className="rounded-md border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          {decodeURIComponent(error)}
        </div>
      ) : null}

      {success === '1' ? (
        <div className="rounded-md border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-700">
          Programa activo actualizado.
        </div>
      ) : null}

      {(localsError || programsError || localListError) && (
        <div className="rounded-md border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          Error al cargar locales o programas.
        </div>
      )}

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="text-base font-semibold text-slate-800">Locales</h2>
        <p className="text-xs text-slate-500">
          Cambiá el programa activo por local (org-level o local-specific).
        </p>

        {activeRows.length === 0 ? (
          <div className="mt-4 rounded-md border border-dashed border-slate-200 p-3 text-sm text-slate-500">
            No hay locales disponibles.
          </div>
        ) : (
          <div className="mt-4 overflow-x-auto">
            <table className="min-w-full text-left text-xs text-slate-600">
              <thead className="border-b border-slate-200 text-[11px] text-slate-400 uppercase">
                <tr>
                  <th className="px-3 py-2">Local</th>
                  <th className="px-3 py-2">Programa activo</th>
                  <th className="px-3 py-2">Actualizado</th>
                  <th className="px-3 py-2">Acción</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {activeRows.map((local) => {
                  const eligiblePrograms =
                    eligibleProgramsByLocal.get(local.id) ?? [];
                  return (
                    <tr key={local.id}>
                      <td className="px-3 py-2 font-medium text-slate-800">
                        {local.name}
                      </td>
                      <td className="px-3 py-2 text-slate-700">
                        {local.program_name ?? '—'}
                      </td>
                      <td className="px-3 py-2 text-slate-500">
                        {formatDate(local.activated_at)}
                      </td>
                      <td className="px-3 py-2">
                        <details className="rounded-md border border-slate-200 bg-slate-50 p-3">
                          <summary className="cursor-pointer text-xs font-semibold text-slate-700">
                            Cambiar
                          </summary>
                          <form
                            action={setLocalActiveProgramAction}
                            className="mt-3 flex flex-col gap-3"
                          >
                            <input
                              type="hidden"
                              name="local_id"
                              value={local.id}
                            />
                            <label className="flex flex-col gap-1 text-xs">
                              <span className="text-slate-500">Programa</span>
                              <select
                                name="program_id"
                                defaultValue={local.program_id ?? ''}
                                className="rounded-md border border-slate-300 bg-white px-3 py-2 text-sm"
                                required
                              >
                                <option value="">Seleccionar programa</option>
                                {eligiblePrograms.map((program) => (
                                  <option key={program.id} value={program.id}>
                                    {program.name}
                                    {program.local_id ? ' · Local' : ' · Org'}
                                  </option>
                                ))}
                              </select>
                            </label>
                            <label className="flex flex-col gap-1 text-xs">
                              <span className="text-slate-500">
                                Motivo (opcional)
                              </span>
                              <textarea
                                name="reason"
                                rows={2}
                                className="rounded-md border border-slate-300 px-3 py-2 text-sm"
                                placeholder="Ej: Ajuste por temporada"
                              />
                            </label>
                            <button
                              type="submit"
                              className="rounded-md bg-slate-900 px-3 py-2 text-sm font-semibold text-white"
                            >
                              Guardar
                            </button>
                          </form>
                        </details>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="text-base font-semibold text-slate-800">
          Historial reciente
        </h2>
        <p className="text-xs text-slate-500">
          Últimos 20 cambios en la organización.
        </p>

        {historyError ? (
          <div className="mt-3 rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
            Error al cargar historial.
          </div>
        ) : null}

        {(history ?? []).length === 0 ? (
          <div className="mt-4 rounded-md border border-dashed border-slate-200 p-3 text-sm text-slate-500">
            Sin eventos registrados.
          </div>
        ) : (
          <div className="mt-4 overflow-x-auto">
            <table className="min-w-full text-left text-xs text-slate-600">
              <thead className="border-b border-slate-200 text-[11px] text-slate-400 uppercase">
                <tr>
                  <th className="px-3 py-2">Fecha</th>
                  <th className="px-3 py-2">Local</th>
                  <th className="px-3 py-2">De</th>
                  <th className="px-3 py-2">A</th>
                  <th className="px-3 py-2">Usuario</th>
                  <th className="px-3 py-2">Motivo</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {(history ?? []).map((event: ChangeEventRow) => (
                  <tr key={event.id}>
                    <td className="px-3 py-2 text-slate-500">
                      {formatDate(event.created_at)}
                    </td>
                    <td className="px-3 py-2 text-slate-700">
                      {localsMap.get(event.local_id) ?? event.local_id}
                    </td>
                    <td className="px-3 py-2 text-slate-700">
                      {event.from_program_id
                        ? (programsMap.get(event.from_program_id) ??
                          event.from_program_id)
                        : '—'}
                    </td>
                    <td className="px-3 py-2 text-slate-700">
                      {programsMap.get(event.to_program_id) ??
                        event.to_program_id}
                    </td>
                    <td className="px-3 py-2 text-slate-500">
                      {event.changed_by_user_id}
                    </td>
                    <td className="px-3 py-2 text-slate-500">
                      {truncate(event.reason)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <article className="rounded-lg border border-slate-200 bg-slate-50 p-4 text-xs text-slate-500">
        Cambiar programa activo no modifica entrenamientos existentes.
      </article>
    </main>
  );
}
