# Post-MVP6 - Configuracion del Bot (Roadmap + Contrato)

**Estado:** Docs-only (Sub-lote 0)

## 1) Alcance y definicion

**Que es "configurar el bot" en ONBO**

Configurar el bot significa **definir que conocimiento usa, como responde y como evalua** dentro del flujo secuencial de entrenamiento. No es crear cursos libres ni editar el aprendizaje fuera de la secuencia.

Alcances reales hoy (schema + codigo):

- **Contenido**: programas, unidades, conocimiento (knowledge_items) y su mapeo a unidades.
- **Comportamiento**: reglas de grounding y prompts de chat/evaluacion (hardcodeados hoy).
- **Evaluacion**: parametros de evaluacion final y su uso en engine (configurable por programa).

**Anti-alcance (guardrails anti-LMS)**

- No hay authoring libre ni builder de cursos.
- No hay quizzes de opcion multiple ni contenido fuera de la secuencia.
- No hay conocimiento externo ni herramientas externas del bot.
- No hay cambios retroactivos que afecten evaluaciones ya realizadas.

## 2) Modelo conceptual (contrato)

**Capas**

1. **Contenido (knowledge)**
   - Datos persistidos que el bot puede usar.
   - Scope: org-level (`local_id` NULL) o local-level (`local_id` = local).
   - Fuente: `knowledge_items` + `unit_knowledge_map` + unidades activas.

2. **Comportamiento (respuesta)**
   - Reglas de respuesta, tono, formato y limites.
   - Hoy vive en:
     - `app/learner/training/actions.ts` (system prompt)
     - `lib/ai/context-builder.ts` (reglas de grounding + contexto)
     - `lib/ai/practice-evaluator.ts` (prompt evaluador practica)
     - `lib/ai/final-evaluation-engine.ts` (prompts de preguntas y evaluacion)

3. **Evaluacion (criterios y preguntas)**
   - Configurable por programa via `final_evaluation_configs`.
   - Engine usa la config "latest by created_at".

**Modo bot**

- **Entrenamiento**: chat grounded con knowledge permitido por unidad actual y pasadas.
- **Practica**: role-play con `practice_scenarios` + evaluador JSON estricto.
- **Evaluacion final**: preguntas directas/roleplay + evaluacion semantica JSON.
- **Repaso**: hoy es **solo lectura** (sin bot activo); contenido pendiente.

## 3) Configurables vs no configurables (matriz)

| Item                                                              | Nivel (org/local/program) | Rol que puede          | Estado actual           | Riesgo | Requiere DB?         | Requiere UI?         |
| ----------------------------------------------------------------- | ------------------------- | ---------------------- | ----------------------- | ------ | -------------------- | -------------------- |
| Config evaluacion final (`final_evaluation_configs`)              | program                   | admin_org / superadmin | ya existe (RPC + UI)    | medio  | no                   | no (UI existente)    |
| Programa activo por local (`local_active_programs`)               | local                     | admin_org / superadmin | ya existe (RPC + UI)    | alto   | no                   | no (UI existente)    |
| Knowledge item + mapeo a unidad (`create_and_map_knowledge_item`) | org/local + unidad        | admin_org / superadmin | ya existe (RPC + UI)    | alto   | no                   | no (UI existente)    |
| Desactivar knowledge (`disable_knowledge_item`, `is_enabled`)     | org/local                 | admin_org / superadmin | ya existe (RPC + UI)    | medio  | no                   | no (UI existente)    |
| Programas (`training_programs`)                                   | org/local                 | admin_org / superadmin | hardcode (seed)         | alto   | si                   | si                   |
| Unidades (`training_units`)                                       | program                   | admin_org / superadmin | hardcode (seed)         | alto   | si                   | si                   |
| Practice scenarios (`practice_scenarios`)                         | program + unidad          | admin_org / superadmin | hardcode (seed)         | medio  | si                   | si                   |
| Reglas de grounding (no externo, no avanzar)                      | global                    | -                      | hardcode (prompts)      | alto   | no                   | no                   |
| Estilo/tono/formato del bot                                       | program/org               | -                      | no existe               | medio  | si (si se configura) | si (si se configura) |
| Plantillas de preguntas (evaluacion/practica)                     | program                   | -                      | hardcode (prompts)      | medio  | si (si se configura) | si (si se configura) |
| Tipos de conocimiento (concepto/procedimiento/regla/guion)        | knowledge                 | -                      | no existe               | medio  | si (si se configura) | si (si se configura) |
| Seleccion de escenarios (dificultad/estrategia)                   | program                   | -                      | hardcode (difficulty=1) | bajo   | no (si se mantiene)  | no (si se mantiene)  |

**Configurable (MVP y vigente)**

