Actuá como Lead Software Architect + Senior Backend Engineer siguiendo AGENTS.md y docs/plan-mvp.md.

OBJETIVO (LOTE 5):
Conectar el “chat engine” end-to-end: recibir mensaje del aprendiz (server action),
construir contexto (Lote 4), llamar a un provider LLM de forma provider-agnostic,
persistir mensaje del aprendiz + respuesta del bot en conversation_messages (append-only),
y devolver la respuesta a la UI.

SOURCES OF TRUTH:

- docs/product-master.md
- docs/plan-mvp.md
- AGENTS.md

REGLAS:

- Todo server-only (nada de llamar LLM desde client).
- Provider-agnostic: interfaz única + adapter.
- El bot SOLO responde con el contexto construido (Lote 4). No conocimiento externo.
- Persistencia append-only: no updates/deletes de messages.
- No romper RLS: leer/escribir solo lo permitido.
- Entregables: código (server action + adapter + minimal API), y una migración DB SOLO si hace falta.
- Al final: npx supabase db reset (si hubo migración), npm run lint, npm run build.
- Git: commit directo en main + push.

TAREAS:

A) PROVIDER-AGNOSTIC LLM LAYER (server-only)

1. Crear /lib/ai/provider.ts con una interfaz:
   - generateReply({ system, messages }): returns { text, raw? }
     Donde:
   - system: string (reglas + contexto serializado)
   - messages: array de { role: 'user'|'assistant', content: string }

2. Implementar un adapter mínimo:
   Opción A (recomendada): usar OpenAI API si ya está disponible en tu stack.
   Opción B: si no hay API key aún, implementar "mock provider" que devuelva respuesta controlada
   (pero NO lo dejes como default en production).

   Decisión:
   - Si existe env OPENAI_API_KEY (u otra), usar provider real.
   - Si no existe, lanzar error claro: "LLM provider no configurado" (fail closed).

   IMPORTANTE: no hardcodear modelos ni keys; todo por env.

B) SERVER ACTION: sendLearnerMessage
Crear en /app/learner/training/actions.ts (o ubicación server-only equivalente):

Firma sugerida:

- sendLearnerMessage(input: { text: string }): Promise<{ reply: string }>

Comportamiento:

1. Obtener user_id de sesión (supabase SSR) y validar autenticación.
2. Obtener conversación activa del aprendiz:
   - usar v_learner_active_conversation si existe,
   - si no existe conversación para la unidad activa, crearla (server-only) en conversations.
     Reglas para crear:
     - learner_id = auth.uid()
     - local_id = current_local_id()
     - program_id = learner_trainings.program_id
     - unit_order = learner_trainings.current_unit_order
     - context = 'training'
3. Insertar mensaje del aprendiz en conversation_messages:
   - sender='learner'
   - content=input.text
4. Construir contexto con buildChatContext(auth.uid()).
5. Llamar al provider:
   - system: incluir reglas + JSON compactado del context package.
   - messages: últimos N mensajes del thread (ej 20), mapeados a user/assistant.
6. Insertar respuesta del bot en conversation_messages:
   - sender='bot'
   - content=reply
7. (Opcional) Insertar evaluación base en bot_message_evaluations (si definiste métricas mínimas):
   - tags básicos o placeholder (sin sobre-ingeniería).
8. Devolver reply al cliente.

C) LECTURA DEL THREAD (server)
Asegurar que hay un helper server-only para leer el thread (últimos N):

- getConversationThread(conversationId, limit)

D) UI MINIMAL WIRING (si ya existe pantalla de training)
Si existe /app/learner/training:

- agregar form/input + submit que llame la server action
- renderizar mensajes del thread (server fetch + client hydration mínima)
- estados: loading / error

NO crear diseño complejo; solo funcionalidad real.

E) ENV VARS (documentar)
Agregar a README o docs (o activity log) cuáles env vars necesita:

- LLM provider key (ej OPENAI_API_KEY)
- (si aplica) modelo (ej OPENAI_MODEL)
  Sin exponer secretos.

F) ACTIVITY LOG
Actualizar docs/activity-log.md con:

- Lote 5: chat end-to-end
- provider-agnostic layer
- guardrails fail-closed

G) VERIFICACIÓN

- Si no hay provider key: el envío debe fallar con error claro (no fallback).
- Con provider key: responder y persistir ambos mensajes.
- npm run lint + npm run build OK.
- Si tocaste migraciones: npx supabase db reset OK.

AL FINAL

- Commit directo en main:
  "feat: lote 5 chat e2e server action + llm adapter"
- Push origin main
- Reportar archivos tocados + comandos y resultados
