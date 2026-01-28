# POST-MVP6: Roadmap configuración del bot (docs-first)

## Contexto

Definir el roadmap y contrato de configuración del bot (contenido, comportamiento y evaluación) sin tocar SQL ni UI.

## Prompt ejecutado

```txt
ok read AGENTS.md to get context then # PROMPT PARA CODEX CLI — Post-MVP6 (Docs-first): Roadmap “Configuración del Bot” + Contrato de Comportamiento (sin SQL / sin UI)

Contexto
- Repo: onbo-conversational (trabajo directo en main).
- ONBO es multi-tenant estricto: Organization → Local → User.
- Filosofía: DB-first, RLS-first, Zero Trust, append-only donde afecte auditoría.
- El bot SOLO usa knowledge cargado (sin conocimiento externo) y el aprendizaje es secuencial.
- Ya existe configuración operable parcial (final_evaluation_configs + UI), knowledge coverage K1/K2/K3, métricas M1–M5.
- Ahora queremos ordenar y cerrar el “modelo de configuración del bot” (contenido + comportamiento + evaluación) sin caer en LMS.

Objetivo del lote (Docs-first)
Crear un documento maestro (roadmap + contrato) que defina:
1) Qué significa “configurar el bot” en ONBO.
2) Qué partes son configurables (y por quién: admin_org / referente / superadmin).
3) Qué NO se va a configurar (guardrails anti-LMS).
4) Qué requiere DB changes (tablas/columns/views/RPC) vs qué se resuelve con prompts/plantillas.
5) Un plan de sub-lotes ejecutables (orden, entregables, riesgos, QA smokes).

RESTRICCIONES (MANDATORIAS)
- SOLO documentación: NO crear migraciones, NO tocar UI, NO tocar server actions.
- NO inventar features ni tablas: todo debe partir del schema real.
- Si falta info crítica, documentar “OPEN QUESTIONS” y cómo resolverlas inspeccionando DB/código.
- El documento debe ser accionable por sub-lotes, con deliverables claros y smoke/QA por cada sub-lote.
- Mantener el espíritu “Configurar un bot, no construir un curso”.

Tareas
A) Inspección (repo + DB docs)
1. Leer:
   - docs/post-mvp3/config-bot/A0-inventory.md
   - docs/post-mvp3/config-bot/A1-contract.md
   - docs/roadmap-product-final.md
   - docs/activity-log.md (para entender hitos ya cerrados)
   - docs/db/schema.public.sql y docs/db/dictionary.md (fuente de verdad)
   - AGENTS.md (reglas de mantenimiento de docs/roadmap)
2. Buscar en código dónde vive el “comportamiento del bot”:
   - lib/ai/context-builder.ts
   - lib/ai/* (chat engine, prompts, evaluadores)
   - final-evaluation-engine.ts
   - práctica: evaluador + prompts
3. Relevar “qué ya es configurable” hoy vs “hardcodeado”.

B) Crear el documento de roadmap/contrato (nuevo)
Crear archivo:
- docs/post-mvp6/bot-configuration-roadmap.md

Contenido obligatorio del documento (estructura):
1. Alcance y definición
   - Qué es “Configuración del bot” en ONBO
   - Anti-alcance (no LMS, no authoring libre)
2. Modelo conceptual (como contrato)
   - Capas: Contenido (knowledge) / Comportamiento (respuestas) / Evaluación (criterios y preguntas)
   - Modo bot: entrenamiento | práctica | evaluación final | repaso (si aplica)
3. Configurables vs no configurables (matriz)
   - Tabla: Item | Nivel (org/local/program) | Rol que puede | Estado actual (ya existe / hardcode / no existe) | Riesgo | Requiere DB? | Requiere UI?
   - Listas ✅ / ❌ / 🟡 (MVP, luego, nunca)
4. “Contratos de comportamiento” (lo que falta hoy)
   - Estilo de respuesta: formato, longitud, tono pedagógico, cuándo preguntar vs responder
   - Guardrails: nunca inventar, siempre grounded, cómo manejar “no sé”
   - Qué señales registrar (duda, omisión, etc.)
   - Qué outputs se esperan del evaluador (JSON estricto, etc.)
5. Tipos de contenido y tipología pedagógica (propuesta mínima)
   - Si el schema actual no tiene type: documentar “necesitamos type”
   - Definir tipos mínimos (concepto/procedimiento/regla/guion) y para qué se usan
6. Evaluación (contrato operativo)
   - Qué campos ya existen (final_evaluation_configs) y cómo se interpretan
   - Qué falta (ej: “dificultad” o “plantillas de preguntas”) y si conviene/no conviene
   - Reglas no retroactivas + versionado
7. Plan de sub-lotes ejecutables (orden recomendado)
   - Sub-lote 0: docs-only (este)
   - Sub-lote 1: DB changes mínimas (si aplica) — columnas type/flags, append-only, views
   - Sub-lote 2: Views read-only “config del bot”
   - Sub-lote 3: 1 write seguro guiado (si aplica) (similar a K2)
   - Sub-lote 4: UI mínima (si aplica)
   - Cada sub-lote con:
     - objetivo
     - entregables exactos
     - riesgos
     - QA/smoke SQL esperado
8. OPEN QUESTIONS (si hay)
   - Preguntas que requieren inspección adicional + cómo responderlas

C) Integración con AGENTS.md (mantenimiento)
Actualizar AGENTS.md para:
1. Registrar que docs/post-mvp6/bot-configuration-roadmap.md es un “living roadmap” que debe actualizarse:
   - al cerrar cada sub-lote Post-MVP6
   - al agregar/alterar tablas/columns/views/RPC relacionadas a configuración del bot
2. Incluir una regla simple:
   - “Todo sub-lote Post-MVP6 debe: (a) actualizar roadmap doc, (b) registrar activity-log, (c) regenerar docs/db si hubo cambios de DB”
3. NO romper reglas existentes (solo sumar una sección pequeña y clara).

D) Logging
Actualizar:
- docs/activity-log.md
Con una entrada:
- “Post-MVP6: creado roadmap/contrato configuración del bot (docs-only)”
Incluye:
- resumen
- impacto
- próximos pasos sugeridos

Formato de entrega
- Commit directo en main:
  - docs(post-mvp6): add bot configuration roadmap + agents rule
- Debe incluir únicamente:
  - el nuevo documento
  - el ajuste de AGENTS.md
  - activity-log actualizado
- NO más archivos.

Verificación
- No hace falta db reset, lint, build (porque es docs-only).
- Pero sí verificar que los paths existen y el markdown está bien formado.

Al finalizar
1) Imprimir un resumen con:
   - archivos tocados
   - decisiones clave tomadas
   - lista de OPEN QUESTIONS
2) Proponer el siguiente prompt “Sub-lote 1” solo como borrador (no implementarlo).

IMPORTANTE
- Si detectás que ya existe un doc equivalente, NO dupliques: mejora/expande el existente y explica por qué.
```

Resultado esperado

Documento maestro de roadmap/contrato para la configuración del bot (docs/post-mvp6/bot-configuration-roadmap.md), actualización de AGENTS.md y activity-log.

Notas (opcional)

Se agrega archivo de prompt por regla obligatoria de AGENTS.md.
