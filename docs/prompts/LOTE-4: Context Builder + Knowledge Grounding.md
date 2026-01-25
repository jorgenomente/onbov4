Actuá como Lead Software Architect + Senior Backend Engineer siguiendo AGENTS.md y docs/plan-mvp.md.

OBJETIVO (LOTE 4):
Implementar el motor de conocimiento “cargado” y el context builder server-only para el chatbot,
asegurando que el bot responda SOLO con conocimiento permitido (unidad activa + pasadas),
sin perder estado ni violar RLS.

SOURCES OF TRUTH:

- docs/product-master.md
- docs/plan-mvp.md
- AGENTS.md

REGLAS:

- DB-first + RLS-first.
- SQL nativo únicamente para schema.
- Nada de select \*.
- Todo conocimiento es explícito y persistido.
- El bot NO usa conocimiento externo ni improvisa.
- Context builder es server-only.
- Entregables: 1 migración SQL + helpers server-only + activity log.
- Al final: npx supabase db reset, npm run lint, npm run build.
- Git: commit directo en main.

TAREAS:

A) MIGRACIÓN DB (1 archivo nuevo):

1. knowledge_items
   - id uuid pk default gen_random_uuid()
   - org_id uuid not null references organizations(id) on delete restrict
   - local_id uuid null references locals(id) on delete restrict
     (NULL = knowledge a nivel organización)
   - title text not null
   - content text not null
   - created_at timestamptz not null default now()
     Indexes: (org_id), (local_id)

2. unit_knowledge_map
   - unit_id uuid not null references training_units(id) on delete cascade
   - knowledge_id uuid not null references knowledge_items(id) on delete cascade
   - primary key (unit_id, knowledge_id)

B) RLS + POLICIES:

Habilitar RLS en:

- knowledge_items
- unit_knowledge_map

Policies SELECT:

1. knowledge_items:

- superadmin: todo
- admin_org: org_id = current_org_id()
- referente/aprendiz:
  - org_id = current_org_id()
  - AND (local_id IS NULL OR local_id = current_local_id())

2. unit_knowledge_map:

- permitido indicates si el knowledge_id es visible según policy de knowledge_items
  (usar EXISTS)

Writes:

- Por ahora, NO habilitar INSERT/UPDATE/DELETE desde client.
- Dejar listo para server flows futuros.

C) HELPERS SERVER-ONLY (TypeScript):

Crear helpers en `/lib/ai/context-builder.ts` (server-only):

Funciones mínimas:

1. getActiveUnitContext(learnerId)
   - Obtiene:
     - learner_training (unidad activa)
     - training_unit actual
     - training_units pasadas (solo metadata necesaria)
   - Valida pertenencia por RLS (usar supabase server client)

2. getKnowledgeForContext(unitIds[])
   - Devuelve knowledge_items asociados a esas unidades
   - Respeta herencia org/local (NULL local_id permitido)

3. buildChatContext(learnerId)
   Devuelve objeto estructurado:
   {
   learner: { id, local_id },
   program: { id, name },
   unit: { order, title, objectives },
   allowedKnowledge: [{ title, content }],
   rules: [
   "No uses conocimiento externo",
   "No avances de unidad",
   "Responde solo con lo permitido"
   ]
   }

⚠️ Este helper NO llama a ningún LLM todavía.

D) GUARDRAILS:

- Si no hay knowledge asociado a la unidad activa:
  - lanzar error controlado (no fallback silencioso)
- Si learnerId no pertenece a la sesión:
  - fail closed

E) ACTIVIDAD (docs/activity-log.md):
Agregar entrada con:

- creación de knowledge tables
- regla de grounding estricto
- separación DB vs IA provider

F) VERIFICACIÓN:

1. npx supabase db reset OK
2. Manual:

- aprendiz no puede acceder a knowledge de otra org/local
- knowledge con local_id NULL es visible en su org

3. npm run lint + npm run build OK

AL FINAL:

- Commit directo en main:
  "feat: lote 4 knowledge grounding + context builder base"
- Push a origin main
- Reportar archivos tocados + comandos y resultados
