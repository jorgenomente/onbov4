# PATCH LOGIN ADMIN ORG E2E

## Contexto

Reemplazar la función `loginAsAdminOrg()` del spec E2E para tolerar redirecciones y fallar con causa clara en caso de error de login.

## Prompt ejecutado

````txt
```ts
// PATCH: reemplazá SOLO la función loginAsAdminOrg() en tu spec
// (mantiene el resto del test igual, pero ahora falla con causa clara y
// tolera redirecciones intermedias).

import { expect } from '@playwright/test';

const BASE_URL = process.env.E2E_BASE_URL ?? 'http://localhost:3000';
const ADMIN_EMAIL = process.env.E2E_ADMIN_EMAIL ?? 'admin@demo.com';
const ADMIN_PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'prueba123';

export async function loginAsAdminOrg(page: any) {
  await page.goto(`${BASE_URL}/login`, { waitUntil: 'domcontentloaded' });

  const email = page
    .getByLabel(/email|correo/i)
    .or(page.locator('input[type="email"], input[name="email"]'));

  const password = page
    .getByLabel(/password|contraseñ?a/i)
    .or(page.locator('input[type="password"], input[name="password"]'));

  await expect(email).toBeVisible();
  await expect(password).toBeVisible();

  await email.fill(ADMIN_EMAIL);
  await password.fill(ADMIN_PASSWORD);

  const submit = page
    .getByRole('button', { name: /iniciar|entrar|login|sign in|continuar/i })
    .first();

  await expect(submit).toBeEnabled();
  await submit.click();

  // Esperar: o redirige a /org/* (éxito) o aparece un error en pantalla (fracaso).
  const errorAlert = page.getByRole('alert').first().or(page.locator('[data-state="open"][role="alert"]'));

  await Promise.race([
    page.waitForURL(/\/org(\/|$)/, { timeout: 15_000 }),
    errorAlert.waitFor({ state: 'visible', timeout: 15_000 }),
  ]);

  // Si NO salió de /login y hay alert, fallar con mensaje accionable.
  if (page.url().includes('/login')) {
    let alertText = '';
    if (await errorAlert.count()) {
      alertText = (await errorAlert.innerText().catch(() => ''))?.trim();
    }

    throw new Error(
      [
        `Login no completado: seguimos en ${page.url()}`,
        alertText ? `UI alert: ${alertText}` : 'UI alert: (no pude leer texto)',
        '',
        'Checklist inmediato:',
        '1) Asegurá seed demo/local: npx supabase db reset',
        '2) Confirmá que la app está apuntando a Supabase LOCAL (NEXT_PUBLIC_SUPABASE_URL/ANON_KEY).',
        '3) Credenciales esperadas (docs/smoke-credentials.md): admin@demo.com / prueba123',
      ].join('\n'),
    );
  }

  // OK: ya estamos dentro del /org/*
  await expect(page).toHaveURL(/\/org(\/|$)/);
}
```
````

**Qué te va a decir esto si vuelve a fallar:** el texto real del `alert` (p.ej. “Invalid login credentials”) y un error que te deja 100% claro si es **seed no aplicada** o **env apuntando a un Supabase equivocado**.

### Ejecutá así (para ver el error rápido en consola + trace)

```bash
npx supabase status
npx supabase db reset
npx playwright test e2e/admin-org-config-flow.spec.ts --project=chromium --headed --trace=on
```

Si después de `db reset` sigue saliendo “invalid login credentials”, casi seguro estás logueando contra **otro proyecto** (env vars). En ese caso, pegáme el texto exacto del alert que imprima este patch y lo cerramos en 1 paso.

```

Resultado esperado

Actualizar la función de login del spec E2E y mejorar el diagnóstico cuando el login falla.
```
