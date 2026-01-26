export function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(
      `Missing required env var: ${name}. Set it before running npm run e2e.`,
    );
  }
  return value;
}

export function getE2ECredentials() {
  return {
    learnerEmail: requireEnv('E2E_LEARNER_EMAIL'),
    learnerPassword: requireEnv('E2E_LEARNER_PASSWORD'),
    referenteEmail: requireEnv('E2E_REFERENTE_EMAIL'),
    referentePassword: requireEnv('E2E_REFERENTE_PASSWORD'),
  };
}
