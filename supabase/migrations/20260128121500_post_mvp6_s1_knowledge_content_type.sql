-- Post-MVP6 Sub-lote 1 (DB minimo): tipado opcional de knowledge_items (sin romper seeds / sin UI)
-- Objetivo: habilitar clasificacion pedagogica (concepto/procedimiento/regla/guion) para prompts/evaluacion.

begin;

-- 1) Enum: knowledge_content_type (idempotente)
do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where t.typname = 'knowledge_content_type'
      and n.nspname = 'public'
  ) then
    create type public.knowledge_content_type as enum (
      'concepto',
      'procedimiento',
      'regla',
      'guion'
    );
  end if;
end
$$;

comment on type public.knowledge_content_type is
  'Post-MVP6: tipologia pedagogica minima para knowledge_items (opcional).';

-- 2) Columna: knowledge_items.content_type (NULLABLE, sin default)
alter table public.knowledge_items
  add column if not exists content_type public.knowledge_content_type;

comment on column public.knowledge_items.content_type is
  'Post-MVP6: tipo pedagogico opcional (concepto/procedimiento/regla/guion). NULL permitido para compatibilidad retroactiva.';

commit;
