# SUBLOTE-M1-ALERTAS-DB-FIRST

## Contexto

Post-MVP 2 / Sub-lote M.1. Modelo DB-first de alertas/eventos con RLS y append-only.

## Prompt ejecutado

```txt
Post-MVP 2 / Sub-lote M.1 — Alertas: modelo DB-first (eventos) + RLS (sin enviar nada)

Contexto:
ONBO necesita registrar alertas/eventos operativos derivados de acciones humanas
y estados del aprendiz, de forma auditable y multi-tenant, sin notificar aún.

Objetivo:
Definir y crear la infraestructura DB para alertas/eventos (append-only),
con RLS estricta y sin UI.

Reglas:
- DB-first / RLS-first / Zero Trust.
- Append-only (prohibir UPDATE/DELETE).
- Multi-tenancy por org → local.
- NO enviar emails, push ni notificaciones (eso es M.2).
- NO cambiar estados existentes.
- NO tocar UI.

Tareas:
1) Crear enum `alert_type` (mínimo):
   - review_submitted_v2
   - review_rejected_v2
   - review_reinforcement_requested_v2
   - learner_at_risk
   - final_evaluation_submitted

2) Crear tabla `alert_events` (append-only):
   Campos:
   - id uuid pk
   - alert_type alert_type not null
   - learner_id uuid not null
   - local_id uuid not null
   - org_id uuid not null
   - source_table text not null
   - source_id uuid not null
   - payload jsonb not null default '{}'::jsonb
   - created_at timestamptz not null default now()

   Constraints:
   - payload debe ser jsonb object

3) Índices:
   - (org_id, created_at desc)
   - (local_id, created_at desc)
   - (learner_id, created_at desc)
   - (alert_type, created_at desc)

4) Trigger append-only:
   - prevent UPDATE/DELETE

5) RLS:
   - SELECT:
     - superadmin: todo
     - admin_org: org_id = current_org_id()
     - referente: local_id = current_local_id()
     - aprendiz: solo eventos propios (learner_id = auth.uid())
   - INSERT:
     - solo server-only (authenticated con RLS validando scope por joins)
     - aprendiz NO puede insertar

6) Grants:
   - no anon
   - authenticated según RLS
   - service_role ALL (si el patrón del repo lo usa)

7) Docs:
   - Regenerar dictionary + schema
   - Activity log con Sub-lote M.1
   - NO seeds

Entregables:
- Migración SQL única
- docs/db/dictionary.md
- docs/db/schema.public.sql
- docs/activity-log.md

NO wiring ni triggers automáticos aún.
```

Resultado esperado

Migracion con enum, tabla alert_events, RLS, append-only y docs regeneradas.

Notas (opcional)

Sin UI ni wiring.
