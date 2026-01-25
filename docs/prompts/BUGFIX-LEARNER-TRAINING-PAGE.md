# BUGFIX-LEARNER-TRAINING-PAGE

## Contexto

/login redirige a /learner/training pero la ruta 404 porque falta app/learner/training/page.tsx.

## Prompt ejecutado

```txt
Sos un Senior Frontend Engineer (Next.js 16 App Router). El login como aprendiz redirige a /learner/training pero devuelve 404. En el repo existe app/learner/training/layout.tsx y actions.ts, pero falta page.tsx, por lo que la ruta no está definida.

Tarea:
1) Crear el archivo app/learner/training/page.tsx.
2) Implementar un componente mínimo (sin lógica, sin server actions) que renderice un título “Entrenamiento” y un texto descriptivo.
3) No tocar layouts, no cambiar rutas existentes, no agregar navegación nueva.

Criterio de aceptación:
- Login como aprendiz redirige a /learner/training.
- La ruta carga sin 404.
- No se introducen cambios colaterales.
```

Resultado esperado
Crear page.tsx mínimo para que /learner/training exista.

Notas (opcional)
N/A.
