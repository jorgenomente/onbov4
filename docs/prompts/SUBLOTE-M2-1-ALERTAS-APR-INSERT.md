# SUBLOTE-M2-1-ALERTAS-APR-INSERT

## Contexto

Post-MVP 2 / Sub-lote M.2.1. Remover service_role y permitir INSERT de aprendiz para final_evaluation_submitted.

## Prompt ejecutado

```txt
Se detecta uso de service_role en M.2. Se requiere removerlo y agregar policy limitada para aprendiz:
- Solo alert_type = final_evaluation_submitted
- learner_id = auth.uid()
- source_table = final_evaluation_attempts
- source_id pertenece al learner
- org_id/local_id coherentes con learner_trainings/locals
```

Resultado esperado

Micro-migracion con policy de insert para aprendiz y wiring usando supabase SSR client.

Notas (opcional)

Sin UI ni notificaciones.
