# SUBLOTE-L2-WIRING-VALIDACION-HUMANA-V2

## Contexto

Post-MVP 2 / Sub-lote L.2. Wiring server-only para insertar decisiones v2 sin tocar UI.

## Prompt ejecutado

```txt
Post-MVP 2 / Sub-lote L.2 — Wiring server-only para Validación humana v2

Objetivo:
Crear el wiring backend (Server Action o RPC) para insertar decisiones en
learner_review_validations_v2 usando el contrato v2, sin tocar UI.

Reglas:
- NO migraciones DB.
- NO cambios de UI.
- Server-only.
- Derivar snapshots (local_id, program_id) en backend.
- reviewer_id = auth.uid() siempre.
- Usar Supabase SSR client.
- RLS debe ser la única barrera de seguridad.

Tareas:
1) Crear una Server Action (o RPC si el patrón del repo lo prefiere)
   que reciba:
   - learner_id
   - decision_type
   - perceived_severity
   - recommended_action
   - checklist (jsonb)
   - comment (opcional)

2) En backend:
   - Obtener reviewer_name y reviewer_role desde profiles
   - Obtener local_id y program_id desde learner_trainings
     (no confiar en input del cliente)

3) Validar:
   - learner en estado en_revision
   - rol permitido (admin_org | referente | superadmin)

4) Insertar en learner_review_validations_v2

5) Manejo de errores:
   - fail-closed
   - mensajes claros (no genéricos)

6) QA:
   - Smoke manual como referente/admin
   - Aprendiz no puede ejecutar la acción

Entregables:
- Archivo(s) de Server Action / RPC
- Update en docs/activity-log.md

NO implementar cambios de estado ni emails.
```

Resultado esperado

Server Action/RPC para insertar decisiones v2 con derivaciones server-side, validaciones y activity log actualizado.

Notas (opcional)

Sin UI ni cambios de estado/emails.
