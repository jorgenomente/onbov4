# LOTE 7.1

## Contexto

Enviar emails transaccionales al aprendiz tras decisiones humanas (aprobado / requiere refuerzo) con Resend, registro append-only e idempotencia por decision_id.

## Prompt ejecutado

```txt
Actuá como Senior Backend Engineer + Product Engineer siguiendo AGENTS.md y docs/plan-mvp.md.

OBJETIVO (LOTE 7.1):
Enviar emails transaccionales al aprendiz cuando un referente/admin toma una decisión:
- Aprobado
- Requiere refuerzo
Con Resend, server-only, auditable, sin exponer secretos.
Registrar cada envío (append-only) y evitar duplicados por decisión.

SOURCES OF TRUTH:
- docs/product-master.md
- docs/plan-mvp.md
- AGENTS.md

REGLAS:
- Server-only para envío de email.
- Resend como proveedor (ya configurado).
- No usar service_role en cliente.
- Auditoría append-only del envío.
- Idempotencia: no enviar dos veces el mismo email para la misma decision_id.
- No tocar UI más de lo mínimo indispensable (si hace falta, solo feedback de “email enviado” en panel).
- Git: commit directo en main + push.
- Al final: npm run lint, npm run build. (db reset solo si hay migración)

TAREAS:

A) DB: EMAIL LOG (append-only)

Crear migración única nueva:

1) notification_emails (append-only)
   - id uuid pk default gen_random_uuid()
   - org_id uuid not null references organizations(id) on delete restrict
   - local_id uuid not null references locals(id) on delete restrict
   - learner_id uuid not null references profiles(user_id) on delete cascade
   - decision_id uuid not null references learner_review_decisions(id) on delete cascade
   - email_type text not null check (email_type in ('decision_approved','decision_needs_reinforcement'))
   - to_email text not null
   - subject text not null
   - provider text not null default 'resend'
   - provider_message_id text null
   - status text not null check (status in ('sent','failed'))
   - error text null
   - created_at timestamptz not null default now()

   Constraints:
   - unique(decision_id, email_type)  -- idempotencia

   Indexes: (learner_id), (decision_id), (created_at)

2) RLS:
   - SELECT:
     - aprendiz: solo sus emails
     - referente: emails de su local
     - admin_org: emails de su org
     - superadmin: todo
   - INSERT:
     - SOLO server flows
   - NO UPDATE/DELETE

B) SERVER EMAIL LAYER

1) Reusar lib/email/resend.ts (o crear si falta):
   - export resend client
   - export EMAIL_FROM
   - export APP_URL

2) Crear templates mínimos (server-only):
   - lib/email/templates/decisionApproved.ts
   - lib/email/templates/decisionNeedsReinforcement.ts

Cada template recibe:
- learnerName (fallback: "Hola")
- reason
- appUrl (APP_URL)
- (opcional) link directo a /learner/training

Mantener HTML simple, profesional, sin branding complejo.

C) SERVICE: sendDecisionEmail (server-only)

Crear: lib/email/sendDecisionEmail.ts

Inputs:
- decisionId
- decisionType ('approved'|'needs_reinforcement')

Flujo:
1) Leer decision + learner + local + org (vía SQL con supabase server client)
2) Resolver email del aprendiz:
   - desde auth.users (si accesible) o desde perfil si guardan email (si no existe, agregarlo a profiles en lote futuro)
   - Si no se puede obtener email, fail con error claro.
3) Determinar email_type + subject + template
4) Insertar en notification_emails:
   - status='failed' con error si falla envío
   - status='sent' con provider_message_id si ok
   Nota: para idempotencia:
   - antes de enviar, chequear si ya existe notification_emails con (decision_id, email_type); si existe, NO reenviar.

D) INTEGRACIÓN CON ACCIONES DE REVISIÓN

Modificar app/referente/review/actions.ts:

- Luego de crear learner_review_decisions (y transiciones):
  - llamar sendDecisionEmail(decisionId, decisionType)

Reglas:
- Si el envío falla:
  - NO revertir la decisión (la decisión es fuente de verdad)
  - Retornar respuesta al UI indicando: "Decisión guardada, email falló" + reason
- Si el envío ok:
  - Retornar: "Decisión guardada, email enviado"

E) (Opcional) UI feedback mínimo

En la pantalla de detalle:
- Mostrar un banner/toast simple:
  - enviado / falló
No crear pantallas nuevas.

F) PROMPTS ARCHIVE

Antes de terminar, crear:
- docs/prompts/LOTE-7.1.md
Pegando el prompt exacto ejecutado y contexto.

G) ACTIVITY LOG

Actualizar docs/activity-log.md:
- Lote 7.1 emails
- idempotencia por decision_id
- registro append-only de envíos
- comportamiento ante fallos

H) VERIFICACIÓN

- npm run lint
- npm run build
- Manual:
  - tomar decisión “approved” → se inserta notification_emails sent/failed
  - reintentar misma decisión (si UI permite) → NO duplica email por unique(decision_id,email_type)
  - si falta RESEND_API_KEY/EMAIL_FROM → fail claro, decisión sigue registrada

AL FINAL:
- Commit directo en main:
  "feat: lote 7.1 decision emails + audit log"
- Push origin main
- Reportar archivos tocados + comandos y resultados
```

Resultado esperado
Migración de notification_emails con RLS, servicio de envío con Resend, integración en decisiones, actividad registrada y verificación de lint/build.
