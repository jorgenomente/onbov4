## 2026-01-26 — E2E smoke tests con Playwright

**Tipo:** feature  
**Alcance:** frontend | qa | docs

**Resumen**
Se agregan tests E2E mínimos con Playwright para validar regresiones críticas (login, evaluación final sin refresh y cola de revisión), con data-testid mínimos y guía de ejecución.

**Impacto**

- Smoke tests reproducibles con Supabase local y seed demo
- Cobertura mínima del flujo crítico de evaluación final
- No se agregan bypasses ni endpoints de test

## 2026-01-26 — Mock LLM provider para QA local

**Tipo:** feature  
**Alcance:** backend | qa

**Resumen**
Se agrega un provider LLM `mock` para entornos no productivos que devuelve respuestas determinísticas (incluyendo JSON de evaluación) y permite correr E2E sin depender de APIs externas.

**Impacto**

- E2E y QA local pueden ejecutarse sin consumir cuotas externas
- Producción bloquea el uso de `LLM_PROVIDER=mock`
- No cambia RLS ni modelo de datos

## 2026-01-26 — Evaluación final: estado en revisión consistente

**Tipo:** fix  
**Alcance:** frontend | ux

**Resumen**
Se muestra el estado “Evaluación enviada / en revisión” cuando el aprendiz ya está en `en_revision` aunque no haya intento activo, evitando que el flujo vuelva a gating por cooldown.

**Impacto**

- La UI respeta el estado del aprendiz tras finalizar la evaluación
- Evita confusión por mensajes de cooldown luego de completar
- No cambia schema ni RLS

## 2026-01-26 — Audit checkpoint y mapa de avance

**Tipo:** docs  
**Alcance:** docs

**Resumen**
Se crea `docs/audit-checkpoint1.md` como mapa vivo de avance y se agrega la regla en AGENTS.md para mantenerlo actualizado en cada hito.

**Impacto**

- Centraliza el estado real del proyecto y el plan de continuidad
- Complementa el activity log con un mapa operativo de avances
- No cambia comportamiento del producto ni del schema

## 2026-01-25 — Lote 8 evaluación final

**Tipo:** feature  
**Alcance:** db | rls | backend | ux

**Resumen**
Se implementa la Evaluación Final con configuración, intentos, preguntas/respuestas y evaluaciones semánticas, incluyendo cooldown, bloqueo y recomendación del bot.

**Impacto**

- Evaluación final auditable y append-only para respuestas
- Recomendación del bot sin reemplazar decisión humana
- Estado del aprendiz pasa a en_revision al finalizar

**Checklist**

- Respeta cooldown y max_attempts
- Intenta solo si entrenamiento completo
- Registro de evaluaciones por unidad

## 2026-01-25 — Lote 7.1 emails de decisión

**Tipo:** feature  
**Alcance:** db | backend

**Resumen**
Se agregan emails transaccionales de decisiones humanas con Resend, registro append-only e idempotencia por decision_id.

**Impacto**

- El aprendiz recibe notificación de aprobado o refuerzo
- Se registran envíos con estado sent/failed
- Fail-closed si faltan claves o email del aprendiz

**Checklist**

- No duplica emails por decision_id
- Decisión no se revierte si email falla

## 2026-01-25 — Lote 7 panel de revisión + decisiones humanas

**Tipo:** feature  
**Alcance:** db | rls | backend | ux

**Resumen**
Se agrega el panel de revisión para referentes/admin, decisiones humanas append-only y vistas de evidencia, con acciones server-only y sin emails.

**Impacto**

- Decisiones humanas quedan auditadas y trazables
- Referentes/Admin pueden revisar evidencias y decidir
- Emails se difieren al Lote 7.1

**Checklist**

- Referente ve solo su local, admin_org su org
- Aprendiz no accede al panel
- Decisiones no se sobrescriben (append-only)

## 2026-01-25 — Lote 6 práctica + evaluación semántica

**Tipo:** feature  
**Alcance:** db | rls | backend

**Resumen**
Se agrega práctica integrada con escenarios, intentos y evaluaciones append-only, más un evaluador server-only con señales de duda y salida JSON estricta.

**Impacto**

- Role-play persistente dentro del flujo de chat
- Evaluación semántica grounded en knowledge permitido
- Cierre de intento vía eventos append-only (sin updates)

**Checklist**

- Sin API key: falla con error claro (fail-closed)
- startPracticeScenario crea conversation + attempt
- submitPracticeAnswer persiste mensaje + evaluación + feedback

## 2026-01-25 — Gemini CLI scripts

**Tipo:** docs  
**Alcance:** backend

**Resumen**
Se agregan scripts CLI para listar modelos Gemini y ejecutar un smoke test usando la API key configurada.

**Uso**

- Env vars:
  - LLM_PROVIDER=gemini
  - GEMINI_API_KEY=... (requerida)
  - GEMINI_MODEL=gemini-2.5-flash (opcional)
- Listar modelos: npm run gemini:list-models
- Smoke test: npm run gemini:smoke

**Nota**
La disponibilidad de modelos depende de lo que devuelve la API con tu key.

## 2026-01-25 — Gemini provider support (LLM)

**Tipo:** feature  
**Alcance:** backend

**Resumen**
Se agrega soporte Gemini en la capa provider-agnostic sin romper OpenAI, con fail-closed y configuracion por entorno.

**Impacto**

- Permite seleccionar LLM via LLM_PROVIDER=gemini
- Modelo default: gemini-2.5-flash (si GEMINI_MODEL no está definido)
- No habilita grounding web ni herramientas externas

**Env vars**

- LLM_PROVIDER=gemini
- GEMINI_API_KEY
- GEMINI_MODEL (opcional, default gemini-2.5-flash)

**Config**

- .env.local (dev)
- Vercel Environment Variables (prod)

## 2026-01-25 — Lote 5 chat e2e + provider agnostic

**Tipo:** feature  
**Alcance:** backend | db | rls

