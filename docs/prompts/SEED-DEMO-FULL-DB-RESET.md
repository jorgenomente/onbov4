# SEED-DEMO-FULL-DB-RESET

## Contexto

Crear seed demo completo e idempotente para que `npx supabase db reset` deje el entorno listo con usuarios Auth, datos de entrenamiento, knowledge y práctica.

## Prompt ejecutado

```txt
Sos Senior Backend Engineer (Supabase Postgres + Auth). Necesito dejar ONBO en un estado 100% reproducible tras `npx supabase db reset`.

DECISIÓN CERRADA:
- Todos los usuarios demo deben crearse con el MISMO password:
  PASSWORD DEMO: "prueba123"

Contexto:
- db reset borra auth.users y todas las tablas public.
- No queremos crear NADA manualmente en Supabase Studio.
- Ya existen migraciones de schema, RLS, views y algunos seeds parciales.
- El smoke test manual debe poder ejecutarse completo después de reset.

Objetivo:
Implementar un seed DB-first, idempotente y versionado que cree TODO el entorno demo, incluidos usuarios de Supabase Auth.

Tareas:

1) Auditoría inicial (obligatoria):
   - Revisar el repo y detectar si ya existe un patrón para crear usuarios Auth:
     - supabase/seed.sql
     - migraciones previas que insertan en auth.users
     - RPCs o helpers existentes
   - REUTILIZAR ese patrón si existe. No inventar otro.

2) Implementar seed demo completo (idempotente):
   Debe asegurar existencia (WHERE NOT EXISTS) de:

   a) Organización
      - name: "Demo Org"
      - UUID fijo

   b) Local
      - name: "Local Centro"
      - org_id: Demo Org

   c) Programa de entrenamiento
      - name: "Onboarding Camareros"
      - activo
      - asignado al local

   d) Unidades (mínimo 2)
      - Unidad 1: Bienvenida y estándar de servicio
      - Unidad 2: Venta sugestiva básica

   e) Knowledge items + unit_knowledge_map
      - Guión de saludo → Unidad 1
      - Upselling → Unidad 2

   f) Practice scenario demo
      - Compatible con startPracticeScenario
      - program_id + unit_order + difficulty alineados

   g) Configuración de evaluación final
      - Valores razonables para smoke test

   h) Learner training assignment
      - aprendiz asignado al programa activo
      - status inicial: en_entrenamiento

3) Usuarios DEMO de Supabase Auth (CRÍTICO):
   Crear o asegurar existencia de los siguientes usuarios Auth,
   TODOS con password: "prueba123"

   - admin@demo.com        → role: admin_org
   - referente@demo.com    → role: referente
   - aprendiz@demo.com     → role: aprendiz
   - superadmin@onbo.dev   → role: superadmin (acceso global)

   Reglas:
   - Usuarios deben poder loguearse vía /auth/v1/token
   - Crear filas correspondientes en public.profiles con:
     - org_id / local_id correctos
     - role correcto
   - El superadmin puede no tener local_id si el modelo lo permite
   - Todo debe ser idempotente

4) Seguridad / orden:
   - Marcar claramente el seed como DEMO / LOCAL.
   - NO romper RLS.
   - NO agregar lógica condicional por entorno en la app.

5) Entrega:
   - Archivo(s) SQL nuevos en supabase/migrations (timestamp actual) o seed.sql según convención del repo.
   - Documentar passwords demo en:
     docs/smoke-credentials.md
     (incluir emails + password "prueba123")
   - Explicar brevemente cómo se crean los usuarios Auth (mecanismo usado).

Criterio de aceptación:
- `npx supabase db reset`
- Login con aprendiz@demo.com / prueba123 funciona
- Login con superadmin@onbo.dev / prueba123 funciona
- /learner/training carga
- Iniciar práctica no falla
```

Resultado esperado
Seed demo completo e idempotente con usuarios Auth y datos mínimos del producto.

Notas (opcional)
N/A.
