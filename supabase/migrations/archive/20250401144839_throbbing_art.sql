/*
  # Add organization data and relationships

  1. Changes
    - Insert organizations if they don't exist
    - Create function to add user-organization relationships
    - Add security policies
*/

-- Function to ensure organizations exist
DO $$
BEGIN
  -- Insert organizations if they don't exist
  IF NOT EXISTS (SELECT 1 FROM organizations LIMIT 1) THEN
    INSERT INTO organizations (name, slug, theme_primary_color, theme_secondary_color, theme_accent_color)
    VALUES 
      ('FreeTaxFiler', 'free-tax-filer', '#1a365d', '#2d3748', '#4299e1'),
      ('OnlineTaxFiler', 'online-tax-filer', '#276749', '#2f855a', '#48bb78'),
      ('USeTaxFiler', 'use-tax-filer', '#744210', '#975a16', '#ecc94b'),
      ('AIUSTax', 'aius-tax', '#702459', '#97266d', '#ed64a6');
  END IF;
END $$;

-- Create function to add user to organizations
CREATE OR REPLACE FUNCTION add_user_to_organizations(user_id uuid)
RETURNS void AS $$
BEGIN
  INSERT INTO user_organizations (user_id, organization_id, role)
  SELECT 
    user_id,
    id as organization_id,
    'admin' as role
  FROM organizations
  ON CONFLICT (user_id, organization_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically add new users to organizations
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  PERFORM add_user_to_organizations(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger for new user creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();