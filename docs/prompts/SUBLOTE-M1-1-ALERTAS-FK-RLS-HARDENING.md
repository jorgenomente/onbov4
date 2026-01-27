# SUBLOTE-M1-1-ALERTAS-FK-RLS-HARDENING

## Contexto

Post-MVP 2 / Sub-lote M.1.1. Ajuste de integridad e hardening en alert_events.

## Prompt ejecutado

```txt
Audit M.1 de tu migración: APROBADA con 2 ajustes recomendados (uno crítico de integridad, uno de hardening).

Ajuste #1 (crítico): cambiar FK alert_events.learner_id a ON DELETE RESTRICT/NO ACTION (no CASCADE).
Ajuste #2 (hardening): en policy INSERT asegurar coherencia de org_id/local_id con learner_trainings/locals (no confiar en snapshots).

Se solicita micro-migración M.1.1 para aplicar ambos cambios.
```

Resultado esperado

Migración corta que actualiza FK y policy INSERT para coherencia de snapshots.

Notas (opcional)

Sin UI ni wiring.
