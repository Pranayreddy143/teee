/*
  # Add organizations and user-organization relationship

  1. New Tables
    - `organizations`
      - Basic organization info and theme settings
    - `user_organizations`
      - Links users to organizations they have access to

  2. Changes
    - Add organization_id to tickets table
    - Update RLS policies

  3. Security
    - Enable RLS on new tables
    - Add appropriate access policies
*/

-- Organizations table
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

-- User-Organization relationship
CREATE TABLE IF NOT EXISTS user_organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) NOT NULL,
  organization_id uuid REFERENCES organizations(id) NOT NULL,
  role text DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, organization_id)
);

-- Add organization_id to tickets
ALTER TABLE tickets ADD COLUMN organization_id uuid REFERENCES organizations(id);
CREATE INDEX idx_tickets_organization ON tickets(organization_id);

-- Enable RLS
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_organizations ENABLE ROW LEVEL SECURITY;

-- Policies for organizations
CREATE POLICY "Users can view organizations they belong to"
  ON organizations
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_organizations
      WHERE organization_id = organizations.id
      AND user_id = auth.uid()
    )
  );

-- Policies for user_organizations
CREATE POLICY "Users can view their organization memberships"
  ON user_organizations
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Update tickets policy to include organization check
CREATE POLICY "Users can access tickets in their organizations"
  ON tickets
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_organizations
      WHERE organization_id = tickets.organization_id
      AND user_id = auth.uid()
    )
  );

-- Insert default organizations
INSERT INTO organizations (name, slug, theme_primary_color, theme_secondary_color, theme_accent_color)
VALUES 
  ('FreeTaxFiler', 'free-tax-filer', '#1a365d', '#2d3748', '#4299e1'),
  ('OnlineTaxFiler', 'online-tax-filer', '#276749', '#2f855a', '#48bb78'),
  ('USeTaxFiler', 'use-tax-filer', '#744210', '#975a16', '#ecc94b'),
  ('AIUSTax', 'aius-tax', '#702459', '#97266d', '#ed64a6');