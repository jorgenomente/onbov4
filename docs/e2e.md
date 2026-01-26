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

Para demo/local:

```
E2E_LEARNER_EMAIL=aprendiz@demo.com
E2E_LEARNER_PASSWORD=prueba123
E2E_REFERENTE_EMAIL=referente@demo.com
E2E_REFERENTE_PASSWORD=prueba123
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
