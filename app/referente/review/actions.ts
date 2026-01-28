'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { sendDecisionEmail } from '../../../lib/email/sendDecisionEmail';
import { getSupabaseServerClient } from '../../../lib/server/supabase';

type DecisionInput = {
  learnerId: string;
  reason: string;
};

type ValidationV2Input = {
  learnerId: string;
  decisionType: 'approve' | 'reject' | 'request_reinforcement';
  perceivedSeverity: 'low' | 'medium' | 'high';
  recommendedAction: 'none' | 'follow_up' | 'retraining';
  checklist: Record<string, unknown>;
  comment?: string | null;
};

const DECISION_TYPES_V2 = new Set([
  'approve',
  'reject',
  'request_reinforcement',
]);
const PERCEIVED_SEVERITIES = new Set(['low', 'medium', 'high']);
const RECOMMENDED_ACTIONS = new Set(['none', 'follow_up', 'retraining']);

async function getReviewerProfile() {
  const supabase = await getSupabaseServerClient();
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData?.user?.id) {
    throw new Error('Unauthenticated');
  }

  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('user_id, role, local_id, org_id, full_name')
    .eq('user_id', userData.user.id)
    .maybeSingle();

  if (profileError || !profile) {
    throw new Error('Reviewer profile not found');
  }

  if (!['superadmin', 'admin_org', 'referente'].includes(profile.role)) {
    throw new Error('Forbidden');
  }

  return {
    supabase,
    reviewerId: profile.user_id,
    reviewerName: profile.full_name ?? 'Referente',
    role: profile.role,
  };
}

async function loadLearnerTraining(
  supabase: Awaited<ReturnType<typeof getSupabaseServerClient>>,
  learnerId: string,
) {
  const { data: learnerTraining, error } = await supabase
    .from('learner_trainings')
    .select('learner_id, status, local_id, program_id')
    .eq('learner_id', learnerId)
    .maybeSingle();

  if (error || !learnerTraining) {
    throw new Error('Learner training not found');
  }

  return learnerTraining;
}

export async function submitReviewValidationV2(input: ValidationV2Input) {
  const learnerId = input.learnerId?.trim();
  if (!learnerId) {
    throw new Error('Learner id is required');
  }

  const decisionType = input.decisionType;
  const perceivedSeverity = input.perceivedSeverity;
  const recommendedAction = input.recommendedAction;

  const checklist =
    input.checklist &&
    typeof input.checklist === 'object' &&
    !Array.isArray(input.checklist)
      ? input.checklist
      : null;

  if (
    !decisionType ||
    !DECISION_TYPES_V2.has(decisionType) ||
    !perceivedSeverity ||
    !PERCEIVED_SEVERITIES.has(perceivedSeverity) ||
    !recommendedAction ||
    !RECOMMENDED_ACTIONS.has(recommendedAction) ||
    !checklist
  ) {
    throw new Error('Invalid decision input');
  }

  const comment = input.comment?.trim() || null;

  const { supabase, reviewerId, reviewerName, role } =
    await getReviewerProfile();
  const learnerTraining = await loadLearnerTraining(supabase, learnerId);

  if (learnerTraining.status !== 'en_revision') {
    throw new Error('Learner is not in review');
  }

  const { data: decisionRecord, error: decisionError } = await supabase
    .from('learner_review_validations_v2')
    .insert({
      learner_id: learnerId,
      reviewer_id: reviewerId,
      local_id: learnerTraining.local_id,
      program_id: learnerTraining.program_id,
      decision_type: decisionType,
      perceived_severity: perceivedSeverity,
      recommended_action: recommendedAction,
      checklist,
      comment,
      reviewer_name: reviewerName,
      reviewer_role: role,
    })
    .select('id')
    .maybeSingle();

  if (decisionError || !decisionRecord) {
    console.error('submitReviewValidationV2: insert failed', decisionError);
    throw new Error(
      `Failed to store validation${decisionError?.message ? `: ${decisionError.message}` : ''}`,
    );
  }

  const { data: localRow, error: localError } = await supabase
    .from('locals')
    .select('org_id')
    .eq('id', learnerTraining.local_id)
    .maybeSingle();

  if (localError || !localRow) {
    throw new Error('Failed to resolve org context');
  }

  const payload = {
    decision_type: decisionType,
    perceived_severity: perceivedSeverity,
    recommended_action: recommendedAction,
  };

  const alertTypes: Array<
    | 'review_submitted_v2'
    | 'review_rejected_v2'
    | 'review_reinforcement_requested_v2'
  > = ['review_submitted_v2'];

  if (decisionType === 'reject') {
    alertTypes.push('review_rejected_v2');
  }

  if (decisionType === 'request_reinforcement') {
    alertTypes.push('review_reinforcement_requested_v2');
  }

  const alertEvents = alertTypes.map((alertType) => ({
    alert_type: alertType,
    learner_id: learnerId,
    local_id: learnerTraining.local_id,
    org_id: localRow.org_id,
    source_table: 'learner_review_validations_v2',
    source_id: decisionRecord.id,
    payload,
  }));

  const { error: alertError } = await supabase
    .from('alert_events')
    .insert(alertEvents);

  if (alertError) {
    console.error('submitReviewValidationV2: alert insert failed', alertError);
    throw new Error(
      `Failed to emit alert events${alertError?.message ? `: ${alertError.message}` : ''}`,
    );
  }

  return { id: decisionRecord.id };
}

