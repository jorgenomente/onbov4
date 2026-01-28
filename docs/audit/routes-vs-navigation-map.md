# Auditoria de rutas vs navigation map

Fecha: 2026-01-28

## Resumen

- Total pages: 17
- Total routes: 2
- En mapa y existe en app: 14
- En mapa pero no existe en app: 1
- Existe en app pero no esta en mapa: 5

---

## A) En mapa y existe en app (OK)

| path                           | tipo  | archivo                                    |
| ------------------------------ | ----- | ------------------------------------------ |
| /auth/redirect                 | route | app/auth/redirect/route.ts                 |
| /learner/final-evaluation      | page  | app/learner/final-evaluation/page.tsx      |
| /learner/profile               | page  | app/learner/profile/page.tsx               |
| /learner/progress              | page  | app/learner/progress/page.tsx              |
| /learner/review/[unitOrder]    | page  | app/learner/review/[unitOrder]/page.tsx    |
| /learner/training              | page  | app/learner/training/page.tsx              |
| /login                         | page  | app/login/page.tsx                         |
| /org/bot-config                | page  | app/org/bot-config/page.tsx                |
| /org/config/bot                | page  | app/org/config/bot/page.tsx                |
| /org/config/knowledge-coverage | page  | app/org/config/knowledge-coverage/page.tsx |
| /org/metrics                   | page  | app/org/metrics/page.tsx                   |
| /referente/alerts              | page  | app/referente/alerts/page.tsx              |
| /referente/review              | page  | app/referente/review/page.tsx              |
| /referente/review/[learnerId]  | page  | app/referente/review/[learnerId]/page.tsx  |

---

## B) En mapa pero NO existe en app (FALTANTE)

| path                 | sugerencia    |
| -------------------- | ------------- |
| /admin/organizations | (crear luego) |

---

## C) Existe en app pero NO esta en mapa (HUERFANA)

| path                                          | tipo  | archivo                                                   | nota |
| --------------------------------------------- | ----- | --------------------------------------------------------- | ---- |
| /                                             | page  | app/page.tsx                                              |      |
| /auth/logout                                  | route | app/auth/logout/route.ts                                  |      |
| /org/config/locals-program                    | page  | app/org/config/locals-program/page.tsx                    |      |
| /org/metrics/coverage/[programId]/[unitOrder] | page  | app/org/metrics/coverage/[programId]/[unitOrder]/page.tsx |      |
| /org/metrics/gaps/[unitOrder]                 | page  | app/org/metrics/gaps/[unitOrder]/page.tsx                 |      |
