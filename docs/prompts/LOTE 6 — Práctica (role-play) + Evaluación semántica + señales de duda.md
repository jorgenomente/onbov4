Actuá como Lead Software Architect + Senior Backend Engineer siguiendo AGENTS.md y docs/plan-mvp.md.

OBJETIVO (LOTE 6):
Implementar “Práctica” integrada (role-play) y evaluación semántica de respuestas abiertas,
persistiendo intentos/evaluaciones (append-only) y detectando señales de duda (“no sé”, etc.),
sin crear una pestaña nueva: todo vive dentro del flujo de chat.

SOURCES OF TRUTH:

- docs/product-master.md
- docs/plan-mvp.md
- AGENTS.md

REGLAS:

- DB-first + RLS-first.
- SQL nativo únicamente para schema.
- Nada de select \*.
- APPEND-ONLY: practice_attempts y practice_evaluations NO se editan ni borran.
- Server-only: evaluación con LLM solo desde server.
- Grounded: el bot evalúa contra criterios definidos + knowledge permitido.
- No crear UI compleja: solo server actions/contratos; si hay que tocar UI, mínimo indispensable.
- Git: commit directo en main + push.
- Al final: npx supabase db reset, npm run lint, npm run build.

TAREAS:

A) MIGRACIÓN DB (1 archivo nuevo)

1. practice_scenarios
   - id uuid pk default gen_random_uuid()
   - org_id uuid not null references organizations(id) on delete restrict
   - local_id uuid null references locals(id) on delete restrict
   - program_id uuid not null references training_programs(id) on delete cascade
   - unit_order int not null
   - title text not null
   - difficulty int not null default 1 check (difficulty between 1 and 5)
   - instructions text not null -- guión del role-play
   - success_criteria text[] not null default '{}' -- bullets evaluables
   - created_at timestamptz not null default now()
     Indexes: (org_id), (local_id), (program_id), (program_id, unit_order)

2. practice_attempts (append-only)
   - id uuid pk default gen_random_uuid()
   - scenario_id uuid not null references practice_scenarios(id) on delete restrict
   - learner_id uuid not null references profiles(user_id) on delete cascade
   - local_id uuid not null references locals(id) on delete restrict
   - conversation_id uuid not null references conversations(id) on delete cascade
   - started_at timestamptz not null default now()
   - ended_at timestamptz null
   - status text not null check (status in ('in_progress','completed'))
     Indexes: (learner_id), (local_id), (scenario_id), (conversation_id)

3. practice_evaluations (append-only)
   - id uuid pk default gen_random_uuid()
   - attempt_id uuid not null references practice_attempts(id) on delete cascade
   - learner_message_id uuid not null references conversation_messages(id) on delete cascade
   - score numeric(5,2) not null check (score between 0 and 100)
   - verdict text not null check (verdict in ('pass','partial','fail'))
   - strengths text[] not null default '{}'
   - gaps text[] not null default '{}'
   - feedback text not null -- pedagógico y accionable
   - doubt_signals text[] not null default '{}' -- ej: ['no_se','ambiguo','inconsistente']
   - created_at timestamptz not null default now()
     Indexes: (attempt_id), (learner_message_id), (created_at)

B) RLS + POLICIES

Habilitar RLS en las 3 tablas.

SELECT:

- aprendiz: solo sus scenarios aplicables (org_id = current_org_id AND (local_id is null OR local_id=current_local_id))
  y solo attempts/evaluations donde learner_id = auth.uid()
- referente: attempts/evaluations de su local
- admin_org: por org
- superadmin: todo

INSERT:

- SOLO server flows (igual que lote 5):
  - practice_attempts insert
  - practice_evaluations insert
    NO UPDATE/DELETE policies.

C) SERVER-ONLY EVALUATOR (TypeScript)

1. Crear /lib/ai/practice-evaluator.ts
   Funciones:

- detectDoubtSignals(text: string): string[]
  Detecta al menos:
  - no_se (regex: /\b(no\s*s[eé]|no\s*lo\s*s[eé]|ni\s*idea)\b/i)
  - no_me_acuerdo
  - ambiguo (heurística simple: muy corto, evasivo)
    (mantener simple)

- evaluatePracticeAnswer(params):
  Inputs:
  - scenario (instructions + success_criteria)
  - learnerAnswer (texto)
  - chatContext (buildChatContext)
    Output:
  - score 0-100
  - verdict pass|partial|fail
  - strengths[], gaps[], feedback
  - doubt_signals[]

Implementación:

- Construir un prompt de evaluación que:
  - use success_criteria como checklist
  - sea estricto, profesional, pedagógico
  - NO invente información fuera del knowledge permitido
- Llamar a lib/ai/provider.ts (provider agnóstico) para obtener output
- Parsear output de forma robusta:
  - exigir JSON estricto en respuesta del modelo
  - si parse falla: error controlado (fail closed)

D) INTEGRACIÓN CON CHAT (server actions)

Modificar /app/learner/training/actions.ts agregando una acción nueva:

- startPracticeScenario(input?: { scenarioId?: string })
  - Selecciona un scenario para la unidad activa:
    - preferir unit_order = current_unit_order
    - difficulty 1 por defecto
    - local override si existe
  - Crea (si no existe) conversación context='practice' para esa unidad
  - Inserta mensaje system/bot inicial con instrucciones del role-play
  - Crea practice_attempt (in_progress)

- submitPracticeAnswer(input: { text: string })
  - Inserta mensaje learner en conversation_messages
  - Evalúa con evaluatePracticeAnswer(...)
  - Inserta practice_evaluation asociada al mensaje
  - Inserta mensaje bot con feedback pedagógico (y próxima consigna si aplica)
  - Si score >= umbral (ej 80) marcar attempt como completed:
    - NO UPDATE permitido por policy (append-only). En este lote, para cerrar intento:
      - usar ended_at y status COMPLETED solo si decidís habilitar UPDATE server-only.
      - Si preferís mantener append-only puro: crear practice_attempt_events (append-only) en vez de update.
        Elegí la opción más consistente con las policies que implementes.

IMPORTANTE:

- No avanzar unidad todavía.
- No modificar learner_training en este lote.

E) VIEWS (opcionales, si aportan valor mínimo)

- v_referente_practice_summary:
  - learner_id, attempt_id, scenario_title, score, verdict, created_at

F) ACTIVITY LOG
Actualizar docs/activity-log.md:

- nuevas tablas
- reglas append-only
- señales de duda
- cómo se evalúa (JSON estricto)
- env vars (ya existen del provider)

G) VERIFICACIÓN

- npx supabase db reset OK
- npm run lint + npm run build OK
- Manual:
  - startPracticeScenario crea attempt + mensaje inicial
  - submitPracticeAnswer persiste mensaje + evaluation + feedback bot
  - Sin API key: fail closed con error claro
  - RLS: aprendiz solo ve lo suyo; referente solo su local

AL FINAL

- Commit directo en main:
  "feat: lote 6 practice roleplay + semantic evaluation"
- Push origin main
- Reportar archivos tocados + comandos y resultados
