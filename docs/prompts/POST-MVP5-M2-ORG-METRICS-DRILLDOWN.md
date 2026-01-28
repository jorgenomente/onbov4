# POST-MVP5 M2 ORG METRICS DRILLDOWN

## Contexto

Sub-lote M2: drill-down read-only desde /org/metrics para gaps, riesgo y cobertura, sin writes.

## Prompt ejecutado

```txt
# Post-MVP 5 — Sub-lote M2 (Read-only): Drill-down accionable desde /org/metrics

OBJETIVO
Convertir las métricas M1 en acciones operativas sin agregar writes:
- Drill-down de Gaps: ver distribución por local (y links)
- Drill-down de Riesgo: link directo a detalle /referente/review/[learnerId]
- Drill-down de Cobertura: ver knowledge activo de esa unidad (y contexto)

ALCANCE (MVP CERRADO)
- Solo lectura: views + UI.
- Sin nuevas tablas.
- Sin RPCs de escritura.
- Sin cambios en engine/chat.
- No dashboards complejos.

ENTRADAS (YA EXISTEN)
- M1:
  - v_org_top_gaps_30d
  - v_org_learner_risk_30d
  - v_org_unit_coverage_30d
- K1/K2/K3:
  - v_org_unit_knowledge_list (filtra is_enabled=true)
- Infra:
  - locals, learner_trainings, profiles (RLS ya endurecida)
  - UI referente review existe: /referente/review/[learnerId]

ENTREGABLES DB (1 migración)
Crear migración: supabase/migrations/YYYYMMDDHHMMSS_post_mvp5_m2_org_metrics_drilldowns.sql

Crear 2 views nuevas (org-scoped, read-only):

1) public.v_org_gap_locals_30d
- Propósito: dado unit_order (gap), mostrar impacto por local
- 1 fila por (org_id, unit_order, local_id)
- Campos:
  - org_id
  - unit_order
  - local_id
  - local_name
  - learners_affected_count
  - percent_learners_affected_local
  - total_events_30d
  - last_event_at
- Fuente recomendada:
  - Basarse en la misma fuente que v_org_top_gaps_30d / v_local_top_gaps_30d (la más confiable existente)
  - Si v_local_top_gaps_30d ya calcula por local y unit_order, entonces:
    - v_org_gap_locals_30d puede ser SELECT directo de v_local_top_gaps_30d + join locals para org
    - y filtrar where current_role() in ('admin_org','superadmin')
  - Evitar select *.

2) public.v_org_unit_knowledge_active
- Propósito: listar knowledge activo para un unit_id (o program_id + unit_order)
- 1 fila por knowledge mapeado a una unidad dentro de un programa de la org
- Campos:
  - org_id
  - program_id
  - program_name
  - unit_id
  - unit_order
  - unit_title
  - knowledge_id
  - knowledge_title
  - knowledge_scope ('org'|'local') derivado de local_id null/not null
  - knowledge_created_at
- Fuente:
  - training_units -> training_programs -> unit_knowledge_map -> knowledge_items
  - Filtrar knowledge_items.is_enabled=true
  - Filtrar role: admin_org/superadmin
  - Filtrar org_id = current_org_id() para admin_org; superadmin sin filtro

RLS / Grants
- Views SECURITY INVOKER.
- Dentro de cada view, incluir guardrail:
  where current_role() in ('admin_org','superadmin')
- Para admin_org: org_id = current_org_id()
- Para superadmin: sin filtro de org_id.

REGENERAR DOCS DB
- npx supabase db reset
- Regenerar docs/db/dictionary.md y docs/db/schema.public.sql

ENTREGABLES UI (Next.js 16 / RSC)
Ruta existente:
- /org/metrics (ya implementada)

UX: agregar drill-down sin complejidad
A) Tab “Gaps”
- Convertir filas a links (o botón “Ver por local”)
- Al click: navegar a /org/metrics/gaps/[unitOrder]
  - Nueva ruta: app/org/metrics/gaps/[unitOrder]/page.tsx
  - Mostrar tabla por local usando v_org_gap_locals_30d filtered unit_order
  - Mostrar CTA link “Ver cobertura unidad” → /org/metrics/coverage?unitOrder=...

B) Tab “Riesgo”
- Cada learner row:
  - Link a /referente/review/[learnerId] (ya existe)
  - (Si admin_org no debería usar rutas referente por rol, entonces:
     - agregar una ruta espejo read-only /org/review/[learnerId] que renderiza el mismo componente de evidencia
     - RECOMENDACIÓN MVP: permitir link a /referente/review/[id] SOLO si admin_org ya tiene acceso; si no, crear /org/review/[id]. Elegir lo que ya esté permitido por routing actual.)
  - No hacer vistas nuevas; solo link.

C) Tab “Cobertura”
- Cada fila (local + unit_order):
  - Link a /org/metrics/coverage/[programId]/[unitOrder]
    - Nueva ruta: app/org/metrics/coverage/[programId]/[unitOrder]/page.tsx
  - En detalle:
    - KPIs cobertura (de v_org_unit_coverage_30d filtrado)
    - Lista “Knowledge activo” (de v_org_unit_knowledge_active filtrado)
    - Nota: “Knowledge desactivado no aparece.”

Estados UI obligatorios:
- loading.tsx para cada nueva ruta
- empty: sin datos
- error: mensaje user-friendly

DOCS / LOG
- docs/activity-log.md: “Post-MVP5 M2 drill-down org metrics”
- docs/prompts/POST-MVP5-M2-ORG-METRICS-DRILLDOWN.md

QA / GATE
- npx supabase db reset
- Manual:
  1) Login admin_org
  2) /org/metrics abre
  3) Gaps -> click en un gap -> abre detalle por local (aunque esté vacío)
  4) Cobertura -> click en una fila -> abre detalle y lista knowledge activo (si hay)
  5) Riesgo -> click learner -> navega a detalle permitido (definir según routing)
- RLS sanity:
  - referente no debe acceder a /org/* (middleware)
- npm run lint
- npm run build

TRABAJO
- Directo sobre main.
- Fix mínimo si bloquea gates; loguear.

NOTAS DE SCOPE
- Si seed no genera filas para 30 días, debe renderizar empty state sin romper.
- No agregar seeds en M2 (si hace falta, sub-lote QA posterior).
```

Resultado esperado

Views nuevas para drill-down y rutas de detalle en /org/metrics.

Notas (opcional)

Sin notas.
