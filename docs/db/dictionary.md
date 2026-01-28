# Diccionario de datos (public)

> Generado automáticamente. No editar a mano.

## Tablas y columnas

| table_name                              | column_name                     | tipo                     | not_null | default                            |
| --------------------------------------- | ------------------------------- | ------------------------ | -------- | ---------------------------------- |
| alert_events                            | id                              | uuid                     | true     | gen_random_uuid()                  |
| alert_events                            | alert_type                      | USER-DEFINED             | true     |                                    |
| alert_events                            | learner_id                      | uuid                     | true     |                                    |
| alert_events                            | local_id                        | uuid                     | true     |                                    |
| alert_events                            | org_id                          | uuid                     | true     |                                    |
| alert_events                            | source_table                    | text                     | true     |                                    |
| alert_events                            | source_id                       | uuid                     | true     |                                    |
| alert_events                            | payload                         | jsonb                    | true     | '{}'::jsonb                        |
| alert_events                            | created_at                      | timestamp with time zone | true     | now()                              |
| bot_message_evaluations                 | id                              | uuid                     | true     | gen_random_uuid()                  |
| bot_message_evaluations                 | message_id                      | uuid                     | true     |                                    |
| bot_message_evaluations                 | coherence_score                 | numeric                  | false    |                                    |
| bot_message_evaluations                 | omissions                       | ARRAY                    | false    |                                    |
| bot_message_evaluations                 | tags                            | ARRAY                    | false    |                                    |
| bot_message_evaluations                 | created_at                      | timestamp with time zone | true     | now()                              |
| conversation_messages                   | id                              | uuid                     | true     | gen_random_uuid()                  |
| conversation_messages                   | conversation_id                 | uuid                     | true     |                                    |
| conversation_messages                   | sender                          | text                     | true     |                                    |
| conversation_messages                   | content                         | text                     | true     |                                    |
| conversation_messages                   | created_at                      | timestamp with time zone | true     | now()                              |
| conversations                           | id                              | uuid                     | true     | gen_random_uuid()                  |
| conversations                           | learner_id                      | uuid                     | true     |                                    |
| conversations                           | local_id                        | uuid                     | true     |                                    |
| conversations                           | program_id                      | uuid                     | true     |                                    |
| conversations                           | unit_order                      | integer                  | true     |                                    |
| conversations                           | context                         | text                     | true     |                                    |
| conversations                           | created_at                      | timestamp with time zone | true     | now()                              |
| final_evaluation_answers                | id                              | uuid                     | true     | gen_random_uuid()                  |
| final_evaluation_answers                | question_id                     | uuid                     | true     |                                    |
| final_evaluation_answers                | learner_answer                  | text                     | true     |                                    |
| final_evaluation_answers                | created_at                      | timestamp with time zone | true     | now()                              |
| final_evaluation_attempts               | id                              | uuid                     | true     | gen_random_uuid()                  |
| final_evaluation_attempts               | learner_id                      | uuid                     | true     |                                    |
| final_evaluation_attempts               | program_id                      | uuid                     | true     |                                    |
| final_evaluation_attempts               | attempt_number                  | integer                  | true     |                                    |
| final_evaluation_attempts               | started_at                      | timestamp with time zone | true     | now()                              |
| final_evaluation_attempts               | ended_at                        | timestamp with time zone | false    |                                    |
| final_evaluation_attempts               | status                          | text                     | true     |                                    |
| final_evaluation_attempts               | global_score                    | numeric                  | false    |                                    |
| final_evaluation_attempts               | bot_recommendation              | text                     | false    |                                    |
| final_evaluation_attempts               | created_at                      | timestamp with time zone | true     | now()                              |
| final_evaluation_configs                | id                              | uuid                     | true     | gen_random_uuid()                  |
| final_evaluation_configs                | program_id                      | uuid                     | true     |                                    |
| final_evaluation_configs                | total_questions                 | integer                  | true     |                                    |
| final_evaluation_configs                | roleplay_ratio                  | numeric                  | true     |                                    |
| final_evaluation_configs                | min_global_score                | numeric                  | true     |                                    |
| final_evaluation_configs                | must_pass_units                 | ARRAY                    | true     | '{}'::integer[]                    |
| final_evaluation_configs                | questions_per_unit              | integer                  | true     | 1                                  |
| final_evaluation_configs                | max_attempts                    | integer                  | true     | 3                                  |
| final_evaluation_configs                | cooldown_hours                  | integer                  | true     | 12                                 |
| final_evaluation_configs                | created_at                      | timestamp with time zone | true     | now()                              |
| final_evaluation_evaluations            | id                              | uuid                     | true     | gen_random_uuid()                  |
| final_evaluation_evaluations            | answer_id                       | uuid                     | true     |                                    |
| final_evaluation_evaluations            | unit_order                      | integer                  | true     |                                    |
| final_evaluation_evaluations            | score                           | numeric                  | true     |                                    |
| final_evaluation_evaluations            | verdict                         | text                     | true     |                                    |
| final_evaluation_evaluations            | strengths                       | ARRAY                    | true     | '{}'::text[]                       |
| final_evaluation_evaluations            | gaps                            | ARRAY                    | true     | '{}'::text[]                       |
| final_evaluation_evaluations            | feedback                        | text                     | true     |                                    |
| final_evaluation_evaluations            | doubt_signals                   | ARRAY                    | true     | '{}'::text[]                       |
| final_evaluation_evaluations            | created_at                      | timestamp with time zone | true     | now()                              |
| final_evaluation_questions              | id                              | uuid                     | true     | gen_random_uuid()                  |
| final_evaluation_questions              | attempt_id                      | uuid                     | true     |                                    |
| final_evaluation_questions              | unit_order                      | integer                  | true     |                                    |
| final_evaluation_questions              | question_type                   | text                     | true     |                                    |
| final_evaluation_questions              | prompt                          | text                     | true     |                                    |
| final_evaluation_questions              | created_at                      | timestamp with time zone | true     | now()                              |
| knowledge_change_events                 | id                              | uuid                     | true     | gen_random_uuid()                  |
| knowledge_change_events                 | org_id                          | uuid                     | true     |                                    |
| knowledge_change_events                 | local_id                        | uuid                     | false    |                                    |
| knowledge_change_events                 | program_id                      | uuid                     | true     |                                    |
| knowledge_change_events                 | unit_id                         | uuid                     | true     |                                    |
| knowledge_change_events                 | unit_order                      | integer                  | true     |                                    |
| knowledge_change_events                 | knowledge_id                    | uuid                     | true     |                                    |
| knowledge_change_events                 | action                          | text                     | true     | 'create_and_map'::text             |
| knowledge_change_events                 | created_by_user_id              | uuid                     | true     |                                    |
| knowledge_change_events                 | title                           | text                     | true     |                                    |
| knowledge_change_events                 | created_at                      | timestamp with time zone | true     | now()                              |
| knowledge_change_events                 | reason                          | text                     | false    |                                    |
| knowledge_items                         | id                              | uuid                     | true     | gen_random_uuid()                  |
| knowledge_items                         | org_id                          | uuid                     | true     |                                    |
| knowledge_items                         | local_id                        | uuid                     | false    |                                    |
| knowledge_items                         | title                           | text                     | true     |                                    |
| knowledge_items                         | content                         | text                     | true     |                                    |
| knowledge_items                         | created_at                      | timestamp with time zone | true     | now()                              |
| knowledge_items                         | is_enabled                      | boolean                  | true     | true                               |
| learner_future_questions                | id                              | uuid                     | true     | gen_random_uuid()                  |
| learner_future_questions                | learner_id                      | uuid                     | true     |                                    |
| learner_future_questions                | local_id                        | uuid                     | true     |                                    |
| learner_future_questions                | program_id                      | uuid                     | true     |                                    |
| learner_future_questions                | asked_unit_order                | integer                  | true     |                                    |
| learner_future_questions                | conversation_id                 | uuid                     | false    |                                    |
| learner_future_questions                | message_id                      | uuid                     | false    |                                    |
| learner_future_questions                | question_text                   | text                     | true     |                                    |
| learner_future_questions                | created_at                      | timestamp with time zone | true     | now()                              |
| learner_review_decisions                | id                              | uuid                     | true     | gen_random_uuid()                  |
| learner_review_decisions                | learner_id                      | uuid                     | true     |                                    |
| learner_review_decisions                | reviewer_id                     | uuid                     | true     |                                    |
| learner_review_decisions                | decision                        | text                     | true     |                                    |
| learner_review_decisions                | reason                          | text                     | true     |                                    |
| learner_review_decisions                | created_at                      | timestamp with time zone | true     | now()                              |
| learner_review_decisions                | reviewer_name                   | text                     | false    |                                    |
| learner_review_validations_v2           | id                              | uuid                     | true     | gen_random_uuid()                  |
| learner_review_validations_v2           | learner_id                      | uuid                     | true     |                                    |
| learner_review_validations_v2           | reviewer_id                     | uuid                     | true     |                                    |
| learner_review_validations_v2           | local_id                        | uuid                     | true     |                                    |
| learner_review_validations_v2           | program_id                      | uuid                     | true     |                                    |
| learner_review_validations_v2           | decision_type                   | USER-DEFINED             | true     |                                    |
| learner_review_validations_v2           | perceived_severity              | USER-DEFINED             | true     | 'low'::perceived_severity          |
| learner_review_validations_v2           | recommended_action              | USER-DEFINED             | true     | 'none'::recommended_action         |
| learner_review_validations_v2           | checklist                       | jsonb                    | true     | '{}'::jsonb                        |
| learner_review_validations_v2           | comment                         | text                     | false    |                                    |
| learner_review_validations_v2           | reviewer_name                   | text                     | true     |                                    |
| learner_review_validations_v2           | reviewer_role                   | USER-DEFINED             | true     |                                    |
| learner_review_validations_v2           | created_at                      | timestamp with time zone | true     | now()                              |
| learner_state_transitions               | id                              | uuid                     | true     | gen_random_uuid()                  |
| learner_state_transitions               | learner_id                      | uuid                     | true     |                                    |
| learner_state_transitions               | from_status                     | USER-DEFINED             | false    |                                    |
| learner_state_transitions               | to_status                       | USER-DEFINED             | true     |                                    |
| learner_state_transitions               | reason                          | text                     | false    |                                    |
| learner_state_transitions               | actor_user_id                   | uuid                     | false    |                                    |
| learner_state_transitions               | created_at                      | timestamp with time zone | true     | now()                              |
| learner_trainings                       | id                              | uuid                     | true     | gen_random_uuid()                  |
| learner_trainings                       | learner_id                      | uuid                     | true     |                                    |
| learner_trainings                       | local_id                        | uuid                     | true     |                                    |
| learner_trainings                       | program_id                      | uuid                     | true     |                                    |
| learner_trainings                       | status                          | USER-DEFINED             | true     | 'en_entrenamiento'::learner_status |
| learner_trainings                       | current_unit_order              | integer                  | true     | 1                                  |
| learner_trainings                       | progress_percent                | numeric                  | true     | 0                                  |
| learner_trainings                       | started_at                      | timestamp with time zone | true     | now()                              |
| learner_trainings                       | updated_at                      | timestamp with time zone | true     | now()                              |
| local_active_program_change_events      | id                              | uuid                     | true     | gen_random_uuid()                  |
| local_active_program_change_events      | org_id                          | uuid                     | true     |                                    |
| local_active_program_change_events      | local_id                        | uuid                     | true     |                                    |
| local_active_program_change_events      | from_program_id                 | uuid                     | false    |                                    |
| local_active_program_change_events      | to_program_id                   | uuid                     | true     |                                    |
| local_active_program_change_events      | changed_by_user_id              | uuid                     | true     |                                    |
| local_active_program_change_events      | reason                          | text                     | false    |                                    |
| local_active_program_change_events      | created_at                      | timestamp with time zone | true     | now()                              |
| local_active_programs                   | local_id                        | uuid                     | true     |                                    |
| local_active_programs                   | program_id                      | uuid                     | true     |                                    |
| local_active_programs                   | created_at                      | timestamp with time zone | true     | now()                              |
| locals                                  | id                              | uuid                     | true     | gen_random_uuid()                  |
| locals                                  | org_id                          | uuid                     | true     |                                    |
| locals                                  | name                            | text                     | true     |                                    |
| locals                                  | created_at                      | timestamp with time zone | true     | now()                              |
| notification_emails                     | id                              | uuid                     | true     | gen_random_uuid()                  |
| notification_emails                     | org_id                          | uuid                     | true     |                                    |
| notification_emails                     | local_id                        | uuid                     | true     |                                    |
| notification_emails                     | learner_id                      | uuid                     | true     |                                    |
| notification_emails                     | decision_id                     | uuid                     | true     |                                    |
| notification_emails                     | email_type                      | text                     | true     |                                    |
| notification_emails                     | to_email                        | text                     | true     |                                    |
| notification_emails                     | subject                         | text                     | true     |                                    |
| notification_emails                     | provider                        | text                     | true     | 'resend'::text                     |
| notification_emails                     | provider_message_id             | text                     | false    |                                    |
| notification_emails                     | status                          | text                     | true     |                                    |
| notification_emails                     | error                           | text                     | false    |                                    |
| notification_emails                     | created_at                      | timestamp with time zone | true     | now()                              |
| organizations                           | id                              | uuid                     | true     | gen_random_uuid()                  |
| organizations                           | name                            | text                     | true     |                                    |
| organizations                           | created_at                      | timestamp with time zone | true     | now()                              |
| practice_attempt_events                 | id                              | uuid                     | true     | gen_random_uuid()                  |
| practice_attempt_events                 | attempt_id                      | uuid                     | true     |                                    |
| practice_attempt_events                 | event_type                      | text                     | true     |                                    |
| practice_attempt_events                 | created_at                      | timestamp with time zone | true     | now()                              |
| practice_attempts                       | id                              | uuid                     | true     | gen_random_uuid()                  |
| practice_attempts                       | scenario_id                     | uuid                     | true     |                                    |
| practice_attempts                       | learner_id                      | uuid                     | true     |                                    |
| practice_attempts                       | local_id                        | uuid                     | true     |                                    |
| practice_attempts                       | conversation_id                 | uuid                     | true     |                                    |
| practice_attempts                       | started_at                      | timestamp with time zone | true     | now()                              |
| practice_attempts                       | ended_at                        | timestamp with time zone | false    |                                    |
| practice_attempts                       | status                          | text                     | true     |                                    |
| practice_evaluations                    | id                              | uuid                     | true     | gen_random_uuid()                  |
| practice_evaluations                    | attempt_id                      | uuid                     | true     |                                    |
| practice_evaluations                    | learner_message_id              | uuid                     | true     |                                    |
| practice_evaluations                    | score                           | numeric                  | true     |                                    |
| practice_evaluations                    | verdict                         | text                     | true     |                                    |
| practice_evaluations                    | strengths                       | ARRAY                    | true     | '{}'::text[]                       |
| practice_evaluations                    | gaps                            | ARRAY                    | true     | '{}'::text[]                       |
| practice_evaluations                    | feedback                        | text                     | true     |                                    |
| practice_evaluations                    | doubt_signals                   | ARRAY                    | true     | '{}'::text[]                       |
| practice_evaluations                    | created_at                      | timestamp with time zone | true     | now()                              |
| practice_scenarios                      | id                              | uuid                     | true     | gen_random_uuid()                  |
| practice_scenarios                      | org_id                          | uuid                     | true     |                                    |
| practice_scenarios                      | local_id                        | uuid                     | false    |                                    |
| practice_scenarios                      | program_id                      | uuid                     | true     |                                    |
| practice_scenarios                      | unit_order                      | integer                  | true     |                                    |
| practice_scenarios                      | title                           | text                     | true     |                                    |
| practice_scenarios                      | difficulty                      | integer                  | true     | 1                                  |
| practice_scenarios                      | instructions                    | text                     | true     |                                    |
| practice_scenarios                      | success_criteria                | ARRAY                    | true     | '{}'::text[]                       |
| practice_scenarios                      | created_at                      | timestamp with time zone | true     | now()                              |
| profiles                                | user_id                         | uuid                     | true     |                                    |
| profiles                                | org_id                          | uuid                     | true     |                                    |
| profiles                                | local_id                        | uuid                     | true     |                                    |
| profiles                                | role                            | USER-DEFINED             | true     |                                    |
| profiles                                | full_name                       | text                     | false    |                                    |
| profiles                                | created_at                      | timestamp with time zone | true     | now()                              |
| profiles                                | updated_at                      | timestamp with time zone | true     | now()                              |
| training_programs                       | id                              | uuid                     | true     | gen_random_uuid()                  |
| training_programs                       | org_id                          | uuid                     | true     |                                    |
| training_programs                       | local_id                        | uuid                     | false    |                                    |
| training_programs                       | name                            | text                     | true     |                                    |
| training_programs                       | is_active                       | boolean                  | true     | true                               |
| training_programs                       | created_at                      | timestamp with time zone | true     | now()                              |
| training_units                          | id                              | uuid                     | true     | gen_random_uuid()                  |
| training_units                          | program_id                      | uuid                     | true     |                                    |
| training_units                          | unit_order                      | integer                  | true     |                                    |
| training_units                          | title                           | text                     | true     |                                    |
| training_units                          | objectives                      | ARRAY                    | true     | '{}'::text[]                       |
| training_units                          | created_at                      | timestamp with time zone | true     | now()                              |
| unit_knowledge_map                      | unit_id                         | uuid                     | true     |                                    |
| unit_knowledge_map                      | knowledge_id                    | uuid                     | true     |                                    |
| v_conversation_thread                   | message_id                      | uuid                     | false    |                                    |
| v_conversation_thread                   | sender                          | text                     | false    |                                    |
| v_conversation_thread                   | content                         | text                     | false    |                                    |
| v_conversation_thread                   | created_at                      | timestamp with time zone | false    |                                    |
| v_learner_active_conversation           | conversation_id                 | uuid                     | false    |                                    |
| v_learner_active_conversation           | unit_order                      | integer                  | false    |                                    |
| v_learner_active_conversation           | context                         | text                     | false    |                                    |
| v_learner_active_conversation           | created_at                      | timestamp with time zone | false    |                                    |
| v_learner_doubt_signals                 | org_id                          | uuid                     | false    |                                    |
| v_learner_doubt_signals                 | local_id                        | uuid                     | false    |                                    |
| v_learner_doubt_signals                 | learner_id                      | uuid                     | false    |                                    |
| v_learner_doubt_signals                 | program_id                      | uuid                     | false    |                                    |
| v_learner_doubt_signals                 | unit_order                      | integer                  | false    |                                    |
| v_learner_doubt_signals                 | signal                          | text                     | false    |                                    |
| v_learner_doubt_signals                 | total_count                     | integer                  | false    |                                    |
| v_learner_doubt_signals                 | last_seen_at                    | timestamp with time zone | false    |                                    |
| v_learner_doubt_signals                 | sources                         | ARRAY                    | false    |                                    |
| v_learner_evaluation_summary            | org_id                          | uuid                     | false    |                                    |
| v_learner_evaluation_summary            | local_id                        | uuid                     | false    |                                    |
| v_learner_evaluation_summary            | learner_id                      | uuid                     | false    |                                    |
| v_learner_evaluation_summary            | program_id                      | uuid                     | false    |                                    |
| v_learner_evaluation_summary            | attempt_id                      | uuid                     | false    |                                    |
| v_learner_evaluation_summary            | attempt_number                  | integer                  | false    |                                    |
| v_learner_evaluation_summary            | status                          | text                     | false    |                                    |
| v_learner_evaluation_summary            | global_score                    | numeric                  | false    |                                    |
| v_learner_evaluation_summary            | bot_recommendation              | text                     | false    |                                    |
| v_learner_evaluation_summary            | unit_order                      | integer                  | false    |                                    |
| v_learner_evaluation_summary            | total_questions                 | integer                  | false    |                                    |
| v_learner_evaluation_summary            | avg_score                       | numeric                  | false    |                                    |
| v_learner_evaluation_summary            | pass_count                      | integer                  | false    |                                    |
| v_learner_evaluation_summary            | partial_count                   | integer                  | false    |                                    |
| v_learner_evaluation_summary            | fail_count                      | integer                  | false    |                                    |
| v_learner_evaluation_summary            | last_evaluated_at               | timestamp with time zone | false    |                                    |
| v_learner_evidence                      | learner_id                      | uuid                     | false    |                                    |
| v_learner_evidence                      | practice_summary                | json                     | false    |                                    |
| v_learner_evidence                      | doubt_signals                   | ARRAY                    | false    |                                    |
| v_learner_evidence                      | recent_messages                 | json                     | false    |                                    |
| v_learner_progress                      | learner_id                      | uuid                     | false    |                                    |
| v_learner_progress                      | status                          | USER-DEFINED             | false    |                                    |
| v_learner_progress                      | progress_percent                | numeric                  | false    |                                    |
| v_learner_progress                      | current_unit_order              | integer                  | false    |                                    |
| v_learner_progress                      | units                           | json                     | false    |                                    |
| v_learner_training_home                 | learner_id                      | uuid                     | false    |                                    |
| v_learner_training_home                 | status                          | USER-DEFINED             | false    |                                    |
| v_learner_training_home                 | program_id                      | uuid                     | false    |                                    |
| v_learner_training_home                 | program_name                    | text                     | false    |                                    |
| v_learner_training_home                 | current_unit_order              | integer                  | false    |                                    |
| v_learner_training_home                 | total_units                     | integer                  | false    |                                    |
| v_learner_training_home                 | current_unit_title              | text                     | false    |                                    |
| v_learner_training_home                 | objectives                      | ARRAY                    | false    |                                    |
| v_learner_training_home                 | progress_percent                | numeric                  | false    |                                    |
| v_learner_wrong_answers                 | org_id                          | uuid                     | false    |                                    |
| v_learner_wrong_answers                 | local_id                        | uuid                     | false    |                                    |
| v_learner_wrong_answers                 | learner_id                      | uuid                     | false    |                                    |
| v_learner_wrong_answers                 | program_id                      | uuid                     | false    |                                    |
| v_learner_wrong_answers                 | attempt_id                      | uuid                     | false    |                                    |
| v_learner_wrong_answers                 | unit_order                      | integer                  | false    |                                    |
| v_learner_wrong_answers                 | question_id                     | uuid                     | false    |                                    |
| v_learner_wrong_answers                 | question_type                   | text                     | false    |                                    |
| v_learner_wrong_answers                 | prompt                          | text                     | false    |                                    |
| v_learner_wrong_answers                 | answer_id                       | uuid                     | false    |                                    |
| v_learner_wrong_answers                 | learner_answer                  | text                     | false    |                                    |
| v_learner_wrong_answers                 | score                           | numeric                  | false    |                                    |
| v_learner_wrong_answers                 | verdict                         | text                     | false    |                                    |
| v_learner_wrong_answers                 | strengths                       | ARRAY                    | false    |                                    |
| v_learner_wrong_answers                 | gaps                            | ARRAY                    | false    |                                    |
| v_learner_wrong_answers                 | feedback                        | text                     | false    |                                    |
| v_learner_wrong_answers                 | doubt_signals                   | ARRAY                    | false    |                                    |
| v_learner_wrong_answers                 | created_at                      | timestamp with time zone | false    |                                    |
| v_local_learner_risk_30d                | local_id                        | uuid                     | false    |                                    |
| v_local_learner_risk_30d                | learner_id                      | uuid                     | false    |                                    |
| v_local_learner_risk_30d                | failed_practice_count           | integer                  | false    |                                    |
| v_local_learner_risk_30d                | failed_final_count              | integer                  | false    |                                    |
| v_local_learner_risk_30d                | doubt_signals_count             | integer                  | false    |                                    |
| v_local_learner_risk_30d                | last_activity_at                | timestamp with time zone | false    |                                    |
| v_local_learner_risk_30d                | risk_level                      | text                     | false    |                                    |
| v_local_learner_risk_30d                | reasons                         | ARRAY                    | false    |                                    |
| v_local_top_gaps_30d                    | local_id                        | uuid                     | false    |                                    |
| v_local_top_gaps_30d                    | gap                             | text                     | false    |                                    |
| v_local_top_gaps_30d                    | count_total                     | integer                  | false    |                                    |
| v_local_top_gaps_30d                    | learners_affected               | integer                  | false    |                                    |
| v_local_top_gaps_30d                    | percent_learners_affected       | numeric                  | false    |                                    |
| v_local_top_gaps_30d                    | last_seen_at                    | timestamp with time zone | false    |                                    |
| v_local_unit_coverage_30d               | local_id                        | uuid                     | false    |                                    |
| v_local_unit_coverage_30d               | program_id                      | uuid                     | false    |                                    |
| v_local_unit_coverage_30d               | unit_order                      | integer                  | false    |                                    |
| v_local_unit_coverage_30d               | avg_practice_score              | numeric                  | false    |                                    |
| v_local_unit_coverage_30d               | avg_final_score                 | numeric                  | false    |                                    |
| v_local_unit_coverage_30d               | practice_fail_rate              | numeric                  | false    |                                    |
| v_local_unit_coverage_30d               | final_fail_rate                 | numeric                  | false    |                                    |
| v_local_unit_coverage_30d               | top_gap                         | text                     | false    |                                    |
| v_org_gap_locals_30d                    | org_id                          | uuid                     | false    |                                    |
| v_org_gap_locals_30d                    | gap_key                         | text                     | false    |                                    |
| v_org_gap_locals_30d                    | local_id                        | uuid                     | false    |                                    |
| v_org_gap_locals_30d                    | local_name                      | text                     | false    |                                    |
| v_org_gap_locals_30d                    | learners_affected_count         | integer                  | false    |                                    |
| v_org_gap_locals_30d                    | percent_learners_affected_local | numeric                  | false    |                                    |
| v_org_gap_locals_30d                    | total_events_30d                | integer                  | false    |                                    |
| v_org_gap_locals_30d                    | last_event_at                   | timestamp with time zone | false    |                                    |
| v_org_learner_risk_30d                  | org_id                          | uuid                     | false    |                                    |
| v_org_learner_risk_30d                  | local_id                        | uuid                     | false    |                                    |
| v_org_learner_risk_30d                  | learner_id                      | uuid                     | false    |                                    |
| v_org_learner_risk_30d                  | risk_level                      | text                     | false    |                                    |
| v_org_learner_risk_30d                  | risk_score                      | integer                  | false    |                                    |
| v_org_learner_risk_30d                  | signals_count_30d               | integer                  | false    |                                    |
| v_org_learner_risk_30d                  | last_signal_at                  | timestamp with time zone | false    |                                    |
| v_org_local_active_programs             | local_id                        | uuid                     | false    |                                    |
| v_org_local_active_programs             | org_id                          | uuid                     | false    |                                    |
| v_org_local_active_programs             | local_name                      | text                     | false    |                                    |
| v_org_local_active_programs             | program_id                      | uuid                     | false    |                                    |
| v_org_local_active_programs             | program_name                    | text                     | false    |                                    |
| v_org_local_active_programs             | program_local_id                | uuid                     | false    |                                    |
| v_org_local_active_programs             | program_is_active               | boolean                  | false    |                                    |
| v_org_local_active_programs             | activated_at                    | timestamp with time zone | false    |                                    |
| v_org_program_final_eval_config_current | program_id                      | uuid                     | false    |                                    |
| v_org_program_final_eval_config_current | org_id                          | uuid                     | false    |                                    |
| v_org_program_final_eval_config_current | program_local_id                | uuid                     | false    |                                    |
| v_org_program_final_eval_config_current | program_name                    | text                     | false    |                                    |
| v_org_program_final_eval_config_current | program_is_active               | boolean                  | false    |                                    |
| v_org_program_final_eval_config_current | config_id                       | uuid                     | false    |                                    |
| v_org_program_final_eval_config_current | total_questions                 | integer                  | false    |                                    |
| v_org_program_final_eval_config_current | roleplay_ratio                  | numeric                  | false    |                                    |
| v_org_program_final_eval_config_current | min_global_score                | numeric                  | false    |                                    |
| v_org_program_final_eval_config_current | must_pass_units                 | ARRAY                    | false    |                                    |
| v_org_program_final_eval_config_current | questions_per_unit              | integer                  | false    |                                    |
| v_org_program_final_eval_config_current | max_attempts                    | integer                  | false    |                                    |
| v_org_program_final_eval_config_current | cooldown_hours                  | integer                  | false    |                                    |
| v_org_program_final_eval_config_current | config_created_at               | timestamp with time zone | false    |                                    |
| v_org_program_final_eval_config_history | program_id                      | uuid                     | false    |                                    |
| v_org_program_final_eval_config_history | org_id                          | uuid                     | false    |                                    |
| v_org_program_final_eval_config_history | program_local_id                | uuid                     | false    |                                    |
| v_org_program_final_eval_config_history | program_name                    | text                     | false    |                                    |
| v_org_program_final_eval_config_history | program_is_active               | boolean                  | false    |                                    |
| v_org_program_final_eval_config_history | config_id                       | uuid                     | false    |                                    |
| v_org_program_final_eval_config_history | total_questions                 | integer                  | false    |                                    |
| v_org_program_final_eval_config_history | roleplay_ratio                  | numeric                  | false    |                                    |
| v_org_program_final_eval_config_history | min_global_score                | numeric                  | false    |                                    |
| v_org_program_final_eval_config_history | must_pass_units                 | ARRAY                    | false    |                                    |
| v_org_program_final_eval_config_history | questions_per_unit              | integer                  | false    |                                    |
| v_org_program_final_eval_config_history | max_attempts                    | integer                  | false    |                                    |
| v_org_program_final_eval_config_history | cooldown_hours                  | integer                  | false    |                                    |
| v_org_program_final_eval_config_history | config_created_at               | timestamp with time zone | false    |                                    |
| v_org_program_knowledge_gaps_summary    | program_id                      | uuid                     | false    |                                    |
| v_org_program_knowledge_gaps_summary    | program_name                    | text                     | false    |                                    |
| v_org_program_knowledge_gaps_summary    | total_units                     | integer                  | false    |                                    |
| v_org_program_knowledge_gaps_summary    | units_missing_mapping           | integer                  | false    |                                    |
| v_org_program_knowledge_gaps_summary    | pct_units_missing_mapping       | numeric                  | false    |                                    |
| v_org_program_knowledge_gaps_summary    | total_knowledge_mappings        | integer                  | false    |                                    |
| v_org_program_unit_knowledge_coverage   | program_id                      | uuid                     | false    |                                    |
| v_org_program_unit_knowledge_coverage   | program_name                    | text                     | false    |                                    |
| v_org_program_unit_knowledge_coverage   | unit_id                         | uuid                     | false    |                                    |
| v_org_program_unit_knowledge_coverage   | unit_order                      | integer                  | false    |                                    |
| v_org_program_unit_knowledge_coverage   | unit_title                      | text                     | false    |                                    |
| v_org_program_unit_knowledge_coverage   | total_knowledge_count           | bigint                   | false    |                                    |
| v_org_program_unit_knowledge_coverage   | org_level_knowledge_count       | bigint                   | false    |                                    |
| v_org_program_unit_knowledge_coverage   | local_level_knowledge_count     | bigint                   | false    |                                    |
| v_org_program_unit_knowledge_coverage   | has_any_mapping                 | boolean                  | false    |                                    |
| v_org_program_unit_knowledge_coverage   | is_missing_mapping              | boolean                  | false    |                                    |
| v_org_recommended_actions_30d           | org_id                          | uuid                     | false    |                                    |
| v_org_recommended_actions_30d           | action_key                      | text                     | false    |                                    |
| v_org_recommended_actions_30d           | priority                        | bigint                   | false    |                                    |
| v_org_recommended_actions_30d           | title                           | text                     | false    |                                    |
| v_org_recommended_actions_30d           | reason                          | text                     | false    |                                    |
| v_org_recommended_actions_30d           | evidence                        | jsonb                    | false    |                                    |
| v_org_recommended_actions_30d           | cta_label                       | text                     | false    |                                    |
| v_org_recommended_actions_30d           | cta_href                        | text                     | false    |                                    |
| v_org_recommended_actions_30d           | created_at                      | timestamp with time zone | false    |                                    |
| v_org_top_gaps_30d                      | org_id                          | uuid                     | false    |                                    |
| v_org_top_gaps_30d                      | gap_key                         | text                     | false    |                                    |
| v_org_top_gaps_30d                      | unit_order                      | integer                  | false    |                                    |
| v_org_top_gaps_30d                      | title                           | text                     | false    |                                    |
| v_org_top_gaps_30d                      | learners_affected_count         | bigint                   | false    |                                    |
| v_org_top_gaps_30d                      | percent_learners_affected       | numeric                  | false    |                                    |
| v_org_top_gaps_30d                      | total_fail_events               | bigint                   | false    |                                    |
| v_org_top_gaps_30d                      | window_days                     | integer                  | false    |                                    |
| v_org_unit_coverage_30d                 | org_id                          | uuid                     | false    |                                    |
| v_org_unit_coverage_30d                 | local_id                        | uuid                     | false    |                                    |
| v_org_unit_coverage_30d                 | local_name                      | text                     | false    |                                    |
| v_org_unit_coverage_30d                 | program_id                      | uuid                     | false    |                                    |
| v_org_unit_coverage_30d                 | unit_order                      | integer                  | false    |                                    |
| v_org_unit_coverage_30d                 | coverage_percent                | numeric                  | false    |                                    |
| v_org_unit_coverage_30d                 | learners_active_count           | bigint                   | false    |                                    |
| v_org_unit_coverage_30d                 | learners_with_evidence_count    | bigint                   | false    |                                    |
| v_org_unit_coverage_30d                 | last_activity_at                | timestamp with time zone | false    |                                    |
| v_org_unit_knowledge_active             | org_id                          | uuid                     | false    |                                    |
| v_org_unit_knowledge_active             | program_id                      | uuid                     | false    |                                    |
| v_org_unit_knowledge_active             | program_name                    | text                     | false    |                                    |
| v_org_unit_knowledge_active             | unit_id                         | uuid                     | false    |                                    |
| v_org_unit_knowledge_active             | unit_order                      | integer                  | false    |                                    |
| v_org_unit_knowledge_active             | unit_title                      | text                     | false    |                                    |
| v_org_unit_knowledge_active             | knowledge_id                    | uuid                     | false    |                                    |
| v_org_unit_knowledge_active             | knowledge_title                 | text                     | false    |                                    |
| v_org_unit_knowledge_active             | knowledge_scope                 | text                     | false    |                                    |
| v_org_unit_knowledge_active             | knowledge_created_at            | timestamp with time zone | false    |                                    |
| v_org_unit_knowledge_list               | program_id                      | uuid                     | false    |                                    |
| v_org_unit_knowledge_list               | program_name                    | text                     | false    |                                    |
| v_org_unit_knowledge_list               | unit_id                         | uuid                     | false    |                                    |
| v_org_unit_knowledge_list               | unit_order                      | integer                  | false    |                                    |
| v_org_unit_knowledge_list               | knowledge_id                    | uuid                     | false    |                                    |
| v_org_unit_knowledge_list               | knowledge_title                 | text                     | false    |                                    |
| v_org_unit_knowledge_list               | knowledge_scope                 | text                     | false    |                                    |
| v_org_unit_knowledge_list               | knowledge_created_at            | timestamp with time zone | false    |                                    |
| v_referente_conversation_summary        | conversation_id                 | uuid                     | false    |                                    |
| v_referente_conversation_summary        | learner_id                      | uuid                     | false    |                                    |
| v_referente_conversation_summary        | full_name                       | text                     | false    |                                    |
| v_referente_conversation_summary        | unit_order                      | integer                  | false    |                                    |
| v_referente_conversation_summary        | last_message_at                 | timestamp with time zone | false    |                                    |
| v_referente_conversation_summary        | total_messages                  | integer                  | false    |                                    |
| v_referente_learners                    | learner_id                      | uuid                     | false    |                                    |
| v_referente_learners                    | full_name                       | text                     | false    |                                    |
| v_referente_learners                    | status                          | USER-DEFINED             | false    |                                    |
| v_referente_learners                    | progress_percent                | numeric                  | false    |                                    |
| v_referente_learners                    | current_unit_order              | integer                  | false    |                                    |
| v_referente_learners                    | updated_at                      | timestamp with time zone | false    |                                    |
| v_referente_practice_summary            | learner_id                      | uuid                     | false    |                                    |
| v_referente_practice_summary            | attempt_id                      | uuid                     | false    |                                    |
| v_referente_practice_summary            | scenario_title                  | text                     | false    |                                    |
| v_referente_practice_summary            | score                           | numeric                  | false    |                                    |
| v_referente_practice_summary            | verdict                         | text                     | false    |                                    |
| v_referente_practice_summary            | created_at                      | timestamp with time zone | false    |                                    |
| v_review_queue                          | learner_id                      | uuid                     | false    |                                    |
| v_review_queue                          | full_name                       | text                     | false    |                                    |
| v_review_queue                          | local_id                        | uuid                     | false    |                                    |
| v_review_queue                          | status                          | USER-DEFINED             | false    |                                    |
| v_review_queue                          | progress_percent                | numeric                  | false    |                                    |
| v_review_queue                          | last_activity_at                | timestamp with time zone | false    |                                    |
| v_review_queue                          | has_doubt_signals               | boolean                  | false    |                                    |
| v_review_queue                          | has_failed_practice             | boolean                  | false    |                                    |

