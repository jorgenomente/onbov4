import 'server-only';

type ProviderMessage = { role: 'user' | 'assistant'; content: string };

type GenerateReplyInput = {
  system: string;
  messages: ProviderMessage[];
};

type GenerateReplyOutput = {
  text: string;
  raw?: unknown;
};

export async function generateReply(
  input: GenerateReplyInput,
): Promise<GenerateReplyOutput> {
  const apiKey = process.env.OPENAI_API_KEY;
  const model = process.env.OPENAI_MODEL;

  if (!apiKey || !model) {
    throw new Error('LLM provider no configurado');
  }

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages: [{ role: 'system', content: input.system }, ...input.messages],
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`LLM provider error: ${response.status} ${errorText}`);
  }

  const payload = (await response.json()) as {
    choices?: { message?: { content?: string } }[];
  };

  const text = payload.choices?.[0]?.message?.content?.trim();
  if (!text) {
    throw new Error('LLM provider returned empty response');
  }

  return { text, raw: payload };
}

export type { GenerateReplyInput, GenerateReplyOutput, ProviderMessage };
