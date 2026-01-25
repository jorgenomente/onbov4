## 2026-01-25 — Gemini CLI scripts

**Tipo:** docs  
**Alcance:** backend

**Resumen**
Se agregan scripts CLI para listar modelos Gemini y ejecutar un smoke test usando la API key configurada.

**Uso**

- Env vars:
  - LLM_PROVIDER=gemini
  - GEMINI_API_KEY=... (requerida)
  - GEMINI_MODEL=gemini-2.5-flash (opcional)
- Listar modelos: npm run gemini:list-models
- Smoke test: npm run gemini:smoke

**Nota**
La disponibilidad de modelos depende de lo que devuelve la API con tu key.

## 2026-01-25 — Gemini provider support (LLM)

**Tipo:** feature  
**Alcance:** backend

**Resumen**
Se agrega soporte Gemini en la capa provider-agnostic sin romper OpenAI, con fail-closed y configuracion por entorno.

**Impacto**

- Permite seleccionar LLM via LLM_PROVIDER=gemini
- Modelo default: gemini-2.5-flash (si GEMINI_MODEL no está definido)
- No habilita grounding web ni herramientas externas

**Env vars**

- LLM_PROVIDER=gemini
- GEMINI_API_KEY
- GEMINI_MODEL (opcional, default gemini-2.5-flash)

**Config**

- .env.local (dev)
- Vercel Environment Variables (prod)

## 2026-01-25 — Lote 5 chat e2e + provider agnostic

**Tipo:** feature  
**Alcance:** backend | db | rls

**Resumen**
Se agrega capa LLM provider-agnostic, server action para mensajes del aprendiz, y policies de insert server-only para conversaciones/mensajes.

**Impacto**

- Chat end-to-end con persistencia append-only
- Fail-closed si no hay provider configurado
- Contexto estrictamente grounded en conocimiento permitido

**Env vars**

- OPENAI_API_KEY
- OPENAI_MODEL

**Checklist**

- Sin provider configurado: falla con error claro
- Con provider: persiste mensaje aprendiz + bot

## 2026-01-23 — Lote 4 knowledge grounding + context builder base

**Tipo:** feature  
**Alcance:** db | rls

**Resumen**
Se crean tablas de conocimiento y mapeo por unidad con RLS estricta, y un context builder server-only que garantiza grounding en conocimiento permitido.

**Impacto**

- El bot queda limitado a conocimiento cargado por unidad activa + pasadas
- Se separa claramente DB (grounding) de proveedor IA
- Writes quedan reservados para flujos server-only

**Checklist RLS (manual)**

- Aprendiz no puede acceder a knowledge de otra org/local
- knowledge con local_id NULL es visible en su org

## 2026-01-23 — Lote 3 conversacion y auditoria base

**Tipo:** feature  
**Alcance:** db | rls

**Resumen**
Se crean conversaciones, mensajes y evaluaciones base con reglas append-only, RLS estricta y vistas de lectura para aprendiz y referente/admin.

**Impacto**

- Habilita persistencia y auditoria completa del chat
- Define contratos de lectura para UI
- Escrituras reservadas a flujos server-only (RPC/Server Actions)

**Checklist RLS (manual)**

- Aprendiz: ve solo sus conversaciones y mensajes
- Referente: ve conversaciones de su local
- Admin Org: ve conversaciones de locales de su organizacion
- Superadmin: ve todo
- No se permiten UPDATE/DELETE en conversaciones ni mensajes

## 2026-01-23 — Lote 2 modelo de entrenamiento + vistas base

**Tipo:** feature  
**Alcance:** db | rls

**Resumen**
Se agrega el modelo de entrenamiento (programas, unidades, asignacion por aprendiz), estado explicito y transiciones append-only, con RLS estricta y vistas base para aprendiz y referente/admin.

**Impacto**

- Habilita progreso y estado del aprendiz con trazabilidad
- Define contratos de lectura para pantallas base
- Mantiene writes restringidos para flujos controlados

**Checklist RLS (manual)**

- Aprendiz: puede leer v_learner_training_home y v_learner_progress (solo propio)
- Referente: puede leer v_referente_learners para su local
- Admin Org: puede leer aprendices de su organizacion
- Superadmin: puede leer todo

## 2026-01-23 — Lote 1 base multi-tenant + roles

**Tipo:** feature  
**Alcance:** db | rls

**Resumen**
Se crea la base multi-tenant con organizations, locals y profiles, enum de roles y helpers para derivar contexto desde auth.uid(), con RLS estricta por org/local/rol.

**Impacto**

- Habilita multi-tenancy segura y roles base para el MVP
- Define helpers de contexto para políticas y futuras queries
- No incluye flujos de creación desde cliente

**Checklist RLS (manual)**

- Usuario autenticado con profile: puede leer solo su profile
- No puede leer profiles ajenos
- Puede leer su local; admin_org ve locales de su org; superadmin ve todo

## 2026-01-23 — Resend setup base

**Tipo:** feature  
**Alcance:** backend

**Resumen**
Se agrega inicializacion server-only de Resend y helper para envio de emails transaccionales.

**Impacto**

- Habilita integrar invitaciones y notificaciones via Resend
- Centraliza validacion de variables de entorno necesarias
- No cambia el flujo de UI ni permisos
