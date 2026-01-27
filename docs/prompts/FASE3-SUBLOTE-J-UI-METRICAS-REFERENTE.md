# FASE3-SUBLOTE-J-UI-METRICAS-REFERENTE

## Contexto

UI de métricas accionables para Referente usando views de Fase 3 (read-only) en /referente/review y /referente/review/[learnerId].

## Prompt ejecutado

```txt
Fase 3 / Sub-lote J — UI Referente: métricas accionables (lectura)

Objetivo:
Exponer las 3 métricas nuevas (views) en la UX del Referente sin agregar acciones ni complejidad.

Alcance (cerrado):
- 1 bloque “Métricas (30 días)” en /referente/review
  - Top gaps del local (v_local_top_gaps_30d) — tabla top 10
  - Riesgo por aprendiz (v_local_learner_risk_30d) — semáforo + razones (máx 2) + link al detalle
- 1 bloque “Cobertura (30 días)” en /referente/review/[learnerId]
  - unit coverage (v_local_unit_coverage_30d) — tabla por unit_order
- Mobile-first, lectura clara, sin charts (MVP).

Reglas:
- RSC + @supabase/ssr (server-side queries).
- Nada de lógica sensible en frontend (solo render).
- No cambiar flujos del Aprendiz.
- No agregar botones de acción nuevos.

Implementación:
1) /referente/review (lista):
   - Query v_local_top_gaps_30d: select gap, count_total, learners_affected, percent_learners_affected, last_seen_at
     order by count_total desc limit 10
   - Query v_local_learner_risk_30d:
     select learner_id, risk_level, reasons, last_activity_at, failed_practice_count, failed_final_count, doubt_signals_count
     order by (risk_level desc), last_activity_at desc
   - Render:
     - Tabla gaps
     - Lista learners con badge (high/medium/low) + “razones” (2) + link a /referente/review/[learnerId]

2) /referente/review/[learnerId] (detalle):
   - Query v_local_unit_coverage_30d:
     select unit_order, avg_practice_score, avg_final_score, practice_fail_rate, final_fail_rate, top_gap
     order by unit_order asc
   - Render tabla “Cobertura (30 días)”

QA:
- npx supabase db reset
- npm run lint
- npm run build
- 1 E2E Playwright:
  - login referente
  - abrir /referente/review y ver “Métricas (30 días)”
  - abrir un learner y ver “Cobertura (30 días)”

Entregables:
- app/referente/review/page.tsx (o ruta actual equivalente)
- app/referente/review/[learnerId]/page.tsx (extensión, sin romper evidencia previa)
- e2e/referente-metrics.spec.ts
- docs/activity-log.md (Sub-lote J + QA)
```

Resultado esperado
UI de métricas para referente + test e2e + QA registrado.

Notas (opcional)
N/A
