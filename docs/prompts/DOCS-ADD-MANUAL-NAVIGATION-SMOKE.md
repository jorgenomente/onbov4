# DOCS-ADD-MANUAL-NAVIGATION-SMOKE

## Contexto

Documentar el smoke manual de navegacion por rol en un doc reproducible.

## Prompt ejecutado

```text
Sos Codex CLI en el repo `onbo-conversational`.

OBJETIVO
Crear un documento reproducible de smoke manual de navegación por rol para ONBO:
`docs/smoke/manual-navigation-smoke.md`

REGLAS
- Solo docs. No tocar código.
- Usar como fuente: docs/navigation-map.md y los CTAs implementados.

CONTENIDO DEL DOC
1) Precondiciones (db reset, dev server, credenciales)
2) Secciones por rol: Público, Aprendiz, Referente, Admin Org
3) Checklist de pasos (como el de esta conversación)
4) “Resultados esperados” por cada paso (redirects, rutas)
5) Troubleshooting corto:
   - Si / no redirige -> revisar app/page.tsx
   - Si CTA no navega -> revisar Link/href
   - Si rol no cae en landing -> revisar /auth/redirect

COMMIT
- Commit directo en main: `docs: add manual navigation smoke test`
```

## Resultado esperado

Doc de smoke manual reproducible en docs/smoke.
