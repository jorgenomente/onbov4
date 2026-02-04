const learnerStatuses = [
  'en_entrenamiento',
  'en_practica',
  'en_revision',
  'en_riesgo',
  'aprobado',
] as const;

export type LearnerStatus = (typeof learnerStatuses)[number];

export type StatusCta = {
  label: string;
  href: string;
};

type StatusBanner = {
  tone: 'info' | 'warning' | 'success';
  title: string;
  description: string;
};

type StatusBadge = {
  label: string;
  tone: 'neutral' | 'info' | 'warning' | 'success';
};

export type LearnerStatusUi = {
  primaryCta: StatusCta;
  secondaryCta?: StatusCta;
  banner?: StatusBanner;
  badge: StatusBadge;
  statusHint: string;
  homeCtaHint: string;
  trainingHint?: string;
  chatInputDisabled: boolean;
  chatInputHint?: string;
};

export function toLearnerStatus(value?: string | null): LearnerStatus {
  if (value && learnerStatuses.includes(value as LearnerStatus)) {
    return value as LearnerStatus;
  }
  return 'en_entrenamiento';
}

const baseChatCta: StatusCta = {
  label: 'Continuar entrenamiento',
  href: '#chat-input',
};

const progressCta: StatusCta = {
  label: 'Ver progreso',
  href: '/learner/progress',
};

const profileCta: StatusCta = {
  label: 'Ver perfil',
  href: '/learner/profile',
};

const statusUiMap: Record<LearnerStatus, LearnerStatusUi> = {
  en_entrenamiento: {
    primaryCta: baseChatCta,
    secondaryCta: progressCta,
    badge: { label: 'En entrenamiento', tone: 'neutral' },
    statusHint: 'Estás avanzando en tu entrenamiento.',
    homeCtaHint: 'Estás avanzando en la unidad actual.',
    chatInputDisabled: false,
  },
  en_practica: {
    primaryCta: {
      label: 'Continuar práctica',
      href: '#chat-input',
    },
    secondaryCta: progressCta,
    badge: { label: 'En práctica', tone: 'info' },
    statusHint: 'Estás practicando con role-play.',
    homeCtaHint: 'Estás avanzando en la unidad actual.',
    trainingHint: 'Seguimos con la práctica activa.',
    chatInputDisabled: false,
  },
  en_revision: {
    primaryCta: progressCta,
    secondaryCta: profileCta,
    banner: {
      tone: 'info',
      title: 'Evaluación en revisión',
      description:
        'Tu evaluación final está en revisión. Podés revisar tu progreso mientras esperás la decisión.',
    },
    badge: { label: 'En revisión', tone: 'info' },
    statusHint: 'Tu evaluación final está en revisión.',
    homeCtaHint: 'Tu evaluación está siendo revisada.',
    trainingHint:
      'La evaluación está en revisión. Volvé al Home para ver el estado.',
    chatInputDisabled: true,
    chatInputHint:
      'La evaluación está en revisión. El chat se reactivará cuando haya una decisión.',
  },
  en_riesgo: {
    primaryCta: baseChatCta,
    secondaryCta: progressCta,
    banner: {
      tone: 'warning',
      title: 'Refuerzo recomendado',
      description:
        'Necesitás reforzar algunos temas. Usá el chat para practicar y aclarar dudas.',
    },
    badge: { label: 'En riesgo', tone: 'warning' },
    statusHint: 'Necesitás reforzar algunos temas clave.',
    homeCtaHint: 'Necesitás reforzar antes de avanzar.',
    trainingHint: 'Podés practicar con el chat para reforzar.',
    chatInputDisabled: false,
  },
  aprobado: {
    primaryCta: progressCta,
    secondaryCta: {
      label: 'Volver al chat',
      href: '#chat-input',
    },
    banner: {
      tone: 'success',
      title: 'Entrenamiento completado',
      description:
        'Ya completaste el entrenamiento. Podés repasar tu progreso o consultar dudas puntuales.',
    },
    badge: { label: 'Aprobado', tone: 'success' },
    statusHint: 'Entrenamiento completado.',
    homeCtaHint: 'Completaste el programa.',
    trainingHint: 'Entrenamiento completado. Podés repasar desde el Home.',
    chatInputDisabled: false,
  },
};

export function getLearnerStatusUi(status?: string | null): LearnerStatusUi {
  const resolvedStatus = toLearnerStatus(status);
  return statusUiMap[resolvedStatus];
}

export function getLearnerHomeCta(status?: string | null): StatusCta {
  const resolvedStatus = toLearnerStatus(status);
  if (resolvedStatus === 'en_revision') {
    return {
      label: 'Ver estado de evaluación',
      href: '/learner/final-evaluation',
    };
  }
  if (resolvedStatus === 'aprobado') {
    return { label: 'Ver resumen / progreso', href: '/learner/progress' };
  }
  return { label: 'Continuar entrenamiento', href: '/learner/training' };
}
