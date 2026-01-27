# BUGFIX-FINAL-EVAL-GATING

## Contexto

Bug de gating en /learner/final-evaluation que bloquea aun con progreso completo; se ajusta comparacion y logs.

## Prompt ejecutado

```txt
Bug: /learner/final-evaluation muestra “Completa el entrenamiento primero” aunque el demo tiene progress_percent=100 y current_unit_order=max.

Objetivo:
Encontrar qué dato usa el gating y por qué sigue bloqueando. Aplicar fix mínimo (sin tocar schema) para que “completado” sea consistente y no haya off-by-one.

Tareas:
1) Localizar la lógica de gating:
   - app/learner/final-evaluation/page.tsx
   - app/learner/final-evaluation/actions.ts
   - lib/ai/final-evaluation-engine.ts (función de gating)
   Identificar exactamente qué campos usa:
   - learner_trainings.progress_percent?
   - learner_trainings.current_unit_order?
   - v_learner_training_home?
   - max_unit_order de training_units?

2) Confirmar si hay bug off-by-one:
   - Si “completado” se representa con current_unit_order == max_unit_order, entonces la condición debe permitir >= max_unit_order.
   - Si el sistema representa “siguiente unidad” como max+1, entonces ajustar el SQL smoke o la condición, pero decidir UNO y mantenerlo consistente.

3) Fix mínimo:
   - Ajustar comparación a la convención correcta (>= vs >), y actualizar el mensaje.
   - No tocar DB schema.
   - No cambiar flujos; solo la condición.

4) Agregar logs server mínimos (solo dev):
   - cuando bloquea, loggear current_unit_order, max_unit_order, progress_percent y program_id.

Entrega:
- Diff completo.
- Explicar en 2 bullets cuál era la convención y por qué el gating ahora es correcto.
```

Resultado esperado
Ajuste minimo de gating con logs de diagnostico y sin cambios de schema.

Notas (opcional)
N/A
