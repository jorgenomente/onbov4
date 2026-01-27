# SUBLOTE-L3-UI-VALIDACION-HUMANA-V2

## Contexto

Post-MVP 2 / Sub-lote L.3. UI Referente para capturar validacion humana v2 usando Server Action existente.

## Prompt ejecutado

```txt
Post-MVP 2 / Sub-lote L.3 — UI Referente: Captura Validación humana v2 (mínimo) + uso de Server Action (sin cambiar estados)

Contexto:
Ya existe la tabla learner_review_validations_v2 (append-only + RLS) y el wiring server-only
submitReviewValidationV2 en app/referente/review/actions.ts. También existe smoke reproducible en docs/qa/smoke-l2.sql.

Objetivo:
Agregar UI mínima en el detalle de revisión del Referente/Admin para capturar una validación v2 estructurada y persistirla
vía submitReviewValidationV2.

Reglas (NO NEGOCIABLE):
- NO migraciones DB.
- NO cambiar estados del learner (seguimos usando el flujo actual; v2 es “paralela”).
- NO enviar emails ni alertas (eso es Sub-lote M).
- DB-first / RLS-first: la UI solo llama al server action; nada de writes directos desde el cliente.
- UX mínima, mobile-first, sin overengineering.
- Append-only: si ya existe una validación v2, NO se edita; se crea otra (si el usuario insiste).
- No romper v1: mantener botones/acciones actuales de approve/refuerzo si existen.

Tareas:

1) Ubicación:
   En la pantalla de detalle del learner en revisión:
   /referente/review/[learnerId] (o la ruta equivalente actual),
   agregar un bloque “Validación v2 (interna)”.

2) Form mínimo (inputs):
   - decision_type (select): approve | reject | request_reinforcement
   - perceived_severity (select): low | medium | high (default low)
   - recommended_action (select): none | follow_up | retraining (default none)
   - checklist: por ahora UI simple con 3 checkboxes fijas (placeholder rubric),
     guardadas como JSON object, ej:
       {
         "covered_core_concepts": true/false,
         "handled_objections": true/false,
         "communication_clarity_ok": true/false
       }
     (IMPORTANTE: no diseñar rubric final; es solo scaffold para escribir JSON estable)
   - comment (textarea opcional)

3) Submit:
   - Al enviar, llamar submitReviewValidationV2({ learnerId, decisionType, perceivedSeverity, recommendedAction, checklist, comment })
     (respetar nombres exactos del action; si difieren, adaptar UI a la firma real)
   - Mostrar estados UI: loading, success, error (mensaje claro)
   - Al éxito: revalidar la ruta y mostrar la validación recién creada en un “Historial v2” (lista simple)

4) Lectura (Historial v2):
   - Mostrar últimas N validaciones v2 (N=5) para ese learner, orden desc por created_at:
     campos: created_at, reviewer_name, reviewer_role, decision_type, perceived_severity, recommended_action, comment (si existe)
   - NO mostrar checklist detallado al learner (esto es UI referente, ok mostrarlo aquí).
   - Fuente de datos: query server-side a learner_review_validations_v2 (RLS ya aplica).

5) Acceso:
   - Solo roles: referente y admin_org y superadmin.
   - Aprendiz nunca ve esto.
   - Si el viewer no tiene acceso, mostrar 404 o “No autorizado” fail-closed (según convención existente).

6) QA manual:
   - Logueado como referente@demo.com:
     - abrir learner en revisión
     - enviar validación v2 (debe aparecer en historial)
   - Logueado como aprendiz@demo.com:
     - no debe poder ver el bloque v2 ni acceder a la ruta.
   - Confirmar que botones v1 siguen funcionando igual.

Entregables:
- Cambios en la página de detalle de revisión (UI)
- Si hace falta, componentes mínimos (sin sobre-abstracción)
- docs/activity-log.md actualizado con Sub-lote L.3 + pasos QA

NO implementar alertas, ni cambios de estados, ni rubric final.
```

Resultado esperado

UI minima en /referente/review/[learnerId] para capturar validacion v2, con historial v2 y estados UI.

Notas (opcional)

Sin cambios de DB ni estados.
