# POST-MVP6 Sub-lote 4: UI Bot Config (read + create/disable)

## Contexto

Implementar pantalla /org/bot-config con lectura de views y acciones create/disable de practice_scenarios.

## Prompt ejecutado

```txt
# PROMPT PARA CODEX CLI — Post-MVP6 Sub-lote 4 (UI mínima): Config del Bot (read + create/disable practice_scenarios)

Actuá como Senior Frontend Engineer + Senior Backend Engineer (Next.js App Router + Supabase). Enfoque: UX operativa, mobile-first, DB-first.

## Objetivo
Post-MVP6 Sub-lote 4 — Implementar **UNA pantalla** de “Configuración del Bot” para Admin Org / Superadmin con:
1) Lectura consolidada (read-only) usando las views Post-MVP6 S2:
   - v_local_bot_config_summary
   - v_local_bot_config_units
   - v_local_bot_config_gaps
2) Acciones mínimas:
   - Crear practice_scenario (RPC: create_practice_scenario)
   - Deshabilitar practice_scenario (RPC: disable_practice_scenario)

Sin inventar features tipo LMS:
- ❌ no editar escenarios
- ❌ no re-enable
- ❌ no mover unidades / programas
- ❌ no CRUD de programs/units
- ✅ solo create + disable, con guardrails

## Contexto (MANDATORIO)
- Repo: onbo-conversational (trabajo directo en main).
- Stack obligatorio: Next.js 16 App Router, TS, Tailwind mobile-first.
- Supabase: @supabase/ssr, RLS estricta (nada de service_role en clientes).
- Multi-tenant estricto.
- DB disponible:
  - Views: v_local_bot_config_summary / units / gaps
  - Tabla: practice_scenarios (tiene is_enabled)
  - RPCs: create_practice_scenario, disable_practice_scenario

## Ruta / Navegación
Agregar una ruta protegida para Admin Org / Superadmin:
- `/org/bot-config`

Entry point:
- Agregar link en navegación del backoffice de org (donde ya exista nav para /org/*).
  - Si hay un layout/nav común, incluir ítem “Bot” o “Config Bot”.
  - No inventar un sistema de permisos nuevo: usar el patrón existente de guard server-side.

## Contrato de datos (NO SELECT *)
En server component (RSC), cargar:
A) Summary:
- select columnas explícitas desde v_local_bot_config_summary
- Para admin_org: mostrar filas de todos los locales de su org
- Para superadmin: permitir filtrar por org/local (mínimo: mostrar todo paginado o pedir local por query param; elegir la opción más simple ya existente en el repo)

B) Units + Gaps:
- cuando el usuario selecciona un local, cargar:
  - v_local_bot_config_units (order by unit_order)
  - v_local_bot_config_gaps (where is_missing_* true)

C) Practice scenarios list (activos) para poder deshabilitar:
- NO existe view dedicada; usar tabla practice_scenarios con select explícito:
  - id, program_id, unit_order, title, difficulty, created_at, local_id, org_id, is_enabled
- Filtrar:
  - org_id/current_org_id y (local_id is null OR local_id = selected_local_id)
  - is_enabled = true
- Si hay patrón de “org scope knowledge” similar, seguirlo.

## UX (mobile-first, minimalista)
Pantalla `/org/bot-config`:

1) Header
- Título: “Config del Bot”
- Subtexto: “Lectura operativa + escenarios de práctica”

2) Selector de Local
- Si admin_org tiene múltiples locales: dropdown/selector
- Default: primer local disponible
- Mostrar métricas de summary del local seleccionado.

3) Card: Resumen
- Programa activo + config final (total questions, ratio, min score, cooldown)
- Conteos: knowledge total / practice scenarios activos / unidades totales

4) Sección: Unidades
- Lista por unidad:
  - unit_order + title
  - knowledge_count
  - practice_scenarios_count
  - badge si está en gaps (missing_knowledge / missing_practice)
- CTA por unidad: “Crear escenario” abre modal (preselecciona unit_order)

5) Sección: Gaps (si hay)
- Lista corta determinista: unidades con missing_knowledge / missing_practice

6) Modal: Crear escenario
Campos:
- unit_order (readonly si viene desde unidad; editable si viene desde botón general)
- title (required)
- instructions (required, textarea)
- difficulty (1..5, default 1)
- success_criteria (simple: textarea multiline -> split por newline a text[])
- Botón “Crear” llama RPC create_practice_scenario
- Handling:
  - loading state
  - error inline
  - success: cerrar modal + refresh data (revalidatePath)

7) Acción: Deshabilitar escenario
- En cada unidad, mostrar escenarios activos (solo título + dificultad)
- Botón “Deshabilitar” abre confirm dialog con campo opcional reason (1 línea)
- Al confirmar, llama RPC disable_practice_scenario(id, reason)
- success: refresh data

## Seguridad / Server Actions (crítico)
- Todas las mutaciones deben ser **Server Actions** (o Route Handlers) usando supabase server client.
- Validar rol server-side (admin_org o superadmin) antes de llamar RPC.
- No exponer RPC calls desde client supabase directo.
- Mantener “nada de lógica sensible en frontend”.

## Archivos esperados (mínimos)
- app/org/bot-config/page.tsx (RSC)
- app/org/bot-config/actions.ts (server actions: create/disable)
- componentes locales (si hace falta) en app/org/bot-config/_components/*
- Actualizar navegación/backoffice layout donde corresponda
- docs/activity-log.md (entrada Post-MVP6 Sub-lote 4 UI)
- docs/prompts/POST-MVP6-SUBLOTE-4-UI-BOT-CONFIG.md

No tocar SQL en este sub-lote.

## QA / Smoke (OBLIGATORIO)
1) npx supabase db reset
2) npm run lint
3) npm run build
4) Manual:
- Loguear como admin_org
- Ir a /org/bot-config
- Ver summary + units + gaps
- Crear escenario en una unidad (se ve en la lista)
- Deshabilitar escenario (desaparece de la lista)
- Confirmar en DB que audit event se creó (opcional, en Studio)

## Commit (directo en main)
- feat(post-mvp6): add bot config UI (read + practice scenario actions)

Al finalizar:
- Resumen de archivos tocados
- Nota de cualquier limitación (p.ej. selector de local en superadmin)
- Confirmar que no se tocó SQL
```

Resultado esperado

Pantalla /org/bot-config con lectura de views y acciones create/disable practice_scenarios.

Notas (opcional)

Sub-lote sin cambios de DB.
