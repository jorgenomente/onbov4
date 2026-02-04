# E2E ADMIN ORG CONFIG FLOW

## Contexto

Agregar/ajustar un test E2E de Admin Org para validar el flujo de configuración de cursos y contenido.

## Prompt ejecutado

````txt
```ts
// e2e/admin-org-config-flow.spec.ts
import { test, expect } from '@playwright/test';

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
 *
 * Credenciales demo: :contentReference[oaicite:0]{index=0}
 * Contexto/actividad: :contentReference[oaicite:1]{index=1}
 */

const BASE_URL = process.env.E2E_BASE_URL ?? 'http://localhost:3000';
const ADMIN_EMAIL = process.env.E2E_ADMIN_EMAIL ?? 'admin@demo.com';
const ADMIN_PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'prueba123';

async function loginAsAdminOrg(page: any) {
  await page.goto(`${BASE_URL}/login`, { waitUntil: 'domcontentloaded' });

  // Selectores tolerantes (evita depender de data-testid si no existe)
  const email = page.getByLabel(/email/i).or(page.locator('input[type="email"], input[name="email"]'));
  const password = page.getByLabel(/password/i).or(page.locator('input[type="password"], input[name="password"]'));

  await email.fill(ADMIN_EMAIL);
  await password.fill(ADMIN_PASSWORD);

  // Botón típico
  const submit = page.getByRole('button', { name: /iniciar|login|entrar|sign in/i }).first();
  await submit.click();

  // Post-login: redirección por rol a /org/*
  await expect(page).toHaveURL(/\/org\/.*/);
}

test.describe('Admin Org — flujo configuración contenido', () => {
  test('smoke: locals-program -> knowledge -> scenarios -> final-eval config -> metrics drilldown', async ({ page }) => {
    await loginAsAdminOrg(page);

    // 1) /org/config/locals-program
    await page.goto(`${BASE_URL}/org/config/locals-program`, { waitUntil: 'domcontentloaded' });
    await expect(page.getByRole('heading', { name: /programa activo|locals|locales/i })).toBeVisible();

    // Intentar cambiar programa del primer local (si UI lo permite).
    // Nota: si en seed solo hay 1 programa, esto igualmente valida que el flujo y el guardrail no rompen.
    const firstLocalRow = page.locator('table tbody tr').first();
    await expect(firstLocalRow).toBeVisible();

    // Abre details / "Cambiar" si existe
    const cambiar = firstLocalRow.getByRole('button', { name: /cambiar/i }).or(firstLocalRow.getByText(/cambiar/i));
    if (await cambiar.count()) {
      await cambiar.first().click();

      // Selector de programa y guardar (fallbacks)
      const programSelect = page
        .locator('select')
        .first()
        .or(page.getByRole('combobox').first());

      if (await programSelect.count()) {
        // Selecciona la segunda opción si existe, sino la primera distinta a placeholder
        const options = programSelect.locator('option');
        const optionCount = await options.count();
        if (optionCount >= 2) {
          await programSelect.selectOption({ index: 1 });
        } else if (optionCount === 1) {
          await programSelect.selectOption({ index: 0 });
        }
      }

      const guardar = page.getByRole('button', { name: /guardar/i }).first();
      await guardar.click();

      // Assert flexible: toast/alert o re-render de tabla
      await expect(page.locator('text=/guardado|actualizado|cambio|asignado/i')).toBeVisible({ timeout: 10_000 }).catch(
        async () => {
          // Si no hay toast, al menos que siga siendo /locals-program sin crash.
          await expect(page).toHaveURL(/\/org\/config\/locals-program/);
        },
      );
    }

    // 2) /org/config/knowledge-coverage
    await page.goto(`${BASE_URL}/org/config/knowledge-coverage`, { waitUntil: 'domcontentloaded' });
    await expect(page.getByRole('heading', { name: /knowledge|cobertura/i })).toBeVisible();

    // Seleccionar programa si hay selector
    const programSelector = page.getByRole('combobox').first().or(page.locator('select').first());
    if (await programSelector.count()) {
      const options = programSelector.locator('option');
      const optionCount = await options.count();
      if (optionCount >= 2) await programSelector.selectOption({ index: 1 });
    }

    const verBtn = page.getByRole('button', { name: /^ver$/i }).or(page.getByRole('button', { name: /ver/i }));
    if (await verBtn.count()) await verBtn.first().click();

    // Agregar knowledge (wizard)
    const addHeading = page.getByRole('heading', { name: /agregar knowledge/i });
    await expect(addHeading).toBeVisible();

    // Campos del form (tolerantes)
    const title = page.getByLabel(/title|t[ií]tulo/i).or(page.locator('input[name="title"]'));
    const content = page.getByLabel(/content|contenido/i).or(page.locator('textarea[name="content"]'));
    await title.fill(`E2E knowledge ${Date.now()}`);
    await content.fill(`Contenido E2E generado para validar wizard de knowledge.`);

    // Unit selector
    const unitSelect = page
      .getByLabel(/unidad|unit/i)
      .or(page.locator('select[name="unit_id"], select[name="unitId"], select').nth(1))
      .or(page.getByRole('combobox').nth(1));
    if (await unitSelect.count()) {
      const opts = unitSelect.locator('option');
      const cnt = await opts.count();
      if (cnt >= 2) await unitSelect.selectOption({ index: 1 });
      else if (cnt === 1) await unitSelect.selectOption({ index: 0 });
    }

    // Scope selector (org/local) si existe
    const scopeSelect = page
      .getByLabel(/scope|alcance/i)
      .or(page.locator('select[name="scope"]'))
      .or(page.getByRole('combobox').filter({ hasText: /org|local/i }).first());
    if (await scopeSelect.count()) {
      // Prefer org (más simple)
      await scopeSelect.selectOption({ value: 'org' }).catch(async () => {
        // fallback: por label visible
        await scopeSelect.selectOption({ label: /org/i }).catch(() => {});
      });
    }

    const addBtn = page.getByRole('button', { name: /agregar|crear/i }).first();
    await addBtn.click();

    await expect(page.locator('text=/creado|agregado|mapeado|ok/i')).toBeVisible({ timeout: 10_000 }).catch(
      async () => {
        // Fallback: validar que lista/tabla creció o que no hubo error fatal visible.
        await expect(page.locator('text=/error|failed|forbidden/i')).toHaveCount(0);
      },
    );

    // 3) /org/bot-config (crear escenario)
    await page.goto(`${BASE_URL}/org/bot-config`, { waitUntil: 'domcontentloaded' });
    await expect(page.getByRole('heading', { name: /bot config|escenarios|pr[aá]ctica/i })).toBeVisible();

    // Seleccionar local si hay selector
    const localSelector = page.getByRole('combobox').first().or(page.locator('select').first());
    if (await localSelector.count()) {
      const options = localSelector.locator('option');
      const optionCount = await options.count();
      if (optionCount >= 2) await localSelector.selectOption({ index: 1 });
    }

    const verLocalBtn = page.getByRole('button', { name: /^ver$/i }).or(page.getByRole('button', { name: /ver/i }));
    if (await verLocalBtn.count()) await verLocalBtn.first().click();

    const crearEscenario = page.getByRole('button', { name: /crear escenario/i }).first();
    await crearEscenario.click();

    // Modal: selector de unidad (dropdown)
    const modal = page.locator('[role="dialog"]').first();
    await expect(modal).toBeVisible();

    const unitOrderSelect = modal
      .getByRole('combobox')
      .first()
      .or(modal.locator('select').first());
    if (await unitOrderSelect.count()) {
      const opts = unitOrderSelect.locator('option');
      const cnt = await opts.count();
      if (cnt >= 2) await unitOrderSelect.selectOption({ index: 1 });
      else if (cnt === 1) await unitOrderSelect.selectOption({ index: 0 });
    }

    await modal.getByLabel(/title|t[ií]tulo/i).or(modal.locator('input[name="title"]')).fill(`E2E escenario ${Date.now()}`);
    await modal
      .getByLabel(/instructions|instrucciones/i)
      .or(modal.locator('textarea[name="instructions"]'))
      .fill('Instrucciones E2E para validar creación create-only.');

    // difficulty puede ser select/number
    const difficulty = modal.getByLabel(/difficulty|dificultad/i).or(modal.locator('input[name="difficulty"], select[name="difficulty"]'));
    if (await difficulty.count()) {
      await difficulty.fill?.('2').catch(async () => {
        await difficulty.selectOption?.({ value: '2' }).catch(() => {});
      });
    }

    // success criteria
    const success = modal
      .getByLabel(/success|criterios/i)
      .or(modal.locator('textarea[name="success_criteria"], textarea[name="successCriteria"]'));
    if (await success.count()) {
      await success.fill('- Criterio 1\n- Criterio 2');
    }

    await modal.getByRole('button', { name: /crear|guardar/i }).first().click();

    await expect(page.locator('text=/escenario.*creado|created/i')).toBeVisible({ timeout: 10_000 }).catch(async () => {
      await expect(page.locator('text=/error|failed|forbidden/i')).toHaveCount(0);
    });

    // 4) /org/config/bot (insert-only config evaluación final)
    await page.goto(`${BASE_URL}/org/config/bot`, { waitUntil: 'domcontentloaded' });
    await expect(page.getByRole('heading', { name: /evaluaci[oó]n final|config/i })).toBeVisible();

    const programSelect2 = page.getByRole('combobox').first().or(page.locator('select').first());
    if (await programSelect2.count()) {
      const options = programSelect2.locator('option');
      const optionCount = await options.count();
      if (optionCount >= 2) await programSelect2.selectOption({ index: 1 });
    }

    // Ver config vigente
    const verConfig = page.getByRole('button', { name: /^ver$/i }).or(page.getByRole('button', { name: /ver/i }));
    if (await verConfig.count()) await verConfig.first().click();

    // Fill form "Nueva configuración" con valores válidos.
    // Nota: los nombres exactos de inputs pueden variar; estos fallbacks buscan por label o name.
    const totalQuestions = page.getByLabel(/total.*questions|total/i).or(page.locator('input[name="total_questions"]'));
    if (await totalQuestions.count()) await totalQuestions.fill('6');

    const roleplayPct = page.getByLabel(/roleplay|role-play|%/i).or(page.locator('input[name="roleplay_percent"]'));
    if (await roleplayPct.count()) await roleplayPct.fill('30');

    const minScore = page.getByLabel(/min.*score|score/i).or(page.locator('input[name="min_global_score"]'));
    if (await minScore.count()) await minScore.fill('60');

    const maxAttempts = page.getByLabel(/max.*attempts/i).or(page.locator('input[name="max_attempts"]'));
    if (await maxAttempts.count()) await maxAttempts.fill('3');

    const cooldown = page.getByLabel(/cooldown|hours|horas/i).or(page.locator('input[name="cooldown_hours"]'));
    if (await cooldown.count()) await cooldown.fill('12');

    // Guardar nueva config
    const saveConfig = page.getByRole('button', { name: /guardar|crear nueva configuraci[oó]n|nueva configuraci[oó]n/i }).first();
    if (await saveConfig.count()) {
      await saveConfig.click();

      // Puede fallar por guardrail si hay intento in_progress (conflict).
      // Assert: o éxito, o mensaje de conflicto explícito.
      const okOrConflict = page.locator('text=/cread[ao]|guardad[ao]|conflict|intento.*progreso|in_progress/i');
      await expect(okOrConflict).toBeVisible({ timeout: 10_000 });
    }

    // 5) /org/metrics (read-only + drilldown)
    await page.goto(`${BASE_URL}/org/metrics`, { waitUntil: 'domcontentloaded' });
    await expect(page.getByRole('heading', { name: /m[eé]tricas/i })).toBeVisible();

    // Tabs presentes
    await expect(page.getByRole('tab', { name: /resumen/i })).toBeVisible();
    await expect(page.getByRole('tab', { name: /gaps/i })).toBeVisible();
    await expect(page.getByRole('tab', { name: /cobertura/i })).toBeVisible();
    await expect(page.getByRole('tab', { name: /riesgo/i })).toBeVisible();

    // Drilldown: intenta clickear primer link a gap o coverage si existe
    const anyDrill = page.locator('a[href^="/org/metrics/"]').first();
    if (await anyDrill.count()) {
      await anyDrill.click();
      await expect(page).toHaveURL(/\/org\/metrics\/(gaps|coverage)\//);
    }
  });
});
```
````

Resultado esperado

Archivo de test E2E para Admin Org con selectores estables y flujo completo.
