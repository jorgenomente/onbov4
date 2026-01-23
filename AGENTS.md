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

### Flujo obligatorio

1. Crear rama:
   `feature/<lote-x-descripcion>`
2. Commits pequeños y atómicos
3. Merge a `main`
4. Push

La IA **DEBE indicar explícitamente**:

- nombre de la rama
- commits sugeridos
- cuándo mergear

Si un cambio **no amerita commit**, debe decirlo explícitamente.

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

---
