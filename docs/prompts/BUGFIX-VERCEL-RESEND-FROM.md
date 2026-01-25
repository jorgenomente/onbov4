# BUGFIX-VERCEL-RESEND-FROM

## Contexto

Build en Vercel falla al recolectar datos de /referente/review/[learnerId] por falta de RESEND_FROM.

## Prompt ejecutado

```txt
intento correr npx vercel --prod y no completa porque me dice esto 2026-01-25T13:15:10.163Z  Collecting page data using 1 worker ...
2026-01-25T13:15:10.524Z  Error: Failed to collect configuration for /referente/review/[learnerId]
2026-01-25T13:15:10.524Z  at ignore-listed frames {
2026-01-25T13:15:10.525Z  [cause]: Error: RESEND_FROM is not set
2026-01-25T13:15:10.525Z  at H (.next/server/chunks/ssr/[root-of-the-server]__b9b11606._.js:2:161148)
2026-01-25T13:15:10.525Z  at module evaluation (.next/server/chunks/ssr/[root-of-the-server]__b9b11606._.js:2:161210)
2026-01-25T13:15:10.525Z  at instantiateModule (.next/server/chunks/ssr/[turbopack]_runtime.js:740:9)
2026-01-25T13:15:10.525Z  at getOrInstantiateModuleFromParent (.next/server/chunks/ssr/[turbopack]_runtime.js:763:12)
2026-01-25T13:15:10.525Z  at Context.esmImport [as i] (.next/server/chunks/ssr/[turbopack]_runtime.js:228:20)
2026-01-25T13:15:10.525Z  at module evaluation (.next/server/chunks/ssr/_04948573._.js:1:32)
2026-01-25T13:15:10.525Z  at instantiateModule (.next/server/chunks/ssr/[turbopack]_runtime.js:740:9)
2026-01-25T13:15:10.526Z  at getOrInstantiateModuleFromParent (.next/server/chunks/ssr/[turbopack]_runtime.js:763:12)
2026-01-25T13:15:10.526Z  at Context.commonJsRequire [as r] (.next/server/chunks/ssr/[turbopack]_runtime.js:249:12)
2026-01-25T13:15:10.526Z  at H.children.children.children.children.page (.next/server/chunks/ssr/_04948573._.js:1:641)
2026-01-25T13:15:10.526Z  }
2026-01-25T13:15:11.031Z
2026-01-25T13:15:11.032Z  > Build error occurred
2026-01-25T13:15:11.034Z  Error: Failed to collect page data for /referente/review/[learnerId]
2026-01-25T13:15:11.035Z  at ignore-listed frames {
2026-01-25T13:15:11.035Z  type: 'Error'
2026-01-25T13:15:11.036Z  }
2026-01-25T13:15:11.069Z  Error: Command "npm run build" exited with 1
jorgepulido@Jorges-MacBook-Pro onbov4 %
```

Resultado esperado
Identificar el uso de RESEND_FROM en build y proponer fix para que no rompa el build si falta env.

Notas (opcional)
N/A.
