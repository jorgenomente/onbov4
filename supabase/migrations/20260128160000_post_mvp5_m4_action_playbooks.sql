-- 20260128160000_post_mvp5_m4_action_playbooks.sql
-- Post-MVP5 M4: playbooks determinísticos para acciones sugeridas (read-only)

set check_function_bodies = off;

begin;

-- ------------------------------------------------------------
-- View: v_org_recommended_actions_playbooks_30d
-- ------------------------------------------------------------
drop view if exists public.v_org_recommended_actions_playbooks_30d;

create view public.v_org_recommended_actions_playbooks_30d
with (security_barrier = true)
as
select
  a.org_id,
  a.action_key,
  a.priority,
  a.title,
  a.reason,
  a.evidence,
  a.cta_label,
  a.cta_href,
  case a.action_key
    when 'top_gap' then array[
      'Abrí el gap y revisá en qué locales pega más.',
      'Revisá cobertura de knowledge de la unidad asociada (si aplica) y completá faltantes.',
      'Revisá si hay knowledge desactualizado y desactivalo.',
      'Pedí al referente revisar conversaciones de 2–3 aprendices afectados.'
    ]
    when 'low_coverage' then array[
      'Abrí la unidad/local con baja cobertura.',
      'Confirmá si falta knowledge mapeado o si está deshabilitado.',
      'Agregá knowledge faltante con el wizard (si corresponde).',
      'Monitoreá la cobertura en 24–48h.'
    ]
    when 'learner_risk' then array[
      'Abrí el detalle del aprendiz y revisá evidencia (errores y señales).',
      'Si corresponde, pedí refuerzo con decisión humana.',
      'Verificá si el programa activo del local está bien asignado.'
    ]
    else array[
      'Revisá el detalle y validá si requiere intervención.'
    ]
  end as checklist,
  case a.action_key
    when 'top_gap' then 'Reducir este gap suele mejorar respuestas en escenarios reales y bajar revisiones.'
    when 'low_coverage' then 'Más cobertura suele reducir dudas y respuestas incompletas.'
    when 'learner_risk' then 'Intervenir temprano reduce el tiempo en revisión y mejora consistencia.'
    else 'Acción sugerida para mantener operación estable.'
  end as impact_note,
  case a.action_key
    when 'top_gap' then jsonb_build_array(
      jsonb_build_object('label', 'Ver gap por local', 'href', a.cta_href),
      jsonb_build_object('label', 'Cobertura de conocimiento', 'href', '/org/config/knowledge-coverage'),
      jsonb_build_object('label', 'Configuración evaluación final', 'href', '/org/config/bot')
    )
    when 'low_coverage' then jsonb_build_array(
      jsonb_build_object('label', 'Abrir detalle cobertura', 'href', a.cta_href),
      jsonb_build_object('label', 'Cobertura de conocimiento', 'href', '/org/config/knowledge-coverage')
    )
    when 'learner_risk' then jsonb_build_array(
      jsonb_build_object('label', 'Abrir revisión del aprendiz', 'href', a.cta_href),
      jsonb_build_object('label', 'Programa activo por local', 'href', '/org/config/locals-program')
    )
    else jsonb_build_array()
  end as secondary_links,
  a.created_at
from public.v_org_recommended_actions_30d a
where public.current_role() in ('admin_org', 'superadmin')
  and (
    public.current_role() = 'superadmin'
    or a.org_id = public.current_org_id()
  );

comment on view public.v_org_recommended_actions_playbooks_30d is
'Post-MVP5 M4: Playbooks determinísticos para acciones sugeridas (checklist, impacto, links secundarios).';

commit;
