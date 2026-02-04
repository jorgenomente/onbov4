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
  // Examples for manual verification (no test harness yet):
  // 1) {"score":80,"verdict":"pass","strengths":[],"gaps":[],"feedback":"ok","doubt_signals":[]}
  // 2) ```json {"score":0,"verdict":"fail","strengths":[],"gaps":["x"],"feedback":"y","doubt_signals":[]} ```
  // 3) Texto previo {"score":50,"verdict":"partial","strengths":["a"],"gaps":["b"],"feedback":"c","doubt_signals":[]} texto final
  const defaultEvaluation: PracticeEvaluation = {
    score: 0,
    verdict: 'fail',
    strengths: [],
    gaps: ['No se pudo interpretar la evaluación automática.'],
    feedback:
      'No pude evaluar tu respuesta en este momento. Intentá nuevamente.',
    doubt_signals: [],
  };

  const truncate = (value: string, max = 500) =>
    value.length > max ? `${value.slice(0, max)}…` : value;

  const extractFromFence = (value: string) => {
    const jsonFence = value.match(/```json\s*([\s\S]*?)\s*```/i);
    if (jsonFence?.[1]) return jsonFence[1].trim();
    const anyFence = value.match(/```\s*([\s\S]*?)\s*```/i);
    if (anyFence?.[1]) return anyFence[1].trim();
    return null;
  };

  const extractFromBraces = (value: string) => {
    const start = value.indexOf('{');
    const end = value.lastIndexOf('}');
    if (start !== -1 && end !== -1 && end > start) {
      return value.slice(start, end + 1).trim();
    }
    return null;
  };

  const rawTrimmed = raw.trim();
  let sanitized = rawTrimmed;
  const fenced = extractFromFence(rawTrimmed);
  if (fenced) {
    sanitized = fenced;
  }

  let parsed: PracticeEvaluation | null = null;
  try {
    parsed = JSON.parse(sanitized) as PracticeEvaluation;
  } catch (error) {
    const braced = extractFromBraces(rawTrimmed);
    if (braced) {
      sanitized = braced;
      try {
        parsed = JSON.parse(sanitized) as PracticeEvaluation;
      } catch (innerError) {
        console.error('practice-evaluator: parse failed', {
          error: innerError instanceof Error ? innerError.message : innerError,
          raw: truncate(rawTrimmed),
          sanitized: truncate(sanitized),
        });
        return defaultEvaluation;
      }
    } else {
      console.error('practice-evaluator: parse failed', {
        error: error instanceof Error ? error.message : error,
        raw: truncate(rawTrimmed),
        sanitized: truncate(sanitized),
      });
      return defaultEvaluation;
    }
  }

  if (!parsed) {
    return defaultEvaluation;
  }

  const isValid =
    typeof parsed.score === 'number' &&
    parsed.score >= 0 &&
    parsed.score <= 100 &&
    ['pass', 'partial', 'fail'].includes(parsed.verdict) &&
    Array.isArray(parsed.strengths) &&
    Array.isArray(parsed.gaps) &&
    typeof parsed.feedback === 'string' &&
    Array.isArray(parsed.doubt_signals);

  if (!isValid) {
    console.error('practice-evaluator: invalid format', {
      raw: truncate(rawTrimmed),
      sanitized: truncate(sanitized),
    });
    return defaultEvaluation;
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
  if (process.env.LLM_PROVIDER === 'mock') {
    return {
      score: 90,
      verdict: 'pass' as const,
      strengths: ['Respuesta clara y alineada al escenario.'],
      gaps: [],
      feedback: 'Buen trabajo. Continuá con el siguiente paso.',
      doubt_signals: detectedSignals,
    };
  }

  const system =
    `Eres un evaluador estricto y pedagógico.\n\n` +
    `Reglas:\n` +
    `- No uses conocimiento externo. Usa SOLO el contexto provisto.\n` +
    `- Evalúa contra success_criteria.\n` +
    `- Responde SOLO con JSON válido. Sin markdown, sin backticks, sin texto extra.\n` +
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
