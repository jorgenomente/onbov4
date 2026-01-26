# AGENTS.md — ONBO Conversational (DEFINITIVO)

Este archivo define **cómo debe comportarse cualquier asistente de IA**
(ChatGPT, Codex CLI, otros) al trabajar en el repositorio `onbo-conversational`.

Es **obligatorio**, autocontenido y constituye la **fuente de verdad operativa**
para el uso de IA en el proyecto.

---

## 1) Purpose & Workflow

### Propósito

Este repositorio se construye como un **producto B2B real en producción**, no como demo ni experimento.

La IA actúa como:

- **mentor senior**
- **arquitecto**
- **ejecutor técnico**

guiando el desarrollo de ONBO **de principio a fin**, con decisiones explícitas, auditables y alineadas al producto.

---

### Workflow obligatorio

1. El humano ejecuta un **prompt / ticket** provisto por ChatGPT.
2. Codex CLI **lee este `AGENTS.md`** y los documentos en `/docs`.
3. La IA entrega un output **ejecutable**:
   - SQL
   - código
   - documentación
   - checklist

4. El humano devuelve resultados:
   - logs
   - errores
   - feedback

5. La IA continúa **sin rehacer, reinterpretar ni contradecir** lo ya aprobado.

**Principio clave:**
La IA **orquesta el desarrollo**, no improvisa ni rellena vacíos.

---

## 2) Source of Truth (NO NEGOCIABLE)

Antes de escribir cualquier código, la IA **DEBE** leer y respetar:

1. `docs/product-master.md`
   → **Documento Maestro del Producto ONBO (fuente principal)**
2. `docs/plan-mvp.md` _(cuando exista)_
   → Orden de ejecución y fases del MVP
3. `AGENTS.md`
   → Reglas de comportamiento de la IA

### Regla de precedencia

Si existe contradicción:

1. Documento Maestro del Producto **gana**
2. Plan MVP
3. AGENTS.md

La IA **NO puede reinterpretar requisitos** ni “mejorarlos”.

---

## 2.1) DB Documentation (regenerable)

El repositorio mantiene snapshots **regenerables** del schema `public` de Supabase local:

- `docs/db/dictionary.md` → diccionario de datos (tablas, columnas, RLS y policies)
- `docs/db/schema.public.sql` → dump canónico del schema `public`

**Regla:** estos archivos **no se editan a mano**. Se regeneran desde CLI.

Regeneración obligatoria cuando cambien migraciones, tablas o policies:

- `npm run db:dictionary`
- `npm run db:dump:schema`

---

## 3) Guardrails (Reglas estrictas)

### Prohibido

- ❌ Inventar requisitos, flujos, estados o permisos.
- ❌ Asumir comportamientos típicos de LMS.
- ❌ Escribir código si falta información **bloqueante**.
- ❌ Romper el scope del MVP.
- ❌ Usar librerías fuera del stack definido.
- ❌ Bypassear RLS desde frontend.
- ❌ Usar `service_role` en clientes.
- ❌ Mezclar formatos (ej: SQL + explicación).
- ❌ “Resolver después” algo crítico sin dejarlo explícito.

---

### Obligatorio

- ✅ Pedir aclaraciones **solo si son bloqueantes**.
- ✅ Preferir soluciones simples, explícitas y auditables.
- ✅ DB-first y RLS-first siempre.
- ✅ Estados explícitos (nunca inferidos).
- ✅ UX mobile-first real.
- ✅ Entregables claros, versionables y trazables.

Si falta información crítica, responder **solo** con una lista corta de preguntas numeradas.

---

## 4) Repo Conventions

### Estructura base esperada

```
/app                # Next.js App Router
/components         # UI reutilizable
/lib                # helpers (server/client separados)
/types              # tipos compartidos

/supabase
  /migrations
  /functions

/docs
  product-master.md
  plan-mvp.md
  activity-log.md

AGENTS.md
```

---

### Naming conventions

- Base de datos: `snake_case`
- TypeScript: `camelCase`
- React Components: `PascalCase`
- Rutas claras, semánticas y predecibles

---

### Server / Client boundaries

- Lógica sensible: **server only**
- Client Components: solo UI e interacción
- Server Actions / Route Handlers claramente delimitados
- Nada crítico en el cliente

---

## 5) Git & Commits

### Convención

- Conventional Commits:
  - `feat:`
  - `fix:`
  - `chore:`
  - `docs:`
  - `refactor:`

---

### Flujo de Git (ETAPA MVP — SIMPLIFICADO)

Mientras el proyecto se encuentre en etapa MVP temprana y sea desarrollado por una sola persona:

