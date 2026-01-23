Actuá como Lead Software Architect + Senior Backend Engineer siguiendo AGENTS.md y docs/plan-mvp.md.

OBJETIVO (LOTE 2):
Implementar el modelo de entrenamiento: programas, unidades, asignación por aprendiz, estado explícito del aprendiz y vistas base (aprendiz + referente/admin).

SOURCES OF TRUTH:

- docs/product-master.md (Documento Maestro)
- docs/plan-mvp.md
- AGENTS.md

REGLAS:

- DB-first + RLS-first.
- SQL nativo únicamente.
- Nada de select \*.
- Todas las tablas con RLS habilitada y policies explícitas.
- Multi-tenancy derivado desde auth.uid() y helpers current\_\*.
- Mantener historial inmutable donde aplique; en Lote 2 como mínimo: transiciones de estado append-only.
- Entregable principal: 1 migración SQL versionada en supabase/migrations.
- Actualizar docs/activity-log.md con una entrada.
- Al final: npx supabase db reset, npm run lint, npm run build (arreglar lo que falle).

TAREAS:

A) MIGRACIÓN DB (1 archivo nuevo):
Crear entidades (todas en schema public):

1. Enum learner_status:
   - en_entrenamiento
   - en_practica
   - en_riesgo
   - en_revision
   - aprobado
     Hacerlo idempotente (DO $$ ... duplicate_object ...).

2. training_programs
   - id uuid pk default gen_random_uuid()
   - org_id uuid not null references organizations(id) on delete restrict
   - local_id uuid null references locals(id) on delete restrict
     (NULL = programa a nivel organización; NOT NULL = override por local)
   - name text not null
   - is_active boolean not null default true
   - created_at timestamptz not null default now()
     Indexes: (org_id), (local_id), (org_id, local_id)

3. training_units
   - id uuid pk default gen_random_uuid()
   - program_id uuid not null references training_programs(id) on delete cascade
   - unit_order int not null (1..N)
   - title text not null
   - objectives text[] not null default '{}'
   - created_at timestamptz not null default now()
     Constraints:
   - unique(program_id, unit_order)
     Index: (program_id)

4. local_active_programs
   - local_id uuid primary key references locals(id) on delete cascade
   - program_id uuid not null references training_programs(id) on delete restrict
   - created_at timestamptz not null default now()
     (Esto modela “un programa activo por local”.)

5. learner_trainings
   - id uuid pk default gen_random_uuid()
   - learner_id uuid not null references profiles(user_id) on delete cascade
   - local_id uuid not null references locals(id) on delete restrict
   - program_id uuid not null references training_programs(id) on delete restrict
   - status learner_status not null default 'en_entrenamiento'
   - current_unit_order int not null default 1
   - progress_percent numeric(5,2) not null default 0
   - started_at timestamptz not null default now()
   - updated_at timestamptz not null default now()
     Constraints:
   - unique(learner_id) (un programa activo por aprendiz)
   - check(progress_percent >= 0 and progress_percent <= 100)
     Indexes: (local_id), (program_id), (status)

6. learner_state_transitions (append-only)
   - id uuid pk default gen_random_uuid()
   - learner_id uuid not null references profiles(user_id) on delete cascade
   - from_status learner_status null
   - to_status learner_status not null
   - reason text null
   - actor_user_id uuid null references profiles(user_id) on delete set null
   - created_at timestamptz not null default now()
     Indexes: (learner_id), (to_status), (created_at)

7. Trigger updated_at para learner_trainings.

B) RLS + POLICIES (STRICT) en todas las tablas nuevas:
Habilitar RLS en:

- training_programs
- training_units
- local_active_programs
- learner_trainings
- learner_state_transitions

Policies mínimas (lectura) que soporten MVP:

1. training_programs SELECT:

- superadmin: todo
- admin_org: programas donde org_id = current_org_id()
- referente/aprendiz: programas donde org_id = current_org_id()
  (y opcionalmente filtrar por local_id is null or local_id = current_local_id())

2. training_units SELECT:

- permitido si el program_id es visible según training_programs (usar EXISTS)

3. local_active_programs SELECT:

- superadmin: todo
- admin_org: locals de su org (join locals.org_id = current_org_id())
- referente/aprendiz: solo su local (local_id = current_local_id())

4. learner_trainings SELECT:

- aprendiz: solo su registro (learner_id = auth.uid())
- referente: registros de su local (local_id = current_local_id())
- admin_org: registros de locales en su org (join locals)
- superadmin: todo

5. learner_state_transitions SELECT:

- aprendiz: solo las suyas
- referente/admin_org/superadmin: según mismo alcance que learner_trainings (EXISTS)

Writes:

- Por ahora, permitir UPDATE solo al sistema controlado:
  - aprendiz: NO puede cambiar status
  - permitir UPDATE limitado del registro learner_trainings solo a server flows (si preferís, dejar sin policies UPDATE y anotar que se implementará con RPC/Server Action en lotes posteriores).
  - Para MVP estable: dejar writes mínimos o ninguno (preferible), pero mantener schema listo.

C) VIEWS (contratos para UI, lectura only):
Crear views:

1. v_learner_training_home
   Devuelve para auth.uid():

- learner_id
- status
- program_id
- program_name
- current_unit_order
- total_units (count)
- current_unit_title
- objectives (current unit)
- progress_percent

2. v_learner_progress
   Devuelve para auth.uid():

- learner_id
- status
- progress_percent
- current_unit_order
- units: lista por unidad (unit_order, title, is_completed boolean)
  Si Postgres JSON ayuda, usar json_agg; sino, una view plana + se arma en app. Elegí lo más simple y confiable.

3. v_referente_learners
   Para referente/admin_org:

- learner_id
- full_name
- status
- progress_percent
- current_unit_order
- updated_at

D) ACTIVIDAD (docs/activity-log.md):
Agregar entrada con:

- migración Lote 2
- entidades creadas
- nota de RLS alcance
- checklist manual mínimo

E) VERIFICACIÓN:

1. npx supabase db reset OK
2. (Manual checklist en docs):

- aprendiz: puede leer v_learner_training_home y v_learner_progress (solo own)
- referente: puede leer v_referente_learners para su local
- admin_org: puede leer aprendiz por org
- superadmin: puede leer todo

AL FINAL:

- npm run lint
- npm run build
- reportar archivos tocados + comandos y resultados
- proponer nombre de rama + commit (NO hacer merge aún)
