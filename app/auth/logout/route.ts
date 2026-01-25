import type { NextRequest } from 'next/server';
import { NextResponse } from 'next/server';

import { getSupabaseRouteClient } from '../../../lib/server/supabase';

function applyCookies(source: NextResponse, target: NextResponse) {
  source.cookies.getAll().forEach((cookie) => {
    target.cookies.set(cookie);
  });
}

export async function GET(request: NextRequest) {
  const response = NextResponse.next();
  const supabase = getSupabaseRouteClient(request, response);

  await supabase.auth.signOut();

  const redirectResponse = NextResponse.redirect(
    new URL('/login', request.url),
  );
  applyCookies(response, redirectResponse);
  return redirectResponse;
}
