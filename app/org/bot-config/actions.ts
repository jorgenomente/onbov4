'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { requireUserAndRole } from '../../../lib/server/requireRole';
import { getSupabaseServerClient } from '../../../lib/server/supabase';

type RedirectParams = {
  localId?: string;
  error?: string;
  success?: string;
};

function buildRedirectUrl(params: RedirectParams) {
  const search = new URLSearchParams();
  if (params.localId) search.set('localId', params.localId);
  if (params.error) search.set('error', params.error);
  if (params.success) search.set('success', params.success);
  const query = search.toString();
  return query ? `/org/bot-config?${query}` : '/org/bot-config';
}

function resolveErrorMessage(raw?: string | null) {
  if (!raw) return 'No se pudo completar la operacion.';
  if (raw.includes('forbidden')) return 'No tenes permisos para esta accion.';
  if (raw.includes('not_found')) return 'Programa o unidad invalida.';
  if (raw.includes('invalid')) {
    const parts = raw.split('invalid:');
    if (parts.length > 1) return parts[1].trim();
    return 'Datos invalidos.';
  }
  return 'No se pudo completar la operacion.';
}

export async function createPracticeScenarioAction(formData: FormData) {
  const { role } = await requireUserAndRole(['admin_org', 'superadmin']);

  const localId = String(formData.get('local_id') ?? '').trim();
  const unitOrderRaw = String(formData.get('unit_order') ?? '').trim();
  const title = String(formData.get('title') ?? '').trim();
  const instructions = String(formData.get('instructions') ?? '').trim();
  const difficultyRaw = String(formData.get('difficulty') ?? '').trim();
  const successCriteriaRaw = String(
    formData.get('success_criteria') ?? '',
  ).trim();

  const unitOrder = Number(unitOrderRaw);
  const difficulty = Number(difficultyRaw || '1');

  if (!localId) {
    redirect(
      buildRedirectUrl({
        error: 'local_id requerido',
      }),
    );
  }

  if (!Number.isFinite(unitOrder) || unitOrder <= 0) {
    redirect(
      buildRedirectUrl({
        localId,
        error: 'unit_order invalido',
      }),
    );
  }

  if (title.length === 0) {
    redirect(buildRedirectUrl({ localId, error: 'title requerido' }));
  }

  if (instructions.length === 0) {
    redirect(buildRedirectUrl({ localId, error: 'instructions requerido' }));
  }

  if (!Number.isFinite(difficulty) || difficulty < 1 || difficulty > 5) {
    redirect(buildRedirectUrl({ localId, error: 'difficulty debe ser 1..5' }));
  }

  const successCriteria = successCriteriaRaw
    ? successCriteriaRaw
        .split('\n')
        .map((line) => line.trim())
        .filter(Boolean)
    : [];

  const supabase = await getSupabaseServerClient();
  const { data: summaryRow } = await supabase
    .from('v_local_bot_config_summary')
    .select('local_id, active_program_id')
    .eq('local_id', localId)
    .maybeSingle();

  const programId = summaryRow?.active_program_id ?? '';

  if (!programId) {
    redirect(
      buildRedirectUrl({
        localId,
        error: 'programa activo no encontrado',
      }),
    );
  }

  const { data: unitRow } = await supabase
    .from('v_local_bot_config_units')
    .select('local_id, program_id, unit_order')
    .eq('local_id', localId)
    .eq('program_id', programId)
    .eq('unit_order', unitOrder)
    .maybeSingle();

  if (!unitRow) {
    redirect(
      buildRedirectUrl({
        localId,
        error: 'unit_order invalido para ese programa',
      }),
    );
  }

  const { error } = await supabase.rpc('create_practice_scenario', {
    p_program_id: programId,
    p_unit_order: unitOrder,
    p_title: title,
    p_instructions: instructions,
    p_success_criteria: successCriteria.length > 0 ? successCriteria : null,
    p_difficulty: difficulty,
    p_local_id: role === 'superadmin' && localId.length > 0 ? localId : null,
  });

  if (error) {
    const message = resolveErrorMessage(error.message);
    redirect(buildRedirectUrl({ localId, error: message }));
  }

  revalidatePath('/org/bot-config');
  redirect(buildRedirectUrl({ localId, success: 'created' }));
}

export async function disablePracticeScenarioAction(formData: FormData) {
  await requireUserAndRole(['admin_org', 'superadmin']);

  const localId = String(formData.get('local_id') ?? '').trim();
  const scenarioId = String(formData.get('scenario_id') ?? '').trim();
  const reason = String(formData.get('reason') ?? '').trim();

  if (!scenarioId) {
    redirect(buildRedirectUrl({ localId, error: 'scenario_id requerido' }));
  }

  if (reason.length > 500) {
    redirect(
      buildRedirectUrl({ localId, error: 'reason length must be <= 500' }),
    );
  }

  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc('disable_practice_scenario', {
    p_scenario_id: scenarioId,
    p_reason: reason.length > 0 ? reason : null,
  });

  if (error) {
    const message = resolveErrorMessage(error.message);
    redirect(buildRedirectUrl({ localId, error: message }));
  }

  revalidatePath('/org/bot-config');
  redirect(buildRedirectUrl({ localId, success: 'disabled' }));
}
