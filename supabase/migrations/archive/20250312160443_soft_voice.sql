/*
  # Add authentication and ticket history tracking

  1. New Tables
    - `users`
      - `id` (uuid, primary key)
      - `email` (text, unique)
      - `role` (text)
      - `created_at` (timestamptz)
    - `ticket_history`
      - `id` (uuid, primary key)
      - `ticket_id` (uuid, references tickets)
      - `changed_by` (uuid, references auth.users)
      - `changed_at` (timestamptz)
      - `field_name` (text)
      - `old_value` (text)
      - `new_value` (text)

  2. Changes
    - Add search indexes on tickets table
    - Add trigger for tracking ticket changes

  3. Security
    - Enable RLS on new tables
    - Add policies for proper access control
*/

-- Create users table
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY REFERENCES auth.users,
  email text UNIQUE NOT NULL,
  role text NOT NULL DEFAULT 'user',
  created_at timestamptz DEFAULT now()
);

-- Create ticket history table
CREATE TABLE IF NOT EXISTS ticket_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid REFERENCES tickets(id) NOT NULL,
  changed_by uuid REFERENCES auth.users NOT NULL,
  changed_at timestamptz DEFAULT now(),
  field_name text NOT NULL,
  old_value text,
  new_value text,
  created_at timestamptz DEFAULT now()
);

-- Add indexes for search
CREATE INDEX IF NOT EXISTS idx_tickets_mobile_no ON tickets(mobile_no);
CREATE INDEX IF NOT EXISTS idx_tickets_client_file_no ON tickets(client_file_no);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_history ENABLE ROW LEVEL SECURITY;

-- Policies for users table
CREATE POLICY "Users can view their own data"
  ON users
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Only admins can update users"
  ON users
  FOR UPDATE
  TO authenticated
  USING (auth.jwt() ->> 'role' = 'admin');

-- Policies for ticket history
CREATE POLICY "All authenticated users can view ticket history"
  ON ticket_history
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only authenticated users can insert ticket history"
  ON ticket_history
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Function to track ticket changes
CREATE OR REPLACE FUNCTION track_ticket_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    -- For each changed column, insert a history record
    IF NEW.status IS DISTINCT FROM OLD.status THEN
      INSERT INTO ticket_history (ticket_id, changed_by, field_name, old_value, new_value)
      VALUES (NEW.id, auth.uid(), 'status', OLD.status, NEW.status);
    END IF;
    
    IF NEW.description IS DISTINCT FROM OLD.description THEN
      INSERT INTO ticket_history (ticket_id, changed_by, field_name, old_value, new_value)
      VALUES (NEW.id, auth.uid(), 'description', OLD.description, NEW.description);
    END IF;
    
    IF NEW.resolution IS DISTINCT FROM OLD.resolution THEN
      INSERT INTO ticket_history (ticket_id, changed_by, field_name, old_value, new_value)
      VALUES (NEW.id, auth.uid(), 'resolution', OLD.resolution, NEW.resolution);
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for tracking changes
CREATE TRIGGER track_ticket_changes
  AFTER UPDATE ON tickets
  FOR EACH ROW
  EXECUTE FUNCTION track_ticket_changes();