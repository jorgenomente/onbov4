Actuá como Lead Software Architect + Senior Backend Engineer siguiendo AGENTS.md y docs/plan-mvp.md.

OBJETIVO (LOTE 3):
Implementar conversación persistente y auditoría completa del chat (DB-first + RLS-first), con contratos de lectura listos para UI y escritura controlada server-only.

SOURCES OF TRUTH:

- docs/product-master.md
- docs/plan-mvp.md
- AGENTS.md

REGLAS:

- DB-first + RLS-first.
- SQL nativo únicamente.
- Nada de select \*.
- Todas las tablas con RLS habilitada y policies explícitas.
- Conversación y mensajes son APPEND-ONLY (no update, no delete).
- Multi-tenancy derivado desde auth.uid() y helpers current\_\*.
- Escrituras solo desde server flows (RPC/Server Actions).
- Entregables: 1 migración SQL versionada + views base + activity log.
- Al final: npx supabase db reset, npm run lint, npm run build (arreglar lo que falle).
- Git: commit directo en main (sin ramas).

TAREAS:

A) MIGRACIÓN DB (1 archivo nuevo):

1. conversations
   - id uuid pk default gen_random_uuid()
   - learner_id uuid not null references profiles(user_id) on delete cascade
   - local_id uuid not null references locals(id) on delete restrict
   - program_id uuid not null references training_programs(id) on delete restrict
   - unit_order int not null
   - context text not null -- ej: 'training' | 'practice' | 'final_evaluation'
   - created_at timestamptz not null default now()
     Indexes: (learner_id), (local_id), (program_id)

2. conversation_messages (APPEND-ONLY)
   - id uuid pk default gen_random_uuid()
   - conversation_id uuid not null references conversations(id) on delete cascade
   - sender text not null check (sender in ('learner','bot','system'))
   - content text not null
   - created_at timestamptz not null default now()
     Indexes: (conversation_id), (created_at)

3. bot_message_evaluations (opcional en Lote 3, base para métricas)
   - id uuid pk default gen_random_uuid()
   - message_id uuid not null references conversation_messages(id) on delete cascade
   - coherence_score numeric(4,2) null
   - omissions text[] null
   - tags text[] null
   - created_at timestamptz not null default now()
     Indexes: (message_id), (created_at)

B) RLS + POLICIES (STRICT):

Habilitar RLS en:

- conversations
- conversation_messages
- bot_message_evaluations

Policies SELECT:

1. conversations:

- aprendiz: learner_id = auth.uid()
- referente: conversations del local (local_id = current_local_id())
- admin_org: conversations de locales de su org (EXISTS locals.org_id = current_org_id())
- superadmin: todo

2. conversation_messages:

- permitido si el usuario puede ver la conversación padre (EXISTS conversations)

3. bot_message_evaluations:

- mismo alcance que conversation_messages (EXISTS)

Writes:

- INSERT permitido solo a server flows.
- NO policies UPDATE ni DELETE (append-only).
- Documentar en comentario que los writes se harán vía RPC/Server Actions.

C) VIEWS (lectura, contratos para UI):

1. v_learner_active_conversation
   Para auth.uid(), devuelve:

- conversation_id
- unit_order
- context
- created_at

(La conversación activa es la de la unidad actual; si hay varias, tomar la más reciente por created_at.)

2. v_conversation_thread
   Devuelve:

- message_id
- sender
- content
- created_at
  Ordenado por created_at asc.
  Acceso controlado por RLS de conversation_messages.

3. v_referente_conversation_summary
   Para referente/admin_org:

- conversation_id
- learner_id
- full_name
- unit_order
- last_message_at
- total_messages

D) ACTIVIDAD (docs/activity-log.md):
Agregar entrada con:

- creación de conversaciones y mensajes
- regla append-only
- alcance RLS
- checklist manual de verificación

E) VERIFICACIÓN:

1. npx supabase db reset OK
2. Manual:

- aprendiz ve solo su conversación
- referente ve conversaciones de su local
- no se puede UPDATE/DELETE mensajes

3. npm run lint + npm run build OK

AL FINAL:

- Commit directo en main:
  "feat: lote 3 conversation + audit base"
- Push a origin main
- Reportar: archivos tocados + comandos y resultados
