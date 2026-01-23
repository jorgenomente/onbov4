# plan-mvp.md — ONBO Conversational (MVP Plan)

**Estado:** ACTIVO  
**Objetivo:** Construir un MVP B2B estable, auditable y vendible para entrenamiento conversacional de camareros.  
**Principios:** DB-first, RLS-first, historial inmutable, UX mínima, entregables pequeños, build/lint frecuente.

---

## 0) Cómo usar este plan

### 0.1 Regla de ejecución

Este plan se ejecuta por **lotes** (phases). Cada lote:

1. define entregables concretos
2. incorpora verificaciones obligatorias
3. no rompe compatibilidad hacia atrás
4. se cierra con checklist

### 0.2 Regla anti-deriva (scope control)

Si algo no está en este plan o en `docs/product-master.md`, no se implementa en MVP.

### 0.3 Regla de estabilidad

Antes de pasar de lote:

- `npm run build` ✅
- `npm run lint` ✅
- migraciones aplican en limpio (`supabase db reset`) ✅
- RLS validada manualmente con 2+ roles ✅

---

## 1) Definition of MVP (qué tiene que existir para vender)

### 1.1 MVP incluye

- Multi-tenant: Organización → Local → Usuario (roles)
- Experiencia Aprendiz: Entrenamiento (chat) + Progreso + Perfil
- Secuencia de Unidades (una activa, futuras bloqueadas, repaso de pasadas)
- Conversación persistida y auditable
- Práctica integrada (role-play) dentro del flujo
- Evaluación Final: habilitación, intentos, cooldown, bloqueo, estado `en_revisión`
- Recomendación del bot + razones (human decides)
- Panel mínimo para Referente/Admin: revisión de aprendiz + evidencias + decisión
- Emails transaccionales: invitación y notificación de decisión final
- Activity log (`docs/activity-log.md`)

### 1.2 MVP NO incluye

- Dashboards avanzados / BI
- Múltiples verticales
- Automatizaciones complejas
- Knowledge ingestion sofisticado
- Reentrenamiento, fine-tuning, etc.

---

## 2) Lotes del MVP (orden recomendado)

> Nota: los lotes están diseñados para evitar “big bang”.  
> Cada uno agrega valor verificable sin bloquear el siguiente.

---

# LOTE 0 — Setup + Guardrails de repo

## Objetivo

Dejar el repo “listo para producir” con build/lint, convenciones y entorno Supabase.

## Entregables

- Next.js 16 + TS + Tailwind funcionando
- ESLint + Prettier + Husky (pre-commit) configurados
- `AGENTS.md` en raíz
- `docs/product-master.md` y `docs/plan-mvp.md`
- `docs/activity-log.md` creado con primera entrada
- Supabase CLI configurado + `supabase init`
- Script/verificación: `npm run build`, `npm run lint`

## Verificación obligatoria

- `npm run build` pasa en limpio
- `npm run lint` sin errores
- `supabase start` / `supabase db reset` funciona en local

## Cierre (DoD)

- Repo ejecuta `npm run dev` sin warnings críticos
- Convenciones listas para DB-first (migrations folder)

---

# LOTE 1 — Identidad, Tenancy y Roles (DB-first + RLS-first)

## Objetivo

Crear base multi-tenant segura: org/local/usuarios/roles, derivado desde `auth.uid()`.

## Entregables (DB)

- Tablas core:
  - `organizations`
  - `locals`
  - `profiles` (1:1 auth.users) con `org_id`, `local_id`, `role`
- Enum/roles:
  - `superadmin`, `admin_org`, `referente`, `aprendiz`
- Helpers SQL (recomendado):
  - `current_profile()` / `current_role()` / `current_org_id()` / `current_local_id()`
- RLS estricta en TODAS las tablas
- Seeds mínimos (solo si aplica para dev): organization/local de ejemplo

## Entregables (App)

- Auth wiring con Supabase SSR
- Middleware básico: rutas protegidas requieren sesión
- Página de “Acceso” (login) mínima (si ya existe, se valida)

## Verificación obligatoria

- Con 2 usuarios en 2 orgs distintas:
  - no hay lectura cruzada (RLS)
- Con referente:
  - solo ve su local
- `npm run build` + `npm run lint`

## Cierre (DoD)

- Tenancy estable y reusable para todo lo siguiente

---

# LOTE 2 — Modelo de Entrenamiento: Programa, Unidades, Estado del Aprendiz

## Objetivo

Persistir secuencia de entrenamiento y estado explícito del aprendiz.

## Entregables (DB)

