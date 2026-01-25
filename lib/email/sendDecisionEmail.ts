import 'server-only';

import { getSupabaseServerClient } from '../server/supabase';
import { sendEmail } from './resend';
import { decisionApprovedTemplate } from './templates/decisionApproved';
import { decisionNeedsReinforcementTemplate } from './templates/decisionNeedsReinforcement';

type DecisionType = 'approved' | 'needs_reinforcement';

type DecisionEmailResult =
  | { status: 'sent'; messageId?: string | null }
  | { status: 'skipped' }
  | { status: 'failed'; error: string };

function mapDecisionToEmailType(decisionType: DecisionType) {
  return decisionType === 'approved'
    ? 'decision_approved'
    : 'decision_needs_reinforcement';
}

export async function sendDecisionEmail(params: {
  decisionId: string;
  decisionType: DecisionType;
}): Promise<DecisionEmailResult> {
  const supabase = await getSupabaseServerClient();
  const emailType = mapDecisionToEmailType(params.decisionType);

  const { data: existing, error: existingError } = await supabase
    .from('notification_emails')
    .select('id, status')
    .eq('decision_id', params.decisionId)
    .eq('email_type', emailType)
    .maybeSingle();

  if (existingError) {
    return { status: 'failed', error: 'Failed to check email log' };
  }

  if (existing) {
    return { status: 'skipped' };
  }

  const { data: decision, error: decisionError } = await supabase
    .from('learner_review_decisions')
    .select('id, learner_id, reviewer_id, decision, reason')
    .eq('id', params.decisionId)
    .maybeSingle();

  if (decisionError || !decision) {
    return { status: 'failed', error: 'Decision not found' };
  }

  const { data: learnerProfile, error: profileError } = await supabase
    .from('profiles')
    .select('user_id, full_name, local_id, org_id')
    .eq('user_id', decision.learner_id)
    .maybeSingle();

  if (profileError || !learnerProfile) {
    return { status: 'failed', error: 'Learner profile not found' };
  }

  const { data: emailData, error: emailError } = await supabase.rpc(
    'get_user_email',
    { target_user_id: decision.learner_id },
  );

  if (emailError || !emailData) {
    return { status: 'failed', error: 'Learner email not available' };
  }

  const toEmail = String(emailData);

  const template =
    params.decisionType === 'approved'
      ? decisionApprovedTemplate({
          learnerName: learnerProfile.full_name,
          reason: decision.reason,
        })
      : decisionNeedsReinforcementTemplate({
          learnerName: learnerProfile.full_name,
          reason: decision.reason,
        });

  let messageId: string | null = null;
  try {
    const response = await sendEmail({
      to: toEmail,
      subject: template.subject,
      html: template.html,
    });
    messageId = response?.data?.id ?? null;
  } catch (error) {
    const errorMessage =
      error instanceof Error ? error.message : 'Email send failed';

    await supabase.from('notification_emails').insert({
      org_id: learnerProfile.org_id,
      local_id: learnerProfile.local_id,
      learner_id: decision.learner_id,
      decision_id: decision.id,
      email_type: emailType,
      to_email: toEmail,
      subject: template.subject,
      provider: 'resend',
      provider_message_id: null,
      status: 'failed',
      error: errorMessage,
    });

    return { status: 'failed', error: errorMessage };
  }

  await supabase.from('notification_emails').insert({
    org_id: learnerProfile.org_id,
    local_id: learnerProfile.local_id,
    learner_id: decision.learner_id,
    decision_id: decision.id,
    email_type: emailType,
    to_email: toEmail,
    subject: template.subject,
    provider: 'resend',
    provider_message_id: messageId,
    status: 'sent',
    error: null,
  });

  return { status: 'sent', messageId };
}
