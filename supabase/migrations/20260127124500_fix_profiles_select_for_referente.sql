-- Allow referente/admin to read profiles in scope (needed for review queue)

drop policy if exists profiles_select_superadmin on public.profiles;
create policy profiles_select_superadmin
on public.profiles
for select
using (public.current_role() = 'superadmin');

drop policy if exists profiles_select_admin_org on public.profiles;
create policy profiles_select_admin_org
on public.profiles
for select
using (
  public.current_role() = 'admin_org'
  and org_id = public.current_org_id()
);

drop policy if exists profiles_select_referente on public.profiles;
create policy profiles_select_referente
on public.profiles
for select
using (
  public.current_role() = 'referente'
  and local_id = public.current_local_id()
);
