# POST-MVP3 E1 ACTIVE PROGRAM BY LOCAL

## Contexto

Sub-lote E.1: programa activo por local (Admin Org) con RPC segura, auditoria append-only y UI minima.

## Prompt ejecutado

```txt
# Post-MVP 3 — Sub-lote E.1: “Programa activo por local” (Admin Org)

OBJETIVO
Permitir que Admin Org pueda asignar/cambiar el programa activo de un local (local_active_programs) desde UI,
con seguridad multi-tenant y auditoría mínima, sin convertirse en course builder.

ALCANCE EXACTO (MVP)
- 1 pantalla Admin Org (read + 1 write).
- 1 RPC segura: set_local_active_program(local_id, program_id, reason?) que hace UPSERT.
- Auditoría append-only de cambios (no borrar ni recalcular).

NO HACER
- No CRUD de programs/units/knowledge.
- No exponer parámetros LLM.
- No tocar engine del bot.
- No agregar “builder”.
- No service_role en clientes.

CONTEXTO DB (YA EXISTE)
- Tabla: public.local_active_programs(local_id PK, program_id, created_at)
- Tabla: public.locals(id, org_id, name, ...)
- Tabla: public.training_programs(id, org_id, local_id nullable, name, is_active, created_at)
- View (ya existe por B.1): public.v_org_local_active_programs (read-only)
- Helpers: current_org_id(), current_role(), current_user_id()/current_profile()

REGLAS DE NEGOCIO (cerradas)
1) Solo roles: admin_org y superadmin pueden cambiar el programa activo.
2) El local debe pertenecer a la org actual.
3) El programa debe pertenecer a la org actual.
4) Programs elegibles para un local:
   - org-level (training_programs.local_id IS NULL) y org_id = current_org_id
   - local-specific (training_programs.local_id = local_id) y org_id = current_org_id
5) Cambiar programa activo NO modifica learner_trainings existentes (afecta nuevos learners / defaults). (documentar)

SEGURIDAD (OBLIGATORIO)
- RLS-first: habilitar INSERT/UPDATE en local_active_programs SOLO para admin_org/superadmin con checks por org/local.
- RPC debe ser SECURITY INVOKER (no bypass), y reforzar validaciones con helpers.
- Writes desde UI solo via Server Action SSR (cookies), NO desde client directo.
- No select *.

AUDITORÍA (mínimo, append-only)
- Crear tabla append-only: public.local_active_program_change_events
  Campos mínimos:
  - id uuid pk default gen_random_uuid()
  - org_id uuid not null
  - local_id uuid not null
  - from_program_id uuid null
  - to_program_id uuid not null
  - changed_by_user_id uuid not null
  - reason text null
  - created_at timestamptz not null default now()
- Trigger prevent_update_delete() aplicado a esta tabla.
- Trigger en local_active_programs (AFTER INSERT OR UPDATE) que inserte evento:
  - from_program_id = OLD.program_id (si update)
  - to_program_id = NEW.program_id
  - org_id derivado del local (join locals)
  - changed_by_user_id = auth.uid() o current_user_id()
  - reason: pasado por RPC (guardarlo en variable local / set_config('app.change_reason', ...) o pasar directo en insert desde RPC)
  Nota: preferir que la inserción del evento la haga la RPC para no depender de hacks.

DB ENTREGABLES (migración única)
- Nueva migración:
  1) Tabla audit local_active_program_change_events + índices (local_id, created_at desc).
  2) Policies RLS:
     - local_active_programs: SELECT ya existe; agregar INSERT/UPDATE (admin_org/superadmin) con:
       - local_id pertenece a org (join locals org_id = current_org_id)
       - program_id pertenece a org (training_programs.org_id = current_org_id)
     - local_active_program_change_events: SELECT admin_org (org scope) y superadmin (todo). INSERT server-only (admin_org/superadmin).
  3) RPC:
     - public.set_local_active_program(p_local_id uuid, p_program_id uuid, p_reason text default null) returns void (o uuid)
     - Validaciones:
       - role in ('admin_org','superadmin')
       - local pertenece a org actual
       - program pertenece a org actual
       - program elegible para ese local (org-level o program.local_id = local)
     - Escritura:
       - upsert local_active_programs(local_id, program_id, created_at=now()) on conflict(local_id) do update set program_id=excluded.program_id
     - Auditoría:
       - insertar en local_active_program_change_events con from/to, user_id, reason.
     - Grant execute to authenticated.

REGENERAR DOCS DB
- Luego de migración: npx supabase db reset
- Regenerar docs/db/dictionary.md y docs/db/schema.public.sql según la regla del repo.

UI ENTREGABLES (Next.js 16 / RSC)
- Ruta: /org/config/locals-program (o /org/config/program-active si ya existe convención; elegir una y mantener simple)
- Pantalla:
  A) Tabla “Locales”:
     - local_name
     - programa activo actual (program_name)
     - botón “Cambiar”
  B) Modal o sección inline “Cambiar programa”:
     - selector local (si modal desde fila, ya viene local)
     - selector programa (lista elegible para ese local; org-level + local-specific)
     - campo opcional “motivo” (text)
     - botón Guardar -> server action -> RPC set_local_active_program
     - success/error (puede ser query param, consistente con D.1)
  C) Sección “Historial reciente” (read-only):
     - último N eventos de local_active_program_change_events para la org (limit 20), mostrando:
       fecha, local, from_program, to_program, changed_by (si se puede resolver), reason (truncado).
     - Si resolver profile/email complica, mostrar changed_by_user_id por ahora (sin romper build).

UI TÉCNICO
- RSC server-side queries con Supabase SSR.
- Server action:
  - valida inputs básicos
  - llama supabase.rpc('set_local_active_program', {...})
  - revalidatePath(ruta)
  - redirect con ?success=1 o ?error=...

DOCS / LOG
- docs/activity-log.md: entrada “Post-MVP3 E.1 programa activo por local”
- docs/prompts/POST-MVP3-E1-ACTIVE-PROGRAM-BY-LOCAL.md: registrar prompt.

QA / GATE OBLIGATORIO (local)
- npx supabase db reset
- npm run lint
- npm run build
- Smoke manual:
  - Loguear admin_org -> cambiar programa de un local -> ver tabla actualizada
  - Ver que se crea evento en local_active_program_change_events
  - Referente no puede escribir (debe fallar por RLS / UI no accesible)

IMPORTANTE
- Trabajar directo en main (sin branches).
- Si surge un bug pre-existente que rompe build/lint, podés arreglarlo solo si es mínimo y necesario, y registrarlo en activity-log.
```

Resultado esperado

Migracion, UI, RPC, RLS, auditoria y QA ejecutados segun alcance.

Notas (opcional)

Sin notas.
