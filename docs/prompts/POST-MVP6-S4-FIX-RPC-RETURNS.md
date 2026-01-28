# POST-MVP6 S4 fix: RPC returns rows (create/disable practice_scenario)

## Contexto

El smoke SQL fallo porque create_practice_scenario no devolvia id; ajustar RPCs para retornar fila.

## Prompt ejecutado

```txt
ahora ejecutemos el test
```

Resultado esperado

RPCs create_practice_scenario y disable_practice_scenario devuelven fila (id/timestamp) y smoke SQL pasa.
