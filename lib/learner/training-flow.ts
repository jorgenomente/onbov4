import 'server-only';

import { getActiveUnitContext } from '../ai/context-builder';
import { getSupabaseServerClient } from '../server/supabase';

type KnowledgeItem = {
  id: string;
  title: string;
  content: string;
  content_type?: string | null;
};

const LEARNING_START_SIGNALS = ['comenzar', 'listo', 'empezar'];

function normalizeText(value: string) {
  return value
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
}

export function isLearningStartSignal(value: string) {
  const normalized = normalizeText(value);
  return LEARNING_START_SIGNALS.some((signal) => normalized === signal);
}

function pickByKeywords(items: KnowledgeItem[], keywords: string[]) {
  return items.filter((item) => {
    const title = normalizeText(item.title);
    return keywords.some((keyword) => title.includes(keyword));
  });
}

export function buildIntroMessage(items: KnowledgeItem[], unitTitle: string) {
  const introItem =
    pickByKeywords(items, ['intro', 'introduccion'])[0] ?? items[0];
  if (!introItem) {
    return `Vamos a trabajar la unidad \"${unitTitle}\". Si necesitas ayuda, escribi tu duda.`;
  }
  return `Introduccion\n${introItem.content}`;
}

export function buildLearningMessage(items: KnowledgeItem[]) {
  const standards = pickByKeywords(items, ['estandar', 'regla']);
  const examples = pickByKeywords(items, ['ejemplo']);
  const parts: string[] = [];

  if (standards.length > 0) {
    parts.push(`Estandar / reglas\n${standards[0].content}`);
  }

  if (examples.length > 0) {
    parts.push(`Ejemplo\n${examples[0].content}`);
  }

  if (parts.length === 0 && items[0]) {
    parts.push(`Recorda\n${items[0].content}`);
  }

  return parts.join('\n\n');
}

export function buildPracticeReminder(items: KnowledgeItem[]) {
  const standards = pickByKeywords(items, ['estandar', 'regla']);
  const examples = pickByKeywords(items, ['ejemplo']);
  const reminders = [...standards.slice(0, 1), ...examples.slice(0, 1)];

  if (reminders.length === 0 && items[0]) {
    reminders.push(items[0]);
  }

  return reminders.map((item) => item.content).join('\n\n');
}

export async function getCurrentUnitKnowledgeItems(learnerId: string) {
  const supabase = await getSupabaseServerClient();
  const activeContext = await getActiveUnitContext(learnerId);

  const { data: mappings, error: mappingError } = await supabase
    .from('unit_knowledge_map')
    .select('knowledge_id')
    .eq('unit_id', activeContext.currentUnitId);

  if (mappingError) {
    throw new Error('Failed to load current unit knowledge');
  }

  const knowledgeIds = (mappings ?? []).map((mapping) => mapping.knowledge_id);

  if (knowledgeIds.length === 0) {
    return {
      items: [] as KnowledgeItem[],
      unitTitle: activeContext.currentUnitTitle,
    };
  }

  const { data: knowledgeItems, error: knowledgeError } = await supabase
    .from('knowledge_items')
    .select('id, title, content, content_type')
    .in('id', knowledgeIds);

  if (knowledgeError) {
    throw new Error('Failed to load knowledge items');
  }

  return {
    items: (knowledgeItems ?? []) as KnowledgeItem[],
    unitTitle: activeContext.currentUnitTitle,
  };
}

export async function getLearningStartState(conversationId: string) {
  const supabase = await getSupabaseServerClient();
  const { data: messages, error } = await supabase
    .from('conversation_messages')
    .select('content, sender')
    .eq('conversation_id', conversationId)
    .eq('sender', 'learner')
    .order('created_at', { ascending: true })
    .limit(10);

  if (error) {
    throw new Error('Failed to load learning signals');
  }

  const started =
    messages?.some((message) => isLearningStartSignal(message.content)) ??
    false;

  return { started };
}

export async function ensureTrainingConversationIntro(learnerId: string) {
  const supabase = await getSupabaseServerClient();

  const { data: trainingData, error: trainingError } = await supabase
    .from('learner_trainings')
    .select('local_id, program_id, current_unit_order')
    .eq('learner_id', learnerId)
    .maybeSingle();

  if (trainingError || !trainingData) {
    const { error: initError } = await supabase.rpc(
      'ensure_learner_training_from_active_program',
    );
    if (initError) {
      throw new Error('Active training not found');
    }
  }

  const { data: ensuredTraining, error: ensuredError } = await supabase
    .from('learner_trainings')
    .select('local_id, program_id, current_unit_order')
    .eq('learner_id', learnerId)
    .maybeSingle();

  if (ensuredError || !ensuredTraining) {
    throw new Error('Active training not found');
  }

  const { data: existingConversation, error: convoError } = await supabase
    .from('conversations')
    .select('id, created_at')
    .eq('learner_id', learnerId)
    .eq('program_id', ensuredTraining.program_id)
    .eq('unit_order', ensuredTraining.current_unit_order)
    .eq('context', 'training')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (convoError) {
    throw new Error('Failed to load training conversation');
  }

  let conversationId = existingConversation?.id ?? null;

  if (!conversationId) {
    const { data: createdConversation, error: createError } = await supabase
      .from('conversations')
      .insert({
        learner_id: learnerId,
        local_id: ensuredTraining.local_id,
        program_id: ensuredTraining.program_id,
        unit_order: ensuredTraining.current_unit_order,
        context: 'training',
      })
      .select('id')
      .maybeSingle();

    if (createError || !createdConversation) {
      throw new Error('Failed to create training conversation');
    }

    conversationId = createdConversation.id;
  }

  if (!conversationId) {
    throw new Error('Training conversation not initialized');
  }

  const { data: existingMessage } = await supabase
    .from('conversation_messages')
    .select('id')
    .eq('conversation_id', conversationId)
    .limit(1)
    .maybeSingle();

  if (!existingMessage) {
    const { items, unitTitle } = await getCurrentUnitKnowledgeItems(learnerId);
    const introMessage = buildIntroMessage(items, unitTitle);

    const { error: introError } = await supabase
      .from('conversation_messages')
      .insert({
        conversation_id: conversationId,
        sender: 'bot',
        content: introMessage,
      });

    if (introError) {
      throw new Error('Failed to insert intro message');
    }

    const { error: promptError } = await supabase
      .from('conversation_messages')
      .insert({
        conversation_id: conversationId,
        sender: 'bot',
        content: 'Cuando estes listo, escribi "comenzar".',
      });

    if (promptError) {
      throw new Error('Failed to insert start prompt');
    }
  }

  const { started } = await getLearningStartState(conversationId);

  return {
    conversationId,
    learningStarted: started,
  };
}
