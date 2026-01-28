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
    ? `/org/config/locals-program?${query}`
    : '/org/config/locals-program';
}

function resolveErrorMessage(raw: string | null | undefined) {
  if (!raw) return 'No se pudo guardar el programa activo.';
  if (raw.includes('forbidden')) {
    return 'No tenés permisos para cambiar el programa activo.';
  }
  if (raw.includes('not_found')) {
    return 'Local o programa fuera de tu organización.';
  }
  if (raw.includes('invalid')) {
    const parts = raw.split('invalid:');
    if (parts.length > 1) return parts[1].trim();
    return 'Programa inválido para ese local.';
  }
  if (raw.includes('conflict')) {
    return 'No se puede cambiar el programa con un intento en progreso.';
  }
  return 'No se pudo guardar el programa activo.';
}

export async function setLocalActiveProgramAction(formData: FormData) {
  const localId = String(formData.get('local_id') ?? '').trim();
  const programId = String(formData.get('program_id') ?? '').trim();
  const reason = String(formData.get('reason') ?? '').trim();

  if (!localId || !programId) {
    redirect(buildRedirectUrl({ error: 'Seleccioná un local y un programa.' }));
  }

  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc('set_local_active_program', {
    p_local_id: localId,
    p_program_id: programId,
    p_reason: reason.length > 0 ? reason : null,
  });

  if (error) {
    const message = resolveErrorMessage(error?.message);
    redirect(buildRedirectUrl({ error: message }));
  }

  revalidatePath('/org/config/locals-program');
  redirect(buildRedirectUrl({ success: '1' }));
}
