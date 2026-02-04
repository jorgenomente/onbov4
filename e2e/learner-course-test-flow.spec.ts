import { expect, test } from '@playwright/test';

import { login } from './helpers/auth';
import { getE2ECredentials } from './helpers/env';

test('Learner completes Curso Test unit 1 flow', async ({ page }) => {
  const { learnerEmail, learnerPassword } = getE2ECredentials();
  const courseEmail = process.env.E2E_COURSE_EMAIL ?? learnerEmail;
  const coursePassword = process.env.E2E_COURSE_PASSWORD ?? learnerPassword;
  const consoleMessages: string[] = [];

  page.on('console', (msg) => {
    consoleMessages.push(msg.text());
  });
  page.on('pageerror', (err) => {
    consoleMessages.push(err.message);
  });

  await login(page, {
    email: courseEmail,
    password: coursePassword,
    expectedPathPrefix: '/learner',
  });

  await page.goto('/learner');

  await expect(page.getByTestId('learner-cta-continue')).toBeVisible();
  await expect(page.getByTestId('learner-current-unit')).toBeVisible();
  await expect(page.getByTestId('learner-progress')).toBeVisible();
  await expect(page.getByTestId('learner-status')).toBeVisible();

  await Promise.all([
    page.waitForNavigation({ url: /\/learner\/training/ }),
    page.getByTestId('learner-cta-continue').click(),
  ]);

  const chatThread = page.getByTestId('chat-thread');
  const messages = page.getByTestId('chat-message');

  await expect(chatThread).toBeVisible();
  await expect.poll(async () => messages.count()).toBeGreaterThanOrEqual(2);

  await expect(
    page.locator('text=Active conversation context not found'),
  ).toHaveCount(0);

  const chatInput = page.getByTestId('chat-input');
  await chatInput.fill('hola');
  await page.getByTestId('chat-send').click();

  await expect.poll(async () => messages.count()).toBeGreaterThanOrEqual(3);

  await expect(page.getByTestId('training-phase')).toContainText('Aprender');
  await expect(page.getByTestId('needs-start')).toBeVisible();
  await expect(page.getByTestId('practice-card')).toHaveCount(0);

  const countBefore = await messages.count();
  await chatInput.fill('comenzar');
  await page.getByTestId('chat-send').click();

  await expect.poll(async () => messages.count()).toBeGreaterThan(countBefore);

  await expect(page.getByTestId('needs-start')).toHaveCount(0);

  const practiceCta = page.getByRole('button', { name: 'Continuar' });
  await practiceCta.click();

  const practiceCard = page.getByTestId('practice-card');
  if (!(await practiceCard.isVisible().catch(() => false))) {
    await page.waitForTimeout(500);
    await practiceCta.click();
  }
  if (!(await practiceCard.isVisible().catch(() => false))) {
    await page.reload({ waitUntil: 'domcontentloaded' });
  }
  await expect(practiceCard).toBeVisible({ timeout: 10_000 });
  await expect(page.getByTestId('training-reminder')).toBeVisible();
  await expect(page.getByTestId('training-phase')).toContainText('Practicar');

  await page.waitForTimeout(500);
  const countBeforePractice = await messages.count();
  await chatInput.fill(
    'Hola, soy Sofia y voy a estar atendiendolos. Quieren agua o una bebida para comenzar?',
  );
  await page.getByTestId('chat-send').click();

  await expect
    .poll(async () => messages.count())
    .toBeGreaterThan(countBeforePractice);

  await page.goto('/learner');
  const progressText = await page.getByTestId('learner-progress').innerText();
  const progressValue = Number(progressText.replace('%', ''));
  expect(progressValue).toBeGreaterThan(0);

  const consoleDump = consoleMessages.join(' | ');
  expect(consoleDump).not.toContain('Active conversation context not found');
  expect(consoleDump).not.toContain('final-evaluation gating blocked');
  expect(consoleDump).not.toContain('Unhandled');
});