## RLS + Policies

### alert_events

- RLS: enabled

| policy_name                                                                                                                                                                                                                                                                                                      | command | using                                                                                                                                                                                                              | with_check |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------- |
| alert_events_insert_aprendiz_final_evaluation                                                                                                                                                                                                                                                                    | INSERT  | (("current_role"() = 'aprendiz'::app_role) AND (alert_type = 'final_evaluation_submitted'::alert_type) AND (learner_id = auth.uid()) AND (source_table = 'final_evaluation_attempts'::text) AND (EXISTS ( SELECT 1 |            |
| FROM ((final_evaluation_attempts a                                                                                                                                                                                                                                                                               |         |                                                                                                                                                                                                                    |            |
| JOIN learner_trainings lt ON ((lt.learner_id = a.learner_id)))                                                                                                                                                                                                                                                   |         |                                                                                                                                                                                                                    |            |
| JOIN locals l ON ((l.id = lt.local_id)))                                                                                                                                                                                                                                                                         |         |                                                                                                                                                                                                                    |            |
| WHERE ((a.id = alert_events.source_id) AND (a.learner_id = auth.uid()) AND (alert_events.local_id = lt.local_id) AND (alert_events.org_id = l.org_id)))))                                                                                                                                                        |         |                                                                                                                                                                                                                    |            |
| alert_events_insert_reviewer                                                                                                                                                                                                                                                                                     | INSERT  | (("current_role"() = ANY (ARRAY['superadmin'::app_role, 'admin_org'::app_role, 'referente'::app_role])) AND (("current_role"() = 'superadmin'::app_role) OR (EXISTS ( SELECT 1                                     |            |
| FROM (learner_trainings lt                                                                                                                                                                                                                                                                                       |         |                                                                                                                                                                                                                    |            |
| JOIN locals l ON ((l.id = lt.local_id)))                                                                                                                                                                                                                                                                         |         |                                                                                                                                                                                                                    |            |
| WHERE ((lt.learner_id = alert_events.learner_id) AND (alert_events.local_id = lt.local_id) AND (alert_events.org_id = l.org_id) AND ((("current_role"() = 'admin_org'::app_role) AND (l.org_id = current_org_id())) OR (("current_role"() = 'referente'::app_role) AND (lt.local_id = current_local_id())))))))) |         |                                                                                                                                                                                                                    |            |
| alert_events_select_admin_org                                                                                                                                                                                                                                                                                    | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id()))                                                                                                                                       |            |
| alert_events_select_aprendiz                                                                                                                                                                                                                                                                                     | SELECT  | (("current_role"() = 'aprendiz'::app_role) AND (learner_id = auth.uid()))                                                                                                                                          |            |
| alert_events_select_referente                                                                                                                                                                                                                                                                                    | SELECT  | (("current_role"() = 'referente'::app_role) AND (local_id = current_local_id()))                                                                                                                                   |            |
| alert_events_select_superadmin                                                                                                                                                                                                                                                                                   | SELECT  | ("current_role"() = 'superadmin'::app_role)                                                                                                                                                                        |            |

