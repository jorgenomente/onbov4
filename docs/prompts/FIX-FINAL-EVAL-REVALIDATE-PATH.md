# FIX-FINAL-EVAL-REVALIDATE-PATH

## Contexto

Eliminar refresh manual en /learner/final-evaluation agregando revalidatePath en server action.

## Prompt ejecutado

```txt
Cambio mínimo para eliminar el refresh manual
Qué hacer

En app/learner/final-evaluation/actions.ts, dentro de submitFinalAnswerAction (después del insert y cualquier lógica necesaria, antes de retornar), agregar:

revalidatePath('/learner/final-evaluation')

Si esa página vive bajo layout de /learner, también podés revalidar ambos paths (pero empezá por uno):

revalidatePath('/learner/final-evaluation') (mínimo)

opcional si no refresca lo suficiente: revalidatePath('/learner')

Por qué alcanza

Tu page.tsx es Server Component y calcula nextQuestion consultando questions + answers. Sin revalidación, el árbol queda stale y no vuelve a ejecutar esas queries hasta refresh manual.
```

Resultado esperado
El submit revalida la ruta y avanza a la siguiente pregunta sin refresh manual.

Notas (opcional)
N/A
