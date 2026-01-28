# DOCS-RECONCILE-NAVIGATION-MAP

## Contexto

Reconciliar el mapa de navegacion con la auditoria de rutas reales sin tocar codigo.

## Prompt ejecutado

```txt
Sos Codex CLI en el repo `onbo-conversational`.

OBJETIVO (LOTE DOCS)
Reconciliar `docs/navigation-map.md` con el resultado de `docs/audit/routes-vs-navigation-map.md`,
eliminando “huérfanas” a nivel doc (o incorporándolas como rutas alcanzables).
NO tocar código todavía.

REGLAS
- Solo modificar documentación (docs/).
- No cambiar layouts, no agregar CTAs, no cambiar app/.
- Mantener el tono y estructura del navigation map existente.

TAREAS

1) Abrir y leer:
- docs/navigation-map.md
- docs/audit/routes-vs-navigation-map.md

2) Actualizar `docs/navigation-map.md` incorporando explícitamente estas rutas que hoy existen en app pero no están en el mapa:
- /auth/logout
- /org/config/locals-program
- /org/metrics/coverage/[programId]/[unitOrder]
- /org/metrics/gaps/[unitOrder]
- / (root)

3) DÓNDE UBICARLAS (estructura sugerida)
A) Sección 0) Público / auth:
- Agregar:
/auth/logout (server-side) → redirige a /login

B) Sección 3) Admin Org:
- En /org/metrics, bajo “drilldowns” o “detalles” agregar:
  - /org/metrics/coverage/[programId]/[unitOrder]
  - /org/metrics/gaps/[unitOrder]
- En “Programa activo por local” (Sección C), reemplazar el placeholder por la ruta real:
  - /org/config/locals-program
  - CTA primario: “Asignar programa”
  - CTA secundario: “Volver a métricas” → /org/metrics

C) Sección 0) Entry / root:
- Agregar una regla explícita para `/`:
  - / → redirect server-side:
    - si hay sesión → /auth/redirect
    - si no hay sesión → /login
  (Esto deja claro que NO existe home genérica)

4) Mantener /admin/organizations como PLAN (faltante real) sin inventar UI.
- No crear rutas nuevas en app.

5) (Opcional pero recomendado) Añadir al final una mini sección:
“Rutas reales incorporadas por auditoría 2026-01-28” con bullets (sin duplicar tablas).

6) Commit directo en main:
- git status debe quedar limpio.
- Commit message: `docs: reconcile navigation map with route audit`

SALIDA
- Confirmá qué se modificó en navigation-map.md (lista de rutas añadidas y dónde quedaron)
- No propongas cambios de código aún.
```

## Resultado esperado

Navigation map reconciliado con rutas reales, sin cambios de codigo.