### bot_message_evaluations

- RLS: enabled

| policy_name                                                                            | command | using              | with_check |
| -------------------------------------------------------------------------------------- | ------- | ------------------ | ---------- |
| bot_message_evaluations_insert_learner                                                 | INSERT  | (EXISTS ( SELECT 1 |            |
| FROM (conversation_messages cm                                                         |         |                    |            |
| JOIN conversations c ON ((c.id = cm.conversation_id)))                                 |         |                    |            |
| WHERE ((cm.id = bot_message_evaluations.message_id) AND (c.learner_id = auth.uid())))) |         |                    |            |
| bot_message_evaluations_select_visible                                                 | SELECT  | (EXISTS ( SELECT 1 |            |
| FROM (conversation_messages cm                                                         |         |                    |            |
| JOIN conversations c ON ((c.id = cm.conversation_id)))                                 |         |                    |            |
| WHERE (cm.id = bot_message_evaluations.message_id)))                                   |         |                    |            |

### conversation_messages

- RLS: enabled

| policy_name                                                                              | command | using              | with_check |
| ---------------------------------------------------------------------------------------- | ------- | ------------------ | ---------- |
| conversation_messages_insert_learner                                                     | INSERT  | (EXISTS ( SELECT 1 |            |
| FROM conversations c                                                                     |         |                    |            |
| WHERE ((c.id = conversation_messages.conversation_id) AND (c.learner_id = auth.uid())))) |         |                    |            |
| conversation_messages_select_visible                                                     | SELECT  | (EXISTS ( SELECT 1 |            |
| FROM conversations c                                                                     |         |                    |            |
| WHERE (c.id = conversation_messages.conversation_id)))                                   |         |                    |            |

