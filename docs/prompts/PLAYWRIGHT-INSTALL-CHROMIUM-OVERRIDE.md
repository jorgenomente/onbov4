# PLAYWRIGHT INSTALL CHROMIUM OVERRIDE

## Contexto

Forzar plataforma arm64 para instalar Chromium con Playwright cuando detecta mac-x64.

## Prompt ejecutado

```txt
PLAYWRIGHT_HOST_PLATFORM_OVERRIDE=mac15-arm64 \
./node_modules/.bin/playwright install chromium
```

## Resultado esperado

Instalación exitosa de Chromium arm64 en el cache de Playwright.
