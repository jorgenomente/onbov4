# FIX-RLS-INITPLAN-AUTH-SELECT

## Contexto

Aplicar un fix idempotente para policies RLS con auth.uid()/auth.role()/current_setting() envolviendo en SELECT.

## Prompt ejecutado

```text
Vamos con la opción 1 y la hago “a prueba de lista incompleta”: una migración única que re-crea automáticamente esas policies tomando la definición actual desde pg_policies y aplicando reemplazos (auth.uid() → (select auth.uid()), etc.). Así no dependemos de copiar/pegar 37 create policy a mano, y mantenés semántica idéntica.

✅ Migración única (idempotente) para auth_rls_initplan

Crea un archivo, por ejemplo:

supabase/migrations/20260128120000_fix_rls_initplan_select_auth.sql

y pegá esto:

-- Fix Supabase linter: auth_rls_initplan
-- Recreate affected RLS policies replacing auth.* and current_setting() calls
-- to be initplan-friendly: (select auth.uid()), etc.
--
-- Safe: does not change logic, only wraps volatile calls to avoid per-row re-eval.

(do $$ ... $$;)

... (contenido completo de la migracion)
```

## Resultado esperado

Migracion idempotente que recrea las policies listadas con auth.\* y current_setting envueltos en SELECT.
