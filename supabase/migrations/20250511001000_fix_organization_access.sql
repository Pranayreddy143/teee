-- Drop existing policy if it exists
drop policy if exists "Allow public read access to organizations" on organizations;

-- Enable RLS (if not already enabled)
alter table organizations enable row level security;

-- Allow public read access to organizations
create policy "Allow public read access to organizations"
  on organizations
  for select
  using (true);

-- Make sure organizations are accessible without auth
-- Revoke first to avoid "permission already granted" errors
revoke select on organizations from anon;
revoke select on organizations from authenticated;
grant select on organizations to anon;
grant select on organizations to authenticated;