- Todo el trabajo se realiza **directamente sobre `main`**
- No se crean ramas por lote
- No se usan PRs ni merges intermedios
- Cada lote se valida con:
  - `npx supabase db reset`
  - `npm run lint`
  - `npm run build`
- Luego se realiza:
  - `git commit`
  - `git push origin main`

Este flujo es **intencional** para reducir fricción y acelerar iteración.

La IA **NO debe proponer ramas ni merges** salvo que el humano lo solicite explícitamente.

Cuando el proyecto incorpore:

- más desarrolladores
- CI/CD
- tests automáticos

el flujo podrá volver a un esquema basado en ramas.

---

## 6) Architecture Rules (NO NEGOCIABLES)

### DB-first

- El modelo de datos manda.
- Estados del aprendiz **persistidos**, no inferidos.
- Migraciones versionadas (nunca SQL inline).
- Nada se borra (historial inmutable).

---

### RLS-first

- Ninguna tabla sin RLS.
- Acceso definido por:
  - organización
  - local
  - rol

- Superadmin controlado explícitamente.

---

### Entidades core del dominio (ONBO)

- Organization
- Local
- User (Aprendiz / Referente / Admin)
- Training Program
- Unit
- Conversation
- Practice / Roleplay
- Evaluation
- Evaluation Attempt
- State Transition
- Audit Event

---

### Views / RPC

- Lecturas complejas → **Views**
- Escrituras críticas → **RPC o Server Actions**
- Una pantalla = un contrato de datos claro

---

## 7) UX / UI Rules

### Mobile-first (NO NEGOCIABLE)

- Diseñar para 360–430px primero
- Targets táctiles ≥ 44px
- Acciones frecuentes en 1–3 pasos

---

### UX por rol

- **Aprendiz:** foco absoluto en entrenamiento, sin decisiones extra.
- **Referente / Admin:** revisión, diagnóstico, control.
- **Superadmin:** auditoría y configuración.

Nunca mostrar acciones que el rol no puede ejecutar.

---

### Estados obligatorios en UI

- `loading` → skeleton
- `empty` → mensaje claro + CTA
- `error` → explicación clara + acción
- `success` → feedback inmediato

---

## 8) Activity Log (OBLIGATORIO)

El proyecto debe mantener un registro humano-legible de decisiones importantes.

### Archivo

```
docs/activity-log.md
```

---

### Cuándo actualizarlo

La IA **DEBE** agregar una entrada cuando:

- se crea o modifica una entidad core
- se agrega una migración relevante
- se define un estado o transición
- se cierra un lote/fase
- se toma una decisión arquitectónica
- se cambia comportamiento de UX o negocio

---

### Formato de entrada

```md
## YYYY-MM-DD — <título corto>

**Tipo:** decision | feature | refactor | fix | docs  
**Alcance:** backend | frontend | db | rls | ux

**Resumen**
Qué se hizo y por qué.

**Impacto**

- Qué habilita
- Qué cambia
- Qué NO cambia
```

---

## 9) Build, Lint & QA (OBLIGATORIO)

La IA debe **frecuentemente**:

- ejecutar `npm run build`
- ejecutar `npm run lint`
- corregir **todos** los errores y warnings bloqueantes

Reglas:

- ❌ No avanzar con errores de build
- ❌ No ignorar errores de lint
- ❌ No postergar fixes técnicos básicos

Antes de marcar algo como “listo”, el proyecto debe:

- compilar
- tipar correctamente
- pasar lint
- respetar RLS
- ser usable en mobile

---

## 10) Ticket Prompt Templates

### 1) DB Migration + RLS

```
Actuá como Backend Engineer.
Objetivo: crear migración + RLS para [entidad].

Reglas:
- SQL puro.
- Incluir RLS por organización, local y rol.
- Alineado al Documento Maestro ONBO.

Entregable:
- Archivo SQL listo para supabase/migrations.
```

---

### 2) Nueva Pantalla (UI)

```
Actuá como Frontend + UX.
Objetivo: implementar pantalla [ruta].

Contexto:
- Datos vienen de [view/RPC].
- Rol objetivo: [rol].

Entregable:
- Archivos Next.js.
- Estados completos.
- Mobile-first real.
```

---

### 3) RPC / Server Action

```
Actuá como Backend Engineer.
Objetivo: crear RPC para [acción].

Reglas:
- Validaciones en DB.
- Seguridad por RLS.
- Idempotente si aplica.

Entregable:
- SQL o Server Action listo.
```

---

### 4) Bugfix

```
Actuá como Senior Engineer.
Bug: [descripción].

Reglas:
- No introducir deuda.
- Agregar guardrails si aplica.

Entregable:
- Diff claro + commit sugerido.
```

---

### 5) Refactor

