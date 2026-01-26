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
