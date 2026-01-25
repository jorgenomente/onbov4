import 'server-only';

import { getAppUrl } from '../resend';

type DecisionApprovedParams = {
  learnerName?: string | null;
  reason: string;
};

export function decisionApprovedTemplate(params: DecisionApprovedParams) {
  const name = params.learnerName?.trim() || 'Hola';
  const trainingUrl = `${getAppUrl()}/learner/training`;

  const subject = 'Tu evaluación fue aprobada';
  const html = `
    <div style="font-family: Arial, sans-serif; line-height: 1.5;">
      <p>${name},</p>
      <p>Tu evaluación final fue aprobada.</p>
      <p><strong>Motivo:</strong> ${params.reason}</p>
      <p>Podés continuar tu entrenamiento aquí:</p>
      <p><a href="${trainingUrl}">${trainingUrl}</a></p>
      <p>Equipo ONBO</p>
    </div>
  `;

  return { subject, html };
}
