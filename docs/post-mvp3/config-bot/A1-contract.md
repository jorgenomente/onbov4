# Post-MVP 3 / Configuracion del bot — Sub-lote A1

## Seccion 2: Contrato minimo operable (✅ / ❌ / 🟡)

### ✅ Configurable por Admin Org (MVP)

1. Configuracion de evaluacion final por programa (`final_evaluation_configs`)

- Campos configurables: `total_questions`, `roleplay_ratio`, `questions_per_unit`, `min_global_score`, `must_pass_units`, `max_attempts`, `cooldown_hours`.
- Accion permitida por RLS hoy: INSERT y UPDATE (admin_org/superadmin).
- Scope: por `program_id` (no por local directo).
- `min_global_score` es porcentaje 0–100, comparado contra el promedio de scores por attempt (no normalizado).

### ❌ No configurable (por ahora)

- Crear/editar/borrar `training_programs` y `training_units` (no hay policies de write).
- Asignar “programa activo” por local (`local_active_programs`) via UI (no hay policies de write).
- Crear/editar/borrar `knowledge_items` (no hay policies de write).
- Crear/editar/borrar `unit_knowledge_map` (no hay policies de write).
- Textos de prompts y logica de generacion de preguntas (hardcode en `final-evaluation-engine.ts`).
- Parametros no existentes en schema: dificultad, pesos por unidad, tono, policy de contexto, etc.

### 🟡 Configurable despues (futuro)

- Activar/cambiar programa activo por local con auditoria (requiere writes en `local_active_programs`).
- Gestionar knowledge items con versionado y RLS write (org y/o local) sin caer en LMS.
- Administrar mapping knowledge ↔ unidad con control de impacto y auditoria.
- Parametros de prompts por programa (solo plantillas, no builder de cursos).

## Seccion 3: Reglas “desde ahora” + implicancias de versionado

### ✅ Configuracion de evaluacion final (`final_evaluation_configs`)

**Aplica desde ahora**

- Se aplica por `program_id`.
- Se usa el registro mas reciente por `created_at` en runtime.
- Impacta tanto el inicio de un intento como la finalizacion (se re-lee config al finalizar).

**Versionado / append-only recomendado**

- Regla operativa: NO actualizar ni borrar filas; insertar nueva fila por cambio.
- Motivo: no existe `config_id` en `final_evaluation_attempts`, por lo que un update puede alterar la regla de evaluacion de intentos en curso o ya cerrados.

**Riesgos si se permite update destructivo**

- Cambia criterios de aprobacion de intentos ya iniciados (o incluso completados si se recalcula).
- Perder trazabilidad de que regla se uso en cada intento.
- Inconsistencia entre `total_questions`/`roleplay_ratio` y preguntas ya generadas.

## Seccion 4: Plan de sub-lotes recomendado (orden exacto)

### A.1 — Aclaraciones necesarias (si aplica)

Entregables:

- Confirmar si la configuracion es por `program_id` (no por local) o si se requiere granuralidad local.
- Confirmar regla operativa: “solo se cambia config cuando no hay intentos en progreso”.
- Confirmar politica: insert-only vs update permitido.

### B.1 — Views read-only “config actual”

Entregables:

- View para Admin Org que liste la config vigente por programa (latest by created_at).
- View de historial (todas las configs por programa, ordenadas).
- RLS de lectura coherente con `final_evaluation_configs`.

### C.1 — Versionado minimo

Entregables:

- Hacer `final_evaluation_configs` append-only (bloquear UPDATE/DELETE) o, si se decide, mantener UPDATE pero con guardrails de auditoria.
- Ajustar policies segun decision de A.1.

### C.2 — RPC write seguro (1 solo write primero)

Entregables:

- RPC `create_final_eval_config` (o equivalente) que inserte nueva fila validando:
  - rol admin_org/superadmin
  - programa pertenece a la org
  - no hay intentos `in_progress` para ese programa (si se adopta la regla)

### D.1 — UI Admin minima (1 pantalla, 1 write)

Entregables:

- Pantalla unica Admin Org para:
  - ver configuracion actual por programa
  - crear nueva configuracion (insert-only)
- Estados obligatorios: loading/empty/error/success.
