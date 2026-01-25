import { Suspense } from 'react';

import LoginForm from './LoginForm';

export default function LoginPage() {
  return (
    <Suspense
      fallback={
        <main className="flex min-h-screen items-center justify-center bg-slate-50 px-4 py-10">
          <div className="w-full max-w-sm rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
            <p className="text-sm text-slate-500">Cargando...</p>
          </div>
        </main>
      }
    >
      <LoginForm />
    </Suspense>
  );
}
