# AUDIT-LEARNER-ESTADOS

## Contexto

Auditar el estado actual del aprendiz para definir UX hardening sin inventar estados ni flags.

## Prompt ejecutado

```txt
Sos Codex CLI trabajando sobre el repo `onbo-conversational`.

OBJETIVO
Auditar el estado actual del “aprendiz” para definir UX hardening sin inventar estados ni flags.

TAREAS

1) Estados formales
- Buscar el enum o tipo que define los estados del aprendiz (ej: learner_status).
- Listar TODOS los valores existentes.
- Indicar en qué archivo/migración se define.

2) Uso de estados
- Buscar dónde se usa el estado del aprendiz en:
  - SQL (policies, views, RPCs)
  - Backend (queries / loaders)
  - Frontend (condicionales de UI)
- Indicar archivos relevantes y ejemplos breves.

3) Flags / condiciones existentes
- Detectar si ya existen flags o conceptos como:
  - evaluation_attempt_status
  - practice_completed / progress thresholds
  - cooldowns / locks
- Indicar tabla/campo o lógica donde aparecen.

4) UX actual (si existe)
- Revisar `/learner/training` y rutas relacionadas.
- Indicar si hoy el UI:
  - distingue estados explícitamente
  - bloquea el chat/input según estado
  - cambia CTAs según estado

SALIDA
- Resumen estructurado en markdown con:
  - Estados existentes (fuente de verdad)
  - Flags existentes
  - Dónde se usan hoy
  - Huecos claros desde el punto de vista UX

Qué hacemos con ese output (siguiente mensaje)

Con lo que devuelva Codex:

Armamos la UX State Matrix real (v1)
→ solo con estados y flags que ya existen

Definimos:

CTA principal por estado

chat habilitado / bloqueado

mensajes UX mínimos

Recién después:

implementamos en /learner/training

sin ifs mágicos

con mapping centralizado

Importante (para no desviarnos)

❌ No inventamos estados

❌ No tocamos DB en este paso

❌ No diseñamos “ideal futuro”

Esto es hardening, no expansión.
```

Resultado esperado

Resumen estructurado con estados, usos y flags existentes del aprendiz.

Notas (opcional)

N/A.
