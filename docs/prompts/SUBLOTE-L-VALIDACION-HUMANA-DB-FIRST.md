# SUBLOTE-L-VALIDACION-HUMANA-DB-FIRST

## Contexto

Post-MVP 2 / Sub-lote L. Analisis DB-first de Validacion humana 2.0 sin escribir codigo.

## Prompt ejecutado

```txt
Post-MVP 2 / Sub-lote L — Análisis DB-first: Validación humana 2.0 (sin escribir código)

Contexto:
ONBO ya permite que un Referente tome decisiones sobre un aprendiz con evidencia
(Fase 2 y 3 cerradas). Ahora necesitamos convertir esas decisiones humanas en
datos estructurados, comparables y auditables, sin cambiar flujos del aprendiz.

Objetivo del análisis:
Definir el contrato mínimo y correcto para “Validación humana 2.0”:
qué datos capturar, dónde viven, cómo se relacionan con lo existente y
qué NO debe hacerse aún.

Reglas:
- SOLO análisis. NO crear migraciones. NO tocar UI.
- DB-first / RLS-first / Zero Trust.
- Append-only. Nada se borra. Nada se recalcula.
- Multi-tenancy estricto (org → local).
- No inventar features nuevas fuera del alcance.

Tareas:

1) Inventario actual:
   Inspeccioná el schema y listá:
   - Tablas actuales relacionadas con decisiones humanas (ej: learner_review_decisions u otras).
   - Qué campos existen hoy (decision, reviewer_id, created_at, etc.).
   - Dónde se consumen actualmente (UI Referente / UI Learner).

2) Problemas del estado actual:
   Respondé explícitamente:
   - ¿Qué NO está estructurado hoy?
   - ¿Qué decisiones no son comparables entre referentes?
   - ¿Qué información no queda registrada pero sería crítica para análisis futuro?

3) Propuesta de contrato “Validación humana 2.0” (solo en papel):
   Definí una estructura mínima que incluya, como máximo:
   - decision_type (approve / reject / request_reinforcement)
   - checklist estructurado (booleans o enums claros)
   - perceived_severity (low / medium / high)
   - recommended_action (none / follow_up / retraining)
   - comment libre (opcional)
   - snapshot del referente (nombre + rol)
   - timestamps

   Indicá:
   - ¿Conviene una tabla nueva o extender la existente?
   - ¿Cómo se relaciona con learner_id, program_id, local_id?
   - ¿Cómo se versiona sin romper historial?

4) RLS y acceso:
   Definí en texto:
   - Quién puede INSERT
   - Quién puede SELECT
   - Qué ve el learner (y qué no)
   - Cómo se evita fuga cross-tenant

5) Impacto en UI (solo conceptual):
   - Qué campos nuevos vería el Referente al decidir.
   - Qué campos nuevos (si alguno) vería el Learner.
   - Qué NO se debe mostrar aún.

6) Riesgos y límites:
   - Riesgos de sobre-estructurar.
   - Riesgos legales / operativos (opiniones humanas).
   - Qué dejar explícitamente fuera del Post-MVP 2.

Formato de salida esperado:
- Sección “Estado actual”
- Sección “Gaps”
- Sección “Contrato propuesto (v2)”
- Sección “RLS / Seguridad”
- Sección “Impacto UI”
- Sección “Fuera de alcance”
- Recomendación clara del siguiente sub-lote (L.1 = migración, L.2 = UI, etc.)

NO escribir SQL ni código.
NO proponer alertas (eso es Sub-lote M).
```

Resultado esperado

Analisis DB-first con inventario, gaps, contrato propuesto, RLS, impacto UI, limites y recomendacion de siguiente sub-lote.

Notas (opcional)

Sin codigo ni SQL.
