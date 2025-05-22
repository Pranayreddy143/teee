/*
  # Consolidated Migration for Help Desk System
  
  1. Tables
    - users (extends auth.users)
    - organizations
    - user_organizations
    - tickets
    - ticket_history
    - chat_rooms
    - chat_participants
    - chat_messages
    - chat_attachments

  2. Functions
    - All functions with SECURITY DEFINER and search_path set
    - Optimized RLS policies using (SELECT auth.uid())
    
  3. Security
    - RLS enabled on all tables
    - Consolidated policies to avoid duplicates
*/

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop existing objects
DO $$ 
BEGIN
    -- Drop triggers
    DROP TRIGGER IF EXISTS set_updated_at ON tickets;
    DROP TRIGGER IF EXISTS track_ticket_changes ON tickets;
    DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
    DROP TRIGGER IF EXISTS update_room_timestamp_on_message ON chat_messages;

    -- Drop functions
    DROP FUNCTION IF EXISTS public.handle_new_user();
    DROP FUNCTION IF EXISTS public.generate_ticket_number();
    DROP FUNCTION IF EXISTS public.notify_ticket_assignment(uuid,uuid);
    DROP FUNCTION IF EXISTS public.get_user_notifications(uuid);
    DROP FUNCTION IF EXISTS public.get_dashboard_stats(uuid);
    DROP FUNCTION IF EXISTS public.update_room_timestamp();
    DROP FUNCTION IF EXISTS public.track_ticket_changes();

    -- Drop policies
    DROP POLICY IF EXISTS "Users can update their own profile" ON users;
    DROP POLICY IF EXISTS "System can create users" ON users;
    DROP POLICY IF EXISTS "Users can view all users" ON users;
    DROP POLICY IF EXISTS "Anyone can view organizations" ON organizations;
    DROP POLICY IF EXISTS "Users can view their organizations" ON user_organizations;
    DROP POLICY IF EXISTS "Users can access tickets in their organizations" ON tickets;
    DROP POLICY IF EXISTS "Users can view rooms they are participants in" ON chat_rooms;
    DROP POLICY IF EXISTS "Users can create rooms" ON chat_rooms;
    DROP POLICY IF EXISTS "Users can view participants in their rooms" ON chat_participants;
    DROP POLICY IF EXISTS "Users can join rooms they are invited to" ON chat_participants;
    DROP POLICY IF EXISTS "Users can view messages in their rooms" ON chat_messages;
    DROP POLICY IF EXISTS "Users can send messages to their rooms" ON chat_messages;
    DROP POLICY IF EXISTS "Users can edit their own messages" ON chat_messages;
    DROP POLICY IF EXISTS "Users can view attachments in their rooms" ON chat_attachments;
    DROP POLICY IF EXISTS "Users can upload attachments to their messages" ON chat_attachments;
END $$;

-- Create Tables

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

-- Chat Rooms Table
CREATE TABLE IF NOT EXISTS chat_rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text,
  type text NOT NULL CHECK (type IN ('direct', 'group')),
  created_by uuid REFERENCES auth.users(id) NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Chat Participants Table
CREATE TABLE IF NOT EXISTS chat_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid REFERENCES chat_rooms(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES auth.users(id) NOT NULL,
  role text DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  joined_at timestamptz DEFAULT now(),
  last_read_at timestamptz DEFAULT now(),
  UNIQUE(room_id, user_id)
);

-- Chat Messages Table
CREATE TABLE IF NOT EXISTS chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid REFERENCES chat_rooms(id) ON DELETE CASCADE NOT NULL,
  sender_id uuid REFERENCES auth.users(id) NOT NULL,
  message_type text NOT NULL CHECK (message_type IN ('text', 'file', 'document')),
  content text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  is_edited boolean DEFAULT false
);

-- Chat Attachments Table
CREATE TABLE IF NOT EXISTS chat_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid REFERENCES chat_messages(id) ON DELETE CASCADE NOT NULL,
  file_name text NOT NULL,
  file_size bigint NOT NULL,
  file_type text NOT NULL,
  storage_path text NOT NULL,
  created_at timestamptz DEFAULT now()
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

