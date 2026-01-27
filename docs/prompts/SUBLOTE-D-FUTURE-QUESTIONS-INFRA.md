# SUBLOTE-D-FUTURE-QUESTIONS-INFRA

## Contexto

Implementar solo infraestructura DB-first + RPC para logging de consultas a unidades futuras, sin wiring en el chat por falta de señal estructurada.

## Prompt ejecutado

```txt
Sub-lote D (redefinido): NO hay señal estructurada de “unidad futura”, así que NO se integra wiring en sendLearnerMessage.
Implementar solo infraestructura DB-first + RPC server-only para logging.

1) Migración SQL:
   - Crear tabla public.learner_future_questions (append-only):
     id uuid pk default gen_random_uuid()
     learner_id uuid not null references auth.users(id)
     local_id uuid not null references public.locals(id)
     program_id uuid not null references public.training_programs(id)
     asked_unit_order integer not null
     conversation_id uuid null references public.conversations(id)
     message_id uuid null references public.conversation_messages(id)
     question_text text not null
     created_at timestamptz not null default now()

   - Índices mínimos:
     (learner_id, created_at desc)
     (local_id, created_at desc)
     (program_id, created_at desc)

2) RLS + policies:
   - Enable RLS.
   - SELECT:
     * aprendiz: learner_id = auth.uid()
     * referente: local_id = current_local_id()
     * admin_org: EXISTS join locals l where l.id = learner_future_questions.local_id and l.org_id = current_org_id()
     * superadmin: allow
   - INSERT:
     * NO permitir insert directo desde cliente con tabla (evitar spoofing de asked_unit_order).
       En su lugar, crear RPC SECURITY DEFINER para insertar (ver punto 3) y NO crear policy INSERT abierta.

   - NO UPDATE/DELETE policies.

3) RPC server-only:
   - Crear function public.log_future_question(
       asked_unit_order integer,
       question_text text,
       conversation_id uuid default null,
       message_id uuid default null
     ) returns uuid
   - SECURITY DEFINER
   - set search_path = public
   - Dentro:
     a) Derivar learner_id = auth.uid() (si null → raise exception)
     b) Obtener local_id y org/program activos desde public.profiles + learner_trainings/local_active_programs (usar lo que ya existe):
        - local_id desde profiles
        - program_id desde learner_trainings del learner (o active program del local)
     c) Insertar en learner_future_questions con esos ids + params
     d) Return id
   - Importante: validar asked_unit_order > current_unit_order (del learner_trainings) para que sea realmente futura.

4) NO tocar sendLearnerMessage por ahora.
   - Solo agregar comentario TODO en el lugar correcto indicando que falta señal estructurada para auto-log.

5) Regenerar docs DB:
   - npm run db:dictionary
   - npm run db:dump:schema

6) Verificación:
   - npx supabase db reset
   - npm run lint
   - npm run build

7) Smoke test mínimo (manual):
   - Con sesión de aprendiz demo en app, ejecutar un script node (o un pequeño test) que llame la RPC log_future_question(asked_unit_order=99, question_text="...") y confirme insert exitoso.
   - Confirmar que learner solo ve sus filas y referente/admin_org ven por alcance.

8) Activity log:
   - Registrar Sub-lote D: tabla+RLS+RPC listos, wiring postergado por falta de señal.

9) Commit directo a main:
   feat: future questions logging infra
```

Resultado esperado

Infra DB + RPC para logging de consultas a unidades futuras, sin wiring en chat.

Notas (opcional)

Sub‑lote D únicamente.
