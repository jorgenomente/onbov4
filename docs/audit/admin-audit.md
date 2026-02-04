# Auditoría Admin Org — Configuración de cursos y contenido

Fecha: 2026-01-30

## Alcance

Auditoría de capacidades reales del Admin Org en UI (rutas `/org/*`), con foco en:

- Configuración de cursos (programas/unidades) y contenido para el aprendiz.
- Flujo exacto para habilitar más contenido a un local.
- Botones, acciones y efectos reales.
- Preparación para E2E.

Fuentes: UI y server actions en `app/org/*` + modelos/flows en `lib/ai/context-builder.ts`.

---

## Mapa de navegación Admin Org

Layout principal (nav fijo): `app/org/layout.tsx`

- /org/metrics — Métricas org (read-only)
- /org/config/bot — Config evaluación final (insert-only)
- /org/config/knowledge-coverage — Knowledge coverage + add/disable knowledge
- /org/bot-config — Config bot local + escenarios de práctica (create/disable)
- /org/config/locals-program — Programa activo por local (set)
- /auth/logout — Cerrar sesión

Acceso: `requireUserAndRole(['admin_org','superadmin'])` en todas las rutas `org`.

---

## Capacidades por pantalla (UI + botones)

### 1) /org/metrics — Métricas org (read-only)

Archivo: `app/org/metrics/page.tsx`

Tabs:

- Resumen: KPIs + “Acciones sugeridas” (con CTA y links secundarios)
- Gaps: lista de gaps -> detalle
- Cobertura: tabla por local/unidad -> detalle
- Riesgo: learners en riesgo -> link a review de referente

Botones/links:

- “Config evaluación final” -> /org/config/bot
- “Cobertura de knowledge” -> /org/config/knowledge-coverage
- Tabs (Resumen/Gaps/Cobertura/Riesgo)
- CTA por acción sugerida -> `cta_href` o `/org/metrics/gaps/[gapKey]`

Data source (views):

- v_org_top_gaps_30d
- v_org_learner_risk_30d
- v_org_unit_coverage_30d
- v_org_recommended_actions_playbooks_with_outcomes_30d

Notas:

- No hay acciones mutables: todo es lectura.

---

### 2) /org/metrics/gaps/[gapKey] — Detalle de gap

Archivo: `app/org/metrics/gaps/[unitOrder]/page.tsx`

Botones/links:

- “Volver a métricas” -> /org/metrics
- “Cobertura de knowledge” -> /org/config/knowledge-coverage

Data source:

- v_org_gap_locals_30d (filtrado por `gap_key`)

---

### 3) /org/metrics/coverage/[programId]/[unitOrder] — Cobertura por unidad

Archivo: `app/org/metrics/coverage/[programId]/[unitOrder]/page.tsx`

Botones/links:

- “Volver a métricas” -> /org/metrics
- “Cobertura de knowledge” -> /org/config/knowledge-coverage

Data source:

- v_org_unit_coverage_30d
- v_org_unit_knowledge_active (solo knowledge activo)

---

### 4) /org/config/bot — Configuración evaluación final (insert-only)

Archivo: `app/org/config/bot/page.tsx`

Qué permite:

- Ver configuración vigente por programa.
- Crear nueva configuración (versionada, append-only).
- Ver historial (últimas 10 configs) por programa.
- Warning de unidades sin knowledge mapping.

Botones/acciones:

- “Volver a métricas” -> /org/metrics
- Selector de programa + botón “Ver” (GET)
- Form “Nueva configuración” -> acción `createFinalEvalConfigAction`
  - RPC: `create_final_evaluation_config`
  - Validaciones: total_questions, roleplay %, min score, questions_per_unit, max_attempts, cooldown_hours, must_pass_units

Dependencias:

- `training_programs`, `training_units`
- views `v_org_program_final_eval_config_current`, `v_org_program_final_eval_config_history`
- view `v_org_program_unit_knowledge_coverage`

Notas:

- No modifica intentos anteriores.
- Si falta mapping de knowledge, se marca como warning.

---

### 5) /org/config/locals-program — Programa activo por local

Archivo: `app/org/config/locals-program/page.tsx`

Qué permite:

- Ver programa activo actual por local.
- Cambiar programa activo por local (org-level o local-specific).
- Ver historial de cambios (últimos 20).

Botones/acciones:

- “Asignar programa” (anchor a tabla)
- “Volver a métricas” -> /org/metrics
- Por local: `details` “Cambiar” + botón “Guardar”
  - acción `setLocalActiveProgramAction`
  - RPC: `set_local_active_program`
  - Param opcional: reason

Reglas relevantes en UI:

- “Cambios afectan nuevos learners (no modifica entrenamientos en curso).”
- Si hay intento en progreso -> error `conflict` (bloquea)

Dependencias:

- view `v_org_local_active_programs`
- tabla `locals`, `training_programs`
- tabla `local_active_program_change_events`

---

### 6) /org/config/knowledge-coverage — Knowledge por unidad

Archivo: `app/org/config/knowledge-coverage/page.tsx`

Qué permite:

- Ver gaps de knowledge por programa/unidad.
- Crear knowledge item y mapearlo a unidad (append-only).
- Desactivar knowledge (no borra).
- Ver detalle de knowledge por unidad (org/local).