- `final_evaluation_configs` (insert-only) por programa.
- Programa activo por local (RPC `set_local_active_program` + auditoria).
- Knowledge (crear + mapear + desactivar) via RPCs K2/K3.

**Configurable despues (si se aprueba)**

- CRUD de programas y unidades.
- CRUD de practice_scenarios (incluye dificultad).
- Tipado de knowledge_items.
- Configuracion de prompts/plantillas por programa.

**Nunca (anti-LMS)**

- Editor libre de cursos o builder drag-and-drop.
- Quizzes de opcion multiple y evaluaciones fuera del chat.
- Cualquier conocimiento externo al schema cargado.

**Infra actual (DB/RPC/Vistas relevantes)**

- RPCs: `create_final_evaluation_config`, `create_and_map_knowledge_item`, `disable_knowledge_item`, `set_local_active_program`.
- Views: `v_org_program_final_eval_config_current`, `v_org_program_final_eval_config_history`, `v_org_program_unit_knowledge_coverage`, `v_org_local_active_programs`.
- Auditoria: `knowledge_change_events`, `local_active_program_change_events` (append-only).

## 4) Contratos de comportamiento (lo que falta hoy)

**Contrato minimo de estilo (a implementar en prompts o config)**

- Respuestas breves, pedagogicas y accionables.
- Priorizar preguntas de clarificacion cuando falte contexto.
- Evitar respuestas que revelen contenido de unidades futuras.
- Si no hay knowledge permitido: responder "no puedo responder con la info disponible".

**Guardrails obligatorios**

- Nunca inventar ni usar conocimiento externo.
- Si el knowledge permitido no cubre la pregunta, **responder con "no se con el contexto actual"** y sugerir volver a la unidad.
- Mantener grounding estricto por unidad actual + pasadas.

**Senales a registrar**

- Duda explicita: `no_se`, `no_me_acuerdo`.
- Respuestas ambiguas/cortas: `ambiguo`.
- (Opcional) Preguntas sobre unidades futuras: existe infraestructura (`learner_future_questions`) pero falta senal en output.

**Outputs del evaluador (contrato JSON)**

Formato estricto (ya usado en practica y evaluacion final):

```json
{"score":number,"verdict":"pass|partial|fail","strengths":string[],"gaps":string[],"feedback":string,"doubt_signals":string[]}
```

## 5) Tipos de contenido y tipologia pedagogica (propuesta minima)

**Estado actual**: `knowledge_items` no tiene tipo ni fuente. Solo `title` y `content`.

**Propuesta minima (si se decide configurar)**

- Agregar un **tipo** para orientar prompts y evaluacion:
  - `concepto` (definicion)
  - `procedimiento` (pasos)
  - `regla` (policy/criterio)
  - `guion` (fraseo/dialogo)

**Nota**: esto **requiere cambios de DB** (columna + enum) y contratos de lectura en UI/engine.

## 6) Evaluacion (contrato operativo)

**Campos existentes (final_evaluation_configs)**

- `total_questions`: numero total de preguntas.
- `roleplay_ratio`: proporcion roleplay (0-1).
- `min_global_score`: promedio minimo 0-100.
- `must_pass_units`: unidades que no pueden fallar.
- `questions_per_unit`: maximo por unidad.
- `max_attempts`: limite de intentos.
- `cooldown_hours`: cooldown entre intentos.

**Interpretacion real hoy (engine)**

- Se usa la config **mas reciente por `created_at`**.
- `roleplay_ratio` determina cuantas preguntas roleplay se generan.
- Aprobacion: promedio `min_global_score` + `must_pass_units` sin fail.
- Guardrail: se bloquea insertar config si hay intento `in_progress`.
- Versionado: append-only (no UPDATE/DELETE) por trigger.

**Que falta (si se decide)**

- Plantillas de preguntas por programa (hoy hardcode).
- Dificultad o perfiles de evaluacion (no existe en config).

## 7) Plan de sub-lotes ejecutables (orden recomendado)

### Sub-lote 0 - Docs-only (este)

**Objetivo**: consolidar contrato + roadmap sin tocar DB/UX.

**Entregables**

- `docs/post-mvp6/bot-configuration-roadmap.md`
- Actualizacion de `AGENTS.md`
- Entrada en `docs/activity-log.md`

**Riesgos**

- Ninguno tecnico (solo claridad).

**QA / smoke**

- Verificar paths y markdown.

---

### Sub-lote 1 - DB changes minimas (si aplica)

**Objetivo**: habilitar tipado/flags minimos para contenido y comportamiento.

**Entregables (condicionales)**

- Columna `knowledge_items.content_type` (enum) si se aprueba tipologia.
- Guardrails append-only si se requiere para nuevas entidades/flags.

