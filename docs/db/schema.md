# Schema de Base de Datos (regenerable)

Este directorio contiene snapshots **regenerables** del schema `public` de Supabase local.

## Archivos

- `docs/db/dictionary.md`: diccionario de datos (tablas, columnas, RLS y policies).
- `docs/db/schema.public.sql`: dump canónico del schema `public`.

**Regla:** no editar estos archivos a mano. Se regeneran desde CLI.

## Regeneración

```bash
npm run db:dictionary
npm run db:dump:schema
```
