import Link from 'next/link';

import ChatClient from './ChatClient';
import ReviewHistory, {
  type ReviewDecision,
} from '../../../components/ReviewHistory';
import {
  getPracticeState,
  type NextStepAction,
} from '../../../lib/learner/next-step';
import { getLearnerStatusUi } from '../../../lib/learner/status-ui';
import {
  buildPracticeReminder,
  ensureTrainingConversationIntro,
  getCurrentUnitKnowledgeItems,
} from '../../../lib/learner/training-flow';
import { getSupabaseServerClient } from '../../../lib/server/supabase';
import ModeIndicator from '../ModeIndicator';
import NextStepCta from '../NextStepCta';

type ChatMessage = {
  id: string;
  sender: 'learner' | 'bot' | 'system';
  content: string;
  createdAt: string;
};

export default async function LearnerTrainingPage() {
  const supabase = await getSupabaseServerClient();
  const { data: userData, error: userError } = await supabase.auth.getUser();

  if (userError || !userData?.user?.id) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-3 px-4 py-6">
        <p className="text-sm text-slate-500">Necesitás iniciar sesión.</p>
      </main>
    );
  }

  const { conversationId: trainingConversationId, learningStarted } =
    await ensureTrainingConversationIntro(userData.user.id);

  const { data: trainingHome } = await supabase
    .from('v_learner_training_home')
    .select(
      'program_name, current_unit_order, current_unit_title, progress_percent, status',
    )
    .maybeSingle();

  const { data: trainingMeta } = await supabase
    .from('learner_trainings')
    .select('local_id, program_id')
    .eq('learner_id', userData?.user?.id ?? '')
    .maybeSingle();

  const { data: reviewDecisions } = await supabase
    .from('learner_review_decisions')
    .select('id, decision, reason, reviewer_name, created_at')
    .eq('learner_id', userData.user.id)
    .order('created_at', { ascending: false });

  const { data: activeConversation, error: conversationError } = await supabase
    .from('v_learner_active_conversation')
    .select('conversation_id, unit_order, context')
    .maybeSingle();

  if (conversationError) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-3 px-4 py-6">
        <h1 className="text-2xl font-semibold text-slate-900">Entrenamiento</h1>
        <p className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Error al cargar la conversación.
        </p>
      </main>
    );
  }

  const practiceActive = activeConversation?.context === 'practice';
  const conversationId = practiceActive
    ? (activeConversation?.conversation_id ?? null)
    : trainingConversationId;
  let initialMessages: ChatMessage[] = [];

  if (conversationId) {
    const { data: messages, error: messagesError } = await supabase
      .from('conversation_messages')
      .select('id, sender, content, created_at')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: true })
      .limit(50);

    if (messagesError) {
      return (
        <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-3 px-4 py-6">
          <h1 className="text-2xl font-semibold text-slate-900">
            Entrenamiento
          </h1>
          <p className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
            Error al cargar mensajes.
          </p>
        </main>
      );
    }

    initialMessages = (messages ?? []).map((message) => ({
      id: message.id,
      sender: message.sender as ChatMessage['sender'],
      content: message.content,
      createdAt: message.created_at,
    }));
  }

  const statusUi = getLearnerStatusUi(trainingHome?.status ?? null);
  const hasTraining = Boolean(
    trainingMeta?.program_id && trainingMeta?.local_id,
  );
  const practiceState = await getPracticeState({
    supabase,
    learnerId: userData?.user?.id ?? '',
    programId: trainingMeta?.program_id ?? null,
    unitOrder: trainingHome?.current_unit_order ?? null,
    localId: trainingMeta?.local_id ?? null,
  });
  const shouldStartPractice =
    hasTraining &&
    practiceState.available &&
    learningStarted &&
    !practiceState.completed &&
    !practiceActive;
  const primaryAction: NextStepAction = statusUi.chatInputDisabled
    ? { type: 'home', label: 'Volver al Home', href: '/learner' }
    : shouldStartPractice
      ? { type: 'practice', label: 'Continuar' }
      : { type: 'training', label: 'Continuar', href: '#chat-input' };
  const hintLine = statusUi.chatInputDisabled
    ? (statusUi.trainingHint ?? 'La evaluación está en revisión.')
    : practiceActive
      ? 'Estás practicando en esta unidad.'
      : shouldStartPractice
        ? 'Tu próximo paso es practicar esta unidad.'
        : practiceState.available &&
            !practiceState.completed &&
            !learningStarted
          ? 'Antes de practicar, escribí "comenzar" para ver el contenido.'
          : 'Tu próximo paso es aprender esta unidad.';
  const hasActiveConversation = Boolean(conversationId);
  const inputDisabled =
    statusUi.chatInputDisabled || !hasTraining || !hasActiveConversation;
  const inputDisabledReason = !hasTraining
    ? 'Tu entrenamiento todavía no está asignado. Contactá a un referente.'
    : !hasActiveConversation
      ? 'Necesitamos iniciar el contexto antes de continuar.'
      : statusUi.chatInputHint;

  const practiceReminder = practiceActive
    ? buildPracticeReminder(
        (await getCurrentUnitKnowledgeItems(userData.user.id)).items,
      )
    : null;

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-6 px-4 py-6">
      <header className="flex flex-col gap-1">
        <h1 className="text-2xl font-semibold text-slate-900">Entrenamiento</h1>
        <p className="text-sm text-slate-600">
          {trainingHome?.current_unit_title
            ? `Unidad ${trainingHome.current_unit_order}: ${trainingHome.current_unit_title}`
            : 'Seguí las indicaciones del bot para avanzar.'}
        </p>
      </header>

      <div data-testid="training-phase">
        <ModeIndicator
          mode={
            practiceActive || shouldStartPractice ? 'Practicar' : 'Aprender'
          }
        />
      </div>

      <div className="flex flex-col gap-2">
        <div className="flex flex-wrap gap-2">
          <NextStepCta
            action={primaryAction}
            className="rounded-md bg-emerald-600 px-3 py-2 text-sm font-semibold text-white"
            afterPracticeHref="/learner/training"
          />
          <Link
            href="/learner"
            className="rounded-md border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-700"
          >
            Volver al Home
          </Link>
        </div>
        <p className="text-xs text-slate-500">{hintLine}</p>
      </div>

      <ReviewHistory
        decisions={reviewDecisions as ReviewDecision[] | null}
        title="Historial de decisiones"
      />

      {!practiceActive &&
      practiceState.available &&
      !practiceState.completed &&
      !learningStarted ? (
        <span data-testid="needs-start" className="sr-only">
          needs-start
        </span>
      ) : null}

      {practiceActive && practiceReminder ? (
        <section
          data-testid="training-reminder"
          className="rounded-lg border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800"
        >
          <p className="text-xs font-semibold text-amber-700 uppercase">
            Recordatorio
          </p>
          <p className="mt-2 whitespace-pre-line">{practiceReminder}</p>
        </section>
      ) : null}

      {!hasTraining ? (
        <div className="rounded-md border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">
          Todavía no tenés un entrenamiento asignado. Contactá a tu referente
          para activarlo.
        </div>
      ) : null}

      <ChatClient
        initialMessages={initialMessages}
        initialContext={practiceActive ? 'practice' : 'training'}
        inputDisabled={inputDisabled}
        inputDisabledReason={inputDisabledReason}
        showPracticeButton={false}
      />
    </main>
  );
}
