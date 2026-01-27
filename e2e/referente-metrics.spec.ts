import { test, expect } from '@playwright/test';

import { login } from './helpers/auth';
import { getE2ECredentials } from './helpers/env';

test('Referente sees metrics blocks', async ({ page }) => {
  const { referenteEmail, referentePassword } = getE2ECredentials();

  await login(page, {
    email: referenteEmail,
    password: referentePassword,
    expectedPathPrefix: '/referente',
  });

  await page.goto('/referente/review');

  await expect(
    page.getByRole('heading', { name: 'Métricas (30 días)' }),
  ).toBeVisible();

  await page.goto('/referente/review/2914f1b6-2694-4488-a10f-7fd85064e697');

  await expect(
    page.getByRole('heading', { name: 'Cobertura (30 días)' }),
  ).toBeVisible();
});
