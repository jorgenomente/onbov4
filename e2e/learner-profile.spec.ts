import { expect, test } from '@playwright/test';

import { login } from './helpers/auth';
import { getE2ECredentials } from './helpers/env';

test('Learner can open profile page', async ({ page }) => {
  const { learnerEmail, learnerPassword } = getE2ECredentials();

  await login(page, {
    email: learnerEmail,
    password: learnerPassword,
    expectedPathPrefix: '/learner',
  });

  await page.goto('/learner/profile');
  await expect(
    page.getByRole('heading', { name: 'Perfil', level: 1 }),
  ).toBeVisible();
  await expect(page.getByText('Historial de decisiones')).toBeVisible();
});
