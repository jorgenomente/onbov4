# Roadmap — ONBO Producto Final (Post‑MVP)

**Propósito**
Este documento transforma el Documento Maestro en un roadmap operativo hacia producto final. Incluye:

- estado actual (lo ya construido)
- brechas por módulo
- fases con entregables y checkpoints
- reglas de tracking para que siempre sepamos “dónde estamos” y “qué sigue”

---

## 1) Estado actual vs Documento Maestro

### 1.1 Cubierto hoy (implementado)

- Multi‑tenant: organizations, locals, profiles + roles.
- RLS base por rol/org/local y helpers (`current_*`).
- Entrenamiento conversacional base:
  - conversación persistida (conversations, conversation_messages)
  - view `v_learner_active_conversation`
  - UI `/learner/training` con chat
- Motor de conocimiento “grounded”:
  - knowledge_items + unit_knowledge_map
  - context builder server‑only
- Práctica integrada (role‑play):
  - practice_scenarios, attempts, evaluations
  - UI dentro de `/learner/training`
- Evaluación final:
  - config, attempts, questions, answers, evaluations
  - gating + cooldown + bloqueo
  - estado `en_revision`
  - UI `/learner/final-evaluation`
- Panel mínimo de revisión:
  - `v_review_queue` + evidencia básica
  - decisiones humanas (approve / refuerzo)
  - historial de decisiones visible en referente/learner
- Seeds demo + tooling de resets
- Emails de decisión (si Resend configurado)

### 1.2 Parcial o faltante (brechas)

- **UX Aprendiz**: faltan tabs reales **Progreso** y **Perfil**.
- **Repaso**: navegación y modo repaso de unidades anteriores no implementado.
- **Consultas sobre unidades futuras**: registrar preguntas futuras + handling explícito.
- **Chat de consulta para Admin/Referente**: no existe.
- **Admin Org UI**: gestión usuarios, locales, programas, métricas agregadas.
- **Superadmin UI**: auditoría global y soporte.
- **Gestión de contenido**:
  - CRUD de training_programs, training_units, knowledge_items, mappings.
- **Métricas avanzadas**:
  - dashboards comparativos, cohortes, por local, por unidad.
- **Evidencia completa de evaluación final**:
  - views de wrong answers / summary por unidad.
- **Emails**: invitación y otros transaccionales (no solo decisión).
- **Auditoría ampliada**:
  - audit events explícitos (tabla dedicada) + UI de auditoría.
- **Hardening**:
  - monitoreo, alertas, gestión de errores, fallbacks operativos.

---

## 2) Principios para post‑MVP (no negociables)

- DB‑first + RLS‑first.
- Estados explícitos, auditables y append‑only.
- Cada pantalla = contrato de datos (view/RPC) previamente definido.
- Mobile‑first real.
- Nada crítico en el cliente.
- Toda decisión humana queda registrada y visible para el learner.

---

## 3) Sistema de tracking (para “saber dónde estamos”)

### 3.1 Checkpoints

Usamos checkpoints cortos y acumulativos.

- **Archivo vivo**: `docs/roadmap-product-final.md` (este documento)
- **Mapa de avance**: `docs/audit-checkpoint1.md` (se mantiene)
- **Activity log**: `docs/activity-log.md`

### 3.2 Regla de actualización

Cada vez que se cierra un checkpoint:

- actualizar **este roadmap** (sección “Checkpoint actual”)
- actualizar `docs/audit-checkpoint1.md`
- registrar entrada en `docs/activity-log.md`

### 3.3 Estructura de checkpoint

Cada checkpoint tiene:

- objetivo
- entregables verificables
- checklist de cierre
- “qué sigue” explícito

---

## 4) Roadmap Post‑MVP (fases)

### Fase 0 — Estabilización MVP+ (hardening)

**Objetivo**: eliminar fricción operativa y asegurar consistencia del flujo end‑to‑end.

**Entregables**

