import 'server-only';

import { getSupabaseServerClient } from '../server/supabase';
import { getKnowledgeForContext } from './context-builder';
import { detectDoubtSignals } from './practice-evaluator';
import { generateReply } from './provider';

type FinalConfig = {
  id: string;
  program_id: string;
  total_questions: number;
  roleplay_ratio: number;
  min_global_score: number;
  must_pass_units: number[];
  questions_per_unit: number;
  max_attempts: number;
  cooldown_hours: number;
};

type FinalQuestion = {
  id: string;
  unit_order: number;
  question_type: 'direct' | 'roleplay';
  prompt: string;
};

function parseEvaluationJson(raw: string) {
  const parsed = JSON.parse(raw) as {
    score: number;
    verdict: 'pass' | 'partial' | 'fail';
    strengths: string[];
    gaps: string[];
    feedback: string;
    doubt_signals: string[];
  };

  if (
    typeof parsed.score !== 'number' ||
    parsed.score < 0 ||
    parsed.score > 100 ||
    !['pass', 'partial', 'fail'].includes(parsed.verdict) ||
    !Array.isArray(parsed.strengths) ||
    !Array.isArray(parsed.gaps) ||
    typeof parsed.feedback !== 'string' ||
    !Array.isArray(parsed.doubt_signals)
  ) {
    throw new Error('Invalid evaluation format');
  }

  return parsed;
}

async function requireLearner(learnerId: string) {
  const supabase = await getSupabaseServerClient();
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData?.user?.id) {
    throw new Error('Unauthenticated');
  }
  if (userData.user.id !== learnerId) {
    throw new Error('Forbidden');
  }
  return supabase;
}

async function loadFinalConfig(
  supabase: Awaited<ReturnType<typeof getSupabaseServerClient>>,
  programId: string,
): Promise<FinalConfig> {
  const { data, error } = await supabase
    .from('final_evaluation_configs')
    .select(
      'id, program_id, total_questions, roleplay_ratio, min_global_score, must_pass_units, questions_per_unit, max_attempts, cooldown_hours',
    )
    .eq('program_id', programId)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error || !data) {
    throw new Error('Final evaluation config not found');
  }

  return data as FinalConfig;
}

