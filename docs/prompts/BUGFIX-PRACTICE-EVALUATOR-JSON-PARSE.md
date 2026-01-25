# BUGFIX-PRACTICE-EVALUATOR-JSON-PARSE

## Contexto

Bug bloqueante al parsear JSON del evaluador de práctica; se requiere sanitización robusta y fail-closed sin romper UI.

## Prompt ejecutado

````txt
Sos Senior Backend/LLM Engineer. Bug bloqueante en práctica (role-play):

Error:
SyntaxError: Unexpected token '`', "```json { ... " is not valid JSON
Stack:
parseEvaluationJson (lib/ai/practice-evaluator.ts:50)
evaluatePracticeAnswer (lib/ai/practice-evaluator.ts:105)
submitPracticeAnswer (app/learner/training/actions.ts:358)

Causa probable:
El LLM está devolviendo el JSON envuelto en triple backticks (```json ... ```), o con texto extra antes/después. Nuestro parser hace JSON.parse(raw) directo y revienta.

Objetivo:
Fix mínimo, robusto y fail-closed para parsear el output del evaluador de práctica:
- Aceptar JSON puro
- Aceptar JSON envuelto en ```json ... ```
- Aceptar texto con JSON embebido (extraer el primer objeto JSON válido)
- Si no se puede parsear, NO tirar 500: devolver una evaluación segura + mensaje user-friendly, y loggear el raw truncado (dev) para depurar.

Tareas exactas:
1) Abrir lib/ai/practice-evaluator.ts:
   - Identificar el lugar donde se construye el prompt del evaluador (para pedir “output ONLY JSON”).
   - Identificar parseEvaluationJson(raw).

2) Implementar sanitización mínima ANTES de JSON.parse:
   - Trim
   - Si contiene ```:
       - Extraer el contenido entre el primer bloque ```...``` (preferir ```json)
   - Si todavía falla:
       - Intentar extraer substring desde el primer '{' hasta el último '}' (inclusive).
   - Luego JSON.parse sobre el string sanitizado.

3) Fail-closed:
   - Si sigue fallando parseo:
       - No lanzar excepción hacia UI.
       - Retornar PracticeEvaluation por defecto:
           score: 0
           passed: false
           strengths: []
           gaps: ["No se pudo interpretar la evaluación automática."]
           feedback: "No pude evaluar tu respuesta en este momento. Intentá nuevamente."
       - Registrar log server con:
           - error.message
           - raw original truncado (max 500 chars)
           - raw sanitizado truncado
       - Persistir un registro en practice_evaluations con flagged status si el schema lo permite; si no existe campo, omitir.

4) Ajustar el prompt del evaluador (si está en el mismo archivo) para reducir ocurrencia:
   - Instrucción explícita: "Respond ONLY with valid JSON. No markdown, no backticks."
   - Mantener formato esperado por PracticeEvaluation.

5) Validación:
   - Reintentar flujo:
     - Iniciar práctica
     - Enviar “No sé”
     - Debe devolver feedback sin crash.
   - Agregar (si hay tests) un test unitario mínimo para parseEvaluationJson con:
       a) JSON puro
       b) ```json ... ```
       c) texto + JSON + texto
     Si no hay harness, al menos dejar un bloque de ejemplos en comentario.

Entrega:
- Archivos tocados + diff.
- Explicar en 2 bullets por qué el parse ahora es robusto y fail-closed.
````

Resultado esperado
Arreglo minimo con sanitizacion de salida LLM, manejo fail-closed y logs; sin 500 en UI.

Notas (opcional)
No tocar codigo fuera de lo necesario.
