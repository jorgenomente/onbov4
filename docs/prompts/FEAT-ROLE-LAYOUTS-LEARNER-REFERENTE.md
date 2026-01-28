# FEAT-ROLE-LAYOUTS-LEARNER-REFERENTE

## Contexto

Completar layouts por rol (learner y referente) con navegacion minima segun navigation map.

## Prompt ejecutado

```text
Sos Codex CLI en el repo `onbo-conversational`.

LOTE: COMPLETAR LAYOUTS POR ROL (MÍNIMOS) — SIN CTAs
Objetivo: cumplir el contrato del `docs/navigation-map.md` en navegación visible por rol.

REGLAS
- No tocar DB / migraciones / RLS.
- No tocar páginas existentes (page.tsx) salvo que sea imprescindible para que compile.
- No agregar CTAs dentro de páginas todavía.
- Solo layouts y componentes de navegación mínimos.
- Mobile-first, UI mínima.
- No inventar rutas; solo usar las existentes listadas en el mapa.

TAREAS

1) Verificar qué layouts existen hoy
- Revisar si ya existe:
  - app/learner/layout.tsx
  - app/referente/layout.tsx
  - app/org/layout.tsx (ya existe)
- Si existen, ajustar para que expongan EXACTAMENTE los links del mapa.

2) Implementar/ajustar `app/learner/layout.tsx`
Debe mostrar navegación mínima tipo tabs (3):
- Entrenamiento → /learner/training
- Progreso → /learner/progress
- Perfil → /learner/profile

Requisitos:
- Mantener children render.
- Resaltar link activo (simple).
- Evitar componentes pesados.

3) Implementar/ajustar `app/referente/layout.tsx`
Links mínimos:
- Revisión → /referente/review
- Alertas → /referente/alerts

Requisitos:
- Mantener children render.
- Resaltar activo (simple).
- UI consistente con org layout (simple header + nav).

4) Revisar `app/org/layout.tsx`
Confirmar que incluye:
- /org/metrics
- /org/config/bot
- /org/config/knowledge-coverage
- /org/bot-config
- /org/config/locals-program

No agregar extras.

5) Smoke obligatorio
- `npm run lint`
- `npm run build`

6) Commit directo en main
- Commit message: `feat: role layouts learner and referente`

SALIDA
- Listado de archivos tocados
- Confirmar que ahora existen los 3 layouts (learner/referente/org)
- Confirmar que NO se agregaron CTAs ni links fuera del mapa
```

## Resultado esperado

Layouts por rol con navegacion minima y resaltado activo en learner y referente.
