-- Add reviewer_name snapshot to learner_review_decisions

alter table public.learner_review_decisions
add column if not exists reviewer_name text;

update public.learner_review_decisions lrd
set reviewer_name = p.full_name
from public.profiles p
where lrd.reviewer_id = p.user_id
  and lrd.reviewer_name is null;