### conversations

- RLS: enabled

| policy_name                                                                                                                                                                              | command | using                                                                                           | with_check |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ----------------------------------------------------------------------------------------------- | ---------- |
| conversations_insert_learner                                                                                                                                                             | INSERT  | (("current_role"() = 'aprendiz'::app_role) AND (learner_id = auth.uid()) AND (EXISTS ( SELECT 1 |            |
| FROM learner_trainings lt                                                                                                                                                                |         |                                                                                                 |            |
| WHERE ((lt.learner_id = auth.uid()) AND (lt.local_id = conversations.local_id) AND (lt.program_id = conversations.program_id) AND (lt.current_unit_order = conversations.unit_order))))) |         |                                                                                                 |            |
| conversations_select_admin_org                                                                                                                                                           | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1                              |            |
| FROM locals l                                                                                                                                                                            |         |                                                                                                 |            |
| WHERE ((l.id = conversations.local_id) AND (l.org_id = current_org_id())))))                                                                                                             |         |                                                                                                 |            |
| conversations_select_aprendiz                                                                                                                                                            | SELECT  | (("current_role"() = 'aprendiz'::app_role) AND (learner_id = auth.uid()))                       |            |
| conversations_select_referente                                                                                                                                                           | SELECT  | (("current_role"() = 'referente'::app_role) AND (local_id = current_local_id()))                |            |
| conversations_select_superadmin                                                                                                                                                          | SELECT  | ("current_role"() = 'superadmin'::app_role)                                                     |            |

