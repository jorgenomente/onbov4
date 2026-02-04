# RLS-LINT-CONSOLIDATE-ALL-REMAINING

## Contexto

Consolidar todos los grupos restantes de policies PERMISSIVE (multiple permissive) en una sola migracion, y aplicar criterios de coalesce para evitar aperturas accidentales.

## Prompt ejecutado

```txt
**Opción 1.** Consolidar **todos** los grupos restantes en **una sola migración**.

Criterios para que quede “bien” y no volvamos a abrir warnings ni romper RLS:

* **1 policy por (tabla, cmd, rol DB)** (en tu caso `to public`).
* **SELECT/DELETE**: `USING ( OR de todas las qual )`.
* **INSERT**: `WITH CHECK ( OR de todos los with_check )`.
* **UPDATE**: `USING ( OR qual )` **y** `WITH CHECK ( OR with_check )`.
* Para robustez cuando venga null:

  * `qual_term := COALESCE(qual, 'false')` (si no hay qual en un SELECT policy, mejor no abrir por accidente)
  * `check_term := COALESCE(with_check, qual, 'false')` (si alguna update policy no define check, al menos hereda su qual; si ninguna, queda false)
* Mantener **PERMISSIVE** (no cambies semantics), y poner nombres consistentes tipo:

  * `"<table>_<cmd>_authenticated"` o `"<table>_<cmd>_public_consolidated"`.

**Checks antes y después (obligatorios):**

1. `npx supabase db reset`
2. Re-correr el query de “multiple permissive” → **0 rows**
3. `npm run db:dictionary` y `npm run db:dump:schema`
4. Smoke RLS rápido (las rutas mínimas: aprendiz SELECT/INSERT donde aplique, referente SELECT, admin_org SELECT)

Ejecutá la migración batch2 con ese enfoque y listo.
```

Resultado esperado

Migracion batch2 que consolide todas las policies restantes y deje el linter en 0 rows para multiple permissive.

Notas (opcional)

N/A.
