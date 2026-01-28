# SUBLOTE-M3-ALERTS-INBOX

## Contexto

Post-MVP 2 / Sub-lote M.3. UI read-only de alert_events para referente/admin.

## Prompt ejecutado

```txt
Post-MVP 2 / Sub-lote M.3 — UI Referente/Admin: Inbox de alert_events (read-only)

Contexto:
Ya existe public.alert_events (append-only + RLS) y se emiten eventos desde M.2.

Objetivo:
Agregar una UI mínima (read-only) para que referente/admin_org vean un inbox
de eventos recientes, sin notificaciones externas, sin acciones.

Reglas:
- NO migraciones DB.
- NO enviar emails/push.
- Read-only: solo SELECT a alert_events.
- RLS manda: no bypass, no service_role.
- Mobile-first, simple.
- No dashboards, no comparativos.

Tareas:

1) Nueva ruta:
- /referente/alerts (o ubicación equivalente en el backoffice del referente)
- Agregar entry point en navegación existente (si hay sidebar).

2) Query server-side:
- Leer últimos 50 eventos de alert_events ordenados por created_at desc.
- Además traer nombre del learner (join a profiles para display):
  - alert_events.learner_id -> profiles (nombre)
- NO select *.

3) Render:
- Lista o tabla simple con:
  - created_at (formato legible)
  - alert_type (map a label)
  - learner (nombre)
  - link contextual:
     - si source_table = 'learner_review_validations_v2' -> link a /referente/review/[learnerId]
     - si source_table = 'final_evaluation_attempts' -> link a /referente/review/[learnerId]
  - resumen de payload (solo keys relevantes, sin mostrar JSON crudo si es muy grande)

4) Acceso:
- Solo roles: referente, admin_org, superadmin.
- Aprendiz: 404 o no autorizado fail-closed.

5) QA manual:
- Como referente: ver solo eventos de su local.
- Como admin_org: ver eventos de toda la org.
- Confirmar links llevan al detalle del learner.
- Confirmar que no hay writes.

Entregables:
- Nuevas páginas/componentes necesarios
- docs/activity-log.md actualizado con M.3 + QA

NO agregar filtros avanzados; si hace falta, solo “tipo” como dropdown opcional.
```

Resultado esperado

UI read-only de alert_events en /referente/alerts con listado y links.

Notas (opcional)

Sin migraciones ni wiring.
