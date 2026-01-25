import 'server-only';

import { sendEmail } from '../server/resend';

function requireEnv(name: string) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is not set`);
  }
  return value;
}

export function getEmailFrom() {
  return requireEnv('RESEND_FROM');
}

export function getAppUrl() {
  return requireEnv('APP_URL');
}

export { sendEmail };
