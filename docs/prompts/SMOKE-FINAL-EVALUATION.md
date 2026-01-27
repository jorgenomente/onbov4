# SMOKE-FINAL-EVALUATION

## Contexto

Smoke test end-to-end de /learner/final-evaluation con gating, intentos, preguntas y persistencia.

## Prompt ejecutado

```txt
Sos Senior Fullstack (Next.js 16 + Supabase). Arrancamos Lote E del smoke test: Evaluación final.

Objetivo:
Validar end-to-end /learner/final-evaluation:
- gating por progreso (solo habilita al completar recorrido)
- creación de intento (max 3, cooldown 12h)
- generación de preguntas (directas + role-play según config)
- registro append-only de preguntas/respuestas/evaluaciones
- al finalizar: learner_trainings.status -> en_revision
- el bot SOLO recomienda (no aprueba); decisión humana queda para referente.

Tareas:
1) Revisar la UI y acciones existentes:
   - app/learner/final-evaluation/page.tsx y actions.ts
   - lib/ai/final-evaluation-engine.ts
2) Confirmar el gating:
   - Si progress_percent < 100 o current_unit_order < last => UI debe bloquear con mensaje claro.
3) Para smoke, permitir el camino recomendado:
   - Con progress completo, iniciar intento
   - Responder 2-3 preguntas
   - Finalizar intento
4) Verificar persistencia en tablas reales del repo (no inventar):
   - attempts, questions, answers, evaluations, transitions
5) UX mínima:
   - mensajes de error user-friendly (cooldown, max attempts, no config)
   - loading state

Restricciones:
- No crear tablas nuevas.
- Fix mínimo si falta wiring o mensajes.
- No romper RLS ni multi-tenant.

Entrega:
- Resultado del smoke (qué funcionó / qué falló).
- Si falta algo, diff mínimo.
```

Resultado esperado
Reporte de smoke test de evaluacion final y ajustes minimos si faltan wiring/mensajes.

Notas (opcional)
Puede requerir ejecutar flujo en UI y consultas DB.
