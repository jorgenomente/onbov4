import 'server-only';

import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

function requireEnv(name: string) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is not set`);
  }
  return value;
}

const supabaseUrl = requireEnv('NEXT_PUBLIC_SUPABASE_URL');
const supabaseAnonKey = requireEnv('NEXT_PUBLIC_SUPABASE_ANON_KEY');

async function getServerSupabaseClient() {
  const cookieStore = await cookies();

  return createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      get(name) {
        return cookieStore.get(name)?.value;
      },
      set(name, value, options) {
        cookieStore.set({ name, value, ...options });
      },
      remove(name, options) {
        cookieStore.set({ name, value: '', ...options, maxAge: 0 });
      },
    },
  });
}

type ActiveUnitContext = {
  learnerId: string;
  localId: string;
  programId: string;
  programName: string;
  currentUnitId: string;
  currentUnitOrder: number;
  currentUnitTitle: string;
  currentUnitObjectives: string[];
  pastUnitIds: string[];
};

export async function getActiveUnitContext(
  learnerId: string,
): Promise<ActiveUnitContext> {
  const supabase = await getServerSupabaseClient();

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData?.user?.id) {
    throw new Error('Unauthenticated');
  }
  if (userData.user.id !== learnerId) {
    throw new Error('Forbidden');
  }

  const { data: trainingData, error: trainingError } = await supabase
    .from('learner_trainings')
    .select('learner_id, local_id, program_id, current_unit_order')
    .eq('learner_id', learnerId)
    .maybeSingle();

  if (trainingError || !trainingData) {
    throw new Error('Active training not found');
  }

  const { data: programData, error: programError } = await supabase
    .from('training_programs')
    .select('id, name')
    .eq('id', trainingData.program_id)
    .maybeSingle();

  if (programError || !programData) {
    throw new Error('Program not found');
  }

  const { data: currentUnitData, error: currentUnitError } = await supabase
    .from('training_units')
    .select('id, unit_order, title, objectives')
    .eq('program_id', trainingData.program_id)
    .eq('unit_order', trainingData.current_unit_order)
    .maybeSingle();

  if (currentUnitError || !currentUnitData) {
    throw new Error('Current unit not found');
  }

  const { data: pastUnitsData, error: pastUnitsError } = await supabase
    .from('training_units')
    .select('id')
    .eq('program_id', trainingData.program_id)
    .lt('unit_order', trainingData.current_unit_order);

  if (pastUnitsError) {
    throw new Error('Failed to load past units');
  }

  return {
    learnerId: trainingData.learner_id,
    localId: trainingData.local_id,
    programId: programData.id,
    programName: programData.name,
    currentUnitId: currentUnitData.id,
    currentUnitOrder: currentUnitData.unit_order,
    currentUnitTitle: currentUnitData.title,
    currentUnitObjectives: currentUnitData.objectives ?? [],
    pastUnitIds: (pastUnitsData ?? []).map((unit) => unit.id),
  };
}

export async function getKnowledgeForContext(unitIds: string[]) {
  if (unitIds.length === 0) {
    return [];
  }

  const supabase = await getServerSupabaseClient();

  const { data: mappings, error: mappingsError } = await supabase
    .from('unit_knowledge_map')
    .select('unit_id, knowledge_id')
    .in('unit_id', unitIds);

  if (mappingsError) {
    throw new Error('Failed to load knowledge mappings');
  }

  const knowledgeIds = Array.from(
    new Set((mappings ?? []).map((mapping) => mapping.knowledge_id)),
  );

  if (knowledgeIds.length === 0) {
    return [];
  }

  const { data: knowledgeItems, error: knowledgeError } = await supabase
    .from('knowledge_items')
    .select('id, title, content')
    .in('id', knowledgeIds);

  if (knowledgeError) {
    throw new Error('Failed to load knowledge items');
  }

  return knowledgeItems ?? [];
}

export async function buildChatContext(learnerId: string) {
  const activeContext = await getActiveUnitContext(learnerId);
  const unitIds = [activeContext.currentUnitId, ...activeContext.pastUnitIds];

  const supabase = await getServerSupabaseClient();
  const { data: currentMappings, error: currentMappingsError } = await supabase
    .from('unit_knowledge_map')
    .select('knowledge_id')
    .eq('unit_id', activeContext.currentUnitId);

  if (currentMappingsError) {
    throw new Error('Failed to load current unit knowledge');
  }

  if (!currentMappings || currentMappings.length === 0) {
    throw new Error('No knowledge configured for current unit');
  }

  const allowedKnowledge = await getKnowledgeForContext(unitIds);

  return {
    learner: {
      id: activeContext.learnerId,
      local_id: activeContext.localId,
    },
    program: {
      id: activeContext.programId,
      name: activeContext.programName,
    },
    unit: {
      order: activeContext.currentUnitOrder,
      title: activeContext.currentUnitTitle,
      objectives: activeContext.currentUnitObjectives,
    },
    allowedKnowledge: allowedKnowledge.map((item) => ({
      title: item.title,
      content: item.content,
    })),
    rules: [
      'No uses conocimiento externo',
      'No avances de unidad',
      'Responde solo con lo permitido',
    ],
  };
}
