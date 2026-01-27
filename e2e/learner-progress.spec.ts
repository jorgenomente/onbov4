import { expect, test } from '@playwright/test';

import { login } from './helpers/auth';
import { getE2ECredentials } from './helpers/env';

test('Learner can open progress and review a completed unit', async ({
  page,
}) => {
  const { learnerEmail, learnerPassword } = getE2ECredentials();

  await login(page, {
    email: learnerEmail,
    password: learnerPassword,
    expectedPathPrefix: '/learner',
  });

  await page.goto('/learner/progress');

  const reviewCta = page.getByTestId('review-cta-1');
  await expect(reviewCta).toBeVisible();

  await Promise.all([
    page.waitForNavigation({ url: /\/learner\/review\/1/ }),
    reviewCta.click(),
  ]);

  await expect(page.getByText('Modo repaso (solo lectura).')).toBeVisible();
});
