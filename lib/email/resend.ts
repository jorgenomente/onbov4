import 'server-only';

import { sendEmail } from '../server/resend';

function requireEnv(name: string) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is not set`);
  }
  return value;
}

export const EMAIL_FROM = requireEnv('RESEND_FROM');
export const APP_URL = requireEnv('APP_URL');

export { sendEmail };
