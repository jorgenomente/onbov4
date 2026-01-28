# FIX MIN GLOBAL SCORE VALIDATION

## Contexto

Ajuste quirurgico para alinear validacion de min_global_score (0-100) en RPC create_final_evaluation_config y documentar contrato.

## Prompt ejecutado

````txt
Excelente catch. **Gracias por frenarlo acá** — este es exactamente el tipo de inconsistencia que hay que cerrar **antes** de UI.

## Decisión correcta (alineada a DB + engine actual)

👉 **Ajustamos la validación a `0–100`**
❌ **NO** 0–1
❌ **NO** quitar upper bound

### Por qué (razón técnica, no opinión)

* `final_evaluation_configs.min_global_score` es `numeric(5,2)`
* El `final-evaluation-engine.ts`:

  * calcula **scores 0–100**
  * compara directamente contra `min_global_score`
* Ya existen seeds/configs válidas en rango **0–100**
* Cambiar la semántica ahora:

  * rompe backward compatibility
  * invalida seeds demo
  * introduce un bug silencioso en gating

👉 El contrato **ya existe de facto**: `min_global_score` = porcentaje **0–100**.
Lo documentamos y lo respetamos.

---

## Qué hay que cambiar (mínimo y quirúrgico)

### 1️⃣ Ajuste en la RPC (único cambio)

Reemplazar este bloque:

```sql
if p_min_global_score is null or p_min_global_score < 0 or p_min_global_score > 1 then
  raise exception 'invalid: min_global_score must be between 0 and 1'
    using errcode = '22023';
end if;
````

Por este:

```sql
if p_min_global_score is null or p_min_global_score < 0 or p_min_global_score > 100 then
  raise exception 'invalid: min_global_score must be between 0 and 100'
    using errcode = '22023';
end if;
```

👉 **Nada más**.
No tocamos schema, no tocamos engine, no tocamos seeds.

---

### 2️⃣ Documentación (ya que sos prolijo)

En `docs/post-mvp3/config-bot/A1-contract.md` (o donde estés definiendo contrato):

- Dejar explícito:
  - `min_global_score`: **porcentaje 0–100**
  - se compara contra promedio de scores por attempt
  - no normalizado

Esto evita que en 2 meses alguien intente “normalizar” de nuevo.

---

## Orden recomendado ahora (sin desviarnos)

1. **Aplicar el fix de la RPC** (mini-migración o amend si preferís)
2. `npx supabase db reset`
3. Smoke rápido:

   ```sql
   select public.create_final_evaluation_config(
     '<PROGRAM_UUID>'::uuid,
     10,
     0.4,
     75,        -- 75%
     array[1,2],
     2,
     3,
     12
   );
   ```

4. Commit:

   ```
   fix(post-mvp3): min_global_score validation aligned to 0–100
   ```

---

## Estado del proyecto después de este fix

✅ Configuración de evaluación final **vendible y segura**
✅ Append-only real
✅ Contrato claro
✅ Sin UI todavía (perfecto)
➡️ **Listos para D.1: UI Admin mínima (1 pantalla, 1 write)**

Si querés, en el próximo mensaje te doy **el diseño exacto de la pantalla Admin** (campos, labels, defaults, errores) **antes** de escribir una sola línea de React.

```

Resultado esperado

Validacion de min_global_score alineada a 0-100 y contrato documentado.

Notas (opcional)

Sin notas.
```
