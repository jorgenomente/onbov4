'use client';

import { useMemo, useState } from 'react';

import {
  createPracticeScenarioAction,
  disablePracticeScenarioAction,
} from '../actions';

type UnitRow = {
  unit_order: number;
  unit_title: string;
  knowledge_count: number | null;
  practice_scenarios_count: number | null;
  practice_difficulty_min: number | null;
  practice_difficulty_max: number | null;
};

type GapRow = {
  unit_order: number;
  unit_title: string;
  is_missing_knowledge: boolean;
  is_missing_practice: boolean;
};

type ScenarioRow = {
  id: string;
  unit_order: number;
  title: string;
  difficulty: number;
};

type PracticeScenarioPanelProps = {
  localId: string;
  units: UnitRow[];
  gaps: GapRow[];
  scenarios: ScenarioRow[];
  isSuperadmin: boolean;
};

export default function PracticeScenarioPanel({
  localId,
  units,
  gaps,
  scenarios,
  isSuperadmin,
}: PracticeScenarioPanelProps) {
  const [createOpen, setCreateOpen] = useState(false);
  const [selectedUnit, setSelectedUnit] = useState<number | null>(null);
  const [disableTarget, setDisableTarget] = useState<ScenarioRow | null>(null);

  const gapsByUnit = useMemo(() => {
    const map = new Map<number, GapRow>();
    gaps.forEach((gap) => map.set(gap.unit_order, gap));
    return map;
  }, [gaps]);

  const scenariosByUnit = useMemo(() => {
    const map = new Map<number, ScenarioRow[]>();
    scenarios.forEach((scenario) => {
      const list = map.get(scenario.unit_order) ?? [];
      list.push(scenario);
      map.set(scenario.unit_order, list);
    });
    return map;
  }, [scenarios]);

  return (
    <section className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h2 className="text-base font-semibold text-slate-900">Unidades</h2>
          <p className="text-xs text-slate-500">
            Escenarios activos por unidad. Crear y deshabilitar es create-only.
          </p>
        </div>
        <button
          type="button"
          onClick={() => {
            setSelectedUnit(null);
            setCreateOpen(true);
          }}
          className="rounded-md bg-slate-900 px-3 py-2 text-xs font-semibold text-white"
        >
          Crear escenario
        </button>
      </div>

      <div className="flex flex-col gap-3">
        {units.map((unit) => {
          const gap = gapsByUnit.get(unit.unit_order);
          const unitScenarios = scenariosByUnit.get(unit.unit_order) ?? [];
          return (
            <div
              key={unit.unit_order}
              className="rounded-lg border border-slate-200 bg-white p-4"
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="text-xs text-slate-500">
                    Unidad {unit.unit_order}
                  </p>
                  <h3 className="text-sm font-semibold text-slate-900">
                    {unit.unit_title}
                  </h3>
                  <div className="mt-2 flex flex-wrap gap-2 text-xs text-slate-600">
                    <span>Knowledge: {unit.knowledge_count ?? 0}</span>
                    <span>
                      Escenarios: {unit.practice_scenarios_count ?? 0}
                    </span>
                    <span>
                      Dificultad: {unit.practice_difficulty_min ?? '—'}
                      {unit.practice_difficulty_max
                        ? `-${unit.practice_difficulty_max}`
                        : ''}
                    </span>
                  </div>
                  {gap ? (
                    <div className="mt-2 flex flex-wrap gap-2 text-xs">
                      {gap.is_missing_knowledge ? (
                        <span className="rounded-full bg-amber-50 px-2 py-0.5 text-amber-700">
                          Sin knowledge
                        </span>
                      ) : null}
                      {gap.is_missing_practice ? (
                        <span className="rounded-full bg-rose-50 px-2 py-0.5 text-rose-700">
                          Sin practica
                        </span>
                      ) : null}
                    </div>
                  ) : null}
                </div>
                <button
                  type="button"
                  onClick={() => {
                    setSelectedUnit(unit.unit_order);
                    setCreateOpen(true);
                  }}
                  className="rounded-md border border-slate-200 px-3 py-2 text-xs font-semibold text-slate-700"
                >
                  Crear escenario
                </button>
              </div>

              <div className="mt-3 flex flex-col gap-2">
                {unitScenarios.length === 0 ? (
                  <p className="text-xs text-slate-400">
                    No hay escenarios activos para esta unidad.
                  </p>
                ) : (
                  unitScenarios.map((scenario) => (
                    <div
                      key={scenario.id}
                      className="flex flex-wrap items-center justify-between gap-2 rounded-md border border-slate-100 bg-slate-50 px-3 py-2"
                    >
                      <div>
                        <p className="text-xs font-semibold text-slate-800">
                          {scenario.title}
                        </p>
                        <p className="text-[11px] text-slate-500">
                          Dificultad {scenario.difficulty}
                        </p>
                      </div>
                      <button
                        type="button"
                        onClick={() => setDisableTarget(scenario)}
                        className="text-xs font-semibold text-rose-600"
                      >
                        Deshabilitar
                      </button>
                    </div>
                  ))
                )}
              </div>
            </div>
          );
        })}
      </div>

      {gaps.length > 0 ? (
        <section className="rounded-lg border border-amber-200 bg-amber-50 p-4">
          <h3 className="text-sm font-semibold text-amber-800">Gaps</h3>
          <ul className="mt-2 space-y-1 text-xs text-amber-700">
            {gaps.map((gap) => (
              <li key={gap.unit_order}>
                Unidad {gap.unit_order}: {gap.unit_title}
                {gap.is_missing_knowledge ? ' · sin knowledge' : ''}
                {gap.is_missing_practice ? ' · sin practica' : ''}
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      {createOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-md rounded-lg bg-white p-4">
            <h3 className="text-base font-semibold text-slate-900">
              Crear escenario
            </h3>
            <form
              action={createPracticeScenarioAction}
              className="mt-3 space-y-3"
            >
              <input type="hidden" name="local_id" value={localId} />
              <div>
                <label className="text-xs font-semibold text-slate-700">
                  Unidad
                </label>
                <select
                  name="unit_order"
                  value={selectedUnit ?? units[0]?.unit_order ?? ''}
                  onChange={(event) => {
                    const nextValue = Number(event.target.value);
                    setSelectedUnit(
                      Number.isFinite(nextValue) ? nextValue : null,
                    );
                  }}
                  className="mt-1 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm"
                  required
                  disabled={units.length === 0}
                >
                  {units.length === 0 ? (
                    <option value="">Sin unidades disponibles</option>
                  ) : null}
                  {units.map((unit) => (
                    <option key={unit.unit_order} value={unit.unit_order}>
                      Unidad {unit.unit_order} — {unit.unit_title}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="text-xs font-semibold text-slate-700">
                  Title
                </label>
                <input
                  type="text"
                  name="title"
                  className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                  required
                />
              </div>
              <div>
                <label className="text-xs font-semibold text-slate-700">
                  Instructions
                </label>
                <textarea
                  name="instructions"
                  rows={4}
                  className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                  required
                />
              </div>
              <div>
                <label className="text-xs font-semibold text-slate-700">
                  Difficulty (1-5)
                </label>
                <input
                  type="number"
                  name="difficulty"
                  min={1}
                  max={5}
                  defaultValue={1}
                  className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                />
              </div>
              <div>
                <label className="text-xs font-semibold text-slate-700">
                  Success criteria (una linea por item)
                </label>
                <textarea
                  name="success_criteria"
                  rows={3}
                  className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                />
              </div>
              <div className="flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setCreateOpen(false)}
                  className="rounded-md border border-slate-200 px-3 py-2 text-xs font-semibold text-slate-600"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  className="rounded-md bg-slate-900 px-3 py-2 text-xs font-semibold text-white"
                >
                  Crear
                </button>
              </div>
              {isSuperadmin ? (
                <p className="text-[11px] text-slate-400">
                  Superadmin: local_id se toma del selector actual.
                </p>
              ) : null}
            </form>
          </div>
        </div>
      ) : null}

      {disableTarget ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-sm rounded-lg bg-white p-4">
            <h3 className="text-base font-semibold text-slate-900">
              Deshabilitar escenario
            </h3>
            <p className="mt-1 text-xs text-slate-500">
              {disableTarget.title} (unidad {disableTarget.unit_order})
            </p>
            <form
              action={disablePracticeScenarioAction}
              className="mt-3 space-y-3"
            >
              <input
                type="hidden"
                name="scenario_id"
                value={disableTarget.id}
              />
              <input type="hidden" name="local_id" value={localId} />
              <div>
                <label className="text-xs font-semibold text-slate-700">
                  Reason (opcional)
                </label>
                <input
                  type="text"
                  name="reason"
                  className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                />
              </div>
              <div className="flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setDisableTarget(null)}
                  className="rounded-md border border-slate-200 px-3 py-2 text-xs font-semibold text-slate-600"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  className="rounded-md bg-rose-600 px-3 py-2 text-xs font-semibold text-white"
                >
                  Deshabilitar
                </button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </section>
  );
}
