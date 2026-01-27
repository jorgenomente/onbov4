# BUGFIX-FINAL-EVAL-CONFIG-MISSING-RUNTIME

## Contexto

Diagnostico runtime de config_missing en evaluacion final y fix minimo.

## Prompt ejecutado

```txt
Bug: /learner/final-evaluation sigue mostrando “No hay configuración…” y logs dicen
final-evaluation gating blocked reason='config_missing', aunque DB está OK (audit SQL):
- config_rows_total=1, readiness OK, cooldown OK, progress=100, unit_order=max.

Objetivo:
Diagnosticar en runtime por qué loadFinalConfig no devuelve data y aplicar fix mínimo.

Tareas:
1) Abrir lib/ai/final-evaluation-engine.ts y localizar loadFinalConfig(programId, ...) (o el helper equivalente).
2) Instrumentar DEV-only (NODE_ENV !== 'production') para loguear:
   - programId recibido
   - filtros EXACTOS aplicados en la query (si usa algo extra además de program_id)
   - resultado del query principal: { data, error }
   - y un conteo con los mismos filtros:
     const { count, error: countError } = await supabase
       .from('final_evaluation_configs')
       .select('id', { count: 'exact', head: true })
       ...mismos filtros...
   Loguear { count, countError } también.
3) Revisar si hay filtros extra (local_id/org_id/is_active/status/etc) o si consulta una tabla/view distinta.
4) Fix mínimo según lo que se vea en logs:
   A) Si hay filtro extra incorrecto -> eliminarlo (dejar solo eq('program_id', programId)).
   B) Si está apuntando a una tabla/view equivocada -> apuntar a public.final_evaluation_configs.
   C) Si hay error silencioso -> loguearlo y corregir la causa (p.ej. typo de columna).
5) Validación:
   - Reiniciar dev server
   - Visitar /learner/final-evaluation como aprendiz demo (con progress=100)
   - Ver en logs que count=1 y data no es null
   - UI permite iniciar intento (ya no muestra config_missing)

Entrega:
- Diff completo
- Causa raíz encontrada (1 párrafo)
- Fix mínimo aplicado (1 párrafo)
```

Resultado esperado
Logs dev de lookup y correccion minima para evitar config_missing.

Notas (opcional)
N/A