**Resumen**
Se agrega capa LLM provider-agnostic, server action para mensajes del aprendiz, y policies de insert server-only para conversaciones/mensajes.

**Impacto**

- Chat end-to-end con persistencia append-only
- Fail-closed si no hay provider configurado
- Contexto estrictamente grounded en conocimiento permitido

**Env vars**

- OPENAI_API_KEY
- OPENAI_MODEL

**Checklist**

- Sin provider configurado: falla con error claro
- Con provider: persiste mensaje aprendiz + bot

## 2026-01-23 — Lote 4 knowledge grounding + context builder base

**Tipo:** feature  
**Alcance:** db | rls

**Resumen**
Se crean tablas de conocimiento y mapeo por unidad con RLS estricta, y un context builder server-only que garantiza grounding en conocimiento permitido.

**Impacto**

- El bot queda limitado a conocimiento cargado por unidad activa + pasadas
- Se separa claramente DB (grounding) de proveedor IA
- Writes quedan reservados para flujos server-only

**Checklist RLS (manual)**

- Aprendiz no puede acceder a knowledge de otra org/local
- knowledge con local_id NULL es visible en su org

## 2026-01-23 — Lote 3 conversacion y auditoria base

**Tipo:** feature  
**Alcance:** db | rls

**Resumen**
Se crean conversaciones, mensajes y evaluaciones base con reglas append-only, RLS estricta y vistas de lectura para aprendiz y referente/admin.

**Impacto**

- Habilita persistencia y auditoria completa del chat
- Define contratos de lectura para UI
- Escrituras reservadas a flujos server-only (RPC/Server Actions)

**Checklist RLS (manual)**

- Aprendiz: ve solo sus conversaciones y mensajes
- Referente: ve conversaciones de su local
- Admin Org: ve conversaciones de locales de su organizacion
- Superadmin: ve todo
- No se permiten UPDATE/DELETE en conversaciones ni mensajes

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

## 2026-01-25 — Fix build por RESEND_FROM missing

**Tipo:** fix  
**Alcance:** backend

**Resumen**
Se evita leer variables de entorno de Resend en import-time para que el build no falle si faltan envs; ahora se leen solo al enviar email.

**Impacto**

- Build de Vercel no se rompe al recolectar páginas que importan acciones de email
- Las envs siguen siendo obligatorias en runtime al enviar emails
- No cambia el flujo de aprobación ni la lógica de envío

## 2026-01-25 — Lote 8.5 Auth UI mínima

**Tipo:** feature  
**Alcance:** backend | frontend | ux

**Resumen**
Se agrega login básico, logout, protección de rutas por sesión y redirección por rol usando Supabase SSR. Se definen rutas públicas/privadas, middleware de sesión y layouts con enforcement de rol.

**Impacto**

- Acceso por email+password para usuarios existentes de Supabase Auth
- Redirección segura por rol tras login y bloqueo de rutas no permitidas
- Logout server-side y rutas protegidas por sesión

**Cómo testear (manual)**

- /login y credenciales válidas → redirige por rol
- /learner/\* sin sesión → /login?next=...
- /login con sesión → /auth/redirect

## 2026-01-25 — Migración middleware → proxy

**Tipo:** refactor  
**Alcance:** frontend

**Resumen**
Se migra el archivo de middleware a proxy para alinearse con la convención de Next.js 16 y eliminar el warning de deprecación.

**Impacto**

- Mantiene la misma protección de rutas por sesión
- Elimina el warning de build sobre middleware
- No cambia flujos de login/logout

## 2026-01-25 — Fix env Supabase en cliente

**Tipo:** fix  
**Alcance:** frontend

**Resumen**
Se corrige el acceso a variables de entorno públicas en el cliente para evitar undefined en runtime y permitir login.

**Impacto**

- Login deja de romper por NEXT_PUBLIC_SUPABASE_URL undefined
- Mantiene uso de variables públicas en build-time
- Sin cambios en flujos de auth

## 2026-01-25 — Chat mínimo en entrenamiento

**Tipo:** feature  
**Alcance:** frontend

**Resumen**
Se conecta la pantalla /learner/training al server action existente para enviar mensajes y mostrar el hilo actual con grounding fail-closed.

**Impacto**

- Aprendiz ve el chat y puede enviar mensajes
- Se refresca el hilo tras cada envío
- Errores de grounding se muestran con mensaje user-friendly

## 2026-01-25 — CTA práctica en entrenamiento

**Tipo:** feature  
**Alcance:** frontend | ux

**Resumen**
Se agrega CTA para iniciar práctica desde /learner/training y se conecta el envío de respuestas con el motor de práctica existente.

**Impacto**

- El aprendiz puede iniciar práctica y ver el prompt en el chat
- Las respuestas se evalúan vía server action y se refresca el hilo
- Errores del evaluador se muestran con mensaje amigable

## 2026-01-25 — Seed práctica demo/local

**Tipo:** fix  
**Alcance:** db

**Resumen**
Se agrega un seed mínimo de practice_scenarios para programas activos del entorno demo/local, evitando errores de escenario inexistente.

**Impacto**

- Iniciar práctica ya no falla por falta de escenarios
- Se mantiene lógica RLS y append-only existente
- No cambia esquema ni flujos de evaluación

## 2026-01-25 — Seed demo completo (Auth + datos)

**Tipo:** feature  
**Alcance:** db | backend

**Resumen**
Se agrega seed demo/local completo para reset reproducible: org/local/programa, unidades, knowledge, práctica, evaluación final, usuarios Auth y perfiles.

**Impacto**

- `npx supabase db reset` deja el entorno listo para smoke tests
- Usuarios demo pueden loguearse con password común
- Chat/práctica/evaluación tienen datos base cargados

## 2026-01-25 — Parser robusto evaluacion practica

**Tipo:** fix  
**Alcance:** backend | ux

**Resumen**
Se endurece el parseo del output del evaluador de practica para aceptar JSON con code fences o texto extra y fallar en modo seguro sin romper la UI.

**Impacto**