export async function approveLearner(input: DecisionInput) {
  const reason = input.reason?.trim();
  if (!input.learnerId || !reason) {
    throw new Error('Reason is required');
  }

  const { supabase, reviewerId, reviewerName } = await getReviewerProfile();
  const learnerTraining = await loadLearnerTraining(supabase, input.learnerId);

  const { data: decisionRecord, error: decisionError } = await supabase
    .from('learner_review_decisions')
    .insert({
      learner_id: input.learnerId,
      reviewer_id: reviewerId,
      decision: 'approved',
      reason,
      reviewer_name: reviewerName,
    })
    .select('id')
    .maybeSingle();

  if (decisionError || !decisionRecord) {
    console.error('approveLearner: insert decision failed', decisionError);
    throw new Error(
      `Failed to store decision${decisionError?.message ? `: ${decisionError.message}` : ''}`,
    );
  }

  const { error: transitionError } = await supabase
    .from('learner_state_transitions')
    .insert({
      learner_id: input.learnerId,
      from_status: learnerTraining.status,
      to_status: 'aprobado',
      reason,
      actor_user_id: reviewerId,
    });

  if (transitionError) {
    throw new Error('Failed to store state transition');
  }

  const { error: updateError } = await supabase
    .from('learner_trainings')
    .update({ status: 'aprobado' })
    .eq('learner_id', input.learnerId);

  if (updateError) {
    throw new Error('Failed to update learner status');
  }

  const emailResult = await sendDecisionEmail({
    decisionId: decisionRecord.id,
    decisionType: 'approved',
  });

  revalidatePath('/referente/review');
  revalidatePath(`/referente/review/${input.learnerId}`);

  if (emailResult.status === 'failed') {
    redirect(`/referente/review/${input.learnerId}?email=failed`);
  }

  if (emailResult.status === 'skipped') {
    redirect(`/referente/review/${input.learnerId}?email=skipped`);
  }

  redirect(`/referente/review/${input.learnerId}?email=sent`);
}

export async function requestReinforcement(input: DecisionInput) {
  const reason = input.reason?.trim();
  if (!input.learnerId || !reason) {
    throw new Error('Reason is required');
  }

  const { supabase, reviewerId, reviewerName } = await getReviewerProfile();
  const learnerTraining = await loadLearnerTraining(supabase, input.learnerId);

  const { data: decisionRecord, error: decisionError } = await supabase
    .from('learner_review_decisions')
    .insert({
      learner_id: input.learnerId,
      reviewer_id: reviewerId,
      decision: 'needs_reinforcement',
      reason,
      reviewer_name: reviewerName,
    })
    .select('id')
    .maybeSingle();

  if (decisionError || !decisionRecord) {
    console.error(
      'requestReinforcement: insert decision failed',
      decisionError,
    );
    throw new Error(
      `Failed to store decision${decisionError?.message ? `: ${decisionError.message}` : ''}`,
    );
  }

  const { error: transitionError } = await supabase
    .from('learner_state_transitions')
    .insert({
      learner_id: input.learnerId,
      from_status: learnerTraining.status,
      to_status: 'en_riesgo',
      reason,
      actor_user_id: reviewerId,
    });

  if (transitionError) {
    throw new Error('Failed to store state transition');
  }

  const { error: updateError } = await supabase
    .from('learner_trainings')
    .update({ status: 'en_riesgo' })
    .eq('learner_id', input.learnerId);

  if (updateError) {
    throw new Error('Failed to update learner status');
  }

  const emailResult = await sendDecisionEmail({
    decisionId: decisionRecord.id,
    decisionType: 'needs_reinforcement',
  });

  revalidatePath('/referente/review');
  revalidatePath(`/referente/review/${input.learnerId}`);

  if (emailResult.status === 'failed') {
    redirect(`/referente/review/${input.learnerId}?email=failed`);
  }

  if (emailResult.status === 'skipped') {
    redirect(`/referente/review/${input.learnerId}?email=skipped`);
  }

  redirect(`/referente/review/${input.learnerId}?email=sent`);
}
