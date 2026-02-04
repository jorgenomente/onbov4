import { test, expect } from '@playwright/test';
import type { Locator } from '@playwright/test';
import { login } from './helpers/auth';

const password = 'prueba123';

const users = {
  learner: {
    email: 'aprendiz@demo.com',
    expectedPathPrefix: '/learner',
  },
  referente: {
    email: 'referente@demo.com',
    expectedPathPrefix: '/referente/review',
  },
  admin: {
    email: 'admin@demo.com',
    expectedPathPrefix: '/org/metrics',
  },
  superadmin: {
    email: 'superadmin@onbo.dev',
    expectedPathPrefix: '/referente/review',
  },
};

async function waitForAnyVisible(locators: Locator[], timeoutMs = 8000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    for (const locator of locators) {
      const visible = await locator.isVisible().catch(() => false);
      if (visible) return true;
    }
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  return false;
}

test('UI smoke - aprendiz', async ({ page }) => {
  await login(page, {
    email: users.learner.email,
    password,
    expectedPathPrefix: users.learner.expectedPathPrefix,
  });

  await page.goto('/learner/training');

  await expect(
    page.getByRole('heading', { name: 'Entrenamiento' }),
  ).toBeVisible();

  const input = page.locator('#chat-input');
  await expect(input).toBeVisible();

  const errorBanner = page.getByText(
    /No pudimos|No tengo información|No pudimos evaluar|Error al cargar/i,
  );

  for (let i = 1; i <= 2; i += 1) {
    await input.fill(`smoke mensaje ${i}`);
    await page.getByRole('button', { name: 'Enviar' }).click();
    await page.waitForTimeout(1000);

    const cleared = (await input.inputValue()) === '';
    const hasError = await errorBanner
      .first()
      .isVisible()
      .catch(() => false);
    expect.soft(cleared || hasError).toBeTruthy();
  }

  const practiceButton = page.getByRole('button', { name: 'Iniciar práctica' });
  if (await practiceButton.isVisible()) {
    await practiceButton.click();
    await page.waitForTimeout(1500);

    const practiceMode = page.getByText('Modo role-play activo.');
    const noScenarioError = page.getByText(
      /No hay escenarios de práctica configurados/i,
    );
    const practiceVisible = await practiceMode.isVisible().catch(() => false);
    const practiceError = await noScenarioError.isVisible().catch(() => false);
    expect.soft(practiceVisible || practiceError).toBeTruthy();
  }
});

test('UI smoke - referente', async ({ page }) => {
  await login(page, {
    email: users.referente.email,
    password,
    expectedPathPrefix: users.referente.expectedPathPrefix,
  });

  const reviewQueue = page.getByTestId('review-queue');
  const emptyQueue = page.getByText(
    /Sin aprendices para revisar|No hay aprendices en revisión/i,
  );
  const reviewHeading = page.getByRole('heading', { name: 'Revisión' });
  const learnerHeading = page.getByRole('heading', { name: /Aprendiz/i });
  const anyVisible = await waitForAnyVisible([
    reviewQueue,
    emptyQueue,
    reviewHeading,
    learnerHeading,
  ]);
  expect.soft(anyVisible).toBeTruthy();

  const queueVisible = await reviewQueue.isVisible().catch(() => false);
  let shouldHaveDetail = false;
  if (queueVisible) {
    const rows = page.getByTestId('review-learner-row');
    await expect(rows.first()).toBeVisible();
    const reviewLink = rows
      .first()
      .getByRole('link', { name: 'Revisar evidencia' });
    await reviewLink.click();
    shouldHaveDetail = true;
  } else {
    const detailLink = page
      .getByRole('link', { name: 'Ver detalle →' })
      .first();
    if (await detailLink.isVisible().catch(() => false)) {
      await detailLink.click();
      shouldHaveDetail = true;
    }
  }

  const detailHeading = page.getByText('Evidencias y decisión final.');
  if (!shouldHaveDetail) {
    shouldHaveDetail = await detailHeading.isVisible().catch(() => false);
  }
  if (shouldHaveDetail) {
    await expect(detailHeading).toBeVisible();
  }
});

test('UI smoke - admin org', async ({ page }) => {
  await login(page, {
    email: users.admin.email,
    password,
    expectedPathPrefix: users.admin.expectedPathPrefix,
  });

  await expect(
    page.getByRole('heading', { name: 'Métricas (últimos 30 días)' }),
  ).toBeVisible();
});

test('UI smoke - superadmin', async ({ page }) => {
  await login(page, {
    email: users.superadmin.email,
    password,
    expectedPathPrefix: users.superadmin.expectedPathPrefix,
  });

  const reviewQueue = page.getByTestId('review-queue');
  const emptyQueue = page.getByText(
    /Sin aprendices para revisar|No hay aprendices en revisión/i,
  );
  const reviewHeading = page.getByRole('heading', { name: 'Revisión' });
  const learnerHeading = page.getByRole('heading', { name: /Aprendiz/i });
  const anyVisible = await waitForAnyVisible([
    reviewQueue,
    emptyQueue,
    reviewHeading,
    learnerHeading,
  ]);
  expect.soft(anyVisible).toBeTruthy();
});
