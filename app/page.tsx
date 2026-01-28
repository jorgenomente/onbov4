import { redirect } from 'next/navigation';

import { getSupabaseServerClient } from '../lib/server/supabase';

export default async function Home() {
  const supabase = await getSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (user?.id) {
    redirect('/auth/redirect');
  }

  redirect('/login');
}
