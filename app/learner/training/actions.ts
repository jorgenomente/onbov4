'use server';

import { buildChatContext } from '../../../lib/ai/context-builder';
import { evaluatePracticeAnswer } from '../../../lib/ai/practice-evaluator';
import { generateReply } from '../../../lib/ai/provider';
import {
  getConversationThread,
  mapThreadToProviderMessages,
} from '../../../lib/ai/thread';
import { getSupabaseServerClient } from '../../../lib/server/supabase';
import { revalidatePath } from 'next/cache';

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

  revalidatePath('/learner/training');
  return { reply: reply.text };
}

export async function startPracticeScenario(input?: {
  scenarioId?: string;
}): Promise<{ conversationId: string; attemptId: string }> {
  const supabase = await getSupabaseServerClient();

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData?.user?.id) {
    throw new Error('Unauthenticated');
  }

  const learnerId = userData.user.id;

  const { data: trainingData, error: trainingError } = await supabase
    .from('learner_trainings')
    .select('local_id, program_id, current_unit_order')
    .eq('learner_id', learnerId)
    .maybeSingle();

  if (trainingError || !trainingData) {
    throw new Error('Active training not found');
  }

  let scenarioData: {
    id: string;
    title: string;
    instructions: string;
    success_criteria: string[];
    local_id: string | null;
    difficulty: number;
  } | null = null;

  if (input?.scenarioId && input.scenarioId.length > 0) {
    const { data, error } = await supabase
      .from('practice_scenarios')
      .select('id, title, instructions, success_criteria, local_id, difficulty')
      .eq('id', input.scenarioId)
      .maybeSingle();

    if (error) {
      throw new Error('Failed to load practice scenario');
    }

    scenarioData = data ?? null;
  }

  if (!scenarioData) {
    const { data: localScenario, error: localError } = await supabase
      .from('practice_scenarios')
      .select('id, title, instructions, success_criteria, local_id, difficulty')
      .eq('program_id', trainingData.program_id)
      .eq('unit_order', trainingData.current_unit_order)
      .eq('local_id', trainingData.local_id)
      .eq('difficulty', 1)
      .maybeSingle();

    if (localError) {
      throw new Error('Failed to load practice scenario');
    }

    scenarioData = localScenario ?? null;
  }

  if (!scenarioData) {
    const { data: orgScenario, error: orgError } = await supabase
      .from('practice_scenarios')
      .select('id, title, instructions, success_criteria, local_id, difficulty')
      .eq('program_id', trainingData.program_id)
      .eq('unit_order', trainingData.current_unit_order)
      .is('local_id', null)
      .eq('difficulty', 1)
      .maybeSingle();

    if (orgError || !orgScenario) {
      console.error('Practice scenario not found', {
        learnerId,
        programId: trainingData.program_id,
        localId: trainingData.local_id,
        unitOrder: trainingData.current_unit_order,
      });
      throw new Error(
        'No hay escenarios de práctica configurados para este local. Contactá a un referente.',
      );
    }

    scenarioData = orgScenario;
  }

  const { data: existingConversation, error: convoError } = await supabase
    .from('conversations')
    .select('id, created_at')
    .eq('learner_id', learnerId)
    .eq('program_id', trainingData.program_id)
    .eq('unit_order', trainingData.current_unit_order)
    .eq('context', 'practice')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (convoError) {
    throw new Error('Failed to load practice conversation');
  }

  let conversationId = existingConversation?.id ?? null;

  if (!conversationId) {
    const { data: createdConversation, error: createError } = await supabase
      .from('conversations')
      .insert({
        learner_id: learnerId,
        local_id: trainingData.local_id,
        program_id: trainingData.program_id,
        unit_order: trainingData.current_unit_order,
        context: 'practice',
      })
      .select('id')
      .maybeSingle();

    if (createError || !createdConversation) {
      throw new Error('Failed to create practice conversation');
    }

    conversationId = createdConversation.id;
  }

  if (!conversationId) {
    throw new Error('Practice conversation not initialized');
  }

  const { error: introError } = await supabase
    .from('conversation_messages')
    .insert({
      conversation_id: conversationId,
      sender: 'system',
      content: scenarioData.instructions,
    });

  if (introError) {
    throw new Error('Failed to insert practice instructions');
  }

  const { data: attempt, error: attemptError } = await supabase
    .from('practice_attempts')
    .insert({
      scenario_id: scenarioData.id,
      learner_id: learnerId,
      local_id: trainingData.local_id,
      conversation_id: conversationId,
      status: 'in_progress',
    })
    .select('id')
    .maybeSingle();

  if (attemptError || !attempt) {
    throw new Error('Failed to create practice attempt');
  }

  return { conversationId, attemptId: attempt.id };
}

