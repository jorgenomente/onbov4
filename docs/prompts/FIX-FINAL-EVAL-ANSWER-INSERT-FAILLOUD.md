# FIX-FINAL-EVAL-ANSWER-INSERT-FAILLOUD

## Contexto

Hardening del insert de respuestas de evaluacion final para fallar loud y mostrar error amigable.

## Prompt ejecutado

```txt
Fix mínimo (único) recomendado: corregir el INSERT y hacer fail-loud

Sin tocar schema ni RLS, solo código server-side.

1) Encontrar el punto exacto del INSERT

En el repo:

rg -n "final_evaluation_answers" -S .
rg -n "answer_text|learner_answer|question_id" -S app src .
rg -n "submitFinal|final evaluation|final_evaluation" -S app src .


Buscá algo similar a:

insert({ question_id, answer_text: ... })

insert({ question_id, learner_answer: ... })

rpc_*final* si lo implementaste vía RPC

2) Corregir el mapping de columnas (canónico)

El insert debe ser exactamente:

tabla: public.final_evaluation_answers

columnas: question_id, learner_answer

Ejemplo (Supabase JS):

const { error } = await supabase
  .from("final_evaluation_answers")
  .insert({
    question_id: questionId,
    learner_answer: answerText, // o como se llame en el server action
  });

if (error) throw error;


Prohibido:

answer_text

attempt_id en answers (no existe)

cualquier update para “marcar respondida”

3) Hacer que el error sea visible (fail-loud)

Si hoy el server action “no muestra error”, casi seguro hay un try/catch que lo oculta.

Regla mínima: si insert.error, throw y que la UI muestre el error (aunque sea un toast simple).

En server action:

if (error) {
  console.error("final_evaluation_answers insert failed", { error, questionId });
  throw new Error("No se pudo guardar tu respuesta. Reintentá.");
}


Esto te va a revelar de inmediato si era:

“column does not exist”

“violates row level security policy”

“null value in column …”

etc.
```

Resultado esperado
Insert de answers con logging y error visible cuando falla.

Notas (opcional)
N/A