### final_evaluation_answers

- RLS: enabled

| policy_name                                                                                                                                                                                                 | command | using              | with_check |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ------------------ | ---------- |
| final_evaluation_answers_insert_learner                                                                                                                                                                     | INSERT  | (EXISTS ( SELECT 1 |            |
| FROM (final_evaluation_questions q                                                                                                                                                                          |         |                    |            |
| JOIN final_evaluation_attempts a ON ((a.id = q.attempt_id)))                                                                                                                                                |         |                    |            |
| WHERE ((q.id = final_evaluation_answers.question_id) AND (a.learner_id = auth.uid()))))                                                                                                                     |         |                    |            |
| final_evaluation_answers_select_visible                                                                                                                                                                     | SELECT  | (EXISTS ( SELECT 1 |            |
| FROM (final_evaluation_questions q                                                                                                                                                                          |         |                    |            |
| JOIN final_evaluation_attempts a ON ((a.id = q.attempt_id)))                                                                                                                                                |         |                    |            |
| WHERE ((q.id = final_evaluation_answers.question_id) AND ((("current_role"() = 'aprendiz'::app_role) AND (a.learner_id = auth.uid())) OR (("current_role"() = 'referente'::app_role) AND (EXISTS ( SELECT 1 |         |                    |            |
| FROM learner_trainings lt                                                                                                                                                                                   |         |                    |            |
| WHERE ((lt.learner_id = a.learner_id) AND (lt.program_id = a.program_id) AND (lt.local_id = current_local_id()))))) OR (("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1                   |         |                    |            |
| FROM (learner_trainings lt                                                                                                                                                                                  |         |                    |            |
| JOIN locals l ON ((l.id = lt.local_id)))                                                                                                                                                                    |         |                    |            |
| WHERE ((lt.learner_id = a.learner_id) AND (lt.program_id = a.program_id) AND (l.org_id = current_org_id()))))) OR ("current_role"() = 'superadmin'::app_role)))))                                           |         |                    |            |

### final_evaluation_attempts

- RLS: enabled

| policy_name                                                                                              | command | using                                                                     | with_check                                                                |
| -------------------------------------------------------------------------------------------------------- | ------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| final_evaluation_attempts_insert_learner                                                                 | INSERT  | (("current_role"() = 'aprendiz'::app_role) AND (learner_id = auth.uid())) |                                                                           |
| final_evaluation_attempts_select_admin_org                                                               | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1        |                                                                           |
| FROM (learner_trainings lt                                                                               |         |                                                                           |                                                                           |
| JOIN locals l ON ((l.id = lt.local_id)))                                                                 |         |                                                                           |                                                                           |
| WHERE ((lt.learner_id = final_evaluation_attempts.learner_id) AND (l.org_id = current_org_id())))))      |         |                                                                           |                                                                           |
| final_evaluation_attempts_select_aprendiz                                                                | SELECT  | (("current_role"() = 'aprendiz'::app_role) AND (learner_id = auth.uid())) |                                                                           |
| final_evaluation_attempts_select_referente                                                               | SELECT  | (("current_role"() = 'referente'::app_role) AND (EXISTS ( SELECT 1        |                                                                           |
| FROM learner_trainings lt                                                                                |         |                                                                           |                                                                           |
| WHERE ((lt.learner_id = final_evaluation_attempts.learner_id) AND (lt.local_id = current_local_id()))))) |         |                                                                           |                                                                           |
| final_evaluation_attempts_select_superadmin                                                              | SELECT  | ("current_role"() = 'superadmin'::app_role)                               |                                                                           |
| final_evaluation_attempts_update_learner                                                                 | UPDATE  | (("current_role"() = 'aprendiz'::app_role) AND (learner_id = auth.uid())) | (("current_role"() = 'aprendiz'::app_role) AND (learner_id = auth.uid())) |

### final_evaluation_configs

- RLS: enabled

| policy_name                                                                                       | command | using                                                                                                  | with_check                                                                      |
| ------------------------------------------------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| final_evaluation_configs_insert_admin                                                             | INSERT  | ("current_role"() = ANY (ARRAY['superadmin'::app_role, 'admin_org'::app_role]))                        |                                                                                 |
| final_evaluation_configs_select_admin                                                             | SELECT  | ("current_role"() = ANY (ARRAY['superadmin'::app_role, 'admin_org'::app_role, 'referente'::app_role])) |                                                                                 |
| final_evaluation_configs_select_aprendiz                                                          | SELECT  | (("current_role"() = 'aprendiz'::app_role) AND (EXISTS ( SELECT 1                                      |                                                                                 |
| FROM learner_trainings lt                                                                         |         |                                                                                                        |                                                                                 |
| WHERE ((lt.learner_id = auth.uid()) AND (lt.program_id = final_evaluation_configs.program_id))))) |         |                                                                                                        |                                                                                 |
| final_evaluation_configs_update_admin                                                             | UPDATE  | ("current_role"() = ANY (ARRAY['superadmin'::app_role, 'admin_org'::app_role]))                        | ("current_role"() = ANY (ARRAY['superadmin'::app_role, 'admin_org'::app_role])) |

### final_evaluation_evaluations

- RLS: enabled

| policy_name                                                                                                                                                                                                     | command | using              | with_check |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ------------------ | ---------- |
| final_evaluation_evaluations_insert_learner                                                                                                                                                                     | INSERT  | (EXISTS ( SELECT 1 |            |
| FROM ((final_evaluation_answers ans                                                                                                                                                                             |         |                    |            |
| JOIN final_evaluation_questions q ON ((q.id = ans.question_id)))                                                                                                                                                |         |                    |            |
| JOIN final_evaluation_attempts a ON ((a.id = q.attempt_id)))                                                                                                                                                    |         |                    |            |
| WHERE ((ans.id = final_evaluation_evaluations.answer_id) AND (a.learner_id = auth.uid()))))                                                                                                                     |         |                    |            |
| final_evaluation_evaluations_select_visible                                                                                                                                                                     | SELECT  | (EXISTS ( SELECT 1 |            |
| FROM ((final_evaluation_answers ans                                                                                                                                                                             |         |                    |            |
| JOIN final_evaluation_questions q ON ((q.id = ans.question_id)))                                                                                                                                                |         |                    |            |
| JOIN final_evaluation_attempts a ON ((a.id = q.attempt_id)))                                                                                                                                                    |         |                    |            |
| WHERE ((ans.id = final_evaluation_evaluations.answer_id) AND ((("current_role"() = 'aprendiz'::app_role) AND (a.learner_id = auth.uid())) OR (("current_role"() = 'referente'::app_role) AND (EXISTS ( SELECT 1 |         |                    |            |
| FROM learner_trainings lt                                                                                                                                                                                       |         |                    |            |
| WHERE ((lt.learner_id = a.learner_id) AND (lt.program_id = a.program_id) AND (lt.local_id = current_local_id()))))) OR (("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1                       |         |                    |            |
| FROM (learner_trainings lt                                                                                                                                                                                      |         |                    |            |
| JOIN locals l ON ((l.id = lt.local_id)))                                                                                                                                                                        |         |                    |            |
| WHERE ((lt.learner_id = a.learner_id) AND (lt.program_id = a.program_id) AND (l.org_id = current_org_id()))))) OR ("current_role"() = 'superadmin'::app_role)))))                                               |         |                    |            |

### final_evaluation_questions

- RLS: enabled

