/*
  # Fix ticket system and improve performance

  1. Changes
    - Add indexes for better query performance
    - Add notification functions
    - Fix ticket assignment tracking

  2. Security
    - Maintain existing security policies
    - Add notification permissions
*/

-- Add performance indexes
CREATE INDEX IF NOT EXISTS idx_tickets_status_org ON tickets(status, organization_id);
CREATE INDEX IF NOT EXISTS idx_tickets_created_on ON tickets(created_on);
CREATE INDEX IF NOT EXISTS idx_tickets_assigned_status ON tickets(assigned_to, status);

-- Function to notify ticket assignment
CREATE OR REPLACE FUNCTION notify_ticket_assignment(
  p_ticket_id uuid,
  p_assigned_to uuid
)
RETURNS void AS $$
BEGIN
  -- Insert into ticket_history
  INSERT INTO ticket_history (
    ticket_id,
    changed_by,
    field_name,
    old_value,
    new_value
  )
  SELECT
    p_ticket_id,
    auth.uid(),
    'assigned_to',
    (SELECT email FROM users WHERE id = tickets.assigned_to),
    (SELECT email FROM users WHERE id = p_assigned_to)
  FROM tickets
  WHERE id = p_ticket_id;

  -- Update ticket
  UPDATE tickets
  SET 
    assigned_to = p_assigned_to,
    updated_at = now()
  WHERE id = p_ticket_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add notification functions
CREATE OR REPLACE FUNCTION get_user_notifications(p_user_id uuid)
RETURNS TABLE (
  ticket_id uuid,
  ticket_no text,
  name_of_client text,
  created_on timestamptz,
  status text
) AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;