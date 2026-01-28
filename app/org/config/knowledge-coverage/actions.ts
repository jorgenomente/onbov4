'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { getSupabaseServerClient } from '../../../../lib/server/supabase';

function buildRedirectUrl(params: Record<string, string | undefined>) {
  const search = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value) search.set(key, value);
  });
  const query = search.toString();
  return query
    ? `/org/config/knowledge-coverage?${query}`
    : '/org/config/knowledge-coverage';
}

function resolveErrorMessage(raw: string | null | undefined) {
  if (!raw) return 'No se pudo agregar knowledge.';
  if (raw.includes('forbidden')) {
    return 'No tenés permisos para agregar knowledge.';
  }
  if (raw.includes('not_found')) {
    return 'Programa o unidad inválidos.';
  }
  if (raw.includes('invalid')) {
    const parts = raw.split('invalid:');
    if (parts.length > 1) return parts[1].trim();
    return 'Datos inválidos.';
  }
  if (raw.includes('conflict')) {
    return 'El mapping ya existe para esa unidad.';
  }
  return 'No se pudo agregar knowledge.';
}

export async function addKnowledgeToUnitAction(formData: FormData) {
  const programId = String(formData.get('program_id') ?? '').trim();
  const unitId = String(formData.get('unit_id') ?? '').trim();
  const scope = String(formData.get('scope') ?? '').trim();
  const localId = String(formData.get('local_id') ?? '').trim();
  const title = String(formData.get('title') ?? '').trim();
  const content = String(formData.get('content') ?? '').trim();
  const reason = String(formData.get('reason') ?? '').trim();

  if (!programId || !unitId) {
    redirect(
      buildRedirectUrl({
        programId,
        error: 'Seleccioná programa y unidad.',
      }),
    );
  }

  if (title.length === 0 || title.length > 120) {
    redirect(
      buildRedirectUrl({
        programId,
        error: 'title length must be 1..120',
      }),
    );
  }

  if (content.length === 0 || content.length > 20000) {
    redirect(
      buildRedirectUrl({
        programId,
        error: 'content length must be 1..20000',
      }),
    );
  }

  if (scope !== 'org' && scope !== 'local') {
    redirect(
      buildRedirectUrl({ programId, error: 'scope must be org or local' }),
    );
  }

  if (scope === 'org' && localId.length > 0) {
    redirect(
      buildRedirectUrl({
        programId,
        error: 'local_id must be empty for org scope',
      }),
    );
  }

  if (scope === 'local' && localId.length === 0) {
    redirect(
      buildRedirectUrl({
        programId,
        error: 'local_id required for local scope',
      }),
    );
  }

  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc('create_and_map_knowledge_item', {
    p_program_id: programId,
    p_unit_id: unitId,
    p_title: title,
    p_content: content,
    p_scope: scope,
    p_local_id: localId.length > 0 ? localId : null,
    p_reason: reason.length > 0 ? reason : null,
  });

  if (error || !data) {
    const message = resolveErrorMessage(error?.message);
    redirect(buildRedirectUrl({ programId, error: message }));
  }

  revalidatePath('/org/config/knowledge-coverage');
  redirect(
    buildRedirectUrl({
      programId,
      success: '1',
      knowledgeId: String(data),
    }),
  );
}
