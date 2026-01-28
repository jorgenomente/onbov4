# POST-MVP6 Sub-lote 3.1: Disable practice_scenarios + audit events

## Contexto

Completar write seguro con disable soft y auditoria append-only para practice_scenarios, sin UI.

## Prompt ejecutado

```txt
# PROMPT PARA CODEX CLI — Post-MVP6 Sub-lote 3.1 (DB): Disable practice_scenarios + Auditoría append-only (sin UI)

Actuá como Backend Engineer (Supabase/Postgres). DB-first, RLS-first, Zero Trust, append-only.

## Objetivo
Post-MVP6 Sub-lote 3.1 — completar el write seguro de practice_scenarios con:
1) **Disable (soft)** via `is_enabled` (sin borrar).
2) **Auditoría append-only** de creación y disable en una tabla de eventos.
Sin tocar UI ni server actions.

Decisiones confirmadas:
- DISABLE_FLAG: SI
- AUDIT_EVENTS: SI

## Restricciones duras
- No inventar features fuera del alcance.
- No DELETE/UPDATE directos desde clientes.
- Nada de service_role en clientes.
- Mantener multi-tenant estricto.
- Auditoría: append-only (sin UPDATE/DELETE).
- Mantener patrones existentes (event tables similares si existen; si existe una tabla de auditoría equivalente, reutilizarla en vez de duplicar).

## Tareas (DB)
Crear UNA migración idempotente en supabase/migrations que haga:

### A) Columna is_enabled en practice_scenarios
- Agregar `practice_scenarios.is_enabled boolean not null default true` (si no existe).
- Comentario en columna.
- Asegurar que el default no rompa seeds.

### B) Tabla de auditoría append-only: practice_scenario_change_events
Crear tabla (si no existe) con:
- id uuid pk default gen_random_uuid()
- org_id uuid not null
- local_id uuid null
- scenario_id uuid not null references practice_scenarios(id)
- actor_user_id uuid null  (auth.uid() al momento del evento; null solo para casos de seed/superadmin tooling si aplica)
- event_type text not null check in ('created','disabled','enabled')  (incluir enabled por si re-enable en futuro; si preferís solo created/disabled, documentarlo)
- payload jsonb not null default '{}'::jsonb
- created_at timestamptz not null default now()

Indexes mínimos:
- (org_id, created_at desc)
- (scenario_id, created_at desc)

Comentarios en tabla y columnas.

### C) RLS para practice_scenario_change_events
- Enable RLS.
- Policies SELECT:
  - superadmin: all
  - admin_org: org_id = current_org_id()
  - referente: local_id = current_local_id()
  - aprendiz: local_id = current_local_id() (o bloquear aprendiz; seguir patrón del repo: si otros eventos son visibles al aprendiz, permitir; si no, bloquear. Documentar decisión.)
- Policy INSERT:
  - Solo vía DB triggers / RPC (pero en Postgres, trigger insert corre como table owner). Para evitar inserts directos:
    - NO otorgar privileges INSERT a authenticated.
    - Opcional: policy INSERT estricta que solo permita cuando actor_user_id = auth.uid() y role in (admin_org, superadmin, referente) pero igual no dar grants.
  - Si el repo usa grants explícitos, seguir el patrón.

### D) Trigger de auditoría en create_practice_scenario
- Modificar el RPC `create_practice_scenario` para que, además de insertar el scenario, inserte un evento `created` en practice_scenario_change_events con:
  - org_id/local_id/scenario_id/actor_user_id/payload { program_id, unit_order, difficulty }
- Mantener output del RPC igual (id, created_at) para no romper contratos.

### E) RPC disable_practice_scenario (write guiado)
Crear RPC `disable_practice_scenario(p_scenario_id uuid, p_reason text default null) -> (id uuid, disabled_at timestamptz)`:
- SECURITY DEFINER siguiendo patrón del repo.
- Validar rol: admin_org o superadmin (no referente/aprendiz).
- Validar que el scenario exista y pertenezca al org (admin_org) o cualquier org (superadmin).
- Admin_org solo puede deshabilitar escenarios ORG-level (local_id is null), igual que create.
- Hacer UPDATE en practice_scenarios: set is_enabled=false
  - Si ya está false, no-op (pero igual puede devolver id/disabled_at actual o now()).
- Insertar evento `disabled` con payload { reason } (si no null).
- No permitir borrar.

RLS/policies para UPDATE en practice_scenarios:
- Agregar policies UPDATE mínimas:
  - admin_org: org_id=current_org_id AND local_id is null
  - superadmin: role=superadmin
- Asegurar que el UPDATE solo afecte is_enabled (si se puede con check en WITH CHECK / usando RPC + column privileges). Si el repo no usa column privileges, documentar el guardrail: solo RPC debe usarse; UI no debe exponer UPDATE.

### F) (Opcional) Ajuste de views Sub-lote 2
- Actualizar v_local_bot_config_* para filtrar `practice_scenarios.is_enabled = true` en conteos/gaps (si corresponde).
- Si ya filtran por is_enabled, verificar coherencia.

## Docs (OBLIGATORIO)
Actualizar:
- docs/post-mvp6/bot-configuration-roadmap.md
  - marcar Sub-lote 3.1 como hecho
  - documentar: is_enabled + disable RPC + tabla de eventos + visibilidad por roles
- docs/activity-log.md
  - entrada “Post-MVP6 Sub-lote 3.1: disable practice_scenarios + audit events”
- docs/db/dictionary.md y docs/db/schema.public.sql
  - regenerar con:
    - npm run db:dictionary
    - npm run db:dump:schema
- Registrar prompt:
  - docs/prompts/POST-MVP6-SUBLOTE-3-1-PRACTICE-SCENARIOS-DISABLE-AUDIT.md

## QA / Smoke (OBLIGATORIO)
1) npx supabase db reset

2) SQL copy/paste (Studio):
- Como admin_org:
  - crear escenario con create_practice_scenario
  - verificar practice_scenarios.is_enabled = true
  - verificar evento created en practice_scenario_change_events
  - llamar disable_practice_scenario
  - verificar is_enabled=false
  - verificar evento disabled (payload reason)

- Como referente/aprendiz:
  - intentar disable_practice_scenario debe fallar
  - select events según la policy definida (o 0 filas si se bloquea aprendiz)

- Como superadmin:
  - poder deshabilitar escenarios local-level también

## Entregables (exactos)
- supabase/migrations/<timestamp>_post_mvp6_s3_1_practice_scenarios_disable_audit.sql
- docs/db/dictionary.md
- docs/db/schema.public.sql
- docs/post-mvp6/bot-configuration-roadmap.md
- docs/activity-log.md
- docs/prompts/POST-MVP6-SUBLOTE-3-1-PRACTICE-SCENARIOS-DISABLE-AUDIT.md

## Commit (directo en main)
- feat(post-mvp6): add practice scenario disable + audit events

Al finalizar:
- Resumen: cambios DB, policies agregadas, RPCs, decisiones de visibilidad aprendiz
- Open questions reales si surgieron
```

Resultado esperado

Disable de practice_scenarios con auditoria append-only y docs actualizadas.

Notas (opcional)

Sub-lote sin UI.
