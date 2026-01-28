-- Smoke: Post-MVP5 M5 outcomes view

set role postgres;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', (select user_id from public.profiles where role = 'admin_org' order by created_at desc limit 1),
    'role', 'admin_org'
  )::text,
  false
);
set role authenticated;

select count(*) as total_rows from public.v_org_actions_outcomes_30d;
select count(*) as invalid_trend
from public.v_org_actions_outcomes_30d
where trend is not null
  and trend not in ('improving', 'stable', 'worsening');

select count(*) as total_rows
from public.v_org_recommended_actions_playbooks_with_outcomes_30d;
