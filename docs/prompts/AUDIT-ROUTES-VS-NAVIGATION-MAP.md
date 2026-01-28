# AUDIT-ROUTES-VS-NAVIGATION-MAP

## Contexto

Auditoria de rutas reales (app router) vs rutas declaradas en docs/navigation-map.md para identificar huérfanas y faltantes.

## Prompt ejecutado

```txt
Sos Codex CLI trabajando en el repo `onbo-conversational` (Next.js App Router + Supabase).
Objetivo: AUDITORÍA DE RUTAS REALES vs `docs/navigation-map.md` para eliminar páginas huérfanas.

REGLAS
- No implementes features nuevas. Solo auditoría + reporte.
- No cambies DB, migraciones, ni RLS.
- No agregues navegación ni CTAs todavía.
- No asumas rutas: listalas desde el filesystem.
- Reporte debe ser determinístico y copiable a docs.

TAREAS

1) Levantar el mapa declarado
- Abrí `docs/navigation-map.md` y extraé la lista de rutas declaradas (paths).
- Normalizá placeholders: `[learnerId]`, `[unitOrder]` como dinámicas.

2) Enumerar rutas reales del repo (App Router)
- Escaneá `app/**` e identificá TODAS las rutas públicas que generan endpoint:
  - `page.tsx` (rutas UI)
  - `route.ts` (API routes)
- Para cada ruta, calculá el path final de Next.js:
  - segmentos `[param]` / `[...param]` se mantienen como dinámicos.
  - ignorá `_components`, `components`, `lib`, etc. (solo `app/`).
- Excluí: archivos que no sean `page.tsx` o `route.ts`.
- Incluí rutas especiales si existen: `/login`, `/auth/*`, etc.

3) Generar tabla de auditoría (SALIDA)
Construí 3 listas:

A) "En mapa y existe en app" (OK)
- path
- tipo: page | route
- archivo fuente (ruta real en repo)

B) "En mapa pero NO existe en app" (FALTANTE)
- path
- sugerencia: (crear luego) | (remover del mapa) — NO decidas, solo marcar.

C) "Existe en app pero NO está en mapa" (HUÉRFANA)
- path
- tipo: page | route
- archivo fuente
- nota corta: “posible legacy/experimental” (si el nombre lo sugiere)

4) Guardar reporte en docs
- Crear/actualizar `docs/audit/routes-vs-navigation-map.md` con:
  - Fecha (YYYY-MM-DD)
  - Resumen numérico: total pages, total routes, ok, faltantes, huérfanas.
  - Las 3 secciones A/B/C en markdown con tablas.

5) Salida final para el usuario
Imprimí en consola:
- El resumen numérico
- Top 10 huérfanas (paths)
- Top 10 faltantes (paths)
y confirmá el archivo generado en `docs/audit/routes-vs-navigation-map.md`.

COMANDOS SUGERIDOS (si los necesitás)
- `ls`, `find app -name page.tsx -o -name route.ts`
- `rg "export default" app -g'page.tsx'` (opcional)
- Node script inline si te ayuda a normalizar paths (permitido).

ENTREGABLE ÚNICO
- Un commit directo en `main` con el nuevo doc `docs/audit/routes-vs-navigation-map.md`.
- Mensaje de commit: `docs: audit routes vs navigation map`

Luego de terminar, NO sigas con layouts ni CTAs. Solo dejá el reporte listo.
```

## Resultado esperado

Reporte determinístico de rutas reales vs navigation map con listas A/B/C y resumen numérico.
