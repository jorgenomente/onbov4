# FIX-PROFILES-RLS-REVIEW-QUEUE

## Contexto

No aparecen aprendices en revisión aunque status es en_revision; revisar RLS y ajustar para que referente/admin puedan leer perfiles de su alcance.

## Prompt ejecutado

```txt
ahora me sucede que no me muestra aprendiz en revision incluso cuando acabo de terminar el final test con aprendiz y el estado actual es en revision
```

Resultado esperado

Ajustar RLS de profiles para permitir lectura por referente/admin según org/local.

Notas (opcional)

Se agrega migración con policies de SELECT.
