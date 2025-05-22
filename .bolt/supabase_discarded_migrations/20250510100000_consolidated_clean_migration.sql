-- Consolidated migration for Supabase project (fixed for app requirements)

-- 1. USERS TABLE
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  email text UNIQUE NOT NULL,
  name text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz
);

-- 2. ORGANIZATIONS TABLE
CREATE TABLE IF NOT EXISTS organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE NOT NULL,
  theme_primary_color text NOT NULL,
  theme_secondary_color text NOT NULL,
  theme_accent_color text NOT NULL,
  logo_url text,
  created_at timestamptz DEFAULT now()
);

-- 3. USER-ORGANIZATIONS TABLE
CREATE TABLE IF NOT EXISTS user_organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) NOT NULL,
  organization_id uuid REFERENCES organizations(id) NOT NULL,
  role text DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, organization_id)
);

-- 4. TICKETS TABLE
CREATE TABLE IF NOT EXISTS tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  title text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'closed')),
  priority text NOT NULL DEFAULT 'normal',
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  organization_id uuid REFERENCES organizations(id) ON DELETE CASCADE,
  assigned_to uuid REFERENCES users(id) ON DELETE SET NULL,
  closed_on timestamptz,
  closed_by uuid REFERENCES users(id) ON DELETE SET NULL,
  attachment_url text,
  attachment_name text,
  attachment_size integer
);
CREATE INDEX IF NOT EXISTS idx_tickets_organization ON tickets(organization_id);

-- Trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at ON tickets;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON tickets
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 5. TICKET HISTORY TABLE
CREATE TABLE IF NOT EXISTS ticket_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid REFERENCES tickets(id) NOT NULL,
  changed_by uuid REFERENCES users(id) NOT NULL,
  changed_at timestamptz DEFAULT now(),
  field_name text NOT NULL,
  old_value text,
  new_value text,
  created_at timestamptz DEFAULT now()
);

-- 6. STORAGE BUCKET FOR ATTACHMENTS
INSERT INTO storage.buckets (id, name, public)
VALUES ('ticket-attachments', 'ticket-attachments', false)
ON CONFLICT (id) DO NOTHING;

-- 7. STORAGE POLICIES
DROP POLICY IF EXISTS "Authenticated users can upload ticket attachments" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can view ticket attachments" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete their attachments" ON storage.objects;
CREATE POLICY "Authenticated users can upload ticket attachments"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'ticket-attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
CREATE POLICY "Authenticated users can view ticket attachments"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'ticket-attachments');
CREATE POLICY "Authenticated users can delete their attachments"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'ticket-attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 8. RLS POLICIES
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_history ENABLE ROW LEVEL SECURITY;

-- USERS POLICIES
CREATE POLICY "Allow authenticated users to view users"
  ON users FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow system to create users"
  ON users FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow users to update themselves"
  ON users FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
DROP POLICY IF EXISTS "Allow admins to update users" ON users;
CREATE POLICY "Allow users to update themselves or admins to update anyone"
  ON users FOR UPDATE TO authenticated
  USING (auth.uid() = id OR (
    EXISTS (
      SELECT 1 FROM user_organizations uo
      WHERE uo.user_id = auth.uid() AND uo.role = 'admin'
    )
  ))
  WITH CHECK (auth.uid() = id OR (
    EXISTS (
      SELECT 1 FROM user_organizations uo
      WHERE uo.user_id = auth.uid() AND uo.role = 'admin'
    )
  ));

-- ORGANIZATIONS POLICIES
CREATE POLICY "Allow public read access to organizations"
  ON organizations FOR SELECT TO public USING (true);

-- USER_ORGANIZATIONS POLICIES
CREATE POLICY "Users can view their organization memberships"
  ON user_organizations FOR SELECT TO authenticated USING (user_id = auth.uid());

-- TICKETS POLICIES
CREATE POLICY "Users can access tickets in their organizations"
  ON tickets FOR ALL TO authenticated USING (
    organization_id IN (SELECT organization_id FROM user_organizations WHERE user_id = auth.uid())
  );

-- TICKET_HISTORY POLICIES
CREATE POLICY "All authenticated users can view ticket history"
  ON ticket_history FOR SELECT TO authenticated USING (true);
CREATE POLICY "Only authenticated users can insert ticket history"
  ON ticket_history FOR INSERT TO authenticated WITH CHECK (true);

