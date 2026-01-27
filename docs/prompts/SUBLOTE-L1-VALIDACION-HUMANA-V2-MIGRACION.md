# SUBLOTE-L1-VALIDACION-HUMANA-V2-MIGRACION

## Contexto

Post-MVP 2 / Sub-lote L.1. Migracion DB-first para decisiones humanas v2 con RLS, sin tocar UI.

## Prompt ejecutado

```txt
Post-MVP 2 / Sub-lote L.1 — Migración DB-first: Validación humana v2 (append-only) + RLS (sin tocar UI)

Objetivo:
Agregar una tabla nueva de decisiones humanas “v2” (estructurada) sin romper v1.
NO cambiar flujos existentes aún. Solo DB + RLS + docs.

Reglas:
- Una sola migración SQL en supabase/migrations/
- Append-only: prohibir UPDATE/DELETE (trigger).
- Zero Trust: RLS estricta. Nada de service_role en clientes.
- Multi-tenancy por helpers current_* (no por inputs).
- NO tocar UI, NO cambiar server actions existentes (eso es L.2/L.3).

1) Crear enums (si no existen):
- decision_type_v2: ('approve','reject','request_reinforcement')
- perceived_severity: ('low','medium','high')
- recommended_action: ('none','follow_up','retraining')

2) Crear tabla nueva:
public.learner_review_validations_v2
Campos mínimos:
- id uuid pk default gen_random_uuid()
- learner_id uuid not null  -- FK a profiles(user_id) o profiles.id según tu schema (usar el que ya se usa en v1)
- reviewer_id uuid not null -- auth.uid()
- local_id uuid not null    -- snapshot (del contexto del learner al momento)
- program_id uuid not null  -- snapshot (program activo del learner al momento)
- decision_type decision_type_v2 not null
- perceived_severity perceived_severity not null default 'low'
- recommended_action recommended_action not null default 'none'
- checklist jsonb not null default '{}'::jsonb
- comment text null
- reviewer_name text not null
- reviewer_role public.app_role not null
- created_at timestamptz not null default now()

Constraints sugeridas:
- checklist debe ser jsonb object: jsonb_typeof(checklist)='object'
- FK/lookup de local_id/program_id:
  - Resolver snapshots vía learner_trainings + locals al insertar (en L.2).
  - En L.1 NO poner defaults mágicos; permitir insert explícito.

Índices:
- (learner_id, created_at desc)
- (local_id, created_at desc)
- (program_id, created_at desc)
- (decision_type, created_at desc)

3) Trigger append-only:
- BEFORE UPDATE/DELETE -> raise exception 'append-only'

4) RLS:
- enable row level security
Policies:
A) SELECT
- superadmin: true
- admin_org: rows where locals.org_id = current_org_id() (join via local_id)
- referente: rows where local_id = current_local_id()
- aprendiz: solo rows where learner_id = auth.uid()
  (y SOLO columnas no sensibles se manejarán en view futura; por ahora permitir select solo propio)
B) INSERT
- superadmin/admin_org/referente: permitido solo si reviewer_id = auth.uid()
  y el learner pertenece a su scope (validar via learner_trainings + locals):
   - referente: learner_trainings.local_id = current_local_id()
   - admin_org: locals.org_id = current_org_id()
- aprendiz: NO puede insertar

IMPORTANTE:
- No confiar en local_id/program_id enviados por cliente para validar scope:
  la policy debe verificar scope por joins (learner_trainings/local/org) usando learner_id.
  (Los snapshots quedan como auditoría, pero el control de acceso se hace por joins).

5) Grants:
- No otorgar a anon.
- Otorgar select/insert a authenticated SOLO si RLS está bien (policies arriba).
- Si el repo usa patrón de revoke/grant central en schema.public.sql, respetarlo.

6) Docs y QA:
- npm run db:dictionary
- npm run db:dump:schema
- npx supabase db reset
- Smoke SQL: como referente y como aprendiz, validar:
  - aprendiz ve solo sus filas (si existen)
  - referente no ve local B (forzado) -> 0
- Actualizar docs/activity-log.md con Sub-lote L.1 + checks.

Entregables:
- supabase/migrations/YYYYMMDDHHMMSS_postmvp2_l1_review_validations_v2.sql
- docs/db/dictionary.md
- docs/db/schema.public.sql
- docs/activity-log.md

NO implementar L.2 (wiring) todavía.
```

Resultado esperado

Migracion con enums, tabla, indices, trigger append-only y RLS. Docs regeneradas y activity log actualizado.

Notas (opcional)

Sin cambios de UI ni server actions.
