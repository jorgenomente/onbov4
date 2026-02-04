# E2E LEARNER CURSO TEST FLOW

## Contexto

Agregar data-testid y un spec de Playwright para el flujo del aprendiz con Curso Test (E2E), usando LLM_PROVIDER=mock y ejecucion deterministica.

## Prompt ejecutado

```txt
# CODEX CLI — ONBO: E2E Learner “Curso Test (E2E)” (Playwright) + data-testid + runner determinístico

Objetivo:
Agregar cobertura automática E2E del flujo del Aprendiz para el “Curso Test (E2E)” usando Playwright, de forma **determinística** (LLM_PROVIDER=mock) y confiable en local.

Debe detectar regresiones de:
- Home del aprendiz claro + CTA único
- Training auto-intro (no chat vacío)
- Gating “comenzar” antes de práctica
- Práctica disponible + recordatorio visible
- Completar práctica avanza progreso/unidad (persistido)
- No hay errores críticos (“Active conversation context not found”, “final-evaluation gating blocked” en Home/Training)

Restricciones:
- No assert sobre texto exacto generado por IA.
- Usar `data-testid` para selectores estables.
- No romper UX, solo agregar atributos y tests.
- DB-first: usar `npx supabase db reset` como parte del flujo de test (documentado).
- Preferir `LLM_PROVIDER=mock` durante E2E.
- Mantener rutas existentes (/learner, /learner/training).
- No usar service_role en cliente; E2E solo navega UI.

---

## Parte 0 — Auditoría repo (obligatoria)
1) Ubicar:
- playwright.config.* (si existe) o configuración actual de e2e
- carpeta e2e/ (ya existe al menos admin-org spec)
- scripts en package.json relacionados a playwright/e2e
- dónde está el LoginForm y cómo loguea (supabase auth)
- credenciales demo en docs/smoke-credentials.md (si aplica)

2) Identificar en UI Learner los elementos a seleccionar:
- CTA principal “Continuar” en /learner
- contenedor de mensajes del chat en /learner/training
- input de chat + botón enviar
- bloque “Recordatorio” (si fase práctica)
- tarjeta de práctica (scenario) cuando se habilita
- visual de progreso en /learner (progress percent o unidad)

3) Confirmar el “Curso Test (E2E)” existe vía seed/migración ya agregada.
- Detectar cómo se asigna al Local Centro (si la migración ya lo fija o si se hace por UI).
- Si por UI: el test deberá loguear admin_org y asignar. Si ya está fijo en seed: el test puede ir directo con learner.

---

## Parte 1 — Agregar `data-testid` (mínimo indispensable)
Agregar `data-testid` en las pantallas del Learner:

### /learner (Home)
- CTA principal: `data-testid="learner-cta-continue"`
- Bloque de unidad actual: `data-testid="learner-current-unit"`
- Progreso visible: `data-testid="learner-progress"` (texto o número)
- Estado visible: `data-testid="learner-status"`

### /learner/training
- Contenedor lista mensajes: `data-testid="chat-thread"`
- Cada mensaje: `data-testid="chat-message"` + `data-role="bot|learner"` si ya se puede, sino data-attr equivalente
- Input: `data-testid="chat-input"`
- Botón enviar: `data-testid="chat-send"`
- Bloque fase: `data-testid="training-phase"` (Aprender/Práctica read-only)
- Bloque recordatorio: `data-testid="training-reminder"` (solo cuando aplique)
- Tarjeta práctica/escenario: `data-testid="practice-card"`
- Indicador “comenzar” gating (si hay copy o estado): NO depender del texto; preferir un flag UI:
  - `data-testid="needs-start"` cuando todavía no se envió “comenzar”
  - o `data-testid="learning-active"` / `data-testid="practice-active"`

No inventar UI nueva; solo agregar attributes donde ya hay elementos existentes.

---

## Parte 2 — E2E spec (determinístico)
Crear `e2e/learner-course-test-flow.spec.ts` con 1 test principal:

### Test: “Learner completes Curso Test unit 1 flow”
Pasos:

0) (opcional) Reset DB indicado en docs, pero el test en sí asume DB ya reseteada.
   Documentar en README/notes de test que se corre después de `npx supabase db reset`.

1) Login como aprendiz del seed (o crear uno antes):
- Ideal: usar credenciales existentes de `docs/smoke-credentials.md` para aprendiz del Local Centro.
- Si no existe learner limpio, entonces:
  - loguear como admin_org y crear invite/usuario si hay UI,
  - o fallback: reutilizar un learner existente pero forzar reinicio del training si existe action (solo si ya existe, no inventar).

2) Navegar a `/learner`
Asserts:
- `learner-cta-continue` visible
- `learner-current-unit` visible
- NO existe switch control “Aprender/Practicar” en home (si hay, detectar ausencia por testid o selector)

3) Click CTA → `/learner/training`
Asserts:
- `chat-thread` visible
- al menos 2 `chat-message` visibles (intro + “comenzar” prompt)
- NO hay error overlay ni texto “Active conversation context not found” (assert negativo por contenido de página/console)

4) Enviar “hola”
Asserts:
- sigue en fase aprender o necesita comenzar:
  - `training-phase` muestra “Aprender” o
  - `needs-start` está presente
- `practice-card` NO visible aún

5) Enviar “comenzar”
Asserts:
- `needs-start` desaparece (si existe)
- aparecen más `chat-message` (aprendizaje)
- eventualmente aparece `practice-card` visible (con timeout razonable)
- `training-reminder` visible cuando `practice-card` aparece (si así se diseñó)

6) Completar práctica:
- Enviar una respuesta “buena” (texto fijo) que típicamente cumple criteria.
- Esperar feedback del bot (nuevo mensaje)
- Esperar que el sistema avance:
  - o cambia unidad
  - o cambia progreso

7) Volver a `/learner`
Asserts:
- `learner-progress` ya no es 0% (o cambió unidad)
- `learner-current-unit` refleja avance (si aplica)

Console checks:
- Capturar console errors y fallar si aparece:
  - “Active conversation context not found”
  - “final-evaluation gating blocked”
  - “500” / “400” de auth
  - Unhandled exception

Nota: NO usar asserts de texto exacto del bot; solo contar mensajes y presencia de bloques.

---

## Parte 3 — Runner: scripts y docs
1) En package.json agregar scripts:
- "test:e2e:learner": "playwright test e2e/learner-course-test-flow.spec.ts"
- "test:e2e:learner:headed": "playwright test e2e/learner-course-test-flow.spec.ts --headed --trace=on"

2) Documentar en un doc existente (preferir docs/smoke o docs/testing si existe):
- Comando recomendado:
  - `npx supabase db reset`
  - `LLM_PROVIDER=mock npm run dev`
  - `npx playwright test e2e/learner-course-test-flow.spec.ts --headed --trace=on`
- Nota sobre why mock.

---

## Parte 4 — QA obligatorio
- npx supabase db reset
- npm run dev (LLM_PROVIDER=mock)
- npm run test:e2e:learner:headed
- npm run lint
- npm run build

---

## Entregables
- data-testid añadidos en /learner y /learner/training
- nuevo spec `e2e/learner-course-test-flow.spec.ts`
- scripts package.json
- doc breve de ejecución

Fin.
```

Resultado esperado

Spec Playwright deterministico para flujo learner del Curso Test (E2E), data-testid estables y doc de ejecucion.

Notas (opcional)

Sin notas.
