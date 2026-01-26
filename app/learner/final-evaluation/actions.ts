'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { getSupabaseServerClient } from '../../../lib/server/supabase';
import {
  canStartFinalEvaluation,
  finalizeAttempt,
  startFinalEvaluation,
  submitFinalAnswer,
} from '../../../lib/ai/final-evaluation-engine';

async function getActiveAttemptId(
  supabase: Awaited<ReturnType<typeof getSupabaseServerClient>>,
) {
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData?.user?.id) {
    throw new Error('Unauthenticated');
  }

  const { data: attempt, error: attemptError } = await supabase
    .from('final_evaluation_attempts')
    .select('id')
    .eq('learner_id', userData.user.id)
    .eq('status', 'in_progress')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (attemptError || !attempt) {
    throw new Error('No active final evaluation attempt');
  }

  return attempt.id;
}

export async function startFinalEvaluationAction() {
  const supabase = await getSupabaseServerClient();
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData?.user?.id) {
    throw new Error('Unauthenticated');
  }

  const allowed = await canStartFinalEvaluation(userData.user.id);
  if (!allowed.allowed) {
    throw new Error(allowed.reason);
  }

  await startFinalEvaluation(userData.user.id);
  revalidatePath('/learner/final-evaluation');
  redirect('/learner/final-evaluation');
}

export async function submitFinalAnswerAction(input: {
  questionId: string;
  text: string;
}) {
  const answerText = input.text?.trim();
  if (!answerText) {
    throw new Error('Answer is required');
  }

  const supabase = await getSupabaseServerClient();
  const activeAttemptId = await getActiveAttemptId(supabase);
  if (process.env.NODE_ENV !== 'production') {
    console.info('final-evaluation attempt resolve', {
      derivedAttemptId: activeAttemptId,
    });
  }

  await submitFinalAnswer({
    supabase,
    attemptId: activeAttemptId,
    questionId: input.questionId,
    learnerAnswer: answerText,
  });

  const { data: questions, error: questionsError } = await supabase
    .from('final_evaluation_questions')
    .select('id')
    .eq('attempt_id', activeAttemptId);

  if (questionsError || !questions) {
    throw new Error('Failed to check remaining questions');
  }

  const { data: answers, error: answersError } = await supabase
    .from('final_evaluation_answers')
    .select('question_id')
    .in(
      'question_id',
      questions.map((question) => question.id),
    );

  if (answersError) {
    throw new Error('Failed to check remaining questions');
  }

  const answeredIds = new Set(
    (answers ?? []).map((answer) => answer.question_id),
  );
  const remaining = questions.filter(
    (question) => !answeredIds.has(question.id),
  );

  if (remaining.length === 0) {
    await finalizeAttempt(activeAttemptId);
    revalidatePath('/learner/final-evaluation');
    redirect('/learner/final-evaluation');
  }

  revalidatePath('/learner/final-evaluation');
  redirect('/learner/final-evaluation');
}
