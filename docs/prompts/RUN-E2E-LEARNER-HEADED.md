# RUN E2E LEARNER HEADED

## Contexto

Ejecución del spec E2E de learner en modo headed con credenciales de learner y referente + LLM mock.

## Prompt ejecutado

```txt
E2E_LEARNER_EMAIL=e2e-aprendiz@demo.com \
E2E_LEARNER_PASSWORD=prueba123 \
E2E_REFERENTE_EMAIL=referente@demo.com \
E2E_REFERENTE_PASSWORD=prueba123 \
LLM_PROVIDER=mock \
npm run test:e2e:learner:headed
```

## Resultado esperado

Correr el spec E2E de learner en modo headed sin fallas de credenciales.
