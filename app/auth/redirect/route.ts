import type { NextRequest } from 'next/server';
import { NextResponse } from 'next/server';

import { getSupabaseRouteClient } from '../../../lib/server/supabase';

type Role = 'superadmin' | 'admin_org' | 'referente' | 'aprendiz';

type RoleConfig = {
  defaultPath: string;
  allowedPrefixes: string[];
};

const roleConfig: Record<Role, RoleConfig> = {
  aprendiz: {
    defaultPath: '/learner',
    allowedPrefixes: ['/learner'],
  },
  referente: {
    defaultPath: '/referente/review',
    allowedPrefixes: ['/referente'],
  },
  admin_org: {
    defaultPath: '/org/metrics',
    allowedPrefixes: ['/org'],
  },
  superadmin: {
    defaultPath: '/referente/review',
    allowedPrefixes: ['/', '/learner', '/referente', '/org', '/admin'],
  },
};

function applyCookies(source: NextResponse, target: NextResponse) {
  source.cookies.getAll().forEach((cookie) => {
    target.cookies.set(cookie);
  });
}

function isSafeInternalPath(path?: string | null) {
  if (!path) return null;
  if (!path.startsWith('/')) return null;
  if (path.startsWith('//')) return null;
  if (path.includes('://')) return null;
  return path;
}

export async function GET(request: NextRequest) {
  const response = NextResponse.next();
  const supabase = getSupabaseRouteClient(request, response);
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user?.id) {
    const redirectResponse = NextResponse.redirect(
      new URL('/login', request.url),
    );
    applyCookies(response, redirectResponse);
    return redirectResponse;
  }

  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('role')
    .eq('user_id', user.id)
    .maybeSingle();

  if (profileError || !profile?.role) {
    const redirectResponse = NextResponse.redirect(
      new URL('/login', request.url),
    );
    applyCookies(response, redirectResponse);
    return redirectResponse;
  }

  const role = profile.role as Role;
  const config = roleConfig[role] ?? roleConfig.aprendiz;
  const nextParam = request.nextUrl.searchParams.get('next');
  const safeNext = isSafeInternalPath(nextParam);

  let targetPath = config.defaultPath;
  if (
    safeNext &&
    config.allowedPrefixes.some((prefix) => safeNext.startsWith(prefix))
  ) {
    targetPath = safeNext;
  }

  const redirectResponse = NextResponse.redirect(
    new URL(targetPath, request.url),
  );
  applyCookies(response, redirectResponse);
  return redirectResponse;
}
