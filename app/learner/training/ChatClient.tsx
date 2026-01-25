'use client';

import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';

import { sendLearnerMessage } from './actions';

type ChatMessage = {
  id: string;
  sender: 'learner' | 'bot' | 'system';
  content: string;
  createdAt: string;
};

type ChatClientProps = {
  initialMessages: ChatMessage[];
};

export default function ChatClient({ initialMessages }: ChatClientProps) {
  const router = useRouter();
  const [messages, setMessages] = useState<ChatMessage[]>(initialMessages);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const orderedMessages = useMemo(() => messages, [messages]);

  useEffect(() => {
    setMessages(initialMessages);
  }, [initialMessages]);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const text = input.trim();
    if (!text || loading) return;

    setLoading(true);
    setError('');

    try {
      const response = await sendLearnerMessage({ text });
      const optimisticLearner: ChatMessage = {
        id: `local-${Date.now()}-learner`,
        sender: 'learner',
        content: text,
        createdAt: new Date().toISOString(),
      };
      const optimisticBot: ChatMessage = {
        id: `local-${Date.now()}-bot`,
        sender: 'bot',
        content: response.reply,
        createdAt: new Date().toISOString(),
      };

      setMessages((prev) => [...prev, optimisticLearner, optimisticBot]);
      setInput('');
      router.refresh();
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Error inesperado.';
      if (message.toLowerCase().includes('no knowledge configured')) {
        setError('No tengo información cargada para responder esa pregunta.');
      } else {
        setError('No pudimos enviar tu mensaje. Intentá de nuevo.');
      }
      console.error(err);
    } finally {
      setLoading(false);
    }
  }

  return (
    <section className="flex flex-1 flex-col gap-4">
      <div className="flex flex-col gap-3 rounded-xl border border-slate-200 bg-white p-4">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold text-slate-700">Chat</h2>
          {loading && (
            <span className="text-xs text-slate-400">Enviando...</span>
          )}
        </div>

        <div className="flex flex-col gap-3">
          {orderedMessages.length === 0 ? (
            <div className="rounded-md border border-dashed border-slate-200 p-4 text-sm text-slate-500">
              Todavía no hay mensajes. Empezá con tu primera pregunta.
            </div>
          ) : (
            orderedMessages.map((message) => (
              <div
                key={message.id}
                className={`flex ${
                  message.sender === 'learner' ? 'justify-end' : 'justify-start'
                }`}
              >
                <div
                  className={`max-w-[85%] rounded-2xl px-3 py-2 text-sm ${
                    message.sender === 'learner'
                      ? 'bg-emerald-600 text-white'
                      : message.sender === 'system'
                        ? 'bg-slate-100 text-slate-600'
                        : 'bg-slate-100 text-slate-800'
                  }`}
                >
                  {message.content}
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {error ? (
        <div className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          {error}
        </div>
      ) : null}

      <form onSubmit={handleSubmit} className="flex flex-col gap-3">
        <label className="text-sm font-medium text-slate-700">Tu mensaje</label>
        <textarea
          value={input}
          onChange={(event) => setInput(event.target.value)}
          rows={3}
          className="w-full rounded-md border border-slate-300 p-2 text-sm focus:border-emerald-500 focus:outline-none"
          placeholder="Escribí tu pregunta..."
          disabled={loading}
          required
        />
        <button
          type="submit"
          className="w-full rounded-md bg-emerald-600 px-3 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-70"
          disabled={loading}
        >
          Enviar
        </button>
      </form>
    </section>
  );
}
