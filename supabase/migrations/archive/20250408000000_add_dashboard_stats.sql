-- Function to get dashboard statistics
CREATE OR REPLACE FUNCTION get_dashboard_stats(p_organization_id uuid)
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'totalTickets', (
      SELECT COUNT(*) 
      FROM tickets 
      WHERE organization_id = p_organization_id
    ),
    'openTickets', (
      SELECT COUNT(*) 
      FROM tickets 
      WHERE organization_id = p_organization_id 
      AND status = 'open'
    ),
    'resolvedToday', (
      SELECT COUNT(*) 
      FROM tickets 
      WHERE organization_id = p_organization_id 
      AND status = 'closed' 
      AND closed_on = CURRENT_DATE
    ),
    'avgResponseTime', (
      SELECT COALESCE(
        EXTRACT(EPOCH FROM AVG(closed_on::timestamp - created_on::timestamp))/3600,
        0
      )::numeric(10,2)
      FROM tickets 
      WHERE organization_id = p_organization_id 
      AND status = 'closed'
    )
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
