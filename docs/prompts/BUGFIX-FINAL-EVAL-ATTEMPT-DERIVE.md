# BUGFIX-FINAL-EVAL-ATTEMPT-DERIVE

## Contexto

El submit de evaluacion final falla con Forbidden por attemptId stale; se debe derivar el intento activo en servidor.

## Prompt ejecutado

```txt
Bug confirmado: submitFinalAnswer lanza "Forbidden" porque el attemptId recibido
desde el cliente es stale/viejo/incorrecto. RLS está OK.

Objetivo:
Eliminar la dependencia del attemptId del cliente y derivar siempre el attempt
activo desde el servidor.

Tareas:
1) Abrir lib/ai/final-evaluation-engine.ts y ubicar submitFinalAnswer().
2) Identificar dónde se recibe attemptId (params o input).
3) Fix estructural:
   - Ignorar el attemptId del cliente.
   - Derivar el attempt activo con:
     select *
     from final_evaluation_attempts
     where learner_id = auth.uid()
       and status = 'in_progress'
     order by created_at desc
     limit 1
   - Si no existe → error claro "No active final evaluation attempt".
4) Validar que:
   - el attempt pertenece al learner (implícito por query)
   - el status sea in_progress
5) Usar ese attempt.id para:
   - validar question_id
   - insertar final_evaluation_answers
6) (Opcional, recomendado) Agregar log DEV:
   - attemptId recibido (si existe)
   - attemptId derivado
7) Ajustar app/learner/final-evaluation/actions.ts si estaba pasando attemptId innecesariamente.
8) Validación manual:
   - Iniciar evaluación final
   - Responder varias preguntas
   - Refresh intermedio
   - Enviar respuesta → NO Forbidden

Entrega:
- Diff completo
- Explicación breve de la causa raíz
```

Resultado esperado
Submit usa intento activo del servidor y evita Forbidden por attemptId stale.

Notas (opcional)
N/A
