-- Allow learners to read final evaluation configs for their own program
create policy final_evaluation_configs_select_aprendiz
on public.final_evaluation_configs
for select
using (
  public.current_role() = 'aprendiz'
  and exists (
    select 1
    from public.learner_trainings lt
    where lt.learner_id = auth.uid()
      and lt.program_id = final_evaluation_configs.program_id
  )
);
