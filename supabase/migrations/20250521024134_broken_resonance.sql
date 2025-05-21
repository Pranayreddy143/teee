-- Clean consolidated migration for Supabase project
-- Migration date: 2025-05-10
-- This is the single source of truth for the database schema

-- [ 1. Enable Extensions ]
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- [ 2. Drop existing objects (if migrating) ]
-- First drop triggers that depend on functions
DROP TRIGGER IF EXISTS set_updated_at ON tickets;
DROP TRIGGER IF EXISTS track_ticket_changes ON tickets;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Then drop functions
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.create_ticket(uuid,text,text,text,text,text,text,uuid);
DROP FUNCTION IF EXISTS public.assign_ticket(uuid,uuid);
DROP FUNCTION IF EXISTS public.generate_ticket_number();
DROP FUNCTION IF EXISTS public.add_user_to_organizations(uuid);
DROP FUNCTION IF EXISTS public.get_dashboard_stats(uuid);
DROP FUNCTION IF EXISTS public.update_updated_at_column();
DROP FUNCTION IF EXISTS public.track_ticket_changes();

-- [ 3. Create Tables ]

-- Users table (extends auth.users)
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  email text UNIQUE NOT NULL,
  name text,
  role text NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Organizations table
CREATE TABLE IF NOT EXISTS organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE NOT NULL,
  theme_primary_color text NOT NULL DEFAULT '#1a365d',
  theme_secondary_color text NOT NULL DEFAULT '#2d3748',
  theme_accent_color text NOT NULL DEFAULT '#4299e1',
  logo_url text,
  created_at timestamptz DEFAULT now()
);

-- User-Organizations mapping
CREATE TABLE IF NOT EXISTS user_organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  organization_id uuid REFERENCES organizations(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, organization_id)
);

-- Tickets table
CREATE TABLE IF NOT EXISTS tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_no text UNIQUE NOT NULL,
  created_on timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  opened_by text NOT NULL,
  client_file_no text NOT NULL,
  mobile_no text NOT NULL,
  name_of_client text NOT NULL,
  issue_type text NOT NULL,
  description text,
  resolution text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'closed')),
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  organization_id uuid REFERENCES organizations(id) ON DELETE CASCADE NOT NULL,
  assigned_to uuid REFERENCES users(id) ON DELETE SET NULL,
  closed_on timestamptz,
  closed_by uuid REFERENCES users(id) ON DELETE SET NULL,
  attachment_url text,
  attachment_name text,
  attachment_size integer
);

-- Ticket history for auditing
CREATE TABLE IF NOT EXISTS ticket_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid REFERENCES tickets(id) ON DELETE CASCADE NOT NULL,
  changed_by uuid REFERENCES users(id) ON DELETE SET NULL NOT NULL,
  changed_at timestamptz DEFAULT now(),
  field_name text NOT NULL,
  old_value text,
  new_value text
);

