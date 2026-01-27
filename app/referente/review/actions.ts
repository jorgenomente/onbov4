'use server';

import { sendDecisionEmail } from '../../../lib/email/sendDecisionEmail';
import { getSupabaseServerClient } from '../../../lib/server/supabase';

type DecisionInput = {
  learnerId: string;
  reason: string;
};

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
    .select('learner_id, status')
    .eq('learner_id', learnerId)
    .maybeSingle();

  if (error || !learnerTraining) {
    throw new Error('Learner training not found');
  }

  return learnerTraining;
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

  if (emailResult.status === 'failed') {
    return { success: true, email: 'failed', emailError: emailResult.error };
  }

  if (emailResult.status === 'skipped') {
    return { success: true, email: 'skipped' };
  }

  return { success: true, email: 'sent' };
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

  if (emailResult.status === 'failed') {
    return { success: true, email: 'failed', emailError: emailResult.error };
  }

  if (emailResult.status === 'skipped') {
    return { success: true, email: 'skipped' };
  }

  return { success: true, email: 'sent' };
}
