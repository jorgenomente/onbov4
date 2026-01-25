import 'server-only';

import { redirect } from 'next/navigation';

import { getSupabaseServerClient } from './supabase';

type Role = 'superadmin' | 'admin_org' | 'referente' | 'aprendiz';

type RequireRoleResult = {
  userId: string;
  role: Role;
};

export async function requireUserAndRole(
  allowedRoles: Role[],
  redirectTo = '/auth/redirect',
): Promise<RequireRoleResult> {
  const supabase = await getSupabaseServerClient();
  const { data: userData, error: userError } = await supabase.auth.getUser();

  if (userError || !userData?.user?.id) {
    redirect('/login');
  }

  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('role')
    .eq('user_id', userData.user.id)
    .maybeSingle();

  if (profileError || !profile?.role) {
    redirect('/login');
  }

  const role = profile.role as Role;

  if (!allowedRoles.includes(role)) {
    redirect(redirectTo);
  }

  return { userId: userData.user.id, role };
}
