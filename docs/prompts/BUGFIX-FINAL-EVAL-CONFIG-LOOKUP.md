# BUGFIX-FINAL-EVAL-CONFIG-LOOKUP

## Contexto

Bug critico: gating de evaluacion final bloquea con config_missing pese a existir config; se pide lookup deterministico y logs dev.

## Prompt ejecutado

```txt
Bug crítico: final-evaluation gating bloquea con reason 'config_missing'
aunque existe una fila en final_evaluation_configs para el program_id.

Causa raíz:
El engine usa maybeSingle() al leer final_evaluation_configs.
maybeSingle() devuelve null tanto si:
- no hay filas
- hay MÁS DE UNA fila
Esto provoca falsos negativos silenciosos.

Objetivo:
Hacer el lookup robusto y determinístico sin cambiar schema.

Tareas:
1) Abrir lib/ai/final-evaluation-engine.ts.
2) Reemplazar el select a final_evaluation_configs:
   - NO usar maybeSingle().
   - Usar:
     .eq('program_id', training.program_id)
     .order('created_at', { ascending: false })
     .limit(1)
     .maybeSingle()
3) Loggear en DEV si error != null para diagnóstico futuro.
4) Mantener el gating exacto (si no hay fila → config_missing).
5) No tocar DB, seeds ni RLS.

Validación:
- npx supabase db reset
- Login aprendiz demo
- /learner/final-evaluation YA NO bloquea por config_missing
- El intento se puede iniciar correctamente.

Entrega:
- Diff completo
- Explicación breve del fix (1 párrafo)
```

Resultado esperado
Lookup de config deterministico con logging dev sin cambios de schema.

Notas (opcional)
N/A
