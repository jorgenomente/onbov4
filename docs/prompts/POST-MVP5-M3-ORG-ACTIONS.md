# POST-MVP5 M3 ORG ACTIONS

## Contexto

Sub-lote M3: acciones sugeridas (read-only) para Admin Org, basadas en métricas M1/M2.

## Prompt ejecutado

```txt
# Post-MVP 5 — Sub-lote M3 (Read-only): “Acciones sugeridas” para Admin Org (Next steps operativos)

OBJETIVO
Transformar métricas (M1/M2) en un listado corto de acciones recomendadas para Admin Org, SIN writes:
- “Qué debería hacer ahora” basado en señales existentes
- Con links directos a pantallas ya operables:
  - /org/config/knowledge-coverage
  - /org/config/bot
  - /org/config/locals-program
  - /referente/review (cola) o equivalente
  - /org/metrics (drill-down)

ALCANCE (MVP CERRADO)
- Solo lectura: views + UI.
- 1 view principal de recomendaciones (top N).
- 1 bloque nuevo en /org/metrics (tab Resumen) o una ruta nueva /org/actions.
- Sin nuevas tablas.
- Sin RPCs de escritura.
- Sin “rules engine” complejo.
- Sin ML.

PRINCIPIOS
- Recomendaciones “explicables” (reason + evidencia).
- Top 5–10 máximo.
- Determinísticas, basadas en thresholds simples.
- Nunca cruzar orgs (tenant-scoped).
- No usar select *.

ENTRADAS (YA EXISTEN)
- v_org_top_gaps_30d
- v_org_unit_coverage_30d
- v_org_learner_risk_30d
- K1/K2/K3: knowledge coverage + gaps summary (si aporta)
- alert_events (opcional) para “pendientes recientes”
- learner_trainings (status, progress)

ENTREGABLES DB (1 migración)
Crear migración: supabase/migrations/YYYYMMDDHHMMSS_post_mvp5_m3_org_recommended_actions.sql

1) View principal: public.v_org_recommended_actions_30d
- Propósito: lista ordenada de acciones sugeridas para la org en ventana 30 días.
- Columnas (contrato):
  - org_id uuid
  - action_key text  -- identificador estable (ej 'knowledge_gap_unit', 'review_queue', 'final_eval_policy')
  - priority int     -- 1..100 (mayor = más urgente)
  - title text       -- texto corto UI
  - reason text      -- explicación breve (1–2 líneas)
  - evidence jsonb   -- payload chico (unit_order, gap_key, local_id, counts)
  - cta_label text   -- ej "Ver gaps", "Abrir cobertura", "Ajustar evaluación"
  - cta_href text    -- ruta interna
  - created_at timestamptz default now() (en view puede ser now() as created_at)
- Filtrado:
  - where current_role() in ('admin_org','superadmin')
  - admin_org: org_id = current_org_id()
  - superadmin: sin filtro org_id

2) Reglas (SQL determinístico, simple)
Construir la view como UNION ALL de “candidatos” con priority calculada:

A) Top gap alto impacto (si existe)
- Fuente: v_org_top_gaps_30d
- Condición: percent_learners_affected >= 25 (o learners_affected_count >= 3)
- priority: 90 - rank*5
- CTA: /org/metrics (tab=gaps) o /org/metrics/gaps/[gapKey]
- evidence: { gap_key, learners_affected_count, percent_learners_affected }

B) Cobertura baja por unidad/local
- Fuente: v_org_unit_coverage_30d
- Condición: coverage_percent < 60 AND learners_active_count >= 2
- priority: 80 - rank*5
- CTA: /org/metrics/coverage/[programId]/[unitOrder]
- evidence: { local_id, program_id, unit_order, coverage_percent }

C) Learners en riesgo
- Fuente: v_org_learner_risk_30d
- Condición: risk_level in ('high','medium') (según valores reales)
- priority: 70 - rank*3
- CTA: /referente/review/[learnerId] o /org/review/[learnerId] (usar lo que ya funcione)
- evidence: { learner_id, local_id, risk_level, last_signal_at }

D) (Opcional, solo si existe señal clara) “Revisar policy de evaluación final”
- Si detectás muchos fails recientes en evaluación final (si hay una view/tabla fácil de agregar):
  - Si no hay fuente estable, OMITIR en M3.
- Mantener M3 sin inventar fuentes.

Ordenar el resultado final por priority desc, limit 10.

REGENERAR DOCS DB
- npx supabase db reset
- Regenerar docs/db/dictionary.md y docs/db/schema.public.sql

ENTREGABLES UI (Next.js 16 / RSC)
Opción recomendada MVP:
- Agregar bloque “Acciones sugeridas (30 días)” en /org/metrics tab “Resumen”
  - Consulta server-side a v_org_recommended_actions_30d
  - Render lista de cards compactas:
    - Title
    - Reason
    - Badge prioridad (Alta/Media/Baja derivada de priority)
    - Botón CTA (link)
- Mantener mobile-first, sin gráficos.

Alternativa si preferís:
- Crear /org/actions como pantalla única, y linkear desde /org/metrics.

Estados:
- loading.tsx
- empty: “No hay acciones sugeridas (sin señales en 30 días)”
- error state claro

DOCS / LOG
- docs/activity-log.md: “Post-MVP5 M3 acciones sugeridas (views + UI read-only)”
- docs/prompts/POST-MVP5-M3-ORG-ACTIONS.md

QA / GATE
- npx supabase db reset
- Manual:
  - Login admin_org
  - /org/metrics → Resumen muestra bloque (aunque vacío)
  - Click en CTA navega sin error
- RLS sanity:
  - referente no accede /org/*
- npm run lint
- npm run build

TRABAJO
- Directo sobre main.
- Usar permisos escalados (opción 2) para commit/push si hace falta.
- Fix mínimo si bloquea gates; loguear.
```

Resultado esperado

View con acciones sugeridas + bloque en /org/metrics (Resumen).

Notas (opcional)

Sin notas.
