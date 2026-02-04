# PLAYWRIGHT INSTALL CHROMIUM DIAGNOSE

## Contexto

Diagnóstico de instalación de Playwright/Chromium cuando `npx playwright install` no hace nada en macOS.

## Prompt ejecutado

````txt
Perfecto, gracias por aclararlo. Acá el punto clave es este:

> **“no hace nada”** cuando corrés `npx playwright install`

Eso **no es normal**, y ya no es un tema de ONBO ni del test: es **cómo se está resolviendo Playwright en tu entorno local**. Vamos a destrabarlo de forma **determinística**, paso a paso, hasta que *sí o sí* se instale Chromium.

---

## 🧠 Diagnóstico probable (por experiencia en macOS)

Cuando `npx playwright install` “no hace nada”, suele ser **una de estas 3 causas**:

1. **Node/NPM resolviendo otro `playwright` que no es el del proyecto**
2. **Playwright instalado pero el binario no está accesible**
3. **Descarga bloqueada / cache roto**

Vamos a descartar una por una.

---

## PASO 1 — Ver si Playwright realmente existe en el proyecto

Desde la raíz del repo:

```bash
ls node_modules/@playwright
````

### Esperado

```text
test
```

Si **NO existe**, entonces Playwright **no está instalado** aunque el repo lo asuma.

👉 En ese caso, corré:

```bash
npm install -D @playwright/test
```

y recién después seguimos.

---

## PASO 2 — Ejecutar el binario local explícitamente (clave)

En lugar de `npx`, ejecutemos **el binario exacto** del proyecto:

```bash
./node_modules/.bin/playwright install chromium
```

⚠️ Esto evita cualquier problema de resolución de `npx`.

### Resultado esperado

Vas a ver logs tipo:

```text
Downloading Chromium 1xx.x.x (playwright build)
Chromium downloaded to ~/.cache/ms-playwright/...
```

Si **esto funciona**, ya está: el problema era `npx`.

---

## PASO 3 — Forzar salida verbose (si sigue “silencioso”)

```bash
DEBUG=pw:install ./node_modules/.bin/playwright install chromium
```

Esto **no puede quedar en silencio**.
Si falla, va a mostrar exactamente dónde.

---

## PASO 4 — Ver si Chromium ya está descargado (por si acaso)

```bash
ls ~/.cache/ms-playwright
```

Si ves carpetas tipo:

```text
chromium-xxxx
```

👉 **ya está instalado** y el error viene de otro lado (raro, pero posible).

---

## PASO 5 — Solución nuclear (solo si todo lo anterior falla)

Esto limpia **solo Playwright**, no todo el repo:

```bash
rm -rf ~/.cache/ms-playwright
rm -rf node_modules/@playwright
rm -rf node_modules/.bin/playwright
npm install
./node_modules/.bin/playwright install chromium
```

---

## PASO 6 — Verificación final (no sigas sin esto)

Estos **tres comandos deben funcionar**:

```bash
./node_modules/.bin/playwright --version
./node_modules/.bin/playwright install chromium
ls ~/.cache/ms-playwright
```

Si eso pasa, **Chromium está listo**.

---

## PASO 7 — Volver a correr el E2E (comando final)

```bash
E2E_LEARNER_EMAIL=e2e-aprendiz@demo.com \
E2E_LEARNER_PASSWORD=prueba123 \
E2E_REFERENTE_EMAIL=referente@demo.com \
E2E_REFERENTE_PASSWORD=prueba123 \
LLM_PROVIDER=mock \
npm run test:e2e:learner:headed
```

---

## Qué necesito ahora (para cerrar esto ya)

Decime **solo una cosa** (copiá/pegá):

- ¿Qué output te da este comando?

```bash
./node_modules/.bin/playwright install chromium
```

Con eso te digo **exactamente** el siguiente ajuste.
Estamos en el último bloqueo de infraestructura, después de esto el flujo corre.

```

## Resultado esperado

Identificar si el binario local de Playwright instala Chromium correctamente y obtener logs para siguiente paso.
```
