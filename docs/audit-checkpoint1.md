# Audit Checkpoint 1

**Fecha:** 2026-01-26
**Fuente:** `docs/product-master.md`, `docs/plan-mvp.md`, `docs/activity-log.md`, `docs/db/dictionary.md`, `docs/db/schema.public.sql`, `docs/smoke-credentials.md`

## Resumen del producto

ONBO es una plataforma B2B de entrenamiento conversacional para camareros. El aprendizaje se realiza en un flujo de chat con unidades secuenciales, práctica (role-play) integrada, y evaluación final con recomendación del bot y decisión humana. Todo es DB-first, RLS-first y con historial inmutable.

## Estado actual (lo que ya existe)

### Base de datos + RLS

- Multi-tenant completo: organizations → locals → profiles con roles (`superadmin`, `admin_org`, `referente`, `aprendiz`).
- Modelo de entrenamiento: programas, unidades, asignación del aprendiz, estado explícito y transiciones append-only.
- Conversación y auditoría: conversaciones, mensajes, evaluaciones y vistas de lectura.
- Knowledge grounding: knowledge_items + unit_knowledge_map con acceso controlado.
- Práctica: escenarios, intentos, evaluaciones y eventos append-only.
- Evaluación final: configs, intentos, preguntas, respuestas, evaluaciones y recomendaciones del bot.
- Panel de revisión: decisiones humanas auditables y cola de revisión.
- Emails de decisión: notificaciones via Resend con registro append-only.
- Seeds demo reproducibles para `supabase db reset`.

### App (UI + server actions)

- Auth mínima: login, logout, redirects por rol, protección de rutas.
- Aprendiz: `/learner/training` con chat + CTA de práctica.
- Aprendiz: `/learner/final-evaluation` con flujo de evaluación final y estados.
- Referente/Admin: `/referente/review` para revisión y decisión.

### Documentación viva

- Documento maestro del producto y plan MVP activos.
- Activity log actualizado con todos los lotes y fixes.
- Snapshots regenerables del schema y diccionario DB.
- Credenciales demo para smoke tests.

## Progreso vs plan MVP

> Nota: la numeración de “lotes” en activity-log refleja la ejecución real, aunque la planilla original asigna la Evaluación Final a Lote 6. Esto debe considerarse al interpretar el avance.

- Lote 0 (setup + guardrails): hecho.
- Lote 1 (tenancy + roles + RLS): hecho.
- Lote 2 (modelo entrenamiento + vistas base): hecho.
- Lote 3 (conversación + auditoría): hecho.
- Lote 4 (knowledge grounding): hecho.
- Lote 5 (práctica + evaluación semántica): hecho.
- Lote 6/8 (evaluación final): hecho.
- Lote 7 (panel de revisión + decisiones): hecho.
- Lote 7.1 (emails de decisión): hecho.
- Lote 8.5 (auth UI mínima): hecho.
- Lote 8 (hardening + smoke tests + stabilization según plan): pendiente.

## Mapa de continuidad (plan vivo)

Este mapa es el checkpoint que se actualiza al avanzar. Cada ítem debe moverse a **Hecho** cuando se complete.

### 1) Hardening MVP (Hecho — 2026-02-04)

- Smoke tests end-to-end (login, training chat, práctica, evaluación final, panel referente) ejecutados con usuarios E2E separados.
- `npx supabase db reset` + `npm run lint` + `npm run build` + `npm run e2e` OK.
- Hardening del avance de práctica para no exceder unidad final y progreso consistente.

### 2) QA sistemático (pendiente)

- Checklist repetible de QA en `docs/`.
- Validar seeds demo y credenciales en reset limpio.
- Revisar rutas protegidas y redirecciones por rol.
- **Hecho (2026-01-26):** Smoke E2E con Playwright (login, evaluación final sin refresh, cola de revisión).
- **Hecho (2026-01-26):** Provider LLM `mock` para QA local sin dependencias externas.

### 3) UX de producción (pendiente)

- Estados UI consistentes (loading/empty/error/success) en todas las pantallas.
- Accesibilidad básica: foco, labels, targets táctiles.
- Feedback inmediato en envíos y errores.

### 4) Observabilidad mínima (pendiente)

- Logging server-only claro para errores de gating, evaluación y envíos.
- Mensajes de error consistentes y trazables.

### 5) Calidad de datos y seguridad (pendiente)

- Verificar que todas las tablas y views tengan RLS activa.
- Revisar políticas críticas de INSERT y SELECT para evitar bypass.
- Confirmar que no haya writes sensibles desde el cliente.

### 6) Cierre MVP (pendiente)

### 7) Post‑MVP 1 — UX Aprendiz completa (Hecho — 2026-01-27)

- Tabs Aprendiz (Entrenamiento/Progreso/Perfil) completadas.
- /learner/progress + repaso lectura-only completado.
- /learner/profile read-only completado.
- Logging de consultas a unidades futuras (DB + RLS + RPC) listo.
- E2E/Smoke certificados para A, B, C y D.

- Actualizar `docs/activity-log.md` con cierre de lote de hardening.
- Documentar cómo correr el smoke test en 1 script o guía.
- Dejar el producto listo para demo con datos reales controlados.

### 8) Post‑MVP 2 — Evidencias completas para Referente/Admin (Hecho — 2026-01-27)

- Views de evidencia avanzada (summary, wrong answers, dudas) en DB.
- UI /referente/review/[id] con bloques de evidencia (lectura).
- Seed cross-tenant para validar aislamiento por local.
- Playwright: referente review headers verificados.

## Cómo usar este checkpoint

- Este archivo es un **mapa vivo** del avance.
- Cuando se completa un ítem, se marca como **Hecho** y se agrega el detalle mínimo (fecha y referencia).
- Cada avance importante debe reflejarse también en `docs/activity-log.md`.
