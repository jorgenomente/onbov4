# UX — Learner Next Step Clarity

## Contexto

Ajuste de claridad de next-step para el aprendiz con un único CTA primario y microcopy por pantalla, reutilizando status-ui.

## Prompt ejecutado

```txt
LOTE: UX HARDENING – NEXT STEP CLARITY (LEARNER)

Contexto:
El learner ya tiene Home (/learner) como entrypoint y un status→UI mapping centralizado
en lib/learner/status-ui.ts. El flujo funciona y pasó QA. Ahora afinamos claridad.

Meta:
Que cada pantalla del aprendiz tenga:
- Un único CTA primario visible
- Microcopy de 1 línea que explique “por qué” ese CTA
- Sin banners ni mensajes duplicados entre pantallas

Reglas duras:
- No tocar DB, RLS, enums ni lógica de negocio
- No crear rutas nuevas
- No agregar estados nuevos
- Reusar status-ui.ts
- Cambios solo de UI / copy

Tareas:

1) Home (/learner)
- Asegurar que solo haya 1 CTA primario según status.
- Agregar microcopy debajo del CTA usando status-ui:
  ejemplos:
  - en_practica: “Estás avanzando en la unidad actual.”
  - en_riesgo: “Necesitás reforzar antes de avanzar.”
  - en_revision: “Tu evaluación está siendo revisada.”
  - aprobado: “Completaste el programa.”
- No repetir banners largos (Home es la fuente principal).

2) Training (/learner/training)
- Mantener 1 CTA primario (Continuar / Ir a Evaluación / Volver al Home).
- Eliminar banners redundantes si Home ya explica el estado.
- Dejar solo un hint corto (1 línea) cuando aplique.

3) Final Evaluation (/learner/final-evaluation)
- Mostrar estado + CTA de retorno (Home o Progress).
- Sin texto duplicado de Training/Home.

4) Progress (/learner/progress)
- Empty state claro si no hay unidades completadas:
  mensaje corto + CTA a Training.
- No agregar lógica nueva.

Checks obligatorios:
- npm run lint
- npm run build

Salida esperada:
- Lista de archivos tocados
- Confirmación de 1 CTA primario por pantalla
- Confirmación de lint/build OK
```

Resultado esperado

Pantallas del aprendiz con 1 CTA primario y microcopy de contexto sin duplicaciones.

Notas (opcional)

Sin cambios de backend/DB.
