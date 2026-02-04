import type { SupabaseClient } from '@supabase/supabase-js';

import { toLearnerStatus, type LearnerStatus } from './status-ui';

export type PracticeState = {
  available: boolean;
  completed: boolean;
};

export type NextStepActionType =
  | 'practice'
  | 'training'
  | 'final_eval'
  | 'progress'
  | 'home';

export type NextStepAction = {
  type: NextStepActionType;
  label: string;
  href?: string;
  disabled?: boolean;
};

export type NextStepUi = {
  modeLabel: 'Aprender' | 'Practicar';
  primaryAction: NextStepAction;
  hintLine: string;
};

type PracticeStateInput = {
  supabase: SupabaseClient;
  learnerId: string;
  programId?: string | null;
  unitOrder?: number | null;
  localId?: string | null;
};

export async function getPracticeState({
  supabase,
  learnerId,
  programId,
  unitOrder,
  localId,
}: PracticeStateInput): Promise<PracticeState> {
  if (!programId || !unitOrder) {
    return { available: false, completed: false };
  }

  const scenarioQuery = supabase
    .from('practice_scenarios')
    .select('id')
    .eq('program_id', programId)
    .eq('unit_order', unitOrder)
    .eq('is_enabled', true);

  if (localId) {
    scenarioQuery.or(`local_id.eq.${localId},local_id.is.null`);
  } else {
    scenarioQuery.is('local_id', null);
  }

  const { data: scenarios } = await scenarioQuery;
  const scenarioIds = (scenarios ?? []).map((scenario) => scenario.id);

  if (!scenarioIds.length) {
    return { available: false, completed: false };
  }

  const { data: attempts } = await supabase
    .from('practice_attempts')
    .select('id')
    .eq('learner_id', learnerId)
    .in('scenario_id', scenarioIds);

  const attemptIds = (attempts ?? []).map((attempt) => attempt.id);

  if (!attemptIds.length) {
    return { available: true, completed: false };
  }

  const { data: completedEvents } = await supabase
    .from('practice_attempt_events')
    .select('id')
    .eq('event_type', 'completed')
    .in('attempt_id', attemptIds)
    .limit(1);

  return {
    available: true,
    completed: (completedEvents ?? []).length > 0,
  };
}

type NextStepInput = {
  status?: string | null;
  practiceState: PracticeState;
  unitOrder?: number | null;
  finalEvalReady?: boolean;
};

export function getNextStepUi({
  status,
  practiceState,
  unitOrder,
  finalEvalReady,
}: NextStepInput): NextStepUi {
  const resolvedStatus: LearnerStatus = toLearnerStatus(status);

  if (resolvedStatus === 'en_revision') {
    return {
      modeLabel: 'Aprender',
      primaryAction: {
        type: 'final_eval',
        label: 'Ver estado de evaluación',
        href: '/learner/final-evaluation',
      },
      hintLine: 'Tu evaluación está siendo revisada.',
    };
  }

  if (resolvedStatus === 'aprobado') {
    return {
      modeLabel: 'Aprender',
      primaryAction: {
        type: 'progress',
        label: 'Ver resumen / progreso',
        href: '/learner/progress',
      },
      hintLine: 'Completaste el programa.',
    };
  }

  if (practiceState.available && !practiceState.completed) {
    return {
      modeLabel: 'Practicar',
      primaryAction: {
        type: 'practice',
        label: `Practicar unidad ${unitOrder ?? ''}`.trim(),
      },
      hintLine: 'Tu próximo paso es practicar esta unidad.',
    };
  }

  if (finalEvalReady) {
    return {
      modeLabel: 'Aprender',
      primaryAction: {
        type: 'final_eval',
        label: 'Ir a evaluación final',
        href: '/learner/final-evaluation',
      },
      hintLine: 'Práctica completada. Podés rendir la evaluación final.',
    };
  }

  if (practiceState.completed) {
    return {
      modeLabel: 'Aprender',
      primaryAction: {
        type: 'training',
        label: 'Continuar entrenamiento',
        href: '#chat-input',
      },
      hintLine: 'Práctica completada. Continuá con la unidad.',
    };
  }

  return {
    modeLabel: 'Aprender',
    primaryAction: {
      type: 'training',
      label: 'Continuar entrenamiento',
      href: '#chat-input',
    },
    hintLine: practiceState.available
      ? 'Seguí avanzando con la unidad actual.'
      : 'No hay práctica disponible para esta unidad.',
  };
}

type TrainingNextStepInput = NextStepInput & {
  practiceActive?: boolean;
};

export function getTrainingNextStepUi({
  status,
  practiceState,
  unitOrder,
  finalEvalReady,
  practiceActive,
}: TrainingNextStepInput): NextStepUi {
  const resolvedStatus: LearnerStatus = toLearnerStatus(status);

  if (resolvedStatus === 'en_revision') {
    return {
      modeLabel: 'Aprender',
      primaryAction: {
        type: 'home',
        label: 'Volver al Home',
        href: '/learner',
      },
      hintLine: 'Tu evaluación está en revisión.',
    };
  }

  if (practiceActive) {
    return {
      modeLabel: 'Practicar',
      primaryAction: {
        type: 'training',
        label: `Continuar práctica${unitOrder ? ` unidad ${unitOrder}` : ''}`,
        href: '#chat-input',
      },
      hintLine: 'Estás practicando en esta unidad.',
    };
  }

  return getNextStepUi({
    status: resolvedStatus,
    practiceState,
    unitOrder,
    finalEvalReady,
  });
}
