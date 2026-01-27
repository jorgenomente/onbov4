# USE-MOCK-LLM-LOCAL

## Contexto

Configurar provider LLM mock para desarrollo/QA local y validar tests sin depender de cuotas externas.

## Prompt ejecutado

```txt
Objetivo: seguir desarrollo y QA local sin depender de cuotas externas de LLM.
Vamos a usar el provider `mock`.

Tareas:

1) Configuración local
   - Asegurar que en entorno local (dev / qa):
     LLM_PROVIDER=mock
   - NO tocar configuración de producción.
   - Confirmar que el provider `mock`:
     * devuelve respuestas determinísticas
     * incluye payload JSON válido cuando el flujo lo requiere (chat / práctica / evaluación).

2) Verificación de código
   - Revisar lib/ai/provider.ts:
     * confirmar que `mock` está soportado
     * confirmar que produce la misma interfaz que otros providers
     * confirmar que NO intenta llamar APIs externas
   - Confirmar que producción bloquea explícitamente `LLM_PROVIDER=mock`.

3) Smoke manual
   - Con LLM_PROVIDER=mock:
     * login aprendiz
     * /learner/training: enviar mensaje → bot responde
     * iniciar práctica (si aplica) → evaluación mock OK
     * NO errores 429 / network

4) E2E
   - Ejecutar Playwright existente con mock activo
   - Confirmar que los E2E pasan sin dependencia externa

5) UX (si aplica)
   - Si existe manejo de error LLM en UI, confirmar que:
     * no se muestra error de quota
     * los mensajes mock son claros (pueden decir “Respuesta simulada” en dev)

6) Documentación
   - Registrar en docs/activity-log.md:
     * “Se habilita LLM_PROVIDER=mock para desarrollo/QA local por límites de cuota en Gemini”
   - NO crear nuevos docs de arquitectura (esto es operativo).

7) Commit
   - Commit directo a main:
     chore: use mock llm provider for local dev
```

Resultado esperado

Proveedor mock habilitado en local, tests E2E corriendo sin dependencia externa y registro en activity-log.

Notas (opcional)

QA manual en UI depende de interacción humana.
