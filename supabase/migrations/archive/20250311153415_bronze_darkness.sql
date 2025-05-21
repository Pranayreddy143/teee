/*
  # Create tickets table for help desk manager

  1. New Tables
    - `tickets`
      - `id` (uuid, primary key)
      - `ticket_no` (text, unique)
      - `created_on` (date)
      - `opened_by` (text)
      - `client_file_no` (text)
      - `mobile_no` (text)
      - `name_of_client` (text)
      - `issue_type` (text)
      - `description` (text)
      - `resolution` (text)
      - `closed_on` (date)
      - `closed_by` (text)
      - `status` (text)
      - `created_at` (timestamp with time zone)

  2. Security
    - Enable RLS on `tickets` table
    - Add policies for authenticated users to perform CRUD operations
*/

CREATE TABLE IF NOT EXISTS tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_no text UNIQUE NOT NULL,
  created_on date NOT NULL,
  opened_by text NOT NULL,
  client_file_no text NOT NULL,
  mobile_no text NOT NULL,
  name_of_client text NOT NULL,
  issue_type text NOT NULL,
  description text,
  resolution text,
  closed_on date,
  closed_by text,
  status text NOT NULL DEFAULT 'open',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for authenticated users"
  ON tickets
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Enable insert access for authenticated users"
  ON tickets
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users"
  ON tickets
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Enable delete access for authenticated users"
  ON tickets
  FOR DELETE
  TO authenticated
  USING (true);