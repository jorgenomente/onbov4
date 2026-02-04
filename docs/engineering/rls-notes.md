# RLS Notes

## RLS + CTEs: visibilidad y single-statement pitfalls

- Evitar CTEs encadenados con INSERT/UPDATE y subqueries RLS que dependen de filas recien creadas en el mismo statement.
- Preferir multiples statements dentro de una transaccion cuando hay dependencias RLS entre inserts.
- Aplica a tests, RPCs y Edge Functions (mismo problema de visibilidad/planificacion).
