# HARDEN-FINAL-EVAL-ATTEMPT-RESOLVE

## Contexto

Evitar race/stale al resolver intento activo en submit/finalize de evaluación final.

## Prompt ejecutado

```txt
Hardening: evitar race/stale al resolver attempt activo para submit/finalize.

Problema:
En actions.ts se llama submitFinalAnswer() y luego se vuelve a resolver el attempt activo
(getActiveAttemptId). Si submitFinalAnswer o el flujo cambia el status del attempt, el segundo
lookup puede fallar ("No active final evaluation attempt"). Además hay duplicación de lógica
entre actions.ts y engine.ts.

Objetivo:
Resolver attempt activo 1 vez y usarlo en todo el flujo.

Cambios:
1) En app/learner/final-evaluation/actions.ts:
   - Mover `const activeAttemptId = await getActiveAttemptId();` AL PRINCIPIO de
     submitFinalAnswerAction (antes de submitFinalAnswer).
   - Pasar activeAttemptId a submitFinalAnswer como parámetro opcional/required (ver punto 2),
     o alternativamente, eliminar getActiveAttemptId y dejar toda la resolución en engine,
     pero entonces NO volver a consultar in_progress después del submit.
   - Para contar preguntas y para finalizeAttempt usar SIEMPRE el attemptId resuelto al inicio,
     no uno recalculado.
2) En lib/ai/final-evaluation-engine.ts:
   Opción preferida:
   - Aceptar input: { attemptId: string, questionId: string, learnerAnswer: string }
   - NO derivar attempt dentro del engine (lo hace actions.ts).
   - Validar que attemptId pertenece al learner y status in_progress.
   - Validar que question.attempt_id = attemptId.
   - Mantener el guard Forbidden si no coincide.
   Alternativa (si querés derivar en engine):
   - Devolver también attemptId usado, para que actions.ts no lo vuelva a derivar.
3) Logs DEV:
   - Loguear derivedAttemptId una sola vez.
4) Validación manual:
   - Iniciar evaluación final
   - Responder 2 preguntas
   - Refresh entre medio
   - Terminar evaluación
   - No debe aparecer "Forbidden" ni "No active final evaluation attempt"

Entrega:
- Diff completo
- Explicación breve del cambio y por qué elimina el race
```

Resultado esperado
Resolución de attempt única por request y sin doble lookup in_progress.

Notas (opcional)
N/A
