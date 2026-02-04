# E2E Referente Env Vars

## Contexto

Ajuste de ejecución de E2E: documentar que el helper exige credenciales de Referente para correr un spec de Learner y decidir cómo proceder para correr tests.

## Prompt ejecutado

````txt
Bien. Esto confirma que el helper `getE2ECredentials()` **exige también credenciales de Referente**, aunque este spec sea de Learner. No es un bug del producto; es configuración del harness de E2E.

Tenés 2 caminos:

1. **rápido (para correr ya):** setear las env vars del referente también.
2. **correcto (mejor UX de tooling):** ajustar el helper para que **solo exija** lo que el spec usa (o usar “optional envs” por rol).

Como querés correr ya el test, vamos con (1). Luego, si querés, hacemos (2) para no pedir variables innecesarias.

---

## ✅ Opción 1 — Ejecutar ya (setear env vars del Referente)

### 1) Encontrar credenciales del referente seed

Abrí `docs/smoke-credentials.md` (o el seed que usen para referente). Buscá algo como:

* `referente@demo.com` / `prueba123`
* o similar

Si no querés buscar, corré:

```bash
grep -R "referente" -n docs/smoke-credentials.md supabase/migrations | head -n 50
````

### 2) Corré el test con todas las env vars

Reemplazá los valores del referente por los reales que encuentres:

```bash
E2E_LEARNER_EMAIL=e2e-aprendiz@demo.com \
E2E_LEARNER_PASSWORD=prueba123 \
E2E_REFERENTE_EMAIL=referente@demo.com \
E2E_REFERENTE_PASSWORD=prueba123 \
LLM_PROVIDER=mock \
npm run test:e2e:learner:headed
```

Con eso el helper deja de fallar y el spec por fin corre.

---

## ✅ Opción 2 — Arreglo “bien” (para que el learner spec no pida referente)

Si preferís que el tooling sea limpio, el cambio correcto es:

- en `e2e/helpers/env.ts`: separar `getLearnerCredentials()` y `getReferenteCredentials()`
- o hacer `E2E_REFERENTE_*` opcionales y solo requerirlos en specs que realmente los usan.

Esto evita que **cada test** requiera credenciales de todos los roles.

Si querés, te paso un prompt para Codex que deje esto impecable (sin romper otros specs).

---

## Qué hacer ahora

Para avanzar **ya**, usá el comando con `E2E_REFERENTE_*`.

Si no encontrás rápido las credenciales del referente, pegá el contenido de `docs/smoke-credentials.md` (la sección de referente) o el output del `grep` y te digo exactamente qué valores usar.

```

## Resultado esperado

Guía clara para correr el E2E con credenciales de Referente y referencia de dónde obtenerlas.

## Notas

Se sugiere un ajuste posterior del helper para no exigir credenciales innecesarias por spec.
```