- Tablas:
  - `training_programs` (por org y opcional por local)
  - `training_units` (orden, título, objetivos, metadata)
  - `local_active_program` (programa activo por local)
  - `learner_training` (asignación aprendiz ↔ programa, unidad_actual, progreso)
- Estados del aprendiz (enum recomendado):
  - `en_entrenamiento`, `en_practica`, `en_riesgo`, `en_revision`, `aprobado`
- Reglas:
  - solo 1 unidad activa por aprendiz
  - futuras bloqueadas (por lógica de lectura + UI)
- Auditoría:
  - `state_transitions` (append-only) o eventos equivalentes

## Entregables (Views)

- `v_learner_home` (qué ve el aprendiz en Entrenamiento)
- `v_learner_progress` (Progreso + unidades + estado)
- `v_referente_learners` (lista aprendices del local)

## Verificación obligatoria

- RLS: aprendiz solo su data
- referente ve aprendices de su local
- admin_org ve organización completa
- `supabase db reset` aplica migraciones en limpio
- build/lint ok

## Cierre (DoD)

- La app ya puede mostrar “Unidad activa” y progreso básico sin chat aún

---

# LOTE 3 — Conversación y Auditoría (Chat como motor)

## Objetivo

Persistir conversaciones, turnos, y trazabilidad completa.

## Entregables (DB)

- Tablas:
  - `conversations` (por aprendiz, por unidad/contexto)
  - `conversation_messages` (append-only: role, content, timestamp)
  - `bot_evaluations` (scoring + razones + tags por mensaje o por bloque)
- Regla: nada se borra

## Entregables (Views/RPC)

- Views de lectura:
  - `v_conversation_thread` (mensajes ordenados)
- RPC / Server Action para escribir mensajes:
  - valida pertenencia org/local via RLS + checks
  - inserta mensaje usuario
  - inserta respuesta bot (si el flujo es server-driven)

## Entregables (App)

- Pantalla Aprendiz: `/app/learner/training`
  - chat básico
  - inicia con contexto de unidad activa
  - estados UI: loading/empty/error
- Persistencia real (refresh no pierde conversación)

## Verificación obligatoria

- Mensajes no se pueden editar/borrar
- RLS: nadie lee mensajes de otra org/local
- build/lint ok

## Cierre (DoD)

- Chat funcional y auditable en torno a “unidad activa”

---

# LOTE 4 — Motor de Conocimiento “Cargado” (sin conocimiento externo)

## Objetivo

Garantizar que el bot responde solo con conocimiento cargado y contexto permitido.

## Entregables (DB)

- Tablas:
  - `knowledge_items` (por org/local, type, content)
  - `unit_knowledge_map` (qué knowledge aplica a cada unidad)
- Reglas:
  - unidad activa puede usar: knowledge de esa unidad + pasadas
  - consultas puntuales no cambian estado/unidad

## Entregables (Server)

- “Context builder” server-only:
  - arma prompt/contexto desde DB (knowledge + unidad + estado)
- Guardrail:
  - prohibir llamadas a proveedor sin “context package” válido

## Verificación obligatoria

- Bot no responde si no hay knowledge cargado (mensaje controlado)
- build/lint ok

## Cierre (DoD)

- Bot consistentemente “grounded” en datos propios

---

# LOTE 5 — Práctica integrada (role-play) + evaluación semántica

## Objetivo

Introducir prácticas dentro del flujo conversacional y evaluar respuestas abiertas.

## Entregables (DB)

- Tablas:
  - `practice_scenarios` (por unidad, dificultad, instrucciones)
  - `practice_attempts` (append-only)
  - `practice_evaluations` (score + razones + tags)
- Señales de duda:
  - flaggear “no sé / no me acuerdo / evasivas” como evento

## Entregables (App)

- Dentro de `/learner/training`:
  - el bot dispara role-play según unidad
  - UI muestra “modo práctica” (sin pestaña nueva)

## Verificación obligatoria

- Un aprendiz puede repetir práctica sin romper progreso
- Registro completo de intentos
- build/lint ok

## Cierre (DoD)

- Práctica real existe y genera evidencias para referentes

---

# LOTE 6 — Evaluación Final (Mesa Complicada) + Estado `en_revision`

## Objetivo

Implementar evaluación final formal: configuración, intentos, cooldown, bloqueo y evidencias.

## Entregables (DB)

