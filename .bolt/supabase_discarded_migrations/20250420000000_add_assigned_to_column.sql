-- Add assigned_to column to tickets table if it doesn't exist
DO $$ 
BEGIN 
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'tickets' 
    AND column_name = 'assigned_to'
  ) THEN
    ALTER TABLE tickets
    ADD COLUMN assigned_to uuid REFERENCES auth.users(id);
  END IF;
END $$;

-- Update the track_ticket_changes trigger function to include assigned_to changes
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
    'name_of_client',
    'assigned_to'
  ];
  
  FOR i IN 1..array_length(changed_fields, 1) LOOP
    EXECUTE format('SELECT ($1.%I)::text', changed_fields[i])
    USING OLD INTO old_value;
    
    EXECUTE format('SELECT ($1.%I)::text', changed_fields[i])
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

-- Drop and recreate the trigger to ensure it's up to date
DROP TRIGGER IF EXISTS track_ticket_changes ON tickets;
CREATE TRIGGER track_ticket_changes
  AFTER UPDATE ON tickets
  FOR EACH ROW
  EXECUTE FUNCTION track_ticket_changes();