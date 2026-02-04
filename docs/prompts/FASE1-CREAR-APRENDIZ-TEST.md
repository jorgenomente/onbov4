# FASE1 CREAR APRENDIZ TEST

## Contexto

Crear un usuario aprendiz de prueba en Supabase local usando CLI y asociarlo a un perfil del sistema ONBO.

## Prompt ejecutado

```txt
✅ OPCIÓN RECOMENDADA — Supabase CLI (Auth + DB coherente)

Esta es la más limpia porque:

crea el usuario en auth

evita inconsistencias

es reversible

respeta el modelo real de Supabase

1️⃣ Crear el usuario Auth (CLI)

Ejecutá en la raíz del repo:

npx supabase auth admin create user \
  --email aprendiz-test@demo.com \
  --password prueba123 \
  --email-confirm


✔️ Esto crea el usuario en auth.users
✔️ Ya puede loguearse

2️⃣ Crear el profile + rol learner (SQL)

Ahora asociamos ese usuario al sistema ONBO.

Abrí el SQL editor (Studio o psql) y ejecutá:

insert into public.profiles (
  id,
  email,
  role,
  local_id
)
select
  u.id,
  u.email,
  'learner',
  l.id
from auth.users u
join locals l on l.slug = 'local-demo'
where u.email = 'aprendiz-test@demo.com';


📌 Ajustá local-demo al slug real del local que estás probando.

3️⃣ Verificación rápida (opcional pero recomendada)
select
  p.email,
  p.role,
  l.name as local
from profiles p
join locals l on l.id = p.local_id
where p.email = 'aprendiz-test@demo.com';


Esperado:

aprendiz-test@demo.com | learner | <nombre del local>
```

Resultado esperado

Usuario Auth creado y perfil asociado al local correcto con rol aprendiz.
