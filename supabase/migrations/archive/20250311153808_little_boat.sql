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
    - Add policies for all operations to allow public access since this is an internal tool
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

-- Enable RLS but create policies that allow all operations
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;

-- Allow public read access
CREATE POLICY "Allow public read access"
  ON tickets
  FOR SELECT
  TO public
  USING (true);

-- Allow public insert access
CREATE POLICY "Allow public insert access"
  ON tickets
  FOR INSERT
  TO public
  WITH CHECK (true);

-- Allow public update access
CREATE POLICY "Allow public update access"
  ON tickets
  FOR UPDATE
  TO public
  USING (true)
  WITH CHECK (true);

-- Allow public delete access
CREATE POLICY "Allow public delete access"
  ON tickets
  FOR DELETE
  TO public
  USING (true);