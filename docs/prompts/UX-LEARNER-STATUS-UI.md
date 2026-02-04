# UX — Learner Status UI Hardening

## Contexto

Endurecer el flujo del Aprendiz según su estado real, usando datos existentes, sin tocar backend.

## Prompt ejecutado

```txt
1) Qué crear con “new”
UI hardening (UX + lógica de presentación). NO DB, NO migraciones, NO RPCs.

2) Objetivo concreto y entregable esperado
Objetivo:
Endurecer (clarificar y guiar) el flujo del Aprendiz según su estado real
(learner_trainings.status), usando SOLO información existente en el repo.

Entregable:
- Un mapping centralizado estado → UX (CTA, banner, bloqueo de input).
- Aplicar ese mapping en /learner/training para:
  - Mostrar el CTA correcto según status.
  - Bloquear o permitir el input del chat cuando corresponda.
  - Mostrar mensajes claros (banner) para estados como en_revision, en_riesgo, aprobado.
- NO cambiar flujos backend ni reglas de negocio existentes.
- NO inventar estados ni flags nuevos.

Archivos esperados:
- Nuevo helper: lib/learner/status-ui.ts (o similar)
- Cambios mínimos en:
  - app/learner/training/page.tsx
  - app/learner/training/ChatClient.tsx
(opcional: pequeños labels en /learner/progress y /learner/profile, solo visual).

3) Ruta / entidad / feature a seguir
Ruta principal:
- /learner/training (pantalla central del Aprendiz)

Entidad fuente de verdad:
- public.learner_trainings.status
  Estados existentes (NO inventar):
  - en_entrenamiento
  - en_practica
  - en_revision
  - en_riesgo
  - aprobado

Reglas importantes:
- Usar SOLO datos ya disponibles en v_learner_training_home:
  status, progress_percent, current_unit_order.
- Si status === en_revision:
  - Mostrar banner “Evaluación en revisión”.
  - Bloquear input del chat (solo repaso permitido).
- Si status === en_riesgo:
  - Mostrar banner de refuerzo.
  - Mantener chat habilitado.
- Si status === aprobado:
  - Mostrar estado completado (sin bloquear).
- NO duplicar lógica del final-evaluation-engine.
- NO agregar gating nuevo en backend.

Definición de éxito:
El Aprendiz siempre entiende:
- dónde está,
- qué puede hacer ahora,
- cuál es el siguiente paso lógico,
sin romper ningún flujo existente.
```

Resultado esperado

Mapping centralizado estado → UX aplicado en `/learner/training` con bloqueo de input y banners claros.

Notas (opcional)

Sin migraciones ni cambios backend.