- Evita 500 cuando el LLM devuelve markdown o contenido extra
- Devuelve feedback fallback y registra logs truncados para depuracion
- No cambia esquema ni RLS

## 2026-01-25 — Gating y parse seguro en evaluación final

**Tipo:** fix  
**Alcance:** backend | ux

**Resumen**
Se agrega verificación de recorrido completo (ultima unidad) con mensajes amigables en el gating, loading state en UI y se endurece el parseo del evaluador final para evitar crashes por JSON con markdown.

**Impacto**

- Bloquea inicio si faltan unidades o config y muestra motivo claro
- Evita fallas de parseo del evaluador con fallback seguro
- No cambia esquema ni RLS

## 2026-01-25 — Logs de gating evaluación final

**Tipo:** fix  
**Alcance:** backend

**Resumen**
Se agregan logs en modo dev para diagnosticar bloqueos del gating de evaluación final (progreso, unidad y config).

**Impacto**

- Permite detectar rápidamente por qué se bloquea el inicio
- No cambia el comportamiento en producción
- No cambia esquema ni RLS

## 2026-01-25 — Log de error en carga de config final

**Tipo:** fix  
**Alcance:** backend

**Resumen**
Se agrega logging en desarrollo cuando falla la carga de final_evaluation_configs para diagnosticar bloqueos por config_missing.

**Impacto**

- Facilita detectar errores de lectura de config en gating
- No cambia comportamiento en producción
- No cambia esquema ni RLS

## 2026-01-26 — RLS para configs de evaluación final (aprendiz)

**Tipo:** fix  
**Alcance:** db | rls

**Resumen**
Se habilita lectura de final_evaluation_configs para el aprendiz del programa correspondiente, evitando bloqueos por config_missing en la UI.

**Impacto**

- El aprendiz puede iniciar evaluación final si cumple gating
- No expone configs de otros programas
- No cambia schema ni flujo de aprobación

## 2026-01-26 — Seed aprendiz demo listo para evaluación final

**Tipo:** feature  
**Alcance:** db

**Resumen**
Se agrega seed idempotente que deja al aprendiz demo con progreso completo y unidad final activa para habilitar la evaluación final tras db reset.

**Impacto**

- `npx supabase db reset` deja el demo listo para /learner/final-evaluation
- Evita pasos manuales de actualización en QA
- No cambia esquema ni RLS

## 2026-01-26 — Derivar intento activo en submit de evaluación final

**Tipo:** fix  
**Alcance:** backend

**Resumen**
Se elimina la dependencia del attemptId enviado por el cliente y se resuelve el intento activo del aprendiz en servidor para evitar Forbidden por ids stale.

**Impacto**

- Submit de respuestas usa siempre el intento vigente
- Reduce errores por refresh o sesión desfasada
- No cambia esquema ni RLS

## 2026-01-26 — Hardening attempt activo en evaluación final

**Tipo:** fix  
**Alcance:** backend

**Resumen**
Se resuelve el intento activo una sola vez por request y se reutiliza para validar respuestas y finalizar, evitando races por reconsulta.

**Impacto**

- El submit ya no depende de un lookup posterior de intento activo
- Reduce errores por refresh o cambios de estado
- No cambia esquema ni RLS

## 2026-01-26 — Fail-loud al insertar respuestas de evaluación final

**Tipo:** fix  
**Alcance:** backend

**Resumen**
Se agrega logging detallado y mensaje de error amigable cuando falla el insert en final_evaluation_answers.

**Impacto**

- Expone errores reales (RLS/columns) en el flujo de evaluación
- Facilita depuración sin cambiar schema ni RLS
- Mantiene comportamiento seguro en producción

## 2026-01-26 — Reuso del client SSR en submit de evaluación final

**Tipo:** fix  
**Alcance:** backend

**Resumen**
El submit de respuestas usa el Supabase client SSR autenticado (con cookies) para evitar inserts anonimos que fallen por RLS.

**Impacto**

- Inserciones de final_evaluation_answers usan auth.uid() correcto
- Reduce fallas silenciosas por cliente sin sesion
- No cambia esquema ni RLS

## 2026-01-26 — Revalidación de ruta en evaluación final

**Tipo:** fix  
**Alcance:** frontend | backend

**Resumen**
Se agrega revalidatePath en el submit de evaluación final para refrescar el Server Component y avanzar de pregunta sin refresh manual.

**Impacto**

- La UI avanza a la siguiente pregunta tras enviar respuesta
- No cambia esquema ni RLS
- Mantiene el flujo existente de evaluación

## 2026-01-26 — Seed práctica demo unidad 2 (local)

**Tipo:** fix  
**Alcance:** db

**Resumen**
Se agrega un escenario de práctica para la unidad 2 del programa demo en el local demo, evitando errores por ausencia de escenarios.

**Impacto**

- El botón de práctica ya encuentra un escenario válido
- No cambia esquema ni RLS
- Mantiene lógica append-only

## 2026-01-27 — Fix RLS recursión en decisiones de revisión

**Tipo:** fix  
**Alcance:** db | rls

**Resumen**
Se elimina la policy auto-referencial en learner_review_decisions que generaba recursión infinita y se reemplaza por una policy simple para aprendiz.

**Impacto**

- Permite insertar decisiones y leer decisiones propias sin error de recursión
- No cambia lógica de negocio ni estados
- Mantiene alcance por rol

## 2026-01-27 — Historial visible de decisiones de revisión

**Tipo:** feature  
**Alcance:** frontend | backend | db | rls

**Resumen**
Se agrega snapshot del revisor en learner_review_decisions y se muestra el historial completo de decisiones en /learner/training, /learner/final-evaluation y /referente/review/[id].

**Impacto**

- Aprendiz y referente ven motivos, fecha/hora y autor de cada decisión
- El historial queda visible sin ocupar demasiado espacio (scroll compacto)
- No cambia reglas de negocio ni estados

## 2026-01-27 — Reintentos ante errores temporales del LLM

**Tipo:** fix  
**Alcance:** backend

