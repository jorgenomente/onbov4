# PATCH LOGIN ADMIN ORG ERROR TEXT

## Contexto

Capturar el mensaje real de error de login en UI (sin role=alert) para diagnóstico en el test E2E.

## Prompt ejecutado

```txt
http://localhost:3000/login
```

Resultado esperado

Actualizar el test para detectar el texto de error de login y reportarlo si falla.
