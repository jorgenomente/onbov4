# POST-MVP5 M1 ORG METRICS

## Contexto

Sub-lote M1: métricas accionables Admin Org (30 días) con views org-scoped y UI read-only.

## Prompt ejecutado

```txt
# Post-MVP 5 — Sub-lote M1 (Read-only): Métricas accionables Admin Org (30 días)

OBJETIVO
Dar a Admin Org visibilidad accionable (sin writes) para operar ONBO a nivel organización:
- Top gaps (temáticas/unidades con más fallas) en ventana 30 días
- Riesgo por aprendiz (en_riesgo / señales) en ventana 30 días
- Cobertura por unidad (evidencia/actividad) por local y org en ventana 30 días

ALCANCE (MVP CERRADO)
- Solo lectura: views + UI.
- 1 pantalla Admin Org con tabs (Resumen / Gaps / Cobertura / Riesgo).
- Sin migraciones de tablas nuevas.
- Sin RPCs de escritura.
- Sin cambios a engine/chat.
- Reusar data existente (evaluación final, práctica, alert_events, knowledge, trainings).

NO HACER
- No dashboards complejos, no gráficos avanzados.
- No export, no filtros múltiples.
- No “builder”.
- No tocar modelos LLM.
- No service_role.

CONTEXTO (YA EXISTE)
Ya hay views métricas para referente/local (Fase 3 previa):
- v_local_top_gaps_30d
- v_local_learner_risk_30d
- v_local_unit_coverage_30d

Y views de evidencia (Fase 2):
- v_learner_evaluation_summary (referente/admin)
- v_learner_wrong_answers
- v_learner_doubt_signals

Más infraestructura:
- alert_events (append-only) + /referente/alerts
- learner_trainings (status, progress, local_id, program_id)
- profiles / locals / organizations
- practice / final evaluation tables (attempts, answers, evaluations) ya tenant-scoped.

DECISIÓN DE DISEÑO (IMPORTANTE)
Admin Org necesita métricas a nivel ORG, pero siempre con posibilidad de “drill-down” por local.
=> M1 crea views ORG agregadas + (opcional) vistas por local reutilizando las existentes.

ENTREGABLES DB (1 migración)
Crear migración: supabase/migrations/YYYYMMDDHHMMSS_post_mvp5_m1_org_metrics_views.sql

1) Views nuevas (org-scoped, read-only)
A) public.v_org_top_gaps_30d
- 1 fila por (unit_order o “gap_key”)
- Campos sugeridos:
  - org_id
  - gap_key (ej: 'unit:2' o 'concept:xyz' según tu model actual)
  - unit_order (si aplica)
  - title (si existe)
  - learners_affected_count
  - percent_learners_affected
  - total_fail_events (o wrong_answers_count)
  - window_days = 30 (comentario)
- Fuente recomendada:
  - Si v_local_top_gaps_30d ya existe y está bien: construir esta view como agregación:
    sum(learners_affected_count) / denominador org
  - Denominador org: learners activos en la org en ventana (o total learners en training).
  - Evitar select *.

B) public.v_org_learner_risk_30d
- 1 fila por learner (en org)
- Campos:
  - org_id
  - local_id
  - learner_id
  - learner_name/email (si ya hay contrato seguro; si no, solo learner_id)
  - risk_level (enum/text)
  - risk_score (num)
  - signals_count_30d
  - last_signal_at
- Fuente:
  - Agregar desde v_local_learner_risk_30d con join a locals/org.
  - O derivar de alert_events + evaluaciones + duda signals existentes.

C) public.v_org_unit_coverage_30d
- 1 fila por (local_id, program_id, unit_order)
- Campos:
  - org_id
  - local_id
  - local_name (opcional si no rompe RLS de profiles; locals sí)
  - program_id
  - unit_order
  - coverage_percent
  - learners_active_count
  - learners_with_evidence_count
  - last_activity_at
- Fuente:
  - Reusar v_local_unit_coverage_30d y agregar org_id via locals.
  - Mantener ventana 30 días.

2) RLS / Grants
- Mantener views como SECURITY INVOKER.
- Asegurar que:
  - admin_org: SELECT solo filas org_id = current_org_id()
  - superadmin: SELECT todo
  - referente/aprendiz: no deben usar estas views (ideal: filtrar por current_role() dentro de la view OR no otorgar permisos).
Recomendación MVP (simple y consistente con K1):
- Incluir filtro por role dentro de la view:
  where current_role() in ('admin_org','superadmin')
  and org_id = current_org_id()  (para admin_org)
  and (para superadmin no filtrar org_id)

NOTA: Evitar usar profiles para nombres si complica RLS; podemos agregarlo en M2.

REGENERAR DOCS DB
- npx supabase db reset
- Regenerar docs/db/dictionary.md y docs/db/schema.public.sql

ENTREGABLES UI (Next.js 16 / RSC)
Ruta:
- /org/metrics  (o /org/analytics si ya existe convención; elegir una)

Pantalla (mobile-first)
- Header: “Métricas (últimos 30 días)”
- Tabs (shadcn/ui opcional si ya está en repo; si no, simple):
  1) Resumen
     - KPIs: learners en riesgo, gaps top 1, cobertura promedio (aprox)
  2) Gaps
     - Tabla: gap_key/unit_order + learners_affected_count + % afectados
  3) Cobertura
     - Tabla: local + unit_order + coverage_percent + last_activity_at
  4) Riesgo
     - Tabla: learner_id (y nombre si disponible) + local + risk_level + last_signal_at
- Estados obligatorios:
  - loading.tsx
  - empty (sin datos en 30 días)
  - error

UI TECH
- Consultas server-side con Supabase SSR (RSC).
- Nada de client fetching.
- No writes.

DOCS / LOG
- docs/activity-log.md: “Post-MVP5 M1 métricas Admin Org (views + UI read-only)”
- docs/prompts/POST-MVP5-M1-ORG-METRICS.md

QA / GATE
- npx supabase db reset
- Smoke manual:
  - login admin_org
  - /org/metrics carga
  - cada tab renderiza al menos headers/tabla vacía sin error
- RLS sanity (manual):
  - referente NO puede acceder a /org/metrics (por routing/rol)
  - si intenta query directa, view no debe retornar filas
- npm run lint
- npm run build

TRABAJO
- Directo sobre main.
- Fix mínimo si bloquea gates, loguear.

NOTA DE SCOPE
- Si el seed local no genera suficiente data de 30 días, está OK que las tablas salgan vacías;
  lo importante es que no rompa y que los contratos existan. Si hace falta, se agrega seed QA
  en un sub-lote QA posterior (M1.1) sin tocar lógica.
```

Resultado esperado

Views org-scoped y UI /org/metrics.

Notas (opcional)

Sin notas.
