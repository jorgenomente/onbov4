-- Smoke: Post-MVP5 M4 playbooks view

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

select count(*) as total_rows from public.v_org_recommended_actions_playbooks_30d;
select count(*) as checklist_not_array
from public.v_org_recommended_actions_playbooks_30d
where checklist is not null
  and jsonb_typeof(to_jsonb(checklist)) <> 'array';