| policy_name                                                                                                                                                                                                  | command | using              | with_check |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------- | ------------------ | ---------- |
| final_evaluation_questions_insert_learner                                                                                                                                                                    | INSERT  | (EXISTS ( SELECT 1 |            |
| FROM final_evaluation_attempts a                                                                                                                                                                             |         |                    |            |
| WHERE ((a.id = final_evaluation_questions.attempt_id) AND (a.learner_id = auth.uid()))))                                                                                                                     |         |                    |            |
| final_evaluation_questions_select_visible                                                                                                                                                                    | SELECT  | (EXISTS ( SELECT 1 |            |
| FROM final_evaluation_attempts a                                                                                                                                                                             |         |                    |            |
| WHERE ((a.id = final_evaluation_questions.attempt_id) AND ((("current_role"() = 'aprendiz'::app_role) AND (a.learner_id = auth.uid())) OR (("current_role"() = 'referente'::app_role) AND (EXISTS ( SELECT 1 |         |                    |            |
| FROM learner_trainings lt                                                                                                                                                                                    |         |                    |            |
| WHERE ((lt.learner_id = a.learner_id) AND (lt.program_id = a.program_id) AND (lt.local_id = current_local_id()))))) OR (("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1                    |         |                    |            |
| FROM (learner_trainings lt                                                                                                                                                                                   |         |                    |            |
| JOIN locals l ON ((l.id = lt.local_id)))                                                                                                                                                                     |         |                    |            |
| WHERE ((lt.learner_id = a.learner_id) AND (lt.program_id = a.program_id) AND (l.org_id = current_org_id()))))) OR ("current_role"() = 'superadmin'::app_role)))))                                            |         |                    |            |

### knowledge_change_events

- RLS: enabled

| policy_name                               | command | using                                                                                                                         | with_check |
| ----------------------------------------- | ------- | ----------------------------------------------------------------------------------------------------------------------------- | ---------- |
| knowledge_change_events_insert_admin_org  | INSERT  | (("current_role"() = 'superadmin'::app_role) OR (("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id()))) |            |
| knowledge_change_events_select_admin_org  | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id()))                                                  |            |
| knowledge_change_events_select_superadmin | SELECT  | ("current_role"() = 'superadmin'::app_role)                                                                                   |            |

### knowledge_items

- RLS: enabled

| policy_name                                                                      | command | using                                                                                                                                                                                               | with_check                                                                                                                                                                |
| -------------------------------------------------------------------------------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| knowledge_items_insert_admin_org                                                 | INSERT  | (("current_role"() = 'superadmin'::app_role) OR (("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id()) AND ((local_id IS NULL) OR (EXISTS ( SELECT 1                           |                                                                                                                                                                           |
| FROM locals l                                                                    |         |                                                                                                                                                                                                     |                                                                                                                                                                           |
| WHERE ((l.id = knowledge_items.local_id) AND (l.org_id = current_org_id()))))))) |         |                                                                                                                                                                                                     |                                                                                                                                                                           |
| knowledge_items_select_admin_org                                                 | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id()))                                                                                                                        |                                                                                                                                                                           |
| knowledge_items_select_local_roles                                               | SELECT  | (("current_role"() = ANY (ARRAY['referente'::app_role, 'aprendiz'::app_role])) AND (org_id = current_org_id()) AND ((local_id IS NULL) OR (local_id = current_local_id())) AND (is_enabled = true)) |                                                                                                                                                                           |
| knowledge_items_select_superadmin                                                | SELECT  | ("current_role"() = 'superadmin'::app_role)                                                                                                                                                         |                                                                                                                                                                           |
| knowledge_items_update_admin_org                                                 | UPDATE  | (("current_role"() = 'superadmin'::app_role) OR (("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id())))                                                                       | (("current_role"() = 'superadmin'::app_role) OR (("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id()) AND ((local_id IS NULL) OR (EXISTS ( SELECT 1 |
| FROM locals l                                                                    |         |                                                                                                                                                                                                     |                                                                                                                                                                           |
| WHERE ((l.id = knowledge_items.local_id) AND (l.org_id = current_org_id()))))))) |         |                                                                                                                                                                                                     |                                                                                                                                                                           |

### learner_future_questions

- RLS: enabled

| policy_name                                                                             | command | using                                                                            | with_check |
| --------------------------------------------------------------------------------------- | ------- | -------------------------------------------------------------------------------- | ---------- |
| learner_future_questions_select_admin_org                                               | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1               |            |
| FROM locals l                                                                           |         |                                                                                  |            |
| WHERE ((l.id = learner_future_questions.local_id) AND (l.org_id = current_org_id()))))) |         |                                                                                  |            |
| learner_future_questions_select_aprendiz                                                | SELECT  | (("current_role"() = 'aprendiz'::app_role) AND (learner_id = auth.uid()))        |            |
| learner_future_questions_select_referente                                               | SELECT  | (("current_role"() = 'referente'::app_role) AND (local_id = current_local_id())) |            |
| learner_future_questions_select_superadmin                                              | SELECT  | ("current_role"() = 'superadmin'::app_role)                                      |            |

### learner_review_decisions

- RLS: enabled

| policy_name                                                                                                                                                                                                                                   | command | using                                                                                                                                                                                                         | with_check |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| learner_review_decisions_insert_reviewer                                                                                                                                                                                                      | INSERT  | ((reviewer_id = auth.uid()) AND ("current_role"() = ANY (ARRAY['superadmin'::app_role, 'admin_org'::app_role, 'referente'::app_role])) AND (("current_role"() = 'superadmin'::app_role) OR (EXISTS ( SELECT 1 |            |
| FROM (learner_trainings lt                                                                                                                                                                                                                    |         |                                                                                                                                                                                                               |            |
| JOIN locals l ON ((l.id = lt.local_id)))                                                                                                                                                                                                      |         |                                                                                                                                                                                                               |            |
| WHERE ((lt.learner_id = learner_review_decisions.learner_id) AND ((("current_role"() = 'admin_org'::app_role) AND (l.org_id = current_org_id())) OR (("current_role"() = 'referente'::app_role) AND (lt.local_id = current_local_id())))))))) |         |                                                                                                                                                                                                               |            |
| learner_review_decisions_select_admin_org                                                                                                                                                                                                     | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1                                                                                                                                            |            |
| FROM (learner_trainings lt                                                                                                                                                                                                                    |         |                                                                                                                                                                                                               |            |
| JOIN locals l ON ((l.id = lt.local_id)))                                                                                                                                                                                                      |         |                                                                                                                                                                                                               |            |
| WHERE ((lt.learner_id = learner_review_decisions.learner_id) AND (l.org_id = current_org_id())))))                                                                                                                                            |         |                                                                                                                                                                                                               |            |
| learner_review_decisions_select_aprendiz                                                                                                                                                                                                      | SELECT  | (("current_role"() = 'aprendiz'::app_role) AND (learner_id = auth.uid()))                                                                                                                                     |            |
| learner_review_decisions_select_referente                                                                                                                                                                                                     | SELECT  | (("current_role"() = 'referente'::app_role) AND (EXISTS ( SELECT 1                                                                                                                                            |            |
| FROM learner_trainings lt                                                                                                                                                                                                                     |         |                                                                                                                                                                                                               |            |
| WHERE ((lt.learner_id = learner_review_decisions.learner_id) AND (lt.local_id = current_local_id())))))                                                                                                                                       |         |                                                                                                                                                                                                               |            |
| learner_review_decisions_select_superadmin                                                                                                                                                                                                    | SELECT  | ("current_role"() = 'superadmin'::app_role)                                                                                                                                                                   |            |

### learner_review_validations_v2

- RLS: enabled

| policy_name                                                                                                                                                                                                                                        | command | using                                                                                                                                                                                                         | with_check |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| learner_review_validations_v2_insert_reviewer                                                                                                                                                                                                      | INSERT  | ((reviewer_id = auth.uid()) AND ("current_role"() = ANY (ARRAY['superadmin'::app_role, 'admin_org'::app_role, 'referente'::app_role])) AND (("current_role"() = 'superadmin'::app_role) OR (EXISTS ( SELECT 1 |            |
| FROM (learner_trainings lt                                                                                                                                                                                                                         |         |                                                                                                                                                                                                               |            |
| JOIN locals l ON ((l.id = lt.local_id)))                                                                                                                                                                                                           |         |                                                                                                                                                                                                               |            |
| WHERE ((lt.learner_id = learner_review_validations_v2.learner_id) AND ((("current_role"() = 'admin_org'::app_role) AND (l.org_id = current_org_id())) OR (("current_role"() = 'referente'::app_role) AND (lt.local_id = current_local_id())))))))) |         |                                                                                                                                                                                                               |            |
| learner_review_validations_v2_select_admin_org                                                                                                                                                                                                     | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1                                                                                                                                            |            |
| FROM (learner_trainings lt                                                                                                                                                                                                                         |         |                                                                                                                                                                                                               |            |
| JOIN locals l ON ((l.id = lt.local_id)))                                                                                                                                                                                                           |         |                                                                                                                                                                                                               |            |
| WHERE ((lt.learner_id = learner_review_validations_v2.learner_id) AND (l.org_id = current_org_id())))))                                                                                                                                            |         |                                                                                                                                                                                                               |            |
| learner_review_validations_v2_select_aprendiz                                                                                                                                                                                                      | SELECT  | (("current_role"() = 'aprendiz'::app_role) AND (learner_id = auth.uid()))                                                                                                                                     |            |
| learner_review_validations_v2_select_referente                                                                                                                                                                                                     | SELECT  | (("current_role"() = 'referente'::app_role) AND (EXISTS ( SELECT 1                                                                                                                                            |            |
| FROM learner_trainings lt                                                                                                                                                                                                                          |         |                                                                                                                                                                                                               |            |
| WHERE ((lt.learner_id = learner_review_validations_v2.learner_id) AND (lt.local_id = current_local_id())))))                                                                                                                                       |         |                                                                                                                                                                                                               |            |
| learner_review_validations_v2_select_superadmin                                                                                                                                                                                                    | SELECT  | ("current_role"() = 'superadmin'::app_role)                                                                                                                                                                   |            |

### learner_state_transitions

- RLS: enabled

