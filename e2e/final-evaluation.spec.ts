import { test, expect } from '@playwright/test';

import { login } from './helpers/auth';
import { getE2ECredentials } from './helpers/env';

test('Learner completes final evaluation and advances without manual refresh', async ({
  page,
}) => {
  const { learnerEmail, learnerPassword } = getE2ECredentials();

  await login(page, {
    email: learnerEmail,
    password: learnerPassword,
    expectedPathPrefix: '/learner',
  });

  await page.goto('/learner/final-evaluation');

  const progress = page.getByTestId('final-progress');
  const startButton = page.getByTestId('final-start');
  const inReview = page.getByTestId('final-in-review');

  if ((await progress.count()) === 0) {
    if ((await startButton.count()) === 0) {
      if ((await inReview.count()) > 0) {
        throw new Error(
          'Final evaluation already completed. Reset the DB before running this test.',
        );
      }
      const pageText = await page.locator('main').first().innerText();
      throw new Error(
        `Final evaluation not startable. Page content: ${pageText}`,
      );
    }
    await Promise.all([
      page.waitForNavigation({ url: /\/learner\/final-evaluation/ }),
      startButton.click(),
    ]);
  }

  await Promise.race([
    expect(progress).toBeVisible({ timeout: 15000 }),
    expect(inReview).toBeVisible({ timeout: 15000 }),
  ]);

  for (let step = 0; step < 20; step += 1) {
    if (await inReview.isVisible()) {
      break;
    }

    await expect(progress).toBeVisible();
    const initialProgressText = await progress.textContent();
    const initialPromptText = await page
      .getByTestId('final-question-prompt')
      .textContent();

    await page
      .getByTestId('final-answer')
      .fill('Respuesta automática de prueba.');
    await Promise.all([
      page.waitForNavigation({ url: /\/learner\/final-evaluation/ }),
      page.getByTestId('final-submit').click(),
    ]);

    await Promise.race([
      page.waitForSelector('[data-testid="final-progress"]', {
        state: 'visible',
        timeout: 15000,
      }),
      page.waitForSelector('[data-testid="final-in-review"]', {
        state: 'visible',
        timeout: 15000,
      }),
    ]);

    if (await inReview.isVisible()) {
      break;
    }

    const updatedProgressText = (await progress.textContent())?.trim() ?? '';
    const updatedPromptText =
      (await page.getByTestId('final-question-prompt').textContent())?.trim() ??
      '';

    if (
      updatedProgressText === (initialProgressText ?? '').trim() &&
      updatedPromptText === (initialPromptText ?? '').trim()
    ) {
      throw new Error('Final evaluation did not advance to the next question.');
    }
  }

  await expect(inReview).toBeVisible();
  await expect(page).toHaveURL(/\/learner\/final-evaluation/);
});