**Resumen**
Se agrega retry con backoff para respuestas 5xx/429/timeout en el proveedor LLM para evitar fallas por sobrecarga temporal.

**Impacto**

- Reduce errores 503 en evaluación final y chat
- No cambia prompts ni lógica de evaluación
- Mantiene mismo proveedor configurado

## 2026-01-27 — RLS de perfiles para cola de revisión

**Tipo:** fix  
**Alcance:** db | rls

**Resumen**
Se habilita lectura de perfiles por admin_org/referente dentro de su alcance para destrabar vistas que combinan learner_trainings con profiles (v_review_queue).

**Impacto**

- Referentes ven aprendices en revisión de su local
- Admin org ve perfiles dentro de su organización
- Mantiene aislamiento entre organizaciones

## 2026-01-27 — Fix recursión RLS en helpers de contexto

**Tipo:** fix  
**Alcance:** db | rls

**Resumen**
Se convierten current_profile/current_role/current_org_id/current_local_id en SECURITY DEFINER con row_security = off para evitar recursión al evaluar policies.

**Impacto**

- Evita errores de stack depth al consultar tablas con RLS
- Destraba gating de evaluación final y colas de revisión
- Mantiene aislamiento por rol/org/local

## 2026-01-27 — Revalidación inmediata tras decisiones de revisión

**Tipo:** fix  
**Alcance:** frontend | backend

**Resumen**
Las acciones de aprobar/pedir refuerzo revalidan rutas y redirigen al detalle para reflejar el historial sin refresh manual.

**Impacto**

- Historial se actualiza al instante en /referente/review/[id]
- La cola de revisión también se revalida
- No cambia lógica de decisiones ni emails

## 2026-01-27 — Roadmap post‑MVP registrado

**Tipo:** docs  
**Alcance:** docs

**Resumen**
Se incorpora `docs/roadmap-product-final.md` como plan operativo post‑MVP y se referencia en AGENTS.md.

**Impacto**

- Fuente adicional de contexto para continuar el desarrollo
- Define fases y checkpoints hacia producto final
- No cambia comportamiento funcional

## 2026-01-27 — Regla de regeneración de docs de DB

**Tipo:** docs  
**Alcance:** docs

**Resumen**
Se explicita en AGENTS.md que los snapshots de DB deben regenerarse y commitearse ante cualquier cambio en migraciones, tablas, policies, views o funciones.

**Impacto**

- Evita desalineación entre schema real y docs
- Refuerza trazabilidad técnica
- No cambia comportamiento funcional

## 2026-01-27 — Shell de navegación Aprendiz con tabs

**Tipo:** feature  
**Alcance:** frontend

**Resumen**
Se agrega navegación con tabs para Aprendiz y se crean páginas placeholder de Progreso y Perfil.

**Impacto**

- Tabs visibles: Entrenamiento, Progreso, Perfil
- No cambia lógica de entrenamiento ni datos
- Prepara el terreno para Sub‑lotes B y C

## 2026-01-27 — Progreso del aprendiz y repaso lectura

**Tipo:** feature  
**Alcance:** frontend

**Resumen**
Se implementa /learner/progress con estado, avance y lista de unidades. Se agrega /learner/review/[unitOrder] en modo lectura para repasar unidades completadas.

**Impacto**

- Aprendiz puede ver progreso y estado actual
- Repaso disponible solo para unidades completadas
- No modifica entrenamiento ni métricas

## 2026-01-27 — E2E smoke Sub-lote A+B (UX Aprendiz)

**Tipo:** qa  
**Alcance:** frontend | e2e

**Resumen**
E2E Playwright exitoso para Sub-lotes A y B:

- navegación Aprendiz
- Progreso
- Repaso lectura-only

**Comando**
E2E_LEARNER_EMAIL=aprendiz@demo.com  
E2E_LEARNER_PASSWORD=prueba123  
E2E_REFERENTE_EMAIL=referente@demo.com  
E2E_REFERENTE_PASSWORD=prueba123  
npx playwright test e2e/learner-progress.spec.ts

**Resultado**

- learner-progress.spec.ts pasó ✅

**Estado**
Sub-lotes A+B certificados.

## 2026-01-27 — Perfil del aprendiz (read-only)

**Tipo:** feature  
**Alcance:** frontend

**Resumen**
Se implementa /learner/profile con datos del usuario, estado actual y historial de decisiones en modo solo lectura.

**Impacto**

- Aprendiz ve identidad, estado y decisiones humanas
- No se modifica el modelo ni el flujo de entrenamiento
- Prepara el cierre del Sub‑lote C

## 2026-01-27 — Infra de logging para consultas a unidades futuras

**Tipo:** feature  
**Alcance:** db | rls | backend

**Resumen**
Se agrega tabla append-only y RPC server-only para registrar consultas a unidades futuras. El wiring al chat se posterga por falta de señal estructurada.

**Impacto**

- Infra de logging lista sin exposición directa en cliente
- RLS por rol/local/org
- No cambia el flujo de entrenamiento actual

## 2026-01-27 — LLM mock habilitado para dev/QA local

**Tipo:** chore  
**Alcance:** dev | qa

**Resumen**
Se configura LLM_PROVIDER=mock en entorno local para evitar dependencia de cuotas externas durante desarrollo y QA.

**Impacto**

- Chat/práctica/evaluación usan respuestas determinísticas en local
- Producción bloquea explícitamente provider mock
- No cambia configuración de producción

## 2026-01-27 — Cierre Post‑MVP 1 (UX Aprendiz completa)

**Tipo:** docs  
**Alcance:** docs

**Resumen**
Se marca como cerrado el Lote Post‑MVP 1 en el roadmap y se actualiza el checkpoint de auditoría con el estado final de los sub‑lotes A‑D.

**Impacto**

- Roadmap actualizado con próximo checkpoint (Fase 2)
- Audit checkpoint refleja Post‑MVP 1 como hecho
- No cambia comportamiento funcional

## 2026-01-27 — Fase 2 Sub‑lote F: views evidencia + hardening RLS final evaluation

