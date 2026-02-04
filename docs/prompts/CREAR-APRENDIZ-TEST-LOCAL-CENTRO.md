# CREAR APRENDIZ TEST LOCAL CENTRO

## Contexto

Crear un usuario aprendiz de prueba en Supabase local y asociarlo al Local Centro para pruebas de flujo.

## Prompt ejecutado

````txt
Perfecto, gracias por el detalle: **confirmo usar *Local Centro***
`local_id = 1af5842d-68c0-4c56-8025-73d416730016`

Abajo te dejo **UN SOLO BLOQUE SQL**, **copiar-pegar-ejecutable**, alineado a lo que describís del schema real (sin asumir columnas que no existen).

---

## ✅ SQL — Crear aprendiz limpio (Auth + Profile)

**Objetivo**

* Usuario nuevo: `aprendiz-test@demo.com`
* Password: `prueba123`
* Rol: `aprendiz`
* Local: **Local Centro**
* Sin historial previo de entrenamiento

> ⚠️ Ejecutar **una sola vez** en Supabase local (Studio o `psql`)

```sql
-- 1. Crear usuario en auth.users
-- (password encriptado vía Supabase: usamos crypt)
insert into auth.users (
  id,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at
)
values (
  gen_random_uuid(),
  'aprendiz-test@demo.com',
  crypt('prueba123', gen_salt('bf')),
  now(),
  now(),
  now()
);

-- 2. Crear identidad email/password
insert into auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  created_at,
  updated_at
)
select
  gen_random_uuid(),
  u.id,
  jsonb_build_object(
    'sub', u.id::text,
    'email', u.email
  ),
  'email',
  now(),
  now()
from auth.users u
where u.email = 'aprendiz-test@demo.com';

-- 3. Crear profile ONBO (rol aprendiz)
insert into public.profiles (
  user_id,
  org_id,
  local_id,
  role,
  created_at
)
select
  u.id,
  l.org_id,
  l.id,
  'aprendiz',
  now()
from auth.users u
join locals l
  on l.id = '1af5842d-68c0-4c56-8025-73d416730016'
where u.email = 'aprendiz-test@demo.com';
````

---

## 🔍 Verificación rápida (opcional)

```sql
select
  p.role,
  o.name as org,
  l.name as local,
  u.email
from profiles p
join auth.users u on u.id = p.user_id
join locals l on l.id = p.local_id
join organizations o on o.id = p.org_id
where u.email = 'aprendiz-test@demo.com';
```

Esperado:

- role → `aprendiz`
- local → **Local Centro**
- org → la org correspondiente
- email → `aprendiz-test@demo.com`

---

## 🧠 Qué va a pasar ahora (importante)

Cuando hagas login con:

```
email: aprendiz-test@demo.com
password: prueba123
```

y entres a:

```
/training
```

El sistema va a:

1. Detectar **usuario nuevo**
2. Crear `learner_training` desde cero
3. Asignar **programa activo del Local Centro**
4. Empezar en **Unidad 1**
5. Construir contexto SOLO con:
   - knowledge mapeado a esa unidad
   - escenarios activos

👉 Este es el **camino canónico** que queríamos probar.

---

### Próximo paso

Logueate como `aprendiz-test@demo.com`, entrá a `/training` y pegáme **el primer mensaje exacto del bot**.
Desde ahí ajustamos UX conversacional fino (tono, ritmo, claridad).

```

Resultado esperado

Usuario auth creado, identidad email registrada y perfil aprendiz asociado a Local Centro.
```
