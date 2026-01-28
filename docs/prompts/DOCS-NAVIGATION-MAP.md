# DOCS-NAVIGATION-MAP

## Contexto

Crear un documento de mapa de navegacion y registrar su uso como fuente de verdad en AGENTS.

## Prompt ejecutado

```txt
que te parece este # ONBO — Navigation Map (MVP + Post-MVP operable)
Estado: ACTIVO
Fuente: flujo de producto + rutas existentes registradas en activity log. :contentReference[oaicite:0]{index=0} :contentReference[oaicite:1]{index=1}

Regla dura:
- Si una ruta existe en app, debe aparecer acá.
- Si una ruta NO aparece acá, se considera huérfana y debe eliminarse o integrarse al flujo.

---

## 0) Login → destino por rol (entrypoint)

### Público
- /login
  - Success → /auth/redirect (server-side)
  - /auth/redirect → redirige por rol (no UI)

### Destinos por rol (no “home” genérica)
- Aprendiz → /learner/training
- Referente → /referente/review
- Admin Org → /org/metrics
- Superadmin → /admin/organizations (PLAN / placeholder si no existe aún)

Credenciales demo/local para QA: :contentReference[oaicite:2]{index=2}

---

## 1) Aprendiz (tabs mínimos)

### Layout / Shell
- /learner/* (layout con tabs visibles)
  - Entrenamiento → /learner/training
  - Progreso → /learner/progress
  - Perfil → /learner/profile

### Flujos y rutas

#### A) Entrenamiento (producto central)
- /learner/training
  - Propósito: chat + avance guiado (aprender/practicar integrado)
  - CTA primario: “Continuar” (enviar mensaje al bot)
  - CTA secundario: “Iniciar práctica” (si hay scenario disponible)
  - CTA de evaluación final: “Iniciar evaluación final” (solo si gating ok)
  - Enlaces internos:
    - /learner/final-evaluation (cuando habilitado)
    - /learner/progress (ver estado general)
  - Estados relevantes que se reflejan acá:
    - en_revision → mostrar “en revisión” + historial de decisiones

#### B) Progreso (read-only)
- /learner/progress
  - Propósito: estado + avance + unidades
  - CTA primario: “Volver a Entrenamiento” → /learner/training
  - CTA secundario: “Repasar unidad” → /learner/review/[unitOrder] (solo completadas)

#### C) Repaso por unidad (read-only)
- /learner/review/[unitOrder]
  - Propósito: repasar contenido completado (sin afectar estado)
  - CTA primario: “Volver a Progreso” → /learner/progress
  - CTA secundario: “Volver a Entrenamiento” → /learner/training

#### D) Perfil (read-only)
- /learner/profile
  - Propósito: identidad + estado + historial decisiones
  - CTA primario: “Volver a Entrenamiento” → /learner/training

#### E) Evaluación final
- /learner/final-evaluation
  - Propósito: responder preguntas + role-play, avanzar sin refresh
  - CTA primario: “Enviar respuesta” (submit)
  - CTA de finalización: implícito al completar (pasa a en_revision)
  - Post-condición: estado en_revision visible + historial decisiones

---

## 2) Referente (operación del local)

### A) Cola + métricas accionables
- /referente/review
  - Propósito: cola de revisión + métricas 30d (top gaps / riesgo)
  - CTA primario: “Abrir revisión” → /referente/review/[learnerId]
  - CTA secundario: “Ver alertas” → /referente/alerts

### B) Detalle de aprendiz (review + evidencia + decisiones)
- /referente/review/[learnerId]
  - Propósito: revisar evidencia (summary / wrong answers / doubt signals), decidir
  - CTA primario:
    - “Aprobar” (acción humana, server-only)
    - “Pedir refuerzo” (acción humana, server-only)
  - CTA secundario:
    - “Registrar validación v2 (interna)” (server-only; no cambia estados)
  - Enlaces:
    - “Volver a cola” → /referente/review
    - “Ir a alertas” → /referente/alerts

### C) Bandeja interna de alertas (read-only)
- /referente/alerts
  - Propósito: eventos recientes (alert_events) con links contextuales
  - CTA primario: “Abrir aprendiz” → /referente/review/[learnerId]
  - CTA secundario: “Volver” → /referente/review

---

## 3) Admin Org (operación org-level)

### A) Métricas org (read-only) + acciones sugeridas
- /org/metrics
  - Propósito: visión org-level 30d (tabs + drilldowns)
  - CTA primario: “Ir a configuración del bot” → /org/bot-config (si esa es la ruta vigente) / o /org/config/bot (si esa es la vigente)
  - CTA secundario:
    - “Cobertura de knowledge” → /org/config/knowledge-coverage
    - “Configurar programa activo por local” → (ver sección C)

> Nota: hoy hay dos rutas mencionadas en el proyecto para config bot:
> - /org/config/bot (config evaluación final + programa activo por local)
> - /org/bot-config (scenarios práctica create/disable)
> El layout de Admin debe exponer ambas si efectivamente existen.

### B) Configuración del bot (evaluación final / guardrails)
- /org/config/bot
  - Propósito: leer config vigente + historial; crear nueva config (append-only)
  - CTA primario: “Crear nueva configuración” (RPC insert-only)
  - CTA secundario: “Volver a métricas” → /org/metrics
  - Guardrail: bloquea creación si hay intento in_progress

### C) Programa activo por local (si está integrado en /org/config/bot o ruta dedicada)
- (Si es ruta dedicada, documentarla explícitamente acá cuando exista)
  - Propósito: set_local_active_program + auditoría
  - CTA primario: “Asignar programa”
  - CTA secundario: “Volver a config” / “Volver a métricas”

### D) Knowledge coverage + wizard
- /org/config/knowledge-coverage
  - Propósito: ver gaps deterministas; crear+mapear knowledge; desactivar knowledge
  - CTA primario: “Agregar knowledge” (wizard)
  - CTA secundario:
    - “Desactivar knowledge” (confirmación)
    - “Volver a métricas” → /org/metrics

### E) Bot config (escenarios de práctica)
- /org/bot-config
  - Propósito: operar practice_scenarios (create/disable) usando views/RPCs
  - CTA primario: “Crear escenario”
  - CTA secundario: “Desactivar escenario”
  - Enlaces: “Volver a métricas” → /org/metrics

---

## 4) Superadmin (plataforma)

### Estado actual
- /admin/organizations
  - PLAN / placeholder si aún no existe en UI.
  - Cuando exista: entrypoint para orgs → locals → users.

Regla:
- Si no está implementado, NO agregar enlaces en UI (evitar “pantallas fantasma”).

---

## 5) Navegación visible por layout (contrato UX)

### /learner/layout.tsx
- Tabs: Entrenamiento (/learner/training), Progreso (/learner/progress), Perfil (/learner/profile)
- Nada más.

### /referente/layout.tsx
- Links mínimos:
  - Revisión (/referente/review)
  - Alertas (/referente/alerts)

### /org/layout.tsx
- Links mínimos:
  - Métricas (/org/metrics)
  - Config evaluación final (/org/config/bot)
  - Knowledge coverage (/org/config/knowledge-coverage)
  - Bot config (escenarios práctica) (/org/bot-config)

### /admin/layout.tsx
- Solo cuando exista UI real:
  - Organizaciones (/admin/organizations)

---

## 6) Checklist anti-páginas huérfanas (rápido)

- [ ] Cada ruta en app/ aparece en este documento.
- [ ] Cada ruta listada acá tiene al menos 1 entrypoint desde su layout o una CTA desde otra pantalla.
- [ ] No hay links “sueltos” a URLs no listadas.
- [ ] Los CTAs primarios empujan el flujo (no navegación turística).

---
 si estas de acuerdo crea un doc como estos que nos sirva de referencia y dile al AGENTS.md que lo lea para este nuevo objetivo
```

## Resultado esperado

Documento de navegacion y actualizacion de AGENTS para incluirlo como fuente de verdad.
