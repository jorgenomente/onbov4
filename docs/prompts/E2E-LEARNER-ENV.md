# E2E Learner Env Vars + Run Test

## Contexto

Diagnosticar el fallo por variables de entorno faltantes en el E2E de learner y ejecutar el test con credenciales explícitas del seed.

## Prompt ejecutado

```txt
Perfecto: **el test está funcionando exactamente como debe**.
No hay ningún bug de Playwright ni del flujo. Lo que falló es **configuración explícita de entorno**, y eso es **buena señal**.

Vamos directo y sin rodeos.

---

## ✅ Qué pasó realmente (diagnóstico)

El error dice:

```

Missing required env var: E2E_LEARNER_EMAIL

````

Esto significa:

* El **spec E2E está bien escrito**
* Usa un helper (`e2e/helpers/env.ts`) que **exige credenciales explícitas**
* El test **no asume defaults mágicos** (excelente práctica)

👉 El test aborta **antes de correr**, como corresponde.

---

## ✅ Qué variables de entorno espera el E2E

Según el helper, necesitás definir (mínimo):

* `E2E_LEARNER_EMAIL`
* `E2E_LEARNER_PASSWORD`

Estas credenciales deben corresponder **al learner E2E que ya seedearon**
(en tu caso: el que crearon en `20260131133000_seed_e2e_learner.sql`).

---

## 🔎 Paso 1 — Confirmar el email del learner E2E

Abrí la migración:

```bash
supabase/migrations/20260131133000_seed_e2e_learner.sql
````

Ahí vas a ver algo como:

```sql
-- ejemplo
insert into auth.users (email, ...)
values ('learner-e2e@demo.com', ...);
```

👉 Anotá:

- email exacto
- password exacto (probablemente `prueba123`)

---

## ▶️ Paso 2 — Correr el test con las env vars (rápido)

Desde la raíz del repo:

```bash
E2E_LEARNER_EMAIL=learner-e2e@demo.com \
E2E_LEARNER_PASSWORD=prueba123 \
LLM_PROVIDER=mock \
npm run test:e2e:learner:headed
```

⚠️ Importante:

- **NO** hace falta poner esto en `.env.local`
- Para E2E es mejor pasarlo inline (explícito y seguro)

---

## ✅ Resultado esperado

Si todo está bien:

- El navegador se abre
- El test:
  - loguea al learner E2E
  - entra a `/learner`
  - hace click en “Continuar”
  - ve intro automática
  - envía “hola” → sigue en aprender
  - envía “comenzar”
  - entra a práctica
  - completa práctica
  - vuelve a `/learner`

- El test termina en **PASS** ✅

---

## 🧠 Por qué este diseño es correcto (y profesional)

Esto que tenés ahora es **exactamente lo que querías lograr**:

- ❌ Sin credenciales → el test falla rápido y claro
- ✅ Con credenciales → flujo real, de punta a punta
- 🔒 Sin hardcodear secretos en el repo
- 🔁 Repetible en cualquier máquina / CI

Esto es **nivel SaaS serio**, no demo.

---

## 🧪 Si falla después (qué mirar)

Si el test **arranca pero falla más adelante**, mirá en este orden:

1. Screenshot (`test-failed-1.png`)
2. Video (`video.webm`)
3. Trace:

   ```bash
   npx playwright show-trace test-results/.../trace.zip
   ```

Y clasificá el fallo:

- selector (UI)
- gating lógico
- seed / estado DB
- timing

En cualquiera de esos casos, **el E2E está haciendo su trabajo**.

---

## Próximo paso (hacelo ahora)

👉 Corré el comando con las env vars como arriba.
Después decime solo una cosa:

**¿PASÓ o FALLÓ?**

Si falló, pegá:

- el primer error
- o decime en qué paso se detuvo

Y lo resolvemos en un solo ajuste quirúrgico.

```

## Resultado esperado

Confirmar email/password del seed E2E y ejecutar el test con env vars explícitas.

## Notas

Se deben pasar las variables inline al comando de E2E.
```