| policy_name                                                                                                                                                                                                                                    | command | using                                                                                                                                                                                                           | with_check |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| learner_state_transitions_insert_learner                                                                                                                                                                                                       | INSERT  | (("current_role"() = 'aprendiz'::app_role) AND (learner_id = auth.uid()) AND (actor_user_id = auth.uid()))                                                                                                      |            |
| learner_state_transitions_insert_reviewer                                                                                                                                                                                                      | INSERT  | ((actor_user_id = auth.uid()) AND ("current_role"() = ANY (ARRAY['superadmin'::app_role, 'admin_org'::app_role, 'referente'::app_role])) AND (("current_role"() = 'superadmin'::app_role) OR (EXISTS ( SELECT 1 |            |
| FROM (learner_trainings lt                                                                                                                                                                                                                     |         |                                                                                                                                                                                                                 |            |
| JOIN locals l ON ((l.id = lt.local_id)))                                                                                                                                                                                                       |         |                                                                                                                                                                                                                 |            |
| WHERE ((lt.learner_id = learner_state_transitions.learner_id) AND ((("current_role"() = 'admin_org'::app_role) AND (l.org_id = current_org_id())) OR (("current_role"() = 'referente'::app_role) AND (lt.local_id = current_local_id())))))))) |         |                                                                                                                                                                                                                 |            |
| learner_state_transitions_select_admin_org                                                                                                                                                                                                     | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1                                                                                                                                              |            |
| FROM (learner_trainings lt                                                                                                                                                                                                                     |         |                                                                                                                                                                                                                 |            |
| JOIN locals l ON ((l.id = lt.local_id)))                                                                                                                                                                                                       |         |                                                                                                                                                                                                                 |            |
| WHERE ((lt.learner_id = learner_state_transitions.learner_id) AND (l.org_id = current_org_id())))))                                                                                                                                            |         |                                                                                                                                                                                                                 |            |
| learner_state_transitions_select_aprendiz                                                                                                                                                                                                      | SELECT  | (("current_role"() = 'aprendiz'::app_role) AND (learner_id = auth.uid()))                                                                                                                                       |            |
| learner_state_transitions_select_referente                                                                                                                                                                                                     | SELECT  | (("current_role"() = 'referente'::app_role) AND (EXISTS ( SELECT 1                                                                                                                                              |            |
| FROM learner_trainings lt                                                                                                                                                                                                                      |         |                                                                                                                                                                                                                 |            |
| WHERE ((lt.learner_id = learner_state_transitions.learner_id) AND (lt.local_id = current_local_id())))))                                                                                                                                       |         |                                                                                                                                                                                                                 |            |
| learner_state_transitions_select_superadmin                                                                                                                                                                                                    | SELECT  | ("current_role"() = 'superadmin'::app_role)                                                                                                                                                                     |            |

### learner_trainings

- RLS: enabled

| policy_name                                                                                                                                                                                                                                | command                                                                                                                                                                        | using                                                                                                                                                                          | with_check                                                                                                                                                         |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| learner_trainings_select_admin_org                                                                                                                                                                                                         | SELECT                                                                                                                                                                         | (("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1                                                                                                             |                                                                                                                                                                    |
| FROM locals l                                                                                                                                                                                                                              |                                                                                                                                                                                |                                                                                                                                                                                |                                                                                                                                                                    |
| WHERE ((l.id = learner_trainings.local_id) AND (l.org_id = current_org_id())))))                                                                                                                                                           |                                                                                                                                                                                |                                                                                                                                                                                |                                                                                                                                                                    |
| learner_trainings_select_aprendiz                                                                                                                                                                                                          | SELECT                                                                                                                                                                         | (("current_role"() = 'aprendiz'::app_role) AND (learner_id = auth.uid()))                                                                                                      |                                                                                                                                                                    |
| learner_trainings_select_referente                                                                                                                                                                                                         | SELECT                                                                                                                                                                         | (("current_role"() = 'referente'::app_role) AND (local_id = current_local_id()))                                                                                               |                                                                                                                                                                    |
| learner_trainings_select_superadmin                                                                                                                                                                                                        | SELECT                                                                                                                                                                         | ("current_role"() = 'superadmin'::app_role)                                                                                                                                    |                                                                                                                                                                    |
| learner_trainings_update_learner_final                                                                                                                                                                                                     | UPDATE                                                                                                                                                                         | (("current_role"() = 'aprendiz'::app_role) AND (learner_id = auth.uid()))                                                                                                      | (("current_role"() = 'aprendiz'::app_role) AND (learner_id = auth.uid()) AND (status = ANY (ARRAY['en_practica'::learner_status, 'en_revision'::learner_status]))) |
| learner_trainings_update_reviewer                                                                                                                                                                                                          | UPDATE                                                                                                                                                                         | (("current_role"() = ANY (ARRAY['superadmin'::app_role, 'admin_org'::app_role, 'referente'::app_role])) AND (("current_role"() = 'superadmin'::app_role) OR (EXISTS ( SELECT 1 |                                                                                                                                                                    |
| FROM locals l                                                                                                                                                                                                                              |                                                                                                                                                                                |                                                                                                                                                                                |                                                                                                                                                                    |
| WHERE ((l.id = learner_trainings.local_id) AND ((("current_role"() = 'admin_org'::app_role) AND (l.org_id = current_org_id())) OR (("current_role"() = 'referente'::app_role) AND (learner_trainings.local_id = current_local_id())))))))) | (("current_role"() = ANY (ARRAY['superadmin'::app_role, 'admin_org'::app_role, 'referente'::app_role])) AND (("current_role"() = 'superadmin'::app_role) OR (EXISTS ( SELECT 1 |                                                                                                                                                                                |                                                                                                                                                                    |
| FROM locals l                                                                                                                                                                                                                              |                                                                                                                                                                                |                                                                                                                                                                                |                                                                                                                                                                    |
| WHERE ((l.id = learner_trainings.local_id) AND ((("current_role"() = 'admin_org'::app_role) AND (l.org_id = current_org_id())) OR (("current_role"() = 'referente'::app_role) AND (learner_trainings.local_id = current_local_id())))))))) |                                                                                                                                                                                |                                                                                                                                                                                |                                                                                                                                                                    |

### local_active_program_change_events

- RLS: enabled

| policy_name                                          | command | using                                                                                                                         | with_check |
| ---------------------------------------------------- | ------- | ----------------------------------------------------------------------------------------------------------------------------- | ---------- |
| local_active_program_change_events_insert_admin_org  | INSERT  | (("current_role"() = 'superadmin'::app_role) OR (("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id()))) |            |
| local_active_program_change_events_select_admin_org  | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id()))                                                  |            |
| local_active_program_change_events_select_superadmin | SELECT  | ("current_role"() = 'superadmin'::app_role)                                                                                   |            |

### local_active_programs

- RLS: enabled

| policy_name                                                                                                                                                                                                      | command            | using                                                                                                               | with_check |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------- | ---------- |
| local_active_programs_insert_admin_org                                                                                                                                                                           | INSERT             | (EXISTS ( SELECT 1                                                                                                  |            |
| FROM (locals l                                                                                                                                                                                                   |                    |                                                                                                                     |            |
| JOIN training_programs tp ON ((tp.id = local_active_programs.program_id)))                                                                                                                                       |                    |                                                                                                                     |            |
| WHERE ((l.id = local_active_programs.local_id) AND (tp.org_id = l.org_id) AND (("current_role"() = 'superadmin'::app_role) OR (("current_role"() = 'admin_org'::app_role) AND (l.org_id = current_org_id())))))) |                    |                                                                                                                     |            |
| local_active_programs_select_admin_org                                                                                                                                                                           | SELECT             | (("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1                                                  |            |
| FROM locals l                                                                                                                                                                                                    |                    |                                                                                                                     |            |
| WHERE ((l.id = local_active_programs.local_id) AND (l.org_id = current_org_id())))))                                                                                                                             |                    |                                                                                                                     |            |
| local_active_programs_select_local_roles                                                                                                                                                                         | SELECT             | (("current_role"() = ANY (ARRAY['referente'::app_role, 'aprendiz'::app_role])) AND (local_id = current_local_id())) |            |
| local_active_programs_select_superadmin                                                                                                                                                                          | SELECT             | ("current_role"() = 'superadmin'::app_role)                                                                         |            |
| local_active_programs_update_admin_org                                                                                                                                                                           | UPDATE             | (EXISTS ( SELECT 1                                                                                                  |            |
| FROM locals l                                                                                                                                                                                                    |                    |                                                                                                                     |            |
| WHERE ((l.id = local_active_programs.local_id) AND (("current_role"() = 'superadmin'::app_role) OR (("current_role"() = 'admin_org'::app_role) AND (l.org_id = current_org_id()))))))                            | (EXISTS ( SELECT 1 |                                                                                                                     |            |
| FROM (locals l                                                                                                                                                                                                   |                    |                                                                                                                     |            |
| JOIN training_programs tp ON ((tp.id = local_active_programs.program_id)))                                                                                                                                       |                    |                                                                                                                     |            |
| WHERE ((l.id = local_active_programs.local_id) AND (tp.org_id = l.org_id) AND (("current_role"() = 'superadmin'::app_role) OR (("current_role"() = 'admin_org'::app_role) AND (l.org_id = current_org_id())))))) |                    |                                                                                                                     |            |

### locals

- RLS: enabled

| policy_name              | command | using                                                                                                         | with_check |
| ------------------------ | ------- | ------------------------------------------------------------------------------------------------------------- | ---------- |
| locals_select_admin_org  | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id()))                                  |            |
| locals_select_own        | SELECT  | (("current_role"() = ANY (ARRAY['referente'::app_role, 'aprendiz'::app_role])) AND (id = current_local_id())) |            |
| locals_select_superadmin | SELECT  | ("current_role"() = 'superadmin'::app_role)                                                                   |            |

### notification_emails

- RLS: enabled

