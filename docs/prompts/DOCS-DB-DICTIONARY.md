# DOCS-DB-DICTIONARY

## Contexto

Agregar documentación regenerable del schema de Supabase y actualizar AGENTS.md con instrucciones de regeneración.

## Prompt ejecutado

```txt
Sos Codex CLI trabajando en el repo `onbov4` (branch main, sin PRs). Objetivo: agregar documentación regenerable del schema de Supabase en Markdown y actualizar AGENTS.md para que el agente sepa que existe y cómo regenerarlo.

REQUISITOS (NO NEGOCIABLES)
- DB-first / RLS-first.
- La documentación de schema debe ser “source of truth consultable” pero regenerable (no edit manual).
- Debe actualizarse cuando se agreguen o quiten tablas: se regenera desde CLI.
- Todo debe funcionar con Supabase local (supabase start / db reset).
- No usar Prisma/Drizzle. Usar psql directo contra Supabase local.
- Entregable: cambios en repo (scripts + docs + package.json + AGENTS.md) + verificación (db reset, lint, build) + commit directo en main.

TAREAS
1) Crear carpeta `docs/db/`.

2) Crear `scripts/db-dictionary.sh` (ejecutable) que genere `docs/db/dictionary.md` en base al schema `public` del Supabase local.
   - Debe incluir:
     A) Sección “Tablas y columnas” (table_name, column_name, tipo, NOT NULL, default).
     B) Sección “RLS + Policies” por tabla (RLS enabled/disabled, policies con command, USING, WITH CHECK).
   - Debe ser idempotente: siempre sobreescribe el archivo.
   - Debe fallar con error claro si Supabase local no está corriendo o no hay conexión.
   - Debe evitar paginador y formatos raros (psql -At, -P pager=off).
   - Para la conexión, resolver el DB_URL desde `supabase status --output json` y parsearlo con node (no jq, para evitar dependencia).

3) Crear `docs/db/schema.md` como README corto del snapshot:
   - Explicar que `docs/db/dictionary.md` es generado automáticamente y NO se edita.
   - Instrucciones para regenerar:
     - `npm run db:dictionary`
     - `npm run db:dump:schema`
   - Linkear los archivos resultantes.

4) Agregar scripts a `package.json`:
   - `"db:dump:schema"`: generar `docs/db/schema.public.sql` con `supabase db dump --local --schema public`.
   - `"db:dictionary"`: ejecutar `bash scripts/db-dictionary.sh`.

5) Actualizar `AGENTS.md`:
   - Agregar una sección “DB Documentation (regenerable)” indicando:
     - Existe `docs/db/dictionary.md` (diccionario de datos) y `docs/db/schema.public.sql` (dump canónico).
     - Regeneración obligatoria cuando cambien migraciones/tablas/policies:
       - `npm run db:dictionary`
       - `npm run db:dump:schema`
     - Regla: no editar estos snapshots a mano; se regeneran desde CLI.

6) Verificación obligatoria (ejecutar y dejar evidencia en output):
   - `npx supabase db reset`
   - `npm run db:dictionary`
   - `npm run db:dump:schema`
   - `npm run lint`
   - `npm run build`

7) Commit directo en `main` con mensaje:
   - `docs: add regenerable db schema dictionary + update AGENTS`

RESTRICCIONES
- No agregar dependencias nuevas.
- No crear herramientas externas.
- No tocar lógica de negocio existente, solo scripts/docs/config.
- Mantener estilo “copy-paste ejecutable” y rutas correctas.

ENTREGA
- Implementá los cambios, corré la verificación, y confirmá que:
  - `docs/db/dictionary.md` se genera correctamente.
  - `docs/db/schema.public.sql` se genera correctamente.
  - `AGENTS.md` referencia ambos y explica regeneración.
  - build/lint pasan.
```

Resultado esperado
Cambios en scripts, docs y package.json; actualización de AGENTS.md; verificación (db reset, dictionary, dump, lint, build) y commit en main.

Notas (opcional)
Sin dependencias nuevas; psql directo a Supabase local.
