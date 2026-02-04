# UX — Training → Practice Clarity

## Contexto

Clarificar el flujo Training → Practice del Aprendiz, sin tocar backend, usando data existente y helpers centralizados.

## Prompt ejecutado

```text
OBJETIVO
Implementar “Paso 2 — Training → Practice clarity” para Aprendiz.
Sin tocar DB, RPCs ni RLS. Solo UI + wiring usando data existente (v_learner_training_home / v_learner_progress) y el helper lib/learner/status-ui.ts.

PROBLEMA A RESOLVER
Hoy el aprendiz no entiende claramente cuándo debe “practicar” vs “seguir aprendiendo”, y el CTA primario no guía el flujo Training → Practice.

ENTREGABLE
1) En /learner (Home) y /learner/training:
   - Mostrar de forma explícita un “modo” (Aprender / Practicar) como UI micro (badge o segmented label NO interactivo por ahora).
   - Definir un CTA primario único que empuje al próximo paso correcto:
     a) Si NO hay práctica disponible / no existe scenario aplicable: CTA primario debe mantener Training (seguir aprendiendo) y mostrar hint claro.
     b) Si hay práctica disponible para la unidad actual: CTA primario debe ser “Practicar unidad {n}”.
     c) Si la práctica ya está completada (según señales ya existentes en el repo): CTA primario debe ser “Continuar” (o “Ir a Evaluación Final” si corresponde por gating existente).
2) En /learner/progress:
   - Mantener 1 CTA primario, pero agregar una línea de guidance consistente (“tu próximo paso es practicar…”).
3) Reutilizar status-ui.ts para badge/hints, pero crear un helper adicional si hace falta:
   - lib/learner/next-step.ts (o similar) que encapsule la lógica de “next step” (training/practice/final-eval) sin duplicar lógica en páginas.

RESTRICCIONES
- No inventar columnas nuevas ni estados nuevos.
- No cambiar backend logic de gating de final evaluation (ya existe en lib/ai/final-evaluation-engine.ts).
- No agregar nuevas rutas si ya existe práctica; si existe /learner/practice o equivalente, usarla.
- Si no existe ruta de práctica, implementar solo banners/CTA placeholders SIN links rotos (link disabled + copy).
- Mantener el patrón “1 primary CTA por pantalla” ya aplicado.
- Mantener accesibilidad básica (button disabled con aria-disabled si aplica).

PASOS
A) Auditar en el repo:
   - ¿Cuál es la ruta real de práctica del aprendiz? (/learner/practice, /learner/practice/[...], etc.)
   - ¿Qué señales existen para saber si práctica está disponible/completada? (practice_attempts, practice_attempt_events, views existentes, etc.)
   - ¿Qué ya devuelve v_learner_training_home y v_learner_progress además de status/progress/current_unit_order?
B) Implementar helper de “next step”:
   - función que recibe trainingHome/progress y devuelve:
     { modeLabel, primaryCta: {label, href|onClick|disabled}, hintLine }
C) Wire en:
   - app/learner/page.tsx
   - app/learner/training/page.tsx
   - app/learner/progress/page.tsx
D) Docs:
   - actualizar docs/navigation-map.md si cambia wiring
   - activity-log entry breve

CHECKS
- npm run lint
- npm run build

OUTPUT
- Entregar lista de archivos tocados + breve explicación de la lógica de next-step y cómo detecta práctica disponible/completada.
```

Resultado esperado

Flujo Training → Practice claro con CTA primario correcto y modo visible.

Notas (opcional)

Sin cambios de backend/DB.
