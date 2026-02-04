# UX — Learner Navigation Hardening

## Contexto

Endurecer la navegación del Aprendiz con un hub de entrada claro y wiring de navegación coherente sin tocar backend.

## Prompt ejecutado

````txt
Perfecto. Sigamos con **opción 1: navegación coherente**.

## Objetivo del hardening de navegación (Aprendiz)

Que el aprendiz tenga **un solo entrypoint obvio** (“Home”) y desde ahí pueda:

* continuar donde quedó (unidad actual),
* ir a repasar unidades anteriores,
* ver progreso,
* entrar a evaluación final cuando corresponda,
* entender claramente el estado (en_entrenamiento/en_practica/en_riesgo/en_revision/aprobado).

## Plan concreto (rápido, sin inventar backend)

### 1) Definir el “Learner Home” como el hub

Ruta recomendada: **`/learner`** (o `/learner/home` si preferís explícito).
Debe usar **solo data existente** (ideal: `v_learner_training_home` + checks ya existentes).

Contenido mínimo:

* **Header**: programa activo + local (si lo tenemos en el view; si no, solo “Tu entrenamiento”).
* **Status badge + hint** (reusando `status-ui.ts`).
* **CTA principal (solo 1)** según estado:

  * normal/en_practica/en_riesgo → “Continuar entrenamiento”
  * en_revision → “Ver estado de evaluación” (link a `/learner/final-evaluation`)
  * aprobado → “Ver resumen / progreso”
* **Sección Progreso**: % + unidad actual (ya lo tenés).
* **Accesos secundarios** (links chicos):

  * Progreso (`/learner/progress`)
  * Perfil (`/learner/profile`)
  * Repaso: link directo a `current_unit_order` o lista de unidades completadas (según lo que ya exista).

### 2) Re-cablear navegación para que no haya “pantallas huérfanas”

* En layout/nav del aprendiz, el primer item debe ser **Home**.
* Desde Training y Final Evaluation: agregar botón “Volver al Home”.

### 3) Reglas claras de redirección

* Login → manda a **`/learner`** (si rol aprendiz).
* Si un aprendiz entra a `/learner/training` directo: permitir, pero siempre con link visible a Home.

---

## Prompt para Codex CLI (directo y accionable)

Pegale esto:

```txt
Queremos hardening de navegación del Aprendiz.

1) Revisá en el repo si ya existe una ruta /learner (o equivalente) y cómo está armado el layout/nav del aprendiz.
2) Si NO existe, creá un hub "Learner Home" en app/learner/page.tsx (preferido) usando datos existentes (ideal v_learner_training_home).
   - Mostrar status badge + hint reutilizando lib/learner/status-ui.ts
   - CTA principal único según status:
     - en_revision => link a /learner/final-evaluation
     - aprobado => link a /learner/progress
     - resto => link a /learner/training
   - Links secundarios: /learner/progress, /learner/profile, y repaso (si existe ruta /learner/review/[unitOrder], link a la unidad actual o última completada)
3) Cablear navegación:
   - Asegurar que el nav del aprendiz tenga "Home" y que Training/Profile/Progress tengan link de vuelta al Home.
4) No tocar backend/DB. Solo UI wiring.
5) Al final correr npm run lint y npm run build.

Mostrame los archivos tocados y el razonamiento de wiring.
````

---

Si Codex te devuelve que **ya existe un home** pero está pobre, lo endurecemos en lugar de crear uno nuevo. Si te devuelve que no hay nav/layout claro, lo resolvemos ahí primero (porque es la raíz del “flujo coherente”).

```

Resultado esperado

Hub de Aprendiz en `/learner` con navegación coherente y CTAs según estado.

Notas (opcional)

Sin cambios de backend/DB.
```
