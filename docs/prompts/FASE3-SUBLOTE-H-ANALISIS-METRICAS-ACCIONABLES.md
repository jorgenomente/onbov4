# FASE3-SUBLOTE-H-ANALISIS-METRICAS-ACCIONABLES

## Contexto

Análisis DB-first de métricas accionables para Referente usando datos existentes (sin migraciones ni UI).

## Prompt ejecutado

```txt
Fase 3 / Sub-lote H — Análisis DB-first de métricas accionables (sin escribir código)

Objetivo:
Definir el alcance mínimo de “métricas accionables” para Referente usando SOLO datos existentes (practice + final eval + evidence views).
Resultado esperado: lista corta de contratos (views) + qué pantallas las consumen. NO implementar aún.

Reglas:
- SOLO análisis. NO migraciones. NO UI.
- DB-first / RLS-first.
- Nada de dashboards complejos: métricas confiables y accionables.

1) Leé primero (contrato):
- docs/roadmap-product-final.md (Fase 3)
- docs/activity-log.md (Fase 2 cerrado)
- docs/db/dictionary.md + docs/db/schema.public.sql

2) Inventario de fuentes disponibles (confirmar con nombres exactos):
- practice_* (attempts/evaluations/scenarios)
- final_evaluation_* (attempts/questions/answers/evaluations)
- views nuevas: v_learner_evaluation_summary, v_learner_wrong_answers, v_learner_doubt_signals
- views existentes relevante: v_review_queue, v_referente_practice_summary, v_referente_learners, etc.

3) Proponer (solo en papel) 3 contratos mínimos de métricas, todos read-only y tenant-scoped:
A) “Top gaps del local (últimos 30 días)”
   - agregación por gap string
   - métricas: count, % learners afectados, last_seen_at
   - fuentes: practice_evaluations.gaps + final_evaluation_evaluations.gaps
B) “Riesgo por aprendiz (semaforización simple)”
   - por learner_id: failed_practice_count, failed_final_count, doubt_signals_count, last_activity_at
   - regla explícita (sin inferencia opaca): thresholds simples documentados (ej: >=3 fails = alto)
   - salida: risk_level (low/med/high) + razones (array)
C) “Cobertura por unidad (local)”
   - por unit_order: avg_score práctica, avg_score final, fail_rate, top_gap
   - fuentes: practice_scenarios.unit_order + practice_evaluations.score/verdict; final_* unit_order + score/verdict

4) Para cada contrato, responder:
- ¿Se puede construir solo con lo existente? (sí/no)
- Tablas/columns exactos a usar
- Qué filtros tenant se deben aplicar (referente local / admin org)
- Índices recomendables si hay riesgo (solo sugerir, no crear)

5) Output final (solo texto, en bullets):
- “3 contratos propuestos” (A/B/C)
- “Campos exactos por contrato”
- “Riesgos RLS / performance”
- “Siguiente sub-lote recomendado” (I = views, J = UI, K = QA)
```

Resultado esperado
Reporte de análisis de contratos de métricas accionables (DB-first).

Notas (opcional)
N/A
