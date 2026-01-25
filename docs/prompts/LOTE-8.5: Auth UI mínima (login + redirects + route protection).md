# LOTE-8.5: Auth UI mínima (login + redirects + route protection)

## Contexto

Implementar Auth UI mínima para login/logout, protección de rutas y redirects por rol con Supabase SSR.

## Prompt ejecutado

```txt
Actuá como Senior Fullstack Engineer (Next.js + Supabase) siguiendo AGENTS.md y docs/plan-mvp.md.

OBJETIVO (LOTE 8.5):
Implementar Auth UI mínima (MVP) para poder entrar y navegar ONBO con usuarios ya creados en Supabase Auth:
- Pantalla /login (email + password)
- Logout
- Protección de rutas por sesión
- Redirección por rol post-login
- Rutas públicas vs privadas
Sin signup público, sin reset password, sin magic link (por ahora).

SOURCES OF TRUTH:
- docs/product-master.md
- docs/plan-mvp.md
- AGENTS.md

REGLAS:
- Server-only para lectura de sesión en rutas protegidas (SSR).
- Nada de service_role en cliente.
- Usar @supabase/ssr y cookies correctamente.
- UX simple, mobile-first, estados completos (loading/empty/error).
- No romper rutas existentes (learner/referente/admin ya implementadas).
- Git: commit directo en main + push.
- Guardar prompt en /docs/prompts/ con nueva convención:
  "LOTE-8.5: Auth UI mínima (login + redirects + route protection).md"
- Al final: npm run lint, npm run build.

TAREAS:

A) SUPABASE SSR CLIENT (si no existe o ajustar)
1) Verificar lib/server/supabase.ts (o equivalente) y asegurar helpers:
   - createServerClient con cookies (Next.js App Router)
   - createBrowserClient para client components cuando aplique
2) Asegurar que tenemos:
   - getUser() / getSession() server-side
   - signInWithPassword client-side
   - signOut server-side o client-side según patrón

B) RUTAS PÚBLICAS / PRIVADAS + MIDDLEWARE
1) Crear/ajustar middleware.ts en root:
   - Definir public routes: /login, / (si es landing), /api/public/*
   - Proteger:
     - /learner/*
     - /referente/*
     - /org/* (si existe)
     - /admin/* (si existe)
   - Si no hay sesión y ruta es protegida -> redirect a /login?next=<path>
   - Si hay sesión y usuario visita /login -> redirect por rol (ver sección D)
   - Evitar loops, y no asumir rutas inexistentes.

2) Implementar matcher correcto para App Router:
   - excluir _next/static, _next/image, favicon, assets

C) PANTALLA /login (UI mínima)
1) Crear app/login/page.tsx (client component):
   - Form: email, password
   - Button "Ingresar"
   - Estado loading mientras intenta
   - Mostrar error friendly si falla (credenciales, etc.)
   - Si existe query param next=, respetarlo al redirigir (solo si es ruta interna)

2) Autenticación:
   - Usar supabase.auth.signInWithPassword({ email, password })
   - Tras login exitoso:
     - NO decidir rol en cliente “a ciegas”
     - Hacer redirect a una ruta server que resuelva rol (ver D) o llamar server action.

D) REDIRECT POR ROL (server-side, seguro)
Crear una ruta server-only que:
- lea sesión + perfil (role) vía RLS
- redirija según role

Implementar como:
1) app/auth/redirect/route.ts (Route Handler, server):
   - Obtener supabase server client (cookies)
   - Si no session -> redirect /login
   - Consultar role desde public.profiles para auth.uid()
   - Mapear:
     - aprendiz -> /learner/training
     - referente -> /referente/review
     - admin_org -> /referente/review (por ahora) o /org (si existe)
     - superadmin -> /referente/review (por ahora)
   - Si existe ?next=... y es ruta interna protegida, permitirla SOLO si:
     - el role tiene acceso a ese prefijo (ej aprendiz solo /learner)
     - si no, ignorar next y usar default por rol

2) En /login, luego de signIn success -> window.location.href = "/auth/redirect" (+next si aplica)

E) LOGOUT
1) Crear endpoint server:
   - app/auth/logout/route.ts
   - Ejecutar supabase.auth.signOut()
   - redirect a /login

2) Agregar botón Logout en áreas mínimas:
   - en /learner/training (si existe layout) o crear un header minimal en:
     - app/learner/layout.tsx
     - app/referente/layout.tsx
   - Botón llama a /auth/logout (link) o action.

F) PROTECCIÓN ADICIONAL POR PREFIJO (opcional pero recomendado)
En middleware, además de sesión:
- Restringir prefijos por role (defensa en profundidad)
  - aprendiz: solo /learner/*
  - referente: /referente/*
  - admin_org: /referente/* (y futuro /org/*)
  - superadmin: permitir todo
Si role no puede acceder -> redirect a /auth/redirect

Implementación:
- En middleware no tenemos fácil RLS profile sin DB call costosa; preferir:
  - dejar middleware solo “requires session”
  - y hacer enforcement de rol en layouts server (mejor)
O:
  - leer role desde un claim si existe (si no existe, no inventar)
Decidir el enfoque más simple y seguro:
- RECOMENDADO: enforcement de rol en layouts server (ver G)

G) ENFORCEMENT DE ROL EN LAYOUTS (server components)
1) Crear helper server-only:
   - lib/server/requireRole.ts
   - Función requireUserAndRole(allowedRoles, redirectTo="/auth/redirect")
   - Obtiene auth.user + profiles.role
   - Si no cumple -> redirect

2) Aplicar en:
   - app/learner/layout.tsx -> allowed: ['aprendiz']
   - app/referente/layout.tsx -> allowed: ['referente','admin_org','superadmin']

H) DOCUMENTACIÓN
1) Actualizar docs/activity-log.md:
   - Lote 8.5: Auth UI mínima + redirects + protection
   - rutas públicas/privadas
   - cómo testear manualmente

2) Guardar prompt:
   - docs/prompts/LOTE-8.5: Auth UI mínima (login + redirects + route protection).md
   - Pegar este prompt íntegro.

I) VERIFICACIÓN MANUAL (obligatoria)
1) npm run lint
2) npm run build
3) Manual:
   - Ir /login
   - Login aprendiz@demo.com -> termina en /learner/training
   - Login referente@demo.com -> /referente/review
   - Login admin@demo.com -> /referente/review
   - Logout -> vuelve a /login
   - Sin sesión: entrar a /learner/training -> redirect /login?next=...
   - Con sesión: visitar /login -> redirect por rol

AL FINAL:
- git status
- git commit -m "feat: lote 8.5 auth ui (login + redirects + protection)"
- git push origin main
- Reportar: archivos tocados + comandos y resultados
```

Resultado esperado
Auth UI mínima con login/logout, redirects por rol y protección de rutas, más verificación y commit.

Notas (opcional)
N/A.
