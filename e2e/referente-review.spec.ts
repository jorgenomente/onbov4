import { test, expect } from '@playwright/test';

import { login } from './helpers/auth';
import { getE2ECredentials } from './helpers/env';

test('Referente can see review queue', async ({ page }) => {
  const { referenteEmail, referentePassword } = getE2ECredentials();

  await login(page, {
    email: referenteEmail,
    password: referentePassword,
    expectedPathPrefix: '/referente',
  });

  await page.goto('/referente/review');

  const queue = page.getByTestId('review-queue');
  if (await queue.count()) {
    await expect(queue).toBeVisible();
    const rows = page.getByTestId('review-learner-row');
    await expect(rows.first()).toBeVisible();
  } else {
    await expect(page.locator('main')).toContainText('Revisión');
  }
});

test('Referente sees evidence sections in review detail', async ({ page }) => {
  const { referenteEmail, referentePassword } = getE2ECredentials();

  await login(page, {
    email: referenteEmail,
    password: referentePassword,
    expectedPathPrefix: '/referente',
  });

  await page.goto('/referente/review/2914f1b6-2694-4488-a10f-7fd85064e697');

  await expect(
    page.getByRole('heading', { name: 'Resumen por unidad' }),
  ).toBeVisible();
  await expect(
    page.getByRole('heading', { name: 'Respuestas fallidas' }),
  ).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Señales' })).toBeVisible();
});