Botones/acciones:

- “Volver a métricas” -> /org/metrics
- Selector de programa + botón “Ver” (GET)
- Form “Agregar knowledge” -> `addKnowledgeToUnitAction`
  - RPC: `create_and_map_knowledge_item`
  - Campos: unit_id, scope (org/local), local_id (solo si scope=local), title, content, reason
- Botón “Desactivar” por item -> `disableKnowledgeItemAction`
  - RPC: `disable_knowledge_item`
  - Confirm + prompt de reason

Dependencias:

- views `v_org_program_knowledge_gaps_summary`, `v_org_program_unit_knowledge_coverage`, `v_org_unit_knowledge_list`
- tablas `training_programs`, `training_units`, `locals`

Notas:

- Si una unidad no tiene knowledge asociado, el bot falla al construir contexto.
- No hay editor visual; `content` es texto plano. (La columna `content_type` existe en DB pero no se expone en UI.)

---

### 7) /org/bot-config — Config bot + escenarios de práctica

Archivo: `app/org/bot-config/page.tsx`

Qué permite:

- Seleccionar local y ver resumen del programa activo.
- Ver gaps de knowledge/práctica por unidad.
- Crear escenarios de práctica (append-only).
- Deshabilitar escenarios de práctica.

Botones/acciones:

- “Volver a métricas” -> /org/metrics
- Selector de local + botón “Ver” (GET)
- “Crear escenario” (modal) -> `createPracticeScenarioAction`
  - RPC: `create_practice_scenario`
  - Campos: unit_order, title, instructions, difficulty (1-5), success_criteria (líneas)
- “Deshabilitar” (modal) -> `disablePracticeScenarioAction`
  - RPC: `disable_practice_scenario`
  - Campo: reason (opcional)

Dependencias:

- views `v_local_bot_config_summary`, `v_local_bot_config_units`, `v_local_bot_config_gaps`
- tabla `practice_scenarios`

Notas importantes:

- En `createPracticeScenarioAction`, si el rol es `admin_org`, se fuerza `local_id = null`.
  - Resultado: admin_org solo puede crear escenarios **org-level**.
  - Escenarios **local-specific** requieren `superadmin`.

---

## Flujo exacto: habilitar más contenido del chat para un local

Objetivo: que un aprendiz de un local vea más contenido en el chat (knowledge + práctica).

1. Verificar que el programa y sus unidades existen
   - No hay UI de CRUD de `training_programs` / `training_units` en Admin.
   - Si faltan, deben existir por seed/migración (DB-first).

2. Asignar programa activo al local
   - Ruta: /org/config/locals-program
   - Acción: “Cambiar” -> seleccionar programa -> “Guardar”
   - RPC: `set_local_active_program`
   - Impacto: solo afecta nuevos learners (no cambia entrenamientos ya en curso).

3. Asegurar knowledge por unidad (mínimo: unidad actual del aprendiz)
   - Ruta: /org/config/knowledge-coverage
   - Seleccionar programa -> “Agregar knowledge a unidad”.
   - Campos clave:
     - Scope = org (compartido) o local (específico)
     - Si scope=local, seleccionar local_id.
   - RPC: `create_and_map_knowledge_item`
   - Nota crítica: si la unidad actual no tiene knowledge mapeado, el chat falla.

4. (Opcional) Agregar escenarios de práctica
   - Ruta: /org/bot-config
   - Seleccionar local -> “Crear escenario”
   - RPC: `create_practice_scenario`
   - Admin Org crea escenarios org-level (aplican a todos los locales). Para escenarios específicos por local, usar rol superadmin.

5. (Opcional) Configurar evaluación final por programa
   - Ruta: /org/config/bot
   - Seleccionar programa -> completar form -> “Guardar nueva configuración”
   - RPC: `create_final_evaluation_config`

6. Validación rápida
   - /org/config/knowledge-coverage: confirmar que unidad tiene knowledge (badge OK).
   - /org/bot-config: confirmar escenarios activos por unidad.
   - /org/metrics/coverage: ver cobertura y actividad.

Notas operativas:

- Si querés que un aprendiz existente vea el nuevo contenido, necesitás:
  - que su unidad actual tenga knowledge mapeado; y/o
  - iniciar un nuevo learner o reiniciar entrenamiento (si el flujo de negocio lo permite).

---

## Limitaciones actuales (relevantes para E2E)

- No hay UI para crear/editar `training_programs` ni `training_units`.
- No hay soporte de “contenido visual” (imágenes/archivos) en UI; solo texto (`knowledge_items.content`).
- Admin Org no puede crear escenarios de práctica local-specific (solo org-level).

---

## Checklist E2E (Admin Org)

1. Login admin_org (ver `docs/smoke-credentials.md`).
2. /org/config/locals-program
   - Confirmar local con programa activo.
3. /org/config/knowledge-coverage
   - Seleccionar programa.
   - Agregar knowledge para unidad actual del learner.
4. /org/bot-config
   - Seleccionar local.
   - Crear al menos 1 escenario de práctica para la unidad objetivo.
5. /org/config/bot
   - Ver/crear config de evaluación final (si el test la necesita).
6. /org/metrics
   - Validar que las vistas cargan (sin errores) y que hay links de drilldown.
