# POST-MVP5 M5 ACTION OUTCOMES

## Contexto

Sub-lote M5: cierre de loop 7d vs 30d y smoke QA DB-first Post-MVP5.

## Prompt ejecutado

```txt
# Post-MVP 5 — Sub-lote M5 (Read-only): Cierre de loop “Mejora vs 30d” + Smoke QA DB-first Post-MVP5

OBJETIVO (M5)
Completar el ciclo medir → actuar → verificar, sin writes:
- Mostrar en /org/metrics (Resumen) si las acciones sugeridas están:
  - Mejorando
  - Sin cambios
  - Empeorando
Comparando señales en ventana corta vs ventana larga.

Además (QA):
- Crear y correr smokes DB-first para Post-MVP5 (M1–M5) y dejar evidencia.

RESTRICCIONES (NO NEGOCIABLES)
- Solo lectura: views + UI. Sin tablas nuevas. Sin RPC writes.
- No tocar engine/chat.
- No inventar fuentes: reutilizar views existentes de Post-MVP5.
- Multi-tenant estricto: admin_org solo su org; superadmin todo.
- No usar service_role.
- Nada de select *.

---------------------------------------------
PARTE 1 — M5 (IMPLEMENTACIÓN)
---------------------------------------------

A) DB — 1 migración (views)
Crear migración:
- supabase/migrations/YYYYMMDDHHMMSS_post_mvp5_m5_action_outcomes.sql

1) View: public.v_org_actions_outcomes_30d
Propósito:
- Para cada action_key de acciones sugeridas (top_gap / low_coverage / learner_risk), calcular un “trend”:
  - improving | stable | worsening
Comparación:
- Corto: últimos 7 días
- Largo: últimos 30 días (ya usado)

Columnas (contrato):
- org_id uuid
- action_key text
- trend text  -- 'improving'|'stable'|'worsening'
- delta_score numeric  -- score_7d - score_30d (signo consistente)
- score_7d numeric
- score_30d numeric
- sample_size_30d int
- computed_at timestamptz

Reglas determinísticas por action_key (NO inventar, usar inputs reales):
- top_gap:
  - score = percent_learners_affected (o learners_affected_count normalizado) desde:
    - v_org_top_gaps_30d (30d)
    - y crear un análogo 7d basado en la MISMA fuente:
      - Si hay una base table o view local que filtra por fecha, crear:
        - v_org_top_gaps_7d (en esta misma migración) o CTE dentro de outcomes
      - Si NO hay forma de derivar 7d sin inventar: fallback seguro:
        - score_7d = NULL, trend='stable' y reason en UI (“insuficiente señal 7d”)
- low_coverage:
  - score = avg(coverage_percent) en org (o % filas < umbral) desde:
    - v_org_unit_coverage_30d
    - análogo 7d si se puede derivar de la misma base; si no, fallback como arriba
- learner_risk:
  - score = count(learners con riesgo high/medium) o avg(risk_score) desde:
    - v_org_learner_risk_30d
    - análogo 7d si existe fuente; si no, fallback

Trend mapping (simple y explicable):
- if score_7d is null or score_30d is null -> trend='stable'
- else:
  - Para métricas “malas” (gaps, riesgo): si score_7d < score_30d - epsilon => improving
  - si score_7d > score_30d + epsilon => worsening
  - else stable
Usar epsilon pequeño (ej 0.5 para percent, 1 para counts) según unidades reales.

IMPORTANTE:
- No cambies M1–M4.
- Si necesitás crear views 7d, hacelo en esta migración solo si hay fuente real (misma tabla base o view con timestamp).

2) (Opcional) View: public.v_org_recommended_actions_playbooks_with_outcomes_30d
- Join de:
  - v_org_recommended_actions_playbooks_30d (M4)
  - v_org_actions_outcomes_30d (M5)
- Para que UI consuma todo junto.
Columnas:
- Todas las de playbooks + outcome fields (trend, delta_score, score_7d/30d)

RLS / Guardrails
- SECURITY INVOKER.
- Filtrar roles en view:
  where current_role() in ('admin_org','superadmin')
- admin_org: org_id = current_org_id(); superadmin sin filtro org_id.

Regenerar docs DB:
- npx supabase db reset
- npm run db:dictionary
- npm run db:dump:schema

B) UI — /org/metrics (Resumen)
Modificar el bloque “Acciones sugeridas”:
- Mostrar badge outcome:
  - “Mejorando” (improving)
  - “Sin cambios” (stable)
  - “Empeoró” (worsening)
- Mostrar microtexto explicable:
  - “Últimos 7d vs 30d”
  - Si score_7d NULL: “Sin señal suficiente 7d”
- No gráficos. Mobile-first.

Estados:
- Si outcomes view falla o devuelve vacío, no romper: ocultar badge y seguir mostrando playbook.

Gates:
- npm run lint
- npm run build

Commit:
- feat(post-mvp5): action outcomes + loop closure (read-only)
Push:
- origin/main

---------------------------------------------
PARTE 2 — QA DB-FIRST (SMOKE) POST-MVP5
---------------------------------------------

OBJETIVO
Crear smokes reproducibles (DB-first) para Post-MVP5:
- M1, M2, M3, M4, M5
Ejecutarlos localmente y registrar evidencia.

Archivos nuevos (docs/qa/):
- docs/qa/smoke-post-mvp5-m1.sql
- docs/qa/smoke-post-mvp5-m2.sql
- docs/qa/smoke-post-mvp5-m3.sql
- docs/qa/smoke-post-mvp5-m4.sql
- docs/qa/smoke-post-mvp5-m5.sql

Reglas smoke:
- NO requieren que haya filas: deben validar que:
  - SELECT no rompe por RLS
  - columnas esperadas existen
  - filtros por rol funcionan (admin_org ok)
- Usar psql con SET ROLE authenticated + request.jwt.claims (admin_org demo), como los smokes anteriores.

Contenido mínimo por smoke:

Smoke M1:
- SELECT 1 fila (LIMIT 1) o count(*) desde:
  - v_org_top_gaps_30d
  - v_org_learner_risk_30d
  - v_org_unit_coverage_30d
- Debe ejecutar sin error.

Smoke M2:
- SELECT desde:
  - v_org_gap_locals_30d (LIMIT 1)
  - v_org_unit_knowledge_active (LIMIT 1)
- Debe ejecutar sin error.

Smoke M3:
- SELECT desde:
  - v_org_recommended_actions_30d (LIMIT 10)
- Validar que cta_href no sea null (si hay filas) con un WHERE cta_href is null (debe devolver 0 o no filas).

Smoke M4:
- SELECT desde:
  - v_org_recommended_actions_playbooks_30d (LIMIT 10)
- Validar que checklist sea array (si hay filas) con jsonb_typeof(to_jsonb(checklist)) = 'array' (si aplica en SQL) o simplemente seleccionar.

Smoke M5:
- SELECT desde:
  - v_org_actions_outcomes_30d (LIMIT 10)
  - (si existe) v_org_recommended_actions_playbooks_with_outcomes_30d (LIMIT 10)
- Validar que trend esté en ('improving','stable','worsening') si hay filas.

Ejecución smoke (local):
- npx supabase db reset
- psql ... -f docs/qa/smoke-post-mvp5-m1.sql
- psql ... -f docs/qa/smoke-post-mvp5-m2.sql
- psql ... -f docs/qa/smoke-post-mvp5-m3.sql
- psql ... -f docs/qa/smoke-post-mvp5-m4.sql
- psql ... -f docs/qa/smoke-post-mvp5-m5.sql
- npm run lint
- npm run build

Evidencia:
- Agregar entrada en docs/activity-log.md:
  - “QA DB-first Post-MVP5 (M1–M5)”
  - PASS/FAIL por smoke
  - Notas (si M5 cae en fallback por falta de señal 7d, documentarlo)

Commit QA:
- docs(post-mvp5): add + run db-first smokes m1-m5
Push:
- origin/main

IMPORTANTE
- Si M5 no puede computar 7d por falta de fuente temporal real, implementar fallback explícito y documentarlo (NO inventar).
```

Resultado esperado

View outcomes + UI badges + smokes Post-MVP5 creados y ejecutados.

Notas (opcional)

Sin notas.
