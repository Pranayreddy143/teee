/*
  # Add organizations and user-organization relationship

  1. New Tables
    - `organizations`
      - Basic organization info and theme settings
    - `user_organizations`
      - Links users to organizations they have access to

  2. Changes
    - Add indexes for organization lookups
    - Set up RLS policies
    - Insert default organizations with conflict handling

  3. Security
    - Enable RLS on new tables
    - Add appropriate access policies
*/

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

-- User-Organization relationship
CREATE TABLE IF NOT EXISTS user_organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) NOT NULL,
  organization_id uuid REFERENCES organizations(id) NOT NULL,
  role text DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, organization_id)
);

-- Create index for organization lookups
CREATE INDEX IF NOT EXISTS idx_tickets_organization ON tickets(organization_id);

-- Enable RLS
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_organizations ENABLE ROW LEVEL SECURITY;

-- Policies for organizations
DROP POLICY IF EXISTS "Users can view organizations they belong to" ON organizations;
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
DROP POLICY IF EXISTS "Users can view their organization memberships" ON user_organizations;
CREATE POLICY "Users can view their organization memberships"
  ON user_organizations
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Insert default organizations with conflict handling
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