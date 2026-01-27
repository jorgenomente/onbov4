# FIX-FINAL-EVAL-SSR-CLIENT

## Contexto

Insert de final_evaluation_answers falla por uso de cliente Supabase sin sesion; se debe pasar el client SSR autenticado al engine.

## Prompt ejecutado

```txt
Bug: submitFinalAnswer sigue lanzando Forbidden aunque:
- attempt existe, es in_progress y pertenece al learner
- question pertenece al attempt
- RLS y datos verificados OK

Causa raíz:
El guard basado en `questionAttempt` es redundante y frágil.
`questionAttempt` puede venir null aunque attempt y question sean válidos,
provocando Forbidden incorrecto.

Objetivo:
Eliminar completamente la dependencia de `questionAttempt` y validar solo con:
- attempt (resuelto server-authoritative)
- question
- relación: question.attempt_id === attempt.id

Tareas:
1) Abrir lib/ai/final-evaluation-engine.ts
2) Ubicar submitFinalAnswer
3) Eliminar:
   - el query que produce `attempts?.[0]` / `questionAttempt`
   - el guard:
     if (!questionAttempt || questionAttempt.learner_id !== userId) Forbidden
     if (questionAttempt.status !== 'in_progress')
4) Mantener solo:
   - carga de attempt por attemptId
   - carga de question por questionId
   - validación:
     if (question.attempt_id !== attempt.id) throw new Error('Invalid attempt')
5) Agregar log DEV (no prod):
   console.info('final-eval submit debug', {
     attemptId: attempt.id,
     questionId,
     questionAttemptId: question.attempt_id
   })
6) No tocar schema, RLS ni seeds.

Validación esperada:
- Enviar respuesta inserta final_evaluation_answers
- answers_count > 0
- No aparece Forbidden
- El attempt sigue in_progress hasta finalizar

Entrega:
- Diff completo
- Breve explicación del cambio
```

Resultado esperado
Engine usa Supabase SSR client con sesion para inserts y evita RLS anon.

Notas (opcional)
N/A
