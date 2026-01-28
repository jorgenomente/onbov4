# FEAT-NAVIGATION-BASE-REDIRECTS-LAYOUTS

## Contexto

Cableado base de navegacion: redirect en / y layouts minimos por rol.

## Prompt ejecutado

```txt
Sos Codex CLI en el repo `onbo-conversational` (Next.js App Router + Supabase).

LOTE: CABLEADO BASE DE NAVEGACIÓN (CODE)
Meta: eliminar páginas huérfanas a nivel UX implementando redirects y layouts por rol.

REGLAS
- No tocar DB / migraciones / RLS.
- No crear pantallas nuevas (excepto lo mínimo para cumplir redirect `/` si falta).
- No inventar rutas nuevas: solo usar las ya existentes en app/ y las del navigation map.
- No meter lógica sensible en cliente. Redirects server-side.
- Mantener mobile-first, minimal UI. Nada de dashboards nuevos.

FUENTES DE VERDAD
- docs/navigation-map.md (recientemente actualizado)
- rutas reales ya auditadas y existentes en app/

TAREAS

1) Implementar el redirect server-side para `/`
- Abrí app/page.tsx (existe).
- Debe hacer redirect determinístico:
  - Si hay sesión → redirect a `/auth/redirect`
  - Si NO hay sesión → redirect a `/login`
- Debe ser server-side (RSC). Usar `createClient` de `@supabase/ssr` / helper existente en el repo.
- No renderizar UI en `/` (cero home). Solo redirect.

Notas:
- Si el proyecto ya tiene un helper del estilo `createServerClient()` en `lib/supabase/server` o similar, usarlo.
- Revisar cómo hoy determinan sesión en otras rutas (ej /auth/redirect). Reutilizar patrón.

2) Verificar `/auth/logout` contract
- Abrí app/auth/logout/route.ts.
- Confirmar que termina en redirect a `/login` y limpia sesión. Si no lo hace:
  - Ajustar para que haga signOut server-side y redirect a /login.
- Mantener response headers/redirect correcto en App Router.

3) Layouts por rol (solo navegación mínima)
A) app/learner/layout.tsx
- Debe tener tabs/links:
  - Entrenamiento → /learner/training
  - Progreso → /learner/progress
  - Perfil → /learner/profile
- No agregar links extra.
- Mantener diseño simple (Tailwind). Mobile-first.

B) app/referente/layout.tsx
- Links mínimos:
  - Revisión → /referente/review
  - Alertas → /referente/alerts

C) app/org/layout.tsx
- Links mínimos:
  - Métricas → /org/metrics
  - Config evaluación final → /org/config/bot
  - Knowledge coverage → /org/config/knowledge-coverage
  - Escenarios de práctica → /org/bot-config
  - Programa por local → /org/config/locals-program
- Importante: NO linkear /admin/*.

D) app/admin/layout.tsx
- NO crear si no existe carpeta /admin aún. No inventar UI.
- Si existe, asegurar que no muestra links a rutas no implementadas.

4) Guardrails de acceso (sin overengineering)
- No implementar un RBAC nuevo.
- Pero si ya existe middleware/guard por rol, asegurate de no romperlo.
- Si no existe guard por rol, no lo agregues en este lote.

5) Smoke local (obligatorio)
Ejecutar:
- `npm run lint`
- `npm run build`
(no corras db reset en este lote)

6) Commit directo en main
- Mensaje: `feat: navigation base redirects and role layouts`

SALIDA
- Resumen de archivos tocados
- Confirmación de que `/` ya no renderiza nada (solo redirect)
- Confirmación de que layouts exponen exactamente los links del mapa
- Output de lint/build (si falla, arreglar)

IMPORTANTE
No agregar CTAs dentro de páginas aún. Eso es el próximo lote.
```

## Resultado esperado

Redirect server-side en /, layout org con links minimos, sin cambios de DB ni nuevas rutas.
