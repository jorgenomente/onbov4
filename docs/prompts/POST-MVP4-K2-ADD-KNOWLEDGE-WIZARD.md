# POST-MVP4 K2 ADD KNOWLEDGE WIZARD

## Contexto

Sub-lote K2: write guiado para crear knowledge_item y mapearlo a una unidad (admin_org) con RPC y auditoria append-only.

## Prompt ejecutado

```txt
# Post-MVP 4 — Sub-lote K2 (1 write guiado): “Agregar Knowledge a Unidad” (Admin Org)

OBJETIVO
Habilitar que Admin Org pueda cargar conocimiento SIN SQL de forma guiada y segura:
- Crear 1 knowledge_item
- Mapearlo a 1 unidad (unit_knowledge_map)
Todo en una sola acción (transacción), sin abrir CRUD libre tipo LMS.

ALCANCE (MVP CERRADO)
- 1 write: “Agregar knowledge a unidad” (create + map).
- Read model: reutilizar K1 (coverage + list) para ver el resultado.
- Sin edición de knowledge existente (append-only).
- Sin delete. Sin update.
- No “builder”.

NO HACER
- No UI para editar programs/units.
- No UI para editar knowledge existente.
- No versionado complejo.
- No prompts tuning.
- No service_role en clientes.

CONTEXTO DB (YA EXISTE)
- public.training_programs
- public.training_units
- public.knowledge_items (org_id, local_id nullable, title, content, created_at)
- public.unit_knowledge_map (unit_id, knowledge_id PK compuesta)
- Views K1:
  - v_org_program_unit_knowledge_coverage
  - v_org_unit_knowledge_list

REQUERIMIENTOS CRÍTICOS
- Multi-tenant estricto (org → local).
- RLS-first + Zero Trust.
- Writes SOLO via RPC (server-side) y Server Action SSR (cookies).
- Validaciones duras para evitar inconsistencias.
- Auditoría mínima append-only (recomendado).

DB: MIGRACIÓN ÚNICA (K2)
Crear migración: supabase/migrations/YYYYMMDDHHMMSS_post_mvp4_k2_add_knowledge_rpc.sql

1) RLS writes para knowledge (mínimo)
- knowledge_items:
  - Mantener SELECT existente.
  - Agregar INSERT SOLO para roles ('admin_org','superadmin'):
    - new.org_id = current_org_id()
    - new.local_id is null OR new.local_id pertenece a org (join locals)
  - NO UPDATE/DELETE.

- unit_knowledge_map:
  - Mantener SELECT existente.
  - Agregar INSERT SOLO para ('admin_org','superadmin'):
    - unit_id visible por org (via training_units -> training_programs.org_id = current_org_id())
    - knowledge_id visible por org (knowledge_items.org_id = current_org_id())
  - NO UPDATE/DELETE.

2) Auditoría append-only (recomendado, mínimo)
Crear tabla: public.knowledge_change_events (append-only)
Campos mínimos:
- id uuid pk default gen_random_uuid()
- org_id uuid not null
- local_id uuid null
- program_id uuid not null
- unit_id uuid not null
- unit_order int not null
- knowledge_id uuid not null
- action text not null default 'create_and_map'
- created_by_user_id uuid not null
- title text not null
- created_at timestamptz not null default now()
Aplicar trigger prevent_update_delete().
RLS:
- SELECT: admin_org (org scope), superadmin (todo). (referente opcional solo lectura, pero NO necesario en K2)
- INSERT: admin_org/superadmin (pero idealmente SOLO via RPC; igual queda protegido por role + org)

3) RPC transaccional (una sola)
Crear: public.create_and_map_knowledge_item(
  p_program_id uuid,
  p_unit_id uuid,
  p_title text,
  p_content text,
  p_scope text,        -- 'org' | 'local'
  p_local_id uuid,     -- requerido si scope='local', null si scope='org'
  p_reason text default null
) returns uuid  -- retorna knowledge_id
- SECURITY INVOKER (default).
- Validaciones:
  - role in ('admin_org','superadmin')
  - program_id pertenece a current_org_id()
  - unit_id pertenece al program_id (training_units.program_id = p_program_id)
  - scope:
    - if p_scope='org': p_local_id debe ser null
    - if p_scope='local': p_local_id not null y local.org_id = current_org_id()
  - p_title trimmed length > 0 (ej <= 120)
  - p_content trimmed length > 0 (ej <= 20000) (solo guardrail razonable)
- Transacción:
  - Insert knowledge_items(org_id=current_org_id(), local_id según scope, title, content) returning id
  - Insert unit_knowledge_map(unit_id, knowledge_id)
  - Insert knowledge_change_events con snapshot (org/local/program/unit/order/title/user)
- Manejar conflicto:
  - si mapping ya existe: error conflict (unit_id, knowledge_id) por PK compuesta (mostrar mensaje user-friendly en UI).
- Grants:
  - grant execute to authenticated.

REGENERAR DOCS DB
- npx supabase db reset
- Regenerar docs/db/dictionary.md y docs/db/schema.public.sql

UI (Next.js 16 / RSC) — 1 flujo guiado
Ruta recomendada:
- Reutilizar pantalla K1: /org/config/knowledge-coverage
  - Agregar botón “Agregar knowledge” (visible solo admin_org/superadmin)
  - Modal (o panel) para el wizard

Wizard “Agregar knowledge a unidad”
Inputs:
1) Programa (si ya está seleccionado en K1, reusar)
2) Unidad (dropdown: training_units por program_id, order by unit_order)
3) Scope:
   - radio: “Compartido (Organización)” vs “Específico (Local)”
   - Si “Local”: dropdown de locals de la org
4) Title (text)
5) Content (textarea)
6) Motivo (opcional)

Submit:
- Server Action SSR:
  - valida básicos + trims
  - llama RPC create_and_map_knowledge_item
  - revalidatePath('/org/config/knowledge-coverage')
  - redirect con ?success=1 o ?error=...
UX:
- Mensaje claro: “Esto crea un item nuevo (append-only). No edita items existentes.”
- Al éxito, mostrar en el drill-down (v_org_unit_knowledge_list) el nuevo item.

Estados:
- loading, empty, error, success (consistente con D.1)

QA / GATE
- npx supabase db reset
- Manual:
  1) Login admin_org
  2) Ir /org/config/knowledge-coverage
  3) Seleccionar Programa Demo
  4) Elegir una unidad y agregar knowledge org-level
  5) Ver que:
     - coverage count aumenta
     - aparece en drill-down list
     - existe evento en knowledge_change_events
- RLS negative:
  - Login referente: botón no visible / intento write falla por RLS
- npm run lint
- npm run build

DOCS / LOG
- docs/activity-log.md: “Post-MVP4 K2 add knowledge wizard (RPC + audit)”
- docs/prompts/POST-MVP4-K2-ADD-KNOWLEDGE-WIZARD.md

TRABAJO
- Directo sobre main.
- Arreglar build breaks preexistentes solo si bloquean gate y loguear.
```

Resultado esperado

Migracion, RPC, RLS, auditoria y UI read/write guiado en K1.

Notas (opcional)

Sin notas.
