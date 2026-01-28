'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

type NavItem = {
  href: string;
  label: string;
};

const navItems: NavItem[] = [
  { href: '/referente/review', label: 'Revisión' },
  { href: '/referente/alerts', label: 'Alertas' },
];

export default function ReferenteNav() {
  const pathname = usePathname();

  return (
    <div className="flex flex-wrap items-center gap-2 text-xs font-semibold text-slate-600">
      {navItems.map((item) => {
        const isActive = pathname?.startsWith(item.href);
        return (
          <Link
            key={item.href}
            href={item.href}
            className={`rounded-md border px-3 py-2 transition ${
              isActive
                ? 'border-emerald-300 bg-emerald-50 text-emerald-700'
                : 'border-slate-200 text-slate-600 hover:text-slate-800'
            }`}
          >
            {item.label}
          </Link>
        );
      })}
      <Link
        href="/auth/logout"
        className="rounded-md border border-slate-200 px-3 py-2"
      >
        Cerrar sesión
      </Link>
    </div>
  );
}
