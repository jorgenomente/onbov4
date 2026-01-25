# FEATURE-LEARNER-TRAINING-CHAT-UI

## Contexto

Implementar UI mínima de chat en /learner/training usando server action existente y grounding fail-closed.

## Prompt ejecutado

```txt
Sos un Senior Frontend/Fullstack Engineer (Next.js 16 App Router + Supabase SSR). Ya auditamos el repo y confirmamos que el motor existe; NO hay que re-crear nada.

Hallazgos confirmados (no discutir, actuar):
- Existe server action: app/learner/training/actions.ts → sendLearnerMessage (crea conversation si no existe, inserta conversation_messages learner+bot, usa buildChatContext + generateReply).
- Existe lib/ai/thread.ts para recuperar hilo.
- Existen views: v_learner_active_conversation y v_conversation_thread.
- El problema actual: app/learner/training/page.tsx es placeholder y no llama al motor.
- Grounding es fail-closed: si no hay knowledge para unidad activa, buildChatContext lanza error “No knowledge configured…”. Hay que capturar y mostrar esto en UI (sin 500).

Objetivo del cambio:
Implementar UI mínima en /learner/training que:
1) Muestre el hilo actual (mensajes recientes) del aprendiz al cargar la página.
2) Permita enviar un mensaje (input + submit) llamando sendLearnerMessage.
3) Renderice la respuesta del bot en pantalla y refresque el hilo.
4) Maneje loading/error y muestre un mensaje user-friendly si falla por grounding (sin exponer stacktrace).
5) No tocar DB, no tocar migraciones, no crear nuevas tablas, no re-arquitecturar.

Requisitos técnicos:
- Preferir RSC para carga inicial + componente client para interacción.
- Nada de service_role en cliente. Lecturas iniciales deben usar getSupabaseServerClient() y views existentes (sin select *).
- Revalidación: usar revalidatePath('/learner/training') dentro de sendLearnerMessage (si no está) o en la UI con router.refresh() tras enviar.
- UI mobile-first simple (Tailwind). Sin shadcn salvo que ya esté en el repo y sea trivial.
- No agregar nuevas rutas.

Implementación solicitada (pasos exactos):
A) Server: carga inicial del thread
- En app/learner/training/page.tsx (server component), cargar:
  - training home con view v_learner_training_home (si aplica) para mostrar unidad activa (opcional).
  - conversation_id con v_learner_active_conversation.
  - thread con v_conversation_thread (orden asc) LIMIT razonable (ej 50).
- Pasar mensajes iniciales al client component.

B) Client: componente de chat
- Crear app/learner/training/ChatClient.tsx (client component) que reciba:
  - initialMessages (array)
- Render:
  - lista de mensajes (distinguir learner vs assistant)
  - textarea/input + botón enviar
  - loading state
  - error banner
- Al enviar:
  - llamar server action sendLearnerMessage(formData o params según firma actual)
  - optimista opcional (no requerido)
  - luego router.refresh() para recargar mensajes desde server
- Si sendLearnerMessage arroja error que incluye “No knowledge configured”, mostrar:
  - “No tengo información cargada para responder esa pregunta.”
  (esto preserva fail-closed sin romper UX)

C) Ajustes mínimos en actions.ts (solo si falta)
- Asegurar que sendLearnerMessage haga revalidatePath('/learner/training') al final (solo si no lo hace ya).
- Asegurar que los errores se propaguen con un mensaje estable (sin stack gigante). No ocultar en server logs.

Criterios de aceptación (obligatorios):
1) Login aprendiz → /learner/training muestra chat (no placeholder).
2) Enviar “¿Cómo debo saludar a un cliente?” → aparece respuesta del bot (grounded).
3) Enviar “¿Qué es upselling?” → NO inventa; responde de forma controlada si no hay knowledge permitido.
4) No hay 500; los errores de grounding se ven como mensaje user-friendly.
5) Se observa persistencia en DB: conversation_messages agrega 2 filas por intercambio.

Entrega:
- Lista de archivos tocados + diff completo.
- Confirmar qué view/queries se usan (v_learner_active_conversation, v_conversation_thread) en el código final.
```

Resultado esperado
UI mínima de chat en /learner/training usando acciones existentes y grounding.

Notas (opcional)
N/A.
