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
