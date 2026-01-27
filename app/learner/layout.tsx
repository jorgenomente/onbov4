import Link from 'next/link';

import { requireUserAndRole } from '../../lib/server/requireRole';
import LearnerTabs from './LearnerTabs';

type LearnerLayoutProps = {
  children: React.ReactNode;
};

export default async function LearnerLayout({ children }: LearnerLayoutProps) {
  await requireUserAndRole(['aprendiz']);

  return (
    <div className="min-h-screen bg-slate-50">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex w-full max-w-3xl items-center justify-between px-4 py-4">
          <div>
            <p className="text-xs font-semibold tracking-wide text-emerald-600 uppercase">
              ONBO
            </p>
            <p className="text-sm font-semibold text-slate-800">
              Entrenamiento
            </p>
          </div>
          <Link
            href="/auth/logout"
            className="rounded-md border border-slate-200 px-3 py-2 text-xs font-semibold text-slate-600"
          >
            Cerrar sesión
          </Link>
        </div>
      </header>
      <LearnerTabs />
      {children}
    </div>
  );
}