export async function canStartFinalEvaluation(learnerId: string) {
  const supabase = await requireLearner(learnerId);

  const { data: training, error: trainingError } = await supabase
    .from('learner_trainings')
    .select('program_id, progress_percent, current_unit_order, status')
    .eq('learner_id', learnerId)
    .maybeSingle();

  if (trainingError || !training) {
    return { allowed: false, reason: 'Entrenamiento no encontrado' };
  }

  if (Number(training.progress_percent) < 100) {
    return { allowed: false, reason: 'Completa el entrenamiento primero' };
  }

  const config = await loadFinalConfig(supabase, training.program_id);

  const { data: lastAttempt } = await supabase
    .from('final_evaluation_attempts')
    .select('attempt_number, ended_at, status')
    .eq('learner_id', learnerId)
    .order('attempt_number', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (lastAttempt?.status === 'blocked') {
    return { allowed: false, reason: 'Intentos bloqueados' };
  }

  if (lastAttempt?.status === 'in_progress') {
    return { allowed: false, reason: 'Evaluación en curso' };
  }

  if (
    lastAttempt?.attempt_number &&
    lastAttempt.attempt_number >= config.max_attempts
  ) {
    return { allowed: false, reason: 'Se alcanzó el máximo de intentos' };
  }

  if (lastAttempt?.ended_at) {
    const endedAt = new Date(lastAttempt.ended_at).getTime();
    const now = Date.now();
    const diffHours = (now - endedAt) / (1000 * 60 * 60);
    if (diffHours < config.cooldown_hours) {
      return { allowed: false, reason: 'Cooldown activo' };
    }
  }

  return { allowed: true, reason: 'ok' };
}

export async function startFinalEvaluation(learnerId: string) {
  const supabase = await requireLearner(learnerId);

  const allowed = await canStartFinalEvaluation(learnerId);
  if (!allowed.allowed) {
    throw new Error(allowed.reason);
  }

  const { data: training } = await supabase
    .from('learner_trainings')
    .select('program_id, current_unit_order, status')
    .eq('learner_id', learnerId)
    .maybeSingle();

  if (!training) {
    throw new Error('Entrenamiento no encontrado');
  }

  const config = await loadFinalConfig(supabase, training.program_id);

  const { data: lastAttempt } = await supabase
    .from('final_evaluation_attempts')
    .select('attempt_number')
    .eq('learner_id', learnerId)
    .order('attempt_number', { ascending: false })
    .limit(1)
    .maybeSingle();

  const attemptNumber = (lastAttempt?.attempt_number ?? 0) + 1;

  const { data: attempt, error: attemptError } = await supabase
    .from('final_evaluation_attempts')
    .insert({
      learner_id: learnerId,
      program_id: training.program_id,
      attempt_number: attemptNumber,
      status: 'in_progress',
    })
    .select('id')
    .maybeSingle();

  if (attemptError || !attempt) {
    throw new Error('Failed to create final evaluation attempt');
  }

  const { data: units, error: unitsError } = await supabase
    .from('training_units')
    .select('unit_order, title, objectives')
    .eq('program_id', training.program_id)
    .order('unit_order', { ascending: true });

  if (unitsError || !units || units.length === 0) {
    throw new Error('No training units found');
  }

  const questions: FinalQuestion[] = [];
  const roleplayCount = Math.round(
    config.total_questions * config.roleplay_ratio,
  );
  let remainingRoleplay = roleplayCount;

  for (const unit of units) {
    for (let i = 0; i < config.questions_per_unit; i += 1) {
      if (questions.length >= config.total_questions) {
        break;
      }

      const isRoleplay = remainingRoleplay > 0;
      if (isRoleplay) {
        remainingRoleplay -= 1;
      }

      const prompt = isRoleplay
        ? `Simulá una interacción en la unidad "${unit.title}". Respondé como camarero.`
        : `Responde de forma clara sobre la unidad "${unit.title}". Objetivos: ${
            unit.objectives?.join(', ') ?? ''
          }`;

      questions.push({
        id: '',
        unit_order: unit.unit_order,
        question_type: isRoleplay ? 'roleplay' : 'direct',
        prompt,
      });
    }
    if (questions.length >= config.total_questions) {
      break;
    }
  }

  const insertQuestions = questions.map((question) => ({
    attempt_id: attempt.id,
    unit_order: question.unit_order,
    question_type: question.question_type,
    prompt: question.prompt,
  }));

  const { error: questionError } = await supabase
    .from('final_evaluation_questions')
    .insert(insertQuestions);

  if (questionError) {
    throw new Error('Failed to create evaluation questions');
  }

  await supabase.from('learner_state_transitions').insert({
    learner_id: learnerId,
    from_status: training.status,
    to_status: 'en_practica',
    reason: 'Inicio evaluación final',
    actor_user_id: learnerId,
  });

  await supabase
    .from('learner_trainings')
    .update({ status: 'en_practica' })
    .eq('learner_id', learnerId);

  return { attemptId: attempt.id };
}

export async function submitFinalAnswer(input: {
  attemptId: string;
  questionId: string;
  learnerAnswer: string;
}) {
  const supabase = await getSupabaseServerClient();

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData?.user?.id) {
    throw new Error('Unauthenticated');
  }

  const { data: question, error: questionError } = await supabase
    .from('final_evaluation_questions')
    .select(
      'id, attempt_id, unit_order, prompt, final_evaluation_attempts(learner_id, program_id, status)',
    )
    .eq('id', input.questionId)
    .maybeSingle();

  if (questionError || !question) {
    throw new Error('Question not found');
  }

  const attempts = question.final_evaluation_attempts as
    | { learner_id: string; program_id: string; status: string }[]
    | null;
  const attempt = attempts?.[0] ?? null;

  if (!attempt || attempt.learner_id !== userData.user.id) {
    throw new Error('Forbidden');
  }

  if (attempt.status !== 'in_progress') {
    throw new Error('Attempt is not active');
  }
  if (question.attempt_id !== input.attemptId) {
    throw new Error('Invalid attempt');
  }

  const { data: answer, error: answerError } = await supabase
    .from('final_evaluation_answers')
    .insert({
      question_id: question.id,
      learner_answer: input.learnerAnswer,
    })
    .select('id')
    .maybeSingle();

  if (answerError || !answer) {
    throw new Error('Failed to store answer');
  }

  const { data: unit, error: unitError } = await supabase
    .from('training_units')
    .select('id, title, objectives')
    .eq('program_id', attempt.program_id)
    .eq('unit_order', question.unit_order)
    .maybeSingle();

  if (unitError || !unit) {
    throw new Error('Unit not found');
  }

  const allowedKnowledge = await getKnowledgeForContext([unit.id]);

  const evaluationPrompt =
    `Evaluá la respuesta del aprendiz.\n` +
    `Reglas:\n- Solo usa el contexto provisto.\n- Responde JSON estricto: {"score":number,"verdict":"pass|partial|fail","strengths":string[],"gaps":string[],"feedback":string,"doubt_signals":string[]}\n\n` +
    `Pregunta: ${question.prompt}\n` +
    `Unidad: ${unit.title}\n` +
    `Objetivos: ${JSON.stringify(unit.objectives ?? [])}\n` +
    `Conocimiento permitido: ${JSON.stringify(allowedKnowledge)}\n` +
    `Respuesta del aprendiz: ${input.learnerAnswer}`;

  const result = await generateReply({
    system: evaluationPrompt,
    messages: [{ role: 'user', content: input.learnerAnswer }],
  });

  const evaluation = parseEvaluationJson(result.text);
  const doubtSignals = Array.from(
    new Set([
      ...evaluation.doubt_signals,
      ...detectDoubtSignals(input.learnerAnswer),
    ]),
  );

  const { error: evalError } = await supabase
    .from('final_evaluation_evaluations')
    .insert({
      answer_id: answer.id,
      unit_order: question.unit_order,
      score: evaluation.score,
      verdict: evaluation.verdict,
      strengths: evaluation.strengths,
      gaps: evaluation.gaps,
      feedback: evaluation.feedback,
      doubt_signals: doubtSignals,
    });

  if (evalError) {
    throw new Error('Failed to store evaluation');
  }

  return { answerId: answer.id };
}

