import Link from 'next/link';

import { requireUserAndRole } from '../../lib/server/requireRole';

type OrgLayoutProps = {
  children: React.ReactNode;
};

const navLinks = [
  { href: '/org/metrics', label: 'Metricas' },
  { href: '/org/config/bot', label: 'Config evaluacion final' },
  { href: '/org/config/knowledge-coverage', label: 'Knowledge coverage' },
  { href: '/org/bot-config', label: 'Escenarios practica' },
  { href: '/org/config/locals-program', label: 'Programa por local' },
];

export default async function OrgLayout({ children }: OrgLayoutProps) {
  await requireUserAndRole(['admin_org', 'superadmin']);

  return (
    <div className="min-h-screen bg-slate-50">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex w-full max-w-5xl items-center justify-between gap-4 px-4 py-4">
          <div>
            <p className="text-xs font-semibold tracking-wide text-emerald-600 uppercase">
              ONBO
            </p>
            <p className="text-sm font-semibold text-slate-800">
              Operacion org
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2 text-xs font-semibold text-slate-600">
            {navLinks.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className="rounded-md border border-slate-200 px-3 py-2"
              >
                {link.label}
              </Link>
            ))}
            <Link
              href="/auth/logout"
              className="rounded-md border border-slate-200 px-3 py-2"
            >
              Cerrar sesion
            </Link>
          </div>
        </div>
      </header>
      {children}
    </div>
  );
}
