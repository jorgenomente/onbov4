# POST-MVP5 QA SMOKE M1 M5

## Contexto

QA DB-first para Post-MVP5: crear y ejecutar smokes M1–M5.

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

Smokes Post-MVP5 creados y ejecutados con evidencia.

Notas (opcional)

Sin notas.
