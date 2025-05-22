/*
  # Initial database schema setup
  
  1. Tables
    - users
    - organizations
    - user_organizations
    - tickets
    - ticket_history
  
  2. Functions
    - Ticket management
    - Notifications
    - Statistics
*/

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

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

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_tickets_organization ON tickets(organization_id);
CREATE INDEX IF NOT EXISTS idx_tickets_assigned_to ON tickets(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_status_org ON tickets(status, organization_id);
CREATE INDEX IF NOT EXISTS idx_tickets_created_on ON tickets(created_on);
CREATE INDEX IF NOT EXISTS idx_tickets_assigned_status ON tickets(assigned_to, status);
CREATE INDEX IF NOT EXISTS idx_ticket_history_ticket ON ticket_history(ticket_id);
CREATE INDEX IF NOT EXISTS idx_user_organizations_user ON user_organizations(user_id);
CREATE INDEX IF NOT EXISTS idx_user_organizations_org ON user_organizations(organization_id);

-- Functions
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

CREATE OR REPLACE FUNCTION notify_ticket_assignment(
  p_ticket_id uuid,
  p_assigned_to uuid
)
RETURNS void AS $$
BEGIN
  INSERT INTO ticket_history (
    ticket_id,
    changed_by,
    field_name,
    old_value,
    new_value
  )
  SELECT
    p_ticket_id,
    auth.uid(),
    'assigned_to',
    (SELECT email FROM users WHERE id = tickets.assigned_to),
    (SELECT email FROM users WHERE id = p_assigned_to)
  FROM tickets
  WHERE id = p_ticket_id;

  UPDATE tickets
  SET 
    assigned_to = p_assigned_to,
    updated_at = now()
  WHERE id = p_ticket_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_notifications(p_user_id uuid)
RETURNS TABLE (
  ticket_id uuid,
  ticket_no text,
  name_of_client text,
  created_on timestamptz,
  status text
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.id,
    t.ticket_no,
    t.name_of_client,
    t.created_on,
    t.status
  FROM tickets t
  WHERE t.assigned_to = p_user_id
  AND t.status = 'open'
  ORDER BY t.created_on DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies
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

CREATE POLICY "Anyone can view organizations"
  ON organizations FOR SELECT
  TO public USING (true);

CREATE POLICY "Users can view their organizations"
  ON user_organizations FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

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

-- Insert default organizations
INSERT INTO organizations (name, slug, theme_primary_color, theme_secondary_color, theme_accent_color)
VALUES 
  ('FreeTaxFiler', 'free-tax-filer', '#1a365d', '#2d3748', '#4299e1'),
  ('OnlineTaxFiler', 'online-tax-filer', '#276749', '#2f855a', '#48bb78'),
  ('USeTaxFiler', 'use-tax-filer', '#744210', '#975a16', '#ecc94b'),
  ('AIUSTax', 'aius-tax', '#702459', '#97266d', '#ed64a6')
ON CONFLICT (slug) DO NOTHING;