**Tipo:** feature  
**Alcance:** db | rls

**Resumen**
Se agregan las views `v_learner_evaluation_summary`, `v_learner_wrong_answers` y `v_learner_doubt_signals` para evidencia de revisión. Se endurecen policies SELECT de `final_evaluation_questions`, `final_evaluation_answers` y `final_evaluation_evaluations` para scope por org/local (tenant‑scoped).

**Impacto**

- Referente/Admin cuentan con contratos de evidencia completos por unidad y señales de duda
- Se evita lectura cross‑tenant en tablas de evaluación final
- No cambia flujo del aprendiz ni lógica de evaluación

**Checks manuales mínimos**

- Referente: SELECT en `v_learner_evaluation_summary` y `v_learner_wrong_answers` solo devuelve learners de su local
- Admin Org: SELECT en las 3 views solo devuelve learners de su org
- Aprendiz: SELECT en las 3 views no devuelve filas

## 2026-01-27 — Seed mínimo evidencia (QA local)

**Tipo:** chore  
**Alcance:** db | qa

**Resumen**
Se agrega un seed mínimo idempotente para generar datos de práctica y evaluación final y validar las views de evidencia en local.

**Impacto**

- Permite smoke tests de `v_learner_evaluation_summary`, `v_learner_wrong_answers` y `v_learner_doubt_signals`
- No afecta producción (solo local por migración de seed)
- No cambia flujos de aprendiz/referente

## 2026-01-27 — Fase 2 Sub‑lote F.1: seed cross‑tenant (Local B) + leakage checks

**Tipo:** chore  
**Alcance:** db | qa

**Resumen**
Se agrega seed idempotente para un segundo local (Local B) con referente/aprendiz y evidencia mínima (práctica + evaluación final), para pruebas concluyentes de fuga entre locales.

**Impacto**

- Permite validar que Referente A no ve evidencia de Local B
- Habilita comparación de resultados A vs B en views de evidencia
- No cambia lógica de producto

**Leakage checks (counts)**

- Test anterior (mismo sub cambiando claim local_id): INVALIDO (current_local_id() usa profiles.local_id, ignora claim)
- Referente A resolved_local_id=1af5842d-68c0-4c56-8025-73d416730016 (Local A)
- Referente A forzando Local B: summary_b_forced=0, wrong_b_forced=0, doubt_b_forced=0
- PASS/FAIL: PASS

## 2026-01-27 — Fase 2 Sub‑lote G: UI Referente evidencia (lectura)

**Tipo:** feature  
**Alcance:** frontend | ux | qa

**Resumen**
Se extiende /referente/review/[id] para mostrar evidencia de evaluación final con tres bloques (resumen por unidad, respuestas fallidas, señales) usando views server-side. Se agrega test Playwright que valida la presencia de los tres headers.

**Impacto**

- Referente accede a evidencia accionable sin nuevas acciones
- Lectura mobile-first con datos de v_learner_evaluation_summary / v_learner_wrong_answers / v_learner_doubt_signals
- QA básica: lint/build y db reset OK

**Checks manuales mínimos**

- npx supabase db reset
- npm run lint
- npm run build
- npm run e2e -- referente-review.spec.ts

## 2026-01-27 — Cierre Fase 2 (Evidencias completas Referente/Admin)

**Tipo:** docs  
**Alcance:** backend | frontend | qa

**Resumen**
Se declara cerrado el checkpoint de Fase 2 con views de evidencia, UI de revisión ampliada y validaciones de QA/E2E.

**Impacto**

- Referentes pueden revisar evidencia profunda por unidad
- Validación de aislamiento por local realizada con seed cross-tenant
- QA mínima completada (db reset, lint, build, e2e)

## 2026-01-27 — Fase 3 Sub‑lote I: views métricas accionables (30 días)

**Tipo:** feature  
**Alcance:** db | rls

**Resumen**
Se agregan views read-only tenant-scoped para métricas accionables del referente/admin: top gaps del local, riesgo por aprendiz y cobertura por unidad (ventana 30 días).

**Impacto**

- Contratos listos para UI de métricas mínimas por local
- Aislamiento por rol/local/org sin exponer a aprendiz
- Base para Fase 3 Admin Org

**QA (DB)**

- Smoke OK: v_local_top_gaps_30d / v_local_learner_risk_30d / v_local_unit_coverage_30d
- Denominador top_gaps validado (percent_learners_affected=50% con 2 learners activos)
- RLS local OK (Referente A forzando Local B: 0 filas)

## 2026-01-27 — Fase 3 Sub‑lote J: UI Referente métricas (lectura)

**Tipo:** feature  
**Alcance:** frontend | ux | qa

**Resumen**
Se agregan bloques de métricas (30 días) en /referente/review y cobertura por unidad en /referente/review/[learnerId], consumiendo views de métricas accionables en RSC.

**Impacto**

- Referente ve top gaps y riesgo por aprendiz sin acciones nuevas
- Cobertura por unidad visible en el detalle
- QA mínima ejecutada para Sub‑lote J

**Checks manuales mínimos**

- npx supabase db reset
- npm run lint
- npm run build
- npm run e2e -- referente-metrics.spec.ts

## 2026-01-27 — Fase 3 Sub‑lote K: QA extendida métricas (checklist)

**Tipo:** qa  
**Alcance:** db | rls | ux | e2e

**Resumen**
Se ejecuta checklist extendido de QA para métricas accionables: smoke DB, invariantes, ventana temporal, aislamiento por local, UI smoke manual y E2E.

**Resultados**

- K1 Smoke views (superadmin): OK
- K1 Invariantes: bad_rows=0, bad_levels=0, bad_rates=0
- K1 Ventana temporal: seed-gap-old=0, seed-gap-new=1
- K2 RLS (Referente A forzando Local B): top_gaps_b=0, learner_risk_b=0, unit_coverage_b=0
- K3 UI smoke manual: pendiente de ejecución manual
- K4 E2E: referente-review.spec.ts PASS, referente-metrics.spec.ts PASS
- K5 Gate: db reset, lint, build OK

