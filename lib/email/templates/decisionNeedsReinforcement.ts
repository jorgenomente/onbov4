import 'server-only';

import { APP_URL } from '../resend';

type DecisionNeedsReinforcementParams = {
  learnerName?: string | null;
  reason: string;
};

export function decisionNeedsReinforcementTemplate(
  params: DecisionNeedsReinforcementParams,
) {
  const name = params.learnerName?.trim() || 'Hola';
  const trainingUrl = `${APP_URL}/learner/training`;

  const subject = 'Tu evaluación requiere refuerzo';
  const html = `
    <div style="font-family: Arial, sans-serif; line-height: 1.5;">
      <p>${name},</p>
      <p>Tu evaluación requiere refuerzo antes de aprobar.</p>
      <p><strong>Motivo:</strong> ${params.reason}</p>
      <p>Podés retomar el entrenamiento aquí:</p>
      <p><a href="${trainingUrl}">${trainingUrl}</a></p>
      <p>Equipo ONBO</p>
    </div>
  `;

  return { subject, html };
}
