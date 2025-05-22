/*
  # Fix function search paths for security

  1. Changes
    - Add SET search_path = public to all functions
    - Make functions more secure by setting explicit search paths
    - No schema changes, only function updates

  2. Security
    - Prevent search path manipulation
    - Ensure functions use correct schema
*/

-- Update generate_ticket_number function
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_ticket_no text;
BEGIN
  SELECT CONCAT('TKT-', TO_CHAR(NOW(), 'YYYYMMDD'), '-', 
    LPAD(COALESCE(
      (SELECT COUNT(*) + 1 
       FROM tickets 
       WHERE created_on::date = CURRENT_DATE), 
      1)::text, 
    4, '0'))
  INTO new_ticket_no;
  RETURN new_ticket_no;
END;
$$;

-- Update notify_ticket_assignment function
CREATE OR REPLACE FUNCTION notify_ticket_assignment(
  p_ticket_id uuid,
  p_assigned_to uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
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

  UPDATE tickets
  SET 
    assigned_to = p_assigned_to,
    updated_at = now()
  WHERE id = p_ticket_id;
END;
$$;

-- Update get_user_notifications function
CREATE OR REPLACE FUNCTION get_user_notifications(p_user_id uuid)
RETURNS TABLE (
  ticket_id uuid,
  ticket_no text,
  name_of_client text,
  created_on timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
$$;

-- Update get_dashboard_stats function
CREATE OR REPLACE FUNCTION get_dashboard_stats(p_organization_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'totalTickets', (
      SELECT COUNT(*) FROM tickets WHERE organization_id = p_organization_id
    ),
    'openTickets', (
      SELECT COUNT(*) FROM tickets WHERE organization_id = p_organization_id AND status = 'open'
    ),
    'resolvedToday', (
      SELECT COUNT(*) FROM tickets 
      WHERE organization_id = p_organization_id 
      AND status = 'closed' 
      AND closed_on::date = CURRENT_DATE
    ),
    'avgResponseTime', (
      SELECT COALESCE(
        EXTRACT(EPOCH FROM AVG(closed_on - created_on))/3600, 
        0
      )::numeric(10,2)
      FROM tickets 
      WHERE organization_id = p_organization_id 
      AND status = 'closed'
    )
  ) INTO result;
  RETURN result;
END;
$$;

-- Update handle_new_user function
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'name', 'user')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Update update_room_timestamp function
CREATE OR REPLACE FUNCTION update_room_timestamp()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE chat_rooms
  SET updated_at = now()
  WHERE id = NEW.room_id;
  RETURN NEW;
END;
$$;