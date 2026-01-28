'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { getSupabaseServerClient } from '../../../../lib/server/supabase';

function toNumber(value: FormDataEntryValue | null) {
  if (typeof value !== 'string' || value.trim() === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function buildRedirectUrl(params: Record<string, string | undefined>) {
  const search = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value) search.set(key, value);
  });
  const query = search.toString();
  return query ? `/org/config/bot?${query}` : '/org/config/bot';
}

function resolveErrorMessage(raw: string | null | undefined) {
  if (!raw) return 'No se pudo guardar la configuración. Intentá nuevamente.';
  if (raw.includes('forbidden')) {
    return 'No tenés permisos para crear configuraciones.';
  }
  if (raw.includes('not_found')) {
    return 'Programa inválido o fuera de tu organización.';
  }
  if (raw.includes('invalid')) {
    const parts = raw.split('invalid:');
    if (parts.length > 1) {
      return parts[1].trim();
    }
    return 'Parámetros inválidos. Revisá los valores.';
  }
  return 'No se pudo guardar la configuración. Intentá nuevamente.';
}

export async function createFinalEvalConfigAction(formData: FormData) {
  const programId = String(formData.get('program_id') ?? '').trim();
  if (!programId) {
    redirect(
      buildRedirectUrl({ error: 'Seleccioná un programa antes de guardar.' }),
    );
  }

  const totalQuestions = toNumber(formData.get('total_questions'));
  const roleplayPercent = toNumber(formData.get('roleplay_percent'));
  const minGlobalScore = toNumber(formData.get('min_global_score'));
  const questionsPerUnit = toNumber(formData.get('questions_per_unit'));
  const maxAttempts = toNumber(formData.get('max_attempts'));
  const cooldownHours = toNumber(formData.get('cooldown_hours'));
  const mustPassRaw = formData.getAll('must_pass_units');

  if (!totalQuestions || totalQuestions <= 0) {
    redirect(
      buildRedirectUrl({
        programId,
        error: 'total_questions debe ser > 0',
      }),
    );
  }

  if (
    roleplayPercent === null ||
    roleplayPercent < 0 ||
    roleplayPercent > 100
  ) {
    redirect(
      buildRedirectUrl({
        programId,
        error: 'roleplay_percent debe estar entre 0 y 100',
      }),
    );
  }

  if (minGlobalScore === null || minGlobalScore < 0 || minGlobalScore > 100) {
    redirect(
      buildRedirectUrl({
        programId,
        error: 'min_global_score debe estar entre 0 y 100',
      }),
    );
  }

  if (!questionsPerUnit || questionsPerUnit <= 0) {
    redirect(
      buildRedirectUrl({
        programId,
        error: 'questions_per_unit debe ser > 0',
      }),
    );
  }

  if (!maxAttempts || maxAttempts <= 0) {
    redirect(
      buildRedirectUrl({
        programId,
        error: 'max_attempts debe ser > 0',
      }),
    );
  }

  if (cooldownHours === null || cooldownHours < 0) {
    redirect(
      buildRedirectUrl({
        programId,
        error: 'cooldown_hours debe ser >= 0',
      }),
    );
  }

  const mustPassUnits = mustPassRaw
    .map((value) => Number(value))
    .filter((value) => Number.isFinite(value)) as number[];

  const roleplayRatio = Math.round((roleplayPercent / 100) * 100) / 100;

  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc('create_final_evaluation_config', {
    p_program_id: programId,
    p_total_questions: totalQuestions,
    p_roleplay_ratio: roleplayRatio,
    p_min_global_score: minGlobalScore,
    p_must_pass_units: mustPassUnits,
    p_questions_per_unit: questionsPerUnit,
    p_max_attempts: maxAttempts,
    p_cooldown_hours: cooldownHours,
  });

  if (error || !data) {
    const message = resolveErrorMessage(error?.message);
    redirect(buildRedirectUrl({ programId, error: message }));
  }

  revalidatePath('/org/config/bot');
  redirect(
    buildRedirectUrl({
      programId,
      success: '1',
      configId: String(data),
    }),
  );
}
