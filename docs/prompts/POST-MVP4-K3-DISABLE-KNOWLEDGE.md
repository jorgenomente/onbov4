# POST-MVP4 K3 DISABLE KNOWLEDGE

## Contexto

Sub-lote K3: desactivar knowledge_items (is_enabled) con RPC y auditoria, sin delete ni edits.

## Prompt ejecutado

```txt
# Post-MVP 4 — Sub-lote K3 (1 write controlado): “Desactivar Knowledge” (Admin Org)

OBJETIVO
Permitir que Admin Org pueda “corregir” contenido sin borrar ni editar:
- Desactivar un knowledge_item (no se borra, no se edita)
- Mantener auditoría append-only de la acción
- Reflejarlo en la UI de coverage/drill-down

IMPORTANTE: Esto NO es un CRUD completo. Es solo “disable”.

ALCANCE (MVP CERRADO)
- 1 write: disable knowledge_item (por id) + evento audit
- UI: botón “Desactivar” en el drill-down de /org/config/knowledge-coverage
- Read model: coverage/list deben ocultar desactivados (o marcarlos claramente)
- No delete
- No editar title/content
- No “reactivar” todavía (opcional, fuera de scope)

DECISIÓN DE MODELO (elige 1, preferida A)
A) Preferida (mínimo schema + claro para clientes):
- Agregar columna `is_enabled boolean not null default true` a knowledge_items
- Permitir UPDATE SOLO de is_enabled=true→false vía RPC (no updates libres)
- Views K1 deben contar/listar solo is_enabled=true

B) Alternativa (full append-only sin UPDATE en tabla):
- Crear tabla knowledge_item_state_events (append-only)
- Derivar enabled_state por latest event en views
- Más compleja; NO hacer en K3.

=> Usar A.

SEGURIDAD / RLS
- knowledge_items:
  - SELECT existente: ajustar para que aprendiz/referente solo vean is_enabled=true (si corresponde).
  - UPDATE:
    - NO habilitar UPDATE general.
    - Solo permitir UPDATE de is_enabled bajo constraints:
      - rol admin_org/superadmin
      - org_id = current_org_id()
      - (local_id is null OR local_id pertenece a org)
      - SOLO si OLD.is_enabled = true AND NEW.is_enabled = false
      - bloquear cualquier cambio de title/content/org_id/local_id
- Alternativa mejor: bloquear UPDATE a nivel trigger + RPC (recomendado).
  - Trigger BEFORE UPDATE en knowledge_items que:
    - permite solo cambiar is_enabled true->false
    - si cambia algo más, raise exception
    - si intenta false->true, raise exception
  - Esto elimina posibilidad de update indebido incluso si alguien logra policy.

AUDITORÍA
- Reusar tabla ya creada en K2: knowledge_change_events (append-only)
  - Insertar evento con:
    - action = 'disable'
    - knowledge_id
    - org_id/local_id snapshot desde knowledge_items
    - program_id/unit_id/unit_order: obtener desde unit_knowledge_map + training_units (si hay múltiples unidades mapeadas, registrar 1 evento por mapping o elegir 1; ver regla abajo)
    - created_by_user_id
    - reason text (obligatorio o opcional)
  - Recomendación: registrar 1 evento por CADA unidad mapeada (más correcto y simple de implementar con INSERT SELECT).

RPC (una sola)
Crear: public.disable_knowledge_item(
  p_knowledge_id uuid,
  p_reason text default null
) returns integer  -- cantidad de mappings afectados (eventos creados)
- Validaciones:
  - role in ('admin_org','superadmin')
  - knowledge_items.org_id = current_org_id()
  - si knowledge_items.local_id not null => local.org_id = current_org_id()
  - si ya is_enabled=false => raise exception 'conflict: already disabled'
  - reason: opcional pero recomendado (trim length <= 500)
- Transacción:
  1) UPDATE knowledge_items set is_enabled=false where id=p_knowledge_id
     (y capturar org_id/local_id/title)
  2) Insert audit events:
     insert into knowledge_change_events (...)
     select ... from unit_knowledge_map join training_units join training_programs
     where unit_knowledge_map.knowledge_id = p_knowledge_id
       and training_programs.org_id = current_org_id()
  3) return rowcount de eventos insertados
- Grants:
  - grant execute to authenticated

DB: MIGRACIÓN ÚNICA (K3)
Crear migración: supabase/migrations/YYYYMMDDHHMMSS_post_mvp4_k3_disable_knowledge.sql

Debe incluir:
1) Alter knowledge_items add column is_enabled boolean not null default true
   - Backfill implícito por default (para filas existentes, set true)
2) Trigger guardrail BEFORE UPDATE on knowledge_items:
   - permitir solo is_enabled true->false
   - bloquear cualquier otro update
3) Policies:
   - SELECT en views/list (K1) ajustadas para ignorar is_enabled=false
   - UPDATE policy (si la necesitás para que RPC haga update):
     - admin_org/superadmin + org scope
   - Ojo: si trigger hace el bloqueo, la policy solo habilita UPDATE pero el trigger controla.
4) RPC disable_knowledge_item
5) Actualizar views K1:
   - v_org_program_unit_knowledge_coverage: contar SOLO knowledge_items.is_enabled=true
   - v_org_unit_knowledge_list: listar SOLO is_enabled=true (o mostrar enabled flag; MVP: filtrar)

REGENERAR DOCS DB
- npx supabase db reset
- Regenerar docs/db/dictionary.md y docs/db/schema.public.sql

UI (Next.js / RSC)
Ruta existente:
- /org/config/knowledge-coverage

Cambios UI:
- En el drill-down list por unidad:
  - agregar botón “Desactivar” por knowledge item
  - confirmación simple (window.confirm o modal mínimo)
  - campo motivo opcional (puede ser prompt input) o reutilizar textarea pequeño
  - Server Action SSR:
    - llama supabase.rpc('disable_knowledge_item', { p_knowledge_id, p_reason })
    - revalidatePath('/org/config/knowledge-coverage')
    - redirect con ?success=... o ?error=...
- UX copy:
  - “Desactivar no borra. El item deja de usarse para el bot desde ahora.”

QA / GATE
- npx supabase db reset
- Manual:
  1) Admin Org crea un knowledge nuevo (K2)
  2) Confirmar que aparece en drill-down y coverage
  3) Click “Desactivar” -> confirmar
  4) Confirmar que:
     - desaparece del drill-down (o se marca como desactivado si decidís no filtrar)
     - coverage decrementa
     - evento 'disable' insertado en knowledge_change_events
  5) Referente no puede desactivar (botón no visible / RPC falla por RLS)
- npm run lint
- npm run build

DOCS / LOG
- docs/activity-log.md: “Post-MVP4 K3 disable knowledge (RPC + guardrails)”
- docs/prompts/POST-MVP4-K3-DISABLE-KNOWLEDGE.md

TRABAJO
- Directo sobre main.
- Fixes mínimos si bloquean gates, loguear.

NOTAS
- Si un knowledge está mapeado a múltiples unidades, se registran múltiples eventos (uno por mapping).
- No agregamos “reactivar” en K3.
```

Resultado esperado

Migracion, RPC, guardrails y UI para desactivar knowledge.

Notas (opcional)

Sin notas.
