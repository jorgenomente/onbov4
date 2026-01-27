-- Fix: avoid self-referential RLS recursion on learner_review_decisions

begin;

drop policy if exists learner_review_decisions_select_aprendiz_latest on public.learner_review_decisions;

create policy learner_review_decisions_select_aprendiz
on public.learner_review_decisions
for select
using (
  public.current_role() = 'aprendiz'
  and learner_id = auth.uid()
);

commit;
