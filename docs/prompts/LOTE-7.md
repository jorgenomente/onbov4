# LOTE 7

## Contexto

Implementar el Panel de Revisión para Referente/Admin con decisiones humanas auditables y vistas de evidencia.

## Prompt ejecutado

```txt
Actuá como Lead Software Architect + Senior Backend Engineer siguiendo AGENTS.md y docs/plan-mvp.md.

OBJETIVO (LOTE 7):
Implementar el Panel de Revisión para Referente/Admin:
- listar aprendices en revisión
- ver evidencias (errores, dudas, prácticas)
- permitir decisión humana (aprobar / pedir refuerzo)
Todo server-only, auditable y sin emails.

SOURCES OF TRUTH:
- docs/product-master.md
- docs/plan-mvp.md
- AGENTS.md

REGLAS:
- DB-first + RLS-first.
- SQL nativo únicamente para schema.
- Nada de select *.
- Auditoría completa: toda decisión humana queda registrada.
- Server-only para acciones críticas.
- No incluir emails en este lote.
- UI funcional, mínima y mobile-first (sin diseño complejo).
- Git: commit directo en main + push.
- Al final: npx supabase db reset (si aplica), npm run lint, npm run build.

TAREAS:

A) MODELO DE DECISIONES (DB)

1) learner_review_decisions (append-only)
   - id uuid pk default gen_random_uuid()
   - learner_id uuid not null references profiles(user_id) on delete cascade
   - reviewer_id uuid not null references profiles(user_id) on delete restrict
   - decision text not null check (decision in ('approved','needs_reinforcement'))
   - reason text not null
   - created_at timestamptz not null default now()
   Indexes: (learner_id), (reviewer_id), (created_at)

2) RLS:
   - SELECT:
     - aprendiz: solo puede ver su última decisión (si existe)
     - referente: decisiones de aprendices de su local
     - admin_org: decisiones de su org
     - superadmin: todo
   - INSERT:
     - SOLO server flows (no UPDATE/DELETE)

B) VIEWS (contratos de lectura)

1) v_review_queue
Para referente/admin:
- learner_id
- full_name
- local_id
- status
- progress_percent
- last_activity_at
- flags:
  - has_doubt_signals (bool)
  - has_failed_practice (bool)

Reglas:
- incluir solo aprendices cuyo status sea:
  - 'en_revision'
  - 'requiere_revision' (si existe en tu enum; si no, usar el que corresponda)
- flags se calculan vía EXISTS sobre:
  - practice_evaluations (verdict='fail' OR doubt_signals not empty)
  - bot_message_evaluations (si aplica)

2) v_learner_evidence
Para un learner_id dado:
- resumen de prácticas:
  - scenario_title
  - score
  - verdict
  - feedback
  - created_at
- señales de duda agregadas
- últimos mensajes relevantes del chat (ej últimos 5)

Mantener simple y legible (puede ser vista plana).

C) SERVER ACTIONS (decisiones humanas)

Agregar en /app/referente/review/actions.ts (server-only):

1) approveLearner(input: { learnerId: string; reason: string })
   - Validar rol (referente/admin_org/superadmin)
   - INSERT en learner_review_decisions
   - Transición de estado del aprendiz:
     - NO UPDATE directo del estado si tu modelo es append-only.
     - Registrar transición en learner_state_transitions:
       - from_status -> 'aprobado'
       - to_status = 'aprobado'
       - reason
       - actor_user_id = reviewer
   - (Si existe learner_trainings.status como campo mutable y tenés policy server-only,
      actualizarlo; si no, dejar solo transición registrada.)

2) requestReinforcement(input: { learnerId: string; reason: string })
   - Misma lógica:
     - INSERT en learner_review_decisions
     - INSERT en learner_state_transitions (to_status='en_riesgo' o 'en_practica')

D) UI MINIMAL (Panel)

Rutas sugeridas:
- /app/referente/review/page.tsx        → lista (v_review_queue)
- /app/referente/review/[learnerId]     → detalle + evidencias (v_learner_evidence)

Requisitos:
- Mobile-first
- Estados: loading / empty / error
- Acciones claras:
  - “Aprobar”
  - “Pedir refuerzo”
- Textarea obligatorio para reason
- Feedback visual al guardar

NO:
- No charts
- No filtros avanzados
- No bulk actions

E) ACTIVITY LOG

Actualizar docs/activity-log.md:
- Lote 7: panel revisión
- Decisión humana como autoridad final
- Auditoría append-only
- Emails excluidos (van a Lote 7.1)

F) VERIFICACIÓN

- RLS:
  - referente ve solo su local
  - admin_org ve su org
  - aprendiz NO ve panel
- Decisiones crean registros (no overwrite)
- Estados se reflejan correctamente
- npm run lint + npm run build OK

AL FINAL:
- Commit directo en main:
  "feat: lote 7 review panel + human decisions"
- Push origin main
- Reportar archivos tocados + comandos y resultados
 Hay una funcion nueva en AGENTS.md que consiste en crear un nuevo archivo en /docs/prompts con los prompts que yo te doy, no te olvides de hacer eso
```

Resultado esperado
Migración con decisiones y vistas, server actions, UI mínima, activity log y verificación completa.
