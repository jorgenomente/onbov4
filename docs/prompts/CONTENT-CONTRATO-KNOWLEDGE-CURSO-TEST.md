# CONTRATO KNOWLEDGE + CURSO TEST + FLUJO PEDAGOGICO

## Contexto

Definir contrato de contenido, crear Curso Test con knowledge/practica y ajustar flujo pedagógico del aprendiz (intro → aprender → practicar → completar).

## Prompt ejecutado

```txt
# CODEX CLI — ONBO: “Curso Test” + Contrato de Knowledge + Flujo pedagógico (Intro → Aprender → Practicar → Completar)

Objetivo general (MVP):
1) Definir y documentar un **contrato de contenido** (Knowledge) para que el Admin sepa qué escribir y el bot pueda enseñar.
2) Crear un **Curso Test** (programa + 1 unidad mínimo) para probar el flujo end-to-end.
3) Ajustar el **flujo del Aprendiz** para que:
   - el bot inicie la unidad con una **introducción automática** (el aprendiz no arranca en blanco)
   - exista una fase explícita “Aprender” antes de “Practicar”
   - NUNCA se evalúe algo que no se enseñó antes
   - el modo (aprender/practicar) lo decide el sistema (no el usuario)
4) Que todo sea DB-first, auditable, RLS-first, sin romper rutas ni seeds.

Restricciones:
- Next.js App Router + RSC.
- Supabase Postgres + RLS strict (Zero Trust).
- SQL nativo (no ORM).
- No inventar lógica sensible en frontend.
- Preferir View/RPC para contratos de datos.
- No agregar features fuera de alcance.

---

## Parte 0 — Auditoría previa (obligatoria)
Antes de implementar, inspeccionar repo para identificar verdad actual:

A) UI Aprendiz:
- Rutas: /learner, /learner/training, /learner/progress, /learner/profile
- Componentes/acciones:
  - app/learner/training/actions.ts (sendLearnerMessage)
  - cualquier action de “continuar/avanzar unidad”
  - cómo se define el “modo” hoy (aprendiz/práctica)
  - qué determina “práctica disponible” (practice_scenarios / views)

B) Data model:
- Tablas/vistas relevantes (buscar en migrations/schema):
  - training_programs, training_units
  - local_active_programs (o equivalente)
  - learner_trainings (estado, progress, current_unit_order)
  - conversations, conversation_messages (si existen)
  - knowledge_items, unit_knowledge_map (o equivalente)
  - practice_scenarios
  - any v_* views usadas en learner y en org config
- Confirmar nombres exactos de columnas (no asumir).
- Confirmar enums/valores de role: 'aprendiz' etc.

C) Admin Org UI actual:
- /org/config/knowledge-coverage (alta knowledge + mapping unidad)
- /org/bot-config (alta escenario + criterios)
Revisar campos exactos: title/content/scope/local_id/reason; scenario fields.

D) Docs existentes:
- product-master.md
- docs/audit/* (incluye admin-audit)
- docs/roadmap* / docs/*screens* / docs/*navigation*
Identificar dónde documentar el “contrato knowledge” sin crear docs redundantes.

---

## Parte 1 — Definir “Contrato Knowledge” (documentación y UX)
### 1.1 Documento
Crear/actualizar un documento único (si ya existe uno similar, actualizar ese en lugar de crear nuevo):
- docs/content/knowledge-contract.md (solo si no existe algo equivalente)
Contenido mínimo:
- qué es knowledge en ONBO (materia prima operativa, no LMS)
- formato recomendado
- tipos de knowledge por unidad:
  A) Introducción (obligatorio, 1 por unidad)
  B) Estándar/Reglas (1-3)
  C) Ejemplos (opcional)
- límites de extensión (ej: 5-15 líneas por item)
- reglas duras:
  - todo criterio evaluado debe estar enseñado en knowledge o en “recordatorio previo”
  - evitar textos largos tipo manual

### 1.2 UX helpers (sin overengineering)
En /org/config/knowledge-coverage:
- agregar placeholders/ayuda inline:
  - “Introducción (obligatorio)”
  - “Estándar / reglas”
  - “Ejemplo”
Sin cambiar DB: solo copy/placeholder y micro-hints.

---

## Parte 2 — “Curso Test” end-to-end (seed DB-first)
Objetivo: tener un programa mínimo para probar flujo completo.

### 2.1 Definición
Crear un programa “Curso Test (E2E)” con:
- 1 programa
- 1 unidad (Unidad 1)
- knowledge items (3 items):
  1) Intro
  2) Estándar
  3) Ejemplo
- 1 practice scenario con:
  - instructions claras
  - success criteria 5-6 ítems concretos
- Marcarlo como activo solo para el Local Centro (no contaminar otros locales).

### 2.2 Implementación DB
Implementar como migración SQL versionada (supabase/migrations/XXXXXXXXXXXXXX_course_test.sql):
- Insert training_programs + training_units (si no existen mecanismos ya).
- Insert knowledge_items + unit_knowledge_map para la unidad 1.
- Insert practice_scenarios para unit_order=1.
- Asignar local_active_program para Local Centro al programa test (si hay tabla/evento formal, usarla; no inventar).
- Todo con ids deterministas o lookup por slug/name.
- No borrar datos previos: seed append-only donde aplique.

Notas:
- Si ya existe un programa demo, NO reemplazarlo: crear uno adicional “Curso Test (E2E)”.
- Si hay constraints de unicidad, usar ON CONFLICT DO NOTHING con criterios correctos.

---

## Parte 3 — Flujo Aprendiz: Intro automática + gating pedagógico
### 3.1 Regla: el bot inicia la unidad (no chat vacío)
Al entrar a /learner/training:
- si NO existen mensajes para la conversación de la unidad actual:
  - crear mensaje inicial del bot (introducción)
  - crear mensaje del bot “Cuando estés listo, escribí ‘comenzar’”
Esto debe ser server-side (action/RSC) para no depender del cliente.

### 3.2 Regla: no practicar sin aprender mínimo
Antes de entrar a práctica:
- se requiere al menos 1 paso de aprendizaje completado, definido por evento explícito:
  - simplest: primer mensaje del learner que sea “comenzar” o “listo”
  - y/o una marca en DB (ej: learner_trainings.current_phase = 'learn'/'practice')
Preferir mínimo cambio:
- no crear tabla nueva si ya existe campo/estado utilizable.
- Si hay que agregar un campo nuevo, hacerlo explícito y auditable (migration + defaults).

### 3.3 UX en /learner/training
- Quitar switch “Modo” como control. Si se muestra, que sea indicador read-only.
- Mostrar “Fase actual: Aprender” o “Fase actual: Práctica”.
- Si fase es práctica, mostrar arriba un bloque “Recordatorio” derivado de knowledge (estándar + ejemplo).
- El input debe estar habilitado solo si existe contexto y la fase lo permite.

### 3.4 Envío de mensajes robusto
En sendLearnerMessage:
- si no existe learner_training o conversación activa:
  - inicializar automáticamente (training + conversation) según programa activo del local
  - y luego continuar
- NO tirar error “Active conversation context not found” al usuario final.

---

## Parte 4 — “Completar unidad” (mínimo viable)
Definir cómo se completa la unidad en el Curso Test:
- Cuando el aprendiz cumple los success criteria del escenario (aprobación de práctica):
  - avanzar estado / progreso:
    - current_unit_order +1
    - progress_percent recalculado o actualizado (según diseño actual)
  - persistir evento auditable si existe tabla de eventos
No recalcular histórico; no borrar nada.

Si ya existe lógica de avance, reutilizarla.
Si no existe, implementar la mínima en RPC server-side y llamar desde action.

---

## Parte 5 — QA obligatorio
1) npx supabase db reset
2) Login Admin Org:
- Ir a /org/config/locals-program y asignar “Curso Test (E2E)” al Local Centro (si la migración no lo fija)
- Verificar knowledge coverage OK
- Verificar scenario activo

3) Login Aprendiz NUEVO:
- /learner: CTA “Continuar”
- /learner/training:
  - Debe aparecer introducción automática del bot
  - Debe pedir “escribí comenzar”
  - Luego debe enseñar (estándar + ejemplo)
  - Luego práctica
  - Luego feedback
  - Luego completar unidad (si aplica)

4) npm run lint
5) npm run build
6) (Si hay Playwright) agregar/actualizar e2e mínimo:
- e2e/learner-course-test-flow.spec.ts

---

## Entregables
- Migración SQL: “Curso Test (E2E)” + knowledge + scenario + asignación local (si aplica).
- Doc “knowledge contract” (nuevo o update de doc existente).
- Cambios learner/training: intro automática, gating pedagógico, no chat vacío, no crash.
- Ajustes menores en /org/config/knowledge-coverage: placeholders/hints (sin rediseñar).
- Tests y QA pasados.

No hacer:
- No agregar editor rico de contenido.
- No crear LMS.
- No dashboards nuevos.
- No tocar evaluación final en este lote.

Fin.
```

Resultado esperado

Contrato de knowledge documentado, Curso Test seed DB-first y flujo pedagógico del aprendiz ajustado (intro → aprender → practicar → completar) sin romper rutas.

Notas (opcional)

Sin notas.
