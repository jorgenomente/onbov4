# SUBLOTE-F1-SEED-CROSS-TENANT

## Contexto

Seed cross-tenant mínimo para probar leakage entre Local A y Local B con views de evidencia.

## Prompt ejecutado

```txt
Sub-lote F.1 — Seed cross-tenant para prueba concluyente (mínimo, idempotente).

Objetivo: crear un 2do local en la misma org demo (Local B) + 1 aprendiz y 1 referente asociados,
+ learner_trainings para el aprendiz B, + 1 practice_attempt/evaluation y 1 final_evaluation attempt/question/answer/eval
en el Local B, para poder probar que Referente A NO ve evidencia del Local B.

Reglas:
- SOLO agregar una migración de seed idempotente.
- Usar el patrón existente de seed de auth.users + auth.identities + public.profiles (ver 20260125201500_l9_demo_seed_full.sql).
- No tocar UX ni lógica app.
- Re-correr db reset y ejecutar los 2 queries de leakage (local A vs local B) dejando resultados en docs/activity-log.md.

Entregables:
- supabase/migrations/YYYYMMDDHHMMSS_seed_cross_tenant_evidence.sql
- docs/activity-log.md con resultados counts (local A vs B).

Modelo de migracion de referencia incluido en el prompt.
```

Resultado esperado
Migración seed cross-tenant aplicada, docs/db regenerados y leakage checks registrados.

Notas (opcional)
N/A
