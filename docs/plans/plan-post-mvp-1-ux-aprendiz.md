```md
# Plan de Ejecución — Post-MVP 1: UX Aprendiz Completa

⚠️ Este documento **NO reemplaza** el roadmap del producto.

Complementa:

- `docs/roadmap-product-final.md`
- `Documento Maestro del Producto`

Propósito:
Ejecutar de forma ordenada, segura y verificable el **Lote Post-MVP 1**
sin modificar la arquitectura base ni el alcance del producto.

Este plan es:

- táctico
- temporal
- específico de este lote

Una vez cerrado el lote, el documento queda como referencia histórica.

# PLAN DE EJECUCIÓN ORDENADO (Post-MVP 1) — UX Aprendiz Completa

Repositorio: onbo-conversational (trabajo directo sobre main)
Objetivo: avanzar sin romper nada, con entregables verificables, DB-first/RLS-first y contratos por pantalla.

Este plan está diseñado para ejecutarse con Codex CLI. Cada paso incluye un prompt listo para copiar/pegar.

---

## 0) Reglas operativas (NO NEGOCIABLES)

- No tocar data model salvo que sea imprescindible.
- Cualquier pantalla nueva debe consumir:
  - una VIEW (read-only) o
  - una RPC (si hay lógica crítica).
- Nada de lógica sensible en frontend.
- Multi-tenancy siempre derivado de auth.uid() y helpers current\_\*.
- Nada se borra. Nada se recalcula.
- Al cierre de cada lote:
  1. npx supabase db reset
  2. npm run lint
  3. npm run build
  4. commit directo a main (convención feat:/fix:/docs:/refactor:/chore:)

---

## 1) Checkpoint actual y estrategia

Checkpoint actual según roadmap: CP-0 → “UX Aprendiz completa” es el siguiente lote inmediato.
Vamos a ejecutar el LOTE Post-MVP 1 en 4 sub-lotes pequeños, cada uno cerrable y reversible.

Sub-lotes:
A) Shell + Tabs (Entrenamiento / Progreso / Perfil)
B) /learner/progress (read-only) + repaso mínimo (sin impacto)
C) /learner/profile (read-only) + historial decisiones
D) Logging de “consultas a unidades futuras” (DB + wiring mínimo)

---

## 2) Sub-lote A — Shell + Tabs (routing estable)

### Objetivo

Dejar navegación Aprendiz consistente con el Documento Maestro:
Tabs visibles: Entrenamiento, Progreso, Perfil.

### Entregables

- Layout de learner con navegación mobile-first.
- Rutas:
  - /learner/training (ya existe)
  - /learner/progress (placeholder inicial)
  - /learner/profile (placeholder inicial)
- Guard rails:
  - Mantener protección por sesión + rol
  - No duplicar lógica de redirect

### Prompt para Codex CLI (A)

“Implementa el shell de navegación del Aprendiz:

- Revisa docs (Documento Maestro + roadmap) para confirmar tabs requeridas.
- Crea/ajusta layout en /app/learner/\* para que siempre muestre tabs:
  - Entrenamiento → /learner/training
  - Progreso → /learner/progress
  - Perfil → /learner/profile
- Mobile-first con Tailwind. No uses shadcn/ui salvo que aporte.
- Deja /learner/progress y /learner/profile como páginas placeholder (por ahora), sin lógica.
- No rompas /learner/training.
- Ejecuta: npm run lint + npm run build (solo reporta resultados).
- Commit: feat: learner tabs shell”

---

## 3) Sub-lote B — /learner/progress + repaso mínimo

### Objetivo

Cumplir “Progreso” del Maestro y roadmap:

- progreso por unidad
- estado actual
- acceso a repaso de unidades completadas
  Repaso:
- lectura/mini práctica opcional
- NO cambia progreso ni estado

### Diseño (mínimo, sin DB nueva si se puede)

Data sources existentes:

- v_learner_progress (lista de unidades + current_unit_order + progress_percent + status)
- v_learner_training_home (resumen de la unidad actual)

Implementación UI:

- Página /learner/progress:
  - header: program_name, status, progress_percent
  - lista unidades (unit_order, title, estado visual):
    - completada → botón “Repasar”
    - actual → etiqueta “Actual”
    - futura → bloqueada
- Repaso mínimo:
  - Ruta /learner/review/[unitOrder]
  - Renderiza knowledge permitido de esa unidad (solo lectura).
  - (Opcional mini práctica) solo si existe un escenario de practice_scenarios para esa unidad:
    - inicia práctica en “modo review” en UI pero NO debe afectar learner_trainings ni cambiar current_unit_order.
    - Si hoy el motor de práctica siempre crea attempts normales, entonces en MVP:
      - solo mostrar lectura y omitir mini práctica (para no tocar DB/lógica).

### Punto de control

Antes de agregar mini práctica, validar si:

- practice_attempts / evaluations impactan métricas críticas o aparecen en evidencia.
  Si impactan, se omite mini práctica en repaso por ahora.

### Prompt para Codex CLI (B)

“Implementa /learner/progress read-only y modo repaso mínimo:

1. Usa SOLO views existentes como contrato (no select \*):
   - v_learner_progress
   - v_learner_training_home
2. Crea página /learner/progress:
   - muestra estado, % progreso y lista de unidades con su title.
   - para unidades completadas, agrega CTA ‘Repasar’ que navegue a /learner/review/[unitOrder].
   - futuras bloqueadas (sin CTA).
3. Crea /learner/review/[unitOrder]:
   - valida que unitOrder sea <= current_unit_order (del learner) para permitir repaso.
   - renderiza contenido (knowledge) asociado a esa unidad en modo lectura.
   - NO debe modificar learner_trainings ni crear attempts por ahora.
4. Si necesitas una vista para ‘knowledge por unit_order’ para evitar queries complejas, crea una VIEW DB-first con RLS-safe.
5. Agrega tests mínimos (si ya hay Playwright smoke, agrega 1 test simple de navegación a Progreso y abrir repaso).
6. Ejecuta: npx supabase db reset, npm run lint, npm run build.
7. Commit: feat: learner progress + review read-only”

---

## 4) Sub-lote C — /learner/profile (read-only)

### Objetivo

Cumplir Perfil:

- datos básicos (nombre, local, org)
- estado actual
- historial de decisiones humanas (ya implementado en varias pantallas)

### Contrato de datos

- profiles (propio) + locals + organizations (si ya hay views, preferir views)
- learner_trainings (propio) o v_learner_training_home
- learner_review_decisions (propio) — ya con snapshot reviewer_name

### UI

- /learner/profile:
  - card: nombre, rol, local
  - card: estado actual + progreso
  - sección: “Historial de decisiones” (lista, compacta)

### Prompt para Codex CLI (C)

“Implementa /learner/profile read-only:

- Página /learner/profile:
  - muestra datos del usuario (full_name, role) y contexto (local, org si aplica).
  - muestra estado + progreso desde view existente (v_learner_training_home o v_learner_progress).
  - renderiza historial completo de learner_review_decisions visible para el learner (orden desc).
- Reutiliza componentes existentes si hay.
- No agregues lógica de escritura.
- Ejecuta: npm run lint + npm run build.
- Commit: feat: learner profile page”

---

## 5) Sub-lote D — Logging “consultas sobre unidades futuras”

### Objetivo

Cumplir Maestro + roadmap:
Cuando el aprendiz pregunta algo que corresponde a una unidad futura:

- responder general + aclaración (ya en lógica conversacional)
- registrar el evento para análisis

### DB (probablemente necesario)

Tabla nueva mínima (append-only):

- learner_future_questions
  - id uuid pk default gen_random_uuid()
  - learner_id uuid not null
  - local_id uuid not null
  - program_id uuid not null
  - asked_unit_order integer not null (la unidad futura a la que apunta)
  - conversation_id uuid nullable
  - message_id uuid nullable (si corresponde)
  - question_text text not null
  - created_at timestamptz not null default now()

RLS:

- INSERT: learner solo para su propio learner_id y dentro de su local/program activos
- SELECT:
  - learner: solo sus filas
  - referente: filas de su local
  - admin_org: por org (join via locals)
  - superadmin: todo

Wiring:

- En el server action del chat, cuando se detecta “unidad futura” (según tu heurística/engine),
  insertar un row en esta tabla.
- Si todavía no existe esa detección formal, implementar una versión mínima:
  - si el LLM/engine ya retorna metadata (future_unit_order), úsala.
  - si no, NO inventar heurística compleja: crear un TODO y dejar solo tabla + RPC lista.

### Prompt para Codex CLI (D)

“Agrega logging append-only de consultas a unidades futuras:

1. Crea migración SQL para tabla learner_future_questions con campos:
   learner_id, local_id, program_id, asked_unit_order, conversation_id, message_id, question_text, created_at.
2. Habilita RLS + policies Zero Trust:
   - learner inserta/lee solo propio
   - referente lee por local
   - admin_org lee por org
   - superadmin lee todo
3. Integra el insert en el flujo server-only del chat (donde se procesa el mensaje del learner):
   - solo si existe una señal explícita de ‘unidad futura’ en el motor actual.
   - si no existe señal hoy, deja TODO y NO implementes heurística improvisada.
4. Regenera docs DB:
   - npm run db:dictionary
   - npm run db:dump:schema
5. Ejecuta: npx supabase db reset, npm run lint, npm run build.
6. Commit: feat: log future unit questions”

---

## 6) Cierre del Lote Post-MVP 1 (definición de “terminado”)

Se considera terminado cuando:

- Tabs Aprendiz visibles y estables.
- /learner/progress funcional (read-only) y permite repaso lectura.
- /learner/profile funcional (read-only) y muestra historial decisiones.
- Logging de consultas futuras listo (tabla + RLS + wiring o TODO explícito si falta señal).
- Smoke manual completo sin refresh raro:
  - login → /learner/training
  - navegar Progreso → abrir repaso
  - navegar Perfil → ver decisiones
- Build/lint/reset OK.
- docs actualizados:
  - docs/roadmap-product-final.md: marcar Fase 1 en progreso o cerrada
  - docs/audit-checkpoint1.md actualizado
  - docs/activity-log.md nueva entrada

---

## 7) Orden recomendado de ejecución (exacto)

1. Sub-lote A (tabs shell)
2. Sub-lote B (progress + review read-only)
3. Sub-lote C (profile)
4. Sub-lote D (future questions logging)
5. Cierre + docs

---

## 8) Primer prompt para empezar HOY (copia y pega a Codex)

“Vamos a ejecutar el Lote Post-MVP 1 (UX Aprendiz completa) en sub-lotes.
Arranca por Sub-lote A:

- Implementa un layout de /learner con tabs mobile-first:
  Entrenamiento (/learner/training), Progreso (/learner/progress), Perfil (/learner/profile).
- Crea pages placeholder para /learner/progress y /learner/profile (solo texto por ahora).
- No rompas /learner/training ni la protección de sesión/rol.
- Corre npm run lint y npm run build.
- Commit directo a main: feat: learner tabs shell”

---
```

Fuentes de referencia del plan (mismas que leerá Codex en el repo): Documento Maestro y Roadmap Post-MVP .
