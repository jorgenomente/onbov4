import ChatClient from './ChatClient';
import ReviewHistory, {
  type ReviewDecision,
} from '../../../components/ReviewHistory';
import { getSupabaseServerClient } from '../../../lib/server/supabase';

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

  const { data: trainingHome } = await supabase
    .from('v_learner_training_home')
    .select(
      'program_name, current_unit_order, current_unit_title, progress_percent',
    )
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

  const conversationId = activeConversation?.conversation_id ?? null;
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

      <ReviewHistory
        decisions={reviewDecisions as ReviewDecision[] | null}
        title="Historial de decisiones"
      />

      <ChatClient
        initialMessages={initialMessages}
        initialContext={activeConversation?.context ?? 'training'}
      />
    </main>
  );
}
