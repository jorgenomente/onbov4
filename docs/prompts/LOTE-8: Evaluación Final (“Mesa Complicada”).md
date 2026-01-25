# LOTE 8

## Contexto

Implementar Evaluación Final (“Mesa Complicada”) con intentos, cooldown, evaluación semántica, recomendación del bot y aprobación humana final.

## Prompt ejecutado

```txt
Actuá como Lead Software Architect + Senior Backend Engineer siguiendo AGENTS.md y docs/plan-mvp.md.

OBJETIVO (LOTE 8):
Implementar la Evaluación Final (“Mesa Complicada”) con:
- habilitación automática al completar el recorrido
- estructura configurable (Q&A + role-play)
- evaluación semántica + diagnóstico por unidad
- intentos, cooldown y bloqueo
- recomendación del bot + aprobación humana final
Todo auditable, server-only y sin romper historial.

SOURCES OF TRUTH:
- docs/product-master.md (Sección 14 — Evaluación Final)
- docs/plan-mvp.md
- AGENTS.md

REGLAS:
- DB-first + RLS-first.
- SQL nativo para schema.
- Nada de select *.
- APPEND-ONLY para intentos y respuestas.
- Server-only para evaluación con LLM.
- El bot sugiere resultado; el humano decide.
- No emails en este lote.
- Git: commit directo en main + push.
- Al final: npx supabase db reset, npm run lint, npm run build.

TAREAS:

A) CONFIGURACIÓN DE EVALUACIÓN (DB)

1) final_evaluation_configs
   - id uuid pk default gen_random_uuid()
   - program_id uuid not null references training_programs(id) on delete cascade
   - total_questions int not null
   - roleplay_ratio numeric(3,2) not null check (roleplay_ratio between 0 and 1)
   - min_global_score numeric(5,2) not null
   - must_pass_units int[] not null default '{}'   -- unit_order críticos
   - questions_per_unit int not null default 1
   - max_attempts int not null default 3
   - cooldown_hours int not null default 12
   - created_at timestamptz not null default now()

2) RLS:
   - SELECT:
     - admin_org/superadmin
     - referente (solo lectura)
   - INSERT/UPDATE:
     - server-only (configuración interna)

B) INTENTOS DE EVALUACIÓN (APPEND-ONLY)

1) final_evaluation_attempts
   - id uuid pk default gen_random_uuid()
   - learner_id uuid not null references profiles(user_id) on delete cascade
   - program_id uuid not null references training_programs(id) on delete restrict
   - attempt_number int not null
   - started_at timestamptz not null default now()
   - ended_at timestamptz null
   - status text not null check (status in ('in_progress','completed','blocked'))
   - global_score numeric(5,2) null
   - bot_recommendation text null check (bot_recommendation in ('approved','not_approved'))
   - created_at timestamptz not null default now()

   Constraints:
   - unique(learner_id, attempt_number)

2) RLS:
   - SELECT:
     - aprendiz: solo los suyos
     - referente/admin_org: por alcance
   - INSERT:
     - server-only
   - NO UPDATE/DELETE

C) PREGUNTAS Y RESPUESTAS (APPEND-ONLY)

1) final_evaluation_questions
   - id uuid pk default gen_random_uuid()
   - attempt_id uuid not null references final_evaluation_attempts(id) on delete cascade
   - unit_order int not null
   - question_type text not null check (question_type in ('direct','roleplay'))
   - prompt text not null
   - created_at timestamptz not null default now()

2) final_evaluation_answers
   - id uuid pk default gen_random_uuid()
   - question_id uuid not null references final_evaluation_questions(id) on delete cascade
   - learner_answer text not null
   - created_at timestamptz not null default now()

3) final_evaluation_evaluations
   - id uuid pk default gen_random_uuid()
   - answer_id uuid not null references final_evaluation_answers(id) on delete cascade
   - unit_order int not null
   - score numeric(5,2) not null
   - verdict text not null check (verdict in ('pass','partial','fail'))
   - strengths text[] not null default '{}'
   - gaps text[] not null default '{}'
   - feedback text not null
   - doubt_signals text[] not null default '{}'
   - created_at timestamptz not null default now()

Indexes donde aplique para lectura por attempt.

D) SERVER-ONLY ENGINE (TypeScript)

1) /lib/ai/final-evaluation-engine.ts

Funciones:
- canStartFinalEvaluation(learnerId): { allowed, reason }
  - verifica:
    - programa completo
    - intentos usados < max_attempts
    - cooldown cumplido
    - no bloqueado

- startFinalEvaluation(learnerId)
  - crea attempt (attempt_number incremental)
  - genera set de preguntas:
    - cobertura estratificada por unidad
    - mezcla direct/roleplay según config
    - dificultad básica (sin adaptativo complejo aún)

- submitFinalAnswer(input)
  - guarda answer
  - evalúa con LLM (reusar practice evaluator)
  - guarda evaluation

- finalizeAttempt(attemptId)
  - calcula global_score
  - aplica reglas:
    - min_global_score
    - must_pass_units
  - set bot_recommendation
  - marca ended_at
  - si excede max_attempts → status 'blocked'

E) INTEGRACIÓN CON UI (MÍNIMA)

- Botón “Iniciar evaluación final” visible SOLO si canStartFinalEvaluation.allowed
- Vista dedicada de evaluación (no persistente como pestaña):
  - preguntas secuenciales
  - sin navegación libre
- Al finalizar:
  - mostrar estado “En revisión”
  - NO mostrar aprobado/no aprobado al aprendiz

F) ESTADOS Y TRANSICIONES

- Al iniciar evaluación:
  - learner_trainings.status → 'en_practica' o 'en_revision' (según tu modelo)
- Al finalizar:
  - learner_trainings.status → 'en_revision'
- Decisión final humana sigue siendo en Lote 7 (panel)

Registrar transiciones en learner_state_transitions.

G) PROMPTS ARCHIVE

Crear:
- docs/prompts/LOTE-8.md
Pegando el prompt exacto ejecutado.

H) ACTIVITY LOG

Actualizar docs/activity-log.md:
- Evaluación Final
- intentos + cooldown
- recomendación del bot vs decisión humana
- diagnóstico por unidad

I) VERIFICACIÓN

- npx supabase db reset OK
- npm run lint + npm run build OK
- Manual:
  - no se puede iniciar sin completar entrenamiento
  - respeta cooldown
  - intentos no se borran
  - evaluaciones se guardan
  - aprendiz queda “En revisión”

AL FINAL:
- Commit directo en main:
  "feat: lote 8 final evaluation engine"
- Push origin main
- Reportar archivos tocados + comandos y resultados
```

Resultado esperado
Migración con configuración, intentos, preguntas y evaluaciones; engine server-only; UI mínima para iniciar y responder; activity log actualizado; verificación completa.
