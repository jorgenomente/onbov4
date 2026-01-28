# Post-MVP 3 / Configuracion del bot — Sub-lote A0

## Seccion 1: Inventario real

### A) Programas / estructura

**Tablas reales**

- `training_programs`
  - Campos: `id`, `org_id`, `local_id` (nullable), `name`, `is_active`, `created_at`.
  - Scope: org-level (`local_id` NULL) o local-specific (`local_id` = local).
  - `is_active` existe pero no hay uso en app ni policies de UPDATE/INSERT para clientes.
- `training_units`
  - Campos: `id`, `program_id`, `unit_order`, `title`, `objectives`, `created_at`.
  - Constraints: `unit_order >= 1`, `unique(program_id, unit_order)`.
- `local_active_programs`
  - Campos: `local_id` (PK), `program_id`, `created_at`.
  - Define 1 programa activo por local via PK en `local_id`.
- `learner_trainings`
  - Asignacion aprendiz ↔ programa/local con estado y unidad actual.
  - Campos: `learner_id`, `local_id`, `program_id`, `status`, `current_unit_order`, `progress_percent`, `started_at`, `updated_at`.

**Enums relevantes**

- `learner_status`: `en_entrenamiento`, `en_practica`, `en_riesgo`, `en_revision`, `aprobado`.

**Como se define “programa activo” por local**

- Concepto formal: `local_active_programs` (1 fila por `local_id`).
- Uso actual en DB: funcion `log_future_question` cae a `local_active_programs` si el learner no tiene `learner_trainings`.
- En app: no hay consumo directo de `local_active_programs` (solo seeds).

### B) Conocimiento (knowledge)

**Tablas reales**

- `knowledge_items`
  - Campos: `id`, `org_id`, `local_id` (nullable), `title`, `content`, `created_at`.
  - Scope: org-level (`local_id` NULL) o local-specific (`local_id` = local).
  - No existen campos de `source`, `type`, `version` o `status`.
- `unit_knowledge_map`
  - Campos: `unit_id`, `knowledge_id` (PK compuesta).
  - Relaciona knowledge con unidades.

**Relacion con unidades/programa**

- `unit_knowledge_map.unit_id` -> `training_units.id`.
- `unit_knowledge_map.knowledge_id` -> `knowledge_items.id`.

**Consumo actual**

- `lib/ai/context-builder.ts`:
  - Carga `training_programs`, `training_units`, `unit_knowledge_map`, `knowledge_items`.
  - Requiere knowledge para la unidad actual; si no hay mapping, falla con error.

### C) Evaluacion final (config/politica)

**Tabla real de configuracion**

- `final_evaluation_configs`
  - Campos: `program_id`, `total_questions`, `roleplay_ratio`, `min_global_score`,
    `must_pass_units`, `questions_per_unit`, `max_attempts`, `cooldown_hours`, `created_at`.
  - Constraint: `roleplay_ratio` entre 0 y 1; `total_questions > 0`.
  - No existe `active`/`status` ni versionado explicito.

**Como se resuelve HOY la configuracion**

- `lib/ai/final-evaluation-engine.ts`:
  - Consulta por `program_id`, ordena por `created_at desc`, `limit 1`.
  - Si no hay fila, se bloquea la evaluacion final con motivo `config_missing`.

**Politica implementada en codigo (hardcode)**

- Prompts de preguntas directas/roleplay (texto) estan hardcodeados en `final-evaluation-engine.ts`.
- Logica de mezcla de preguntas usa `roleplay_ratio`, `questions_per_unit`, `total_questions`.
- Regla de aprobacion usa `min_global_score` + `must_pass_units`.
- Limite de intentos y cooldown usan `max_attempts` y `cooldown_hours`.
- No hay “dificultad” configurable (no existe campo).

**Tablas de ejecucion (no config)**

- `final_evaluation_attempts`, `final_evaluation_questions`, `final_evaluation_answers`, `final_evaluation_evaluations`.
- Todas enlazadas por `attempt_id` y `program_id` (via `final_evaluation_attempts`).

### D) Permisos y RLS

**Helpers reales**

- `current_org_id()`, `current_local_id()`, `current_role()`, `current_profile()`, `current_user_id()`.
- `get_user_email(target_user_id)` (lectura email con gating por rol).

**Programas / unidades / programa activo**

- `training_programs`: RLS solo SELECT.
  - `admin_org`: org_id = current_org_id.
  - `referente`/`aprendiz`: org_id = current_org_id AND (local_id IS NULL OR local_id = current_local_id).
  - `superadmin`: acceso total.
- `training_units`: RLS solo SELECT (visible si `training_programs` visible).
- `local_active_programs`: RLS solo SELECT.
  - `admin_org`: local dentro de su org.
  - `referente`/`aprendiz`: local_id = current_local_id.
  - `superadmin`: acceso total.

**Knowledge**

- `knowledge_items`: RLS solo SELECT.
  - `admin_org`: org_id = current_org_id.
  - `referente`/`aprendiz`: org_id = current_org_id AND (local_id IS NULL OR local_id = current_local_id).
  - `superadmin`: acceso total.
- `unit_knowledge_map`: RLS solo SELECT (visible si `knowledge_items` visible).

**Evaluacion final (config)**

- `final_evaluation_configs`:
  - SELECT: `superadmin`, `admin_org`, `referente`.
  - SELECT aprendiz: si `learner_trainings.program_id = final_evaluation_configs.program_id`.
  - INSERT/UPDATE: `superadmin` y `admin_org`.
  - No hay policy de DELETE.

**Append-only real**

- Hay trigger `prevent_update_delete()` aplicado a tablas de auditoria/ejecucion (mensajes, intents, evaluaciones, decisiones, alert_events, etc.).
- `final_evaluation_configs`, `training_programs`, `training_units`, `knowledge_items`, `unit_knowledge_map`, `local_active_programs` NO tienen trigger append-only.

### E) Consumo actual (app)

**Programas / unidades**

- `lib/ai/context-builder.ts`: usa `training_programs` y `training_units` para construir contexto del chat.
- `app/learner/review/[unitOrder]/page.tsx`: consulta `training_units` para mostrar unidad en modo repaso.
- Views:
  - `v_learner_training_home` usa `training_programs` + `training_units`.
  - `v_learner_progress` usa `training_units`.

**Knowledge**

- `lib/ai/context-builder.ts`: usa `unit_knowledge_map` + `knowledge_items`.

**Evaluacion final**

- `lib/ai/final-evaluation-engine.ts`: lee `final_evaluation_configs` y usa `training_units` para generar prompts.
- `app/learner/final-evaluation/*`: usa `final_evaluation_attempts`, `final_evaluation_questions`, `final_evaluation_answers`.

**Seeds / SQL vs UI**

- Programas, unidades, knowledge, mapeos y final_evaluation_configs se cargan hoy via seeds SQL en migraciones (`supabase/migrations/*seed*`).
- No hay UI de Admin Org para crear/editar estos datos.