-- Create Functions
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
$$;

CREATE OR REPLACE FUNCTION notify_ticket_assignment(
  p_ticket_id uuid,
  p_assigned_to uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
    (SELECT auth.uid()),
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
$$;

CREATE OR REPLACE FUNCTION get_user_notifications(p_user_id uuid)
RETURNS TABLE (
  ticket_id uuid,
  ticket_no text,
  name_of_client text,
  created_on timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
$$;

CREATE OR REPLACE FUNCTION get_dashboard_stats(p_organization_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
$$;

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'name', 'user')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION update_room_timestamp()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE chat_rooms
  SET updated_at = now()
  WHERE id = NEW.room_id;
  RETURN NEW;
END;
$$;

-- Create Triggers
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

CREATE TRIGGER update_room_timestamp_on_message
  AFTER INSERT ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_room_timestamp();

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_attachments ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies
CREATE POLICY "Users can view all users"
  ON users FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "System can create users"
  ON users FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can update their own profile"
  ON users FOR UPDATE
  TO authenticated
  USING (id = (SELECT auth.uid()))
  WITH CHECK (id = (SELECT auth.uid()));

CREATE POLICY "Anyone can view organizations"
  ON organizations
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Users can view their organizations"
  ON user_organizations
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can access tickets in their organizations"
  ON tickets
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_organizations
      WHERE user_id = (SELECT auth.uid())
      AND organization_id = tickets.organization_id
    )
  );

CREATE POLICY "Users can view rooms they are participants in"
  ON chat_rooms
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_participants
      WHERE room_id = chat_rooms.id
      AND user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY "Users can create rooms"
  ON chat_rooms
  FOR INSERT
  TO authenticated
  WITH CHECK (created_by = (SELECT auth.uid()));

CREATE POLICY "Users can view participants in their rooms"
  ON chat_participants
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_participants AS cp
      WHERE cp.room_id = chat_participants.room_id
      AND cp.user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY "Users can join rooms they are invited to"
  ON chat_participants
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid()) OR
    EXISTS (
      SELECT 1 FROM chat_participants
      WHERE room_id = chat_participants.room_id
      AND user_id = (SELECT auth.uid())
      AND role = 'admin'
    )
  );

CREATE POLICY "Users can view messages in their rooms"
  ON chat_messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_participants
      WHERE room_id = chat_messages.room_id
      AND user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY "Users can send messages to their rooms"
  ON chat_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM chat_participants
      WHERE room_id = chat_messages.room_id
      AND user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY "Users can edit their own messages"
  ON chat_messages
  FOR UPDATE
  TO authenticated
  USING (sender_id = (SELECT auth.uid()))
  WITH CHECK (sender_id = (SELECT auth.uid()));

CREATE POLICY "Users can view attachments in their rooms"
  ON chat_attachments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_messages
      JOIN chat_participants ON chat_messages.room_id = chat_participants.room_id
      WHERE chat_messages.id = chat_attachments.message_id
      AND chat_participants.user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY "Users can upload attachments to their messages"
  ON chat_attachments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM chat_messages
      WHERE id = message_id
      AND sender_id = (SELECT auth.uid())
    )
  );

-- Insert default organizations
INSERT INTO organizations (name, slug, theme_primary_color, theme_secondary_color, theme_accent_color)
VALUES 
  ('FreeTaxFiler', 'free-tax-filer', '#1a365d', '#2d3748', '#4299e1'),
  ('OnlineTaxFiler', 'online-tax-filer', '#276749', '#2f855a', '#48bb78'),
  ('USeTaxFiler', 'use-tax-filer', '#744210', '#975a16', '#ecc94b'),
  ('AIUSTax', 'aius-tax', '#702459', '#97266d', '#ed64a6')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  theme_primary_color = EXCLUDED.theme_primary_color,
  theme_secondary_color = EXCLUDED.theme_secondary_color,
  theme_accent_color = EXCLUDED.theme_accent_color;