## 2026-01-27 — Sub-lote L.1: Validacion humana v2 (DB + RLS)

**Tipo:** feature  
**Alcance:** db | rls | docs

**Resumen**
Se agrega la tabla append-only `learner_review_validations_v2` con enums, indices y RLS estricta para decisiones humanas v2, manteniendo v1 intacto.

**Impacto**

- Habilita registrar decisiones estructuradas con severidad, accion y checklist
- Mantiene aislamiento por org/local/rol en inserts y lecturas
- No cambia UI ni server actions existentes

**Checklist**

- Enums v2 creados
- Tabla append-only con trigger prevent update/delete
- Policies SELECT/INSERT por rol y scope

## 2026-01-27 — Sub-lote L.1.1: RLS SELECT sin confiar en snapshots

**Tipo:** fix  
**Alcance:** db | rls | docs

**Resumen**
Se ajustan las policies SELECT de `learner_review_validations_v2` para admin_org y referente usando joins por learner_id a `learner_trainings`, evitando confiar en `local_id` snapshot.

**Impacto**

- Evita ocultar filas legitimas si el snapshot local_id es incorrecto
- Mantiene aislamiento por org/local basado en contexto real del learner
- No cambia UI ni server actions

**Checklist**

- Policies SELECT admin_org/referente ajustadas
- Smoke RLS valido con SET ROLE authenticated + claims (primer intento como postgres invalido)

## 2026-01-27 — Sub-lote L.2: Wiring server-only validacion v2

**Tipo:** feature  
**Alcance:** backend

**Resumen**
Se agrega una Server Action para insertar decisiones en `learner_review_validations_v2` derivando snapshots y perfil del revisor en server-side, sin tocar UI ni estados.

**Impacto**

- Inserciones v2 seguras con `auth.uid()` y datos derivados de `learner_trainings`
- Validacion de rol permitido y estado `en_revision`
- Sin cambios en flujos v1 ni emails

**Checklist**

- Server Action creada
- No toca UI ni estados

## 2026-01-27 — Smoke L.2 (RLS + app validation)

**Tipo:** qa  
**Alcance:** db | rls | backend | docs

**Resumen**
Se agrega smoke reproducible en `docs/qa/smoke-l2.sql` con RLS real (`SET ROLE authenticated` + claims) y nota de validación de aplicación para el caso fuera de `en_revision`.

**Impacto**

- Deja evidencia DB-first/RLS-first para L.2
- Cubre referente OK y aprendiz FAIL por RLS
- Documenta validación de aplicación para `en_revision`

## 2026-01-27 — Sub-lote L.3: UI Referente validación v2

**Tipo:** feature  
**Alcance:** frontend | backend | ux

**Resumen**
Se agrega un bloque “Validación v2 (interna)” en el detalle de revisión con formulario mínimo y historial v2 (últimas 5), usando la Server Action v2 sin cambiar estados ni emails.

**Impacto**

- Referente/Admin pueden registrar validaciones v2 estructuradas desde la UI
- Historial v2 visible con checklist y comentario
- Mantiene flujo v1 intacto

**QA manual**

- Referente: /referente/review/[learnerId] -> enviar validación v2 y verla en historial
- Aprendiz: no puede acceder a /referente/review
- Botones v1 (aprobar/refuerzo) siguen funcionando

## 2026-01-27 — Sub-lote M.1: alert_events (DB + RLS)

**Tipo:** feature  
**Alcance:** db | rls | docs

**Resumen**
Se agrega `alert_events` append-only con enum `alert_type`, RLS estricta y indices para eventos alertables sin emitir notificaciones.

**Impacto**

- Infra DB para registrar eventos auditables por org/local/learner
- SELECT scope por rol y tenant; INSERT server-only via RLS
- Sin wiring ni UI todavía (M.2/M.3)

## 2026-01-27 — Sub-lote M.1.1: hardening alert_events

**Tipo:** fix  
**Alcance:** db | rls | docs

**Resumen**
Se ajusta la FK de `alert_events.learner_id` para evitar cascade y se endurece la policy INSERT para asegurar coherencia de org/local con el learner real.

**Impacto**

- Protege historial auditado ante borrados accidentales de profiles
- Evita snapshots incoherentes (org/local) en inserts server-only
- Sin cambios de UI ni wiring

## 2026-01-27 — Sub-lote M.2: emisión de alert_events

**Tipo:** feature  
**Alcance:** backend

**Resumen**
Se emiten eventos en `alert_events` desde submitReviewValidationV2 y cuando se finaliza una evaluación final, sin notificar ni cambiar estados.

**Impacto**

- review_submitted_v2 siempre + extras por decision_type
- final_evaluation_submitted al cerrar attempt
- Sin emails ni UI

**QA manual**

- Referente: crear validación v2 -> 1 o 2 filas en alert_events
- Aprendiz: SELECT solo sus eventos
- Final evaluation: al completar intento, crear alert final_evaluation_submitted

## 2026-01-27 — Sub-lote M.2.1: policy aprendiz final_evaluation_submitted

**Tipo:** fix  
**Alcance:** db | rls | backend | docs

**Resumen**
Se elimina el uso de service_role y se habilita INSERT limitado para aprendiz solo para `final_evaluation_submitted`, con coherencia org/local por learner.

**Impacto**

- Inserción de eventos desde sesión del aprendiz sin llaves privilegiadas
- Mantiene Zero Trust y snapshot coherente
- Sin cambios de UI ni notificaciones

## 2026-01-28 — Sub-lote M.3: inbox interno de alertas

**Tipo:** feature  
**Alcance:** frontend | backend | ux

**Resumen**
Se agrega /referente/alerts como bandeja read-only de alert_events con joins a profiles, y un entry point en la navegación del referente.

**Impacto**

- Referente/Admin ven eventos recientes sin notificaciones externas
- Links contextuales hacia /referente/review/[learnerId]
- Sin writes ni cambios de estado

