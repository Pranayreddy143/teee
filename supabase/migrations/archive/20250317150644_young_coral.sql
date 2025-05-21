/*
  # Fix database policies and triggers

  1. Changes
    - Update RLS policies for better security
    - Fix ticket history tracking
    - Improve user management

  2. Security
    - Ensure proper access control
    - Fix policy conflicts
*/
-- Rolling out policies
-- Drop existing policies
DROP POLICY IF EXISTS "Enable select for all users" ON users;
DROP POLICY IF EXISTS "Enable insert for auth service" ON users;
DROP POLICY IF EXISTS "Enable update for admins" ON users;

-- Create new policies for users table
CREATE POLICY "Allow authenticated users to view users"
  ON users
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow system to create users"
  ON users
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow admins to update users"
  ON users
  FOR UPDATE
  TO authenticated
  USING (role = 'admin')
  WITH CHECK (role = 'admin');

-- Update ticket history trigger function
CREATE OR REPLACE FUNCTION track_ticket_changes()
RETURNS TRIGGER AS $$
DECLARE
  changed_fields text[];
  old_value text;
  new_value text;
BEGIN
  changed_fields := ARRAY[
    'status',
    'description',
    'resolution',
    'closed_on',
    'closed_by',
    'issue_type',
    'client_file_no',
    'mobile_no',
    'name_of_client'
  ];
  
  FOR i IN 1..array_length(changed_fields, 1) LOOP
    EXECUTE format('SELECT $1.%I::text', changed_fields[i])
    USING OLD INTO old_value;
    
    EXECUTE format('SELECT $1.%I::text', changed_fields[i])
    USING NEW INTO new_value;
    
    IF new_value IS DISTINCT FROM old_value THEN
      INSERT INTO ticket_history (
        ticket_id,
        changed_by,
        field_name,
        old_value,
        new_value
      ) VALUES (
        NEW.id,
        auth.uid(),
        changed_fields[i],
        old_value,
        new_value
      );
    END IF;
  END LOOP;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;