'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const tabs = [
  { href: '/learner/training', label: 'Entrenamiento' },
  { href: '/learner/progress', label: 'Progreso' },
  { href: '/learner/profile', label: 'Perfil' },
];

export default function LearnerTabs() {
  const pathname = usePathname();

  return (
    <nav className="border-b border-slate-200 bg-white">
      <div className="mx-auto flex w-full max-w-3xl items-center gap-2 px-4">
        {tabs.map((tab) => {
          const isActive = pathname?.startsWith(tab.href);
          return (
            <Link
              key={tab.href}
              href={tab.href}
              className={`inline-flex flex-1 items-center justify-center border-b-2 px-2 py-3 text-sm font-semibold transition ${
                isActive
                  ? 'border-emerald-600 text-emerald-700'
                  : 'border-transparent text-slate-500 hover:text-slate-700'
              }`}
            >
              {tab.label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