- Smoke tests oficiales (login, training, práctica, evaluación, revisión).
- Mensajes de error consistentes + retry en LLM.
- Correcciones de RLS y helpers (ya en curso).
- Página de loading/skeleton en rutas críticas.

**Cierre**

- `npm run build` + `npm run lint` OK.
- `supabase db reset` OK.
- Flujo completo sin refresh manual.

---

### Fase 1 — UX Aprendiz completo (CERRADA)

**Objetivo**: cumplir navegación Aprendiz definida en el Maestro.

**Entregables**

- `/learner/progress` con:
  - progreso por unidad
  - estado actual
  - acceso a repaso
- `/learner/profile`:
  - datos básicos
  - estado actual
  - historial de decisiones
- Modo repaso:
  - lectura + mini prácticas
  - sin impacto en progreso
- Registro de consultas futuras (tabla + UI mínima)

**Cierre**

- Tabs completas visibles (Entrenamiento/Progreso/Perfil).
- Repaso funcional y auditado.

---

### Fase 2 — Evidencias completas para Referente/Admin

**Objetivo**: dar decisiones con evidencias más profundas.

**Entregables**

- Views:
  - `v_learner_evaluation_summary`
  - `v_learner_wrong_answers`
  - `v_learner_doubt_signals`
- UI `/referente/review/[id]` con:
  - resumen por unidad
  - respuestas fallidas + razones
  - señales de duda agregadas

**Cierre**

- Referente toma decisión con evidencia completa.

---

### Fase 3 — Admin Org (gestión y métricas mínimas)

**Objetivo**: habilitar operación real por organización.

**Entregables**

- UI `/org/learners` + filtros por local.
- UI `/org/locals` y `/org/users` (gestión básica).
- Métricas agregadas (mínimo):
  - tasa de aprobación por local
  - tiempos promedio de finalización
  - brechas por unidad

**Cierre**

- Admin puede operar sin soporte interno.

---

### Fase 4 — Gestión de contenido (programas y conocimiento)

**Objetivo**: permitir construir/editar contenido desde la app.

**Entregables**

- CRUD de training_programs / training_units.
- CRUD de knowledge_items + mapping a unidades.
- Validaciones de consistencia (orden, vacíos, unidades huérfanas).

**Cierre**

- Contenido editable sin tocar DB manualmente.

---

### Fase 5 — Observabilidad y auditoría avanzada

**Objetivo**: trazabilidad total y soporte operativo.

**Entregables**

- Tabla `audit_events` + triggers para eventos críticos.
- UI superadmin de auditoría.
- Exportes básicos (CSV/JSON) por organización.

**Cierre**

- Auditoría y soporte sin acceso directo a DB.

---

### Fase 6 — Producto “final” (polish + escalamiento)

**Objetivo**: experiencia estable, presentable y escalable.

**Entregables**

- UX/UI consistente (microcopys + feedback).
- Estrategia de onboarding organizacional.
- SLA de disponibilidad y backoff integrado.
- Hardening de emails y reintentos.

**Cierre**

- Producto listo para múltiples clientes con operación estable.

---

## 5) Checkpoint actual

**Checkpoint actual:** CP‑1 (Evidencias completas para Referente/Admin)

**En curso**

- Definición de views de evidencia avanzada.
- UI de revisión con evidencia profunda.

**Siguiente inmediato**

- Iniciar Fase 2 según roadmap.

---

## 6) Qué sigue (próximo lote post‑MVP)

**LOTE Post‑MVP 2 — Evidencias completas para Referente/Admin**

- Views de evidencia avanzada (summary, wrong answers, dudas).
- UI de revisión ampliada.

**Checklist de cierre**

- Referente toma decisión con evidencia completa.
- `npm run build` + `npm run lint` OK.

---

## 7) Regla final

Este roadmap se actualiza **cada vez que se cierre un checkpoint**.
Si no se actualiza, el trabajo se considera incompleto.
