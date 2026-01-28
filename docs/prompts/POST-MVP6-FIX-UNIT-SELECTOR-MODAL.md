# POST-MVP6-FIX-UNIT-SELECTOR-MODAL

## Contexto

Fix UI para reemplazar el input libre de unit_order por un selector de unidad en el modal de crear escenario.

## Prompt ejecutado

```txt
# PROMPT PARA CODEX CLI — Fix UI: Selector de Unidad en modal “Crear escenario” (Post-MVP6)

Actuá como Senior Frontend Engineer (Next.js App Router, RSC, Tailwind, UX operativa).

## Objetivo
Eliminar el input libre “Unit order” en el modal **Crear escenario** y reemplazarlo por un **selector de Unidad (dropdown)** que muestre:
- número de unidad
- nombre de la unidad

El value enviado debe seguir siendo `unit_order` (number), sin cambios en DB ni server actions.

## Contexto
- Ruta: /org/bot-config
- Modal actual: Create Practice Scenario
- Data disponible:
  - Las unidades ya están cargadas en la página desde `v_local_bot_config_units`
  - Cada unidad tiene: `unit_order`, `unit_title`
- Server action:
  - `createPracticeScenarioAction` recibe `unit_order` (number)
  - El server valida contra DB, así que el frontend solo debe enviar un valor correcto

## Alcance exacto (NO salirse de esto)
- ❌ No tocar SQL
- ❌ No tocar RPCs
- ❌ No tocar server actions
- ❌ No agregar estados globales nuevos
- ✅ Solo UI del modal

## Tareas

### 1) Reemplazar input libre por `<select>`
En `PracticeScenarioPanel.tsx` (o componente equivalente del modal):

**Antes**
- Input texto / number:
  - label: “Unit order”
  - name: `unit_order`

**Después**
- `<select name="unit_order" required>`
- Opciones generadas desde las unidades disponibles:

Formato de cada option:
- value: `unit_order`
- label visible:
  - `Unidad {unit_order} — {unit_title}`

Ejemplo:
- value="1" → “Unidad 1 — Bienvenida y estándar de servicio”
- value="2" → “Unidad 2 — Venta sugestiva básica”

### 2) Preselección inteligente
- Si el modal se abre desde el botón **Crear escenario** de una unidad:
  - El select debe venir **preseleccionado** con ese `unit_order`
- Si el modal se abre desde el botón global:
  - El select arranca sin selección o con la primera unidad (la opción más simple)

No inventar lógica compleja.

### 3) UX mínima
- Cambiar label a:
  - **“Unidad”**
- Eliminar cualquier placeholder tipo “Unit order”
- Mantener estilo consistente con el resto del modal

### 4) Limpieza
- Eliminar cualquier parsing innecesario del input anterior
- Asegurarse de que el `FormData` siga enviando:
  - `unit_order` como string numérico (HTML select ya lo hace)

## QA Manual (OBLIGATORIO)
1) `npm run dev`
2) Ir a `/org/bot-config`
3) Click “Crear escenario” desde:
   - botón global
   - botón dentro de una unidad
4) Verificar:
   - El selector muestra todas las unidades con nombre
   - Preselección correcta cuando aplica
   - Crear escenario funciona sin errores
   - No aparece más “Programa o unidad inválida”

## Entregables
- Cambios solo en UI (modal y props relacionados)
- No tocar DB ni server actions
- Commit directo en main

## Commit
Mensaje sugerido:
- `fix(ui): replace unit order input with unit selector in practice scenario modal`

Al finalizar:
- Resumen corto de archivos tocados
- Confirmar que no se tocó SQL
```

## Resultado esperado

Dropdown de unidad en el modal de creación, con preselección y sin cambios en DB ni server actions.
