import 'server-only';

import { getSupabaseServerClient } from '../server/supabase';
import type { ProviderMessage } from './provider';

type ThreadMessage = {
  sender: 'learner' | 'bot' | 'system';
  content: string;
  created_at: string;
};

export async function getConversationThread(
  conversationId: string,
  limit = 20,
): Promise<ThreadMessage[]> {
  const supabase = await getSupabaseServerClient();

  const { data, error } = await supabase
    .from('conversation_messages')
    .select('sender, content, created_at')
    .eq('conversation_id', conversationId)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) {
    throw new Error('Failed to load conversation thread');
  }

  return (data ?? []).reverse();
}

export function mapThreadToProviderMessages(
  thread: ThreadMessage[],
): ProviderMessage[] {
  return thread
    .filter((msg) => msg.sender !== 'system')
    .map((msg) => ({
      role: msg.sender === 'learner' ? 'user' : 'assistant',
      content: msg.content,
    }));
}
