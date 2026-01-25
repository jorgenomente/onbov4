# DIAG-SUPABASE-STUDIO-LOCAL

## Contexto

Diagnosticar por qué Supabase Studio no está disponible en local y dejarlo funcionando, siguiendo pasos A-D con comandos específicos.

## Prompt ejecutado

```txt
Sos un Lead Software Architect + Senior Backend Engineer (Supabase/Postgres/RLS) y tu tarea es diagnosticar por qué Supabase Studio no está disponible en mi entorno local y dejarlo funcionando, sin suposiciones.

Contexto real (NO inventar):
- `npx supabase status` muestra:
  - Project URL: http://127.0.0.1:54321
  - REST: http://127.0.0.1:54321/rest/v1
  - GraphQL: http://127.0.0.1:54321/graphql/v1
  - DB URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
  - Mailpit: http://127.0.0.1:54324
- No aparece Studio en el output de status.
- http://localhost:54323 no carga nada.
- Al pegarle a 54321 con / devuelve: {"message":"no Route matched with those values"}.

Objetivo:
1) Determinar si Studio está deshabilitado por config, no se levantó el contenedor, falló al arrancar, o está en otro puerto.
2) Corregirlo de forma reproducible (sin “magia”), y dejar una verificación final clara.

Restricciones:
- No uses service_role ni toques migraciones.
- No cambies la app Next.js.
- Solo intervenir en: supabase local stack (CLI/Docker/config.toml) y diagnóstico.
- Todo debe ser ejecutable en mi máquina (macOS) con comandos copy/paste.

Plan de ejecución obligatorio (no saltear pasos):
A) Recolección de evidencia
   - Ejecutar: `npx supabase status`
   - Ejecutar: `npx supabase version`
   - Ejecutar: `docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}"`
   - Ejecutar: `docker ps -a | grep -i supabase`
   - Verificar puertos: `lsof -i :54323 || true`
   - Buscar config: `ls -la supabase && [ -f supabase/config.toml ] && sed -n '1,200p' supabase/config.toml || true`
   - Grep studio: `grep -n "studio" -n supabase/config.toml || true`

B) Diagnóstico (explicar en 5-10 líneas máximo)
   - Concluir cuál escenario aplica:
     1) Studio no está definido/está disabled en config
     2) Studio contenedor no existe
     3) Studio contenedor existe pero está Exited (ver logs)
     4) Conflicto de puerto / mapeo distinto

C) Remediación
   - Si falta/disabled: habilitar Studio en `supabase/config.toml` (solo cambios mínimos) y reiniciar stack.
   - Si contenedor no existe: reiniciar stack y verificar pull/creación.
   - Si Exited: mostrar logs: `docker logs <studio_container> --tail 200` y aplicar fix (puerto, imagen, etc.).
   - Comandos permitidos:
     - `npx supabase stop --no-backup`
     - `npx supabase start`
     - `npx supabase status`

D) Verificación final (obligatoria)
   - Confirmar que `npx supabase status` muestre la URL de Studio (o explicar por qué no es posible).
   - Probar con:
     - `curl -I http://127.0.0.1:<PUERTO_STUDIO>`
     - Abrir en navegador: `http://127.0.0.1:<PUERTO_STUDIO>`
   - Si el puerto resultó no ser 54323, dejarlo explícito.

Output requerido:
- Un log paso a paso de lo que ejecutaste y lo que encontraste.
- Los cambios exactos (si tocaste config.toml, mostrar diff o las líneas editadas).
- Una sección final: “RESULTADO” con la URL definitiva de Studio y cómo validarla.

Empezá por A) Recolección de evidencia, ejecutá comandos, y seguí el plan hasta dejar Studio accesible.
```

Resultado esperado
Diagnóstico reproducible y Studio local funcionando con verificación clara.

Notas (opcional)
N/A.