-- [ 4. Create Indexes ]
CREATE INDEX IF NOT EXISTS idx_tickets_organization ON tickets(organization_id);
CREATE INDEX IF NOT EXISTS idx_tickets_assigned_to ON tickets(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets(status);
CREATE INDEX IF NOT EXISTS idx_ticket_history_ticket ON ticket_history(ticket_id);
CREATE INDEX IF NOT EXISTS idx_user_organizations_user ON user_organizations(user_id);
CREATE INDEX IF NOT EXISTS idx_user_organizations_org ON user_organizations(organization_id);

-- [ 5. Storage Setup ]
-- Create bucket for ticket attachments
INSERT INTO storage.buckets (id, name, public)
VALUES ('ticket-attachments', 'ticket-attachments', false)
ON CONFLICT (id) DO NOTHING;

-- [ 6. Functions ]

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Generate ticket numbers
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS text AS $$
DECLARE
  new_ticket_no text;
BEGIN
  SELECT CONCAT('TKT-', TO_CHAR(NOW(), 'YYYYMMDD'), '-', 
    LPAD(COALESCE(
      (SELECT COUNT(*) + 1 
       FROM tickets 
       WHERE created_on::date = CURRENT_DATE), 
      1)::text, 
    4, '0'))
  INTO new_ticket_no;
  RETURN new_ticket_no;
END;
$$ LANGUAGE plpgsql;

-- Track ticket changes
CREATE OR REPLACE FUNCTION track_ticket_changes()
RETURNS TRIGGER AS $$
DECLARE
  changed_fields text[] := ARRAY[
    'status',
    'description',
    'assigned_to',
    'priority',
    'resolution',
    'closed_on',
    'closed_by'
  ];
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

-- Handle new user creation
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'name', 'user')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add user to organizations
CREATE OR REPLACE FUNCTION add_user_to_organizations(user_id uuid)
RETURNS void AS $$
BEGIN
  INSERT INTO user_organizations (user_id, organization_id, role)
  SELECT user_id, id, 'member' FROM organizations
  ON CONFLICT (user_id, organization_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create ticket
CREATE OR REPLACE FUNCTION create_ticket(
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
    opened_by,
    client_file_no,
    mobile_no,
    name_of_client,
    issue_type,
    description,
    organization_id,
    assigned_to
  ) VALUES (
    generate_ticket_number(),
    p_opened_by,
    p_client_file_no,
    p_mobile_no,
    p_name_of_client,
    p_issue_type,
    p_description,
    p_organization_id,
    p_assigned_to
  )
  RETURNING id INTO new_ticket_id;
  
  RETURN new_ticket_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get dashboard stats
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
      SELECT COUNT(*) FROM tickets 
      WHERE organization_id = p_organization_id 
      AND status = 'closed' 
      AND closed_on::date = CURRENT_DATE
    ),
    'avgResponseTime', (
      SELECT COALESCE(
        EXTRACT(EPOCH FROM AVG(closed_on - created_on))/3600, 
        0
      )::numeric(10,2)
      FROM tickets 
      WHERE organization_id = p_organization_id 
      AND status = 'closed'
    )
  ) INTO result;
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- [ 7. Triggers ]
DROP TRIGGER IF EXISTS set_updated_at ON tickets;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON tickets
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS track_ticket_changes ON tickets;
CREATE TRIGGER track_ticket_changes
  AFTER UPDATE ON tickets
  FOR EACH ROW
  EXECUTE FUNCTION track_ticket_changes();

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- [ 8. Enable RLS ]
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_history ENABLE ROW LEVEL SECURITY;

-- [ 9. RLS Policies ]

-- Drop existing policies first
DROP POLICY IF EXISTS "Users can view all users" ON users;
DROP POLICY IF EXISTS "System can create users" ON users;
DROP POLICY IF EXISTS "Users can update their own profile" ON users;
DROP POLICY IF EXISTS "Anyone can view organizations" ON organizations;
DROP POLICY IF EXISTS "Users can view their organizations" ON user_organizations;
DROP POLICY IF EXISTS "Admins can manage organization members" ON user_organizations;
DROP POLICY IF EXISTS "Users can access tickets in their organizations" ON tickets;
DROP POLICY IF EXISTS "Users can view ticket history in their organizations" ON ticket_history;
DROP POLICY IF EXISTS "Users can upload ticket attachments" ON storage.objects;
DROP POLICY IF EXISTS "Organization members can view attachments" ON storage.objects;

-- User policies
CREATE POLICY "Users can view all users"
  ON users FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "System can create users"
  ON users FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can update their own profile"
  ON users FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Organization policies
CREATE POLICY "Anyone can view organizations"
  ON organizations FOR SELECT
  TO public USING (true);

-- User-Organization policies
CREATE POLICY "Users can view their organizations"
  ON user_organizations FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Admins can manage organization members"
  ON user_organizations FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND role = 'admin'
  ));

-- Ticket policies
CREATE POLICY "Users can access tickets in their organizations"
  ON tickets FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_organizations
      WHERE user_id = auth.uid()
      AND organization_id = tickets.organization_id
    )
  );

-- Ticket history policies
CREATE POLICY "Users can view ticket history in their organizations"
  ON ticket_history FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM tickets t
      JOIN user_organizations uo ON t.organization_id = uo.organization_id
      WHERE t.id = ticket_history.ticket_id
      AND uo.user_id = auth.uid()
    )
  );

-- Storage policies
CREATE POLICY "Users can upload ticket attachments"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'ticket-attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Organization members can view attachments"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'ticket-attachments'
  );

-- [ 10. Default Data ]
INSERT INTO organizations (name, slug, theme_primary_color, theme_secondary_color, theme_accent_color)
VALUES 
  ('FreeTaxFiler', 'free-tax-filer', '#1a365d', '#2d3748', '#4299e1'),
  ('OnlineTaxFiler', 'online-tax-filer', '#276749', '#2f855a', '#48bb78'),
  ('AIUSTax', 'aius-tax', '#702459', '#97266d', '#ed64a6')
ON CONFLICT (slug) DO NOTHING;

-- [ End of migration ]