# QA-VERIFICACION-FINAL-POST-FIX

## Contexto

Verificacion final post-fix con reset de DB, login por curl via GoTrue y chequeo de data demo minima.

## Prompt ejecutado

```txt
Verificación final post-fix (demo seed + gotrue).

1) Ejecutar:
   - npx supabase db reset

2) Verificar login por curl:
   - aprendiz@demo.com / prueba123
   - referente@demo.com / prueba123
   - admin@demo.com / prueba123
   - superadmin@onbo.dev / prueba123

3) Verificar que existe data demo mínima:
   - training_programs, training_units
   - knowledge_items + unit_knowledge_map
   - learner_trainings
   - practice_scenarios

4) Reportar resultados (OK/FAIL) con queries usadas.
No tocar código.
```

Resultado esperado
Reporte de OK/FAIL con comandos y queries usadas sin modificar codigo.

Notas (opcional)
Se requiere conocer endpoint local de GoTrue y credenciales del proyecto para curl.