- Tablas:
  - `final_evaluations` (config por programa/local)
  - `final_evaluation_attempts` (attempt #, started_at, ended_at, status)
  - `final_evaluation_questions` (pregunta directa / role-play, unidad, dificultad)
  - `final_evaluation_answers` (respuesta aprendiz)
  - `final_evaluation_scoring` (score + razones + must-pass flags)
- Reglas:
  - habilitación: unidades + prácticas completas
  - intentos: max 3
  - cooldown: 12h
  - bloqueo al fallar 3
  - abandono: no respondidas = incorrectas
- Estado:
  - al finalizar intento completo: aprendiz pasa a `en_revision`
- Auditoría:
  - registrar recomendación del bot y razones (no editable)

## Entregables (App)

- Botón “Iniciar evaluación final” aparece solo si corresponde
- Flujo de evaluación:
  - presenta N preguntas según config
  - guarda respuestas
  - genera recomendación bot + razones
- UI Aprendiz post-evaluación:
  - estado visible: “En revisión”
  - mensaje claro: pendiente decisión humana

## Verificación obligatoria

- Intentos y cooldown respetados (tests manuales)
- RLS: aprendiz no ve evidencia de otros
- build/lint ok

## Cierre (DoD)

- Evaluación final completa y auditable existe end-to-end

---

# LOTE 7 — Panel Referente/Admin: Revisión + Decisión Humana

## Objetivo

Dar a referente/admin un flujo mínimo para tomar decisión con evidencias.

## Entregables (Views)

- `v_reviewer_queue` (aprendices `en_revision`)
- `v_learner_evaluation_summary` (score, brechas, must-pass)
- `v_learner_wrong_answers` (pregunta, respuesta, evaluación bot, razones)
- `v_learner_doubt_signals` (no sé / inconsistencias)

## Entregables (RPC / Server Actions)

- `approve_learner(learner_id, reason)`:
  - valida rol + scope (local/org)
  - cambia estado a `aprobado`
  - registra evento
- `reject_learner(learner_id, reason)`:
  - cambia estado (ej: `en_riesgo` o vuelve a entrenamiento según regla definida)
  - registra evento

## Entregables (App)

- Rutas:
  - Referente: `/app/referente/learners`
  - Detalle: `/app/referente/learners/[id]`
  - Admin Org: `/app/org/learners` (si aplica en MVP)
- UI:
  - evidencias claras
  - botones aprobar/desaprobar con motivo
  - estados loading/empty/error
- Emails (mínimo):
  - notificar al aprendiz decisión final (aprobado / requiere refuerzo)

## Verificación obligatoria

- Referente solo opera su local
- Admin org opera toda la org
- Estado cambia y queda auditado
- build/lint ok

## Cierre (DoD)

- Humano puede decidir con evidencia sin fricción

---

# LOTE 8 — Hardening + Smoke Tests + Stabilization

## Objetivo

Reducir errores, asegurar regresiones mínimas y preparar demo real.

## Entregables

- Smoke tests manuales documentados:
  - login
  - aprendiz entrenamiento
  - práctica
  - evaluación final
  - revisión referente
- Script/guía de verificación RLS (queries)
- Revisión de performance básica:
  - índices en FK + campos de filtro
- Cleanup:
  - eliminar dead code
  - mejorar mensajes de error
- `docs/activity-log.md` con cierre de MVP

## Verificación obligatoria

- `npm run build` + `npm run lint` siempre OK
- `supabase db reset` OK
- RLS revisada en tablas y views

## Cierre (DoD)

- MVP demostrable y estable para primer cliente

---

## 3) Checklist global de calidad (siempre activo)

### 3.1 Base de datos

- No hay tablas sin RLS
- No hay `select *`
- Writes críticos pasan por DB/RPC/Server Actions
- Historial append-only para conversación, intentos, decisiones

### 3.2 Frontend

- Mobile-first real
- Estados UI completos
- Nada sensible en cliente
- Accesos controlados por rol

### 3.3 Operación

- Activity-log actualizado por cambios relevantes
- Emails transaccionales mínimos funcionan
- No hay features fuera de scope

---

## 4) Notas de implementación (anti-error)

### 4.1 Entregables pequeños

Cada ticket debe producir **una sola cosa** (migración / pantalla / rpc / doc).
Evitar “mega PRs”.

### 4.2 Contratos por pantalla

Antes de una pantalla, definir su view/RPC.
Una pantalla = un contrato.

### 4.3 Frecuencia de build/lint

Correr `npm run build` y `npm run lint`:

- al cerrar cada ticket
- al cerrar cada lote
- cuando se toca auth/middleware/RLS

---

## 5) Primeros tickets sugeridos (para arrancar ya)

1. LOTE 0: Setup + AGENTS + docs base + build/lint
2. LOTE 1: org/local/profiles/roles + helpers + RLS
3. LOTE 2: training_programs + units + learner_training + estados + views base