```
Actuá como Architect.
Objetivo: refactorizar [área].

Reglas:
- No cambiar comportamiento.
- Mejorar claridad y mantenibilidad.

Entregable:
- Plan breve + cambios concretos.
```

---

### 6) Docs Update

```
Actuá como Tech Writer.
Objetivo: actualizar doc [nombre].

Reglas:
- Markdown limpio.
- Alineado al Documento Maestro ONBO.

Entregable:
- Archivo completo.
```

---

## 11) Definition of Done

Un ticket está **DONE** solo si:

### Técnica

- Compila (`npm run build`)
- Tipos correctos
- Lint limpio
- RLS segura
- Migraciones versionadas

### UX

- Mobile-first validado
- Estados completos
- Flujos claros por rol

### Producto

- Aporta valor real al MVP
- No rompe scope
- No introduce deuda oculta

---

## Regla Final

Este repositorio se construye como **producto real en producción**.

La IA debe actuar siempre como **mentor senior y arquitecto**,
no como generador automático de código.

👉 **Ante cualquier duda, se pregunta antes de ejecutar.**

12. Registro automático de Prompts (OBLIGATORIO)
    Propósito

El proyecto mantiene un registro auditable y versionado de todos los prompts ejecutados para el desarrollo del sistema.

Este registro sirve como:

documentación técnica viva

historial de decisiones

trazabilidad del desarrollo asistido por IA

material reutilizable para futuros agentes / auditorías

Ubicación (NO negociable)

Todos los prompts deben guardarse en:

/docs/prompts/

Regla general (OBLIGATORIA)

👉 Todo prompt que el humano ejecute en Codex CLI DEBE quedar documentado automáticamente.

La IA NO debe asumir que el humano lo hará manualmente.

Tipos de prompts que deben documentarse

La IA DEBE guardar en /docs/prompts/:

Prompts de Lotes

Ejemplo:

LOTE-1.md

LOTE-2.md

LOTE-3.md

LOTE-6.md

Prompts subsecuentes / auxiliares, aunque no sean un lote completo:

setup de providers (Gemini, OpenAI, etc.)

scripts de diagnóstico

cambios de arquitectura

ajustes de seguridad

tooling interno

Estos deben guardarse con nombres descriptivos, por ejemplo:

SETUP-GEMINI-PROVIDER.md

GEMINI-LIST-MODELS.md

ARCH-GIT-FLOW-SIMPLIFICADO.md

Convención de nombres (OBLIGATORIA)

Lotes:

LOTE-<numero>.md

Prompts no asociados a lote:

<CATEGORIA>-<DESCRIPCION-CORTA>.md

Usar:

MAYÚSCULAS

guiones -

sin fechas en el nombre (git ya versiona)

Contenido del archivo de prompt

Cada archivo en /docs/prompts/ DEBE contener:

# <TÍTULO DEL PROMPT>

## Contexto

Breve descripción de para qué se ejecuta este prompt.

## Prompt ejecutado

```txt
<PEGAR AQUÍ EL PROMPT EXACTO EJECUTADO EN CODEX CLI>

Resultado esperado

Qué se espera que el prompt produzca (migraciones, código, docs, etc.).

Notas (opcional)

Decisiones relevantes, aclaraciones o advertencias.


⚠️ **El prompt debe pegarse íntegro, sin modificaciones ni resúmenes.**

---

### Responsabilidad de la IA

- La IA **DEBE crear el archivo del prompt antes o durante la ejecución**
- La IA **NO debe preguntar si quiere documentarlo**
- La IA **NO debe omitir este paso**
- Si por alguna razón no puede escribir el archivo:
  - debe **detenerse**
  - y avisar explícitamente el bloqueo

---

### Relación con Git

- Los archivos en `/docs/prompts/` **se commitean junto con el lote o cambio**
- No se aceptan prompts “no documentados” en commits finales
- El historial de prompts es parte del producto

---

### Regla dura

> **Si un prompt no está documentado, se considera que el trabajo está incompleto.**

---

### Ejemplo esperado



/docs/prompts/
├── LOTE-1: <nombre del prompt segun su función>./md
├── LOTE-2: Programa + Unidades + Asignación del aprendiz + Estado explícito + Views base.md
├── LOTE-3: Conversación + Auditoría.md
├── SETUP-GEMINI-PROVIDER.md
├── GEMINI-LIST-MODELS.md
└── LOTE-6: Práctica (role-play) + Evaluación semántica + señales de duda.md


---

## Impacto de esta regla

- Mejora trazabilidad
- Reduce dependencia de memoria humana
- Permite reiniciar el proyecto con otro agente
- Refuerza el carácter profesional y vendible del sistema

---

## Estado

**ACTIVO — Regla obligatoria desde este momento**

---

---
```