export async function finalizeAttempt(attemptId: string) {
  const supabase = await getSupabaseServerClient();

  const { data: attempt, error: attemptError } = await supabase
    .from('final_evaluation_attempts')
    .select('id, learner_id, program_id, attempt_number')
    .eq('id', attemptId)
    .maybeSingle();

  if (attemptError || !attempt) {
    throw new Error('Attempt not found');
  }

  const config = await loadFinalConfig(supabase, attempt.program_id);

  const { data: evaluations, error: evalError } = await supabase
    .from('final_evaluation_evaluations')
    .select(
      'score, unit_order, verdict, final_evaluation_answers!inner(final_evaluation_questions!inner(attempt_id))',
    )
    .eq(
      'final_evaluation_answers.final_evaluation_questions.attempt_id',
      attemptId,
    );

  if (evalError) {
    throw new Error('Failed to load evaluations');
  }

  const scores = (evaluations ?? []).map((e) => Number(e.score));
  const globalScore = scores.length
    ? scores.reduce((acc, score) => acc + score, 0) / scores.length
    : 0;

  const mustPassUnits = config.must_pass_units ?? [];
  const mustPassOk = mustPassUnits.every((unitOrder) =>
    (evaluations ?? []).every(
      (e) => e.unit_order !== unitOrder || e.verdict !== 'fail',
    ),
  );

  const recommendation =
    globalScore >= config.min_global_score && mustPassOk
      ? 'approved'
      : 'not_approved';

  const status =
    recommendation === 'approved'
      ? 'completed'
      : attempt.attempt_number >= config.max_attempts
        ? 'blocked'
        : 'completed';

  const { error: updateError } = await supabase
    .from('final_evaluation_attempts')
    .update({
      ended_at: new Date().toISOString(),
      status,
      global_score: globalScore,
      bot_recommendation: recommendation,
    })
    .eq('id', attemptId);

  if (updateError) {
    throw new Error('Failed to finalize attempt');
  }

  await supabase.from('learner_state_transitions').insert({
    learner_id: attempt.learner_id,
    from_status: 'en_practica',
    to_status: 'en_revision',
    reason: 'Evaluación final completada',
    actor_user_id: attempt.learner_id,
  });

  await supabase
    .from('learner_trainings')
    .update({ status: 'en_revision' })
    .eq('learner_id', attempt.learner_id);

  return { globalScore, recommendation, status };
}
