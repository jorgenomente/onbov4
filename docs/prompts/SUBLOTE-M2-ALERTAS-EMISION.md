# SUBLOTE-M2-ALERTAS-EMISION

## Contexto

Post-MVP 2 / Sub-lote M.2. Emision de alert_events desde acciones existentes (sin notificar, sin UI).

## Prompt ejecutado

```txt
Post-MVP 2 / Sub-lote M.2 — Emisión de alert_events desde acciones existentes (sin notificar, sin UI)

Contexto:
Ya existe public.alert_events (append-only + RLS hardened) y Validación humana v2 (submitReviewValidationV2).

Objetivo:
Emitir registros en alert_events en momentos clave, de forma server-only, derivando org_id/local_id
desde learner_trainings/locals (no confiar en input), sin enviar emails ni notificaciones.

Reglas:
- NO migraciones DB.
- NO UI.
- NO emails/alertas externas (eso es M.3/M.4 si existiera; hoy no).
- Zero Trust: inserts a alert_events solo desde server actions / backend.
- Append-only: nunca update/delete.
- No cambiar estados del learner.

Tareas:

A) Hook en submitReviewValidationV2
1) Después de insertar learner_review_validations_v2, insertar 1+ alert_events:
   - Siempre insertar: alert_type = 'review_submitted_v2'
   - Si decision_type = 'reject' -> insertar además 'review_rejected_v2'
   - Si decision_type = 'request_reinforcement' -> insertar además 'review_reinforcement_requested_v2'
   - Si decision_type = 'approve' -> no insertar extra (solo submitted)

2) Campos alert_events:
   - learner_id: el learner validado
   - org_id/local_id: derivados server-side desde learner_trainings + locals (coherentes)
   - source_table: 'learner_review_validations_v2'
   - source_id: id de la fila v2 recién creada
   - payload: jsonb con snapshot mínimo no sensible:
       { "decision_type": "...", "perceived_severity":"...", "recommended_action":"..." }

B) Evento final_evaluation_submitted
1) Identificar el punto server-side donde se finaliza/submit una evaluación final (attempt ends/submitted)
   sin inventar flujos nuevos.
2) Al ocurrir, insertar un alert_events con:
   - alert_type = 'final_evaluation_submitted'
   - source_table = 'final_evaluation_attempts'
   - source_id = attempt.id
   - payload mínimo: { "attempt_number": n, "program_id": "...", "status": "..." }
   - org_id/local_id derivados por learner_trainings (usando learner_id + program_id si aplica)

C) QA manual (mínimo):
- Como referente: enviar validación v2 y verificar que se crean 1 o 2 filas en alert_events.
- Como aprendiz: verificar que puede SELECT solo sus eventos.
- Confirmar que NO hay emails ni cambios de estado.

Entregables:
- Cambios en server actions/backend correspondientes
- docs/activity-log.md actualizado con M.2 + pasos QA
- (opcional) docs/qa/smoke-m2.sql para validar SELECT/INSERT vía RLS si aplica
```

Resultado esperado

Emision de eventos en alert_events desde v2 y final evaluation, sin notificaciones.

Notas (opcional)

Sin UI ni migraciones.
