# POST-MVP6 Sub-lote 3: Practice scenarios create-only (RPC + RLS)

## Contexto

Habilitar un unico write controlado para crear practice_scenarios (create-only), sin UI ni server actions ni tablas nuevas.

## Prompt ejecutado

```txt
# PROMPT PARA CODEX CLI — Post-MVP6 Sub-lote 3 (DB): 1 write seguro guiado (practice_scenarios create-only) + auditoría mínima (sin tablas nuevas)

Actuá como Backend Engineer (Supabase/Postgres). DB-first, RLS-first, Zero Trust.

## Objetivo
Post-MVP6 Sub-lote 3 — habilitar **UN write** controlado para configuración del bot: **crear escenarios de práctica** (`practice_scenarios`) de forma segura, sin caer en LMS.

**Alcance exacto (MVP-safe):**
- ✅ CREATE-only (INSERT).
- ❌ NO UPDATE/DELETE.
- ❌ NO UI, NO server actions (solo DB).
- ✅ Sin tablas nuevas (auditoría mínima vía `practice_attempt_events` NO aplica; acá no hay attempts. Entonces: solo comentario/contract en docs + future work para auditoría real).

## Decisión operativa (para evitar ambigüedad)
**En este sub-lote, admin_org solo puede crear escenarios ORG-level** (`local_id IS NULL`) dentro de su org.
Superadmin puede crear ORG-level o local-level.

Esto evita decisiones de “a qué local” y mantiene multi-tenant claro.

## Tarea (DB)
1) Crear una migración SQL idempotente que agregue:
   A) RPC `create_practice_scenario(...)` (SECURITY DEFINER) que:
   - Inserta en `practice_scenarios` con:
     - org_id = current_org_id() (o permitido para superadmin)
     - local_id = NULL (para admin_org) o `input_local_id` opcional solo para superadmin
     - program_id (obligatorio)
     - unit_order (obligatorio)
     - title, instructions (obligatorio, no vacíos)
     - success_criteria (text[]; default {} si null)
     - difficulty (int; default 1; clamp/validar rango 1..5)
   - Validaciones duras:
     - `program_id` debe existir en `training_programs` y pertenecer al mismo org (y si program.local_id no es null, NO permitir en este sub-lote para admin_org; superadmin sí).
     - `unit_order` debe existir en `training_units` para ese program_id.
   - Devuelve el row insertado (o al menos id + created_at).
   - No permite spoof de org_id/local_id.
   - Manejo de errores claro con `raise exception`.

   B) RLS/policies mínimas necesarias para permitir INSERT:
   - Agregar policy INSERT sobre `practice_scenarios` para:
     - superadmin: permitir todo
     - admin_org: permitir INSERT solo si `org_id = current_org_id()` AND `local_id is null`
   - Mantener SELECT policies existentes intactas.
   - NO agregar UPDATE/DELETE policies (queda prohibido por default).

   C) Grants:
   - `grant execute` del RPC a roles que correspondan (usar el patrón del repo para roles).
   - Asegurar `revoke all` si el patrón lo exige (seguir estilo existente de otras RPCs).

2) Actualizar docs DB regenerables (OBLIGATORIO):
   - npm run db:dictionary
   - npm run db:dump:schema

3) Actualizar docs (OBLIGATORIO):
   - docs/post-mvp6/bot-configuration-roadmap.md
     - marcar Sub-lote 3 como hecho
     - documentar el contrato del RPC (inputs, validaciones, scope ORG-level)
     - registrar que NO hay auditoría de creación todavía (open item para Post-MVP6 Sub-lote 3.1 si se decide)
   - docs/activity-log.md
     - entrada “Post-MVP6 Sub-lote 3: create-only practice_scenarios (RPC + RLS)”
   - Registrar prompt:
     - docs/prompts/POST-MVP6-SUBLOTE-3-PRACTICE-SCENARIOS-CREATE-ONLY.md

## QA / Smoke (OBLIGATORIO)
- npx supabase db reset
- En SQL (Studio) incluir bloque copy/paste:

1) Como admin_org:
   - llamar `create_practice_scenario` con program_id válido de su org y unit_order existente
   - verificar que `local_id` quedó NULL siempre
   - verificar que un program_id de otra org falla

2) Como referente/aprendiz:
   - intentar llamar RPC debe fallar (sin permiso)
   - SELECT de practice_scenarios sigue funcionando según policies existentes

3) Como superadmin:
   - insertar con local_id opcional (si implementado) y verificar que queda seteado

## Restricción de entrega
Entregar EXACTAMENTE estos archivos:
- supabase/migrations/<timestamp>_post_mvp6_s3_practice_scenarios_create_only.sql
- docs/db/dictionary.md (regenerado)
- docs/db/schema.public.sql (regenerado)
- docs/post-mvp6/bot-configuration-roadmap.md (update)
- docs/activity-log.md (update)
- docs/prompts/POST-MVP6-SUBLOTE-3-PRACTICE-SCENARIOS-CREATE-ONLY.md

## Commit (directo en main)
- feat(post-mvp6): add create-only practice scenarios rpc

Al finalizar:
1) Resumen: policies agregadas, RPC signature, validaciones
2) Listar open questions reales (ej: si queremos auditoría append-only para creación y disable)
```

Resultado esperado

RPC create-only para practice_scenarios con RLS adecuada, y docs actualizadas.

Notas (opcional)

Sub-lote sin UI ni writes adicionales.
