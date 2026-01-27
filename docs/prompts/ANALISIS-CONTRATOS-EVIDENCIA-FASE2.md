# ANALISIS-CONTRATOS-EVIDENCIA-FASE2

## Contexto

Análisis DB-first de contratos de evidencia para panel del Referente en Fase 2, sin crear migraciones ni tocar UI.

## Prompt ejecutado

```txt
Fase 2 / Sub-lote E — Análisis de contratos de evidencia (DB-first, sin escribir código)

Contexto:
- Objetivo: armar evidencias completas para el panel del Referente sin cambiar flujos del Aprendiz.
- Restricción: SOLO análisis. NO crear migraciones, NO tocar UI, NO proponer tablas nuevas.
- Fuente de verdad: docs y schema actual del repo.

0) Leé primero estos docs (en este orden) y usalos como contrato:
- docs/roadmap-product-final.md (Fase 2)
- docs/db/dictionary.md (tablas/columns + RLS/policies + views existentes)
- docs/db/schema.public.sql (DDL canónico)
- docs/activity-log.md (qué ya se implementó + vistas existentes relevantes)
- docs/product-master.md (definiciones de roles/estados/evaluación)

1) Inspección — listá explícitamente (con nombres exactos) qué YA existe hoy para evidencia:
A) Evaluación final:
- tablas: final_evaluation_attempts, final_evaluation_questions, final_evaluation_answers, final_evaluation_evaluations
- campos relevantes (por tabla): ids, unit_order, question_type, prompt, learner_answer, score, verdict, strengths, gaps, feedback, doubt_signals, global_score, bot_recommendation, timestamps
B) Práctica:
- tablas: practice_attempts, practice_evaluations (+ si aplica practice_attempt_events)
- campos relevantes: scenario_id, learner_message_id, score/verdict/strengths/gaps/feedback/doubt_signals, timestamps
C) Conversación:
- tablas: conversations, conversation_messages, bot_message_evaluations
- campos relevantes para “evidencia” (si aplica)
D) Vistas ya existentes relacionadas a referente/review/evidence:
- v_review_queue
- v_learner_evidence
- v_referente_practice_summary
- cualquier otra view relacionada

2) Para cada entregable de Fase 2, respondé si se puede construir SOLO con lo existente:
Entregable 1: v_learner_evaluation_summary
- Qué debería resumir mínimamente (en términos de datos disponibles): por learner_id + program_id (+ attempt_id si corresponde), agregación por unit_order, cantidad de preguntas, promedio/mediana score, % correctas (según verdict), gaps/strengths agregados (si existen), y estado del intento.
- Decí “SE PUEDE” o “NO SE PUEDE”.
- Si “SE PUEDE”: enumerá exactamente qué tablas/columns lo soportan.
- Si “NO SE PUEDE”: enumerá exactamente qué dato falta (columna inexistente o relación faltante).

Entregable 2: v_learner_wrong_answers
- Definición operativa: “wrong” = verdict != 'pass' (o el valor real que use el sistema; verificá enums/texto).
- Debe devolver: learner_id, attempt_id, unit_order, question_id, prompt, learner_answer, score, verdict, gaps, feedback, created_at (y lo que sea imprescindible).
- Decí “SE PUEDE” / “NO SE PUEDE” y justificá con tablas/columns exactos.

Entregable 3: v_learner_doubt_signals
- Fuente esperada: doubt_signals (arrays) en practice_evaluations y final_evaluation_evaluations (confirmar).
- Definí: agregación por learner_id + unit_order (conteo por tipo de señal), última ocurrencia, total.
- Decí “SE PUEDE” / “NO SE PUEDE”.
- Si ya hay una vista que lo aproxima (ej: v_learner_evidence), describí exactamente qué falta para cumplir el entregable de Fase 2.

3) RLS / Alcance (solo análisis)
- Confirmá si las tablas/vistas necesarias ya tienen policies SELECT que:
  - referente: solo su local
  - admin_org: solo su org
  - aprendiz: no debe acceder a estas nuevas vistas (si ya puede leer algo, señalarlo)
- Si detectás un gap de RLS (p.ej. view nueva necesitaría SELECT sobre tablas sin policy suficiente), anotá el gap, sin proponer solución todavía.

4) Output requerido (formato)
Devolvé SOLO este reporte, en bullets, sin UI, sin SQL:

- “Inventario de fuentes” (tablas + views relevantes)
- “Mapeo por entregable” (summary / wrong_answers / doubt_signals)
- “Gaps exactos” (si existen)
- “Riesgos RLS exactos” (si existen)
- “Recomendación de mínimos” (si hay varias opciones, elegí la más DB-first y simple, pero sin escribir SQL)

Recordatorio: NO escribir migraciones, NO crear views todavía, NO tocar UI.
```

Resultado esperado
Reporte de análisis DB-first usando docs y schema actuales.

Notas (opcional)
N/A
