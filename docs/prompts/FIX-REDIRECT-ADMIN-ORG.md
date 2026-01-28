# FIX-REDIRECT-ADMIN-ORG

## Contexto

Corregir el mapping de admin_org en /auth/redirect para que redirija a /org/metrics.

## Prompt ejecutado

```text
Sos Codex CLI en el repo `onbo-conversational`.

LOTE: FIX REDIRECT admin_org (BUG DE MAPPING)
Objetivo: corregir el redirect inicial del rol admin_org para que cumpla el navigation map.

CONTEXTO
- El redirect usa correctamente `profiles.role`.
- El bug está en el mapping `roleConfig` dentro de:
  app/auth/redirect/route.ts
- Actualmente:
  admin_org.defaultPath apunta erróneamente a `/referente/review`.

FUENTE DE VERDAD
- docs/navigation-map.md
  - Admin Org landing: `/org/metrics`

CAMBIOS A REALIZAR

1) Abrir `app/auth/redirect/route.ts`.

2) En el objeto `roleConfig` (o equivalente):
   - Cambiar:
     admin_org.defaultPath → `/org/metrics`
   - Ajustar `allowedPrefixes` para admin_org a:
     - `['/org']`

   No incluir `/referente` en allowedPrefixes.
   El mapa no lo habilita y evita cruces de rol innecesarios.

3) NO tocar:
   - lógica de lectura de sesión
   - queries a profiles
   - otros roles (learner, referente, superadmin)
   - DB / migraciones / RLS

4) Smoke mínimo local
   - Login con admin@demo.com
   - Debe aterrizar en `/org/metrics`
   - Acceso a `/referente/*` debe quedar bloqueado si existe guard

5) Commit directo en main
   - Commit message:
     `fix: correct admin_org redirect to org metrics`

SALIDA
- Confirmar archivo modificado
- Confirmar nuevo defaultPath de admin_org
- Confirmar build OK
```

## Resultado esperado

admin_org redirige a /org/metrics y no permite /referente como prefix.
