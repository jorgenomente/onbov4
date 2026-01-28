-- Smoke: Post-MVP5 M3 view

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

select count(*) as total_rows from public.v_org_recommended_actions_30d;
select count(*) as null_cta_href
from public.v_org_recommended_actions_30d
where cta_href is null;
