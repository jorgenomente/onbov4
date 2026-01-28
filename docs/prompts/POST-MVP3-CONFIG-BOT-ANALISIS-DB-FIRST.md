# POST-MVP3 CONFIG BOT ANALISIS DB FIRST

## Contexto

Sub-lote A de Post-MVP 3 para inventario real de schema y contrato mínimo operable de configuración del bot (Admin Org). Solo documentación.

## Prompt ejecutado

```txt
Post-MVP 3 / Sub-lote A — Análisis DB-first (docs-only): Configuración del bot (Admin Org)

Contexto:
ONBO ya funciona end-to-end (validación humana v2, alertas, evaluación final). Ahora queremos
hacer el sistema operable por clientes sin convertirlo en un LMS: configuración simple y guiada
para Admin Org (y Superadmin solo para auditoría/soporte).

Objetivo del sub-lote A:
Generar el inventario REAL del schema y un contrato mínimo operable para “Configuración del bot”.
SOLO DOCUMENTACIÓN. NO migraciones. NO UI. NO cambios de código.

Reglas:
- DB-first / RLS-first / Zero Trust (en análisis).
- No inventar tablas/features que no existan.
- No proponer un course builder estilo LMS.
- Multi-tenant estricto org → local.
- Append-only como principio para cambios que afecten auditoría.

Tareas:

1) Inventario del schema (REAL)
Inspeccioná el repo y el schema actual (supabase/migrations + docs/db/schema.public.sql + docs/db/dictionary.md)
y documentá:

A) Programas / estructura
- Qué tablas existen para: programas, unidades, asignación programa↔local.
- Campos relevantes y enums actuales (status, order, etc).
- Cómo se define “programa activo” para un local (si existe concepto).

B) Conocimiento (knowledge)
- Qué tablas existen para knowledge items / fuentes.
- Si hay scope org vs local, cómo está modelado.
- Cómo se relaciona knowledge con unidades/programa.

C) Evaluación final (config/política)
- Dónde vive HOY la configuración: cantidad preguntas, mix roleplay/directas, dificultad, límites intentos, cooldown.
- Si no existe como config, documentar dónde está hardcodeado.
- Qué tablas capturan attempts/questions/answers y cómo se enlazan a program/local.

D) Permisos y RLS
- Qué roles hoy pueden leer/escribir cada bloque (program/units/knowledge/policy).
- Qué helpers existen (current_org_id, current_local_id, current_role, etc).

E) Consumo actual (app)
- Qué rutas/actions leen estas piezas hoy.
- Qué parte hoy se hace por seed/SQL vs por UI.

2) Contrato mínimo operable (en papel)
Basado en el inventario real, definir 3 listas:

✅ Configurable por Admin Org (MVP)
- Campos y acciones exactas que podrían exponerse en UI sin riesgo.

❌ No configurable (por ahora)
- Todo lo que sería peligroso o nos haría caer en LMS.

🟡 Configurable después (futuro)
- Cosas valiosas pero no necesarias para operabilidad inicial.

3) Reglas de cambio (no retroactivo)
Para cada ítem ✅, indicar:
- “aplica desde ahora” (a qué entidades afecta)
- si requiere versionado/append-only
- riesgos si se permite update destructivo

4) Recomendación de próximos sub-lotes (orden exacto)
Proponer el plan mínimo ejecutable para avanzar a configuración:
- A.1 (si hace falta): aclaraciones/faltantes
- B.1: views read-only “config actual”
- C.1: versionado mínimo (si aplica)
- C.2: RPC write seguro (1 solo write primero)
- D.1: UI Admin mínima (1 pantalla, 1 write)

Formato de salida (obligatorio):
- Sección 1: Inventario real (Programas / Unidades / Knowledge / Evaluación Final / RLS / Consumo app)
- Sección 2: Contrato mínimo operable (✅ / ❌ / 🟡)
- Sección 3: Reglas “desde ahora” + implicancias de versionado
- Sección 4: Plan de sub-lotes recomendado (con deliverables)

Entregables en repo (docs-only):
- docs/post-mvp3/config-bot/A0-inventory.md
- docs/post-mvp3/config-bot/A1-contract.md
- docs/activity-log.md (entrada Post-MVP3 Sub-lote A)

NO escribir SQL.
NO tocar UI.
NO tocar server actions.
```

Resultado esperado

Documentación en `docs/post-mvp3/config-bot/` y actualización de `docs/activity-log.md`.

Notas (opcional)

Sin notas.
