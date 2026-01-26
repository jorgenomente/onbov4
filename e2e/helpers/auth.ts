import type { Page } from '@playwright/test';
import { expect } from '@playwright/test';

export async function login(
  page: Page,
  {
    email,
    password,
    expectedPathPrefix,
  }: { email: string; password: string; expectedPathPrefix: string },
) {
  await page.goto('/login');
  await page.getByTestId('login-email').fill(email);
  await page.getByTestId('login-password').fill(password);
  await page.getByTestId('login-submit').click();

  await expect(page).toHaveURL(new RegExp(`^.*${expectedPathPrefix}`));
}
