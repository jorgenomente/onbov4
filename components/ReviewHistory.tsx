import type { ReactNode } from 'react';

export type ReviewDecision = {
  id: string;
  decision: string;
  reason: string | null;
  reviewer_name: string | null;
  created_at: string;
};

type ReviewHistoryProps = {
  decisions: ReviewDecision[] | null | undefined;
  compact?: boolean;
  title?: ReactNode;
};

const labels: Record<string, string> = {
  approved: 'Aprobado',
  needs_reinforcement: 'Refuerzo solicitado',
};

export default function ReviewHistory({
  decisions,
  compact = true,
  title = 'Historial de decisiones',
}: ReviewHistoryProps) {
  if (!decisions || decisions.length === 0) return null;

  return (
    <section className="rounded-lg border border-slate-200 bg-white p-4">
      <h2 className="text-sm font-semibold text-slate-700">{title}</h2>
      <div
        className={`mt-2 flex flex-col gap-3 text-xs text-slate-600${
          compact ? 'max-h-40 overflow-auto pr-1' : ''
        }`}
      >
        {decisions.map((decision) => {
          const label = labels[decision.decision] ?? decision.decision;
          const createdAt = new Date(decision.created_at).toLocaleString(
            'es-AR',
            {
              dateStyle: 'medium',
              timeStyle: 'short',
            },
          );
          return (
            <div
              key={decision.id}
              className="rounded-md border border-slate-100 p-3"
            >
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span className="font-semibold text-slate-700">{label}</span>
                <span className="text-slate-400">{createdAt}</span>
              </div>
              <div className="mt-1 flex flex-wrap gap-2 text-slate-500">
                <span>{decision.reviewer_name?.trim() || 'Referente'}</span>
              </div>
              {decision.reason ? (
                <p className="mt-2 text-slate-600">{decision.reason}</p>
              ) : null}
            </div>
          );
        })}
      </div>
    </section>
  );
}
