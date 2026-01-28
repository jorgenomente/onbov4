# ONBO — Navigation Map (MVP + Post-MVP operable)

Estado: ACTIVO

Regla dura:

- Si una ruta existe en app, debe aparecer aca.
- Si una ruta NO aparece aca, se considera huerfana y debe eliminarse o integrarse al flujo.

---

## 0) Login -> destino por rol (entrypoint)

### Publico

- /login
  - Success -> /auth/redirect (server-side)
  - /auth/redirect -> redirige por rol (no UI)

### Destinos por rol (no “home” generica)

- Aprendiz -> /learner/training
- Referente -> /referente/review
- Admin Org -> /org/metrics
- Superadmin -> /admin/organizations (PLAN / placeholder si no existe aun)

Credenciales demo/local para QA: docs/smoke-credentials.md

---

## 1) Aprendiz (tabs minimos)

### Layout / Shell

- /learner/\* (layout con tabs visibles)
  - Entrenamiento -> /learner/training
  - Progreso -> /learner/progress
  - Perfil -> /learner/profile

### Flujos y rutas

#### A) Entrenamiento (producto central)

- /learner/training
  - Proposito: chat + avance guiado (aprender/practicar integrado)
  - CTA primario: “Continuar” (enviar mensaje al bot)
  - CTA secundario: “Iniciar practica” (si hay scenario disponible)
  - CTA de evaluacion final: “Iniciar evaluacion final” (solo si gating ok)
  - Enlaces internos:
    - /learner/final-evaluation (cuando habilitado)
    - /learner/progress (ver estado general)
  - Estados relevantes que se reflejan aca:
    - en_revision -> mostrar “en revision” + historial de decisiones

#### B) Progreso (read-only)

- /learner/progress
  - Proposito: estado + avance + unidades
  - CTA primario: “Volver a Entrenamiento” -> /learner/training
  - CTA secundario: “Repasar unidad” -> /learner/review/[unitOrder] (solo completadas)

#### C) Repaso por unidad (read-only)

- /learner/review/[unitOrder]
  - Proposito: repasar contenido completado (sin afectar estado)
  - CTA primario: “Volver a Progreso” -> /learner/progress
  - CTA secundario: “Volver a Entrenamiento” -> /learner/training

#### D) Perfil (read-only)

- /learner/profile
  - Proposito: identidad + estado + historial decisiones
  - CTA primario: “Volver a Entrenamiento” -> /learner/training

#### E) Evaluacion final

- /learner/final-evaluation
  - Proposito: responder preguntas + role-play, avanzar sin refresh
  - CTA primario: “Enviar respuesta” (submit)
  - CTA de finalizacion: implicito al completar (pasa a en_revision)
  - Post-condicion: estado en_revision visible + historial decisiones

---

## 2) Referente (operacion del local)

### A) Cola + metricas accionables

- /referente/review
  - Proposito: cola de revision + metricas 30d (top gaps / riesgo)
  - CTA primario: “Abrir revision” -> /referente/review/[learnerId]
  - CTA secundario: “Ver alertas” -> /referente/alerts

### B) Detalle de aprendiz (review + evidencia + decisiones)

- /referente/review/[learnerId]
  - Proposito: revisar evidencia (summary / wrong answers / doubt signals), decidir
  - CTA primario:
    - “Aprobar” (accion humana, server-only)
    - “Pedir refuerzo” (accion humana, server-only)
  - CTA secundario:
    - “Registrar validacion v2 (interna)” (server-only; no cambia estados)
  - Enlaces:
    - “Volver a cola” -> /referente/review
    - “Ir a alertas” -> /referente/alerts

### C) Bandeja interna de alertas (read-only)

- /referente/alerts
  - Proposito: eventos recientes (alert_events) con links contextuales
  - CTA primario: “Abrir aprendiz” -> /referente/review/[learnerId]
  - CTA secundario: “Volver” -> /referente/review

---

## 3) Admin Org (operacion org-level)

### A) Metricas org (read-only) + acciones sugeridas

- /org/metrics
  - Proposito: vision org-level 30d (tabs + drilldowns)
  - CTA primario: “Ir a configuracion del bot” -> /org/bot-config (si esa es la ruta vigente) / o /org/config/bot (si esa es la vigente)
  - CTA secundario:
    - “Cobertura de knowledge” -> /org/config/knowledge-coverage
    - “Configurar programa activo por local” -> (ver seccion C)

> Nota: hoy hay dos rutas mencionadas en el proyecto para config bot:
>
> - /org/config/bot (config evaluacion final + programa activo por local)
> - /org/bot-config (scenarios practica create/disable)
>   El layout de Admin debe exponer ambas si efectivamente existen.

### B) Configuracion del bot (evaluacion final / guardrails)

- /org/config/bot
  - Proposito: leer config vigente + historial; crear nueva config (append-only)
  - CTA primario: “Crear nueva configuracion” (RPC insert-only)
  - CTA secundario: “Volver a metricas” -> /org/metrics
  - Guardrail: bloquea creacion si hay intento in_progress

### C) Programa activo por local (si esta integrado en /org/config/bot o ruta dedicada)

- (Si es ruta dedicada, documentarla explicitamente aca cuando exista)
  - Proposito: set_local_active_program + auditoria
  - CTA primario: “Asignar programa”
  - CTA secundario: “Volver a config” / “Volver a metricas”

### D) Knowledge coverage + wizard

- /org/config/knowledge-coverage
  - Proposito: ver gaps deterministas; crear+mapear knowledge; desactivar knowledge
  - CTA primario: “Agregar knowledge” (wizard)
  - CTA secundario:
    - “Desactivar knowledge” (confirmacion)
    - “Volver a metricas” -> /org/metrics

### E) Bot config (escenarios de practica)

- /org/bot-config
  - Proposito: operar practice_scenarios (create/disable) usando views/RPCs
  - CTA primario: “Crear escenario”
  - CTA secundario: “Desactivar escenario”
  - Enlaces: “Volver a metricas” -> /org/metrics

---

## 4) Superadmin (plataforma)

### Estado actual

- /admin/organizations
  - PLAN / placeholder si aun no existe en UI.
  - Cuando exista: entrypoint para orgs -> locals -> users.

Regla:

- Si no esta implementado, NO agregar enlaces en UI (evitar “pantallas fantasma”).

---

## 5) Navegacion visible por layout (contrato UX)

### /learner/layout.tsx

- Tabs: Entrenamiento (/learner/training), Progreso (/learner/progress), Perfil (/learner/profile)
- Nada mas.

### /referente/layout.tsx

- Links minimos:
  - Revision (/referente/review)
  - Alertas (/referente/alerts)

### /org/layout.tsx

- Links minimos:
  - Metricas (/org/metrics)
  - Config evaluacion final (/org/config/bot)
  - Knowledge coverage (/org/config/knowledge-coverage)
  - Bot config (escenarios practica) (/org/bot-config)

### /admin/layout.tsx

- Solo cuando exista UI real:
  - Organizaciones (/admin/organizations)

---

## 6) Checklist anti-paginas huerfanas (rapido)

- [ ] Cada ruta en app/ aparece en este documento.
- [ ] Cada ruta listada aca tiene al menos 1 entrypoint desde su layout o una CTA desde otra pantalla.
- [ ] No hay links “sueltos” a URLs no listadas.
- [ ] Los CTAs primarios empujan el flujo (no navegacion turistica).
