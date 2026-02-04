import { test, expect, type Locator, type Page } from '@playwright/test';
import { login } from './helpers/auth';

/**
 * Admin Org — Configuración de cursos/contenido (smoke E2E)
 *
 * Requiere:
 *  - Supabase local con seed demo (npx supabase db reset)
 *  - App corriendo (npm run dev)
 *
 * Env:
 *  - E2E_BASE_URL (default http://localhost:3000)
 *  - E2E_ADMIN_EMAIL (default admin@demo.com)
 *  - E2E_ADMIN_PASSWORD (default prueba123)
 */

const BASE_URL = process.env.E2E_BASE_URL ?? 'http://localhost:3000';
const ADMIN_EMAIL = process.env.E2E_ADMIN_EMAIL ?? 'admin@demo.com';
const ADMIN_PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'prueba123';

async function selectFirstNonEmptyOption(select: Locator) {
  const options = select.locator('option');
  const count = await options.count();
  for (let i = 0; i < count; i += 1) {
    const option = options.nth(i);
    const value = await option.getAttribute('value');
    if (value && value.trim().length > 0) {
      await select.selectOption(value);
      return true;
    }
  }
  return false;
}

async function loginAsAdminOrg(page: Page) {
  await login(page, {
    email: ADMIN_EMAIL,
    password: ADMIN_PASSWORD,
    expectedPathPrefix: '/org',
  });
}

