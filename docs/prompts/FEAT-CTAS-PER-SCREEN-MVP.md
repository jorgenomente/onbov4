# FEAT-CTAS-PER-SCREEN-MVP

## Contexto

Agregar CTAs minimos por pantalla segun navigation map para evitar callejones sin salida.

## Prompt ejecutado

```text
Sos Codex CLI en el repo `onbo-conversational`.

LOTE: CTAs POR PANTALLA (MVP) — SIN FEATURES NUEVAS
Objetivo: que cada pantalla del `docs/navigation-map.md` tenga:
- 1 CTA primario (acción principal)
- 1 CTA secundario (navegación o acción complementaria)
y que no existan “callejones sin salida”.

REGLAS
- No tocar DB / migraciones / RLS.
- No crear rutas nuevas.
- No inventar pantallas nuevas.
- No agregar enlaces a rutas fuera del navigation map.
- No agregar más de 2 CTAs visibles por pantalla (primario/secundario).
- Mantener UI mínima (Tailwind). Mobile-first.
- Si un CTA requiere estado que no está disponible, mostrarlo como disabled con texto “Disponible al completar el recorrido” (sin lógica extra).

PANTALLAS OBJETIVO (todas existen hoy en app/)
Learner:
- /learner/training (app/learner/training/page.tsx)
- /learner/progress
- /learner/profile
- /learner/review/[unitOrder]
- /learner/final-evaluation

Referente:
- /referente/review
- /referente/review/[learnerId]
- /referente/alerts

Org admin:
- /org/metrics
- /org/config/bot
- /org/config/knowledge-coverage
- /org/bot-config
- /org/config/locals-program
- Drilldowns:
  - /org/metrics/coverage/[programId]/[unitOrder]
  - /org/metrics/gaps/[unitOrder]

Auth/public:
- /login (opcional: link a logout no aplica)
- /auth/logout (route, no UI)
- /auth/redirect (route, no UI)
- / (ya es redirect)

TAREAS

1) Implementar CTAs en cada page.tsx (UI)
Para cada pantalla, aplicar EXACTAMENTE:

A) /learner/training
- CTA primario: “Continuar” -> foco en input/enviar (si ya hay componente de chat, usar su submit; si no, botón que haga scroll/focus al input)
- CTA secundario: “Ver progreso” -> link a /learner/progress
- CTA evaluación final: si ya existe UI para iniciar, mantener; si no existe, NO agregar tercer CTA. (Respetar la regla de 2 CTAs.)

B) /learner/progress
- CTA primario: “Volver a entrenamiento” -> /learner/training
- CTA secundario: “Repasar unidad” -> link a la última unidad completada si ya está en data; si no hay data fácil, mostrar botón disabled + texto “Completa una unidad para habilitar repaso”.

C) /learner/review/[unitOrder]
- CTA primario: “Volver a progreso” -> /learner/progress
- CTA secundario: “Volver a entrenamiento” -> /learner/training

D) /learner/profile
- CTA primario: “Volver a entrenamiento” -> /learner/training
- CTA secundario: “Ver progreso” -> /learner/progress

E) /learner/final-evaluation
- CTA primario: “Enviar respuesta” -> submit existente (no inventar)
- CTA secundario: “Volver a entrenamiento” -> /learner/training (si no rompe flow; si hoy debe bloquearse, poner disabled con texto breve)

Referente:
F) /referente/review
- CTA primario: “Abrir revisión” -> si hay listado, link a primer learnerId; si no hay data, dejarlo disabled con “Sin aprendices para revisar”
- CTA secundario: “Ver alertas” -> /referente/alerts

G) /referente/review/[learnerId]
- CTA primario: “Volver a cola” -> /referente/review
- CTA secundario: “Ir a alertas” -> /referente/alerts
(NO implementar botones “Aprobar/Pedir refuerzo” si eso no está ya; este lote es solo navegación/CTAs mínimos)

H) /referente/alerts
- CTA primario: “Volver a revisión” -> /referente/review
- CTA secundario: si hay listado, “Abrir aprendiz” -> primer learnerId; si no hay data, disabled.

Org:
I) /org/metrics
- CTA primario: “Config evaluación final” -> /org/config/bot
- CTA secundario: “Cobertura de knowledge” -> /org/config/knowledge-coverage
(No agregar 3er CTA. El resto queda en navegación del layout.)

J) /org/config/bot
- CTA primario: si existe acción “Crear nueva configuración” mantener; si no existe, no inventar. En ese caso CTA primario: “Volver a métricas”.
- CTA secundario: “Volver a métricas” (si el primario no es volver). Evitar duplicados: si “Volver” es primario, secundario puede ser /org/config/locals-program

K) /org/config/locals-program
- CTA primario: si existe “Asignar programa” mantener; si no existe, no inventar. En ese caso: CTA primario “Volver a métricas”
- CTA secundario: “Volver a métricas” (si no se usó como primario)

L) /org/config/knowledge-coverage
- CTA primario: si existe “Agregar knowledge” mantener; si no, no inventar.
- CTA secundario: “Volver a métricas” -> /org/metrics

M) /org/bot-config
- CTA primario: si existe “Crear escenario” mantener; si no, no inventar.
- CTA secundario: “Volver a métricas” -> /org/metrics

N) Drilldowns metrics
- /org/metrics/coverage/[programId]/[unitOrder]
  - CTA primario: “Volver a métricas” -> /org/metrics
  - CTA secundario: “Volver a coverage” -> si existe parent en UI; si no, repetir /org/metrics (pero evitar duplicado: en ese caso usar “Cobertura de knowledge” -> /org/config/knowledge-coverage)

- /org/metrics/gaps/[unitOrder]
  - CTA primario: “Volver a métricas” -> /org/metrics
  - CTA secundario: “Cobertura de knowledge” -> /org/config/knowledge-coverage

2) Implementación técnica
- Usar `next/link` para navegación.
- Para botones, usar clases Tailwind existentes o patrón del repo.
- Si hay componentes UI existentes (Button), reutilizar.
- Mantener consistencia visual: CTAs en un bloque al inicio de la página (arriba), no al final.

3) Smoke obligatorio
- `npm run lint`
- `npm run build`

4) Commit directo en main
- Commit message: `feat: add screen CTAs per navigation map`

SALIDA
- Lista de archivos tocados
- Confirmación de que cada pantalla tiene <=2 CTAs visibles
- Reporte de lint/build OK
```

## Resultado esperado

CTAs minimos por pantalla con navegacion consistente y sin rutas nuevas.
