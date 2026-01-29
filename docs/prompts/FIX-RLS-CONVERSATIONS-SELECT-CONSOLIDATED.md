# FIX-RLS-CONVERSATIONS-SELECT-CONSOLIDATED

## Contexto

Consolidar policies SELECT de conversations y corregir initplan en final_evaluation_questions_select_visible.

## Prompt ejecutado

```text
Perfecto. Estos 2 warnings son dos categorías distintas y se resuelven distinto:

1) multiple_permissive_policies en public.conversations (authenticated, SELECT)
2) auth_rls_initplan en final_evaluation_questions_select_visible

Se pide consolidar SELECT policies de conversations y recrear final_evaluation_questions_select_visible con auth.uid() envuelto en SELECT.
```

## Resultado esperado

- Migration que consolida conversations SELECT en una policy.
- Migration que corrige auth.uid() en final_evaluation_questions_select_visible.
