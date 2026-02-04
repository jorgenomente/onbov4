# FASE1 VERIFICAR PROVIDER OPENAI

## Contexto

Verificación técnica mínima para confirmar que el motor usa OpenAI real (no mock) y que el server fue reiniciado si cambia el provider.

## Prompt ejecutado

```txt
FASE 1 — Verificación técnica mínima (5 minutos)

Antes de probar UX, confirmamos que el motor está usando OpenAI real y no mock.

1️⃣ Verificá el provider activo

Abrí este archivo (ya existe en tu repo):

lib/ai/provider.ts


Deberías ver algo conceptualmente así (no exacto, pero la idea):

const provider = process.env.LLM_PROVIDER ?? 'mock'


Confirmá en tu .env.local:

LLM_PROVIDER=openai
OPENAI_API_KEY=sk-...


👉 Importante: reiniciá el server si no lo hiciste

npm run dev
```

Resultado esperado

Confirmación del provider en código y de las variables en .env.local, con indicación de reinicio del server.
