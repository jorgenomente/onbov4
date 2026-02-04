# LINTER-RLS-WARNINGS-PLAN

## Contexto

El usuario propone un plan para eliminar warnings de Splinter/RLS (InitPlan y Multiple Permissive Policies) y pide avanzar con consolidaciones/migración.

## Prompt ejecutado

````txt
Dale, esto ya no es “un bug puntual”: es **un patrón** del linter (Splinter) que te va a seguir tirando warnings mientras tengas:

1. **Multiple Permissive Policies** (mismo `table + action + role` con más de una PERMISSIVE), y/o
2. **Auth RLS Initialization Plan** (funciones como `auth.uid()`, `auth.role()`, `current_setting()` evaluadas por fila).

Abajo te dejo un plan “industrial” para liquidar **todos** los posibles warnings de este tipo, con queries para **detectar → agrupar → arreglar**.

---

## 0) Regla de oro: cuándo arreglar vs cuándo ignorar

* **Auth RLS InitPlan**: casi siempre conviene arreglarlo (es mecánico y no cambia lógica).
* **Multiple Permissive Policies**: conviene arreglarlo **solo cuando**:

  * Todas aplican al **mismo rol DB** (p. ej. `authenticated`) y
  * Se ejecutan para el **mismo action** (SELECT/INSERT/UPDATE/DELETE).

En Supabase es común que todas sean “TO authenticated” y la segmentación real sea por `public.current_role()` (tu `app_role`). Eso **dispara el warning**, y la solución es **consolidar**.

---

## 1) Detectar TODO lo que queda (queries canónicas)

### 1.1 — Encontrar policies que aún evalúan `auth.*` / `current_setting()` por fila

> Busca llamadas no envueltas en `(select ...)`.

```sql
select
  schemaname,
  tablename,
  policyname,
  cmd,
  roles,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and (
    qual ilike '%auth.%' or qual ilike '%current_setting(%'
    or with_check ilike '%auth.%' or with_check ilike '%current_setting(%'
  )
  and (
    -- auth.uid()
    (qual ilike '%auth.uid()%' and qual not ilike '%(select auth.uid())%')
    or (with_check ilike '%auth.uid()%' and with_check not ilike '%(select auth.uid())%')

    -- auth.role()
    or (qual ilike '%auth.role()%' and qual not ilike '%(select auth.role())%')
    or (with_check ilike '%auth.role()%' and with_check not ilike '%(select auth.role())%')

    -- current_setting('...')
    or (qual ilike '%current_setting(%' and qual not ilike '%(select current_setting(%')
    or (with_check ilike '%current_setting(%' and with_check not ilike '%(select current_setting(%')
  )
order by tablename, cmd, policyname;
````

### 1.2 — Detectar “Multiple Permissive Policies” por tabla/acción/rol

**Ojo**: en `pg_policies.roles` vienen roles como array en texto. Esto te permite agrupar.

```sql
with p as (
  select
    schemaname,
    tablename,
    cmd,
    policyname,
    permissive,
    roles
  from pg_policies
  where schemaname = 'public'
),
expanded as (
  select
    schemaname,
    tablename,
    cmd,
    policyname,
    permissive,
    unnest(roles) as role
  from p
)
select
  schemaname,
  tablename,
  cmd,
  role,
  count(*) as policy_count,
  array_agg(policyname order by policyname) as policies
from expanded
where permissive = 'PERMISSIVE'
group by schemaname, tablename, cmd, role
having count(*) > 1
order by policy_count desc, tablename, cmd, role;
```

Con esto vas a poder ver exactamente lo que te muestra el dashboard (como lo de `public.conversations`).

---

## 2) Cómo se arregla cada clase (patrones)

## A) Auth RLS Initialization Plan (wrap)

Lo correcto (y ya lo aplicaste) es:

- `auth.uid()` → `(select auth.uid())`
- `auth.role()` → `(select auth.role())`
- `current_setting('x')` → `(select current_setting('x'))`

✅ Esto **no cambia semántica**, solo evita reevaluación por fila.

**Caso típico que te queda:** policies nuevas agregadas después de tu migración “global”, o policies que usan `current_setting()` con variantes.

---

## B) Multiple Permissive Policies (consolidación)

El linter se queja porque **cada policy se evalúa**, aunque sean mutuamente excluyentes por `current_role()`.

### Solución estándar (la que hiciste en conversations SELECT):

- Hacer **1 sola policy** por `action` para el rol DB `authenticated`
- `USING ( <OR de todas las condiciones previas> )`

Ejemplo conceptual:

```sql
drop policy if exists "t_select_admin" on public.t;
drop policy if exists "t_select_aprendiz" on public.t;
drop policy if exists "t_select_referente" on public.t;

create policy "t_select_authenticated"
on public.t
for select
to authenticated
using (
  (
    public.current_role() = 'admin_org'::public.app_role
    and ...cond_admin...
  )
  or (
    public.current_role() = 'aprendiz'::public.app_role
    and ...cond_aprendiz...
  )
  or (
    public.current_role() = 'referente'::public.app_role
    and ...cond_referente...
  )
);
```

### Importante

- No mezcles `USING` con `WITH CHECK` (son para acciones distintas).
- Para `INSERT`: se consolida con **WITH CHECK** (OR de checks).
- Para `UPDATE`: normalmente tenés **USING** + **WITH CHECK**.
- Para `DELETE`: solo **USING**.

---

## 3) La manera más rápida de bajar de 115 a ~0

### Paso 1 — Atacar **todas** las “Auth RLS InitPlan” restantes

Usás la query 1.1 y corregís en lote.

### Paso 2 — Atacar “Multiple permissive” por tabla (de a una acción por vez)

Usás la query 1.2 y empezás por las tablas con más policies repetidas:

- `alert_events`
- `learner_review_decisions`
- `learner_review_validations_v2`
- etc. (lo que te salga arriba)

Para cada combinación `(tabla, cmd, role)`:

- levantás `qual/with_check` de cada policy
- armás **una consolidada** con OR
- dropeás las anteriores

---

## 4) Si querés hacerlo CI-friendly (sin depender del dashboard)

Supabase CLI tiene `supabase db lint` para lintear schema (warning/error) y controlar salida (útil para CI). ([Supabase][1])

Eso no es exactamente el “Performance Advisor” del dashboard, pero te sirve como **guardrail** automatizable.

---

## 5) Qué necesito de vos para seguir sin fricción

Pegame el **output** de la query **1.2** (aunque sea las primeras 20 filas) y yo te devuelvo:

- una **migración idempotente** que consolide por tabla/acción/rol
- manteniendo tu modelo `org/local/app_role` + `auth.uid()` (envuelto)

Si preferís ir por “quick wins”, arrancamos por las 5 tablas con más repetidas (máximo impacto).

[1]: https://supabase.com/docs/reference/cli/supabase-db-lint 'CLI Reference | Supabase Docs'

```

Resultado esperado

Definir el plan de consolidación y preparar migración/RLS basada en el output del query 1.2.

Notas (opcional)

Pendiente obtener el output de las queries para construir la migración.
```
