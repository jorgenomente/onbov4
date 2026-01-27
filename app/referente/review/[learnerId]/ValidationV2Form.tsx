'use client';

import { useRouter } from 'next/navigation';
import { useState, useTransition } from 'react';

import { submitReviewValidationV2 } from '../actions';

type ValidationV2FormProps = {
  learnerId: string;
};

export default function ValidationV2Form({ learnerId }: ValidationV2FormProps) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const [decisionType, setDecisionType] = useState(
    'approve' as 'approve' | 'reject' | 'request_reinforcement',
  );
  const [perceivedSeverity, setPerceivedSeverity] = useState(
    'low' as 'low' | 'medium' | 'high',
  );
  const [recommendedAction, setRecommendedAction] = useState(
    'none' as 'none' | 'follow_up' | 'retraining',
  );
  const [coveredCoreConcepts, setCoveredCoreConcepts] = useState(false);
  const [handledObjections, setHandledObjections] = useState(false);
  const [communicationClarityOk, setCommunicationClarityOk] = useState(false);
  const [comment, setComment] = useState('');

  function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setSuccess(null);

    const checklist = {
      covered_core_concepts: coveredCoreConcepts,
      handled_objections: handledObjections,
      communication_clarity_ok: communicationClarityOk,
    };

    startTransition(async () => {
      try {
        await submitReviewValidationV2({
          learnerId,
          decisionType,
          perceivedSeverity,
          recommendedAction,
          checklist,
          comment: comment.trim() || null,
        });

        setSuccess('Validación v2 registrada.');
        setComment('');
        setCoveredCoreConcepts(false);
        setHandledObjections(false);
        setCommunicationClarityOk(false);
        router.refresh();
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Error inesperado.');
      }
    });
  }

  return (
    <form onSubmit={onSubmit} className="flex flex-col gap-4">
      <div className="grid gap-3 sm:grid-cols-3">
        <label className="text-sm text-slate-600">
          Decisión
          <select
            value={decisionType}
            onChange={(event) =>
              setDecisionType(
                event.target.value as
                  | 'approve'
                  | 'reject'
                  | 'request_reinforcement',
              )
            }
            className="mt-1 w-full rounded-md border border-slate-300 bg-white px-2 py-2 text-sm"
          >
            <option value="approve">approve</option>
            <option value="reject">reject</option>
            <option value="request_reinforcement">request_reinforcement</option>
          </select>
        </label>
        <label className="text-sm text-slate-600">
          Severidad
          <select
            value={perceivedSeverity}
            onChange={(event) =>
              setPerceivedSeverity(
                event.target.value as 'low' | 'medium' | 'high',
              )
            }
            className="mt-1 w-full rounded-md border border-slate-300 bg-white px-2 py-2 text-sm"
          >
            <option value="low">low</option>
            <option value="medium">medium</option>
            <option value="high">high</option>
          </select>
        </label>
        <label className="text-sm text-slate-600">
          Acción
          <select
            value={recommendedAction}
            onChange={(event) =>
              setRecommendedAction(
                event.target.value as 'none' | 'follow_up' | 'retraining',
              )
            }
            className="mt-1 w-full rounded-md border border-slate-300 bg-white px-2 py-2 text-sm"
          >
            <option value="none">none</option>
            <option value="follow_up">follow_up</option>
            <option value="retraining">retraining</option>
          </select>
        </label>
      </div>

      <fieldset className="rounded-md border border-slate-200 p-3">
        <legend className="px-1 text-xs font-semibold text-slate-500">
          Checklist (placeholder)
        </legend>
        <div className="mt-2 flex flex-col gap-2 text-sm text-slate-600">
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={coveredCoreConcepts}
              onChange={(event) => setCoveredCoreConcepts(event.target.checked)}
              className="h-4 w-4"
            />
            Cubre conceptos base
          </label>
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={handledObjections}
              onChange={(event) => setHandledObjections(event.target.checked)}
              className="h-4 w-4"
            />
            Maneja objeciones
          </label>
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={communicationClarityOk}
              onChange={(event) =>
                setCommunicationClarityOk(event.target.checked)
              }
              className="h-4 w-4"
            />
            Claridad de comunicación
          </label>
        </div>
      </fieldset>

      <label className="text-sm text-slate-600">
        Comentario (opcional)
        <textarea
          value={comment}
          onChange={(event) => setComment(event.target.value)}
          rows={3}
          className="mt-1 w-full rounded-md border border-slate-300 p-2 text-sm"
          placeholder="Observaciones internas..."
        />
      </label>

      {error ? (
        <p className="rounded-md border border-red-200 bg-red-50 p-2 text-sm text-red-700">
          {error}
        </p>
      ) : null}
      {success ? (
        <p className="rounded-md border border-emerald-200 bg-emerald-50 p-2 text-sm text-emerald-700">
          {success}
        </p>
      ) : null}

      <button
        type="submit"
        disabled={isPending}
        className="w-full rounded-md bg-slate-900 px-3 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:bg-slate-400"
      >
        {isPending ? 'Guardando…' : 'Guardar validación v2'}
      </button>
    </form>
  );
}
