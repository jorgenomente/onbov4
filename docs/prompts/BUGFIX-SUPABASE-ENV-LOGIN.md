# BUGFIX-SUPABASE-ENV-LOGIN

## Contexto

Runtime error en /login por falta de NEXT_PUBLIC_SUPABASE_URL en el cliente.

## Prompt ejecutado

```txt
## Error Type
Runtime Error

## Error Message
NEXT_PUBLIC_SUPABASE_URL is not set


    at requireEnv (lib/client/supabase.ts:6:11)
    at module evaluation (lib/client/supabase.ts:11:21)
    at module evaluation (app/login/LoginForm.tsx:6:1)
    at LoginPage (app/login/page.tsx:16:7)

## Code Frame
  4 |   const value = process.env[name];
  5 |   if (!value) {
> 6 |     throw new Error(`${name} is not set`);
    |           ^
  7 |   }
  8 |   return value;
  9 | }

Next.js version: 16.1.4 (Turbopack)
```

Resultado esperado
Configurar variables de entorno públicas de Supabase para que el login funcione sin error.

Notas (opcional)
N/A.
