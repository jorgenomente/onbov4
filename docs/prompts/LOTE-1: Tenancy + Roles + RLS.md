Actuá como Lead Software Architect + Senior Backend Engineer siguiendo AGENTS.md y docs/plan-mvp.md.

OBJETIVO (LOTE 1):
Implementar la base multi-tenant y roles con Supabase Postgres (DB-first + RLS-first) para ONBO Conversational.

SOURCES OF TRUTH:

- docs/product-master.md
- docs/plan-mvp.md
- AGENTS.md

REGLAS:

- SQL nativo únicamente (sin Prisma/Drizzle).
- Nada de select \*.
- Todas las tablas con RLS habilitada y policies explícitas.
- Multi-tenancy derivado desde auth.uid() (no se confía en el cliente).
- No usar service_role en cliente.
- Entregable en una migración SQL versionada en supabase/migrations.
- Añadir entradas relevantes a docs/activity-log.md.
- Al finalizar: ejecutar npm run lint y npm run build y arreglar issues si aparecen.

TAREAS CONCRETAS:

A) MIGRACIÓN DB (una sola migración, nombre claro):

1. Crear tabla organizations:
   - id uuid pk default gen_random_uuid()
   - name text not null
   - created_at timestamptz not null default now()

2. Crear tabla locals:
   - id uuid pk default gen_random_uuid()
   - org_id uuid not null references organizations(id) on delete restrict
   - name text not null
   - created_at timestamptz not null default now()
   - index (org_id)

3. Crear enum app_role:
   - superadmin
   - admin_org
   - referente
   - aprendiz

4. Crear tabla profiles (1:1 con auth.users):
   - user_id uuid pk references auth.users(id) on delete cascade
   - org_id uuid not null references organizations(id) on delete restrict
   - local_id uuid not null references locals(id) on delete restrict
   - role app_role not null
   - full_name text null
   - created_at timestamptz not null default now()
   - updated_at timestamptz not null default now()
   - indexes (org_id), (local_id), (role)

5. Trigger updated_at para profiles.

B) HELPERS SQL (SECURITY DEFINITIONS CUANDO CORRESPONDA):
Crear funciones helper en schema public:

- current_user_id() -> uuid (auth.uid())
- current*profile() -> row (select * de profiles para auth.uid) (OJO: no usar select \_ en código, enumerar columnas)
- current_role() -> app_role
- current_org_id() -> uuid
- current_local_id() -> uuid
  Todas deben fallar de forma segura si no existe perfil.

C) RLS (STRICT):

1. Habilitar RLS en organizations, locals, profiles.
2. Policies mínimas:
   - profiles:
     - SELECT: el usuario puede leer solo su profile
     - UPDATE: el usuario puede actualizar solo full_name (y updated_at)
     - INSERT: restringido (solo superadmin o proceso controlado; para MVP dejar sin insert desde client)
   - locals:
     - SELECT:
       - superadmin puede ver todo
       - admin_org puede ver locales de su org
       - referente/aprendiz puede ver solo su local
   - organizations:
     - SELECT: - superadmin puede ver todo - resto: solo su org
       Nota: por ahora no necesitamos policies de write en org/locals (solo lectura) salvo que sea estrictamente necesario para seeds/dev.

D) SEED DEV (opcional pero recomendado para smoke local):

- Insertar 1 organization + 1 local SOLO si estamos en entorno local y lo considerás razonable.
  Si preferís no seedear en migración, dejá una sección comentada con instrucciones manuales y NO rompas RLS.

E) APP MINIMUM WIRES (si ya existen, solo validar y no reescribir):

- Confirmar que el middleware/protected routes no rompa build.
- No construir pantallas nuevas aún.

F) VERIFICACIÓN:

1. Asegurar que migración aplica con npx supabase db reset.
2. Proveer en comentario de docs/activity-log.md un mini checklist manual de RLS para:
   - usuario autenticado con profile: puede leer su profile.
   - no puede leer profiles ajenos.
   - puede leer su local; admin_org ve locales de su org; superadmin ve todo.

ENTREGABLES:

- 1 archivo SQL en supabase/migrations/ (con nombre timestamp + l1_tenancy_roles.sql)
- docs/activity-log.md actualizado con una entrada (tipo: feature, alcance: db/rls)
- Si tocás TS, que sea mínimo y solo si bloquea build/lint.

AL FINAL:

- Ejecutar npm run lint y npm run build. Corregir errores si aparecen.
- Mostrar resumen breve: archivos tocados + comandos ejecutados + resultado.
