# POST-MVP6 Sub-lote 2: Views config del bot (read-only)

## Contexto

Consolidar lectura operativa de la configuracion del bot con views tenant-scoped, sin UI ni writes.

## Prompt ejecutado

```txt
# PROMPT PARA CODEX CLI — Post-MVP6 Sub-lote 2 (DB): Views read-only “Config del Bot” (sin UI, sin writes)

Actuá como Backend Engineer (Supabase/Postgres, DB-first, RLS-first, Zero Trust).

## Objetivo
Post-MVP6 Sub-lote 2 — Consolidar **lectura operativa** de la “configuración del bot” mediante **views read-only** tenant-scoped, sin inventar entidades nuevas y sin tocar UI ni server actions.

La meta es que Admin Org / Referente / (si aplica) Superadmin puedan consultar:
- qué programa está activo en un local
- qué config de evaluación final está vigente (latest)
- qué coverage de knowledge tiene cada unidad del programa activo
- qué escenarios de práctica existen por unidad (conteo + dificultad)
- (opcional) último activity timestamp relevante (si ya existe material sin nuevas tablas)

## Contexto (MANDATORIO)
- Repo: onbo-conversational (trabajo directo en main, sin ramas).
- Multi-tenant estricto: Organization → Local → User.
- NO usar service_role en clientes.
- NO inventar tablas nuevas.
- NO tocar UI ni server actions.
- Mantener políticas existentes (no agregar RLS nueva salvo que sea estrictamente necesario para que las views sean legibles por los roles correctos).
- Respetar el contrato en: docs/post-mvp6/bot-configuration-roadmap.md
- Sub-lote 1 ya agregó: knowledge_items.content_type (nullable) — usarlo en lectura si aporta.

## Relevamiento (antes de escribir SQL)
1) Inspeccionar schema y views existentes (docs/db/* como fuente, y/o supabase/migrations):
   - local_active_programs, training_programs, training_units
   - knowledge_items + unit_knowledge_map
   - practice_scenarios
   - final_evaluation_configs
   - views existentes: v_org_* y v_local_* relacionadas a programas/config/coverage (evitar duplicar)
2) Identificar qué ya existe para:
   - “config vigente” de final eval (latest by created_at)
   - “programa activo” por local
   - coverage por unidad (knowledge mapeado / total / etc)
Si ya existe una view equivalente, **NO crear duplicado**: extender/ajustar la existente.

## Tareas (entregable DB)
Crear UNA migración en supabase/migrations que agregue/actualice views read-only, preferentemente con estos contratos:

### A) View 1 — v_local_bot_config_summary
Fila por local (scope local), con:
- local_id
- org_id (derivado via locals)
- active_program_id
- active_program_name
- total_units
- current_final_eval_config_id (si existe)
- final_eval_total_questions, roleplay_ratio, min_global_score, must_pass_units, questions_per_unit, max_attempts, cooldown_hours
- counts:
  - total_knowledge_items_active_program (mapeados a unidades del programa)
  - total_practice_scenarios_active_program
- (si aplica) breakdown por content_type (conteo por tipo) — solo si no complica.

### B) View 2 — v_local_bot_config_units
Fila por unidad del programa activo del local:
- local_id
- program_id
- unit_order
- unit_title
- knowledge_count (mapeado)
- knowledge_count_by_type (json o columnas separadas solo si simple)
- practice_scenarios_count
- practice_difficulty_min / max (si hay escenarios)
- success_criteria_count_total (si es trivial de derivar sin overhead)

### C) (Opcional) View 3 — v_local_bot_config_gaps
Solo si existen datos para inferir “huecos” sin inventar:
- unidades sin escenarios de práctica
- unidades sin knowledge mapeado
- unidades sin coverage suficiente (si ya hay un criterio existente)

Si esto requiere inventar reglas nuevas, NO hacerlo: limitarse a checks deterministas (count=0).

## RLS / Seguridad (CRÍTICO)
- Las views deben ser tenant-scoped **por construcción**:
  - Referente: solo su local (current_local_id())
  - Admin Org: solo su org (current_org_id()) — puede ver múltiples locales
  - Superadmin: todo (si ya existe ese patrón en otras views)
- Evitar depender de claims “forzables”; usar helpers actuales (current_org_id/current_local_id) y joins a locals/learner_trainings cuando corresponda.
- Si una view necesita policy extra en tablas base para que roles la lean, preferir:
  - consumir solo tablas ya legibles por esos roles
  - o ajustar con mínima policy SELECT (pero SOLO si estrictamente necesario y justificado en activity-log + roadmap)

## QA / Smoke (OBLIGATORIO)
Agregar en el final del prompt/entrega un bloque “QA manual” con:
1) npx supabase db reset
2) Queries de verificación:
   - como referente: ver 1 fila en summary (su local) y N unidades en units
   - como admin_org: ver filas para todos los locales de su org
   - como aprendiz: (decidir) o devuelve 0 filas o no tiene acceso (según patrón actual; justificar)
Incluí SQL listo para ejecutar en Studio para validar conteos.

## Docs (OBLIGATORIO)
Actualizar:
- docs/post-mvp6/bot-configuration-roadmap.md
  - marcar Sub-lote 2 como hecho
  - describir las nuevas views y su contrato de lectura
- docs/activity-log.md
  - nueva entrada “Post-MVP6 Sub-lote 2: views config del bot (read-only)”
- docs/db/dictionary.md y docs/db/schema.public.sql
  - regenerar con:
    - npm run db:dictionary
    - npm run db:dump:schema
- Registrar este prompt en:
  - docs/prompts/POST-MVP6-SUBLOTE-2-VIEWS-CONFIG-BOT.md

## Restricción de entrega
Entregar EXACTAMENTE estos archivos (si el repo lo permite por reglas):
- supabase/migrations/<timestamp>_post_mvp6_s2_views_bot_config.sql
- docs/db/dictionary.md (regenerado)
- docs/db/schema.public.sql (regenerado)
- docs/post-mvp6/bot-configuration-roadmap.md (update)
- docs/activity-log.md (update)
- docs/prompts/POST-MVP6-SUBLOTE-2-VIEWS-CONFIG-BOT.md

## Comandos a ejecutar (y reportar)
- npm run db:dictionary
- npm run db:dump:schema

## Commit (directo en main)
Mensaje:
- feat(post-mvp6): add bot config read-only views

Al finalizar:
1) imprimir resumen: archivos tocados, views creadas/extendidas, decisiones de RLS tomadas
2) listar cualquier “open question” nueva si surgió un bloqueo real
```

Resultado esperado

Views read-only con contratos de lectura de config del bot y docs actualizadas.

Notas (opcional)

Sub-lote sin UI ni writes.
