import Link from 'next/link';

import { getSupabaseServerClient } from '../../lib/server/supabase';

const ALERT_LABELS: Record<string, string> = {
  review_submitted_v2: 'Validacion v2 enviada',
  review_rejected_v2: 'Validacion v2 rechazada',
  review_reinforcement_requested_v2: 'Validacion v2: refuerzo',
  learner_at_risk: 'Aprendiz en riesgo',
  final_evaluation_submitted: 'Evaluacion final enviada',
};

type AlertRow = {
  id: string;
  alert_type: string;
  learner_id: string;
  source_table: string;
  source_id: string;
  payload: Record<string, unknown> | null;
  created_at: string;
  profiles?: {
    full_name: string | null;
  } | null;
};

function buildPayloadSummary(payload: Record<string, unknown> | null) {
  if (!payload) return '—';

  const fields: Array<[string, string]> = [];
  if (typeof payload.decision_type === 'string') {
    fields.push(['decision', payload.decision_type]);
  }
  if (typeof payload.perceived_severity === 'string') {
    fields.push(['severity', payload.perceived_severity]);
  }
  if (typeof payload.recommended_action === 'string') {
    fields.push(['action', payload.recommended_action]);
  }
  if (typeof payload.attempt_number === 'number') {
    fields.push(['attempt', String(payload.attempt_number)]);
  }
  if (typeof payload.status === 'string') {
    fields.push(['status', payload.status]);
  }
  if (fields.length === 0) return '—';

  return fields.map(([key, value]) => `${key}: ${value}`).join(' · ');
}

function getLearnerLink(alert: AlertRow) {
  if (
    alert.source_table === 'learner_review_validations_v2' ||
    alert.source_table === 'final_evaluation_attempts'
  ) {
    return `/referente/review/${alert.learner_id}`;
  }
  return null;
}

export default async function AlertsInboxPage() {
  const supabase = await getSupabaseServerClient();

  const { data: alerts, error } = await supabase
    .from('alert_events')
    .select(
      'id, alert_type, learner_id, source_table, source_id, payload, created_at, profiles!alert_events_learner_id_fkey(full_name)',
    )
    .order('created_at', { ascending: false })
    .limit(50);

  if (error) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-4 px-4 py-6">
        <h1 className="text-xl font-semibold">Alertas</h1>
        <p className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Error al cargar alertas.
        </p>
      </main>
    );
  }

  const rows = (alerts as AlertRow[] | null) ?? [];

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-4 px-4 py-6">
      <div className="flex flex-col gap-1">
        <h1 className="text-xl font-semibold">Alertas</h1>
        <p className="text-sm text-slate-500">
          Actividad reciente para revision interna.
        </p>
      </div>

      {rows.length === 0 ? (
        <div className="rounded-md border border-dashed border-slate-200 p-4 text-sm text-slate-500">
          No hay alertas recientes.
        </div>
      ) : (
        <div className="overflow-x-auto rounded-lg border border-slate-200 bg-white">
          <table className="min-w-full text-left text-xs text-slate-600">
            <thead className="text-[11px] text-slate-400 uppercase">
              <tr>
                <th className="px-3 py-2">Fecha</th>
                <th className="px-3 py-2">Tipo</th>
                <th className="px-3 py-2">Aprendiz</th>
                <th className="px-3 py-2">Fuente</th>
                <th className="px-3 py-2">Detalle</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((alert) => {
                const label =
                  ALERT_LABELS[alert.alert_type] ?? alert.alert_type;
                const createdAt = new Date(alert.created_at).toLocaleString(
                  'es-AR',
                );
                const learnerName =
                  alert.profiles?.full_name?.trim() || 'Aprendiz';
                const link = getLearnerLink(alert);
                const detail = buildPayloadSummary(alert.payload ?? null);

                return (
                  <tr key={alert.id} className="border-t">
                    <td className="px-3 py-2 text-slate-500">{createdAt}</td>
                    <td className="px-3 py-2 text-slate-700">{label}</td>
                    <td className="px-3 py-2 text-slate-700">{learnerName}</td>
                    <td className="px-3 py-2">
                      {link ? (
                        <Link
                          href={link}
                          className="text-xs font-semibold text-slate-700"
                        >
                          Ver detalle
                        </Link>
                      ) : (
                        <span className="text-xs text-slate-400">—</span>
                      )}
                    </td>
                    <td className="px-3 py-2 text-slate-500">{detail}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </main>
  );
}
