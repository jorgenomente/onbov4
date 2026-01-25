'use client';

import { useMemo, useState } from 'react';
import { useSearchParams } from 'next/navigation';

import { getSupabaseBrowserClient } from '../../lib/client/supabase';

function isSafeInternalPath(path?: string | null) {
  if (!path) return null;
  if (!path.startsWith('/')) return null;
  if (path.startsWith('//')) return null;
  if (path.includes('://')) return null;
  return path;
}

export default function LoginForm() {
  const searchParams = useSearchParams();
  const nextParam = useMemo(
    () => isSafeInternalPath(searchParams.get('next')),
    [searchParams],
  );

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError('');
    setLoading(true);

    const supabase = getSupabaseBrowserClient();
    const { error: signInError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (signInError) {
      setError('No pudimos iniciar sesión. Revisá tus credenciales.');
      setLoading(false);
      return;
    }

    const redirectUrl = nextParam
      ? `/auth/redirect?next=${encodeURIComponent(nextParam)}`
      : '/auth/redirect';

    window.location.href = redirectUrl;
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-50 px-4 py-10">
      <div className="w-full max-w-sm rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
        <div className="space-y-2">
          <p className="text-xs font-semibold tracking-wide text-emerald-600 uppercase">
            ONBO
          </p>
          <h1 className="text-2xl font-semibold text-slate-900">
            Iniciar sesión
          </h1>
          <p className="text-sm text-slate-500">
            Accedé con tu email y contraseña.
          </p>
        </div>

        <form onSubmit={handleSubmit} className="mt-6 space-y-4">
          <label className="block text-sm font-medium text-slate-700">
            Email
            <input
              type="email"
              name="email"
              autoComplete="email"
              required
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              className="mt-2 w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:border-emerald-500 focus:outline-none"
              placeholder="tu@email.com"
            />
          </label>

          <label className="block text-sm font-medium text-slate-700">
            Contraseña
            <input
              type="password"
              name="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              className="mt-2 w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:border-emerald-500 focus:outline-none"
              placeholder="••••••••"
            />
          </label>

          {error ? (
            <p className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
              {error}
            </p>
          ) : null}

          <button
            type="submit"
            disabled={loading}
            className="flex w-full items-center justify-center rounded-md bg-emerald-600 px-3 py-2 text-sm font-semibold text-white transition disabled:cursor-not-allowed disabled:opacity-70"
          >
            {loading ? 'Ingresando...' : 'Ingresar'}
          </button>
        </form>
      </div>
    </main>
  );
}
