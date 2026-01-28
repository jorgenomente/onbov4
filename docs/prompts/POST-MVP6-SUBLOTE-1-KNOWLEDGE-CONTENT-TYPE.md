# POST-MVP6 Sub-lote 1: Knowledge content type (DB minimo)

## Contexto

Agregar tipado opcional de knowledge_items para clasificacion pedagogica, sin tocar UI ni server actions.

## Prompt ejecutado

```txt
Actuá como Backend Engineer.
Objetivo: Post-MVP6 Sub‑lote 1 — DB mínimo: tipado opcional de knowledge_items.

Contexto:
- No inventar tablas nuevas fuera del alcance.
- Mantener DB‑first, RLS‑first, append‑only donde aplique.
- No tocar UI ni server actions.
- Respetar el roadmap y contrato en docs/post-mvp6/bot-configuration-roadmap.md.

Tarea
1) Crear migración idempotente que:
   - Agrega enum `knowledge_content_type` con valores: concepto, procedimiento, regla, guion.
   - Agrega columna nullable `knowledge_items.content_type` (sin default).
   - Comentarios en type y column.

2) Actualizar documentación DB regenerable:
   - npm run db:dictionary
   - npm run db:dump:schema

3) Actualizar docs:
   - docs/post-mvp6/bot-configuration-roadmap.md (marcar Sub‑lote 1 como hecho + describir cambios)
   - docs/activity-log.md (entrada Post‑MVP6 Sub‑lote 1)

4) Registrar prompt en /docs/prompts/ (OBLIGATORIO).

Entregables:
- Archivo SQL en supabase/migrations.
- docs/db/dictionary.md actualizado.
- docs/db/schema.public.sql actualizado.
- docs/post-mvp6/bot-configuration-roadmap.md actualizado.
- docs/activity-log.md actualizado.
- docs/prompts/POST-MVP6-SUBLOTE-1-KNOWLEDGE-CONTENT-TYPE.md

QA/Smoke:
- db reset aplica.
- SELECT muestra content_type.
- RLS intacto (no nuevas policies).

Commit:
- feat(post-mvp6): add optional knowledge content type
```

Resultado esperado

Migracion y docs DB actualizadas, con registro en activity-log y roadmap Post-MVP6.

Notas (opcional)

Se ejecuta como sub-lote DB minimo sin UI.
