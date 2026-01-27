# RETRY-LLM-PROVIDER

## Contexto

Agregar reintentos automáticos en el proveedor LLM para manejar errores temporales (503 overload).

## Prompt ejecutado

```txt
hacemos 1
```

Resultado esperado

Reintentos con backoff en llamadas al proveedor LLM.

Notas (opcional)

Aplicar en lib/ai/provider.ts.
