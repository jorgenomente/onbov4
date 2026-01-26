# E2E-PLAYWRIGHT-SMOKE

## Contexto

Agregar smoke tests E2E con Playwright para validar regresiones críticas, en especial avance sin refresh en Evaluación Final.

## Prompt ejecutado

```txt
queremos hacer test con playwright y te voy a dar un prmpt como referencia. Sos Codex CLI trabajando en el repo `onbov4` (MVP, trabajo directo sobre `main`, sin ramas, sin PRs). Objetivo: agregar E2E browser smoke tests con Playwright para ONBO, con el mínimo scope para validar regresiones críticas (especialmente “avanza sin refresh” en Evaluación Final).

REGLAS (NO NEGOCIABLES)
- Mantener DB-first/RLS-first. No agregar bypass inseguro.
- NO usar service_role en tests.
- NO crear endpoints test-only.
- Mantener scope mínimo: 2–3 tests smoke E2E.
- Si falta algún selector estable, agregar `data-testid` mínimos en la UI (solo donde sea necesario).
- Todo debe ser reproducible: `npx supabase db reset` + `npm run dev` + `npm run e2e` debe pasar.
- No agregar dependencias innecesarias. Solo Playwright.
- Entregable: código + scripts + docs + ejecución local (lint/build opcional, pero e2e debe correr).

PLAN DE EJECUCIÓN

1) Instalar Playwright
- Agregar dev deps:
  - `@playwright/test`
- Instalar browsers:
  - `npx playwright install`

2) Configuración Playwright
- Crear `playwright.config.ts` (mínimo) con:
  - baseURL: `http://localhost:3000`
  - testDir: `e2e`
  - retries: 0 (por ahora)
  - reporter: `list`
  - trace: `retain-on-failure`
  - screenshot: `only-on-failure`
  - video: `retain-on-failure`
  - timeout razonable (por ejemplo 60s)

3) Scripts npm
- En `package.json` agregar:
  - `"e2e": "playwright test"`
  - `"e2e:headed": "playwright test --headed"`
  - `"e2e:ui": "playwright test --ui"`

4) Estabilizar selectores (mínimo con data-testid)
Agregar `data-testid` solo en los puntos críticos del flujo:
- Login page `/login`:
  - input email: `data-testid="login-email"`
  - input password: `data-testid="login-password"`
  - submit button: `data-testid="login-submit"`
- Final evaluation `/learner/final-evaluation`:
  - CTA iniciar evaluación: `data-testid="final-start"`
  - label de progreso pregunta (ej: “Pregunta 1 de 4”): `data-testid="final-progress"`
  - input/textarea respuesta: `data-testid="final-answer"`
  - botón enviar: `data-testid="final-submit"`
  - contenedor prompt/pregunta visible: `data-testid="final-question-prompt"`
  - estado en revisión (pantalla final): `data-testid="final-in-review"` o badge equivalente
- Referente panel `/referente/review` (o ruta actual):
  - tabla/lista queue: `data-testid="review-queue"`
  - item del aprendiz: `data-testid="review-learner-row"`
  (si ya existe algo estable por texto, evitar agregar testids extra)

IMPORTANTE: no cambiar UX; solo añadir atributos.

5) Añadir utilidades E2E
- Crear `e2e/helpers/auth.ts`:
  - función `login(page, { email, password })` que navega a `/login`, llena inputs (testids), submit y espera redirect.
- Tomar credenciales demo desde env vars para no hardcodear:
  - `E2E_LEARNER_EMAIL`, `E2E_LEARNER_PASSWORD`
  - `E2E_REFERENTE_EMAIL`, `E2E_REFERENTE_PASSWORD`
- Crear `e2e/helpers/env.ts` que valide env vars y falle con mensaje claro.

6) Tests E2E (mínimo)
Crear carpeta `e2e/` y agregar estos tests:

A) `e2e/final-evaluation.spec.ts`
- Test: “Learner completes final evaluation and advances without manual refresh”
  Pasos:
  1) login como aprendiz (env vars)
  2) ir a `/learner/final-evaluation`
  3) click iniciar (final-start) si está disponible
     - si aparece gating “Debés esperar 12h…”, el test debe fallar con mensaje (esto indica seed no limpia o estado no reseteado)
  4) Capturar texto inicial de `final-progress` (p.ej. “Pregunta 1 de 4”)
  5) Escribir respuesta en `final-answer` y submit (`final-submit`)
  6) Assert: `final-progress` cambia a “Pregunta 2 de 4” (o que el valor cambie respecto al inicial)
     - NO usar refresh. Simplemente esperar con `expect(...).not.toHaveText(initialText)`
  7) Repetir submit hasta completar (loop hasta que detecte estado final):
     - Mientras exista `final-progress`, responder y enviar
     - Terminar cuando aparezca `final-in-review` o texto “en revisión”
  8) Assert final:
     - `final-in-review` visible (o un texto estable “En revisión”)
     - URL sigue en `/learner/final-evaluation` (o donde sea el end state)

B) `e2e/cooldown-gating.spec.ts` (opcional pero recomendable)
- Test: “After completion, learner sees cooldown gating”
  Pasos:
  1) login aprendiz
  2) ir a `/learner/final-evaluation`
  3) si ya completó un intento, debe mostrarse mensaje de cooldown
  Nota: este test puede depender del estado del seed; si es inestable, omitir por ahora.

C) `e2e/referente-review.spec.ts`
- Test: “Referente can see review queue”
  Pasos:
  1) login referente
  2) ir a `/referente/review`
  3) Assert: `review-queue` visible
  4) Assert: existe al menos un row (si seed lo garantiza). Si no, assert solo que carga sin 403.

7) Documentación
- Crear/actualizar `docs/e2e.md` con:
  - requisitos: supabase local corriendo, `db reset`, `npm run dev`
  - env vars requeridas para e2e
  - comandos para correr: `npm run e2e`, `npm run e2e:headed`
  - nota: e2e no levanta el servidor automáticamente (por ahora)

8) Verificación local (obligatoria)
- Ejecutar:
  - `npx supabase db reset`
  - `npm run dev` (asegurar que esté en http://localhost:3000)
  - `E2E_LEARNER_EMAIL=... E2E_LEARNER_PASSWORD=... E2E_REFERENTE_EMAIL=... E2E_REFERENTE_PASSWORD=... npm run e2e`
- Confirmar que el test principal “advances without manual refresh” pasa.

9) Commit directo en main
- `feat: add playwright e2e smoke tests`

NOTAS IMPORTANTES
- Si el seed no deja al learner listo para iniciar evaluación final (o ya cae en cooldown), ajustar el seed mínimo (solo seeds) para que en DB reset el learner esté en estado “listo para iniciar” (gating satisfecho y sin cooldown).
- Si hoy el end state de la evaluación final no muestra “en revisión” en UI, agregar un elemento mínimo (badge/text) con `data-testid="final-in-review"` cuando learner esté en `en_revision`. No agregar pantallas nuevas.

ENTREGA
- Implementar todo lo anterior, correr e2e y dejar evidencia de que pasa.
```

Resultado esperado
Playwright configurado, smoke tests mínimos E2E funcionando, documentación y ejecución local verificada.

Notas (opcional)
N/A