**QA manual**

- Referente: ver solo eventos de su local
- Admin Org: ver eventos de toda la org
- Links llevan al detalle del learner

## 2026-01-28 — Post-MVP 3 Sub-lote A: inventario DB y contrato config bot

**Tipo:** docs  
**Alcance:** db | rls | backend | producto

**Resumen**
Se documenta el inventario real del schema relevante para configuracion del bot (programas, knowledge, evaluacion final) y se define el contrato minimo operable para Admin Org basado en el estado actual de RLS y consumo en app.

**Impacto**

- Establece limites claros de que es configurable hoy vs futuro
- Expone dependencias reales del bot (knowledge y configs) sin inventar entidades
- Habilita planificacion de sub-lotes de configuracion sin tocar schema ni UI

## 2026-01-28 — Post-MVP 3 Sub-lote B.1: views config bot

**Tipo:** feature  
**Alcance:** db | docs

**Resumen**
Se agregan views read-only para configurar/observar la configuracion del bot: config vigente e historial por programa, coverage de knowledge por unidad y programa activo por local.

**Impacto**

- Habilita lectura operativa sin writes ni cambios de UI
- Mantiene multi-tenant via RLS de tablas base
- Sin cambios de comportamiento del bot

## 2026-01-28 — Post-MVP 3 Sub-lote C: final eval config append-only + RPC

**Tipo:** feature  
**Alcance:** db | rls

**Resumen**
Se hace append-only a final_evaluation_configs con trigger prevent_update_delete y se agrega RPC create_final_evaluation_config para insertar nuevas versiones con validaciones de rol y tenant.

**Impacto**

- Versionado por insert-only en configuraciones de evaluación final
- No se modifica engine ni UI
- Mantiene Zero Trust mediante RLS y checks de rol/org

## 2026-01-28 — Fix: validacion min_global_score 0-100 en RPC

**Tipo:** fix  
**Alcance:** db | docs

**Resumen**
Se ajusta la validacion de min_global_score en la RPC create_final_evaluation_config a rango 0–100, alineado a engine y seeds actuales, y se documenta el contrato.

**Impacto**

- Evita gating incorrecto por configs validas en porcentaje
- Mantiene compatibilidad con seeds existentes
- Sin cambios en engine ni schema

## 2026-01-28 — Post-MVP3 D.1: UI Admin config eval final

**Tipo:** feature  
**Alcance:** frontend | backend | ux

**Resumen**
Se agrega la pantalla /org/config/bot para Admin Org con selector de programa, lectura de config vigente e historial y formulario insert-only via RPC create_final_evaluation_config.

**Impacto**

- Admin puede crear nuevas configuraciones sin tocar engine
- Lectura de warnings de coverage sin writes adicionales
- Respeta RLS y append-only

## 2026-01-28 — Fix: import path supabase en referente/alerts

**Tipo:** fix  
**Alcance:** frontend

**Resumen**
Se corrige el import relativo de getSupabaseServerClient en /referente/alerts para restaurar build.

**Impacto**

- Build vuelve a compilar
- Sin cambios de comportamiento

## 2026-01-28 — Fix: await searchParams en /org/config/bot

**Tipo:** fix  
**Alcance:** frontend

**Resumen**
Se ajusta la firma de page.tsx para await searchParams (Promise) en App Router y evitar crash al navegar con query params.

**Impacto**

- Evita rebote al seleccionar programa
- Sin cambios funcionales adicionales

## 2026-01-28 — Post-MVP3 D.2/C.3: guardrail config con intento en progreso

**Tipo:** fix  
**Alcance:** db | rls

**Resumen**
Se endurece la RPC create_final_evaluation_config para bloquear nuevas configs si existe un intento final_evaluation_attempts en status in_progress para el programa.

**Impacto**

- Evita cambios de config durante intentos activos
- Sin cambios de schema ni engine

## 2026-01-28 — QA: smoke SQL guardrail D.2

**Tipo:** docs  
**Alcance:** db | qa

**Resumen**
Se agrega script de smoke QA para validar el guardrail D.2 (sin intento activo OK / con intento activo conflict) en `docs/qa/smoke-post-mvp3-d2.sql`.

**Impacto**

- Evidencia audit-friendly del comportamiento esperado
- No ejecuta QA en este paso

## 2026-01-28 — Post-MVP3 E.1: programa activo por local

**Tipo:** feature  
**Alcance:** db | rls | backend | frontend | ux

**Resumen**
Se agrega RPC set_local_active_program con auditoria append-only, RLS de escritura para admin_org/superadmin y pantalla Admin Org para asignar programa activo por local con historial reciente.

**Impacto**

- Cambios de programa activo quedan auditados
- Admin Org puede actualizar locales sin builder
- No afecta learner_trainings existentes

## 2026-01-28 — QA: smoke SQL E.1 programa activo por local

**Tipo:** docs  
**Alcance:** db | qa

**Resumen**
Se agrega script smoke DB-first para validar set_local_active_program y auditoría append-only en `docs/qa/smoke-post-mvp3-e1.sql`.

**Impacto**

- Evidencia reproducible de guardrails y auditoría en E.1
- No ejecuta QA en este paso

## 2026-01-28 — QA DB-first completa (L2, D2, E1)

**Tipo:** docs  
**Alcance:** db | qa

**Resumen**
Se ejecutan smokes DB-first: L2 (RLS review v2), D2 (guardrail config in_progress) y E1 (set_local_active_program + auditoría). Resultado: PASS.

**Impacto**

- Evidencia reproducible de seguridad y guardrails críticos
- Base operable para UI Admin sin riesgo de bypass

## 2026-01-28 — QA: harden smokes D.2 y E.1

**Tipo:** docs  
**Alcance:** qa

**Resumen**
Se ajustan smokes DB-first: D.2 agrega attempt_number explícito; E.1 suma query de locales + programas elegibles para evitar fallos por selección inválida.

**Impacto**

- Smokes copy/paste sin sorpresas
- Menos fricción al repetir QA