test.describe('Admin Org — flujo configuración contenido', () => {
  test('smoke: locals-program -> knowledge -> scenarios -> final-eval config -> metrics drilldown', async ({
    page,
  }) => {
    await loginAsAdminOrg(page);

    // 1) /org/config/locals-program
    await page.goto(`${BASE_URL}/org/config/locals-program`, {
      waitUntil: 'domcontentloaded',
    });
    await expect(
      page.getByRole('heading', { name: /programa activo/i }),
    ).toBeVisible();

    const noLocals = page.getByText(/no hay locales disponibles/i);
    if (await noLocals.isVisible().catch(() => false)) {
      // Sin locales, no se puede continuar con asignación.
    } else {
      const firstLocalRow = page.locator('table tbody tr').first();
      await expect(firstLocalRow).toBeVisible();

      const cambiar = firstLocalRow.locator('summary', { hasText: /cambiar/i });
      if (await cambiar.count()) {
        await cambiar.first().click();

        const programSelect = firstLocalRow
          .locator('select[name="program_id"]')
          .first();

        if (await programSelect.count()) {
          await selectFirstNonEmptyOption(programSelect);
        }

        const guardar = firstLocalRow
          .getByRole('button', { name: /guardar/i })
          .first();
        await guardar.click();

        const successOrSafe = page.locator(
          'text=/programa activo actualizado|guardado|actualizado/i',
        );
        await expect(successOrSafe)
          .toBeVisible({ timeout: 10_000 })
          .catch(async () => {
            await expect(page).toHaveURL(/\/org\/config\/locals-program/);
          });
      }
    }

    // 2) /org/config/knowledge-coverage
    await page.goto(`${BASE_URL}/org/config/knowledge-coverage`, {
      waitUntil: 'domcontentloaded',
    });
    await expect(
      page.getByRole('heading', { name: /knowledge|cobertura/i }),
    ).toBeVisible();

    const programSelector = page.locator('select[name="programId"]').first();
    if (await programSelector.count()) {
      await selectFirstNonEmptyOption(programSelector);
    }

    const verBtn = page.getByRole('button', { name: /^ver$/i }).first();
    if (await verBtn.count()) await verBtn.click();

    const addHeading = page.getByRole('heading', {
      name: /agregar knowledge/i,
    });
    await expect(addHeading).toBeVisible();

    const title = page.locator('input[name="title"]').first();
    const content = page.locator('textarea[name="content"]').first();
    await title.fill(`E2E knowledge ${Date.now()}`);
    await content.fill(
      'Contenido E2E generado para validar wizard de knowledge.',
    );

    const unitSelect = page.locator('select[name="unit_id"]').first();
    if (await unitSelect.count()) {
      await selectFirstNonEmptyOption(unitSelect);
    }

    const scopeSelect = page.locator('select[name="scope"]').first();
    if (await scopeSelect.count()) {
      await scopeSelect.selectOption({ value: 'org' }).catch(async () => {
        await selectFirstNonEmptyOption(scopeSelect);
      });
    }

    const addBtn = page
      .getByRole('button', { name: /agregar knowledge/i })
      .first();
    await addBtn.click();

    await expect(page.locator('text=/knowledge agregado|agregado/i'))
      .toBeVisible({ timeout: 10_000 })
      .catch(async () => {
        await expect(
          page.locator('text=/error|failed|forbidden/i'),
        ).toHaveCount(0);
      });

    // 3) /org/bot-config (crear escenario)
    await page.goto(`${BASE_URL}/org/bot-config`, {
      waitUntil: 'domcontentloaded',
    });
    await expect(
      page.getByRole('heading', { name: /config del bot/i }),
    ).toBeVisible();

    const noLocalsForConfig = page.getByText(
      /no hay locales con programa activo/i,
    );
    if (!(await noLocalsForConfig.isVisible().catch(() => false))) {
      const localSelector = page.locator('select[name="localId"]').first();
      if (await localSelector.count()) {
        await selectFirstNonEmptyOption(localSelector);
      }

      const verLocalBtn = page.getByRole('button', { name: /^ver$/i }).first();
      if (await verLocalBtn.count()) {
        await Promise.all([
          page.waitForNavigation({ url: /\/org\/bot-config/ }),
          verLocalBtn.click(),
        ]);
      }

      const crearEscenario = page
        .getByRole('button', { name: /crear escenario/i })
        .first();

      const createForm = page.locator('form').filter({
        has: page.locator('input[name="title"]'),
      });
      for (let attempt = 0; attempt < 2; attempt += 1) {
        await crearEscenario.click();
        if (
          await createForm
            .first()
            .isVisible()
            .catch(() => false)
        )
          break;
        await page.waitForTimeout(500);
      }
      await expect(createForm.first()).toBeVisible({ timeout: 10_000 });

      const unitOrderSelect = createForm
        .locator('select[name="unit_order"]')
        .first();
      if (await unitOrderSelect.count()) {
        await selectFirstNonEmptyOption(unitOrderSelect);
      }

      await createForm
        .locator('input[name="title"]')
        .fill(`E2E escenario ${Date.now()}`);
      await createForm
        .locator('textarea[name="instructions"]')
        .fill('Instrucciones E2E para validar creación create-only.');

      const difficulty = createForm.locator('input[name="difficulty"]');
      if (await difficulty.count()) {
        await difficulty.fill('2');
      }

      const success = createForm.locator('textarea[name="success_criteria"]');
      if (await success.count()) {
        await success.fill('- Criterio 1\n- Criterio 2');
      }

      await createForm.getByRole('button', { name: /crear/i }).first().click();

      await expect(page.locator('text=/escenario creado|creado/i'))
        .toBeVisible({ timeout: 10_000 })
        .catch(async () => {
          await expect(
            page.locator('text=/error|failed|forbidden/i'),
          ).toHaveCount(0);
        });
    }

    // 4) /org/config/bot (insert-only config evaluación final)
    await page.goto(`${BASE_URL}/org/config/bot`, {
      waitUntil: 'domcontentloaded',
    });
    await expect(
      page.getByRole('heading', { name: /evaluaci[oó]n final/i }),
    ).toBeVisible();

    const programSelect2 = page.locator('select[name="programId"]').first();
    if (await programSelect2.count()) {
      await selectFirstNonEmptyOption(programSelect2);
    }

    const verConfig = page.getByRole('button', { name: /^ver$/i }).first();
    if (await verConfig.count()) await verConfig.click();

    await page.locator('input[name="total_questions"]').fill('6');
    await page.locator('input[name="roleplay_percent"]').fill('30');
    await page.locator('input[name="min_global_score"]').fill('60');
    await page.locator('input[name="questions_per_unit"]').fill('2');
    await page.locator('input[name="max_attempts"]').fill('3');
    await page.locator('input[name="cooldown_hours"]').fill('12');

    const saveConfig = page
      .getByRole('button', { name: /guardar nueva configuraci[oó]n/i })
      .first();
    if (await saveConfig.count()) {
      await saveConfig.click();
      const okOrConflict = page.locator(
        'text=/nueva configuraci[oó]n guardada|conflict|intento.*progreso|in_progress/i',
      );
      await expect(okOrConflict).toBeVisible({ timeout: 10_000 });
    }

    // 5) /org/metrics (read-only + drilldown)
    await page.goto(`${BASE_URL}/org/metrics`, {
      waitUntil: 'domcontentloaded',
    });
    await expect(
      page.getByRole('heading', { name: /m[eé]tricas/i }),
    ).toBeVisible();

    const metricsTabs = page.getByRole('navigation');
    await expect(
      metricsTabs.getByRole('link', { name: 'Resumen', exact: true }),
    ).toBeVisible();
    await expect(
      metricsTabs.getByRole('link', { name: 'Gaps', exact: true }),
    ).toBeVisible();
    await expect(
      metricsTabs.getByRole('link', { name: 'Cobertura', exact: true }),
    ).toBeVisible();
    await expect(
      metricsTabs.getByRole('link', { name: 'Riesgo', exact: true }),
    ).toBeVisible();

    const anyDrill = page.locator('a[href^="/org/metrics/"]').first();
    if (await anyDrill.count()) {
      await anyDrill.click();
      await expect(page).toHaveURL(/\/org\/metrics\/(gaps|coverage)\//);
    }
  });
});