**Estado**: Hecho (2026-01-28)

**Implementado**

- Enum `knowledge_content_type` + columna `knowledge_items.content_type` (nullable, sin default).

**Riesgos**

- Cambios de schema sin UI pueden quedar huerfanos.

**QA / smoke (SQL)**

- Insert con `content_type` valido.
- RLS: admin_org ve/crea dentro de org/local.

---

### Sub-lote 2 - Views read-only "config del bot"

**Objetivo**: consolidar lectura operativa de configuracion.

**Entregables**

- View resumen (si se necesita): active program + config vigente + coverage.
- Extender vistas actuales si faltan campos de comportamiento.

**Estado**: Hecho (2026-01-28)

**Implementado**

- `v_local_bot_config_summary`: resumen por local (programa activo, config final vigente, coverage knowledge, escenarios).
- `v_local_bot_config_units`: detalle por unidad del programa activo (knowledge por tipo, escenarios).
- `v_local_bot_config_gaps`: huecos deterministas (sin knowledge / sin practica).

**Riesgos**

- Duplicar vistas ya existentes (debe evitarse).

**QA / smoke (SQL)**

- SELECT por rol (admin_org/referente/aprendiz) sin fuga cross-tenant.

---

### Sub-lote 3 - 1 write seguro guiado (si aplica)

**Objetivo**: habilitar **un** write controlado para configuracion faltante.

**Entregables (condicionales)**

- RPC minima (ej: crear escenario de practica o registrar plantilla por programa).
- Auditoria append-only asociada.

**Estado**: Hecho (2026-01-28)

**Implementado**

- RPC `create_practice_scenario` (create-only) con validaciones de program_id + unit_order + difficulty.
- Scope: admin_org solo ORG-level (local_id NULL); superadmin puede ORG/local.
- Sin auditoria de creacion (pendiente si se decide Sub-lote 3.1).

**Riesgos**

- Exceso de libertad (deriva hacia LMS).

**QA / smoke (SQL)**

- INSERT valido con rol admin_org.
- RLS: aprendiz/referente no pueden escribir.

---

### Sub-lote 3.1 - Disable practice_scenarios + auditoria (append-only)

**Objetivo**: completar write seguro con disable soft + auditoria append-only.

**Entregables**

- Columna `practice_scenarios.is_enabled` (default true).
- Tabla `practice_scenario_change_events` (append-only) con eventos created/disabled.
- RPC `disable_practice_scenario` con validaciones de rol y scope.
- Views de config del bot filtradas por `is_enabled=true`.

**Estado**: Hecho (2026-01-28)

**Implementado**

- `is_enabled` en practice_scenarios + policies UPDATE para admin_org/superadmin.
- Auditoria append-only (sin UPDATE/DELETE) con RLS: superadmin/org/referente; aprendiz bloqueado.
- create_practice_scenario emite evento `created`; disable_practice_scenario emite `disabled`.

**Riesgos**

- Sin auditoria de re-enable (event_type existe, RPC no implementado).

**QA / smoke (SQL)**

- Admin Org: create + disable OK (solo ORG-level).
- Referente/aprendiz: disable bloqueado.
- Superadmin: disable local-level OK.

---

### Sub-lote 4 - UI minima (si aplica)

**Objetivo**: exponer la configuracion anadida con UI minimalista.

**Entregables**

- 1 pantalla, 1 write, estados completos.

**Estado**: Hecho (2026-01-28)

**Implementado**

- Ruta `/org/bot-config` con lectura de views S2 y acciones create/disable practice_scenarios.
- Selector de local, resumen, unidades, gaps y modales create/disable.

**Riesgos**

- UI sin contrato de datos claro.

**QA / smoke**

- Rutas protegidas por rol.
- Create/read sin errores.

## 8) OPEN QUESTIONS

1. Queremos tipar knowledge (concepto/procedimiento/regla/guion) o mantener texto libre?
   - Resolver: inspeccionar necesidades reales del motor y UX; si se aprueba, agregar columna en `knowledge_items`.
2. Se permite configurar prompts/plantillas por programa?
   - Resolver: definir si se guarda en DB o en plantillas versionadas en codigo.
3. Resuelto: practice_scenarios create-only con admin_org ORG-level y superadmin ORG/local (Sub-lote 3).
   - Pendiente: definir auditoria append-only para creacion (posible Sub-lote 3.1).
4. Repaso tendra bot activo o seguira read-only?
   - Resolver: revisar UX deseada y definir si necesita contenido/config adicional.
5. Se requiere granularidad por local en final_evaluation_configs?
   - Resolver: hoy es por programa; confirmar si hay necesidad local-specific.
