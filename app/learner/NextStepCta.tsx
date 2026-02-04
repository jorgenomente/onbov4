'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';

import { startPracticeScenario } from './training/actions';
import type { NextStepAction } from '../../lib/learner/next-step';

type NextStepCtaProps = {
  action: NextStepAction;
  className?: string;
  afterPracticeHref?: string;
};

export default function NextStepCta({
  action,
  className,
  afterPracticeHref = '/learner/training',
}: NextStepCtaProps) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  if (action.type === 'practice') {
    return (
      <button
        type="button"
        onClick={async () => {
          if (loading || action.disabled) return;
          setLoading(true);
          try {
            await startPracticeScenario();
            router.push(afterPracticeHref);
            router.refresh();
          } finally {
            setLoading(false);
          }
        }}
        disabled={action.disabled || loading}
        aria-disabled={action.disabled || loading}
        className={
          className ??
          'rounded-md bg-emerald-600 px-3 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-70'
        }
      >
        {loading ? 'Iniciando práctica...' : action.label}
      </button>
    );
  }

  if (action.disabled) {
    return (
      <button
        type="button"
        disabled
        aria-disabled
        className={
          className ??
          'rounded-md bg-slate-200 px-3 py-2 text-sm font-semibold text-slate-500'
        }
      >
        {action.label}
      </button>
    );
  }

  if (action.href?.startsWith('#')) {
    return (
      <a
        href={action.href}
        className={
          className ??
          'rounded-md bg-emerald-600 px-3 py-2 text-sm font-semibold text-white'
        }
      >
        {action.label}
      </a>
    );
  }

  const href =
    action.href ??
    (action.type === 'progress'
      ? '/learner/progress'
      : action.type === 'final_eval'
        ? '/learner/final-evaluation'
        : action.type === 'home'
          ? '/learner'
          : '/learner/training');

  return (
    <Link
      href={href}
      className={
        className ??
        'rounded-md bg-emerald-600 px-3 py-2 text-sm font-semibold text-white'
      }
    >
      {action.label}
    </Link>
  );
}
