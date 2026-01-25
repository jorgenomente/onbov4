import { createBrowserClient } from '@supabase/ssr';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

function requirePublicEnv(value: string | undefined, name: string) {
  if (!value) {
    throw new Error(`${name} is not set`);
  }
  return value;
}

const requiredUrl = requirePublicEnv(supabaseUrl, 'NEXT_PUBLIC_SUPABASE_URL');
const requiredAnonKey = requirePublicEnv(
  supabaseAnonKey,
  'NEXT_PUBLIC_SUPABASE_ANON_KEY',
);

let browserClient: ReturnType<typeof createBrowserClient> | null = null;

export function getSupabaseBrowserClient() {
  if (browserClient) {
    return browserClient;
  }

  browserClient = createBrowserClient(requiredUrl, requiredAnonKey);
  return browserClient;
}
