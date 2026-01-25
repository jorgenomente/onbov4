import 'server-only';

import { Resend } from 'resend';
import type { CreateEmailOptions } from 'resend';

type SendEmailParams = {
  to: string | string[];
  subject: string;
  html?: string;
  text?: string;
  from?: string;
};

function requireEnv(name: string) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is not set`);
  }
  return value;
}

type ResendConfig = {
  client: Resend;
  defaultFrom: string;
};

let cachedConfig: ResendConfig | null = null;

function getResendConfig(): ResendConfig {
  if (cachedConfig) {
    return cachedConfig;
  }

  const resendApiKey = requireEnv('RESEND_API_KEY');
  const defaultFrom = requireEnv('RESEND_FROM');

  cachedConfig = {
    client: new Resend(resendApiKey),
    defaultFrom,
  };

  return cachedConfig;
}

export function getDefaultFrom() {
  return getResendConfig().defaultFrom;
}

export async function sendEmail(params: SendEmailParams) {
  if (!params.html && !params.text) {
    throw new Error('sendEmail requires html or text');
  }

  const { client, defaultFrom } = getResendConfig();
  const from = params.from ?? defaultFrom;
  const base = {
    from,
    to: params.to,
    subject: params.subject,
  };

  if (params.html) {
    const options: CreateEmailOptions = {
      ...base,
      html: params.html,
    };

    return client.emails.send(options);
  }

  const text = params.text;
  if (!text) {
    throw new Error('sendEmail requires text when html is not provided');
  }

  const options: CreateEmailOptions = {
    ...base,
    text,
  };

  return client.emails.send(options);
}
