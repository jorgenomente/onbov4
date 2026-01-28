-- Smoke: Post-MVP5 M1 views

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

select count(*) as total_rows from public.v_org_top_gaps_30d;
select count(*) as total_rows from public.v_org_learner_risk_30d;
select count(*) as total_rows from public.v_org_unit_coverage_30d;