| policy_name                                                                                                                                                                                                                              | command | using                                                                                                                                                                          | with_check |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------- |
| notification_emails_insert_reviewer                                                                                                                                                                                                      | INSERT  | (("current_role"() = ANY (ARRAY['superadmin'::app_role, 'admin_org'::app_role, 'referente'::app_role])) AND (("current_role"() = 'superadmin'::app_role) OR (EXISTS ( SELECT 1 |            |
| FROM (learner_trainings lt                                                                                                                                                                                                               |         |                                                                                                                                                                                |            |
| JOIN locals l ON ((l.id = lt.local_id)))                                                                                                                                                                                                 |         |                                                                                                                                                                                |            |
| WHERE ((lt.learner_id = notification_emails.learner_id) AND ((("current_role"() = 'admin_org'::app_role) AND (l.org_id = current_org_id())) OR (("current_role"() = 'referente'::app_role) AND (lt.local_id = current_local_id())))))))) |         |                                                                                                                                                                                |            |
| notification_emails_select_admin_org                                                                                                                                                                                                     | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1                                                                                                             |            |
| FROM (learner_trainings lt                                                                                                                                                                                                               |         |                                                                                                                                                                                |            |
| JOIN locals l ON ((l.id = lt.local_id)))                                                                                                                                                                                                 |         |                                                                                                                                                                                |            |
| WHERE ((lt.learner_id = notification_emails.learner_id) AND (l.org_id = current_org_id())))))                                                                                                                                            |         |                                                                                                                                                                                |            |
| notification_emails_select_aprendiz                                                                                                                                                                                                      | SELECT  | (("current_role"() = 'aprendiz'::app_role) AND (learner_id = auth.uid()))                                                                                                      |            |
| notification_emails_select_referente                                                                                                                                                                                                     | SELECT  | (("current_role"() = 'referente'::app_role) AND (EXISTS ( SELECT 1                                                                                                             |            |
| FROM learner_trainings lt                                                                                                                                                                                                                |         |                                                                                                                                                                                |            |
| WHERE ((lt.learner_id = notification_emails.learner_id) AND (lt.local_id = current_local_id())))))                                                                                                                                       |         |                                                                                                                                                                                |            |
| notification_emails_select_superadmin                                                                                                                                                                                                    | SELECT  | ("current_role"() = 'superadmin'::app_role)                                                                                                                                    |            |

### organizations

- RLS: enabled

| policy_name                     | command | using                                       | with_check |
| ------------------------------- | ------- | ------------------------------------------- | ---------- |
| organizations_select_own        | SELECT  | (id = current_org_id())                     |            |
| organizations_select_superadmin | SELECT  | ("current_role"() = 'superadmin'::app_role) |            |

### practice_attempt_events

- RLS: enabled

| policy_name                                                                                    | command | using                                                              | with_check |
| ---------------------------------------------------------------------------------------------- | ------- | ------------------------------------------------------------------ | ---------- |
| practice_attempt_events_insert_learner                                                         | INSERT  | (EXISTS ( SELECT 1                                                 |            |
| FROM practice_attempts pa                                                                      |         |                                                                    |            |
| WHERE ((pa.id = practice_attempt_events.attempt_id) AND (pa.learner_id = auth.uid()))))        |         |                                                                    |            |
| practice_attempt_events_select_admin_org                                                       | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1 |            |
| FROM (practice_attempts pa                                                                     |         |                                                                    |            |
| JOIN locals l ON ((l.id = pa.local_id)))                                                       |         |                                                                    |            |
| WHERE ((pa.id = practice_attempt_events.attempt_id) AND (l.org_id = current_org_id())))))      |         |                                                                    |            |
| practice_attempt_events_select_aprendiz                                                        | SELECT  | (("current_role"() = 'aprendiz'::app_role) AND (EXISTS ( SELECT 1  |            |
| FROM practice_attempts pa                                                                      |         |                                                                    |            |
| WHERE ((pa.id = practice_attempt_events.attempt_id) AND (pa.learner_id = auth.uid())))))       |         |                                                                    |            |
| practice_attempt_events_select_referente                                                       | SELECT  | (("current_role"() = 'referente'::app_role) AND (EXISTS ( SELECT 1 |            |
| FROM practice_attempts pa                                                                      |         |                                                                    |            |
| WHERE ((pa.id = practice_attempt_events.attempt_id) AND (pa.local_id = current_local_id()))))) |         |                                                                    |            |
| practice_attempt_events_select_superadmin                                                      | SELECT  | ("current_role"() = 'superadmin'::app_role)                        |            |

### practice_attempts

- RLS: enabled

| policy_name                                                                                                                                             | command | using                                                                                           | with_check |
| ------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ----------------------------------------------------------------------------------------------- | ---------- |
| practice_attempts_insert_learner                                                                                                                        | INSERT  | ((learner_id = auth.uid()) AND ("current_role"() = 'aprendiz'::app_role) AND (EXISTS ( SELECT 1 |            |
| FROM practice_scenarios ps                                                                                                                              |         |                                                                                                 |            |
| WHERE ((ps.id = practice_attempts.scenario_id) AND (ps.org_id = current_org_id()) AND ((ps.local_id IS NULL) OR (ps.local_id = current_local_id())))))) |         |                                                                                                 |            |
| practice_attempts_select_admin_org                                                                                                                      | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1                              |            |
| FROM locals l                                                                                                                                           |         |                                                                                                 |            |
| WHERE ((l.id = practice_attempts.local_id) AND (l.org_id = current_org_id())))))                                                                        |         |                                                                                                 |            |
| practice_attempts_select_aprendiz                                                                                                                       | SELECT  | (("current_role"() = 'aprendiz'::app_role) AND (learner_id = auth.uid()))                       |            |
| practice_attempts_select_referente                                                                                                                      | SELECT  | (("current_role"() = 'referente'::app_role) AND (local_id = current_local_id()))                |            |
| practice_attempts_select_superadmin                                                                                                                     | SELECT  | ("current_role"() = 'superadmin'::app_role)                                                     |            |

### practice_evaluations

- RLS: enabled

| policy_name                                                                                 | command | using                                                              | with_check |
| ------------------------------------------------------------------------------------------- | ------- | ------------------------------------------------------------------ | ---------- |
| practice_evaluations_insert_learner                                                         | INSERT  | (EXISTS ( SELECT 1                                                 |            |
| FROM practice_attempts pa                                                                   |         |                                                                    |            |
| WHERE ((pa.id = practice_evaluations.attempt_id) AND (pa.learner_id = auth.uid()))))        |         |                                                                    |            |
| practice_evaluations_select_admin_org                                                       | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1 |            |
| FROM (practice_attempts pa                                                                  |         |                                                                    |            |
| JOIN locals l ON ((l.id = pa.local_id)))                                                    |         |                                                                    |            |
| WHERE ((pa.id = practice_evaluations.attempt_id) AND (l.org_id = current_org_id())))))      |         |                                                                    |            |
| practice_evaluations_select_aprendiz                                                        | SELECT  | (("current_role"() = 'aprendiz'::app_role) AND (EXISTS ( SELECT 1  |            |
| FROM practice_attempts pa                                                                   |         |                                                                    |            |
| WHERE ((pa.id = practice_evaluations.attempt_id) AND (pa.learner_id = auth.uid())))))       |         |                                                                    |            |
| practice_evaluations_select_referente                                                       | SELECT  | (("current_role"() = 'referente'::app_role) AND (EXISTS ( SELECT 1 |            |
| FROM practice_attempts pa                                                                   |         |                                                                    |            |
| WHERE ((pa.id = practice_evaluations.attempt_id) AND (pa.local_id = current_local_id()))))) |         |                                                                    |            |
| practice_evaluations_select_superadmin                                                      | SELECT  | ("current_role"() = 'superadmin'::app_role)                        |            |

### practice_scenarios

- RLS: enabled

| policy_name                           | command | using                                                                                                                                                                       | with_check |
| ------------------------------------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| practice_scenarios_select_admin_org   | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id()))                                                                                                |            |
| practice_scenarios_select_local_roles | SELECT  | (("current_role"() = ANY (ARRAY['referente'::app_role, 'aprendiz'::app_role])) AND (org_id = current_org_id()) AND ((local_id IS NULL) OR (local_id = current_local_id()))) |            |
| practice_scenarios_select_superadmin  | SELECT  | ("current_role"() = 'superadmin'::app_role)                                                                                                                                 |            |

### profiles

- RLS: enabled

| policy_name                | command | using                                                                            | with_check             |
| -------------------------- | ------- | -------------------------------------------------------------------------------- | ---------------------- |
| profiles_select_admin_org  | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id()))     |                        |
| profiles_select_own        | SELECT  | (user_id = auth.uid())                                                           |                        |
| profiles_select_referente  | SELECT  | (("current_role"() = 'referente'::app_role) AND (local_id = current_local_id())) |                        |
| profiles_select_superadmin | SELECT  | ("current_role"() = 'superadmin'::app_role)                                      |                        |
| profiles_update_own        | UPDATE  | (user_id = auth.uid())                                                           | (user_id = auth.uid()) |

### training_programs

- RLS: enabled

| policy_name                          | command | using                                                                                                                                                                       | with_check |
| ------------------------------------ | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| training_programs_select_admin_org   | SELECT  | (("current_role"() = 'admin_org'::app_role) AND (org_id = current_org_id()))                                                                                                |            |
| training_programs_select_local_roles | SELECT  | (("current_role"() = ANY (ARRAY['referente'::app_role, 'aprendiz'::app_role])) AND (org_id = current_org_id()) AND ((local_id IS NULL) OR (local_id = current_local_id()))) |            |
| training_programs_select_superadmin  | SELECT  | ("current_role"() = 'superadmin'::app_role)                                                                                                                                 |            |

### training_units

- RLS: enabled

| policy_name                                 | command | using              | with_check |
| ------------------------------------------- | ------- | ------------------ | ---------- |
| training_units_select_visible_programs      | SELECT  | (EXISTS ( SELECT 1 |            |
| FROM training_programs tp                   |         |                    |            |
| WHERE (tp.id = training_units.program_id))) |         |                    |            |

### unit_knowledge_map

- RLS: enabled

| policy_name                                                                                              | command | using                                                                                                              | with_check |
| -------------------------------------------------------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------ | ---------- |
| unit_knowledge_map_insert_admin_org                                                                      | INSERT  | (("current_role"() = 'superadmin'::app_role) OR (("current_role"() = 'admin_org'::app_role) AND (EXISTS ( SELECT 1 |            |
| FROM (training_units tu                                                                                  |         |                                                                                                                    |            |
| JOIN training_programs tp ON ((tp.id = tu.program_id)))                                                  |         |                                                                                                                    |            |
| WHERE ((tu.id = unit_knowledge_map.unit_id) AND (tp.org_id = current_org_id())))) AND (EXISTS ( SELECT 1 |         |                                                                                                                    |            |
| FROM knowledge_items ki                                                                                  |         |                                                                                                                    |            |
| WHERE ((ki.id = unit_knowledge_map.knowledge_id) AND (ki.org_id = current_org_id()))))))                 |         |                                                                                                                    |            |
| unit_knowledge_map_select_visible                                                                        | SELECT  | (EXISTS ( SELECT 1                                                                                                 |            |
| FROM knowledge_items ki                                                                                  |         |                                                                                                                    |            |
| WHERE (ki.id = unit_knowledge_map.knowledge_id)))                                                        |         |                                                                                                                    |            |
