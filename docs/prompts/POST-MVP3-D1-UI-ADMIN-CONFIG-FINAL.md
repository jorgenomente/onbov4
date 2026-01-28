# POST-MVP3 D1 UI ADMIN CONFIG FINAL

## Contexto

Sub-lote D.1: UI Admin minima para configuracion de evaluacion final con lectura de config vigente e historial y write via RPC insert-only.

## Prompt ejecutado

```txt
# Post-MVP 3 — Sub-lote D.1 (UI Admin mínima): Configuración Evaluación Final

OBJETIVO
Implementar una única pantalla para Admin Org que permita:
1) Ver configuración vigente e historial (read-only) de evaluación final por programa.
2) Crear una nueva configuración (INSERT-only) usando RPC existente.
NO implementar course builder. NO tocar schema. NO tocar engine. NO agregar writes nuevos fuera de esta RPC.

CONTEXTO DB (YA EXISTE)
- View vigente: public.v_org_program_final_eval_config_current
- View historial: public.v_org_program_final_eval_config_history
- View coverage (opcional warnings): public.v_org_program_unit_knowledge_coverage
- Tablas para selector: public.training_programs (RLS select)
- RPC write: public.create_final_evaluation_config(
    p_program_id uuid,
    p_total_questions int,
    p_roleplay_ratio numeric,  -- 0..1
    p_min_global_score numeric, -- 0..100
    p_must_pass_units int[],
    p_questions_per_unit int,
    p_max_attempts int,
    p_cooldown_hours int
  ) returns uuid
- final_evaluation_configs es append-only (UPDATE/DELETE bloqueados).

STACK / REGLAS (OBLIGATORIO)
- Next.js 16 App Router + RSC.
- Mobile-first Tailwind.
- Nada de lógica sensible en frontend.
- NO service_role en clientes.
- Escritura SOLO vía Server Action (SSR client con cookies).
- No usar select *.
- Manejar estados: loading/empty/error/success.
- Multi-tenant: confiar en RLS. No pasar org_id/local_id desde UI.

RUTA ÚNICA
- Crear: /org/config/bot
  - Implementar en: app/org/config/bot/page.tsx

UX / UI (MVP)
Pantalla con:
A) Selector de programa (dropdown)
   - Fuente: training_programs visibles por RLS (order by created_at desc o name asc).
   - Si no hay programa seleccionado, mostrar estado vacío con instrucción.

B) Card "Configuración vigente" (read-only)
   - Fuente: v_org_program_final_eval_config_current filtrado por program_id
   - Mostrar campos:
     - total_questions
     - roleplay_ratio como %
     - min_global_score (0–100)
     - questions_per_unit
     - must_pass_units (lista o “—”)
     - max_attempts
     - cooldown_hours
     - config_created_at
   - Si config_id es null: banner warning "Falta configuración (config_missing)."

C) Card "Nueva configuración (aplica desde ahora)" (form)
   - Campos editables (con defaults):
     - total_questions (default: vigente o 10)
     - roleplay_percent (UI 0..100) -> convertir a ratio 0..1 antes de llamar RPC
     - min_global_score (default: vigente o 75) rango 0..100
     - questions_per_unit (default: vigente o 2)
     - must_pass_units (multi-select por unit_order + title; necesita listar units del programa)
     - max_attempts (default: vigente o 3)
     - cooldown_hours (default: vigente o 12)
   - Texto fijo: "Se crea una nueva versión. No modifica intentos anteriores. (Append-only)"
   - Botón: "Guardar nueva configuración"
   - Al guardar:
     - Llamar server action que invoque RPC create_final_evaluation_config
     - revalidatePath('/org/config/bot')
     - Mostrar success toast/alert con new_config_id

D) Sección "Historial" (read-only)
   - Fuente: v_org_program_final_eval_config_history filtrado por program_id limit 10
   - Tabla compacta: fecha, total_questions, roleplay %, min_score, max_attempts, cooldown

E) (Opcional) warnings coverage
   - Consultar v_org_program_unit_knowledge_coverage por program_id
   - Si hay is_missing_knowledge_mapping=true: mostrar warning "Unidad X sin knowledge mapping (esto rompe el chat)."

ARQUITECTURA TÉCNICA
- Usar Supabase SSR client (@supabase/ssr) en server-side.
- Implementar Server Action en el mismo módulo o en lib/actions:
  - function createFinalEvalConfigAction(formData)
  - Validar server-side:
    - program_id presente
    - ranges básicos (total>0, 0..100 percent, score 0..100, per_unit>0, max_attempts>0, cooldown>=0)
  - Convertir roleplay_percent -> roleplay_ratio (percent/100)
  - Parse must_pass_units (array de ints)
  - Llamar RPC: supabase.rpc('create_final_evaluation_config', {...})
  - Manejar errores con mensaje user-friendly (forbidden/not_found/invalid).

DATOS PARA LISTAR UNIDADES (para must_pass_units)
- Query a public.training_units (RLS select) por program_id, order by unit_order asc.
- No inventar nuevas views.

ENTREGABLES
- app/org/config/bot/page.tsx (RSC + UI)
- Server Action (donde corresponda)
- Componentes mínimos (pueden ser inline, sin sobre-ingeniería)
- Update docs/activity-log.md con entrada "Post-MVP3 D.1 UI Admin config eval final"
- Comandos de verificación a ejecutar:
  - npx supabase db reset
  - npm run lint
  - npm run build

NO HACER
- No agregar otras pantallas.
- No CRUD de programs/units/knowledge.
- No exponer parámetros LLM.
- No agregar nuevas tablas/migraciones.
```

Resultado esperado

Pantalla /org/config/bot con lectura y write via RPC, y logs actualizados.

Notas (opcional)

Sin notas.