## 2026-01-28 — Post-MVP3 cierre formal

**Tipo:** docs  
**Alcance:** producto

**Resumen**
Se cierra formalmente Post-MVP 3 con QA DB-first completo (L2, D2, E1) y entregables en main.

**Impacto**

- Base operativa estable para avanzar a Post-MVP 4
- Guardrails críticos auditados
- Sin deuda abierta en la fase

## 2026-01-28 — Post-MVP4 K1: knowledge coverage (views + UI read-only)

**Tipo:** feature  
**Alcance:** db | frontend | ux | docs

**Resumen**
Se agregan views read-only para cobertura de knowledge por unidad y gaps por programa, junto a UI Admin Org en /org/config/knowledge-coverage.

**Impacto**

- Visibilidad operativa de gaps que rompen el bot
- Sin writes ni cambios de engine
- Lectura multi-tenant via RLS

## 2026-01-28 — Post-MVP4 K2: add knowledge wizard (RPC + audit)

**Tipo:** feature  
**Alcance:** db | rls | backend | frontend | ux

**Resumen**
Se agrega RPC create_and_map_knowledge_item con auditoría append-only y políticas RLS de insert para knowledge_items y unit_knowledge_map. Se integra wizard en /org/config/knowledge-coverage para crear knowledge y mapearlo a una unidad.

**Impacto**

- Admin Org puede cargar knowledge sin SQL
- Coverage/list K1 reflejan el nuevo item
- Append-only preservado sin CRUD libre

## 2026-01-28 — Post-MVP4 K3: disable knowledge (RPC + guardrails)

**Tipo:** feature  
**Alcance:** db | rls | backend | frontend | ux

**Resumen**
Se agrega is_enabled en knowledge_items con guardrail de update, RPC disable_knowledge_item y eventos audit en knowledge_change_events. La UI de knowledge coverage permite desactivar items con confirmación.

**Impacto**

- Admin puede desactivar knowledge sin borrar ni editar
- Coverage/drill-down filtran desactivados
- Auditoría append-only por mapping

## 2026-01-28 — Post-MVP5 M1: métricas Admin Org (views + UI read-only)

**Tipo:** feature  
**Alcance:** db | frontend | ux | docs

**Resumen**
Se agregan views org-scoped de métricas 30 días (gaps, riesgo, cobertura) y pantalla /org/metrics con tabs de lectura para Admin Org.

**Impacto**

- Visibilidad operativa sin writes
- Drill-down por local en tablas
- RLS por org/rol

## 2026-01-28 — Post-MVP5 M2: drill-down org metrics

**Tipo:** feature  
**Alcance:** db | frontend | ux | docs

**Resumen**
Se agregan views read-only para drill-down (gaps por local y knowledge activo por unidad) y rutas de detalle desde /org/metrics.

**Impacto**

- Navegación operativa sin writes
- Cobertura y knowledge visibles por unidad
- Enlaces directos a revisión de learners

## 2026-01-28 — Post-MVP4 QA DB-first (K1/K2/K3)

**Tipo:** docs  
**Alcance:** qa

**Resumen**
Se agregan y ejecutan smokes DB-first para K1/K2/K3. Resultado: PASS en los tres.

**Impacto**

- Evidencia reproducible de views y RPCs Post-MVP4
- Guardrails de disable verificados
- Base lista para Post-MVP5 sin deuda de QA

## 2026-01-28 — Post-MVP5 M3: acciones sugeridas (read-only)

**Tipo:** feature  
**Alcance:** db | frontend | ux | docs

**Resumen**
Se agrega la view org-scoped v_org_recommended_actions_30d y un bloque de acciones sugeridas en /org/metrics (Resumen).

**Impacto**

- Sugerencias operativas explicables sin writes
- Enlaces directos a drill-down y revisión
- Priorización simple y determinística

## 2026-01-28 — Post-MVP5 M4: playbooks para acciones sugeridas

**Tipo:** feature  
**Alcance:** db | frontend | ux | docs

**Resumen**
Se agrega la view v_org_recommended_actions_playbooks_30d con checklist, impacto y links secundarios, y se renderizan en /org/metrics (Resumen).

**Impacto**

- Acciones sugeridas con pasos concretos
- CTA principal + links secundarios
- Sin writes ni reglas dinámicas

## 2026-01-28 — Post-MVP5 M5: outcomes 7d vs 30d (read-only)

**Tipo:** feature  
**Alcance:** db | frontend | ux | docs

**Resumen**
Se agregan views de outcomes 7d vs 30d para acciones sugeridas y se muestra el estado (mejorando/estable/empeorando) en /org/metrics.

**Impacto**

- Cierre de loop medir → actuar → verificar
- Fallback explícito cuando no hay señal 7d
- Sin writes ni lógica dinámica

## 2026-01-28 — QA DB-first Post-MVP5 (M1–M5)

**Tipo:** docs  
**Alcance:** qa

**Resumen**
Se ejecutan smokes DB-first para M1–M5 con resultados PASS en todos los casos. M5 usa fallback sin señal 7d (score_7d NULL) por falta de fuente temporal 7d.

**Impacto**

- Evidencia reproducible de métricas y playbooks Post-MVP5
- Validación de outcomes y joins sin errores
- QA cerrada para continuar sub-lotes

## 2026-01-28 — Post-MVP6: roadmap/contrato configuración del bot (docs-only)

**Tipo:** docs  
**Alcance:** docs | producto

**Resumen**
Se crea el documento maestro de configuración del bot (contenido, comportamiento y evaluación), basado en el schema y el comportamiento actual, con matriz de configurables, guardrails anti‑LMS y plan de sub‑lotes.

**Impacto**

- Qué habilita: planificación accionable para cerrar configuración del bot sin inventar entidades
- Qué cambia: claridad sobre qué es configurable hoy vs hardcodeado
- Qué NO cambia: no modifica DB, RLS ni UI
- Próximos pasos sugeridos: definir Sub‑lote 1 (cambios mínimos de DB, si aplica)
