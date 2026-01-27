# QA-VALIDACION-VIEWS-EVIDENCIA-RLS

## Contexto

Validación de seeds, views de evidencia y hardening RLS en local (Supabase Studio/psql).

## Prompt ejecutado

```txt
DB — Validar que las views devuelven datos y que NO hay fuga cross-tenant
1.1. Tenés datos seed?

En Supabase Studio local (o psql), probá:

select count(*) from public.final_evaluation_attempts;
select count(*) from public.final_evaluation_questions;
select count(*) from public.final_evaluation_answers;
select count(*) from public.final_evaluation_evaluations;

select count(*) from public.practice_attempts;
select count(*) from public.practice_evaluations;
select count(*) from public.practice_scenarios;


Si alguno está en 0, la UI no va a mostrar evidencia todavía (no es bug del lote).

1.2. Smoke básico de las 3 views (sin RLS aún)
select * from public.v_learner_evaluation_summary limit 20;
select * from public.v_learner_wrong_answers limit 20;
select * from public.v_learner_doubt_signals limit 20;


Esperado:

evaluation_summary: filas agrupadas por attempt_id + unit_order.

wrong_answers: solo verdict <> 'pass'.

doubt_signals: signal + total_count y sources con practice/final.

1.3. Smoke de RLS “como Referente” (lo importante)

Necesitás un usuario referente logueado en local, y su local_id asociado.

En SQL Editor de Studio, simulá JWT (si ya tenés helpers típicos en ONBO). Probá:

-- 1) fijar el usuario actual
select public.set_claim('sub', '<REFERENTE_USER_UUID>');
select public.set_claim('role', 'authenticated');
select public.set_claim('onbo_role', 'referente');
select public.set_claim('local_id', '<LOCAL_UUID_DEL_REFERENTE>');
-- (si usan org_id)
select public.set_claim('org_id', '<ORG_UUID_DEL_REFERENTE>');

-- 2) leer evidence views
select * from public.v_learner_evaluation_summary limit 50;
select * from public.v_learner_wrong_answers limit 50;
select * from public.v_learner_doubt_signals limit 50;


Esperado: solo filas del local del referente.

1.4. Test de fuga (cross-tenant) — debe dar 0 filas

Buscá (o inventá) un local_id de otra org/local (si existe seed). Cambiá el claim local_id a uno que no corresponda a los datos y repetí:

select public.set_claim('local_id', '<OTRO_LOCAL_UUID>');
select count(*) from public.v_learner_evaluation_summary;
select count(*) from public.v_learner_wrong_answers;
select count(*) from public.v_learner_doubt_signals;


Esperado: todo 0.

Si no tenés otro local/org en seed, este test no es concluyente. Pero con 2 locales ya lo probás perfecto.

1.5. Verificación directa del hardening RLS (tablas finales)

Como referente, intentá leer directamente tablas final_evaluation_* (esto antes era el riesgo):

select count(*) from public.final_evaluation_questions;
select count(*) from public.final_evaluation_answers;
select count(*) from public.final_evaluation_evaluations;


Esperado: solo ve lo que pertenece a su local/org (vía learner_trainings).
```

Resultado esperado
Confirmar seeds y resultados de views/RLS en local.

Notas (opcional)
N/A
