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
  const provider = process.env.LLM_PROVIDER ?? 'openai';

  if (provider === 'mock') {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('Mock LLM provider not allowed in production');
    }

    const expectsJson =
      input.system.includes('Responde SOLO con JSON') ||
      input.system.includes('JSON válido') ||
      input.system.includes('JSON estricto');

    if (expectsJson) {
      return {
        text: JSON.stringify({
          score: 85,
          verdict: 'pass',
          strengths: ['Respuesta clara y enfocada'],
          gaps: [],
          feedback: 'Buen trabajo. Mantené la claridad y el tono cordial.',
          doubt_signals: [],
        }),
      };
    }

    return { text: 'Respuesta de prueba (mock).' };
  }

  if (provider === 'openai') {
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
        messages: [
          { role: 'system', content: input.system },
          ...input.messages,
        ],
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

  if (provider === 'gemini') {
    const apiKey = process.env.GEMINI_API_KEY;
    const model = process.env.GEMINI_MODEL ?? 'gemini-2.5-flash';

    if (!apiKey) {
      throw new Error('Gemini API key not configured');
    }

    const contents = [
      {
        role: 'user',
        parts: [{ text: `SYSTEM\\n${input.system}` }],
      },
      ...input.messages.map((message) => ({
        role: message.role === 'assistant' ? 'model' : 'user',
        parts: [{ text: message.content }],
      })),
    ];

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents,
          generationConfig: {
            temperature: 0.2,
          },
        }),
      },
    );

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`LLM provider error: ${response.status} ${errorText}`);
    }

    const payload = (await response.json()) as {
      candidates?: { content?: { parts?: { text?: string }[] } }[];
    };

    const text = payload.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
    if (!text) {
      throw new Error('LLM provider returned empty response');
    }

    return { text, raw: payload };
  }

  throw new Error('Unsupported LLM provider');
}

export type { GenerateReplyInput, GenerateReplyOutput, ProviderMessage };
