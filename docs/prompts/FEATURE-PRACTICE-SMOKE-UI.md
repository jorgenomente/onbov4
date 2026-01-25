# FEATURE-PRACTICE-SMOKE-UI

## Contexto

Agregar CTA y wiring mínimo para iniciar práctica y enviar respuestas desde /learner/training, usando server actions existentes.

## Prompt ejecutado

```txt
Sos Senior Fullstack (Next.js 16 App Router + Supabase). Continuamos el smoke test manual E2E en ONBO.

Contexto confirmado:
- Chat grounded del aprendiz ya funciona y está commiteado.
- Existe motor de práctica:
  - app/learner/training/actions.ts:
      - startPracticeScenario
      - submitPracticeAnswer
  - lib/ai/practice-evaluator.ts
- Existen tablas:
  - practice_scenarios
  - practice_attempts
  - practice_attempt_events
  - practice_evaluations
- RLS y append-only ya implementados.

Objetivo del lote:
Validar end-to-end la práctica (role-play) desde la UI del aprendiz.

Tareas exactas:
1) Revisar si en /learner/training existe un entry point visible para iniciar práctica.
   - Si existe, usarlo.
   - Si NO existe, agregar CTA mínimo (ej: botón “Iniciar práctica”) en /learner/training/page.tsx o ChatClient.tsx.
   - El CTA debe llamar startPracticeScenario (server action existente).
2) Al iniciar práctica:
   - Confirmar que se crea un registro en practice_attempts.
   - Mostrar UI mínima de práctica (estado, prompt/escenario).
3) Enviar una respuesta de prueba (“No sé”) usando submitPracticeAnswer.
4) Verificar persistencia:
   - practice_attempt_events: registra la respuesta del aprendiz.
   - practice_evaluations: registra evaluación del bot (si aplica).
5) Validar reglas:
   - El aprendiz solo ve/usa su propia práctica.
   - No hay 500.
   - Si falla el evaluator, el error se muestra de forma user-friendly (no stacktrace).

Restricciones:
- NO crear tablas nuevas.
- NO re-implementar el motor.
- NO mover lógica sensible al cliente.
- Fix mínimo orientado a smoke test.

Entrega:
- Resultado del smoke test (qué funcionó / qué faltó).
- Si falta algo, aplicar el cambio mínimo necesario (UI wiring).
- Listar archivos tocados y diff.
```

Resultado esperado
UI mínima para iniciar práctica y enviar respuestas usando el motor existente.

Notas (opcional)
N/A.