-- 9. FUNCTIONS & TRIGGERS
-- Function to track ticket changes
CREATE OR REPLACE FUNCTION track_ticket_changes()
RETURNS TRIGGER AS $$
DECLARE
  changed_fields text[] := ARRAY['status','description','assigned_to','priority'];
  old_value text;
  new_value text;
BEGIN
  FOR i IN 1..array_length(changed_fields, 1) LOOP
    EXECUTE format('SELECT ($1.%I)::text', changed_fields[i]) USING OLD INTO old_value;
    EXECUTE format('SELECT ($1.%I)::text', changed_fields[i]) USING NEW INTO new_value;
    IF new_value IS DISTINCT FROM old_value THEN
      INSERT INTO ticket_history (
        ticket_id, changed_by, field_name, old_value, new_value
      ) VALUES (
        NEW.id, auth.uid(), changed_fields[i], old_value, new_value
      );
    END IF;
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS track_ticket_changes ON tickets;
CREATE TRIGGER track_ticket_changes
  AFTER UPDATE ON tickets
  FOR EACH ROW
  EXECUTE FUNCTION track_ticket_changes();

-- Function to handle new user creation from auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, name)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'name')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to add user to all organizations as admin (optional, can be customized)
CREATE OR REPLACE FUNCTION add_user_to_organizations(user_id uuid)
RETURNS void AS $$
BEGIN
  INSERT INTO user_organizations (user_id, organization_id, role)
  SELECT user_id, id, 'admin' FROM organizations
  ON CONFLICT (user_id, organization_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate ticket number
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS text AS $$
DECLARE
  new_ticket_no text;
BEGIN
  SELECT CONCAT('TKT-', TO_CHAR(NOW(), 'YYYYMMDD'), '-', 
    LPAD(COALESCE(
      (SELECT COUNT(*) + 1 
       FROM tickets 
       WHERE created_at::date = CURRENT_DATE), 
      1)::text, 
    4, '0'))
  INTO new_ticket_no;
  RETURN new_ticket_no;
END;
$$ LANGUAGE plpgsql;

-- Function to handle ticket creation (matches frontend call)
CREATE OR REPLACE FUNCTION public.create_ticket(
  p_assigned_to uuid,
  p_client_file_no text,
  p_description text,
  p_issue_type text,
  p_mobile_no text,
  p_name_of_client text,
  p_opened_by text,
  p_organization_id uuid
)
RETURNS uuid AS $$
DECLARE
  new_ticket_id uuid;
BEGIN
  INSERT INTO tickets (
    ticket_no,
    created_at,
    opened_by,
    client_file_no,
    mobile_no,
    name_of_client,
    issue_type,
    description,
    status,
    organization_id,
    assigned_to
  ) VALUES (
    generate_ticket_number(),
    now(),
    p_opened_by,
    p_client_file_no,
    p_mobile_no,
    p_name_of_client,
    p_issue_type,
    p_description,
    'open',
    p_organization_id,
    p_assigned_to
  )
  RETURNING id INTO new_ticket_id;
  RETURN new_ticket_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. DASHBOARD STATS FUNCTION
CREATE OR REPLACE FUNCTION get_dashboard_stats(p_organization_id uuid)
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'totalTickets', (
      SELECT COUNT(*) FROM tickets WHERE organization_id = p_organization_id
    ),
    'openTickets', (
      SELECT COUNT(*) FROM tickets WHERE organization_id = p_organization_id AND status = 'open'
    ),
    'resolvedToday', (
      SELECT COUNT(*) FROM tickets WHERE organization_id = p_organization_id AND status = 'closed' AND closed_on::date = CURRENT_DATE
    ),
    'avgResponseTime', (
      SELECT COALESCE(EXTRACT(EPOCH FROM AVG(closed_on::timestamp - created_at::timestamp))/3600, 0)::numeric(10,2)
      FROM tickets WHERE organization_id = p_organization_id AND status = 'closed'
    )
  ) INTO result;
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. INSERT DEFAULT ORGANIZATIONS
INSERT INTO organizations (name, slug, theme_primary_color, theme_secondary_color, theme_accent_color)
VALUES 
  ('FreeTaxFiler', 'free-tax-filer', '#1a365d', '#2d3748', '#4299e1'),
  ('OnlineTaxFiler', 'online-tax-filer', '#276749', '#2f855a', '#48bb78'),
  ('AIUSTax', 'aius-tax', '#702459', '#97266d', '#ed64a6')
ON CONFLICT (slug) DO NOTHING;

-- END OF MIGRATION
