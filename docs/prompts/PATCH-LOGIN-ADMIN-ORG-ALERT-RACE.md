# PATCH LOGIN ADMIN ORG ALERT RACE

## Contexto

Evitar falsos positivos del selector de alertas globales en /org que disparaban el error de login en el test E2E.

## Prompt ejecutado

```txt
Ajustá el login del test para no depender de role=alert global y usar solo el texto de error de login.
```

Resultado esperado

Actualizar el test E2E para que el login solo falle cuando el mensaje de error real del login aparezca en /login.
