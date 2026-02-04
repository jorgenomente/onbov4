# SIMPLIFICAR FLUJO APRENDIZ (HOME + ENTRENAMIENTO)

## Contexto

Corregir el flujo del Aprendiz para que sea explícito y sin ambigüedad en Home y Entrenamiento, evitando gating de evaluación final fuera de su ruta.

## Prompt ejecutado

```txt
# CODEx CLI — ONBO: Simplificar flujo del Aprendiz (Home + Entrenamiento) y eliminar confusiones

Objetivo: corregir el flujo del Aprendiz para que sea explícito y sin ambigüedad.
Problemas actuales detectados:
1) /learner (Home) es confuso: muestra Aprender/Practicar + CTA “Practicar unidad” aunque el sistema bloquea por gating.
2) Se ejecuta/loguea “final-evaluation gating blocked” (progress_incomplete) cuando el usuario intenta practicar, aunque NO está intentando evaluación final.
3) Navegación duplicada: tabs superiores (Home/Entrenamiento/Progreso/Perfil) y botones inferiores (Progreso/Perfil/Repasar) redundantes.
4) /learner/training permite enviar mensajes sin contexto activo si no existe learner_training/conversation (ya detectamos que la creación no estaba garantizada).

Regla de producto (MVP, no negociable):
- El aprendiz NO debe decidir entre “Aprender” o “Practicar”. El sistema decide el siguiente paso.
- En /learner debe existir UN solo CTA principal (“Continuar”) que lleve al lugar correcto.
- Nunca mostrar botones que están bloqueados por reglas de negocio.
- No debe ejecutarse gating de evaluación final en acciones de Home/Training, excepto cuando el usuario explícitamente entra a la evaluación final.

Stack / restricciones:
- Next.js App Router + RSC.
- Supabase + RLS (no usar service_role en cliente).
- DB-first, estado explícito.
- No inventar tablas nuevas salvo que sea estrictamente necesario (preferir usar views/RPC existentes).
- No romper rutas existentes.
- Mantener UI minimalista (mobile-first).

---

## Parte A — Auditar repo antes de cambiar
1) Ubicar páginas:
- app/learner/page.tsx (o equivalente /learner home)
- app/learner/training/page.tsx
- app/learner/training/actions.ts (sendLearnerMessage falla con “Active conversation context not found”)
- Cualquier action/handler que se llame desde el botón “Practicar unidad 1”
- Cualquier gating relacionado con final evaluation que esté siendo llamado desde learner home/training

2) Encontrar fuentes de verdad para estado del aprendiz:
- Tablas/views: learner_trainings, conversations, practice_scenarios, etc.
- Ver si ya existe una view tipo: v_learner_home_state / v_learner_training_state / v_learner_active_conversation_context.
Si no existe, identificar el query actual que usan las páginas y reutilizarlo.

3) Revisar docs del repo que definan UX/flujo del aprendiz (si existen):
- docs/product-master.md
- docs/roadmap*
- docs/audit/* (especialmente lo reciente sobre admin org y training)
- cualquier doc de “navigation map” o “screens/index”.

---

## Parte B — Cambios UX (Front) con mínimo riesgo

### B1) /learner (Home)
Rediseñar /learner para que sea “Dashboard de estado + CTA único”:

- Mantener tabs superiores: Home / Entrenamiento / Progreso / Perfil (solo 1 lugar de navegación).
- Eliminar el switch “Aprender · Practicar” en Home.
- Eliminar el botón “Practicar unidad X”.
- Eliminar botones duplicados “Progreso / Perfil / Repasar…” dentro del contenido del Home (quedan solo como tabs superiores).
- Mostrar:
  - Programa activo (nombre)
  - Estado actual (label claro): En entrenamiento / En práctica / En revisión / Aprobado
  - Unidad actual: “Unidad N de M — {título}”
  - Progreso % (si existe)
- CTA principal único:
  - Texto: “Continuar”
  - Comportamiento: navegar a /learner/training
  - Subtexto debajo del CTA (copy claro) dependiente del estado:
    - si en entrenamiento: “Tu próximo paso es aprender esta unidad.”
    - si en práctica: “Tu próximo paso es practicar esta unidad.”
    - si en revisión: “Tu evaluación final está en revisión.”
    - si aprobado: “Entrenamiento completado.”

Importante: /learner NO debe disparar ninguna lógica de final evaluation gating ni mostrar logs de gating.

### B2) /learner/training
En training, hacer que el usuario pueda continuar sin errores:
- Si NO existe learner_training / conversación activa:
  - en vez de permitir enviar mensaje y fallar, inicializar (server-side) el contexto mínimo o mostrar un CTA “Comenzar”.
  - Deshabilitar input “Enviar” hasta que exista contexto.
- Remover el switch Aprender/Practicar (si existe) o convertirlo a indicador read-only (ej. “Modo: Aprender” / “Modo: Práctica”).
- El modo se define por estado del learner_training y disponibilidad de práctica:
  - si hay escenario activo y el sistema decide que toca práctica => mostrar práctica y prompt correcto.
  - si no hay práctica disponible => mostrar aprender (con knowledge, explicación guiada, ejemplos).
- El bot debe enseñar antes de evaluar. Si el modo es práctica, antes de la primera respuesta mostrar un bloque breve “Antes de practicar, recordá…” derivado del knowledge o criterios.

---

## Parte C — Fix de lógica: separar gating de evaluación final
- Identificar dónde se está logueando “final-evaluation gating blocked {reason: progress_incomplete}” cuando el usuario hace click en “Practicar unidad”.
- Eso debe ocurrir SOLO al intentar entrar/iniciar evaluación final (ruta de evaluación final), nunca en Home o Training.
- Corregir wiring:
  - El botón/CTA de Home debe ir a /learner/training (no a ninguna acción de gating).
  - Cualquier action de “start practice” no debe llamar gating final evaluation.

---

## Parte D — Contracts de datos (sin inventar)
- Reutilizar views/RPC existentes si ya hay.
- Si falta un “home state” consolidado, crear una view DB-first MINIMAL:
  - v_learner_home_state: learner_id, program_id, program_name, status, current_unit_order, total_units, unit_title, progress_percent, can_start_practice(boolean), has_practice_scenarios(boolean)
- Asegurar RLS y que se pueda consultar como learner (solo su local/org).

Solo crear DB objetos si es estrictamente necesario para evitar queries frágiles en frontend. Preferir view antes que lógica duplicada.

---

## Parte E — QA obligatorio
1) Local reset:
- npx supabase db reset

2) Build/lint:
- npm run lint
- npm run build

3) Smoke manual (aprendiz nuevo):
- Login como aprendiz nuevo sin training -> /learner
  - debe mostrar CTA “Continuar”
  - sin switch Aprender/Practicar
  - sin botones duplicados
- Click “Continuar” -> /learner/training
  - no debe fallar “Active conversation context not found”
  - si no hay contexto aún, debe inicializar o pedir “Comenzar” sin crash
- Confirmar que NO aparecen logs “final-evaluation gating blocked” durante Home/Training.

4) Si existe Playwright:
- Actualizar/crear test smoke del aprendiz:
  - navega /learner
  - click “Continuar”
  - envía primer mensaje si corresponde o valida CTA “Comenzar”
  - assert no error.

---

## Entregables
- Cambios en UI /learner para dejarlo claro y minimalista.
- /learner/training robusto: no crash sin contexto.
- Eliminación de gating de evaluación final en flujo de Home/Training.
- Si se crea view/RPC: migración SQL versionada + RLS adecuada.
- Actualizar docs si hay mapa de pantallas o navegación (solo si ya existe documento para eso).

No inventar features fuera de este alcance.

Fin.
## Definition of Done (DoD) — Flujo Aprendiz ONBO (MVP)

El lote se considera **COMPLETO** cuando **TODOS** los puntos siguientes se cumplen:

### UX / Flujo
- [ ] En `/learner` existe **UN SOLO CTA principal** (“Continuar”).
- [ ] No existe switch visible “Aprender · Practicar” en `/learner`.
- [ ] No existen botones duplicados de “Progreso” o “Perfil” dentro del contenido (solo tabs superiores).
- [ ] El copy en `/learner` explica explícitamente:
  - estado actual (en entrenamiento / en práctica / en revisión / aprobado)
  - unidad actual
  - qué va a pasar al presionar “Continuar”.
- [ ] El aprendiz **nunca** ve un botón que esté bloqueado por reglas de negocio.

### Navegación
- [ ] “Continuar” en `/learner` **SIEMPRE** navega a `/learner/training`.
- [ ] `/learner/training` nunca dispara lógica de evaluación final.
- [ ] No aparecen logs de `final-evaluation gating blocked` durante Home o Training.

### Entrenamiento / Chat
- [ ] Si el aprendiz no tiene `learner_training`, el sistema lo inicializa o muestra un CTA “Comenzar” (sin crash).
- [ ] No es posible enviar mensajes si no existe contexto activo (input deshabilitado o inicialización automática).
- [ ] El bot **enseña antes de evaluar**:
  - si hay práctica activa, muestra primero un bloque de aprendizaje/recordatorio.
- [ ] El usuario nunca recibe feedback de error sin haber visto antes el estándar esperado.

### Datos / Backend
- [ ] No se agregan estados implícitos: todo estado proviene de DB (training, unidad, progreso).
- [ ] No se duplica lógica de estado en frontend.
- [ ] Si se creó una view/RPC nueva:
  - está versionada por migración
  - tiene RLS correcta
  - solo devuelve datos del learner autenticado.

### Estabilidad
- [ ] `npm run lint` pasa sin errores.
- [ ] `npm run build` pasa sin errores.
- [ ] Smoke manual con aprendiz nuevo:
  - Login → `/learner` → “Continuar” → `/learner/training`
  - No errores en consola
  - No crashes al enviar mensaje.

### Documentación
- [ ] Si existe documento de mapa de pantallas / navegación, está actualizado.
- [ ] No se agregan docs nuevos innecesarios.

Si algún ítem no se cumple, el lote **NO está terminado**.
```

Resultado esperado

Cambios en UI/logic para simplificar el flujo del aprendiz, robustecer /learner/training y separar gating de evaluación final.

Notas (opcional)

Sin notas.
