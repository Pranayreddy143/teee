/*
  # Fix organization access for login screen

  1. Changes
    - Update RLS policies for organizations table to allow public access
    - Keep other security measures intact
    - Ensure organizations are visible during login

  2. Security
    - Allow public read access to organizations
    - Maintain existing security for other operations
*/

-- Drop existing policy
DROP POLICY IF EXISTS "Users can view organizations they belong to" ON organizations;

-- Create new policy to allow public read access to organizations
CREATE POLICY "Allow public read access to organizations"
  ON organizations
  FOR SELECT
  TO public
  USING (true);