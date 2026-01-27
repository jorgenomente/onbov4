import { getSupabaseServerClient } from '../../../lib/server/supabase';

type ReviewDecision = {
  decision: string;
  reason: string | null;
  reviewer_name: string | null;
  created_at: string;
};

export default async function LearnerProfilePage() {
  const supabase = await getSupabaseServerClient();

  const { data: userData } = await supabase.auth.getUser();
  const userEmail = userData?.user?.email ?? null;

  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('user_id, full_name, role, local_id')
    .maybeSingle();

  const { data: trainingHome, error: trainingError } = await supabase
    .from('v_learner_training_home')
    .select('program_name, status, progress_percent, current_unit_title')
    .maybeSingle();

  const { data: decisions, error: decisionsError } = await supabase
    .from('learner_review_decisions')
    .select('decision, reason, reviewer_name, created_at')
    .order('created_at', { ascending: false });

  const { data: local, error: localError } = await supabase
    .from('locals')
    .select('name')
    .eq('id', profile?.local_id ?? '')
    .maybeSingle();

  if (profileError || trainingError || decisionsError) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-4 px-4 py-6">
        <h1 className="text-2xl font-semibold text-slate-900">Perfil</h1>
        <p className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Error al cargar el perfil.
        </p>
      </main>
    );
  }

  if (!profile) {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-4 px-4 py-6">
        <h1 className="text-2xl font-semibold text-slate-900">Perfil</h1>
        <p className="rounded-md border border-dashed border-slate-200 p-4 text-sm text-slate-500">
          No encontramos tu perfil.
        </p>
      </main>
    );
  }

  const reviewHistory = (decisions as ReviewDecision[] | undefined) ?? [];
  const localName = !localError && local?.name ? local.name : null;

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-6 px-4 py-6">
      <header>
        <h1 className="text-2xl font-semibold text-slate-900">Perfil</h1>
        <p className="text-sm text-slate-500">
          Tu información y estado actual.
        </p>
      </header>

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="text-sm font-semibold text-slate-700">Perfil</h2>
        <div className="mt-3 space-y-2 text-sm text-slate-600">
          <div>
            <span className="text-xs text-slate-400">Nombre</span>
            <p className="font-semibold text-slate-800">
              {profile.full_name ?? userEmail ?? 'Aprendiz'}
            </p>
          </div>
          <div>
            <span className="text-xs text-slate-400">Rol</span>
            <p className="text-slate-700">{profile.role}</p>
          </div>
          <div>
            <span className="text-xs text-slate-400">Local</span>
            <p className="text-slate-700">
              {localName ?? profile.local_id ?? 'Local asignado'}
            </p>
          </div>
        </div>
      </section>

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="text-sm font-semibold text-slate-700">Estado actual</h2>
        <div className="mt-3 space-y-2 text-sm text-slate-600">
          <div>
            <span className="text-xs text-slate-400">Programa</span>
            <p className="text-slate-800">
              {trainingHome?.program_name ?? 'Programa activo'}
            </p>
          </div>
          <div className="flex items-center justify-between">
            <div>
              <span className="text-xs text-slate-400">Estado</span>
              <p className="text-slate-700">{trainingHome?.status ?? '—'}</p>
            </div>
            <div className="text-right">
              <span className="text-xs text-slate-400">Progreso</span>
              <p className="text-slate-700">
                {Math.round(Number(trainingHome?.progress_percent ?? 0))}%
              </p>
            </div>
          </div>
          <div>
            <span className="text-xs text-slate-400">Unidad actual</span>
            <p className="text-slate-700">
              {trainingHome?.current_unit_title ?? '—'}
            </p>
          </div>
        </div>
      </section>

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="text-sm font-semibold text-slate-700">
          Historial de decisiones
        </h2>
        {reviewHistory.length === 0 ? (
          <p className="mt-2 text-sm text-slate-500">
            Todavía no hay decisiones registradas.
          </p>
        ) : (
          <ul className="mt-3 flex flex-col gap-3 text-sm text-slate-700">
            {reviewHistory.map((decision, index) => {
              const createdAt = new Date(decision.created_at).toLocaleString(
                'es-AR',
                { dateStyle: 'medium', timeStyle: 'short' },
              );
              return (
                <li
                  key={`${decision.created_at}-${index}`}
                  className="rounded-md border border-slate-100 p-3"
                >
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <span className="font-semibold">{decision.decision}</span>
                    <span className="text-xs text-slate-400">{createdAt}</span>
                  </div>
                  <p className="mt-1 text-xs text-slate-500">
                    {decision.reviewer_name ?? 'Referente'}
                  </p>
                  {decision.reason ? (
                    <p className="mt-2 text-sm text-slate-600">
                      {decision.reason}
                    </p>
                  ) : null}
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </main>
  );
}
