'use server';

import { buildChatContext } from '../../../lib/ai/context-builder';
import { generateReply } from '../../../lib/ai/provider';
import {
  getConversationThread,
  mapThreadToProviderMessages,
} from '../../../lib/ai/thread';
import { getSupabaseServerClient } from '../../../lib/server/supabase';

type SendLearnerMessageInput = {
  text: string;
};

export async function sendLearnerMessage(
  input: SendLearnerMessageInput,
): Promise<{ reply: string }> {
  const text = input.text?.trim();
  if (!text) {
    throw new Error('Message text is required');
  }

  const supabase = await getSupabaseServerClient();

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData?.user?.id) {
    throw new Error('Unauthenticated');
  }

  const learnerId = userData.user.id;

  const { data: activeConversation, error: activeError } = await supabase
    .from('v_learner_active_conversation')
    .select('conversation_id, unit_order, context')
    .maybeSingle();

  if (activeError || !activeConversation) {
    throw new Error('Active conversation context not found');
  }

  let conversationId = activeConversation.conversation_id as string | null;

  if (!conversationId) {
    const { data: trainingData, error: trainingError } = await supabase
      .from('learner_trainings')
      .select('local_id, program_id, current_unit_order')
      .eq('learner_id', learnerId)
      .maybeSingle();

    if (trainingError || !trainingData) {
      throw new Error('Active training not found');
    }

    const { data: createdConversation, error: createError } = await supabase
      .from('conversations')
      .insert({
        learner_id: learnerId,
        local_id: trainingData.local_id,
        program_id: trainingData.program_id,
        unit_order: trainingData.current_unit_order,
        context: 'training',
      })
      .select('id')
      .maybeSingle();

    if (createError || !createdConversation) {
      throw new Error('Failed to create conversation');
    }

    conversationId = createdConversation.id;
  }

  const { error: insertLearnerError } = await supabase
    .from('conversation_messages')
    .insert({
      conversation_id: conversationId,
      sender: 'learner',
      content: text,
    });

  if (insertLearnerError) {
    throw new Error('Failed to store learner message');
  }

  if (!conversationId) {
    throw new Error('Conversation not initialized');
  }

  const contextPackage = await buildChatContext(learnerId);
  const system = `Reglas estrictas:\n- No uses conocimiento externo\n- No avances de unidad\n- Responde solo con lo permitido\n\nContexto:\n${JSON.stringify(
    contextPackage,
  )}`;

  const thread = await getConversationThread(conversationId, 20);
  const messages = mapThreadToProviderMessages(thread);

  const reply = await generateReply({ system, messages });

  const { error: insertBotError } = await supabase
    .from('conversation_messages')
    .insert({
      conversation_id: conversationId,
      sender: 'bot',
      content: reply.text,
    });

  if (insertBotError) {
    throw new Error('Failed to store bot message');
  }

  return { reply: reply.text };
}
