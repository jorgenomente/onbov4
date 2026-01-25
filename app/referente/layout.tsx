import Link from 'next/link';

import { requireUserAndRole } from '../../lib/server/requireRole';

type ReferenteLayoutProps = {
  children: React.ReactNode;
};

export default async function ReferenteLayout({
  children,
}: ReferenteLayoutProps) {
  await requireUserAndRole(['referente', 'admin_org', 'superadmin']);

  return (
    <div className="min-h-screen bg-slate-50">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex w-full max-w-4xl items-center justify-between px-4 py-4">
          <div>
            <p className="text-xs font-semibold tracking-wide text-emerald-600 uppercase">
              ONBO
            </p>
            <p className="text-sm font-semibold text-slate-800">
              Revisión de aprendices
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
      {children}
    </div>
  );
}
