# POST-MVP5 M4 ACTION PLAYBOOKS

## Contexto

Sub-lote M4: playbooks guiados para acciones sugeridas (read-only) basados en M3.

## Prompt ejecutado

```txt
# Post-MVP 5 — Sub-lote M4 (Read-only): Playbooks “guiados” para Acciones sugeridas (Admin Org)

OBJETIVO
Subir el valor operativo de M3 sin agregar writes:
- Cada “Acción sugerida” debe traer un mini-playbook guiado:
  - checklist (pasos sugeridos)
  - impacto esperado (heurístico, no promesa)
  - links secundarios relevantes (2–3 máximo)
Todo determinístico, explicable y mobile-first.

ALCANCE (MVP CERRADO)
- Solo lectura: view + UI.
- No nuevas tablas.
- No RPCs write.
- No motor de reglas complejo.
- No LLM.

INPUTS EXISTENTES
- v_org_recommended_actions_30d (M3)
  - action_key, priority, title, reason, evidence, cta_label, cta_href

DECISIÓN DE DISEÑO
Implementar “playbook” como lógica determinística en una view wrapper:
- v_org_recommended_actions_playbooks_30d
que enriquece cada fila con:
- checklist (text[])
- impact_note (text)
- secondary_links (jsonb[])  -- {label, href}
De esta forma la UI solo renderiza y no “interpreta”.

ENTREGABLES DB (1 migración)
Crear migración: supabase/migrations/YYYYMMDDHHMMSS_post_mvp5_m4_action_playbooks.sql

1) Crear view: public.v_org_recommended_actions_playbooks_30d
- Basada en public.v_org_recommended_actions_30d
- Mantener filtros role/org como en M3 (admin_org/superadmin)
- Columnas (contrato):
  - org_id uuid
  - action_key text
  - priority int
  - title text
  - reason text
  - evidence jsonb
  - cta_label text
  - cta_href text
  - checklist text[]          -- lista de 3–6 pasos
  - impact_note text          -- 1 línea, sin promesas
  - secondary_links jsonb     -- array JSON [{label, href}, ...], 0–3 items
  - created_at timestamptz

2) Reglas de enriquecimiento (CASE por action_key)
Definir playbooks por action_key real usado en M3.
Esperados (ajustar a tus keys reales):
- 'gap_high_impact'
- 'unit_coverage_low'
- 'learners_at_risk'

Ejemplos (MVP):
A) gap_high_impact
- checklist:
  1) Abrí el gap y revisá en qué locales pega más (drill-down).
  2) Revisá cobertura de knowledge de la unidad asociada (si aplica) y completá faltantes.
  3) Revisá si hay knowledge desactualizado y desactivalo.
  4) Pedí al referente revisar conversaciones de 2–3 aprendices afectados.
- impact_note:
  “Reducir este gap suele mejorar respuestas en escenarios reales y bajar revisiones.”
- secondary_links:
  - {label:"Ver gap por local", href: cta_href}
  - {label:"Cobertura de conocimiento", href:"/org/config/knowledge-coverage"}
  - {label:"Configuración evaluación final", href:"/org/config/bot"}

B) unit_coverage_low
- checklist:
  1) Abrí la unidad/local con baja cobertura.
  2) Confirmá si falta knowledge mapeado o si está deshabilitado.
  3) Agregá knowledge faltante con el wizard (si corresponde).
  4) Monitoreá la cobertura en 24–48h.
- impact_note:
  “Más cobertura suele reducir dudas y respuestas incompletas.”
- secondary_links:
  - {label:"Abrir detalle cobertura", href: cta_href}
  - {label:"Cobertura de conocimiento", href:"/org/config/knowledge-coverage"}

C) learners_at_risk
- checklist:
  1) Abrí el detalle del aprendiz y revisá evidencia (errores y señales).
  2) Si corresponde, pedí refuerzo con decisión humana.
  3) Verificá si el programa activo del local está bien asignado.
- impact_note:
  “Intervenir temprano reduce el tiempo en revisión y mejora consistencia.”
- secondary_links:
  - {label:"Abrir revisión del aprendiz", href: cta_href}
  - {label:"Programa activo por local", href:"/org/config/locals-program"}

Notas:
- No inventar links a rutas que no existan.
- No hacer mapping gap_key→unit_order si no existe. Mantenerlo “si aplica”.

REGENERAR DOCS DB
- npx supabase db reset
- npm run db:dictionary
- npm run db:dump:schema
- Commit dumps: docs/db/dictionary.md, docs/db/schema.public.sql

ENTREGABLES UI
Modificar /org/metrics (tab Resumen) para usar la view nueva:
- En vez de v_org_recommended_actions_30d, consultar v_org_recommended_actions_playbooks_30d
- UI:
  - Card por acción:
    - title + reason
    - badge prioridad (Alta/Media/Baja)
    - Checklist renderizada en bullets
    - impact_note en texto pequeño
    - CTA principal (button/link)
    - Secondary links como links secundarios (2–3)
- Estados:
  - loading ya existente
  - empty: “No hay acciones sugeridas…”
  - error state

DOCS / LOG
- docs/activity-log.md: “Post-MVP5 M4 playbooks para acciones sugeridas”
- docs/prompts/POST-MVP5-M4-ACTION-PLAYBOOKS.md

QA / GATE
- npx supabase db reset
- Manual:
  1) Admin org: /org/metrics -> Resumen muestra cards con checklist
  2) CTA y secondary links navegan
  3) Empty state ok si no hay filas
- npm run lint
- npm run build

COMMIT / PUSH (permisos escalados OK)
- Commit: feat(post-mvp5): action playbooks (read-only)
- Push: origin main

RESTRICCIONES
- No agregar seeds.
- No cambiar lógica M3 (solo enriquecer + UI).
- Si falla por action_key distinto, ajustar CASE a keys reales de la view M3.
```

Resultado esperado

View con playbooks y UI actualizada en /org/metrics.

Notas (opcional)

Sin notas.
