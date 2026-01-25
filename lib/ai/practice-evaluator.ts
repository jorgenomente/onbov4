import 'server-only';

import { generateReply } from './provider';

type PracticeScenario = {
  title: string;
  instructions: string;
  success_criteria: string[];
};

type ChatContext = {
  learner: { id: string; local_id: string };
  program: { id: string; name: string };
  unit: { order: number; title: string; objectives: string[] };
  allowedKnowledge: { title: string; content: string }[];
};

type PracticeEvaluation = {
  score: number;
  verdict: 'pass' | 'partial' | 'fail';
  strengths: string[];
  gaps: string[];
  feedback: string;
  doubt_signals: string[];
};

const NO_SE_REGEX = /\b(no\s*s[eé]|no\s*lo\s*s[eé]|ni\s*idea)\b/i;
const NO_ME_ACUERDO_REGEX = /\b(no\s*me\s*acuerdo|no\s*recuerdo)\b/i;

export function detectDoubtSignals(text: string): string[] {
  const signals = new Set<string>();
  const normalized = text.trim();

  if (NO_SE_REGEX.test(normalized)) {
    signals.add('no_se');
  }
  if (NO_ME_ACUERDO_REGEX.test(normalized)) {
    signals.add('no_me_acuerdo');
  }

  const wordCount = normalized.split(/\s+/).filter(Boolean).length;
  if (wordCount <= 3 || normalized.length < 20) {
    signals.add('ambiguo');
  }

  return Array.from(signals);
}

function parseEvaluationJson(raw: string): PracticeEvaluation {
  const parsed = JSON.parse(raw) as PracticeEvaluation;

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

  return {
    score: parsed.score,
    verdict: parsed.verdict,
    strengths: parsed.strengths,
    gaps: parsed.gaps,
    feedback: parsed.feedback,
    doubt_signals: parsed.doubt_signals,
  };
}

export async function evaluatePracticeAnswer(params: {
  scenario: PracticeScenario;
  learnerAnswer: string;
  chatContext: ChatContext;
}) {
  const { scenario, learnerAnswer, chatContext } = params;
  const detectedSignals = detectDoubtSignals(learnerAnswer);

  const system =
    `Eres un evaluador estricto y pedagógico.\n\n` +
    `Reglas:\n` +
    `- No uses conocimiento externo. Usa SOLO el contexto provisto.\n` +
    `- Evalúa contra success_criteria.\n` +
    `- Responde en JSON estricto con esta forma:\n` +
    `{"score":number,"verdict":"pass|partial|fail","strengths":string[],"gaps":string[],"feedback":string,"doubt_signals":string[]}\n\n` +
    `Escenario:\n` +
    `title: ${scenario.title}\n` +
    `instructions: ${scenario.instructions}\n` +
    `success_criteria: ${JSON.stringify(scenario.success_criteria)}\n\n` +
    `Contexto permitido:\n` +
    `${JSON.stringify({
      unit: chatContext.unit,
      allowedKnowledge: chatContext.allowedKnowledge,
    })}`;

  const result = await generateReply({
    system,
    messages: [{ role: 'user', content: learnerAnswer }],
  });

  let evaluation = parseEvaluationJson(result.text);

  const mergedSignals = new Set([
    ...evaluation.doubt_signals,
    ...detectedSignals,
  ]);

  evaluation = {
    ...evaluation,
    doubt_signals: Array.from(mergedSignals),
  };

  return evaluation;
}
