# Manual navigation smoke (ONBO)

Fecha: 2026-01-28

## Precondiciones (local)

1. `npx supabase db reset`
2. `npm run dev`
3. Usar credenciales de `docs/smoke-credentials.md`

---

## 1) Público (sin sesión)

- [ ] Abrir `http://localhost:3000/` -> debe terminar en `/login`
- [ ] Ir a `/auth/redirect` sin sesión -> debe terminar en `/login` (o redirect coherente)
- [ ] Login correcto -> redirige al landing del rol

---

## 2) Aprendiz

### Entrada

- [ ] Login aprendiz -> aterriza en `/learner/training`

### Navegación por layout

- [ ] Tabs funcionan: Training <-> Progress <-> Profile

### CTAs

- [ ] En `/learner/training`: “Continuar” hace focus al input y no rompe UI
- [ ] En `/learner/training`: “Ver progreso” -> `/learner/progress`
- [ ] En `/learner/progress`: “Volver a entrenamiento” -> `/learner/training`
- [ ] “Repasar unidad”:
  - [ ] si NO hay unidad completada -> disabled + texto correcto
  - [ ] si SI hay completada -> navega a `/learner/review/[unitOrder]`
- [ ] En `/learner/review/[unitOrder]`: “Volver a progreso” y “Volver a entrenamiento” OK
- [ ] En `/learner/profile`: “Volver a entrenamiento” OK

### Logout

- [ ] Ir a `/auth/logout` -> vuelve a `/login`

---

## 3) Referente

### Entrada

- [ ] Login referente -> `/referente/review`

### Layout links

- [ ] “Revisión” <-> “Alertas” funcionan

### CTAs

- [ ] En `/referente/review`: “Ver alertas” -> `/referente/alerts`
- [ ] “Abrir revisión”:
  - [ ] si hay aprendices -> navega a `/referente/review/[learnerId]`
  - [ ] si no hay -> disabled + texto “Sin aprendices para revisar”
- [ ] En `/referente/review/[learnerId]`: “Volver a cola” -> `/referente/review`, “Ir a alertas” -> `/referente/alerts`
- [ ] En `/referente/alerts`: “Volver a revisión” -> `/referente/review`

### Logout

- [ ] `/auth/logout` -> `/login`

---

## 4) Admin Org

### Entrada

- [ ] Login admin org -> `/org/metrics`

### Layout links

- [ ] Navegar a:
  - [ ] `/org/config/bot`
  - [ ] `/org/config/knowledge-coverage`
  - [ ] `/org/bot-config`
  - [ ] `/org/config/locals-program`

### CTAs

- [ ] En `/org/metrics`:
  - [ ] “Config evaluación final” -> `/org/config/bot`
  - [ ] “Cobertura de knowledge” -> `/org/config/knowledge-coverage`
- [ ] En `/org/config/bot`: “Volver a métricas” OK (y si existe “crear config”, no rompe)
- [ ] En `/org/config/locals-program`: CTAs vuelven a métricas, y si hay form/acción existente no rompe
- [ ] En `/org/config/knowledge-coverage`: CTA “Volver a métricas” OK (y si hay wizard existente no rompe)
- [ ] En `/org/bot-config`: “Volver a métricas” OK

### Drilldowns

- [ ] Abrir manualmente:
  - [ ] `/org/metrics/gaps/1` -> “Volver a métricas” y “Cobertura de knowledge” OK
  - [ ] `/org/metrics/coverage/<programId>/<unitOrder>` (usar uno real) -> CTAs OK

### Logout

- [ ] `/auth/logout` -> `/login`

---

## Troubleshooting (rápido)

- Si `/` no redirige -> revisar `app/page.tsx`
- Si CTA no navega -> revisar `Link` / `href` en la page
- Si el rol no cae en landing -> revisar `/auth/redirect`
