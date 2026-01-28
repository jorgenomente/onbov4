# POST-MVP6-S4-FIX-DERIVE-PROGRAM-ID

## Contexto

Fix en UI/Server Action para eliminar mismatch de program_id al crear practice_scenarios.

## Prompt ejecutado

````txt
Listo. Ese fix es el correcto y además **mejora seguridad** (anti-tampering) y coherencia multi-tenant.

Te marco 2 ajustes finos para que quede perfecto y no metas un bug nuevo:

## 1) Validación de `unit_order` debe estar ligada al **programa activo**

En tu snippet, el check de unit_order hace:

```ts
.eq('local_id', localId)
.eq('unit_order', unitOrder)
````

Eso puede dar **falsos positivos** si la view trae unidades de otro programa (depende de cómo está construida `v_local_bot_config_units`).

✅ Mejor (como te propuse antes): filtrar también por `program_id = active_program_id`:

```ts
const { data: unitRow } = await supabase
  .from('v_local_bot_config_units')
  .select('local_id, program_id, unit_order')
  .eq('local_id', localId)
  .eq('program_id', programId)
  .eq('unit_order', unitOrder)
  .maybeSingle();
```

## 2) No uses `program_id` hidden en el form (sí, removelo)

No es obligatorio, pero reduce confusión y elimina el origen del bug.

---

# Qué hacer ahora (paso a paso, sin tool)

### A) Aplicá el patch en `app/org/bot-config/actions.ts`

- Derivá `programId` por `localId` desde `v_local_bot_config_summary`.
- Validá el `unitOrder` contra `v_local_bot_config_units` filtrando por `programId`.
- Llamá RPC con `programId` derivado.

### B) (Opcional) En `PracticeScenarioPanel.tsx`

- Quitá el `<input type="hidden" name="program_id" .../>`

### C) Smoke inmediato

```bash
npm run dev
```

- Ir a `/org/bot-config?localId=2af5842d-68c0-4c56-8025-73d416730017`
- Crear escenario en unidad 1
- Debe funcionar.

### D) Commit

```bash
npm run lint
npm run build
git add -A
git commit -m "fix(post-mvp6): derive program_id server-side for practice scenario create"
git push origin main
```

---

## Por qué esto resuelve tu error

Tu DB smoke mostró que **ese program_id y unit_order son válidos**.
El fallo es UI enviando un `program_id` stale o de otro local. Al derivarlo server-side, eso desaparece.

---

Si pegás ahora el contenido de `PracticeScenarioPanel.tsx` (solo la parte del `<form>`), te digo si además hay un bug de estado (por ejemplo, modal no resetea al cambiar de local), pero con el fix server-side ya quedás cubierto.

```

## Resultado esperado
Ajuste de server action para derivar program_id por local, validar unit_order por programa activo y remover program_id del form.
```
