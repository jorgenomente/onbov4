# FASE2-SUBLOTE-F-VIEWS-EVIDENCIA-RLS

## Contexto

El usuario propone SQL para crear views de evidencia y endurecer RLS en final*evaluation*\*.

## Prompt ejecutado

```txt
Fase 2 / Sub-lote F — Views de evidencia + hardening RLS (read-only)

- Crea:
  - v_learner_evaluation_summary
  - v_learner_wrong_answers
  - v_learner_doubt_signals

- Endurece RLS (evita cross-tenant) en:
  - final_evaluation_questions
  - final_evaluation_answers
  - final_evaluation_evaluations

Nota:
- Estas views NIEGAN aprendiz por definición (no RLS en views),
  y filtran por local/org usando current_local_id/current_org_id.

[SQL provisto]
```

Resultado esperado
Definir si aplicar como migración/changes y revisar impacto.

Notas (opcional)
N/A