export async function submitPracticeAnswer(input: {
  text: string;
}): Promise<{ reply: string; score: number; verdict: string }> {
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

  const { data: trainingData, error: trainingError } = await supabase
    .from('learner_trainings')
    .select('local_id, program_id, current_unit_order')
    .eq('learner_id', learnerId)
    .maybeSingle();

  if (trainingError || !trainingData) {
    throw new Error('Active training not found');
  }

  const { data: conversation, error: convoError } = await supabase
    .from('conversations')
    .select('id')
    .eq('learner_id', learnerId)
    .eq('program_id', trainingData.program_id)
    .eq('unit_order', trainingData.current_unit_order)
    .eq('context', 'practice')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (convoError || !conversation) {
    throw new Error('Practice conversation not found');
  }

  const conversationId = conversation.id;

  const { data: attempt, error: attemptError } = await supabase
    .from('practice_attempts')
    .select('id, scenario_id')
    .eq('learner_id', learnerId)
    .eq('conversation_id', conversationId)
    .order('started_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (attemptError || !attempt) {
    throw new Error('Practice attempt not found');
  }

  const { data: scenario, error: scenarioError } = await supabase
    .from('practice_scenarios')
    .select('id, title, instructions, success_criteria')
    .eq('id', attempt.scenario_id)
    .maybeSingle();

  if (scenarioError || !scenario) {
    throw new Error('Practice scenario not found');
  }

  const { data: learnerMessage, error: learnerMessageError } = await supabase
    .from('conversation_messages')
    .insert({
      conversation_id: conversationId,
      sender: 'learner',
      content: text,
    })
    .select('id')
    .maybeSingle();

  if (learnerMessageError || !learnerMessage) {
    throw new Error('Failed to store learner message');
  }

  const contextPackage = await buildChatContext(learnerId);
  const evaluation = await evaluatePracticeAnswer({
    scenario,
    learnerAnswer: text,
    chatContext: contextPackage,
  });

  const { error: evalError } = await supabase
    .from('practice_evaluations')
    .insert({
      attempt_id: attempt.id,
      learner_message_id: learnerMessage.id,
      score: evaluation.score,
      verdict: evaluation.verdict,
      strengths: evaluation.strengths,
      gaps: evaluation.gaps,
      feedback: evaluation.feedback,
      doubt_signals: evaluation.doubt_signals,
    });

  if (evalError) {
    throw new Error('Failed to store practice evaluation');
  }

  const feedbackMessage = `${evaluation.feedback}`;
  const { error: botError } = await supabase
    .from('conversation_messages')
    .insert({
      conversation_id: conversationId,
      sender: 'bot',
      content: feedbackMessage,
    });

  if (botError) {
    throw new Error('Failed to store feedback message');
  }

  if (evaluation.score >= 80) {
    await supabase.from('practice_attempt_events').insert({
      attempt_id: attempt.id,
      event_type: 'completed',
    });
  }

  return {
    reply: feedbackMessage,
    score: evaluation.score,
    verdict: evaluation.verdict,
  };
}
