# SUBLOTE-G-UI-REFERENTE-EVIDENCIA

## Contexto

Extender UI /referente/review/[id] para mostrar evidencia desde views de Fase 2, más test e2e.

## Prompt ejecutado

```txt
Fase 2 / Sub-lote G — UI Referente (lectura) usando evidence views.

Objetivo: extender /referente/review/[id] para mostrar evidencia accionable sin agregar acciones.

1) Implementar 3 bloques:
   A) Resumen por unidad (v_learner_evaluation_summary)
   B) Respuestas fallidas (v_learner_wrong_answers)
   C) Señales (v_learner_doubt_signals)

2) Reglas:
   - Mobile-first, lectura clara.
   - No agregar botones de acción nuevos.
   - No tocar UX del aprendiz.
   - Consultas via supabase server (RSC) usando @supabase/ssr y session server-authoritative.

3) QA:
   - 1 test Playwright: login referente, abrir review y verificar que existen los 3 headers.
   - db reset, lint, build.

Entregables:
- cambios UI en app/referente/review/[id]/*
- e2e/playwright test nuevo
- docs/activity-log.md actualizado (Sub-lote G)
```

Resultado esperado
UI de evidencia para referente + test e2e + logs.

Notas (opcional)
N/A
