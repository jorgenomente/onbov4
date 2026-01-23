## 2026-01-23 — Lote 2 modelo de entrenamiento + vistas base

**Tipo:** feature  
**Alcance:** db | rls

**Resumen**
Se agrega el modelo de entrenamiento (programas, unidades, asignacion por aprendiz), estado explicito y transiciones append-only, con RLS estricta y vistas base para aprendiz y referente/admin.

**Impacto**

- Habilita progreso y estado del aprendiz con trazabilidad
- Define contratos de lectura para pantallas base
- Mantiene writes restringidos para flujos controlados

**Checklist RLS (manual)**

- Aprendiz: puede leer v_learner_training_home y v_learner_progress (solo propio)
- Referente: puede leer v_referente_learners para su local
- Admin Org: puede leer aprendices de su organizacion
- Superadmin: puede leer todo

## 2026-01-23 — Lote 1 base multi-tenant + roles

**Tipo:** feature  
**Alcance:** db | rls

**Resumen**
Se crea la base multi-tenant con organizations, locals y profiles, enum de roles y helpers para derivar contexto desde auth.uid(), con RLS estricta por org/local/rol.

**Impacto**

- Habilita multi-tenancy segura y roles base para el MVP
- Define helpers de contexto para políticas y futuras queries
- No incluye flujos de creación desde cliente

**Checklist RLS (manual)**

- Usuario autenticado con profile: puede leer solo su profile
- No puede leer profiles ajenos
- Puede leer su local; admin_org ve locales de su org; superadmin ve todo

## 2026-01-23 — Resend setup base

**Tipo:** feature  
**Alcance:** backend

**Resumen**
Se agrega inicializacion server-only de Resend y helper para envio de emails transaccionales.

**Impacto**

- Habilita integrar invitaciones y notificaciones via Resend
- Centraliza validacion de variables de entorno necesarias
- No cambia el flujo de UI ni permisos
