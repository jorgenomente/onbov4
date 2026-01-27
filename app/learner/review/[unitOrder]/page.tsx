import Link from 'next/link';
import { notFound } from 'next/navigation';

import { getSupabaseServerClient } from '../../../../lib/server/supabase';

type ReviewPageProps = {
  params: Promise<{ unitOrder: string }>;
};

export default async function LearnerReviewPage({ params }: ReviewPageProps) {
  const { unitOrder } = await params;
  const requestedOrder = Number(unitOrder);

  if (!Number.isFinite(requestedOrder) || requestedOrder <= 0) {
    notFound();
  }

  const supabase = await getSupabaseServerClient();

  const { data: trainingHome, error: trainingError } = await supabase
    .from('v_learner_training_home')
    .select('program_id, current_unit_order')
    .maybeSingle();

  if (trainingError || !trainingHome) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-4 px-4 py-6">
        <p className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Error al cargar la unidad.
        </p>
      </main>
    );
  }

  if (requestedOrder >= Number(trainingHome.current_unit_order)) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-4 px-4 py-6">
        <Link href="/learner/progress" className="text-sm text-slate-500">
          ← Volver a progreso
        </Link>
        <div className="rounded-md border border-dashed border-slate-200 p-4 text-sm text-slate-500">
          Unidad no disponible para repaso.
        </div>
      </main>
    );
  }

  const { data: unit, error: unitError } = await supabase
    .from('training_units')
    .select('title')
    .eq('program_id', trainingHome.program_id)
    .eq('unit_order', requestedOrder)
    .maybeSingle();

  if (unitError || !unit) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-4 px-4 py-6">
        <p className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          No encontramos la unidad solicitada.
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-4 px-4 py-6">
      <Link href="/learner/progress" className="text-sm text-slate-500">
        ← Volver a progreso
      </Link>
      <div>
        <h1 className="text-2xl font-semibold text-slate-900">
          Unidad {requestedOrder}: {unit.title}
        </h1>
        <p className="text-sm text-slate-500">Modo repaso (solo lectura).</p>
      </div>
      <div className="rounded-lg border border-slate-200 bg-white p-4 text-sm text-slate-600">
        Contenido de repaso disponible próximamente.
      </div>
    </main>
  );
}
