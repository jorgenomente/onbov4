'use server';

import { getSupabaseServerClient } from '../../../lib/server/supabase';
import {
  canStartFinalEvaluation,
  finalizeAttempt,
  startFinalEvaluation,
  submitFinalAnswer,
} from '../../../lib/ai/final-evaluation-engine';

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

  return startFinalEvaluation(userData.user.id);
}

export async function submitFinalAnswerAction(input: {
  attemptId: string;
  questionId: string;
  text: string;
}) {
  const answerText = input.text?.trim();
  if (!answerText) {
    throw new Error('Answer is required');
  }

  await submitFinalAnswer({
    attemptId: input.attemptId,
    questionId: input.questionId,
    learnerAnswer: answerText,
  });

  const supabase = await getSupabaseServerClient();

  const { data: questions, error: questionsError } = await supabase
    .from('final_evaluation_questions')
    .select('id')
    .eq('attempt_id', input.attemptId);

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
    return finalizeAttempt(input.attemptId);
  }

  return { status: 'in_progress' };
}
