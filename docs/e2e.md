# E2E Smoke Tests (Playwright)

Estos tests validan regresiones críticas de UI (especialmente que la Evaluación Final avance sin refresh manual).

## Requisitos

- Supabase local corriendo (`npx supabase start`)
- DB limpia y seed demo aplicado:
  - `npx supabase db reset`
- App corriendo en `http://localhost:3000`:
  - `LLM_PROVIDER=mock npm run dev` (recomendado para no depender de APIs externas)

## Variables de entorno (obligatorias)

```
E2E_LEARNER_EMAIL
E2E_LEARNER_PASSWORD
E2E_REFERENTE_EMAIL
E2E_REFERENTE_PASSWORD
```

Variables opcionales (para aislar flujos):

```
E2E_COURSE_EMAIL
E2E_COURSE_PASSWORD
E2E_FINAL_EMAIL
E2E_FINAL_PASSWORD
```

Para demo/local:

```
E2E_LEARNER_EMAIL=aprendiz@demo.com
E2E_LEARNER_PASSWORD=prueba123
E2E_REFERENTE_EMAIL=referente@demo.com
E2E_REFERENTE_PASSWORD=prueba123
```

Recomendado para Curso Test E2E:

```
E2E_COURSE_EMAIL=e2e-aprendiz@demo.com
E2E_COURSE_PASSWORD=prueba123
```

Recomendado para smoke de evaluación final (evita el intento seed 999):

```
E2E_FINAL_EMAIL=e2e-final@demo.com
E2E_FINAL_PASSWORD=prueba123
```

## Comando recomendado (flujo aprendiz)

```bash
E2E_LEARNER_EMAIL=aprendiz@demo.com \
E2E_LEARNER_PASSWORD=prueba123 \
E2E_REFERENTE_EMAIL=referente@demo.com \
E2E_REFERENTE_PASSWORD=prueba123 \
E2E_FINAL_EMAIL=e2e-final@demo.com \
E2E_FINAL_PASSWORD=prueba123 \
npm run e2e -- e2e/ui-smoke.spec.ts e2e/learner-progress.spec.ts e2e/learner-profile.spec.ts e2e/final-evaluation.spec.ts
```

## Comando recomendado (Curso Test E2E)

```bash
npx supabase db reset
LLM_PROVIDER=mock npm run dev
E2E_LEARNER_EMAIL=aprendiz@demo.com \
E2E_LEARNER_PASSWORD=prueba123 \
E2E_REFERENTE_EMAIL=referente@demo.com \
E2E_REFERENTE_PASSWORD=prueba123 \
E2E_COURSE_EMAIL=e2e-aprendiz@demo.com \
E2E_COURSE_PASSWORD=prueba123 \
npm run test:e2e:learner:headed
```

Comando recomendado (flujo admin org config):

```bash
E2E_ADMIN_EMAIL=admin@demo.com \
E2E_ADMIN_PASSWORD=prueba123 \
npx playwright test e2e/admin-org-config-flow.spec.ts --headed --trace=on
```

## Ejecutar tests

```
npm run e2e
npm run e2e:headed
```

## Notas

- Los tests no levantan el servidor automáticamente.
- No se usan credenciales con service_role ni endpoints test-only.
- Si ya tenés proveedor LLM configurado, podés omitir `LLM_PROVIDER=mock`.
