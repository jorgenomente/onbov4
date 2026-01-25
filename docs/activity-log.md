## 2026-01-25 — Lote 8 evaluación final

**Tipo:** feature  
**Alcance:** db | rls | backend | ux

**Resumen**
Se implementa la Evaluación Final con configuración, intentos, preguntas/respuestas y evaluaciones semánticas, incluyendo cooldown, bloqueo y recomendación del bot.

**Impacto**

- Evaluación final auditable y append-only para respuestas
- Recomendación del bot sin reemplazar decisión humana
- Estado del aprendiz pasa a en_revision al finalizar

**Checklist**

- Respeta cooldown y max_attempts
- Intenta solo si entrenamiento completo
- Registro de evaluaciones por unidad

## 2026-01-25 — Lote 7.1 emails de decisión

**Tipo:** feature  
**Alcance:** db | backend

**Resumen**
Se agregan emails transaccionales de decisiones humanas con Resend, registro append-only e idempotencia por decision_id.

**Impacto**

- El aprendiz recibe notificación de aprobado o refuerzo
- Se registran envíos con estado sent/failed
- Fail-closed si faltan claves o email del aprendiz

**Checklist**

- No duplica emails por decision_id
- Decisión no se revierte si email falla

## 2026-01-25 — Lote 7 panel de revisión + decisiones humanas

**Tipo:** feature  
**Alcance:** db | rls | backend | ux

**Resumen**
Se agrega el panel de revisión para referentes/admin, decisiones humanas append-only y vistas de evidencia, con acciones server-only y sin emails.

**Impacto**

- Decisiones humanas quedan auditadas y trazables
- Referentes/Admin pueden revisar evidencias y decidir
- Emails se difieren al Lote 7.1

**Checklist**

- Referente ve solo su local, admin_org su org
- Aprendiz no accede al panel
- Decisiones no se sobrescriben (append-only)

## 2026-01-25 — Lote 6 práctica + evaluación semántica

**Tipo:** feature  
**Alcance:** db | rls | backend

**Resumen**
Se agrega práctica integrada con escenarios, intentos y evaluaciones append-only, más un evaluador server-only con señales de duda y salida JSON estricta.

**Impacto**

- Role-play persistente dentro del flujo de chat
- Evaluación semántica grounded en knowledge permitido
- Cierre de intento vía eventos append-only (sin updates)

**Checklist**

- Sin API key: falla con error claro (fail-closed)
- startPracticeScenario crea conversation + attempt
- submitPracticeAnswer persiste mensaje + evaluación + feedback

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

## 2026-01-25 — Fix build por RESEND_FROM missing

**Tipo:** fix  
**Alcance:** backend

**Resumen**
Se evita leer variables de entorno de Resend en import-time para que el build no falle si faltan envs; ahora se leen solo al enviar email.

**Impacto**

- Build de Vercel no se rompe al recolectar páginas que importan acciones de email
- Las envs siguen siendo obligatorias en runtime al enviar emails
- No cambia el flujo de aprobación ni la lógica de envío

## 2026-01-25 — Lote 8.5 Auth UI mínima

**Tipo:** feature  
**Alcance:** backend | frontend | ux

**Resumen**
Se agrega login básico, logout, protección de rutas por sesión y redirección por rol usando Supabase SSR. Se definen rutas públicas/privadas, middleware de sesión y layouts con enforcement de rol.

**Impacto**

- Acceso por email+password para usuarios existentes de Supabase Auth
- Redirección segura por rol tras login y bloqueo de rutas no permitidas
- Logout server-side y rutas protegidas por sesión

**Cómo testear (manual)**

- /login y credenciales válidas → redirige por rol
- /learner/\* sin sesión → /login?next=...
- /login con sesión → /auth/redirect

## 2026-01-25 — Migración middleware → proxy

**Tipo:** refactor  
**Alcance:** frontend

**Resumen**
Se migra el archivo de middleware a proxy para alinearse con la convención de Next.js 16 y eliminar el warning de deprecación.

**Impacto**

- Mantiene la misma protección de rutas por sesión
- Elimina el warning de build sobre middleware
- No cambia flujos de login/logout

## 2026-01-25 — Fix env Supabase en cliente

**Tipo:** fix  
**Alcance:** frontend

**Resumen**
Se corrige el acceso a variables de entorno públicas en el cliente para evitar undefined en runtime y permitir login.

**Impacto**

- Login deja de romper por NEXT_PUBLIC_SUPABASE_URL undefined
- Mantiene uso de variables públicas en build-time
- Sin cambios en flujos de auth

## 2026-01-25 — Chat mínimo en entrenamiento

**Tipo:** feature  
**Alcance:** frontend

**Resumen**
Se conecta la pantalla /learner/training al server action existente para enviar mensajes y mostrar el hilo actual con grounding fail-closed.

**Impacto**

- Aprendiz ve el chat y puede enviar mensajes
- Se refresca el hilo tras cada envío
- Errores de grounding se muestran con mensaje user-friendly

## 2026-01-25 — CTA práctica en entrenamiento

**Tipo:** feature  
**Alcance:** frontend | ux

**Resumen**
Se agrega CTA para iniciar práctica desde /learner/training y se conecta el envío de respuestas con el motor de práctica existente.

**Impacto**

- El aprendiz puede iniciar práctica y ver el prompt en el chat
- Las respuestas se evalúan vía server action y se refresca el hilo
- Errores del evaluador se muestran con mensaje amigable

## 2026-01-25 — Seed práctica demo/local

**Tipo:** fix  
**Alcance:** db

**Resumen**
Se agrega un seed mínimo de practice_scenarios para programas activos del entorno demo/local, evitando errores de escenario inexistente.

**Impacto**

- Iniciar práctica ya no falla por falta de escenarios
- Se mantiene lógica RLS y append-only existente
- No cambia esquema ni flujos de evaluación

## 2026-01-25 — Seed demo completo (Auth + datos)

**Tipo:** feature  
**Alcance:** db | backend

**Resumen**
Se agrega seed demo/local completo para reset reproducible: org/local/programa, unidades, knowledge, práctica, evaluación final, usuarios Auth y perfiles.

**Impacto**

- `npx supabase db reset` deja el entorno listo para smoke tests
- Usuarios demo pueden loguearse con password común
- Chat/práctica/evaluación tienen datos base cargados

## 2026-01-25 — Parser robusto evaluacion practica

**Tipo:** fix  
**Alcance:** backend | ux

**Resumen**
Se endurece el parseo del output del evaluador de practica para aceptar JSON con code fences o texto extra y fallar en modo seguro sin romper la UI.

**Impacto**

- Evita 500 cuando el LLM devuelve markdown o contenido extra
- Devuelve feedback fallback y registra logs truncados para depuracion
- No cambia esquema ni RLS
