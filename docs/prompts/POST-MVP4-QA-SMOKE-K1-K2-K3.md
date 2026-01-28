# POST-MVP4 QA SMOKE K1 K2 K3

## Contexto

QA DB-first para Post-MVP4 (K1/K2/K3): crear y ejecutar smokes reproducibles.

## Prompt ejecutado

```txt
Post-MVP4 — QA DB-first (Smoke) para K1/K2/K3

Contexto:
- Repo: onbo-conversational (trabajo directo sobre main, sin ramas)
- Post-MVP4 ya implementado:
  - K1: views read-only de knowledge coverage + UI /org/config/knowledge-coverage
  - K2: writes guiados (wizard) + RLS INSERT para knowledge + audit append-only + RPC create_and_map_knowledge_item (nombre/firma a verificar)
  - K3: disable knowledge (is_enabled + guardrail true→false) + RPC disable_knowledge_item (nombre/firma a verificar) + audit

Objetivo:
- Crear y correr smokes SQL reproducibles (DB-first) para K1/K2/K3.
- NO inventar nombres/firmas: inspeccionar migraciones y schema actual.
- Dejar evidencia en docs/activity-log.md.
- Commit directo en main + push.

Plan:

1) Inspección (obligatoria)
- Buscar en supabase/migrations los archivos Post-MVP4 K1/K2/K3.
- Extraer:
  - nombres exactos de views K1
  - tablas involucradas (knowledge_items, unit_knowledge_map, knowledge_change_events, etc.)
  - RPCs y SUS FIRMAS exactas (pg_proc / migración)
  - triggers/guardrails (append-only / true→false)

2) Crear 3 smokes (docs/qa/)
- docs/qa/smoke-post-mvp4-k1.sql
  Debe validar como admin_org:
  - SELECT devuelve filas (o 0 filas pero sin error) en cada view K1 para el Programa Demo
  - coverage por unidad y gaps summary ejecutan sin RLS errors
  - (opcional) verificar que referentes no puedan acceder a vistas org-only si aplica
- docs/qa/smoke-post-mvp4-k2.sql
  Debe validar como admin_org:
  - Ejecutar la RPC (según firma real) para crear knowledge item + mapearlo a una unidad existente del programa demo
  - Verificar que:
    - existe el knowledge_item creado
    - existe el mapping en unit_knowledge_map
    - se insertó evento en knowledge_change_events (append-only)
  - Asegurar cleanup mínimo: si hace falta, usar valores únicos en title para no chocar en reruns
- docs/qa/smoke-post-mvp4-k3.sql
  Debe validar como admin_org:
  - Tomar un knowledge_item habilitado (is_enabled=true) mapeado a una unidad
  - Llamar RPC disable_knowledge_item (según firma real)
  - Verificar:
    - knowledge_items.is_enabled quedó false
    - evento en knowledge_change_events con action=disable (o equivalente)
    - guardrail: intentar reactivar (false→true) debe FALLAR (si aplica)
    - si hay trigger de “solo true→false”, probar el fallo explícito

3) Ejecución local (obligatoria)
- Correr:
  - npx supabase db reset
- Ejecutar los 3 smokes en orden:
  - smoke-post-mvp4-k1.sql
  - smoke-post-mvp4-k2.sql
  - smoke-post-mvp4-k3.sql
Usar la misma técnica que ya usamos: psql con SET ROLE authenticated + request.jwt.claims para simular admin_org real (email admin@demo.com).
Si hay ya scripts/helpers en docs/qa o Makefile/npm scripts, reutilizarlos.

4) Evidencia + docs
- Agregar entrada en docs/activity-log.md con:
  - fecha, alcance Post-MVP4 QA
  - PASS/FAIL por smoke
  - notas de gotchas (ej: si hubo que setear algún campo NOT NULL, etc.)

5) Gates + commit
- Ejecutar (mínimo):
  - npm run lint
  - npm run build
- Commit directo en main:
  - docs(post-mvp4): add + run db-first smokes k1-k3
- Push a origin main

Restricciones:
- No tocar UI.
- No cambiar migraciones existentes salvo que un smoke revele un bug real; si aparece bug, arreglarlo con una migración nueva + documentar.
- No usar service_role.
```

Resultado esperado

Smokes DB-first creados y ejecutados para K1/K2/K3, con evidencia en activity-log y commit en main.

Notas (opcional)

Sin notas.
